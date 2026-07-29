import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/app.dart';
import 'package:world_keeper/app/app_info.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/about/presentation/about_dialog.dart';
import 'package:world_keeper/features/shell/presentation/app_menu.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// The reference is long by design, so most of it starts below the fold.
Future<void> scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_about_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> openAbout(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
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
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWorldKeeperAbout(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('desktop', () {
    testWidgets('names the app and the build', (tester) async {
      await openAbout(tester, const Size(1440, 900));

      expect(find.text('About $appName'), findsOneWidget);
      expect(find.text('Version $appVersion'), findsOneWidget);
    });

    testWidgets('shows the resolved on-disk paths, not a description of them', (
      tester,
    ) async {
      // "Somewhere in AppData" is not an answer anyone can act on.
      await openAbout(tester, const Size(1440, 900));

      expect(find.textContaining(AppPaths.configFileName), findsOneWidget);
      expect(find.textContaining(AppPaths.databaseFileName), findsOneWidget);
      expect(find.textContaining('keys'), findsWidgets);
    });

    testWidgets('lists every command group', (tester) async {
      await openAbout(tester, const Size(1440, 900));

      for (final group in [
        'Discovery',
        'Listing files',
        'Server stats',
        'Push a world',
        'Pull a world',
        'Restore from a backup (World Library)',
        'Terminal',
        'One-time setup',
      ]) {
        await scrollTo(tester, group);
        expect(find.text(group), findsOneWidget, reason: group);
      }
    });

    testWidgets('says it is showing placeholders while disconnected', (
      tester,
    ) async {
      await openAbout(tester, const Size(1440, 900));
      expect(find.textContaining('Not connected'), findsOneWidget);
    });

    testWidgets('groups start collapsed — the commands are opt-in detail', (
      tester,
    ) async {
      await openAbout(tester, const Size(1440, 900));
      await scrollTo(tester, 'Discovery');
      expect(find.textContaining('cat /etc/os-release'), findsNothing);

      await tester.tap(find.text('Discovery'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cat /etc/os-release'), findsOneWidget);
    });

    testWidgets('copy all puts the whole reference on the clipboard', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await openAbout(tester, const Size(1440, 900));
      await tester.tap(find.text('Copy all'));
      await tester.pumpAndSettle();

      expect(copied, isNotNull);
      expect(copied, contains('## Discovery'));
      expect(copied, contains('## Restore from a backup (World Library)'));
      expect(copied, contains('cat /proc/meminfo'));
    });
  });

  group('phone', () {
    testWidgets('goes full screen rather than an inset box', (tester) async {
      await openAbout(tester, const Size(360, 800));

      expect(find.byType(Dialog), findsOneWidget);
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.insetPadding, EdgeInsets.zero, reason: 'Dialog.fullscreen');
    });

    testWidgets('lays out without overflowing', (tester) async {
      await openAbout(tester, const Size(360, 800));
      expect(tester.takeException(), isNull);

      // Long absolute paths and long command strings are the two things most likely to
      // burst a 360 px dialog; both are reachable and neither throws.
      await scrollTo(tester, 'Discovery');
      await tester.tap(find.text('Discovery'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('AppMenu', () {
    Future<void> pumpMenu(WidgetTester tester, {required bool compact}) async {
      tester.view.physicalSize = compact
          ? const Size(360, 800)
          : const Size(1440, 900);
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
            home: Scaffold(
              appBar: AppBar(actions: [AppMenu(compact: compact)]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cycles the theme system → light → dark → system', (
      tester,
    ) async {
      // The controller had a cycle() from the start and nothing ever called it — this is
      // the button that finally does.
      await pumpMenu(tester, compact: false);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppMenu)),
      );

      expect(container.read(themeModeProvider), ThemeMode.system);

      for (final expected in [
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
      ]) {
        await tester.tap(
          find.byIcon(themeIcon(container.read(themeModeProvider))),
        );
        await tester.pumpAndSettle();
        expect(container.read(themeModeProvider), expected);
      }
    });

    testWidgets('opens About', (tester) async {
      await pumpMenu(tester, compact: false);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('About $appName'), findsOneWidget);
    });

    testWidgets('folds into an overflow menu on a phone', (tester) async {
      // 360 px is already spent on the connection status and profile name.
      await pumpMenu(tester, compact: true);

      expect(find.byIcon(Icons.info_outline), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
      expect(find.textContaining('Theme:'), findsOneWidget);
    });
  });
}
