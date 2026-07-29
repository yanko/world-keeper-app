import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:world_keeper/app/app.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/about/presentation/disclaimer_dialog.dart';
import 'package:world_keeper/features/shell/presentation/shortcuts.dart';

void main() {
  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_shortcuts_test');
    db = AuditDatabaseFactory.inMemory();
    sessionId = await db.startSession('test');
    // Otherwise the first-run notice sits over the shell and eats the keystrokes.
    SharedPreferences.setMockInitialValues({disclaimerStorageKey: true});
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          auditDatabaseProvider.overrideWithValue(db),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
        ],
        child: const WorldKeeperApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex!;

  group('navigation', () {
    testWidgets('Ctrl+N jumps to the Nth destination', (tester) async {
      await pumpApp(tester);
      expect(selectedIndex(tester), 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(
        selectedIndex(tester),
        2,
        reason: 'Ctrl+3 is the third destination',
      );
    });

    testWidgets('an unbound digit changes nothing', (tester) async {
      // There are seven destinations, so Ctrl+9 must be inert rather than clamping to the
      // last one — a shortcut that silently does something else is worse than one that
      // does nothing.
      await pumpApp(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(selectedIndex(tester), 0);
    });

    testWidgets('a bare digit does nothing — no accidental navigation', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();

      expect(selectedIndex(tester), 0);
    });
  });

  group('help', () {
    testWidgets('F1 opens the shortcut list', (tester) async {
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();

      expect(find.text('Keyboard shortcuts'), findsWidgets);
    });

    testWidgets('the list documents every binding that exists', (tester) async {
      // The help and the bindings are built from one list precisely so this holds.
      final shortcuts = buildAppShortcuts(
        destinationLabels: const ['Stats', 'Discovery', 'Library'],
        helpDescription: 'Keyboard shortcuts',
        onSelect: (_) {},
        onHelp: () {},
      );

      expect(
        shortcuts.map((s) => s.description),
        containsAll(['Stats', 'Library']),
      );
      expect(shortcuts.last.keysLabel, 'F1');
      expect(
        bindingsOf(shortcuts).length,
        greaterThanOrEqualTo(shortcuts.length),
      );
    });

    testWidgets('says plainly that nothing destructive is bound', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Nothing destructive has a shortcut'),
        findsOneWidget,
      );
    });
  });

  group('bindings', () {
    test('caps at nine destinations rather than running out of digits', () {
      final shortcuts = buildAppShortcuts(
        destinationLabels: List.generate(12, (i) => 'Destination $i'),
        helpDescription: 'Keyboard shortcuts',
        onSelect: (_) {},
        onHelp: () {},
      );
      // Nine digits plus F1.
      expect(shortcuts, hasLength(10));
    });

    test('binds both Ctrl and Cmd so one build serves both desktops', () {
      final shortcuts = buildAppShortcuts(
        destinationLabels: const ['Stats'],
        helpDescription: 'Keyboard shortcuts',
        onSelect: (_) {},
        onHelp: () {},
      );
      expect(shortcuts.first.activators, hasLength(2));
    });

    test('no destructive action is bound', () {
      // The design decision, asserted rather than left to a comment.
      final shortcuts = buildAppShortcuts(
        helpDescription: 'Keyboard shortcuts',
        destinationLabels: const [
          'Stats',
          'Discovery',
          'Library',
          'Push',
          'Pull',
          'Terminal',
          'Audit',
        ],
        onSelect: (_) {},
        onHelp: () {},
      );
      // Navigating *to* Push is fine; there is no binding that performs one.
      expect(
        shortcuts.map((s) => s.description),
        everyElement(isNot(anyOf(contains('Disconnect'), contains('Clear')))),
      );
    });
  });
}
