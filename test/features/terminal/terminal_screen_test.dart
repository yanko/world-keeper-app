import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/terminal/presentation/terminal_screen.dart';
import 'package:world_keeper/l10n/l10n.dart';

void main() {
  late Directory tempDir;
  late AuditDatabase audit;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_term_test');
    audit = AuditDatabaseFactory.inMemory();
    sessionId = await audit.startSession('test');
  });

  tearDown(() async {
    await audit.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          auditDatabaseProvider.overrideWithValue(audit),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          theme: WkTheme.dark(),
          home: const Scaffold(body: TerminalScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  group('idle state', () {
    testWidgets('offers to start a session and nothing more', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Start session'), findsOneWidget);
      expect(find.text('No session'), findsOneWidget);
      // Nothing is opened just because the screen rendered — this is a root shell.
      expect(find.text('Close session'), findsNothing);
    });

    testWidgets('start is disabled while disconnected', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start session'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('says plainly that nothing opens automatically', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1440, 900));
      expect(find.textContaining('Nothing is opened'), findsOneWidget);
    });

    testWidgets('warns that the shell is not sandboxed', (tester) async {
      // Worth being explicit: this is the same trust level as ssh-ing to the host.
      await pumpAt(tester, const Size(1440, 900));
      expect(find.textContaining('not sandboxed'), findsOneWidget);
    });

    testWidgets('lays out on a phone without overflowing', (tester) async {
      await pumpAt(tester, const Size(360, 800));
      expect(tester.takeException(), isNull);
      expect(find.text('Start session'), findsOneWidget);
    });

    testWidgets('no accessory bar without a session', (tester) async {
      // The bar belongs to a live session, not to the screen.
      await pumpAt(tester, const Size(360, 800));
      expect(find.text('Ctrl'), findsNothing);
      expect(find.text('Esc'), findsNothing);
    });
  });
}
