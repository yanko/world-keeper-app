import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/audit/audit_export.dart';

void main() {
  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_export_test');
    db = AuditDatabaseFactory.inMemory();
    sessionId = await db.startSession('1.0.0');

    await db.recordConnect(
      sessionId,
      profileId: 'p1',
      host: '10.0.0.68',
      sshUser: 'root',
      authMethod: 'key',
    );
    await db.logEvent(sessionId, 'push_begin', detail: {'slot': 0});
    await db.logEvent(sessionId, 'push_done', detail: {'slot': 0}, ok: true);
    await db.logSshCommand(
      sessionId,
      command: "systemctl stop 'corekeeper'",
      exitCode: 0,
      stdout: 'stopped',
      stderr: '',
      durationMs: 900,
    );
    await db.logError(
      sessionId,
      context: 'push',
      message: 'verification failed',
    );
    await db.logBackup(
      sessionId,
      slot: 0,
      remotePath: '/worlds/.backups/0.2026-07-28_120000',
      bytes: 10_000_000,
      note: 'pre-restore safety backup',
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<Archive> exportAndOpen({File? databaseFile}) async {
    final dest = p.join(tempDir.path, 'audit.zip');
    await AuditExporter(db).exportTo(dest, databaseFile: databaseFile);
    return ZipDecoder().decodeBytes(File(dest).readAsBytesSync());
  }

  test('produces a CSV per table', () async {
    final archive = await exportAndOpen();
    expect(
      archive.files.map((f) => f.name),
      containsAll([
        'events.csv',
        'ssh_commands.csv',
        'errors.csv',
        'sessions.csv',
        'backups.csv',
      ]),
    );
  });

  test('CSVs carry a header and the rows', () async {
    final archive = await exportAndOpen();
    final events = String.fromCharCodes(
      archive.findFile('events.csv')!.content as List<int>,
    );

    expect(events, startsWith('id,session_id,ts,kind,state,detail_json,ok'));
    expect(events, contains('push_begin'));
    expect(events, contains('push_done'));
  });

  test('quotes fields containing commas and quotes', () async {
    // Commands are shell-quoted and full of characters that break naive CSV.
    final archive = await exportAndOpen();
    final commands = String.fromCharCodes(
      archive.findFile('ssh_commands.csv')!.content as List<int>,
    );

    expect(commands, contains('systemctl stop'));
    // Round-trip through a decoder: the real check is that it parses back cleanly.
    final rows = const CsvLineSplitter().parse(commands);
    expect(rows.first.first, 'id');
    expect(rows.length, 2, reason: 'header plus one command');
  });

  test('exports oldest first — it is a record to read through', () async {
    final archive = await exportAndOpen();
    final events = String.fromCharCodes(
      archive.findFile('events.csv')!.content as List<int>,
    );
    expect(events.indexOf('push_begin'), lessThan(events.indexOf('push_done')));
  });

  test('includes the raw database when one exists on disk', () async {
    // Both formats on purpose: the CSVs are what a human reads, the .db is the complete
    // queryable original.
    final fakeDb = File(p.join(tempDir.path, 'world_keeper.db'));
    await fakeDb.writeAsBytes(List.filled(2048, 7));

    final archive = await exportAndOpen(databaseFile: fakeDb);
    final entry = archive.findFile('world_keeper.db');
    expect(entry, isNotNull);
    expect(entry!.size, 2048);
  });

  test('an in-memory database has no file, and that is not an error', () async {
    final archive = await exportAndOpen(
      databaseFile: File(p.join(tempDir.path, 'does-not-exist.db')),
    );
    expect(archive.findFile('world_keeper.db'), isNull);
    expect(archive.findFile('events.csv'), isNotNull);
  });

  test('leaves no staging directory behind', () async {
    final before = Directory.systemTemp
        .listSync()
        .where((e) => e.path.contains('wk-audit-export-'))
        .length;
    await exportAndOpen();
    final after = Directory.systemTemp
        .listSync()
        .where((e) => e.path.contains('wk-audit-export-'))
        .length;
    expect(after, before);
  });

  test('exports an empty log without failing', () async {
    final empty = AuditDatabaseFactory.inMemory();
    addTearDown(empty.close);

    final dest = p.join(tempDir.path, 'empty.zip');
    await AuditExporter(empty).exportTo(dest);

    final archive = ZipDecoder().decodeBytes(File(dest).readAsBytesSync());
    final events = String.fromCharCodes(
      archive.findFile('events.csv')!.content as List<int>,
    );
    // Header only.
    expect(events.trim().split('\n'), hasLength(1));
  });

  group('defaultAuditExportName', () {
    test('embeds the date so exports do not overwrite each other', () {
      expect(
        defaultAuditExportName(DateTime(2026, 7, 28)),
        'world-keeper-audit-2026-07-28.zip',
      );
    });

    test('zero-pads', () {
      expect(
        defaultAuditExportName(DateTime(2026, 1, 5)),
        'world-keeper-audit-2026-01-05.zip',
      );
    });
  });

  group('formatAuditTimestamp', () {
    test('compacts a stored RFC-3339 value to a fixed-width column', () {
      // The stored form is 27 characters of mostly-constant text that wraps onto two
      // lines in a list and buries the part that differs between rows.
      final formatted = formatAuditTimestamp('2026-07-28T13:51:33.117100Z');
      expect(formatted, matches(RegExp(r'^\d{2}-\d{2} {2}\d{2}:\d{2}:\d{2}$')));
      expect(formatted, hasLength(15));
    });

    test('every row renders to the same width, so the column lines up', () {
      final a = formatAuditTimestamp('2026-01-05T01:02:03.000001Z');
      final b = formatAuditTimestamp('2026-12-31T23:59:59.999999Z');
      expect(a.length, b.length);
    });

    test('timeOnly drops the date for narrow layouts', () {
      final formatted = formatAuditTimestamp(
        '2026-07-28T13:51:33.117100Z',
        timeOnly: true,
      );
      expect(formatted, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
    });

    test('renders in local time', () {
      const raw = '2026-07-28T13:51:33.117100Z';
      final expected = DateTime.parse(raw).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      expect(
        formatAuditTimestamp(raw),
        '${two(expected.month)}-${two(expected.day)}  '
        '${two(expected.hour)}:${two(expected.minute)}:${two(expected.second)}',
      );
    });

    test('returns an unparseable value unchanged rather than throwing', () {
      expect(formatAuditTimestamp('not a date'), 'not a date');
    });
  });

  group('formatAuditTimestampFull', () {
    test('gives both readings', () {
      // Local answers "when did I do this"; UTC is what the export and the server's own
      // logs use, so neither alone is enough.
      const raw = '2026-07-28T13:51:33.117100Z';
      final full = formatAuditTimestampFull(raw);

      expect(full, contains('(local)'));
      expect(full, contains(raw));
      expect(full, contains('UTC, as stored'));
    });

    test('returns an unparseable value unchanged', () {
      expect(formatAuditTimestampFull('garbage'), 'garbage');
    });
  });

  group('prettyJson', () {
    test('indents valid JSON', () {
      expect(prettyJson('{"slot":0}'), '{\n  "slot": 0\n}');
    });

    test('returns malformed input unchanged rather than throwing', () {
      // Detail columns are only written by this app, but a hand-edited database should
      // display rather than crash the row.
      expect(prettyJson('not json'), 'not json');
    });

    test('handles null and empty', () {
      expect(prettyJson(null), '');
      expect(prettyJson(''), '');
    });
  });
}

/// Minimal CSV reader, just enough to prove the export parses back.
class CsvLineSplitter {
  const CsvLineSplitter();

  List<List<String>> parse(String input) {
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        row.add(field.toString());
        field = StringBuffer();
      } else if (ch == '\n') {
        row.add(field.toString());
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
      } else if (ch != '\r') {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
