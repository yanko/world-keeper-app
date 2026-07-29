import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/errors/exceptions.dart';

/// One-time import of the Rust app's `ckmanager.db` into this app's database.
///
/// Users have real audit history — sessions going back to whenever they set the server
/// up — and losing it on switching apps would be a regression, not a migration.
///
/// ## Why copy rather than adopt the file
///
/// Opening the legacy file *as* the drift database would be less code, but drift tracks
/// schema state in `PRAGMA user_version`, which the Rust app never sets (it just issues
/// `CREATE TABLE IF NOT EXISTS` on every launch). Drift would read version 0, decide the
/// database is new, and run `onCreate` against tables that already exist.
///
/// Copying also leaves the legacy file **completely untouched**, so a user can go back
/// to the Rust app with its history intact. That matters while both apps are installed.
///
/// ## Id preservation
///
/// Primary keys are carried across verbatim, because `events.session_id`,
/// `backups.session_id`, `file_ops.event_id` and the World Library's note-enrichment
/// join all depend on them. Inserting explicit ids also advances SQLite's
/// `AUTOINCREMENT` sequence past them, so new rows can't collide.
class LegacyAuditImporter {
  const LegacyAuditImporter(this._db);

  final AuditDatabase _db;

  /// Marker event recorded once the import completes, so it never runs twice.
  static const String importedMarkerKind = 'legacy_audit_imported';

