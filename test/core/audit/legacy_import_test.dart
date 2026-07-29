import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/audit/legacy_import.dart';

/// The Rust app's schema, verbatim from `audit.rs`. Recreating it here rather than
/// checking in a binary fixture keeps the thing being tested — "does our importer
/// understand *that* schema" — visible and reviewable.
const String legacySchema = '''
CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY,
  started_at TEXT NOT NULL,
  app_version TEXT,
  profile_id TEXT,
  host TEXT,
  ssh_user TEXT,
  auth_method TEXT
);
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY,
  session_id INTEGER REFERENCES sessions(id),
  ts TEXT NOT NULL,
  kind TEXT NOT NULL,
  state TEXT,
  detail_json TEXT,
  ok INTEGER
);
CREATE TABLE IF NOT EXISTS file_ops (
  id INTEGER PRIMARY KEY,
  event_id INTEGER REFERENCES events(id),
  op TEXT, src TEXT, dst TEXT, bytes INTEGER, slot INTEGER
);
CREATE TABLE IF NOT EXISTS backups (
  id INTEGER PRIMARY KEY,
  session_id INTEGER REFERENCES sessions(id),
  ts TEXT NOT NULL, slot INTEGER, lxc_path TEXT, bytes INTEGER,
  game_id_before TEXT, note TEXT
);
CREATE TABLE IF NOT EXISTS ssh_commands (
  id INTEGER PRIMARY KEY,
  session_id INTEGER REFERENCES sessions(id),
  ts TEXT NOT NULL, command TEXT NOT NULL, exit_code INTEGER,
  stdout TEXT, stderr TEXT, duration_ms INTEGER
);
CREATE TABLE IF NOT EXISTS errors (
  id INTEGER PRIMARY KEY,
  session_id INTEGER REFERENCES sessions(id),
  ts TEXT NOT NULL, context TEXT NOT NULL, message TEXT NOT NULL, detail_json TEXT
);
''';

