import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:world_keeper/app/app.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/about/presentation/disclaimer_dialog.dart';
import 'package:world_keeper/features/shell/presentation/app_menu.dart';
import 'package:world_keeper/l10n/l10n.dart';

import '../support/l10n.dart';

/// The wiring between "a language is selected" and "the app is in that language".
///
/// The ARB files are checked against each other in `arb_test.dart`; this is the other
/// half — that a locale actually reaches the widgets, and that choosing one is a thing a
/// person can do and undo.
void main() {
  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_l10n_test');
    db = AuditDatabaseFactory.inMemory();
    sessionId = await db.startSession('test');
    SharedPreferences.setMockInitialValues({disclaimerStorageKey: true});
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<ProviderContainer> pumpIn(
    WidgetTester tester, {
    Locale? locale,
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
        auditDatabaseProvider.overrideWithValue(db),
        initialAuditSessionIdProvider.overrideWithValue(sessionId),
      ],
    );
    addTearDown(container.dispose);

    if (locale != null) {
      await container.read(localeProvider.notifier).select(locale);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WorldKeeperApp(),
      ),
    );
    await tester.pump();
    return container;
  }

  group('the app renders in the selected language', () {
    testWidgets('English', (tester) async {
      await pumpIn(tester, locale: const Locale('en'));

      expect(find.text('Discovery'), findsWidgets);
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('French', (tester) async {
      await pumpIn(tester, locale: const Locale('fr'));

      // Navigation, a button and the connection status: three separate files, so this
      // fails if the delegate reached only the widget that happened to be tested.
      expect(find.text('Détection'), findsWidgets);
      expect(find.text('Connecter'), findsOneWidget);
      expect(find.text('Déconnecté'), findsWidgets);

      expect(find.text('Discovery'), findsNothing);
    });

    testWidgets('an unsupported device language falls back to English', (
      tester,
    ) async {
      // Material's resolution picks the first supported locale when nothing matches, and
      // English is deliberately first in `supportedLocales` for exactly this.
      await pumpIn(tester, locale: const Locale('de'));

      expect(find.text('Connect'), findsOneWidget);
    });
  });

  group('choosing a language', () {
    testWidgets('the cycler walks system → English → French → system', (
      tester,
    ) async {
      final container = await pumpIn(tester);
      final controller = container.read(localeProvider.notifier);

      expect(
        container.read(localeProvider),
        isNull,
        reason: 'starts on the device',
      );

      await controller.cycle();
      expect(container.read(localeProvider)?.languageCode, 'en');

      await controller.cycle();
      expect(container.read(localeProvider)?.languageCode, 'fr');

      await controller.cycle();
      expect(
        container.read(localeProvider),
        isNull,
        reason: 'the way back to the device setting must not be a dead end',
      );
    });

    testWidgets('the choice survives a restart', (tester) async {
      final container = await pumpIn(tester);
      await container.read(localeProvider.notifier).select(const Locale('fr'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wk.locale'), 'fr');

      // A second container reads what the first wrote, which is what a relaunch does.
      final restarted = ProviderContainer(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          auditDatabaseProvider.overrideWithValue(db),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
        ],
      );
      addTearDown(restarted.dispose);

      restarted.read(localeProvider);
      await tester.pump();
      expect(restarted.read(localeProvider)?.languageCode, 'fr');
    });

    testWidgets('a stored language the app no longer ships is ignored', (
      tester,
    ) async {
      // Dropping a language should return those users to their device setting, not leave
      // them looking at a locale nothing can resolve.
      SharedPreferences.setMockInitialValues({
        disclaimerStorageKey: true,
        'wk.locale': 'eo',
      });

      final container = await pumpIn(tester);
      container.read(localeProvider);
      await tester.pump();

      expect(container.read(localeProvider), isNull);
    });
  });

  group('the language menu', () {
    test('names each language in that language, never in the current one', () {
      final english = l10nFor('en');
      final french = l10nFor('fr');

      // The label is identical whichever language the interface is in — that is the
      // point of an endonym.
      expect(languageLabel(english, const Locale('fr')), 'Français');
      expect(languageLabel(french, const Locale('fr')), 'Français');
      expect(languageLabel(english, const Locale('en')), 'English');
      expect(languageLabel(french, const Locale('en')), 'English');

      // "System" is the exception: it names a setting rather than a language.
      expect(languageLabel(english, null), 'System');
      expect(languageLabel(french, null), 'Système');
    });

    testWidgets('is reachable from the desktop chrome', (tester) async {
      await pumpIn(tester, locale: const Locale('en'));

      // The tooltip names the *current* language, same as the theme button names the
      // current theme — a cycler that announces where it will take you is unreadable
      // once there are three states.
      expect(
        find.byTooltip('Language: English'),
        findsOneWidget,
        reason:
            'the theme cycler shipped for three phases with no UI; not again',
      );
    });
  });

  group('the language button', () {
    // Deliberately just the menu, not the whole app: this is about the control, and a
    // full shell drags seven mounted screens and their polling providers into a test
    // whose subject is one button.
    Future<ProviderContainer> pumpMenu(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            home: Scaffold(body: Center(child: AppMenu())),
          ),
        ),
      );
      await tester.pump();
      return container;
    }

    Finder languageButton() => find.ancestor(
      of: find.byType(LanguageGlyph),
      matching: find.byType(IconButton),
    );

    testWidgets('every press changes what the button shows', (tester) async {
      // The bug this exists for: the control worked and looked broken. It was the
      // translate glyph in all three states, so the only feedback was a tooltip — and
      // the first press moves system → English, which on an English machine changes
      // nothing else on screen either. Three presses, three different faces.
      final container = await pumpMenu(tester);

      expect(find.byIcon(Icons.translate_outlined), findsOneWidget);
      expect(find.text('EN'), findsNothing);

      await tester.tap(languageButton());
      await tester.pump();
      expect(container.read(localeProvider)?.languageCode, 'en');
      expect(find.text('EN'), findsOneWidget);
      expect(find.byIcon(Icons.translate_outlined), findsNothing);

      await tester.tap(languageButton());
      await tester.pump();
      expect(container.read(localeProvider)?.languageCode, 'fr');
      expect(find.text('FR'), findsOneWidget);

      await tester.tap(languageButton());
      await tester.pump();
      expect(container.read(localeProvider), isNull);
      expect(
        find.byIcon(Icons.translate_outlined),
        findsOneWidget,
        reason: 'back to following the device',
      );
    });

    testWidgets('the glyph means "following the device", not "no language"', (
      tester,
    ) async {
      await pumpMenu(tester);

      // Hovering is the only way to reach a tooltip, so the words have to be there for
      // the people who do — and for a screen reader, which reads it.
      expect(find.byTooltip('Language: System'), findsOneWidget);
    });
  });
}
