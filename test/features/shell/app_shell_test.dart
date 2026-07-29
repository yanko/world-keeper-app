import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/app.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/connection/presentation/connection_bar.dart';
import 'package:world_keeper/features/shell/presentation/app_shell.dart';

import '../../support/l10n.dart';

/// Proves the responsive shell actually changes shape, rather than merely having the
/// breakpoints defined. The layouts are designed at desktop width and have to survive
/// down to a 360 px phone, so both ends are asserted.
void main() {
  // The destinations are a function of the string table now, since their labels are the
  // primary navigation. English, because that is what the assertions below name.
  final destinations = appDestinations(l10nFor());

  late Directory tempDir;
  late AuditDatabase db;
  late AppPaths paths;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_shell_test');
    paths = AppPaths.forTesting(tempDir);
    db = AuditDatabaseFactory.inMemory();
    sessionId = await db.startSession('test');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpAppAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(paths),
          auditDatabaseProvider.overrideWithValue(db),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
        ],
        child: const WorldKeeperApp(),
      ),
    );
    await tester.pump();
  }

  group('desktop (1440x900)', () {
    testWidgets('uses a navigation rail with visible labels', (tester) async {
      await pumpAppAt(tester, const Size(1440, 900));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue, reason: 'desktop should show labels');
    });

    testWidgets('shows the full connection bar', (tester) async {
      await pumpAppAt(tester, const Size(1440, 900));
      expect(find.byType(ConnectionBar), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('offers every destination', (tester) async {
      await pumpAppAt(tester, const Size(1440, 900));
      for (final d in destinations) {
        expect(
          find.text(d.label),
          findsWidgets,
          reason: 'missing destination: ${d.label}',
        );
      }
    });
  });

  group('small desktop (1100x800)', () {
    testWidgets('still uses a rail, with labels', (tester) async {
      await pumpAppAt(tester, const Size(1100, 800));
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });
  });

  group('tablet (768x1024)', () {
    testWidgets('collapses the rail to icons only', (tester) async {
      await pumpAppAt(tester, const Size(768, 1024));
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse, reason: 'medium should be icons-only');
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('phone (360x800)', () {
    testWidgets('uses a bottom bar, not a rail', (tester) async {
      await pumpAppAt(tester, const Size(360, 800));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('replaces the wide bar with a compact app bar', (tester) async {
      await pumpAppAt(tester, const Size(360, 800));

      // The full bar has too many controls for 360 px, so it moves behind a sheet.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('World Keeper'), findsOneWidget);
      expect(find.byType(ConnectionBar), findsNothing);
    });

    testWidgets('lays out without overflowing', (tester) async {
      await pumpAppAt(tester, const Size(360, 800));
      // A RenderFlex overflow logs an exception rather than throwing, so the check is
      // that nothing was recorded during layout.
      expect(tester.takeException(), isNull);
    });
  });

  group('shell behaviour', () {
    testWidgets('screens stay alive across navigation', (tester) async {
      await pumpAppAt(tester, const Size(1440, 900));

      // IndexedStack keeps every destination mounted. That is load-bearing rather than
      // an optimisation: the terminal holds a live PTY and the operation panels hold
      // in-flight progress, and the original app had real bugs from its tab widget
      // destroying inactive panels.
      expect(find.byType(IndexedStack), findsOneWidget);
      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.children, hasLength(destinations.length));
    });

    testWidgets(
      'explains itself when disconnected rather than showing a blank',
      (tester) async {
        await pumpAppAt(tester, const Size(1440, 900));
        expect(find.text('Not connected'), findsWidgets);
      },
    );

    testWidgets('discovery and audit remain reachable without a target', (
      tester,
    ) async {
      // Discovery is what *creates* a target, and the audit log is local — gating either
      // behind a connection would be a deadlock and a nuisance respectively.
      final openWithoutTarget = destinations
          .where((d) => !d.requiresTarget)
          .map((d) => d.label)
          .toList();
      expect(openWithoutTarget, containsAll(['Discovery', 'Audit']));
    });
  });

  group('theming', () {
    testWidgets('applies the instrument palette', (tester) async {
      await pumpAppAt(tester, const Size(1440, 900));
      final ctx = tester.element(find.byType(AppShell));
      expect(Theme.of(ctx).extension<WkColors>(), isNotNull);
    });
  });
}
