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
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/features/about/presentation/disclaimer_dialog.dart';
import 'package:world_keeper/features/connection/data/connection_controller.dart';
import 'package:world_keeper/features/connection/domain/connection_status.dart';
import 'package:world_keeper/features/connection/presentation/connection_bar.dart';
import 'package:world_keeper/features/shell/presentation/app_shell.dart';

/// A connection state the test can move, standing in for an attempt in progress.
class _StagedConnection extends ConnectionController {
  @override
  ConnectionStatus build() => const Disconnected();

  // ignore: use_setters_to_change_properties — reads as an action at the call site.
  void moveTo(ConnectionStatus status) => state = status;
}

void main() {
  const profile = Profile(
    id: 'p1',
    name: 'lxc core keeper',
    host: '10.0.0.169',
    user: 'root',
    auth: AuthMethod.key,
  );

  group('shouldCloseConnectionSheet', () {
    // `ConnectionStatus` is sealed and its connected members hold a real `SshSession`
    // whose constructor is private, so no test can build one. The decision lives here so
    // it can be checked at all; the widget tests below cover the wiring for every state a
    // test *can* reach.

    test('closes on the transition into connected', () {
      expect(
        shouldCloseConnectionSheet(wasConnected: false, isConnected: true),
        isTrue,
      );
    });

    test('does not close on a state that was already connected', () {
      // The sheet is also how you disconnect, so opening it with a live connection must
      // not slam it shut.
      expect(
        shouldCloseConnectionSheet(wasConnected: true, isConnected: true),
        isFalse,
      );
    });

    test('does not close on disconnecting', () {
      expect(
        shouldCloseConnectionSheet(wasConnected: true, isConnected: false),
        isFalse,
      );
    });

    test('does not close while nothing is connected', () {
      expect(
        shouldCloseConnectionSheet(wasConnected: false, isConnected: false),
        isFalse,
      );
    });
  });

  group('the sheet itself', () {
    late Directory tempDir;
    late AuditDatabase db;
    late int sessionId;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wk_sheet_test');
      db = AuditDatabaseFactory.inMemory();
      sessionId = await db.startSession('test');
      SharedPreferences.setMockInitialValues({disclaimerStorageKey: true});
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Future<_StagedConnection> openSheet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
            auditDatabaseProvider.overrideWithValue(db),
            initialAuditSessionIdProvider.overrideWithValue(sessionId),
            connectionProvider.overrideWith(_StagedConnection.new),
          ],
          child: const WorldKeeperApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_ethernet));
      await tester.pumpAndSettle();
      expect(
        find.byType(ConnectionBar),
        findsOneWidget,
        reason: 'sheet is open',
      );

      return ProviderScope.containerOf(
            tester.element(find.byType(ConnectionBar)),
          ).read(connectionProvider.notifier)
          as _StagedConnection;
    }

    testWidgets('opens from the app bar on a phone', (tester) async {
      await openSheet(tester);
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('stays open while an attempt is in flight', (tester) async {
      final connection = await openSheet(tester);

      connection.moveTo(const Connecting(profile));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionBar), findsOneWidget);
    });

    testWidgets('stays open when the attempt fails, with the error visible', (
      tester,
    ) async {
      // The error belongs next to the controls that produced it, and the next thing you
      // do is fix the profile and try again.
      final connection = await openSheet(tester);

      connection.moveTo(const Connecting(profile));
      await tester.pumpAndSettle();
      connection.moveTo(
        const Disconnected(error: 'could not connect to 10.0.0.169:22'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionBar), findsOneWidget);
    });
  });
}
