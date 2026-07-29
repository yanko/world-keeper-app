import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';
import 'package:world_keeper/features/operations/presentation/stepper.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// The stepper is the signature element and the one thing a user watches during a
/// destructive remote operation, so its layout is asserted at both ends of the range
/// rather than assumed.
///
/// Structural assertions rather than pixel goldens: fonts are not yet vendored, so
/// goldens would be comparing whatever monospace face each machine happens to have and
/// would fail everywhere but the machine that generated them. What matters here is which
/// layout is chosen and which stage is marked how — both of which are checkable exactly.
void main() {
  const steps = <StepDef<PushState>>[
    StepDef(PushState.uploading, 'Upload'),
    StepDef(PushState.checkingService, 'Check'),
    StepDef(PushState.stopping, 'Stop'),
    StepDef(PushState.backingUp, 'Back up'),
    StepDef(PushState.copying, 'Copy in'),
    StepDef(PushState.fixingPerms, 'Perms'),
    StepDef(PushState.starting, 'Start'),
    StepDef(PushState.capturingGameId, 'Game id'),
    StepDef(PushState.verifying, 'Verify'),
  ];

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    List<PushProgress> log, {
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        theme: WkTheme.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: Scaffold(
              body: SingleChildScrollView(
                child: OperationStepper<PushState>(
                  steps: steps,
                  log: log,
                  doneState: PushState.done,
                  failedStates: const [PushState.rollingBack, PushState.failed],
                  failedBanner: 'Rolled back',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<PushProgress> upTo(PushState state) {
    final order = [
      PushState.uploading,
      PushState.checkingService,
      PushState.stopping,
      PushState.backingUp,
      PushState.copying,
      PushState.fixingPerms,
      PushState.starting,
      PushState.capturingGameId,
      PushState.verifying,
    ];
    final idx = order.indexOf(state);
    return [for (var i = 0; i <= idx; i++) OperationProgress(order[i])];
  }

  group('desktop (1440 px)', () {
    testWidgets('lays the pipeline out horizontally', (tester) async {
      await pumpAt(tester, const Size(1440, 900), upTo(PushState.copying));

      // All nine labels visible at once, no scrolling required.
      for (final s in steps) {
        expect(find.text(s.label), findsOneWidget);
      }

      // Horizontal means the first and last nodes differ in x, not y.
      final first = tester.getCenter(find.text('Upload'));
      final last = tester.getCenter(find.text('Verify'));
      expect(last.dx, greaterThan(first.dx));
      expect((last.dy - first.dy).abs(), lessThan(2));
    });

    testWidgets('does not overflow at nine stages', (tester) async {
      await pumpAt(tester, const Size(1440, 900), upTo(PushState.verifying));
      expect(tester.takeException(), isNull);
    });
  });

  group('phone (360 px)', () {
    testWidgets('switches to a vertical timeline', (tester) async {
      await pumpAt(tester, const Size(360, 800), upTo(PushState.copying));

      // Vertical means stages differ in y, not x — and every label stays fully readable
      // rather than being squeezed into a 40 px column or hidden behind a scrollbar.
      final first = tester.getCenter(find.text('Upload'));
      final last = tester.getCenter(find.text('Verify'));
      expect(last.dy, greaterThan(first.dy));
      expect((last.dx - first.dx).abs(), lessThan(2));
    });

    testWidgets('shows every label without truncation', (tester) async {
      await pumpAt(tester, const Size(360, 800), upTo(PushState.stopping));
      for (final s in steps) {
        expect(find.text(s.label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('gives the readout real width', (tester) async {
      await pumpAt(tester, const Size(360, 800), [
        ...upTo(PushState.stopping),
        const OperationProgress(
          PushState.stopping,
          detail: 'waiting for the service to settle',
        ),
      ]);
      expect(find.text('waiting for the service to settle'), findsOneWidget);
    });
  });

  group('stage status', () {
    testWidgets('marks completed, current and pending correctly', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1440, 900), upTo(PushState.copying));

      // Four completed stages before "Copy in" → four check marks.
      expect(find.byIcon(Icons.check), findsNWidgets(4));
      // The current stage spins.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Nothing has failed.
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('a completed run marks every stage done', (tester) async {
      await pumpAt(tester, const Size(1440, 900), [
        ...upTo(PushState.verifying),
        const OperationProgress(PushState.done, ok: true),
      ]);

      expect(find.byIcon(Icons.check), findsNWidgets(steps.length));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failure pins the error to the stage it happened in', (
      tester,
    ) async {
      // This is the whole point of the element: not "it broke" but "it broke *here*".
      await pumpAt(tester, const Size(1440, 900), [
        ...upTo(PushState.starting),
        const OperationProgress(
          PushState.rollingBack,
          detail: 'service failed',
        ),
        const OperationProgress(
          PushState.failed,
          detail: 'service failed',
          ok: false,
        ),
      ]);

      // Six stages completed before Start, which is marked in error.
      expect(find.byIcon(Icons.check), findsNWidgets(6));
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('ROLLED BACK'), findsOneWidget);
      expect(find.text('service failed'), findsOneWidget);
    });

    testWidgets('a failure does not erase the progress already made', (
      tester,
    ) async {
      // rollingBack/failed are not stages in `steps`; using the raw last log entry to
      // find the current stage would reset everything to pending and hide how far it got.
      await pumpAt(tester, const Size(1440, 900), [
        ...upTo(PushState.verifying),
        const OperationProgress(PushState.failed, ok: false),
      ]);
      expect(find.byIcon(Icons.check), findsNWidgets(8));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('an empty log shows nothing as started', (tester) async {
      await pumpAt(tester, const Size(1440, 900), const []);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('respects reduced motion', (tester) async {
      // The spinner becomes a static glyph rather than disappearing, so the current
      // stage is still identifiable without animation.
      await pumpAt(
        tester,
        const Size(1440, 900),
        upTo(PushState.copying),
        disableAnimations: true,
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('labels stages for screen readers', (tester) async {
      // A coloured ring conveys nothing without sight.
      await pumpAt(tester, const Size(1440, 900), upTo(PushState.copying));
      expect(find.bySemanticsLabel('Step done'), findsWidgets);
      expect(find.bySemanticsLabel('Step running'), findsOneWidget);
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          theme: WkTheme.dark(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: OperationStepper<PushState>(
                    steps: steps,
                    log: upTo(PushState.copying),
                    doneState: PushState.done,
                    failedStates: const [PushState.failed],
                    failedBanner: 'Rolled back',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('shorter pipelines', () {
    testWidgets('renders pull\'s four stages', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          theme: WkTheme.dark(),
          home: const Scaffold(
            body: OperationStepper<PullState>(
              steps: [
                StepDef(PullState.checkingService, 'Check'),
                StepDef(PullState.stopping, 'Stop'),
                StepDef(PullState.downloading, 'Download'),
                StepDef(PullState.starting, 'Restart'),
              ],
              log: [
                OperationProgress(PullState.checkingService),
                OperationProgress(PullState.stopping),
                OperationProgress(PullState.downloading),
              ],
              doneState: PullState.done,
              failedStates: [PullState.failed],
              failedBanner: 'Failed',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Download'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });
  });
}