void main() {
  late Directory tempDir;
  late File legacyFile;
  late AuditDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_legacy_test');
    legacyFile = File('${tempDir.path}${Platform.pathSeparator}ckmanager.db');
    db = AuditDatabaseFactory.inMemory();
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Writes a legacy database with a small but representative history.
  void seedLegacy() {
    final legacy = sqlite3.sqlite3.open(legacyFile.path);
    legacy.execute(legacySchema);
    // Non-contiguous ids on purpose: the importer must preserve them, not renumber.
    legacy.execute('''
      INSERT INTO sessions (id, started_at, app_version, profile_id, host, ssh_user, auth_method)
      VALUES (7, '2026-07-24T21:00:00+00:00', '0.9.0', 'ck-lxc-1', '10.0.0.68', 'root', 'password'),
             (9, '2026-07-26T08:00:00+00:00', '1.0.0', 'unraid', '10.0.0.12', 'root', 'key');
    ''');
    legacy.execute('''
      INSERT INTO events (id, session_id, ts, kind, state, detail_json, ok)
      VALUES (101, 7, '2026-07-24T21:00:01+00:00', 'app_start', NULL, NULL, 1),
             (102, 7, '2026-07-24T21:05:00+00:00', 'state_enter', 'Stopping', '{"slot":0}', NULL),
             (103, 9, '2026-07-26T08:00:01+00:00', 'push_done', NULL, '{"slot":0}', 1);
    ''');
    legacy.execute('''
      INSERT INTO file_ops (id, event_id, op, src, dst, bytes, slot)
      VALUES (1, 102, 'upload', 'C:/w/0.world.gzip', '/worlds/.staging/0.world.gzip', 5046105, 0);
    ''');
    legacy.execute('''
      INSERT INTO backups (id, session_id, ts, slot, lxc_path, bytes, game_id_before, note)
      VALUES (1, 7, '2026-07-24T21:05:10+00:00', 0, '/worlds/.backups/0.2026-07-24_210510',
              10093297, 'ABCD-1234', NULL);
    ''');
    // Bound parameters rather than inline literals: real commands are shq-quoted and so
    // contain single quotes, which cannot be embedded in a Dart '''…''' string without
    // terminating it.
    final insertCommand = legacy.prepare(
      'INSERT INTO ssh_commands (id, session_id, ts, command, exit_code, stdout, stderr, duration_ms) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    );
    insertCommand.execute([
      1,
      7,
      '2026-07-24T21:05:00+00:00',
      "systemctl stop 'corekeeper'",
      0,
      '',
      '',
      1200,
    ]);
    insertCommand.execute([
      2,
      7,
      '2026-07-24T21:05:02+00:00',
      'sha256sum /x',
      1,
      '',
      'no such file',
      80,
    ]);
    insertCommand.close();
    legacy.execute('''
      INSERT INTO errors (id, session_id, ts, context, message, detail_json)
      VALUES (1, 7, '2026-07-24T21:06:00+00:00', 'push', 'verification failed', '{"slot":0}');
    ''');
    legacy.close();
  }

  group('importIfNeeded', () {
    test('skips cleanly when there is no legacy database', () async {
      final report = await LegacyAuditImporter(db).importIfNeeded(legacyFile);
      expect(report.didImport, isFalse);
      expect(report.skippedReason, contains('no legacy database'));
    });

    test('skips a file that is not a World Keeper database', () async {
      final other = sqlite3.sqlite3.open(legacyFile.path);
      other.execute('CREATE TABLE unrelated (id INTEGER PRIMARY KEY)');
      other.close();

      final report = await LegacyAuditImporter(db).importIfNeeded(legacyFile);
      expect(report.didImport, isFalse);
      expect(
        report.skippedReason,
        contains('not a World Keeper audit database'),
      );
    });

    test('imports every table and reports the counts', () async {
      seedLegacy();
      final report = await LegacyAuditImporter(db).importIfNeeded(legacyFile);

      expect(report.didImport, isTrue);
      expect(report.rowCounts, {
        'sessions': 2,
        'events': 3,
        'file_ops': 1,
        'backups': 1,
        'ssh_commands': 2,
        'errors': 1,
      });
      expect(report.totalRows, 10);
    });

    test(
      'preserves primary keys and the relationships built on them',
      () async {
        seedLegacy();
        await LegacyAuditImporter(db).importIfNeeded(legacyFile);

        final sessions = await db.select(db.auditSessions).get();
        expect(sessions.map((s) => s.id).toSet(), {7, 9});

        final events = await db.select(db.auditEvents).get();
        expect(events.map((e) => e.id).toSet(), containsAll([101, 102, 103]));
        // The join the World Library and the audit filters both depend on.
        expect(events.firstWhere((e) => e.id == 102).sessionId, 7);

        final fileOp = await db.select(db.auditFileOps).getSingle();
        expect(fileOp.eventId, 102);

        final backup = await db.select(db.auditBackups).getSingle();
        expect(backup.sessionId, 7);
        expect(backup.lxcPath, '/worlds/.backups/0.2026-07-24_210510');
        expect(backup.gameIdBefore, 'ABCD-1234');
      },
    );

    test('carries values across faithfully', () async {
      seedLegacy();
      await LegacyAuditImporter(db).importIfNeeded(legacyFile);

      final session = await (db.select(
        db.auditSessions,
      )..where((s) => s.id.equals(7))).getSingle();
      expect(session.host, '10.0.0.68');
      expect(session.authMethod, 'password');
      expect(session.appVersion, '0.9.0');

      final failed = await (db.select(
        db.auditSshCommands,
      )..where((c) => c.id.equals(2))).getSingle();
      expect(failed.exitCode, 1);
      expect(failed.stderr, 'no such file');

      final error = await db.select(db.auditErrors).getSingle();
      expect(error.context, 'push');
      expect(error.message, 'verification failed');
    });

    test('is idempotent — a second call does nothing', () async {
      seedLegacy();
      final importer = LegacyAuditImporter(db);

      final first = await importer.importIfNeeded(legacyFile);
      expect(first.didImport, isTrue);

      final second = await importer.importIfNeeded(legacyFile);
      expect(second.didImport, isFalse);
      expect(second.skippedReason, contains('already imported'));

      // No duplicated history.
      expect(await db.select(db.auditSessions).get(), hasLength(2));
      expect(
        (await db.select(db.auditEvents).get())
            .where((e) => e.id == 101)
            .length,
        1,
      );
    });

    test('leaves the legacy database untouched', () async {
      seedLegacy();
      final before = legacyFile.lengthSync();
      final modifiedBefore = legacyFile.lastModifiedSync();

      await LegacyAuditImporter(db).importIfNeeded(legacyFile);

      // Opened read-only, so going back to the Rust app finds its history intact.
      expect(legacyFile.lengthSync(), before);
      expect(legacyFile.lastModifiedSync(), modifiedBefore);

      final legacy = sqlite3.sqlite3.open(legacyFile.path);
      final count = legacy
          .select('SELECT COUNT(*) AS c FROM sessions')
          .first['c'];
      legacy.close();
      expect(count, 2);
    });

    test(
      'new rows written afterwards do not collide with imported ids',
      () async {
        seedLegacy();
        await LegacyAuditImporter(db).importIfNeeded(legacyFile);

        // Explicit-id inserts must have advanced SQLite's AUTOINCREMENT sequence.
        final newSession = await db.startSession('1.0.0');
        expect(newSession, greaterThan(9));

        final newEvent = await db.logEvent(newSession, 'app_start', ok: true);
        expect(newEvent, greaterThan(103));
      },
    );

    test('records a marker event describing the import', () async {
      seedLegacy();
      await LegacyAuditImporter(db).importIfNeeded(legacyFile);

      final marker =
          await (db.select(db.auditEvents)..where(
                (e) => e.kind.equals(LegacyAuditImporter.importedMarkerKind),
              ))
              .getSingle();
      expect(marker.detailJson, contains('ckmanager.db'));
      expect(marker.ok, 1);
    });

    test('tolerates a legacy database missing the optional tables', () async {
      // An old install that predates ssh_commands/errors — those tables were added
      // later than sessions/events in the Rust app's history.
      final legacy = sqlite3.sqlite3.open(legacyFile.path);
      legacy.execute('''
        CREATE TABLE sessions (id INTEGER PRIMARY KEY, started_at TEXT NOT NULL,
          app_version TEXT, profile_id TEXT, host TEXT, ssh_user TEXT, auth_method TEXT);
        CREATE TABLE events (id INTEGER PRIMARY KEY, session_id INTEGER, ts TEXT NOT NULL,
          kind TEXT NOT NULL, state TEXT, detail_json TEXT, ok INTEGER);
      ''');
      legacy.execute(
        "INSERT INTO sessions (id, started_at) VALUES (1, '2026-01-01T00:00:00+00:00')",
      );
      legacy.execute(
        "INSERT INTO events (id, session_id, ts, kind) VALUES (1, 1, '2026-01-01T00:00:00+00:00', 'app_start')",
      );
      legacy.close();

      final report = await LegacyAuditImporter(db).importIfNeeded(legacyFile);
      expect(report.didImport, isTrue);
      expect(report.rowCounts['sessions'], 1);
      expect(report.rowCounts['ssh_commands'], 0);
      expect(report.rowCounts['errors'], 0);
    });
  });
}
