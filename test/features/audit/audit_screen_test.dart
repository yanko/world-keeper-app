import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/audit/audit_queries.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/audit/presentation/audit_rows.dart';
import 'package:world_keeper/features/audit/presentation/audit_screen.dart';
import 'package:world_keeper/l10n/l10n.dart';

import '../../support/audit_scope.dart';

/// The connected server, in every test that has one.
const _p1 = AuditScope(
  profileId: 'p1',
  name: 'lxc-core-keeper',
  where: 'root@10.0.0.68',
  locked: true,
);

const _p2 = AuditScope(
  profileId: 'p2',
  name: 'other',
  where: 'admin@10.0.0.99',
  locked: false,
);

void main() {
  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;
  late int otherSessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_audit_ui_test');
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
      stdout: 'stopped cleanly',
      stderr: '',
      durationMs: 900,
    );
    await db.logError(
      sessionId,
      context: 'push',
      message: 'verification failed',
    );

    // A second server in the same database. Nothing below should ever show it, which is
    // the whole point of scoping the screen to the connection.
    otherSessionId = await db.startSession('1.0.0');
    await db.recordConnect(
      otherSessionId,
      profileId: 'p2',
      host: '10.0.0.99',
      sshUser: 'admin',
      authMethod: 'password',
    );
    await db.logEvent(otherSessionId, 'other_server_event', ok: true);
    await db.logSshCommand(
      otherSessionId,
      command: 'systemctl stop other-server',
      exitCode: 0,
      stdout: '',
      stderr: '',
      durationMs: 10,
    );
    await db.logError(
      otherSessionId,
      context: 'pull',
      message: 'other server failure',
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    AuditScope? scope = _p1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          auditDatabaseProvider.overrideWithValue(db),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
          // Stands in for a live connection. The real controller derives this from
          // `connectionProvider`, whose connected states hold an `SshSession` that cannot
          // be constructed in a widget test — that mapping is covered separately.
          auditScopeProvider.overrideWith(() => FixedAuditScope(scope)),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          theme: WkTheme.dark(),
          home: const Scaffold(body: AuditScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('desktop', () {
    testWidgets('shows the three views and a summary', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      expect(find.textContaining('Audit log'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('SSH commands'), findsOneWidget);
      expect(find.text('Errors'), findsOneWidget);
      // Counts come from the database, not a guess.
      expect(find.textContaining('1 sessions'), findsOneWidget);
      expect(find.textContaining('2 events'), findsOneWidget);
    });

    testWidgets('lists events newest first', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      expect(find.text('push_done'), findsOneWidget);
      expect(find.text('push_begin'), findsOneWidget);

      final done = tester.getTopLeft(find.text('push_done'));
      final begin = tester.getTopLeft(find.text('push_begin'));
      expect(done.dy, lessThan(begin.dy));
    });

    testWidgets('expands a row to show its detail', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      // The JSON payload is collapsed until asked for.
      expect(find.textContaining('"slot": 0'), findsNothing);

      await tester.tap(find.text('push_done'));
      await tester.pumpAndSettle();

      expect(find.textContaining('"slot": 0'), findsOneWidget);
    });

    testWidgets('shows a compact timestamp, not the raw stored value', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1440, 900));

      // 27 characters of RFC-3339 wraps onto two lines and buries what differs.
      expect(find.textContaining('T13:'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              RegExp(r'^\d{2}-\d{2} {2}\d{2}:\d{2}:\d{2}$').hasMatch(w.data!),
        ),
        findsWidgets,
      );
    });

    testWidgets('the payload sits close to its event, not halfway across', (
      tester,
    ) async {
      // Giving the title a share of the leftover width pushed `app_start`'s payload to
      // roughly the middle of a 1440 px window. The title column is now sized to the
      // event vocabulary instead.
      await pumpAt(tester, const Size(1440, 900));

      final title = tester.getTopLeft(find.text('push_done'));
      final payload = tester.getTopLeft(find.textContaining('"slot":0').first);

      expect(
        payload.dx - title.dx,
        lessThan(220),
        reason: 'the payload should follow the event closely',
      );
    });

    testWidgets('payloads line up down the list', (tester) async {
      // Close to the event, but still a column — the two goals are not in conflict.
      await pumpAt(tester, const Size(1440, 900));

      final payloads = tester
          .widgetList<Text>(find.textContaining('"slot":0'))
          .toList();
      expect(payloads.length, 2);

      final offsets = find
          .textContaining('"slot":0')
          .evaluate()
          .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dx)
          .toSet();
      expect(offsets, hasLength(1), reason: 'same x for every row');
    });

    testWidgets('nothing in a collapsed row wraps', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.maxLines != null);
      expect(texts, isNotEmpty);
      for (final t in texts) {
        expect(t.maxLines, 1, reason: 'collapsed rows stay on one line');
      }
    });

    testWidgets('expanding reveals the exact stored timestamp', (tester) async {
      // The row abbreviates deliberately, so the precise value has to be one tap away.
      await pumpAt(tester, const Size(1440, 900));

      await tester.tap(find.text('push_done'));
      await tester.pumpAndSettle();

      expect(find.textContaining('UTC, as stored'), findsOneWidget);
      expect(find.textContaining('(local)'), findsOneWidget);
    });

    testWidgets('a row with no payload still expands', (tester) async {
      // Every row carries a timestamp worth seeing in full, payload or not.
      await db.logEvent(sessionId, 'disconnect');
      await pumpAt(tester, const Size(1440, 900));

      await tester.tap(find.text('disconnect'));
      await tester.pumpAndSettle();

      expect(find.textContaining('UTC, as stored'), findsOneWidget);
    });

    testWidgets('switches to the commands view', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      await tester.tap(find.text('SSH commands'));
      await tester.pumpAndSettle();

      expect(find.textContaining('systemctl stop'), findsOneWidget);
      expect(find.text('0'), findsWidgets, reason: 'exit code badge');
    });

    testWidgets('switches to the errors view', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();

      expect(find.text('verification failed'), findsOneWidget);
      expect(find.text('push'), findsOneWidget, reason: 'context badge');
    });

    testWidgets('offers export and clear', (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });
  });

  group('scoped to the connection', () {
    testWidgets('with no server in scope there is no log and no tabs', (
      tester,
    ) async {
      // Only reachable when the log holds nothing at all — otherwise the picker always
      // has something to select.
      await pumpAt(tester, const Size(1440, 900), scope: null);

      expect(find.text('Nothing recorded yet'), findsOneWidget);
      expect(find.text('push_done'), findsNothing);
      expect(find.text('other_server_event'), findsNothing);
      expect(find.text('Events'), findsNothing, reason: 'no tabs either');
    });

    testWidgets('names the server in scope', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      expect(find.textContaining('lxc-core-keeper'), findsOneWidget);
      expect(find.textContaining('root@10.0.0.68'), findsOneWidget);
    });

    testWidgets('events come from the connected server only', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      expect(find.text('push_done'), findsOneWidget);
      expect(find.text('other_server_event'), findsNothing);
    });

    testWidgets('commands come from the connected server only', (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      await tester.tap(find.text('SSH commands'));
      await tester.pumpAndSettle();

      expect(find.textContaining('systemctl stop'), findsOneWidget);
      expect(find.textContaining('other-server'), findsNothing);
    });

    testWidgets('errors come from the connected server only', (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();

      expect(find.text('verification failed'), findsOneWidget);
      expect(find.text('other server failure'), findsNothing);
    });

    testWidgets('the counts describe what is on screen, not the whole file', (
      tester,
    ) async {
      // 2 events for p1 and 1 for p2 are in the database; the header must say 2.
      await pumpAt(tester, const Size(1440, 900));

      expect(find.textContaining('1 sessions'), findsOneWidget);
      expect(find.textContaining('2 events'), findsOneWidget);
      expect(find.textContaining('1 commands'), findsOneWidget);
    });

    testWidgets('the session filter offers only this server\'s sessions', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1440, 900));

      // Tapping the label misses the control and silently does nothing, so the dropdown
      // is opened by type.
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      expect(
        find.text('All sessions'),
        findsWidgets,
        reason: 'the menu opened',
      );

      expect(find.textContaining('#$sessionId root@10.0.0.68'), findsOneWidget);
      expect(find.textContaining('#$otherSessionId'), findsNothing);
      expect(find.textContaining('admin@10.0.0.99'), findsNothing);
    });

    testWidgets('the kind filter offers only this server\'s kinds', (
      tester,
    ) async {
      // A dropdown listing kinds that can never match anything on screen is a dead end.
      await pumpAt(tester, const Size(1440, 900));

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('All kinds'), findsWidgets, reason: 'the menu opened');

      expect(find.text('push_begin'), findsWidgets);
      expect(find.text('other_server_event'), findsNothing);
    });
  });

  group('reacting to the connection', () {
    testWidgets('follows connect and disconnect with no manual refresh', (
      tester,
    ) async {
      // The screen stays mounted throughout — the shell keeps every destination alive —
      // so it has to re-query on its own. The user pressed Connect, not Refresh.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
            auditDatabaseProvider.overrideWithValue(db),
            initialAuditSessionIdProvider.overrideWithValue(sessionId),
            auditScopeProvider.overrideWith(MovableAuditScope.new),
          ],
          child: MaterialApp(
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            theme: WkTheme.dark(),
            home: const Scaffold(body: AuditScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuditScreen)),
      );
      void connectTo(AuditScope? scope) =>
          (container.read(auditScopeProvider.notifier) as MovableAuditScope)
              .moveTo(scope);

      expect(find.text('push_done'), findsNothing);
      expect(find.text('Nothing recorded yet'), findsOneWidget);

      connectTo(_p1);
      await tester.pumpAndSettle();

      expect(find.text('push_done'), findsOneWidget);
      expect(find.textContaining('2 events'), findsOneWidget);

      connectTo(null);
      await tester.pumpAndSettle();

      expect(find.text('push_done'), findsNothing);
      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('reconnecting elsewhere swaps which log is shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
            auditDatabaseProvider.overrideWithValue(db),
            initialAuditSessionIdProvider.overrideWithValue(sessionId),
            auditScopeProvider.overrideWith(MovableAuditScope.new),
          ],
          child: MaterialApp(
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            theme: WkTheme.dark(),
            home: const Scaffold(body: AuditScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuditScreen)),
      );
      final scope =
          container.read(auditScopeProvider.notifier) as MovableAuditScope;
      scope.moveTo(_p1);
      await tester.pumpAndSettle();
      expect(find.text('push_done'), findsOneWidget);

      scope.moveTo(_p2);
      await tester.pumpAndSettle();

      expect(find.text('other_server_event'), findsOneWidget);
      expect(
        find.text('push_done'),
        findsNothing,
        reason: 'the old server is gone',
      );
    });
  });

  group('phone', () {
    testWidgets('lays out without overflowing', (tester) async {
      await pumpAt(tester, const Size(360, 800));
      expect(tester.takeException(), isNull);
      expect(find.text('push_done'), findsOneWidget);
    });

    testWidgets('still shows every filter — none are hidden off-screen', (
      tester,
    ) async {
      // Filters wrap rather than scroll, so a phone user can reach all of them.
      await pumpAt(tester, const Size(360, 800));
      expect(find.text('Kind'), findsOneWidget);
      expect(find.text('Session'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
    });
  });

  group('clearing while connected', () {
    /// Walks to the second prompt, where the widen-scope checkbox lives.
    Future<void> openSecondPrompt(WidgetTester tester) async {
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, clear it'));
      await tester.pumpAndSettle();
    }

    testWidgets('scopes to the connected server, and says so', (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(
        find.text('Clear the audit log for lxc-core-keeper?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Other servers are left alone'),
        findsOneWidget,
      );
    });

    testWidgets('needs two confirmations', (tester) async {
      // The one destructive action whose damage stays invisible until the day you need
      // what it deleted.
      await pumpAt(tester, const Size(1440, 900));
      await openSecondPrompt(tester);

      expect(find.text('Really? This is the black box.'), findsOneWidget);

      // Backing out at the second prompt must change nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await db.select(db.auditEvents).get(), isNotEmpty);
    });

    testWidgets('says plainly that server backups are unaffected', (
      tester,
    ) async {
      // The original had a real bug where clearing the log made real backups
      // unrestorable. It no longer can — and the copy says so.
      await pumpAt(tester, const Size(1440, 900));
      await openSecondPrompt(tester);

      expect(
        find.textContaining('Backups on the server are NOT affected'),
        findsOneWidget,
      );
    });

    testWidgets('offers no way to widen past the server on screen', (
      tester,
    ) async {
      // The picker means there is always exactly one server in scope, so Clear has one
      // meaning. No checkbox, no opt-in, no third prompt — the blast radius is the thing
      // you are looking at.
      await pumpAt(tester, const Size(1440, 900));
      await openSecondPrompt(tester);

      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.textContaining('every server'), findsNothing);
      expect(find.text('Delete it'), findsOneWidget);
    });

    testWidgets('two prompts, and only this server is cleared', (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      await openSecondPrompt(tester);

      await tester.tap(find.text('Delete it'));
      await tester.pumpAndSettle();

      expect(find.text('Every server, then.'), findsNothing);

      // p1 is gone except the trace of the clear; p2 is untouched.
      final events = await db.select(db.auditEvents).get();
      expect(
        events.map((e) => e.kind),
        containsAll(['other_server_event', 'audit_cleared']),
      );
      expect(events.map((e) => e.kind), isNot(contains('push_done')));

      expect(
        await db.queryCommands(const CommandFilter(profileId: 'p1')),
        isEmpty,
      );
      expect(
        await db.queryCommands(const CommandFilter(profileId: 'p2')),
        hasLength(1),
      );
      expect(
        await db.queryErrors(const ErrorFilter(profileId: 'p2')),
        hasLength(1),
      );

      // Both session rows survive: the live one because it is still being written to,
      // the other because it belongs to a server nobody asked to clear.
      final sessions = await db.select(db.auditSessions).get();
      expect(
        sessions.map((s) => s.id),
        containsAll([sessionId, otherSessionId]),
      );
    });

    testWidgets('backing out of the second prompt changes nothing', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1440, 900));
      await openSecondPrompt(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        await db.queryEvents(const EventFilter(profileId: 'p1')),
        isNotEmpty,
      );
      expect(
        await db.queryEvents(const EventFilter(profileId: 'p2')),
        isNotEmpty,
      );
    });

    testWidgets('clearing the picked server works while disconnected too', (
      tester,
    ) async {
      // The unreachable-host case: the log is exactly what you want, and pruning it must
      // not need a connection to the machine it is about.
      await pumpAt(tester, const Size(1440, 900), scope: _p2);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Clear the audit log for other?'), findsOneWidget);

      await tester.tap(find.text('Yes, clear it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete it'));
      await tester.pumpAndSettle();

      expect(await db.queryEvents(const EventFilter(profileId: 'p2')), isEmpty);
      expect(
        await db.queryEvents(const EventFilter(profileId: 'p1')),
        isNotEmpty,
      );
    });
  });

  group('the scope picker', () {
    testWidgets('a connected server is locked, not chosen', (tester) async {
      // Reading one machine's log while operating on another is how you convince yourself
      // the wrong thing happened.
      await pumpAt(tester, const Size(1440, 900));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.textContaining('lxc-core-keeper'), findsOneWidget);
      expect(
        find.byType(DropdownButtonFormField<String>),
        findsNothing,
        reason: 'no server dropdown while connected',
      );
    });

    testWidgets('disconnected, the server is a dropdown', (tester) async {
      await pumpAt(tester, const Size(1440, 900), scope: _p2);

      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets(
      'the empty state is about having no history, not no connection',
      (tester) async {
        await pumpAt(tester, const Size(1440, 900), scope: null);

        expect(find.text('Nothing recorded yet'), findsOneWidget);
        expect(find.text('Clear'), findsOneWidget);
        final clear = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Clear'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(clear.onPressed, isNull, reason: 'nothing to clear');
      },
    );
  });

  group('paging', () {
    // The backend has taken an `offset` since Phase 1 and the screen has had a "Load
    // more" button since Phase 7, and nothing checked that the two met.
    //
    // Only the *wiring* is checked here. Counting rendered rows would prove nothing: the
    // view is a `CustomScrollView`, whose slivers are built lazily, so the number of
    // `ExpandableAuditRow` widgets in the tree is how many are on screen rather than how
    // many were fetched. Whether page two is the right rows is a query-layer question and
    // is asserted in `audit_queries_test`.

    /// Fills the connected server's log past one page.
    Future<void> seedPages(int count) async {
      for (var i = 0; i < count; i++) {
        await db.logEvent(sessionId, 'bulk_event', detail: {'n': i}, ok: true);
      }
    }

    testWidgets('a log that fits on one page offers nothing to load', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1440, 900));
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('a full page offers more, and loading it is the end', (
      tester,
    ) async {
      // `scrollUntilVisible` rather than a bare finder: the button sits below a hundred
      // rows and a lazily-built sliver that has never been laid out is not in the tree at
      // all, so `find.text` would report it missing whether or not it exists.
      await seedPages(AuditViewState.pageSize + 20);

      // Precondition: the screen can only offer a second page if the first one is full.
      final firstPage = await db.queryEvents(
        const EventFilter(profileId: 'p1', limit: AuditViewState.pageSize),
      );
      expect(firstPage, hasLength(AuditViewState.pageSize));

      await pumpAt(tester, const Size(1440, 900));

      // Dragging on a row rather than `scrollUntilVisible`: the latter needs a
      // `Scrollable` finder, and this screen has one per tab view with only the visible
      // one built — picking the wrong one scrolls nothing and reports "No element". A row
      // is unambiguously on screen and its ancestor scrollable is the right one.
      // Dragging the *view*, not a row. A row's centre leaves the viewport as soon as
      // the list moves, and a pointer dispatched outside the scrollable hits nothing —
      // which looks exactly like a list that will not scroll. Forty drags moved it by two
      // rows before this was clear.
      var found = false;
      for (var i = 0; i < 40 && !found; i++) {
        found = find.text('Load more').evaluate().isNotEmpty;
        if (!found) {
          await tester.drag(find.byType(EventsView), const Offset(0, -400));
          await tester.pumpAndSettle();
        }
      }
      expect(found, isTrue, reason: 'a full page must offer the next one');

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      // 120 rows is one full page and one short one, and a short page means there is
      // nothing left to ask for.
      expect(find.text('Load more'), findsNothing);
    });
  });
}
