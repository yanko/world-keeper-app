import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';
import 'package:world_keeper/features/operations/data/push_envelope.dart';
import 'package:world_keeper/features/operations/domain/local_world.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

import '../../support/fake_target.dart';

/// The push envelope, exercised against a fake target.
///
/// This is what the `ServerTarget` seam buys: every branch below — a stop that never
/// settles, a service that fails while starting, a corrupted upload, a rollback with no
/// backup to restore — is a plain unit test with no server, no network and no risk. None
/// of it was reachable in the original app, which has no tests at all.
void main() {
  const worlds = '/home/steam/Core Keeper/worlds';

  late Directory tempDir;
  late AuditDatabase audit;
  late int sessionId;
  late File worldFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_push_test');
    audit = AuditDatabaseFactory.inMemory();
    sessionId = await audit.startSession('test');

    worldFile = File('${tempDir.path}${Platform.pathSeparator}0.world.gzip');
    await worldFile.writeAsBytes(List<int>.generate(2048, (i) => i % 256));
  });

  tearDown(() async {
    await audit.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// The digest the target must report back for the upload to be accepted.
  Future<String> digestOf(File f) async =>
      (await sha256.bind(f.openRead()).first).toString();

  /// A target primed to accept a healthy push of [slot].
  Future<FakeTarget> healthyTarget({
    int slot = 0,
    bool slotOccupied = true,
  }) async {
    final t = FakeTarget(
      serviceKind: const SystemdService(unit: 'corekeeper'),
      worldsPath: worlds,
    )..udpLines = ['UNCONN 0 0 0.0.0.0:56967'];
    t.logTail = 'GameID: TEST-1234\n';

    // The staged upload verifies against the real local digest.
    t.responses["sha256sum '$worlds/.staging/$slot.world.gzip'"] = ExecOutput(
      stdout:
          '${await digestOf(worldFile)}  $worlds/.staging/$slot.world.gzip\n',
      stderr: '',
      exitStatus: 0,
    );

    if (slotOccupied) {
      t.addFile(worlds, '$slot.world.gzip', size: 5046105);
      t.addFile(worlds, '$slot.world.gzip.pugbackup', size: 5047192);
    }
    return t;
  }

  LocalWorldCandidate candidate({int slot = 0, String? pugbackup}) =>
      LocalWorldCandidate(
        slot: slot,
        slotInferred: true,
        mainPath: worldFile.path,
        mainSize: worldFile.lengthSync(),
        pugbackupPath: pugbackup,
      );

  PushEnvelope envelopeFor(FakeTarget t) => PushEnvelope(
    target: t,
    audit: audit,
    sessionId: sessionId,
    timings: EnvelopeTimings.fast,
  );

  group('the happy path', () {
    test('completes and reports the result', () async {
      final t = await healthyTarget();
      final states = <PushState>[];

      final result = await envelopeFor(
        t,
      ).run(candidate(), onProgress: (p) => states.add(p.state));

      expect(result.slot, 0);
      expect(result.gameId, 'TEST-1234');
      expect(result.bytesUploaded, 2048);
      expect(result.backupPath, isNotNull);
      expect(result.udpListening, isTrue);

      expect(states, [
        PushState.uploading,
        PushState.checkingService,
        PushState.stopping,
        PushState.backingUp,
        PushState.copying,
        PushState.fixingPerms,
        PushState.starting,
        PushState.capturingGameId,
        PushState.verifying,
        PushState.done,
      ]);
    });

    test('the upload lands in the audit trail', () async {
      // The one step of a push that leaves no trace anywhere else. Every other action is
      // a shell command and shows up in `ssh_commands`; an SFTP transfer is not a
      // command, so without an explicit row the log said a push happened and never said
      // the file moved. `file_ops` is the table the Rust app used for this, and it was
      // being imported from and never written to.
      final t = await healthyTarget();
      await envelopeFor(t).run(candidate());

      final ops = await audit.customSelect('SELECT * FROM file_ops').get();

      expect(ops, hasLength(1));
      expect(ops.single.data['op'], 'upload');
      expect(ops.single.data['bytes'], 2048);
      expect(
        ops.single.data['event_id'],
        isNotNull,
        reason:
            'file_ops has no session of its own — it scopes through its event',
      );
    });

    test('uploads before stopping the server', () async {
      // The destructive window must be as small as possible: by the time the service is
      // stopped the bytes are already across and verified, so the swap itself is a `mv`.
      final t = await healthyTarget();
      await envelopeFor(t).run(candidate());

      final stopIndex = t.serviceActions.indexOf(ServiceAction.stop);
      expect(stopIndex, greaterThanOrEqualTo(0));
      expect(t.uploads, hasLength(1));
      // The upload happened before any service control at all.
      expect(
        t.commands.indexWhere((c) => c.contains('sha256sum')),
        lessThan(t.commands.indexWhere((c) => c.contains('mv '))),
      );
    });

    test('backs up the live world before overwriting it', () async {
      final t = await healthyTarget();
      await envelopeFor(t).run(candidate());

      final backupIndex = t.commands.indexWhere((c) => c.startsWith('cp -a'));
      final moveIndex = t.commands.indexWhere((c) => c.startsWith('mv '));
      expect(backupIndex, greaterThanOrEqualTo(0));
      expect(moveIndex, greaterThan(backupIndex));
    });

    test(
      'backs up exactly the world pair, not everything sharing the prefix',
      () async {
        // Some images keep .old/.old2/.backup snapshots beside the real files, and users
        // keep their own. A `<slot>.world.gzip*` glob sweeps those into the backup, and a
        // later restore then overwrites them.
        final t = await healthyTarget();
        t.addFile(worlds, '0.world.gzip.old');
        t.addFile(worlds, '0.world.gzip.manual-2026-07-26');

        await envelopeFor(t).run(candidate());

        final copied = t.commands.where((c) => c.startsWith('cp -a')).toList();
        expect(copied, hasLength(2));
        expect(copied.any((c) => c.contains('.old')), isFalse);
        expect(copied.any((c) => c.contains('manual-2026')), isFalse);
      },
    );

    test(
      'uploads under the canonical slot name whatever the source is called',
      () async {
        // This is what lets an arbitrarily-named export be pushed into a chosen slot.
        final odd = File(
          '${tempDir.path}${Platform.pathSeparator}my-export.world.gzip',
        );
        await odd.writeAsBytes(const [1, 2, 3]);

        final t = FakeTarget(
          serviceKind: const SystemdService(unit: 'corekeeper'),
          worldsPath: worlds,
        )..udpLines = ['listening'];
        t.responses["sha256sum '$worlds/.staging/3.world.gzip'"] = ExecOutput(
          stdout: '${await digestOf(odd)}  x\n',
          stderr: '',
          exitStatus: 0,
        );

        await envelopeFor(t).run(
          LocalWorldCandidate(
            slot: 3,
            slotInferred: false,
            mainPath: odd.path,
            mainSize: 3,
          ),
        );

        expect(t.uploads.single.remote, '$worlds/.staging/3.world.gzip');
        expect(
          t.commands.any(
            (c) =>
                c ==
                "mv '$worlds/.staging/3.world.gzip' '$worlds/3.world.gzip'",
          ),
          isTrue,
        );
      },
    );

    test(
      'a first push to an empty slot makes no backup, and that is not a failure',
      () async {
        final t = await healthyTarget(slotOccupied: false);
        final result = await envelopeFor(t).run(candidate());

        expect(result.backupPath, isNull);
        expect(t.commands.any((c) => c.startsWith('cp -a')), isFalse);
      },
    );

    test('leaves an existing pugbackup alone when the source has none', () async {
      // It is already preserved in the dated backup, and Core Keeper regenerates it on
      // the next save cycle — deleting or guessing at it would be worse.
      final t = await healthyTarget();
      await envelopeFor(t).run(candidate());

      final moves = t.commands.where((c) => c.startsWith('mv ')).toList();
      expect(moves, hasLength(1));
      expect(moves.single, contains('0.world.gzip'));
      expect(moves.single.contains('pugbackup'), isFalse);
    });

    test('moves the pugbackup too when the source has one', () async {
      final pug = File(
        '${tempDir.path}${Platform.pathSeparator}0.world.gzip.pugbackup',
      );
      await pug.writeAsBytes(const [9, 9, 9]);

      final t = await healthyTarget();
      t.responses["sha256sum '$worlds/.staging/0.world.gzip.pugbackup'"] =
          ExecOutput(
            stdout: '${await digestOf(pug)}  x\n',
            stderr: '',
            exitStatus: 0,
          );

      final result = await envelopeFor(t).run(candidate(pugbackup: pug.path));

      expect(result.bytesUploaded, 2048 + 3);
      expect(t.commands.where((c) => c.startsWith('mv ')), hasLength(2));
    });

    test('writes a complete audit trail', () async {
      final t = await healthyTarget();
      await envelopeFor(t).run(candidate());
      // Give the fire-and-forget state_enter writes a chance to land.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final events = await audit.select(audit.auditEvents).get();
      final kinds = events.map((e) => e.kind).toSet();
      expect(kinds, containsAll(['push_begin', 'state_enter', 'push_done']));

      final backups = await audit.select(audit.auditBackups).get();
      expect(backups, hasLength(1));
      expect(backups.single.slot, 0);
    });
  });

  group('upload failures happen before anything is stopped', () {
    test('a checksum mismatch aborts without touching the service', () async {
      final t = await healthyTarget();
      t.responses["sha256sum '$worlds/.staging/0.world.gzip'"] =
          const ExecOutput(stdout: 'deadbeef  x\n', stderr: '', exitStatus: 0);

      await expectLater(
        envelopeFor(t).run(candidate()),
        throwsA(
          isA<OperationException>()
              .having((e) => e.step, 'step', 'uploading')
              .having(
                (e) => e.message,
                'message',
                contains('checksum mismatch'),
              ),
        ),
      );

      // The server was never stopped, so there is nothing to roll back to.
      expect(t.serviceActions.contains(ServiceAction.stop), isFalse);
    });

    test('a silent sha256sum is treated as a failure, not a pass', () async {
      // An empty digest must never compare equal to anything.
      final t = await healthyTarget();
      t.responses["sha256sum '$worlds/.staging/0.world.gzip'"] =
          const ExecOutput.empty();

      await expectLater(
        envelopeFor(t).run(candidate()),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('sha256sum produced no output'),
          ),
        ),
      );
    });

    test('a failed mkdir of the staging directory aborts', () async {
      final t = await healthyTarget();
      t.responses["mkdir -p '$worlds/.staging'"] = const ExecOutput(
        stdout: '',
        stderr: 'permission denied',
        exitStatus: 1,
      );

      await expectLater(
        envelopeFor(t).run(candidate()),
        throwsA(isA<OperationException>()),
      );
      expect(t.serviceActions.contains(ServiceAction.stop), isFalse);
    });

    test('a source file deleted between picking and pushing is caught', () async {
      // Resolution and the push are separate user actions; the file can vanish in
      // between, and the failure should be a clear message rather than a crash.
      final t = await healthyTarget();
      final stale = candidate();
      await worldFile.delete();

      await expectLater(
        envelopeFor(t).run(stale),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('no longer exists'),
          ),
        ),
      );
      expect(t.serviceActions.contains(ServiceAction.stop), isFalse);
    });
  });

  group('failures after the stop roll back', () {
    test('a stop that never settles times out and still restarts', () async {
      final t = await healthyTarget()
        ..stateAfterStop = null; // ignores the stop
      final states = <PushState>[];

      await expectLater(
        envelopeFor(t).run(candidate(), onProgress: (p) => states.add(p.state)),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );

      expect(states, contains(PushState.rollingBack));
      expect(states.last, PushState.failed);
      // Never leave a game server stopped and silent.
      expect(t.serviceActions.last, ServiceAction.start);
    });

    test(
      'a service that fails while starting bails early with the log',
      () async {
        final t = await healthyTarget()
          ..stateAfterStart = RunState.failed
          ..logTail = 'fatal: could not bind socket\n';

        await expectLater(
          envelopeFor(t).run(candidate()),
          throwsA(
            isA<OperationException>()
                .having((e) => e.message, 'message', contains('failed state'))
                .having(
                  (e) => e.message,
                  'message',
                  contains('could not bind socket'),
                ),
          ),
        );
      },
    );

    test('rollback restores the backup and restarts', () async {
      final t = await healthyTarget()
        ..stateAfterStart = RunState.failed;

      try {
        await envelopeFor(t).run(candidate());
        fail('expected the push to fail');
      } on OperationException catch (e) {
        expect(e.rollbackNote, contains('restored backup'));
        expect(e.rollbackNote, contains('restart issued'));
      }

      // `cp -a <backup>/. <worlds>/` puts the whole backup back.
      expect(
        t.commands.any((c) => c.startsWith('cp -a') && c.contains('/. ')),
        isTrue,
      );
    });

    test('rollback with no backup says so and still restarts', () async {
      // A first push to an empty slot that then fails: there is nothing to restore, but
      // leaving the service down would still be the worst outcome.
      final t = await healthyTarget(slotOccupied: false)
        ..stateAfterStart = RunState.failed;

      try {
        await envelopeFor(t).run(candidate());
        fail('expected the push to fail');
      } on OperationException catch (e) {
        expect(e.rollbackNote, contains('no backup existed'));
        expect(e.rollbackNote, contains('restart issued'));
      }
      expect(t.serviceActions.last, ServiceAction.start);
    });

    test('a failed copy into place rolls back', () async {
      final t = await healthyTarget();
      t.responses["mv '$worlds/.staging/0.world.gzip' '$worlds/0.world.gzip'"] =
          const ExecOutput(stdout: '', stderr: 'no space left', exitStatus: 1);

      await expectLater(
        envelopeFor(t).run(candidate()),
        throwsA(
          isA<OperationException>()
              .having((e) => e.step, 'step', 'copying')
              .having(
                (e) => e.rollbackNote,
                'rollbackNote',
                contains('restored backup'),
              ),
        ),
      );
    });

    test('a failed chown rolls back', () async {
      final t = await healthyTarget()
        ..fixPermsThrows = true;
      await expectLater(
        envelopeFor(t).run(candidate()),
        throwsA(
          isA<OperationException>().having(
            (e) => e.rollbackNote,
            'rollbackNote',
            isNotNull,
          ),
        ),
      );
    });

    test('a failed backup aborts before anything is overwritten', () async {
      // If the live world cannot be preserved, the swap must not proceed — that backup
      // is the only thing making the rest of the operation reversible.
      final t = await healthyTarget()
        ..failCommandsContaining('.backups/', stderr: 'read-only file system');

      await expectLater(
        envelopeFor(t).run(candidate()),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('backup'),
          ),
        ),
      );

      // Crucially: the staged file was never moved over the live one.
      expect(t.commands.any((c) => c.startsWith('mv ')), isFalse);
    });

    test(
      'verification failure rolls back even though everything else worked',
      () async {
        // The server is running but never binds its port — a real symptom of a world that
        // failed to load.
        final t = await healthyTarget()
          ..udpLines = const [];

        await expectLater(
          envelopeFor(t).run(candidate()),
          throwsA(
            isA<OperationException>()
                .having((e) => e.step, 'step', 'verifying')
                .having(
                  (e) => e.message,
                  'message',
                  contains('udp listening: false'),
                ),
          ),
        );
      },
    );

    test('a missing game id is not a failure', () async {
      // Not every packaging logs it in a recognised format; refusing to complete a good
      // swap over a cosmetic field would be worse.
      final t = await healthyTarget()
        ..logTail = 'no id here\n';
      final result = await envelopeFor(t).run(candidate());
      expect(result.gameId, isNull);
    });

    test('records the failure in the audit trail', () async {
      final t = await healthyTarget()
        ..udpLines = const [];
      await expectLater(
        envelopeFor(t).run(candidate()),
        throwsA(isA<OperationException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final errors = await audit.select(audit.auditErrors).get();
      expect(errors, hasLength(1));
      expect(errors.single.context, 'push');
      expect(errors.single.message, contains('verification failed'));
    });
  });

  group('quoting', () {
    test('every path with a space is quoted', () async {
      final t = await healthyTarget();
      await envelopeFor(t).run(candidate());

      for (final cmd in t.commands.where((c) => c.contains(worlds))) {
        expect(
          cmd.contains("'$worlds"),
          isTrue,
          reason: 'unquoted worlds path in: $cmd',
        );
      }
    });
  });
}
