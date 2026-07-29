import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';

void main() {
  late AuditDatabase db;

  setUp(() => db = AuditDatabaseFactory.inMemory());
  tearDown(() => db.close());

  group('truncateCapture', () {
    test('leaves short captures untouched', () {
      expect(AuditDatabase.truncateCapture('hello'), 'hello');
      expect(AuditDatabase.truncateCapture(''), '');
    });

    test('leaves a capture exactly at the limit untouched', () {
      final exact = 'a' * AuditDatabase.captureTruncateLength;
      expect(AuditDatabase.truncateCapture(exact), exact);
    });

    test('truncates and annotates an oversized capture', () {
      // The real driver: a `journalctl -n 200` on every stats poll would otherwise grow
      // the database without bound during an idle session.
      final huge = 'x' * (AuditDatabase.captureTruncateLength + 500);
      final result = AuditDatabase.truncateCapture(huge);
      expect(result, startsWith('x' * 100));
      expect(result, contains('truncated'));
      expect(
        result,
        contains('${AuditDatabase.captureTruncateLength + 500} bytes total'),
      );
      expect(result.length, lessThan(huge.length));
    });

    test('never splits a multi-byte character', () {
      // 'é' is 2 bytes in UTF-8, so a naive byte cut lands mid-sequence. Log output is
      // full of non-ASCII (box drawing, accented locales), so this is a real case.
      final s = 'é' * AuditDatabase.captureTruncateLength;
      final result = AuditDatabase.truncateCapture(s);
      expect(result, contains('truncated'));
      // The check that matters: the head decodes cleanly, no replacement characters.
      expect(result.split('…').first, isNot(contains('\uFFFD')));
    });

    test('measures the limit in bytes, not UTF-16 code units', () {
      // Just under the byte limit in characters, but over it in bytes.
      final s = 'é' * (AuditDatabase.captureTruncateLength ~/ 2 + 10);
      expect(
        utf8.encode(s).length,
        greaterThan(AuditDatabase.captureTruncateLength),
      );
      expect(AuditDatabase.truncateCapture(s), contains('truncated'));
    });
  });

  group('sessions and events', () {
    test('startSession returns a usable id and records a timestamp', () async {
      final id = await db.startSession('1.0.0');
      expect(id, greaterThan(0));

      final row = await (db.select(
        db.auditSessions,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(row.appVersion, '1.0.0');
      expect(DateTime.tryParse(row.startedAt), isNotNull);
      expect(row.host, isNull);
    });

    test('recordConnect fills in the connection details later', () async {
      final id = await db.startSession('1.0.0');
      await db.recordConnect(
        id,
        profileId: 'p1',
        host: '10.0.0.68',
        sshUser: 'root',
        authMethod: 'key',
      );

      final row = await (db.select(
        db.auditSessions,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(row.host, '10.0.0.68');
      expect(row.sshUser, 'root');
      expect(row.authMethod, 'key');
      // The startup fields survive the update.
      expect(row.appVersion, '1.0.0');
    });

    test('logEvent stores detail as JSON and maps ok to 1/0/null', () async {
      final id = await db.startSession('1.0.0');
      await db.logEvent(id, 'push_begin', detail: {'slot': 0});
      await db.logEvent(id, 'state_enter', state: 'Stopping', ok: true);
      await db.logEvent(id, 'error', ok: false);

      final rows = await db.select(db.auditEvents).get();
      expect(rows, hasLength(3));

      final begin = rows.firstWhere((e) => e.kind == 'push_begin');
      expect(jsonDecode(begin.detailJson!), {'slot': 0});
      expect(begin.ok, isNull);

      expect(rows.firstWhere((e) => e.kind == 'state_enter').state, 'Stopping');
      expect(rows.firstWhere((e) => e.kind == 'state_enter').ok, 1);
      expect(rows.firstWhere((e) => e.kind == 'error').ok, 0);
    });
  });

  group('ssh command log', () {
    test('records a command with output and duration', () async {
      final id = await db.startSession('1.0.0');
      await db.logSshCommand(
        id,
        command: "systemctl is-active 'corekeeper'",
        exitCode: 0,
        stdout: 'active\n',
        stderr: '',
        durationMs: 42,
      );

      final row = await db.select(db.auditSshCommands).getSingle();
      expect(row.command, "systemctl is-active 'corekeeper'");
      expect(row.exitCode, 0);
      expect(row.stdout, 'active\n');
      expect(row.durationMs, 42);
    });

    test(
      'a transport failure records a null exit code, not a fake one',
      () async {
        final id = await db.startSession('1.0.0');
        await db.logSshCommand(
          id,
          command: 'whoami',
          exitCode: null,
          stdout: '',
          stderr: '',
          durationMs: 5,
        );
        expect(
          (await db.select(db.auditSshCommands).getSingle()).exitCode,
          isNull,
        );
      },
    );

    test('truncates captures on the way in', () async {
      final id = await db.startSession('1.0.0');
      await db.logSshCommand(
        id,
        command: 'journalctl -n 200',
        exitCode: 0,
        stdout: 'y' * 20000,
        stderr: '',
        durationMs: 10,
      );
      final row = await db.select(db.auditSshCommands).getSingle();
      expect(row.stdout!.length, lessThan(20000));
      expect(row.stdout, contains('truncated'));
    });
  });

  group('errors and backups', () {
    test('logError records context, message and detail', () async {
      final id = await db.startSession('1.0.0');
      await db.logError(
        id,
        context: 'push',
        message: 'verification failed',
        detail: {'slot': 0, 'rollback': 'restored backup; restart issued'},
      );

      final row = await db.select(db.auditErrors).getSingle();
      expect(row.context, 'push');
      expect(row.message, 'verification failed');
      expect(
        (jsonDecode(row.detailJson!) as Map)['rollback'],
        'restored backup; restart issued',
      );
    });

    test('logBackup records the dated backup directory', () async {
      final id = await db.startSession('1.0.0');
      await db.logBackup(
        id,
        slot: 0,
        remotePath: '/worlds/.backups/0.2026-07-26_120000',
        bytes: 10_093_297,
        note: 'pre-restore safety backup',
      );

      final row = await db.select(db.auditBackups).getSingle();
      expect(row.slot, 0);
      expect(row.lxcPath, '/worlds/.backups/0.2026-07-26_120000');
      expect(row.bytes, 10_093_297);
      expect(row.note, 'pre-restore safety backup');
    });

    test('logFileOp links to its event', () async {
      final sessionId = await db.startSession('1.0.0');
      final eventId = await db.logEvent(
        sessionId,
        'state_enter',
        state: 'Copying',
      );
      await db.logFileOp(
        eventId,
        op: 'upload',
        src: r'C:\worlds\0.world.gzip',
        dst: '/worlds/.staging/0.world.gzip',
        bytes: 5_046_105,
        slot: 0,
      );

      final row = await db.select(db.auditFileOps).getSingle();
      expect(row.eventId, eventId);
      expect(row.op, 'upload');
      expect(row.bytes, 5_046_105);
    });
  });

  group('clearAuditLogForProfile', () {
    late int aliveSession;
    late int otherSession;
    late int liveSession;

    setUp(() async {
      // A finished session for the server being cleared…
      aliveSession = await db.startSession('1.0.0');
      await db.recordConnect(
        aliveSession,
        profileId: 'p1',
        host: '10.0.0.68',
        sshUser: 'root',
        authMethod: 'key',
      );
      final eventId = await db.logEvent(aliveSession, 'push_done', ok: true);
      await db.logFileOp(eventId, op: 'upload', src: '/a', dst: '/b', bytes: 1);
      await db.logError(aliveSession, context: 'push', message: 'boom');
      await db.logBackup(aliveSession, slot: 0, remotePath: '/b', bytes: 1);
      await db.logSshCommand(
        aliveSession,
        command: 'ls',
        exitCode: 0,
        stdout: '',
        stderr: '',
        durationMs: 1,
      );

      // …a second server that must survive untouched…
      otherSession = await db.startSession('1.0.0');
      await db.recordConnect(
        otherSession,
        profileId: 'p2',
        host: '10.0.0.99',
        sshUser: 'admin',
        authMethod: 'password',
      );
      final otherEvent = await db.logEvent(otherSession, 'pull_done', ok: true);
      await db.logFileOp(
        otherEvent,
        op: 'download',
        src: '/x',
        dst: '/y',
        bytes: 2,
      );
      await db.logError(otherSession, context: 'pull', message: 'other');
      await db.logBackup(otherSession, slot: 1, remotePath: '/c', bytes: 2);
      await db.logSshCommand(
        otherSession,
        command: 'whoami',
        exitCode: 0,
        stdout: '',
        stderr: '',
        durationMs: 1,
      );

      // …and the live row, which belongs to the server being cleared.
      liveSession = await db.startSession('1.0.0');
      await db.recordConnect(
        liveSession,
        profileId: 'p1',
        host: '10.0.0.68',
        sshUser: 'root',
        authMethod: 'key',
      );
      await db.logEvent(liveSession, 'connect', ok: true);
    });

    test('clears that server across every table', () async {
      await db.clearAuditLogForProfile('p1', liveSession);

      final events = await db.select(db.auditEvents).get();
      expect(events.map((e) => e.kind), isNot(contains('push_done')));
      expect(events.map((e) => e.kind), isNot(contains('connect')));

      // Nothing of p1's is left in any table.
      final errors = await db.select(db.auditErrors).get();
      expect(errors.map((e) => e.sessionId), isNot(contains(aliveSession)));
      final backups = await db.select(db.auditBackups).get();
      expect(backups.map((b) => b.sessionId), isNot(contains(aliveSession)));
      final commands = await db.select(db.auditSshCommands).get();
      expect(commands.map((c) => c.command), isNot(contains('ls')));
      final fileOps = await db.select(db.auditFileOps).get();
      expect(fileOps.map((f) => f.op), isNot(contains('upload')));
    });

    test('leaves the other server completely alone', () async {
      await db.clearAuditLogForProfile('p1', liveSession);

      expect(await db.select(db.auditErrors).get(), hasLength(1));
      expect(await db.select(db.auditBackups).get(), hasLength(1));
      expect(await db.select(db.auditSshCommands).get(), hasLength(1));
      // `file_ops` is the one table with no session of its own — it scopes through its
      // event, which is exactly where a scoped delete goes wrong if it is careless.
      final fileOps = await db.select(db.auditFileOps).get();
      expect(fileOps.map((f) => f.op), ['download']);
    });

    test(
      'keeps the live session row and drops the profile\'s finished ones',
      () async {
        await db.clearAuditLogForProfile('p1', liveSession);

        final sessions = await db.select(db.auditSessions).get();
        expect(
          sessions.map((s) => s.id),
          unorderedEquals([liveSession, otherSession]),
        );
        expect(sessions.map((s) => s.id), isNot(contains(aliveSession)));
      },
    );

    test('logs the clear against the server it cleared', () async {
      await db.clearAuditLogForProfile('p1', liveSession);

      final events = await db.select(db.auditEvents).get();
      final cleared = events.singleWhere((e) => e.kind == 'audit_cleared');
      expect(cleared.sessionId, liveSession);
      expect(cleared.detailJson, contains('p1'));
    });

    test('an unknown profile deletes nothing', () async {
      // The failure that matters: a scope that quietly widens to everything.
      final before = (await db.select(db.auditEvents).get()).length;
      await db.clearAuditLogForProfile('nope', liveSession);

      final after = await db.select(db.auditEvents).get();
      expect(after.where((e) => e.kind != 'audit_cleared'), hasLength(before));
      expect(await db.select(db.auditSessions).get(), hasLength(3));
    });
  });

  test('foreign keys are enforced', () async {
    // PRAGMA foreign_keys is off by default in SQLite; the schema declares real
    // references and beforeOpen turns enforcement on.
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(result.data.values.first, 1);
  });
}
