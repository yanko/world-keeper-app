import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/operations/data/operation_journal.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';
import 'package:world_keeper/features/operations/presentation/recovery_dialog.dart';
import 'package:world_keeper/l10n/l10n.dart';

import '../../support/fake_target.dart';

/// Recovering from an operation that never finished.
///
/// The failure this exists for: a push is running, the phone is backgrounded, Android
/// freezes the process between "stop the service" and "start it again", and the server
/// stays down with nothing left running to notice.
void main() {
  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;
  late OperationJournal journal;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_recovery_test');
    db = AuditDatabaseFactory.inMemory();
    sessionId = await db.startSession('test');
    journal = OperationJournal(AppPaths.forTesting(tempDir));
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  final marker = InterruptedOperation(
    profileId: 'p1',
    kind: OperationKind.push,
    phase: 'copying',
    startedAt: DateTime.utc(2026, 7, 29, 20, 15),
    slot: 0,
  );

  Future<FakeTarget> pump(
    WidgetTester tester, {
    RunState status = RunState.stopped,
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final target = FakeTarget(
      serviceKind: const SystemdService(unit: 'corekeeper'),
      initialState: status,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          auditDatabaseProvider.overrideWithValue(db),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
          targetProvider.overrideWithValue(target),
        ],
        child: MaterialApp(
          theme: WkTheme.dark(),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showRecoveryDialog(context, ref, marker),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return target;
  }

  testWidgets('it says what was interrupted and where', (tester) async {
    // "Interrupted while copying the world in" and "interrupted while starting it again"
    // call for very different amounts of worry, so the phase is named.
    await pump(tester);

    expect(find.text('An operation was interrupted'), findsOneWidget);
    expect(find.textContaining('push'), findsOneWidget);
    expect(find.textContaining('copying'), findsOneWidget);
  });

  testWidgets('it asks the server rather than assuming the worst', (
    tester,
  ) async {
    // The marker says an operation was interrupted, not that the service is down. Those
    // are different claims and only the host can settle the second — the process may have
    // been killed a millisecond after the start command landed.
    final target = await pump(tester, status: RunState.running);

    expect(target.statusCallCount, greaterThanOrEqualTo(1));
    expect(
      find.text('The service is running — nothing to do.'),
      findsOneWidget,
    );
    expect(
      find.text('Start the server'),
      findsNothing,
      reason: 'nothing to offer when it is already up',
    );
  });

  testWidgets('a stopped service gets a start button', (tester) async {
    await pump(tester);

    expect(find.text('The service is stopped.'), findsOneWidget);
    expect(find.text('Start the server'), findsOneWidget);
  });

  testWidgets('it points at the Library rather than resuming the swap', (
    tester,
  ) async {
    // Deliberately not a resume: re-running a half-finished swap without knowing which
    // half finished is how a world gets overwritten with a partial copy.
    await pump(tester);

    expect(find.textContaining('World Library'), findsOneWidget);
  });

  /// Opens a marker, and lets the write actually happen.
  ///
  /// `testWidgets` runs its body against a **fake clock**: timers are controlled by
  /// `pump`, and real asynchronous work — file I/O included — never completes unless it
  /// is given a turn on the real event loop. Awaiting `File.writeAsString` directly in a
  /// widget test does not fail, it simply never returns, and the test hangs until the
  /// suite's timeout with no indication of where. `runAsync` is the turn.
  Future<void> openMarker(WidgetTester tester) => tester.runAsync(
    () => journal.record(
      profileId: 'p1',
      kind: OperationKind.push,
      progress: const OperationProgress(PushState.stopping),
    ),
  );

  Future<InterruptedOperation?> readMarker(WidgetTester tester) async =>
      // `runAsync` infers a non-nullable T from the callback, so the null the journal
      // returns for "no marker" has to be carried out in a wrapper.
      (await tester.runAsync(() async => [await journal.read()]))!.single;

  /// Gives the widget's own file I/O a turn, then rebuilds.
  ///
  /// The dialog deletes the marker before it closes, and that delete is subject to
  /// exactly the same fake-clock rule as the writes above.
  Future<void> settleRealWork(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('starting the server clears the marker', (tester) async {
    await openMarker(tester);
    expect(await readMarker(tester), isNotNull);

    final target = await pump(tester);

    await tester.tap(find.text('Start the server'));
    await settleRealWork(tester);

    expect(target.serviceActions, contains(ServiceAction.start));
    expect(
      await readMarker(tester),
      isNull,
      reason: 'the app is no longer responsible for a stopped server',
    );
  });

  testWidgets('dismissing clears it too, even with the service down', (
    tester,
  ) async {
    // A prompt that cannot be closed is one people learn to fear rather than read — and
    // the Terminal and the Library are both reasonable places to go first.
    await openMarker(tester);

    await pump(tester);
    await tester.tap(find.text('Dismiss'));
    await settleRealWork(tester);

    expect(await readMarker(tester), isNull);
    expect(find.text('An operation was interrupted'), findsNothing);
  });
}
