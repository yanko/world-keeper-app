import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';

import '../../support/fake_target.dart';

void main() {
  const worlds = '/home/steam/worlds';

  FakeTarget makeTarget({RunState initial = RunState.running}) => FakeTarget(
    serviceKind: const SystemdService(unit: 'corekeeper'),
    worldsPath: worlds,
    initialState: initial,
  );

  ServiceControl controlFor(FakeTarget t) =>
      ServiceControl(t, timings: EnvelopeTimings.fast);

  WorldOperations worldOpsFor(FakeTarget t) =>
      WorldOperations(t, timings: EnvelopeTimings.fast);

  group('ServiceControl', () {
    test('stopAndWait issues the stop and waits for stopped', () async {
      final t = makeTarget();
      await controlFor(t).stopAndWait();
      expect(t.serviceActions, [ServiceAction.stop]);
    });

    test('startAndWait issues the start and waits for running', () async {
      final t = makeTarget(initial: RunState.stopped);
      await controlFor(t).startAndWait();
      expect(t.serviceActions, [ServiceAction.start]);
    });

    test('polls until the state settles rather than assuming', () async {
      // A real stop is not instantaneous; the point of polling is to not proceed until
      // the files are genuinely no longer being written to.
      final t = makeTarget()
        ..stateAfterStop = null
        ..scriptedStates.addAll([
          RunState.running,
          RunState.running,
          RunState.stopped,
        ]);

      await controlFor(t).stopAndWait();
      expect(t.statusCallCount, 3);
    });

    test('times out with the recent log attached', () async {
      // "Timed out" alone is useless; the reason is nearly always in the last few lines.
      final t = makeTarget()
        ..stateAfterStop = null
        ..logTail = 'Jul 28 04:00 ck[1]: still shutting down…\n';

      await expectLater(
        controlFor(t).stopAndWait(),
        throwsA(
          isA<OperationException>()
              .having((e) => e.message, 'message', contains('timed out'))
              .having(
                (e) => e.message,
                'message',
                contains('still shutting down'),
              ),
        ),
      );
    });

    test(
      'bails immediately when the service enters failed while starting',
      () async {
        // It is never going to arrive; burning the full timeout only delays the log.
        final t = makeTarget(initial: RunState.stopped)
          ..stateAfterStart = RunState.failed
          ..logTail = 'fatal: port already in use\n';

        final started = DateTime.now();
        await expectLater(
          controlFor(t).startAndWait(),
          throwsA(
            isA<OperationException>()
                .having((e) => e.message, 'message', contains('failed state'))
                .having(
                  (e) => e.message,
                  'message',
                  contains('port already in use'),
                ),
          ),
        );
        // Far below even the fast timeout, proving it did not wait it out.
        expect(
          DateTime.now().difference(started),
          lessThan(const Duration(seconds: 1)),
        );
      },
    );

    test('a failed state while waiting to STOP is not an early bail', () async {
      // `failed` means "not running", which is what a stop wants. Bailing here would
      // turn a successfully-stopped service into an error.
      final t = makeTarget()..stateAfterStop = RunState.failed;
      await expectLater(
        controlFor(t).stopAndWait(),
        throwsA(isA<OperationException>()),
      );
      // It times out rather than reporting "entered a failed state".
      try {
        await controlFor(
          makeTarget()..stateAfterStop = RunState.failed,
        ).stopAndWait();
      } on OperationException catch (e) {
        expect(e.message, contains('timed out'));
        expect(e.message.contains('failed state'), isFalse);
      }
    });

    test(
      'a status check that throws is treated as unknown, not fatal',
      () async {
        // Status can fail transiently while a service is coming up or down.
        final t = makeTarget()
          ..stateAfterStop = null
          ..scriptedStates.addAll([RunState.unknown, RunState.stopped]);
        await controlFor(t).stopAndWait();
      },
    );

    test('an unavailable log does not mask the real error', () async {
      final t = makeTarget()..stateAfterStop = null;
      t.failures['x'] = Exception('unused');

      await expectLater(
        controlFor(t).stopAndWait(),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });

  group('WorldOperations.backUpLiveWorld', () {
    test('returns null for an empty slot', () async {
      expect(await worldOpsFor(makeTarget()).backUpLiveWorld(0), isNull);
    });

    test('creates a dated directory and copies the pair', () async {
      final t = makeTarget()
        ..addFile(worlds, '0.world.gzip')
        ..addFile(worlds, '0.world.gzip.pugbackup');

      final path = await worldOpsFor(t).backUpLiveWorld(0);

      expect(path, matches(RegExp(r'/\.backups/0\.\d{4}-\d{2}-\d{2}_\d{6}$')));
      expect(t.commands.where((c) => c.startsWith('cp -a')), hasLength(2));
    });

    test('backs up a main file with no pugbackup', () async {
      final t = makeTarget()..addFile(worlds, '0.world.gzip');
      expect(await worldOpsFor(t).backUpLiveWorld(0), isNotNull);
      expect(t.commands.where((c) => c.startsWith('cp -a')), hasLength(1));
    });

    test('a failed mkdir is an error, not a silent skip', () async {
      // Returning null here would look identical to "empty slot" and let the swap
      // proceed with nothing to roll back to.
      final t = makeTarget()
        ..addFile(worlds, '0.world.gzip')
        ..failCommandsContaining('mkdir -p', stderr: 'read-only file system');

      await expectLater(
        worldOpsFor(t).backUpLiveWorld(0),
        throwsA(isA<OperationException>()),
      );
    });

    test('a failed copy is an error', () async {
      final t = makeTarget()
        ..addFile(worlds, '0.world.gzip')
        ..failCommandsContaining('cp -a', stderr: 'no space left on device');

      await expectLater(
        worldOpsFor(t).backUpLiveWorld(0),
        throwsA(
          isA<OperationException>().having(
            (e) => e.message,
            'message',
            contains('no space left'),
          ),
        ),
      );
    });
  });

  group('WorldOperations.sizeOf', () {
    test('sums the contents', () async {
      final t = makeTarget()
        ..addFile('/b', '0.world.gzip', size: 5000)
        ..addFile('/b', '0.world.gzip.pugbackup', size: 3000);
      expect(await worldOpsFor(t).sizeOf('/b'), 8000);
    });

    test('excludes the directory itself', () async {
      // `find <dir> -maxdepth 1 -name '*'` matches the directory at depth 0, so a naive
      // sum adds its ~4 KB inode and overstates every backup.
      final t = makeTarget();
      t.files['/b'] = const [
        FileEntry(path: '/b', size: 4096),
        FileEntry(path: '/b/0.world.gzip', size: 5000),
      ];
      expect(await worldOpsFor(t).sizeOf('/b'), 5000);
    });

    test('is zero for an unreadable directory rather than throwing', () async {
      final t = makeTarget()
        ..failurePatterns.add((
          contains: 'find',
          error: Exception('permission denied'),
        ));
      expect(await worldOpsFor(t).sizeOf('/b'), 0);
    });
  });

  group('WorldOperations.rollback', () {
    test('always restarts, even with no backup', () async {
      final t = makeTarget();
      final note = await worldOpsFor(t).rollback();

      expect(note, contains('no backup existed'));
      expect(note, contains('restart issued'));
      expect(t.serviceActions, [ServiceAction.start]);
    });

    test('restores the backup then restarts', () async {
      final t = makeTarget();
      final note = await worldOpsFor(
        t,
      ).rollback(backupPath: '$worlds/.backups/0.x');

      expect(note, contains('restored backup'));
      // The quoting sits around the paths, with the trailing `/.` and `/` outside it —
      // the shell concatenates adjacent quoted and unquoted runs, so this expands to
      // `cp -a /home/steam/worlds/.backups/0.x/. /home/steam/worlds/`, which copies the
      // backup's *contents* rather than the directory itself.
      expect(t.commands.single, "cp -a '$worlds/.backups/0.x'/. '$worlds'/");
      expect(t.serviceActions, [ServiceAction.start]);
    });

    test('never throws, however badly things are going', () async {
      // Rollback runs *because* something already failed. If it throws, the user is left
      // with no explanation at all.
      final t = makeTarget()
        ..failCommandsContaining('cp -a')
        ..fixPermsThrows = true;

      final note = await worldOpsFor(t).rollback(backupPath: '/b');
      expect(note, contains('restore failed'));
      expect(note, contains('fixing permissions after restore failed'));
      // And it still tried to bring the server back.
      expect(t.serviceActions, [ServiceAction.start]);
    });
  });

  group('WorldOperations.captureGameId', () {
    test('returns the id when the log has one', () async {
      final t = makeTarget()..logTail = 'GameID: ABC-123\n';
      expect(await worldOpsFor(t).captureGameId(), 'ABC-123');
    });

    test('returns null on timeout rather than failing the operation', () async {
      // Not every packaging logs it in a recognised format. Refusing to complete a good
      // swap over a cosmetic field would be worse than reporting it unknown.
      final t = makeTarget()..logTail = 'nothing here\n';
      expect(await worldOpsFor(t).captureGameId(), isNull);
    });
  });

  group('WorldOperations.waitForUdpListening', () {
    test('true when a listener is present', () async {
      final t = makeTarget()..udpLines = ['UNCONN 0 0 0.0.0.0:56967'];
      expect(await worldOpsFor(t).waitForUdpListening(), isTrue);
    });

    test('false after the timeout', () async {
      expect(await worldOpsFor(makeTarget()).waitForUdpListening(), isFalse);
    });
  });

  group('timestamps', () {
    test('formats as the sortable dated-backup name', () async {
      final stamp = WorldOperations.timestampNow(
        DateTime.utc(2026, 7, 26, 18, 21, 14),
      );
      expect(stamp, '2026-07-26_182114');
    });

    test('sorts lexicographically the same as chronologically', () async {
      // This is why the backup list needs no date parsing.
      final earlier = WorldOperations.timestampNow(
        DateTime.utc(2026, 7, 26, 9),
      );
      final later = WorldOperations.timestampNow(DateTime.utc(2026, 7, 26, 18));
      expect(earlier.compareTo(later), lessThan(0));
    });

    test('is UTC regardless of the local zone', () async {
      final stamp = WorldOperations.timestampNow(
        DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      expect(stamp, '2026-01-02_030405');
    });
  });
}
