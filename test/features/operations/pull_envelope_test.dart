import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';
import 'package:world_keeper/features/operations/data/pull_envelope.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

import '../../support/fake_target.dart';

void main() {
  const worlds = '/home/steam/Core Keeper/worlds';

  late Directory tempDir;
  late AuditDatabase audit;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_pull_test');
    audit = AuditDatabaseFactory.inMemory();
    sessionId = await audit.startSession('test');
  });

  tearDown(() async {
    await audit.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FakeTarget targetWithWorlds() {
    final t = FakeTarget(
      serviceKind: const SystemdService(unit: 'corekeeper'),
      worldsPath: worlds,
    );
    t.addFile(worlds, '0.world.gzip', size: 5046105, modified: 1785090045);
    t.addFile(worlds, '0.world.gzip.pugbackup', size: 5047192);
    return t;
  }

  PullEnvelope envelopeFor(FakeTarget t) => PullEnvelope(
    target: t,
    audit: audit,
    sessionId: sessionId,
    timings: EnvelopeTimings.fast,
  );

  group('listRemoteWorlds', () {
    test('lists the main file per slot, sorted', () async {
      final t = targetWithWorlds()
        ..addFile(worlds, '2.world.gzip', size: 100)
        ..addFile(worlds, '1.world.gzip', size: 200);

      final worldsList = await envelopeFor(t).listRemoteWorlds();
      expect(worldsList.map((w) => w.slot), [0, 1, 2]);
      expect(worldsList.first.size, 5046105);
      expect(worldsList.first.modified, 1785090045);
    });

    test('never offers a bare pugbackup as a world', () async {
      // It is one save cycle behind by definition; presenting it as "world N" would
      // quietly hand someone older data than they asked for.
      final t = FakeTarget(
        serviceKind: const SystemdService(unit: 'ck'),
        worldsPath: worlds,
      )..addFile(worlds, '4.world.gzip.pugbackup', size: 10);

      expect(await envelopeFor(t).listRemoteWorlds(), isEmpty);
    });

    test('ignores the extra snapshots that share the prefix', () async {
      final t = targetWithWorlds()
        ..addFile(worlds, '0.world.gzip.old')
        ..addFile(worlds, '0.world.gzip.manual-2026-07-26');

      final worldsList = await envelopeFor(t).listRemoteWorlds();
      expect(worldsList, hasLength(1));
    });
  });

  group('the happy path', () {
    test('stops, downloads and restarts', () async {
      final t = targetWithWorlds();
      final states = <PullState>[];

      final pulled = await envelopeFor(
        t,
      ).run(0, onProgress: (pr) => states.add(pr.state));

      expect(states, [
        PullState.checkingService,
        PullState.stopping,
        PullState.downloading,
        PullState.starting,
        PullState.done,
      ]);
      expect(t.serviceActions, contains(ServiceAction.stop));
      expect(t.serviceActions.last, ServiceAction.start);
      expect(pulled.slot, 0);
      expect(Directory(pulled.tempDir).existsSync(), isTrue);
    });

    test('takes the pugbackup along with the world', () async {
      // Unlike backup's exact pair, the download glob is deliberately inclusive: a pull
      // is read-only, so grabbing what sits alongside is a courtesy rather than a risk.
      final t = targetWithWorlds();
      final pulled = await envelopeFor(t).run(0);

      expect(t.downloads, hasLength(2));
      expect(pulled.pugbackupPath, isNotNull);
    });

    test('every download lands in the audit trail', () async {
      // Same gap as the push: an SFTP transfer is not a shell command, so nothing else in
      // the log records the file coming across. A pull takes the pugbackup too, so both
      // files should be accounted for.
      final t = targetWithWorlds();
      await envelopeFor(t).run(0);

      final ops = await audit.customSelect('SELECT * FROM file_ops').get();

      expect(ops, hasLength(2));
      expect(ops.map((o) => o.data['op']), everyElement('download'));
      expect(ops.map((o) => o.data['slot']), everyElement(0));
    });

    test('restarts as soon as the copy is done', () async {
      final t = targetWithWorlds();
      await envelopeFor(t).run(0);

      // The whole rationale for this flow is minimum downtime.
      expect(t.serviceActions, [ServiceAction.stop, ServiceAction.start]);
    });

    test('records the audit trail', () async {
      final t = targetWithWorlds();
      await envelopeFor(t).run(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final kinds = (await audit.select(audit.auditEvents).get())
          .map((e) => e.kind)
          .toSet();
      expect(kinds, containsAll(['pull_begin', 'state_enter', 'pull_done']));
    });
  });

  group('failures', () {
    test('a stop that never settles fails without downloading', () async {
      final t = targetWithWorlds()..stateAfterStop = null;

      await expectLater(
        envelopeFor(t).run(0),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      expect(t.downloads, isEmpty);
    });

    test('an empty slot fails clearly', () async {
      final t = FakeTarget(
        serviceKind: const SystemdService(unit: 'ck'),
        worldsPath: worlds,
      );

      await expectLater(
        envelopeFor(t).run(7),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('no world files found for slot 7'),
          ),
        ),
      );
    });

    test(
      'a slot with only a pugbackup fails rather than returning half a world',
      () async {
        final t = FakeTarget(
          serviceKind: const SystemdService(unit: 'ck'),
          worldsPath: worlds,
        )..addFile(worlds, '0.world.gzip.pugbackup', size: 10);

        await expectLater(
          envelopeFor(t).run(0),
          throwsA(
            isA<OperationException>().having(
              (e) => e.message,
              'message',
              contains('only a .pugbackup'),
            ),
          ),
        );
      },
    );

    test(
      'THE IMPORTANT ONE: a failed download still restarts the server',
      () async {
        // Leaving a game server stopped because a *copy* failed turns one problem into
        // two. The restart is unconditional for exactly this reason.
        final t = FakeTarget(
          serviceKind: const SystemdService(unit: 'ck'),
          worldsPath: worlds,
        );

        await expectLater(
          envelopeFor(t).run(0),
          throwsA(isA<OperationException>()),
        );

        expect(
          t.serviceActions.last,
          ServiceAction.start,
          reason: 'the server must come back up even when the download failed',
        );
      },
    );

    test(
      'a failed download AND a failed restart reports both, download first',
      () async {
        // The download error is what the user acted on, so it leads; the failed restart is
        // appended because it is the more urgent thing to go and fix.
        final t = FakeTarget(
          serviceKind: const SystemdService(unit: 'ck'),
          worldsPath: worlds,
        )..stateAfterStart = null; // the restart never settles

        await expectLater(
          envelopeFor(t).run(0),
          throwsA(
            isA<OperationException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('no world files found'),
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('the restart afterwards also failed'),
                ),
          ),
        );
      },
    );

    test(
      'a successful download with a failed restart still fails loudly',
      () async {
        final t = targetWithWorlds()..stateAfterStart = null;

        await expectLater(
          envelopeFor(t).run(0),
          throwsA(
            isA<OperationException>().having(
              (e) => e.message,
              'message',
              contains('timed out'),
            ),
          ),
        );
        // The bytes did arrive; the problem is the server.
        expect(t.downloads, isNotEmpty);
      },
    );

    test('records failures in the audit trail', () async {
      final t = FakeTarget(
        serviceKind: const SystemdService(unit: 'ck'),
        worldsPath: worlds,
      );
      await expectLater(
        envelopeFor(t).run(0),
        throwsA(isA<OperationException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final errors = await audit.select(audit.auditErrors).get();
      expect(errors.single.context, 'pull');
    });
  });

  group('packaging', () {
    Future<PulledWorld> fakePulled({bool withPugbackup = true}) async {
      final dir = await Directory.systemTemp.createTemp('wk_pkg_');
      final main = File(p.join(dir.path, 'weird-name.world.gzip'));
      await main.writeAsBytes(const [1, 2, 3, 4]);

      File? pug;
      if (withPugbackup) {
        pug = File(p.join(dir.path, 'weird-name.world.gzip.pugbackup'));
        await pug.writeAsBytes(const [5, 6]);
      }

      return PulledWorld(
        slot: 2,
        tempDir: dir.path,
        mainPath: main.path,
        pugbackupPath: pug?.path,
        bytes: withPugbackup ? 6 : 4,
      );
    }

    test('saves as a folder under canonical names', () async {
      // A folder saved from an oddly-named source must be immediately pushable again.
      final pulled = await fakePulled();
      final dest = p.join(tempDir.path, 'out');

      await PullEnvelope.package(pulled, destination: dest, asZip: false);

      expect(File(p.join(dest, '2.world.gzip')).existsSync(), isTrue);
      expect(File(p.join(dest, '2.world.gzip.pugbackup')).existsSync(), isTrue);
    });

    test('saves as a zip containing both files', () async {
      final pulled = await fakePulled();
      final dest = p.join(tempDir.path, 'world-2.zip');

      await PullEnvelope.package(pulled, destination: dest, asZip: true);

      final zip = File(dest);
      expect(zip.existsSync(), isTrue);
      expect(zip.lengthSync(), greaterThan(0));
    });

    test('cleans up the temp directory afterwards', () async {
      final pulled = await fakePulled();
      await PullEnvelope.package(
        pulled,
        destination: p.join(tempDir.path, 'out2'),
        asZip: false,
      );
      expect(Directory(pulled.tempDir).existsSync(), isFalse);
    });

    test('cleans up even when saving fails', () async {
      final pulled = await fakePulled();
      // Writing a zip *onto an existing directory* cannot succeed. The temp copy must
      // still be cleaned up, or a failed save silently leaks megabytes.
      await expectLater(
        PullEnvelope.package(pulled, destination: tempDir.path, asZip: true),
        throwsA(isA<Object>()),
      );
      expect(Directory(pulled.tempDir).existsSync(), isFalse);
    });

    test('handles a world with no pugbackup', () async {
      final pulled = await fakePulled(withPugbackup: false);
      final dest = p.join(tempDir.path, 'out3');
      await PullEnvelope.package(pulled, destination: dest, asZip: false);

      expect(File(p.join(dest, '2.world.gzip')).existsSync(), isTrue);
      expect(
        File(p.join(dest, '2.world.gzip.pugbackup')).existsSync(),
        isFalse,
      );
    });
  });
}
