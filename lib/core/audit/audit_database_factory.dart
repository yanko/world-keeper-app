import 'package:drift/native.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/legacy_import.dart';
import 'package:world_keeper/core/config/app_paths.dart';

/// Opens the audit database and performs the one-time legacy import.
///
/// Kept separate from [AuditDatabase] itself so the database class stays free of any
/// path or platform knowledge, which is what lets tests construct one over an in-memory
/// executor with no filesystem at all.
abstract final class AuditDatabaseFactory {
  /// Opens the real on-disk database and imports the Rust app's history if this is the
  /// first run and a legacy database exists.
  ///
  /// The import is best-effort: a corrupt or unreadable legacy file must not stop the
  /// app from starting, so the report carries the outcome instead of throwing.
  static Future<({AuditDatabase db, LegacyImportReport import})> open(
    AppPaths paths,
  ) async {
    await paths.ensureCreated();

    // NativeDatabase rather than drift_flutter's `driftDatabase()` helper: the file
    // location has to match Tauri's, not path_provider's, so the path is already
    // resolved by AppPaths. `createInBackground` runs SQLite on its own isolate, which
    // keeps audit writes off the UI thread — every remote command writes a row.
    final db = AuditDatabase(
      NativeDatabase.createInBackground(paths.databaseFile),
    );

    LegacyImportReport report;
    try {
      report = await LegacyAuditImporter(
        db,
      ).importIfNeeded(paths.legacyDatabaseFile);
    } on Object catch (e) {
      report = LegacyImportReport.skipped('import failed: $e');
    }

    return (db: db, import: report);
  }

  /// An empty in-memory database, for tests.
  static AuditDatabase inMemory() => AuditDatabase(NativeDatabase.memory());
}
