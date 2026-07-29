import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:world_keeper/app/app.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/about/presentation/disclaimer_dialog.dart';
import 'package:world_keeper/features/audit/presentation/audit_screen.dart';
import 'package:world_keeper/l10n/l10n.dart';

import '../support/audit_scope.dart';

/// Contrast, tap targets, and anything the app says with colour alone.
///
/// Flutter ships real guideline matchers for the first two, so these are checks rather
/// than assertions of intent. The third is the one that needs judgement: this app signals
/// success and failure with a coloured dot, which conveys nothing to a screen reader and
/// nothing to a red/green-deficient reader either — and it is doing that inside a forensic
/// log whose entire purpose is answering "did that step work".
void main() {
  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_semantics_test');
    db = AuditDatabaseFactory.inMemory();
    sessionId = await db.startSession('test');
    await db.recordConnect(
      sessionId,
      profileId: 'p1',
      host: '10.0.0.68',
      sshUser: 'root',
      authMethod: 'key',
    );
    await db.logEvent(sessionId, 'push_done', detail: {'slot': 0}, ok: true);
    await db.logEvent(sessionId, 'push_begin', detail: {'slot': 0}, ok: false);
    SharedPreferences.setMockInitialValues({disclaimerStorageKey: true});
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Widget child, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          auditDatabaseProvider.overrideWithValue(db),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
          auditScopeProvider.overrideWith(
            () => FixedAuditScope(
              const AuditScope(
                profileId: 'p1',
                name: 'lxc-core-keeper',
                where: 'root@10.0.0.68',
                locked: true,
              ),
            ),
          ),
        ],
        child: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget wrap(Widget body) => MaterialApp(
    localizationsDelegates: localizationsDelegates,
    supportedLocales: supportedLocales,
    theme: WkTheme.dark(),
    home: Scaffold(body: body),
  );

  group('nothing is signalled by colour alone', () {
    testWidgets('an audit row says whether the step succeeded', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, wrap(const AuditScreen()));

      // Matched loosely: the row's tap semantics merge the dot's label in with the
      // timestamp and event kind, which is exactly what a screen reader should read out.
      expect(find.bySemanticsLabel(RegExp('succeeded')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('failed')), findsWidgets);

      handle.dispose();
    });

    testWidgets('the connection chip says its status even with no text shown', (
      tester,
    ) async {
      // The compact bar drops the words to fit; a screen reader must not lose them too.
      final handle = tester.ensureSemantics();
      await pump(tester, const WorldKeeperApp(), size: const Size(360, 800));

      expect(
        find.bySemanticsLabel('Connection status: Disconnected'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('Material guidelines', () {
    testWidgets('desktop meets the text contrast guideline', (tester) async {
      await pump(tester, const WorldKeeperApp());
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('phone meets the text contrast guideline', (tester) async {
      await pump(tester, const WorldKeeperApp(), size: const Size(360, 800));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('phone meets the tap target guideline', (tester) async {
      // The bottom bar and the compact app bar are where touch targets get squeezed.
      await pump(tester, const WorldKeeperApp(), size: const Size(360, 800));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('every tappable thing on the phone is labelled', (
      tester,
    ) async {
      await pump(tester, const WorldKeeperApp(), size: const Size(360, 800));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });

  group('reduced motion', () {
    testWidgets('the app renders with animations disabled', (tester) async {
      // The stepper's pulse is the only decorative motion in the app and it already checks
      // `disableAnimations`; this guards the rest of the tree against acquiring some.
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
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: WorldKeeperApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
