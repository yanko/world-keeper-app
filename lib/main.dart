import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:world_keeper/app/app.dart';
import 'package:world_keeper/app/app_info.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = await AppPaths.resolve();
  final opened = await AuditDatabaseFactory.open(paths);
  final sessionId = await opened.db.startSession(appVersion);
  await opened.db.logEvent(
    sessionId,
    'app_start',
    detail: {'legacyImport': opened.import.toString()},
    ok: true,
  );

  if (_isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 820),
        // The original set no minimum, so it could be dragged to a width where the
        // controls became unusable. 800x600 is the narrowest the desktop layout is
        // designed to hold together at.
        minimumSize: Size(800, 600),
        title: appName,
        titleBarStyle: TitleBarStyle.normal,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        auditDatabaseProvider.overrideWithValue(opened.db),
        initialAuditSessionIdProvider.overrideWithValue(sessionId),
      ],
      child: const WorldKeeperApp(),
    ),
  );
}

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;