  /// Whether an import has already been performed against this database.
  Future<bool> alreadyImported() async {
    final row =
        await (_db.select(_db.auditEvents)
              ..where((e) => e.kind.equals(importedMarkerKind))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Imports [legacyFile] if it exists and nothing has been imported yet.
  ///
  /// Safe to call unconditionally on every startup; returns a report describing what (if
  /// anything) happened.
  Future<LegacyImportReport> importIfNeeded(File legacyFile) async {
    if (await alreadyImported()) {
      return const LegacyImportReport.skipped('already imported');
    }
    // Sync: a single startup existence check, and `dart:io`'s async File methods are
    // measurably slower than their sync counterparts (see `avoid_slow_async_io`).
    if (!legacyFile.existsSync()) {
      return const LegacyImportReport.skipped('no legacy database found');
    }
    return import(legacyFile);
  }

  /// Imports unconditionally. Prefer [importIfNeeded].
  Future<LegacyImportReport> import(File legacyFile) async {
    final sqlite3.Database legacy;
    try {
      // Read-only: this file belongs to the other app and must not be written, not even
      // by SQLite's journal machinery.
      legacy = sqlite3.sqlite3.open(
        legacyFile.path,
        mode: sqlite3.OpenMode.readOnly,
      );
    } on Object catch (e) {
      throw AuditException(
        'could not open the legacy audit database at ${legacyFile.path}',
        cause: e,
      );
    }

    try {
      final present = _tableNames(legacy);
      if (!present.contains('sessions') || !present.contains('events')) {
        return const LegacyImportReport.skipped(
          'file exists but is not a World Keeper audit database',
        );
      }

      final counts = <String, int>{};
      await _db.transaction(() async {
        counts['sessions'] = await _importSessions(legacy);
        counts['events'] = await _importEvents(legacy);
        counts['file_ops'] = present.contains('file_ops')
            ? await _importFileOps(legacy)
            : 0;
        counts['backups'] = present.contains('backups')
            ? await _importBackups(legacy)
            : 0;
        counts['ssh_commands'] = present.contains('ssh_commands')
            ? await _importSshCommands(legacy)
            : 0;
        counts['errors'] = present.contains('errors')
            ? await _importErrors(legacy)
            : 0;
      });

      // Recorded outside the transaction so the marker only lands once the data has
      // actually committed.
      await _db.logEvent(
        await _anySessionId() ?? 0,
        importedMarkerKind,
        detail: {'source': legacyFile.path, 'rows': counts},
        ok: true,
      );

      return LegacyImportReport.imported(counts);
    } finally {
      legacy.close();
    }
  }

  Future<int?> _anySessionId() async {
    final row = await (_db.select(
      _db.auditSessions,
    )..limit(1)).getSingleOrNull();
    return row?.id;
  }

  Set<String> _tableNames(sqlite3.Database db) {
    final result = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return {for (final row in result) row['name'] as String};
  }

  Future<int> _importSessions(sqlite3.Database legacy) async {
    final rows = legacy.select(
      'SELECT id, started_at, app_version, profile_id, host, ssh_user, auth_method '
      'FROM sessions ORDER BY id',
    );
    for (final r in rows) {
      await _db
          .into(_db.auditSessions)
          .insert(
            AuditSessionsCompanion.insert(
              id: Value(_int(r['id'])!),
              // `started_at` is NOT NULL in the legacy schema, but a hand-edited or
              // partially-written database is exactly the kind of thing an importer
              // meets, so fall back rather than throw away the whole import.
              startedAt: _str(r['started_at']) ?? '',
              appVersion: Value(_str(r['app_version'])),
              profileId: Value(_str(r['profile_id'])),
              host: Value(_str(r['host'])),
              sshUser: Value(_str(r['ssh_user'])),
              authMethod: Value(_str(r['auth_method'])),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return rows.length;
  }

  Future<int> _importEvents(sqlite3.Database legacy) async {
    final rows = legacy.select(
      'SELECT id, session_id, ts, kind, state, detail_json, ok FROM events ORDER BY id',
    );
    for (final r in rows) {
      await _db
          .into(_db.auditEvents)
          .insert(
            AuditEventsCompanion.insert(
              id: Value(_int(r['id'])!),
              sessionId: Value(_int(r['session_id'])),
              ts: _str(r['ts']) ?? '',
              kind: _str(r['kind']) ?? 'unknown',
              state: Value(_str(r['state'])),
              detailJson: Value(_str(r['detail_json'])),
              ok: Value(_int(r['ok'])),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return rows.length;
  }

  Future<int> _importFileOps(sqlite3.Database legacy) async {
    final rows = legacy.select(
      'SELECT id, event_id, op, src, dst, bytes, slot FROM file_ops ORDER BY id',
    );
    for (final r in rows) {
      await _db
          .into(_db.auditFileOps)
          .insert(
            AuditFileOpsCompanion.insert(
              id: Value(_int(r['id'])!),
              eventId: Value(_int(r['event_id'])),
              op: Value(_str(r['op'])),
              src: Value(_str(r['src'])),
              dst: Value(_str(r['dst'])),
              bytes: Value(_int(r['bytes'])),
              slot: Value(_int(r['slot'])),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return rows.length;
  }

  Future<int> _importBackups(sqlite3.Database legacy) async {
    final rows = legacy.select(
      'SELECT id, session_id, ts, slot, lxc_path, bytes, game_id_before, note '
      'FROM backups ORDER BY id',
    );
    for (final r in rows) {
      await _db
          .into(_db.auditBackups)
          .insert(
            AuditBackupsCompanion.insert(
              id: Value(_int(r['id'])!),
              sessionId: Value(_int(r['session_id'])),
              ts: _str(r['ts']) ?? '',
              slot: Value(_int(r['slot'])),
              lxcPath: Value(_str(r['lxc_path'])),
              bytes: Value(_int(r['bytes'])),
              gameIdBefore: Value(_str(r['game_id_before'])),
              note: Value(_str(r['note'])),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return rows.length;
  }

  Future<int> _importSshCommands(sqlite3.Database legacy) async {
    final rows = legacy.select(
      'SELECT id, session_id, ts, command, exit_code, stdout, stderr, duration_ms '
      'FROM ssh_commands ORDER BY id',
    );
    for (final r in rows) {
      await _db
          .into(_db.auditSshCommands)
          .insert(
            AuditSshCommandsCompanion.insert(
              id: Value(_int(r['id'])!),
              sessionId: Value(_int(r['session_id'])),
              ts: _str(r['ts']) ?? '',
              command: _str(r['command']) ?? '',
              exitCode: Value(_int(r['exit_code'])),
              stdout: Value(_str(r['stdout'])),
              stderr: Value(_str(r['stderr'])),
              durationMs: Value(_int(r['duration_ms'])),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return rows.length;
  }

  Future<int> _importErrors(sqlite3.Database legacy) async {
    final rows = legacy.select(
      'SELECT id, session_id, ts, context, message, detail_json FROM errors ORDER BY id',
    );
    for (final r in rows) {
      await _db
          .into(_db.auditErrors)
          .insert(
            AuditErrorsCompanion.insert(
              id: Value(_int(r['id'])!),
              sessionId: Value(_int(r['session_id'])),
              ts: _str(r['ts']) ?? '',
              context: _str(r['context']) ?? 'unknown',
              message: _str(r['message']) ?? '',
              detailJson: Value(_str(r['detail_json'])),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return rows.length;
  }

  // SQLite is dynamically typed and this database was written by a different program, so
  // a column can legitimately hold something other than its declared type. Coerce rather
  // than cast — a surprising value should not abort an import of otherwise-good history.
  static String? _str(Object? v) =>
      v == null ? null : v as String? ?? v.toString();

  static int? _int(Object? v) => switch (v) {
    null => null,
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };
}

/// Outcome of an import attempt.
class LegacyImportReport {
  const LegacyImportReport.imported(this.rowCounts)
    : skippedReason = null,
      didImport = true;

  const LegacyImportReport.skipped(String reason)
    : skippedReason = reason,
      rowCounts = const {},
      didImport = false;

  final bool didImport;
  final String? skippedReason;

  /// Rows imported per table.
  final Map<String, int> rowCounts;

  int get totalRows => rowCounts.values.fold(0, (sum, count) => sum + count);

  @override
  String toString() => didImport
      ? 'LegacyImportReport(imported $totalRows rows: $rowCounts)'
      : 'LegacyImportReport(skipped: $skippedReason)';
}
