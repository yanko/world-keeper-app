import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/audit/legacy_import.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/config_repository.dart';

/// Compatibility checks against the **real Rust app installed on this machine**.
///
/// The synthetic fixtures in `models_test.dart` prove the format we *think* the Rust app
/// writes. This proves the format it *actually* wrote — with whatever profiles, service
/// kinds, unicode paths and historical quirks a live install accumulated. That is a
/// different and stronger claim, and it is the real Phase 1 exit criterion.
///
/// Every test here is read-only and skips itself when there is no local install, so it
/// stays green on CI and on a fresh machine.
void main() {
  late AppPaths paths;

  setUpAll(() async => paths = await AppPaths.resolve());

  bool hasConfig() => paths.configFile.existsSync();
  bool hasLegacyDb() => paths.legacyDatabaseFile.existsSync();

  test('resolves the same directory Tauri uses', () {
    // Not asserting the path exists — asserting we compute the identical location, which
    // is what makes sharing possible at all.
    expect(paths.configFile.path, contains(AppPaths.tauriIdentifier));
    expect(paths.configFile.path, endsWith('config.json'));
    if (Platform.isWindows || Platform.isMacOS) {
      // Tauri's dirs::config_dir() and dirs::data_dir() collapse to one directory here.
      expect(paths.configDir.path, paths.dataDir.path);
    }
    // ignore: avoid_print
    print('resolved paths: $paths');
  });

  group('real config.json', () {
    test('loads', () async {
      if (!hasConfig()) {
        markTestSkipped('no local Rust install at ${paths.configFile.path}');
        return;
      }
      final config = await ConfigRepository(paths).load();
      // ignore: avoid_print
      print(
        'loaded ${config.profiles.length} profile(s); '
        'active=${config.activeProfileId}',
      );
      for (final p in config.profiles) {
        // ignore: avoid_print
        print(
          '  ${p.name}: ${p.user}@${p.host}:${p.port} auth=${p.auth.name} '
          'kind=${p.discovered?.serviceKind?.label ?? "(not discovered)"}',
        );
      }
      expect(config.profiles, isNotEmpty);
    });

    test('survives a round trip unchanged', () async {
      if (!hasConfig()) {
        markTestSkipped('no local Rust install at ${paths.configFile.path}');
        return;
      }
      // The guarantee that matters: parse the real file, serialise it back, and get a
      // structurally identical document. Anything else means switching apps would
      // rewrite — or lose — part of a user's real configuration.
      final raw = await paths.configFile.readAsString();
      final original = jsonDecode(raw) as Map<String, dynamic>;
      final section = original['config'] as Map<String, dynamic>;

      final config = await ConfigRepository(paths).load();
      expect(config.toJson(), equals(section));
    });

    test('is never written to by a load', () async {
      if (!hasConfig()) {
        markTestSkipped('no local Rust install at ${paths.configFile.path}');
        return;
      }
      final before = paths.configFile.lastModifiedSync();
      await ConfigRepository(paths).load();
      expect(paths.configFile.lastModifiedSync(), before);
    });
  });

  group('real ckmanager.db', () {
    test('imports into a fresh database without touching the original', () async {
      if (!hasLegacyDb()) {
        markTestSkipped(
          'no local audit db at ${paths.legacyDatabaseFile.path}',
        );
        return;
      }

      final sizeBefore = paths.legacyDatabaseFile.lengthSync();
      final modifiedBefore = paths.legacyDatabaseFile.lastModifiedSync();

      final db = AuditDatabaseFactory.inMemory();
      try {
        final report = await LegacyAuditImporter(
          db,
        ).importIfNeeded(paths.legacyDatabaseFile);
        // ignore: avoid_print
        print('import report: $report');

        expect(report.didImport, isTrue);
        expect(report.totalRows, greaterThan(0));

        // Spot-check that real rows actually landed and kept their shape.
        final sessions = await db.select(db.auditSessions).get();
        expect(sessions, isNotEmpty);
        expect(
          sessions.every((s) => DateTime.tryParse(s.startedAt) != null),
          isTrue,
          reason: 'every imported session should have a parseable timestamp',
        );

        final events = await db.select(db.auditEvents).get();
        expect(events, isNotEmpty);
        // ignore: avoid_print
        print(
          'imported ${sessions.length} session(s), ${events.length} event(s), '
          'kinds: ${events.map((e) => e.kind).toSet().toList()..sort()}',
        );

        // Ids preserved means the session/event relationships still resolve.
        final withSession = events.where((e) => e.sessionId != null);
        final sessionIds = sessions.map((s) => s.id).toSet();
        expect(
          withSession.every((e) => sessionIds.contains(e.sessionId)),
          isTrue,
          reason: 'every event should still point at an imported session',
        );
      } finally {
        await db.close();
      }

      // Read-only: going back to the Rust app must find its history untouched.
      expect(paths.legacyDatabaseFile.lengthSync(), sizeBefore);
      expect(paths.legacyDatabaseFile.lastModifiedSync(), modifiedBefore);
    });
  });
}
