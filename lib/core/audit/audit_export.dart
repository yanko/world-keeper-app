import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_queries.dart';
import 'package:world_keeper/core/errors/exceptions.dart';

/// Exports the audit trail as a zip: human-readable CSVs plus the raw database.
///
/// Both, deliberately. The CSVs open in anything and are what someone actually reads; the
/// `.db` is the complete, queryable original for when a CSV column is not enough. An
/// export that only produced one of the two would eventually be the wrong one.
///
/// Rows are streamed table-by-table into temp files rather than assembled in memory: a
/// real install had 4,247 `ssh_commands` rows with captures up to 4 KB each, which is
/// tens of megabytes for a log nobody expects to be heavy.
class AuditExporter {
  const AuditExporter(this._db);

  final AuditDatabase _db;

  /// Writes the archive to [destination] and returns that path.
  Future<String> exportTo(String destination, {File? databaseFile}) async {
    final staging = await Directory.systemTemp.createTemp('wk-audit-export-');
    try {
      await _writeEvents(File(p.join(staging.path, 'events.csv')));
      await _writeCommands(File(p.join(staging.path, 'ssh_commands.csv')));
      await _writeErrors(File(p.join(staging.path, 'errors.csv')));
      await _writeSessions(File(p.join(staging.path, 'sessions.csv')));
      await _writeBackups(File(p.join(staging.path, 'backups.csv')));

      final encoder = ZipFileEncoder()..create(destination);
      try {
        for (final entity in staging.listSync().whereType<File>()) {
          await encoder.addFile(entity, p.basename(entity.path));
        }
        // The raw database, when it exists on disk. An in-memory database has none, and
        // that is not a reason to fail the export.
        if (databaseFile != null && databaseFile.existsSync()) {
          await encoder.addFile(databaseFile, 'world_keeper.db');
        }
      } finally {
        await encoder.close();
      }
      return destination;
    } on Object catch (e) {
      throw AuditException('could not export the audit log', cause: e);
    } finally {
      if (staging.existsSync()) {
        try {
          await staging.delete(recursive: true);
        } on Object {
          // A leftover temp directory is not worth failing a completed export over.
        }
      }
    }
  }

  /// Pipes rows through the CSV encoder straight to disk.
  Future<void> _write(
    File file,
    List<String> header,
    Stream<List<Object?>> rows,
  ) async {
    final sink = file.openWrite();
    try {
      final withHeader = () async* {
        yield header;
        yield* rows;
      }();
      await withHeader.transform(const CsvEncoder()).forEach(sink.write);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// Everything, oldest first — the export is a record to read through, not the
  /// newest-first view the UI shows.
  Future<void> _writeEvents(File file) async {
    final rows = await (_db.select(
      _db.auditEvents,
    )..orderBy([(e) => OrderingTerm.asc(e.id)])).get();
    await _write(
      file,
      ['id', 'session_id', 'ts', 'kind', 'state', 'detail_json', 'ok'],
      Stream.fromIterable([
        for (final e in rows)
          [e.id, e.sessionId, e.ts, e.kind, e.state, e.detailJson, e.ok],
      ]),
    );
  }

  Future<void> _writeCommands(File file) async {
    final rows = await (_db.select(
      _db.auditSshCommands,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
    await _write(
      file,
      [
        'id',
        'session_id',
        'ts',
        'command',
        'exit_code',
        'stdout',
        'stderr',
        'duration_ms',
      ],
      Stream.fromIterable([
        for (final c in rows)
          [
            c.id,
            c.sessionId,
            c.ts,
            c.command,
            c.exitCode,
            c.stdout,
            c.stderr,
            c.durationMs,
          ],
      ]),
    );
  }

  Future<void> _writeErrors(File file) async {
    final rows = await (_db.select(
      _db.auditErrors,
    )..orderBy([(e) => OrderingTerm.asc(e.id)])).get();
    await _write(
      file,
      ['id', 'session_id', 'ts', 'context', 'message', 'detail_json'],
      Stream.fromIterable([
        for (final e in rows)
          [e.id, e.sessionId, e.ts, e.context, e.message, e.detailJson],
      ]),
    );
  }

  Future<void> _writeSessions(File file) async {
    final rows = await _db.listSessions(limit: 1 << 30);
    await _write(
      file,
      [
        'id',
        'started_at',
        'app_version',
        'profile_id',
        'host',
        'ssh_user',
        'auth_method',
      ],
      Stream.fromIterable([
        for (final s in rows.reversed)
          [
            s.id,
            s.startedAt,
            s.appVersion,
            s.profileId,
            s.host,
            s.sshUser,
            s.authMethod,
          ],
      ]),
    );
  }

  Future<void> _writeBackups(File file) async {
    final rows = await (_db.select(
      _db.auditBackups,
    )..orderBy([(b) => OrderingTerm.asc(b.id)])).get();
    await _write(
      file,
      [
        'id',
        'session_id',
        'ts',
        'slot',
        'path',
        'bytes',
        'game_id_before',
        'note',
      ],
      Stream.fromIterable([
        for (final b in rows)
          [
            b.id,
            b.sessionId,
            b.ts,
            b.slot,
            b.lxcPath,
            b.bytes,
            b.gameIdBefore,
            b.note,
          ],
      ]),
    );
  }
}

/// A default filename with the date in it, so successive exports don't overwrite.
String defaultAuditExportName([DateTime? now]) {
  final d = (now ?? DateTime.now()).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'world-keeper-audit-${d.year}-${two(d.month)}-${two(d.day)}.zip';
}

/// A compact, fixed-width timestamp for a log row: `07-28 13:51:33`, local time.
///
/// The stored value is a full RFC-3339 UTC string with microseconds
/// (`2026-07-28T13:51:33.117100Z`), which is right for the record and wrong for a list —
/// it is 27 characters of mostly-constant text that wraps onto two lines and buries the
/// part that differs between rows. Every row renders to the same width here, so the
/// column reads as a column. The exact stored value is still one tap away.
String formatAuditTimestamp(String raw, {bool timeOnly = false}) {
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw;

  String two(int v) => v.toString().padLeft(2, '0');
  final time =
      '${two(parsed.hour)}:${two(parsed.minute)}:${two(parsed.second)}';
  return timeOnly ? time : '${two(parsed.month)}-${two(parsed.day)}  $time';
}

/// Both readings of a timestamp, for the expanded view.
///
/// Local time answers "when did I do this"; the stored UTC value is what appears in the
/// export and in the server's own logs, so neither one alone is sufficient.
String formatAuditTimestampFull(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final local = parsed.toLocal().toString().split('.').first;
  return '$local  (local)\n$raw  (UTC, as stored)';
}

/// Pretty-prints a JSON detail column for the expanded row view.
///
/// Returns the original text when it is not valid JSON — a detail column is only ever
/// written by this app, but a hand-edited database should display rather than blow up.
String prettyJson(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
  } on FormatException {
    return raw;
  }
}
