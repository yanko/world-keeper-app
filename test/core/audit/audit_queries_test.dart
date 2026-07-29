import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/audit/audit_queries.dart';

void main() {
  late AuditDatabase db;
  late int sessionA;
  late int sessionB;

  setUp(() async {
    db = AuditDatabaseFactory.inMemory();

    sessionA = await db.startSession('1.0.0');
    await db.recordConnect(
      sessionA,
      profileId: 'p1',
      host: '10.0.0.68',
      sshUser: 'root',
      authMethod: 'key',
    );
    await db.logEvent(sessionA, 'app_start', ok: true);
    await db.logEvent(
      sessionA,
      'connect',
      detail: {'host': '10.0.0.68'},
      ok: true,
    );
    await db.logEvent(sessionA, 'state_enter', state: 'Stopping');
    await db.logEvent(sessionA, 'error', detail: {'reason': 'boom'}, ok: false);
    await db.logSshCommand(
      sessionA,
      command: "systemctl stop 'corekeeper'",
      exitCode: 0,
      stdout: '',
      stderr: '',
      durationMs: 1200,
    );
    await db.logSshCommand(
      sessionA,
      command: 'sha256sum /missing',
      exitCode: 1,
      stdout: '',
      stderr: 'no such file',
      durationMs: 40,
    );
    await db.logError(
      sessionA,
      context: 'push',
      message: 'verification failed',
      detail: {'slot': 0},
    );

    sessionB = await db.startSession('1.0.0');
    await db.logEvent(sessionB, 'app_start', ok: true);
    await db.logSshCommand(
      sessionB,
      command: 'whoami',
      exitCode: null,
      stdout: '',
      stderr: '',
      durationMs: 5,
    );
    await db.logError(sessionB, context: 'pull', message: 'timed out');
  });

  tearDown(() => db.close());

  group('events', () {
    test('returns newest first', () async {
      final rows = await db.queryEvents(const EventFilter());
      expect(rows.first.kind, 'app_start');
      expect(rows.first.sessionId, sessionB);
      // Ordered by id, not timestamp — rows written in the same second must still come
      // back in the order they happened.
      expect(
        rows.map((e) => e.id).toList(),
        isNot(rows.map((e) => e.id).toList()..sort()),
      );
    });

    test('filters by kind', () async {
      final rows = await db.queryEvents(const EventFilter(kind: 'state_enter'));
      expect(rows, hasLength(1));
      expect(rows.single.state, 'Stopping');
    });

    test('filters by session', () async {
      final rows = await db.queryEvents(EventFilter(sessionId: sessionB));
      expect(rows, hasLength(1));
    });

    test('filters by outcome', () async {
      expect(await db.queryEvents(const EventFilter(ok: false)), hasLength(1));
      expect(
        (await db.queryEvents(const EventFilter(ok: true))).length,
        greaterThan(1),
      );
      // A null `ok` is neither — an in-progress row must not count as either outcome.
      final all = await db.queryEvents(const EventFilter());
      final okCount = (await db.queryEvents(
        const EventFilter(ok: true),
      )).length;
      final failCount = (await db.queryEvents(
        const EventFilter(ok: false),
      )).length;
      expect(okCount + failCount, lessThan(all.length));
    });

    test('searches kind, state and detail together', () async {
      expect(
        await db.queryEvents(const EventFilter(search: 'Stopping')),
        hasLength(1),
      );
      expect(
        await db.queryEvents(const EventFilter(search: '10.0.0.68')),
        hasLength(1),
      );
      expect(await db.queryEvents(const EventFilter(search: 'nope')), isEmpty);
    });

    test('combines filters', () async {
      final rows = await db.queryEvents(
        EventFilter(sessionId: sessionA, ok: true),
      );
      expect(rows, hasLength(2));
    });

    test('a later page stays inside the profile it was scoped to', () async {
      // The gap this fills: every other scoping test reads page one. A filter that lost
      // its `profileId` somewhere in the `offset` path would show one server's history
      // correctly and then quietly splice another's in underneath — which is exactly the
      // failure the whole per-profile scoping exists to prevent, and the hardest to spot.
      final all = await db.queryEvents(const EventFilter(limit: 1000));
      final scoped = await db.queryEvents(
        const EventFilter(profileId: 'p1', limit: 1000),
      );

      expect(
        scoped.length,
        lessThan(all.length),
        reason: 'the fixture needs a second server for this to mean anything',
      );

      final paged = <int>{};
      for (var offset = 0; offset < scoped.length; offset += 2) {
        final page = await db.queryEvents(
          EventFilter(profileId: 'p1', limit: 2, offset: offset),
        );
        paged.addAll(page.map((e) => e.id));
      }

      expect(
        paged,
        scoped.map((e) => e.id).toSet(),
        reason:
            'paging through must return the same rows as asking for them all',
      );
    });

    test('pages with limit and offset', () async {
      final first = await db.queryEvents(const EventFilter(limit: 2));
      final second = await db.queryEvents(
        const EventFilter(limit: 2, offset: 2),
      );

      expect(first, hasLength(2));
      expect(second, isNotEmpty);
      // No overlap — paging must not repeat rows.
      expect(
        first
            .map((e) => e.id)
            .toSet()
            .intersection(second.map((e) => e.id).toSet()),
        isEmpty,
      );
    });

    test('clamps an absurd limit', () async {
      expect(const EventFilter(limit: 999999).effectiveLimit, 1000);
      expect(const EventFilter(limit: 0).effectiveLimit, 1);
      expect(const EventFilter().effectiveLimit, 200);
    });

    test('filters by time range', () async {
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      expect(
        await db.queryEvents(EventFilter(since: future.toIso8601String())),
        isEmpty,
      );
      final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
      expect(
        await db.queryEvents(EventFilter(since: past.toIso8601String())),
        isNotEmpty,
      );
    });
  });

  group('ssh commands', () {
    test('a missing exit code counts as failed, not as success', () async {
      // A transport failure returns no exit status. Treating that as success would hide
      // exactly the commands worth finding.
      final failed = await db.queryCommands(
        const CommandFilter(failedOnly: true),
      );
      expect(
        failed.map((c) => c.command),
        containsAll(['sha256sum /missing', 'whoami']),
      );

      final ok = await db.queryCommands(const CommandFilter(failedOnly: false));
      expect(ok, hasLength(1));
      expect(ok.single.command, contains('systemctl stop'));
    });

    test('searches command, stdout and stderr', () async {
      expect(
        await db.queryCommands(const CommandFilter(search: 'no such file')),
        hasLength(1),
      );
      expect(
        await db.queryCommands(const CommandFilter(search: 'systemctl')),
        hasLength(1),
      );
    });

    test('filters by session', () async {
      expect(
        await db.queryCommands(CommandFilter(sessionId: sessionB)),
        hasLength(1),
      );
    });
  });

  group('errors', () {
    test('filters by context', () async {
      final rows = await db.queryErrors(const ErrorFilter(context: 'push'));
      expect(rows, hasLength(1));
      expect(rows.single.message, 'verification failed');
    });

    test('searches message and detail', () async {
      expect(
        await db.queryErrors(const ErrorFilter(search: 'verification')),
        hasLength(1),
      );
      expect(
        await db.queryErrors(const ErrorFilter(search: 'slot')),
        hasLength(1),
        reason: 'detail_json is searched too',
      );
    });
  });

  group('facets', () {
    test('lists only the kinds that exist', () async {
      // Offering a filter for something with no rows is a dead end.
      final kinds = await db.listEventKinds();
      expect(
        kinds,
        containsAll(['app_start', 'connect', 'error', 'state_enter']),
      );
      expect(kinds, isNot(contains('push_done')));
      expect(kinds, orderedEquals([...kinds]..sort()));
    });

    test('lists only the error contexts that exist', () async {
      expect(await db.listErrorContexts(), ['pull', 'push']);
    });

    test('lists sessions newest first', () async {
      final sessions = await db.listSessions();
      expect(sessions.first.id, sessionB);
      expect(sessions.last.id, sessionA);
      expect(sessions.last.host, '10.0.0.68');
    });

    test('counts every table', () async {
      final counts = await db.counts();
      expect(counts.sessions, 2);
      expect(counts.events, 5);
      expect(counts.commands, 3);
      expect(counts.errors, 2);
      expect(counts.total, greaterThan(0));
    });
  });

  group('scoped to a profile', () {
    // The audit screen shows one server at a time, so every read has to be restricted to
    // the sessions belonging to that profile. `sessionB` is deliberately left with no
    // profile at all — a run that never connected — and must never leak into a scope.
    late int sessionC;

    setUp(() async {
      sessionC = await db.startSession('1.0.0');
      await db.recordConnect(
        sessionC,
        profileId: 'p2',
        host: '10.0.0.99',
        sshUser: 'admin',
        authMethod: 'password',
      );
      await db.logEvent(sessionC, 'push_done', ok: true);
      await db.logSshCommand(
        sessionC,
        command: 'docker restart ck',
        exitCode: 0,
        stdout: '',
        stderr: '',
        durationMs: 60,
      );
      await db.logError(
        sessionC,
        context: 'restore',
        message: 'other host failed',
      );
    });

    test('events come only from that profile', () async {
      final rows = await db.queryEvents(const EventFilter(profileId: 'p1'));
      expect(rows.map((e) => e.sessionId).toSet(), {sessionA});
      expect(rows.map((e) => e.kind), isNot(contains('push_done')));
    });

    test('commands come only from that profile', () async {
      final rows = await db.queryCommands(const CommandFilter(profileId: 'p1'));
      expect(rows.map((c) => c.sessionId).toSet(), {sessionA});
      expect(rows.map((c) => c.command), isNot(contains('docker restart ck')));
      expect(rows.map((c) => c.command), isNot(contains('whoami')));
    });

    test('errors come only from that profile', () async {
      final rows = await db.queryErrors(const ErrorFilter(profileId: 'p1'));
      expect(rows.map((e) => e.message), ['verification failed']);
    });

    test('an unknown profile returns nothing rather than everything', () async {
      // The failure mode that matters: a scope that silently degrades to "no filter"
      // shows one server's rows while the header names another.
      expect(
        await db.queryEvents(const EventFilter(profileId: 'nope')),
        isEmpty,
      );
      expect(
        await db.queryCommands(const CommandFilter(profileId: 'nope')),
        isEmpty,
      );
      expect(
        await db.queryErrors(const ErrorFilter(profileId: 'nope')),
        isEmpty,
      );
    });

    test(
      'scope composes with the other filters rather than replacing them',
      () async {
        final rows = await db.queryCommands(
          const CommandFilter(profileId: 'p1', failedOnly: true),
        );
        expect(rows.map((c) => c.command), ['sha256sum /missing']);
      },
    );

    test('sessions list only that profile', () async {
      final sessions = await db.listSessions(profileId: 'p2');
      expect(sessions.map((s) => s.id), [sessionC]);
    });

    test('kinds and contexts list only that profile', () async {
      expect(await db.listEventKinds(profileId: 'p2'), ['push_done']);
      expect(await db.listErrorContexts(profileId: 'p2'), ['restore']);
    });

    test('counts describe the scope, not the file', () async {
      final scoped = await db.counts(profileId: 'p1');
      expect(scoped.sessions, 1);
      expect(scoped.events, 4);
      expect(scoped.commands, 2);
      expect(scoped.errors, 1);

      // And unscoped still means everything, which is what the export uses.
      final all = await db.counts();
      expect(all.sessions, 3);
      expect(all.events, 6);
    });

    test('file_ops scope through their event', () async {
      // The one table with no session of its own; it hangs off an event instead.
      final eventId = await db.logEvent(sessionA, 'pull_done', ok: true);
      await db.logFileOp(
        eventId,
        op: 'download',
        src: '/a',
        dst: '/b',
        bytes: 1,
      );

      expect((await db.counts(profileId: 'p1')).fileOps, 1);
      expect((await db.counts(profileId: 'p2')).fileOps, 0);
    });
  });

  group('sessionById', () {
    test('returns the row', () async {
      final row = await db.sessionById(sessionA);
      expect(row?.profileId, 'p1');
      expect(row?.host, '10.0.0.68');
    });

    test('returns null for an id that is not there', () async {
      expect(await db.sessionById(9999), isNull);
    });
  });

  group('filter copyWith', () {
    test('replaces a value', () {
      expect(const EventFilter(kind: 'a').copyWith(kind: 'b').kind, 'b');
    });

    test('can clear a value back to null', () {
      // The reason for the sentinel: "All kinds" has to be reachable from a set filter.
      expect(const EventFilter(kind: 'a').copyWith(kind: null).kind, isNull);
      expect(
        const CommandFilter(
          failedOnly: true,
        ).copyWith(failedOnly: null).failedOnly,
        isNull,
      );
      expect(
        const ErrorFilter(context: 'push').copyWith(context: null).context,
        isNull,
      );
    });

    test('leaves untouched fields alone', () {
      const filter = EventFilter(kind: 'a', ok: true, sessionId: 3);
      final next = filter.copyWith(search: 'x');
      expect(next.kind, 'a');
      expect(next.ok, isTrue);
      expect(next.sessionId, 3);
      expect(next.search, 'x');
    });

    test('never drops the profile scope', () {
      // Losing it silently widens the query to every server the app has touched, which
      // looks like working software right up until it is read as evidence.
      const filter = EventFilter(profileId: 'p1', kind: 'a');
      expect(filter.copyWith(kind: null).profileId, 'p1');
      expect(filter.copyWith(search: 'x').profileId, 'p1');
      expect(
        const CommandFilter(
          profileId: 'p1',
        ).copyWith(failedOnly: true).profileId,
        'p1',
      );
      expect(
        const ErrorFilter(profileId: 'p1').copyWith(context: 'push').profileId,
        'p1',
      );
    });
  });
}
