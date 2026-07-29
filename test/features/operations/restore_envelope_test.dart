import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';
import 'package:world_keeper/features/operations/data/restore_envelope.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

import '../../support/fake_target.dart';

void main() {
  const worlds = '/home/steam/Core Keeper/worlds';
  const backupDir = '$worlds/.backups/0.2026-07-26_120000';

  late AuditDatabase audit;
  late int sessionId;

  setUp(() async {
    audit = AuditDatabaseFactory.inMemory();
    sessionId = await audit.startSession('test');
  });

  tearDown(() async => audit.close());

  /// A server with a live world and one restorable backup.
  FakeTarget healthyTarget({
    bool slotOccupied = true,
    bool backupHasMain = true,
  }) {
    final t = FakeTarget(
      serviceKind: const SystemdService(unit: 'corekeeper'),
      worldsPath: worlds,
    )..udpLines = ['UNCONN 0 0 0.0.0.0:56967'];
    t.logTail = 'GameID: RESTORED-99\n';

    if (slotOccupied) {
      t.addFile(worlds, '0.world.gzip', size: 5046105);
      t.addFile(worlds, '0.world.gzip.pugbackup', size: 5047192);
    }
    if (backupHasMain) {
      t.addFile(backupDir, '0.world.gzip', size: 4000000);
      t.addFile(backupDir, '0.world.gzip.pugbackup', size: 4000100);
    }
    return t;
  }

  RestoreEnvelope envelopeFor(FakeTarget t) => RestoreEnvelope(
    target: t,
    audit: audit,
    sessionId: sessionId,
    timings: EnvelopeTimings.fast,
  );

  group('the happy path', () {
    test('completes and reports the safety backup', () async {
      final t = healthyTarget();
      final states = <RestoreState>[];

      final result = await envelopeFor(
        t,
      ).run(backupDir, 0, onProgress: (p) => states.add(p.state));

      expect(result.slot, 0);
      expect(result.gameId, 'RESTORED-99');
      expect(result.backupPath, isNotNull);

      expect(states, [
        RestoreState.checkingService,
        RestoreState.stopping,
        RestoreState.backingUp,
        RestoreState.copying,
        RestoreState.fixingPerms,
        RestoreState.starting,
        RestoreState.capturingGameId,
        RestoreState.verifying,
        RestoreState.done,
      ]);
    });

    test(
      'backs up what is live before overwriting — a restore is undoable',
      () async {
        final t = healthyTarget();
        final result = await envelopeFor(t).run(backupDir, 0);

        expect(result.backupPath, startsWith('$worlds/.backups/0.'));
        expect(result.backupPath, isNot(backupDir));

        // The safety copy happens before anything is copied in.
        final safetyIndex = t.commands.indexWhere(
          (c) => c.startsWith('cp -a') && c.contains('$worlds/0.world.gzip'),
        );
        final restoreIndex = t.commands.indexWhere(
          (c) => c.startsWith('cp -a') && c.contains(backupDir),
        );
        expect(safetyIndex, greaterThanOrEqualTo(0));
        expect(restoreIndex, greaterThan(safetyIndex));
      },
    );

    test('notes why the safety backup exists', () async {
      final t = healthyTarget();
      await envelopeFor(t).run(backupDir, 0);

      final backups = await audit.select(audit.auditBackups).get();
      expect(backups.single.note, 'pre-restore safety backup');
    });

    test(
      'cherry-picks the world pair, ignoring anything else in the backup',
      () async {
        // Backups made before the exact-pair rule, or against an image that keeps its own
        // snapshots, can hold more than the pair. Restoring those would overwrite files
        // that merely share a prefix.
        final t = healthyTarget()
          ..addFile(backupDir, '0.world.gzip.old')
          ..addFile(backupDir, 'notes.txt')
          ..addFile(backupDir, '1.world.gzip');

        await envelopeFor(t).run(backupDir, 0);

        final restored = t.commands
            .where((c) => c.startsWith('cp -a') && c.contains(backupDir))
            .toList();
        expect(restored, hasLength(2));
        expect(restored.any((c) => c.contains('notes.txt')), isFalse);
        expect(restored.any((c) => c.contains('.old')), isFalse);
        expect(restored.any((c) => c.contains('1.world.gzip')), isFalse);
      },
    );

    test('copies rather than moves, so the backup survives', () async {
      final t = healthyTarget();
      await envelopeFor(t).run(backupDir, 0);
      expect(t.commands.any((c) => c.startsWith('mv ')), isFalse);
    });

    test('restores a backup that has no pugbackup', () async {
      final t = healthyTarget();
      t.files[backupDir]!.removeWhere((f) => f.name.endsWith('.pugbackup'));

      await envelopeFor(t).run(backupDir, 0);
      final restored = t.commands
          .where((c) => c.startsWith('cp -a') && c.contains(backupDir))
          .toList();
      expect(restored, hasLength(1));
    });
  });

  group('the cross-target guard', () {
    test('refuses a path outside this server\'s worlds directory', () async {
      // A stale list or direct API misuse could point at a completely different server.
      final t = healthyTarget();

      await expectLater(
        envelopeFor(t).run('/somewhere/else/.backups/0.2026-01-01_000000', 0),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('refusing to restore across targets'),
          ),
        ),
      );
    });

    test('refuses BEFORE stopping anything', () async {
      // The worst case must be an error message, not a stopped server.
      final t = healthyTarget();

      await expectLater(
        envelopeFor(t).run('/elsewhere/backup', 0),
        throwsA(isA<OperationException>()),
      );

      expect(t.serviceActions, isEmpty);
      expect(t.commands, isEmpty);
    });

    test('rejects a sibling directory that merely shares a prefix', () async {
      // `/…/worlds-evil` starts with `/…/worlds` as a *string* but is a different
      // directory — the check is path containment, not prefix matching.
      final t = healthyTarget();

      await expectLater(
        envelopeFor(t).run('$worlds-evil/backup', 0),
        throwsA(isA<OperationException>()),
      );
      expect(t.serviceActions, isEmpty);
    });

    test('records the refusal', () async {
      final t = healthyTarget();
      await expectLater(
        envelopeFor(t).run('/elsewhere/backup', 0),
        throwsA(isA<OperationException>()),
      );

      final errors = await audit.select(audit.auditErrors).get();
      expect(errors.single.context, 'restore');
    });
  });

  group('failures roll back', () {
    test('a backup with no main world file aborts', () async {
      final t = healthyTarget(backupHasMain: false);

      await expectLater(
        envelopeFor(t).run(backupDir, 0),
        throwsA(
          isA<OperationException>()
              .having((e) => e.step, 'step', 'copying')
              .having(
                (e) => e.message,
                'message',
                contains('nothing to restore'),
              ),
        ),
      );
    });

    test('an aborted restore puts the live world back', () async {
      final t = healthyTarget(backupHasMain: false);

      try {
        await envelopeFor(t).run(backupDir, 0);
        fail('expected the restore to fail');
      } on OperationException catch (e) {
        expect(e.rollbackNote, contains('restored backup'));
        expect(e.rollbackNote, contains('restart issued'));
      }
      expect(t.serviceActions.last, ServiceAction.start);
    });

    test('a stop that never settles fails and restarts', () async {
      final t = healthyTarget()..stateAfterStop = null;

      await expectLater(
        envelopeFor(t).run(backupDir, 0),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      expect(t.serviceActions.last, ServiceAction.start);
    });

    test('a service that fails while starting is caught', () async {
      final t = healthyTarget()
        ..stateAfterStart = RunState.failed
        ..logTail = 'fatal: world corrupt\n';

      await expectLater(
        envelopeFor(t).run(backupDir, 0),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('world corrupt'),
          ),
        ),
      );
    });

    test('verification failure rolls back', () async {
      final t = healthyTarget()..udpLines = const [];

      await expectLater(
        envelopeFor(t).run(backupDir, 0),
        throwsA(
          isA<OperationException>().having((e) => e.step, 'step', 'verifying'),
        ),
      );
    });

    test(
      'restoring into an empty slot has nothing to safety-back-up',
      () async {
        final t = healthyTarget(slotOccupied: false);
        final result = await envelopeFor(t).run(backupDir, 0);
        expect(result.backupPath, isNull);
      },
    );
  });

  group('listBackups', () {
    test('lists dated backups newest first', () async {
      final t = healthyTarget();
      const dir = '$worlds/.backups';
      t.addFile(dir, '0.2026-07-25_090000');
      t.addFile(dir, '0.2026-07-26_120000');
      t.addFile(dir, '1.2026-07-24_080000');

      final backups = await envelopeFor(t).listBackups();

      expect(backups.map((b) => b.path.split('/').last), [
        '1.2026-07-24_080000',
        '0.2026-07-26_120000',
        '0.2026-07-25_090000',
      ]);
      expect(backups.map((b) => b.slot), [1, 0, 0]);
    });

    test('skips the .backups directory itself', () async {
      // `find <dir> -maxdepth 1 -name '*'` matches the directory at depth 0 too.
      final t = healthyTarget();
      const dir = '$worlds/.backups';
      t.files[dir] = const [
        FileEntry(path: dir, size: 4096),
        FileEntry(path: '$dir/0.2026-07-26_120000', size: 0),
      ];

      final backups = await envelopeFor(t).listBackups();
      expect(backups, hasLength(1));
      expect(backups.single.path, endsWith('0.2026-07-26_120000'));
    });

    test('still lists a backup whose name has no parseable slot', () async {
      final t = healthyTarget();
      t.addFile('$worlds/.backups', 'hand-made-copy');

      final backups = await envelopeFor(t).listBackups();
      expect(backups.single.slot, isNull);
    });
  });
}
