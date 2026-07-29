import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/about/presentation/disclaimer_dialog.dart';
import 'package:world_keeper/features/shell/presentation/app_menu.dart';
import 'package:world_keeper/l10n/l10n.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_disclaimer_test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<ProviderContainer> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          theme: WkTheme.dark(),
          home: const DisclaimerGate(
            child: Scaffold(body: Center(child: Text('the app'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(DisclaimerGate)),
    );
  }

  group('first run', () {
    testWidgets('shows the notice before anything else is usable', (
      tester,
    ) async {
      await pumpGate(tester);

      expect(find.text('Before you start'), findsOneWidget);
      expect(
        find.textContaining('no guarantee against data loss'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Keep your own independent backups'),
        findsOneWidget,
      );
    });

    testWidgets('cannot be dismissed by tapping outside it', (tester) async {
      // One way out, and it is the one that records having read it.
      await pumpGate(tester);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Before you start'), findsOneWidget);
    });

    testWidgets('offers no escape but acknowledgement', (tester) async {
      await pumpGate(tester);
      expect(find.text('Close'), findsNothing);
      expect(find.text('I understand'), findsOneWidget);
    });

    testWidgets('acknowledging closes it and remembers', (tester) async {
      final container = await pumpGate(tester);

      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();

      expect(find.text('Before you start'), findsNothing);
      expect(
        container.read(disclaimerAcknowledgedProvider).asData?.value,
        isTrue,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(disclaimerStorageKey), isTrue);
    });
  });

  group('afterwards', () {
    testWidgets('does not show again', (tester) async {
      SharedPreferences.setMockInitialValues({disclaimerStorageKey: true});
      await pumpGate(tester);

      expect(find.text('Before you start'), findsNothing);
      expect(find.text('the app'), findsOneWidget);
    });

    testWidgets('a bumped version shows it again', (tester) async {
      // The `.v1` suffix is the mechanism: an acknowledgement of the old text is not an
      // acknowledgement of a materially changed one.
      SharedPreferences.setMockInitialValues({
        'wk.disclaimer-acknowledged.v0': true,
      });
      await pumpGate(tester);

      expect(find.text('Before you start'), findsOneWidget);
    });

    testWidgets('can be re-read from the menu, and is dismissible then', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({disclaimerStorageKey: true});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          ],
          child: MaterialApp(
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            theme: WkTheme.dark(),
            home: Scaffold(appBar: AppBar(actions: const [AppMenu()])),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.warning_amber));
      await tester.pumpAndSettle();
      expect(find.text('Before you start'), findsOneWidget);

      // Re-reading is not re-consenting, so this one has an ordinary way out.
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Before you start'), findsNothing);
    });
  });
}
