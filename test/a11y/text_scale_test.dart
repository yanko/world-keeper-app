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
import 'package:world_keeper/features/about/presentation/about_dialog.dart';
import 'package:world_keeper/features/about/presentation/disclaimer_dialog.dart';
import 'package:world_keeper/features/audit/presentation/audit_screen.dart';
import 'package:world_keeper/l10n/l10n.dart';

import '../support/audit_scope.dart';
import '../support/l10n.dart';

/// Everything at 2.0 text scale, which is the accessibility setting people actually use.
///
/// A `RenderFlex` overflow does not throw — it paints a yellow-and-black bar and logs an
/// exception — so a layout can be broken for every large-text user while the app "works".
/// `tester.takeException()` is what turns that back into a failure.
///
/// 200% is the ceiling Material's own guidance asks for, and this app is dense: fixed-width
/// timestamp columns, mono command strings, and rows built to stay on one line. Those are
/// exactly the things that break, so they are what gets asserted.
void main() {
  final destinations = appDestinations(l10nFor());

  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_a11y_test');
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
    await db.logSshCommand(
      sessionId,
      command: "systemctl stop 'corekeeper.service'",
      exitCode: 0,
      stdout: 'stopped cleanly',
      stderr: '',
      durationMs: 900,
    );
    await db.logError(
      sessionId,
      context: 'push',
      message: 'verification failed',
    );
    SharedPreferences.setMockInitialValues({disclaimerStorageKey: true});
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Pumps [child] at [size] with the given text scale.
  Future<void> pumpScaled(
    WidgetTester tester,
    Widget child, {
    required Size size,
    double scale = 2.0,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
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
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // The stats and log-tail providers poll forever by design, so `pumpAndSettle` would
      // never return near them. Two frames is enough for layout, which is what is asserted.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget wrap(Widget body) => MaterialApp(
    localizationsDelegates: localizationsDelegates,
    supportedLocales: supportedLocales,
    theme: WkTheme.dark(),
    home: Scaffold(body: body),
  );

  /// Fails with the offending widget rather than just "overflowed by 76 pixels", which on
  /// its own tells you nothing about where to look.
  void expectNoOverflow(WidgetTester tester, {String? reason}) {
    final error = tester.takeException();
    if (error == null) return;
    final where = error is FlutterError
        ? error.diagnostics.map((d) => d.toStringDeep()).join('\n')
        : '$error';
    fail('${reason ?? 'overflow'}\n$where');
  }

  const phone = Size(360, 800);
  const desktop = Size(1440, 900);

  group('the shell', () {
    testWidgets('desktop survives 200% text', (tester) async {
      await pumpScaled(tester, const WorldKeeperApp(), size: desktop);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone survives 200% text', (tester) async {
      // The hardest case: 360 px wide *and* double-size text.
      await pumpScaled(tester, const WorldKeeperApp(), size: phone);
      expectNoOverflow(tester, reason: 'shell at 360 px / 200%');
    });

    // Each screen is pumped on its own rather than navigated to. Two reasons: inside the
    // shell a disconnected destination shows the "Not connected" placeholder instead of the
    // screen, so navigating would test the placeholder seven times; and `pumpAndSettle`
    // cannot be used near the polling providers, which never settle by design.
    for (final destination in destinations) {
      testWidgets('${destination.label} survives 200% text on desktop', (
        tester,
      ) async {
        await pumpScaled(
          tester,
          wrap(Builder(builder: destination.builder)),
          size: desktop,
          settle: false,
        );
        expectNoOverflow(
          tester,
          reason: '${destination.label} at 1440 px / 200%',
        );
      });

      testWidgets('${destination.label} survives 200% text on a phone', (
        tester,
      ) async {
        await pumpScaled(
          tester,
          wrap(Builder(builder: destination.builder)),
          size: phone,
          settle: false,
        );
        expectNoOverflow(
          tester,
          reason: '${destination.label} at 360 px / 200%',
        );
      });
    }
  });

  group('dialogs', () {
    Future<void> openIn(
      WidgetTester tester,
      Size size,
      Future<void> Function(BuildContext) open,
    ) async {
      await pumpScaled(
        tester,
        MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          theme: WkTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        size: size,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('About survives 200% text on a phone', (tester) async {
      await openIn(tester, phone, showWorldKeeperAbout);
    });

    testWidgets('About survives 200% text on desktop', (tester) async {
      await openIn(tester, desktop, showWorldKeeperAbout);
    });

    testWidgets('the safety notice survives 200% text on a phone', (
      tester,
    ) async {
      await openIn(tester, phone, showDisclaimer);
    });
  });

  group('the audit log', () {
    // Rows here are deliberately single-line with a fixed-width timestamp column, which is
    // precisely the construction that bursts when the text doubles.
    testWidgets('desktop rows survive 200% text', (tester) async {
      await pumpScaled(tester, wrap(const AuditScreen()), size: desktop);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone rows survive 200% text', (tester) async {
      await pumpScaled(tester, wrap(const AuditScreen()), size: phone);
      expectNoOverflow(tester, reason: 'audit rows at 360 px / 200%');
    });
  });

  group('extremes', () {
    testWidgets('300% still does not overflow the shell', (tester) async {
      // Beyond what Material asks for, but the OS will happily go there.
      await pumpScaled(tester, const WorldKeeperApp(), size: phone, scale: 3.0);
      expect(tester.takeException(), isNull);
    });
  });
}
