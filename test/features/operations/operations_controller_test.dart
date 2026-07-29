import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/features/operations/data/operations_controller.dart';
import 'package:world_keeper/features/operations/domain/local_world.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

import '../../support/fake_target.dart';

/// The controller is where the mutual-exclusion lock and the UI's "busy" flag become the
/// same thing. The original kept those separate — a Rust mutex that actually prevented
/// overlap, and a React flag that greyed out buttons — which meant they could disagree.
void main() {
  const worlds = '/home/steam/Core Keeper/worlds';

  late Directory tempDir;
  late AuditDatabase audit;
  late int sessionId;
  late File worldFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_ops_test');
    audit = AuditDatabaseFactory.inMemory();
    sessionId = await audit.startSession('test');
    worldFile = File('${tempDir.path}${Platform.pathSeparator}0.world.gzip');
    await worldFile.writeAsBytes(List<int>.generate(1024, (i) => i % 256));
  });

  tearDown(() async {
    await audit.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<FakeTarget> healthyTarget() async {
    final t = FakeTarget(
      serviceKind: const SystemdService(unit: 'corekeeper'),
      worldsPath: worlds,
    )..udpLines = ['listening'];
    t.logTail = 'GameID: OPS-1\n';
    final digest = (await sha256.bind(worldFile.openRead()).first).toString();
    t.responses["sha256sum '$worlds/.staging/0.world.gzip'"] = ExecOutput(
      stdout: '$digest  x\n',
      stderr: '',
      exitStatus: 0,
    );
    t.addFile(worlds, '0.world.gzip', size: 100);
    return t;
  }

  ProviderContainer containerWith(ServerTarget? target) {
    final c = ProviderContainer(
      overrides: [
        auditDatabaseProvider.overrideWithValue(audit),
        initialAuditSessionIdProvider.overrideWithValue(sessionId),
        targetProvider.overrideWithValue(target),
        envelopeTimingsProvider.overrideWithValue(EnvelopeTimings.fast),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  LocalWorldCandidate candidate() => LocalWorldCandidate(
    slot: 0,
    slotInferred: true,
    mainPath: worldFile.path,
    mainSize: worldFile.lengthSync(),
  );

  group('not connected', () {
    test('refuses to start anything', () async {
      final c = containerWith(null);
      await expectLater(
        c.read(operationsProvider.notifier).startPush(candidate()),
        throwsA(isA<NotConnectedException>()),
      );
      expect(c.read(operationsProvider).isBusy, isFalse);
    });
  });

  group('push', () {
    test('tracks running, log and result', () async {
      final c = containerWith(await healthyTarget());
      final notifier = c.read(operationsProvider.notifier);

      await notifier.startPush(candidate());
      final state = c.read(operationsProvider);

      expect(state.push.running, isFalse);
      expect(state.push.result?.gameId, 'OPS-1');
      expect(state.push.log.map((p) => p.state), contains(PushState.done));
      expect(state.push.error, isNull);
      expect(state.isBusy, isFalse, reason: 'the lock must be released');
    });

    test('marks busy while running and clears afterwards', () async {
      final target = await healthyTarget();
      final c = containerWith(target);
      final notifier = c.read(operationsProvider.notifier);

      final observed = <OperationKind?>[];
      c.listen(
        operationsProvider,
        (_, next) => observed.add(next.active),
        fireImmediately: true,
      );

      await notifier.startPush(candidate());

      expect(observed.first, isNull);
      expect(observed, contains(OperationKind.push));
      expect(observed.last, isNull);
    });

    test('records the error and releases the lock on failure', () async {
      final target = await healthyTarget()
        ..udpLines = const [];
      final c = containerWith(target);

      await expectLater(
        c.read(operationsProvider.notifier).startPush(candidate()),
        throwsA(isA<OperationException>()),
      );

      final state = c.read(operationsProvider);
      expect(state.push.running, isFalse);
      expect(state.push.error, contains('verification failed'));
      // A failed push must not wedge the app.
      expect(state.isBusy, isFalse);
    });

    test('reports upload progress', () async {
      final c = containerWith(await healthyTarget());
      await c.read(operationsProvider.notifier).startPush(candidate());

      final state = c.read(operationsProvider);
      expect(state.push.transferTotal, 1024);
      expect(state.push.transferred, 1024);
    });

    test('resetPush clears the previous run', () async {
      final c = containerWith(await healthyTarget());
      final notifier = c.read(operationsProvider.notifier);
      await notifier.startPush(candidate());

      notifier.resetPush();
      final state = c.read(operationsProvider);
      expect(state.push.log, isEmpty);
      expect(state.push.result, isNull);
    });
  });

  group('the lock is one source of truth', () {
    test('a second operation is refused while one runs', () async {
      // Slow the push down by making the service take several polls to stop.
      final target = await healthyTarget()
        ..stateAfterStop = null
        ..scriptedStates.addAll(List.filled(20, RunState.running));
      final c = containerWith(target);
      final notifier = c.read(operationsProvider.notifier);

      final push = notifier.startPush(candidate());
      // The busy flag is set synchronously, before the first await inside the envelope.
      expect(c.read(operationsProvider).active, OperationKind.push);

      await expectLater(
        notifier.startPull(0),
        throwsA(isA<OperationBusyException>()),
      );

      await expectLater(push, throwsA(isA<OperationException>()));
      expect(c.read(operationsProvider).isBusy, isFalse);
    });

    test('the refusal names the operation actually holding the lock', () async {
      final target = await healthyTarget()
        ..stateAfterStop = null
        ..scriptedStates.addAll(List.filled(20, RunState.running));
      final c = containerWith(target);
      final notifier = c.read(operationsProvider.notifier);

      final push = notifier.startPush(candidate());
      try {
        await notifier.startRestore('$worlds/.backups/0.x', 0);
        fail('expected a refusal');
      } on OperationBusyException catch (e) {
        expect(e.message, contains('push'));
      }
      await expectLater(push, throwsA(isA<OperationException>()));
    });

    test('operations run fine one after another', () async {
      final c = containerWith(await healthyTarget());
      final notifier = c.read(operationsProvider.notifier);

      await notifier.startPush(candidate());
      expect(c.read(operationsProvider).isBusy, isFalse);

      await notifier.startPull(0);
      expect(c.read(operationsProvider).isBusy, isFalse);
      expect(c.read(operationsProvider).pull.result, isNotNull);
    });
  });

  group('pull', () {
    test('lists worlds and completes', () async {
      final c = containerWith(await healthyTarget());
      final notifier = c.read(operationsProvider.notifier);

      expect((await notifier.listRemoteWorlds()).single.slot, 0);

      await notifier.startPull(0);
      final state = c.read(operationsProvider);
      expect(state.pull.result, isNotNull);
      expect(state.pull.log.map((p) => p.state), contains(PullState.done));
    });

    test('packaging clears the result, since the temp copy is gone', () async {
      final c = containerWith(await healthyTarget());
      final notifier = c.read(operationsProvider.notifier);
      await notifier.startPull(0);

      final pulled = c.read(operationsProvider).pull.result!;
      await notifier.packagePulled(
        pulled: pulled,
        destination: '${tempDir.path}${Platform.pathSeparator}out',
        asZip: false,
      );

      expect(c.read(operationsProvider).pull.result, isNull);
    });
  });

  group('restore', () {
    test('lists backups', () async {
      final target = await healthyTarget()
        ..addFile('$worlds/.backups', '0.2026-07-26_120000');
      final c = containerWith(target);

      final backups = await c.read(operationsProvider.notifier).listBackups();
      expect(backups.single.slot, 0);
    });

    test('a cross-target path is refused and the lock released', () async {
      final c = containerWith(await healthyTarget());

      await expectLater(
        c
            .read(operationsProvider.notifier)
            .startRestore('/elsewhere/backup', 0),
        throwsA(isA<OperationException>()),
      );
      expect(c.read(operationsProvider).isBusy, isFalse);
    });
  });

  group('OperationRun', () {
    test('reports transfer progress as a fraction', () {
      const run = OperationRun<PushState, PushResult>(
        transferred: 512,
        transferTotal: 1024,
      );
      expect(run.transferFraction, 0.5);
      expect(run.hasTransfer, isTrue);
    });

    test('a completed transfer is no longer in progress', () {
      const run = OperationRun<PushState, PushResult>(
        transferred: 1024,
        transferTotal: 1024,
      );
      expect(run.hasTransfer, isFalse);
    });

    test('currentState follows the log', () {
      const run = OperationRun<PushState, PushResult>(
        log: [
          OperationProgress(PushState.uploading),
          OperationProgress(PushState.stopping),
        ],
      );
      expect(run.currentState, PushState.stopping);
      expect(const OperationRun<PushState, PushResult>().currentState, isNull);
    });
  });

  test('an unawaited failure still releases the lock', () async {
    // Fire-and-forget from a button handler is the realistic call shape.
    final target = await healthyTarget()
      ..udpLines = const [];
    final c = containerWith(target);

    unawaited(
      c
          .read(operationsProvider.notifier)
          .startPush(candidate())
          .catchError((Object _) {}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(c.read(operationsProvider).isBusy, isFalse);
  });
}
