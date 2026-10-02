import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/app_info.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/audit/audit_queries.dart';
import 'package:world_keeper/core/config/models.dart';

/// A session row is what ties audit rows to a server, so it has to describe exactly one.
///
/// `recordConnect` fills the profile into the row opened at startup. Connecting to a
/// second profile in the same run would therefore relabel a row that already holds the
/// first server's events — attributing them to the wrong machine, and hiding them from the
/// right one. Rolling to a fresh row is what keeps the scoped audit view honest.
void main() {
  late AuditDatabase db;
  late int startupSession;

  const alpha = Profile(
    id: 'p1',
    name: 'alpha',
    host: '10.0.0.68',
    user: 'root',
    auth: AuthMethod.key,
  );
  const beta = Profile(
    id: 'p2',
    name: 'beta',
    host: '10.0.0.99',
    user: 'admin',
    auth: AuthMethod.password,
  );

  setUp(() async {
    db = AuditDatabaseFactory.inMemory();
    startupSession = await db.startSession('1.0.0');
  });

  tearDown(() => db.close());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        auditDatabaseProvider.overrideWithValue(db),
        initialAuditSessionIdProvider.overrideWithValue(startupSession),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the first connection claims the row opened at startup', () async {
    final container = makeContainer();
    final id = await container
        .read(auditSessionIdProvider.notifier)
        .recordConnect(alpha);

    expect(id, startupSession, reason: 'no reason to open a second row');
    final row = await db.sessionById(id);
    expect(row?.profileId, 'p1');
    expect(row?.host, '10.0.0.68');
    expect(row?.sshUser, 'root');
    expect(row?.authMethod, 'key');
  });

  test('reconnecting to the same profile reuses the row', () async {
    // Disconnect/reconnect within a run is ordinary; it should not fragment the log.
    final container = makeContainer();
    final notifier = container.read(auditSessionIdProvider.notifier);

    final first = await notifier.recordConnect(alpha);
    final second = await notifier.recordConnect(alpha);

    expect(second, first);
    expect(await db.listSessions(), hasLength(1));
  });

  test('connecting elsewhere opens a new row instead of relabelling', () async {
    final container = makeContainer();
    final notifier = container.read(auditSessionIdProvider.notifier);

    final alphaSession = await notifier.recordConnect(alpha);
    await db.logEvent(alphaSession, 'push_done', ok: true);

    final betaSession = await notifier.recordConnect(beta);
    await db.logEvent(betaSession, 'pull_done', ok: true);

    expect(betaSession, isNot(alphaSession));

    // The decisive assertion: alpha's row still says alpha, and still owns its event.
    final alphaRow = await db.sessionById(alphaSession);
    expect(alphaRow?.profileId, 'p1');
    expect(alphaRow?.host, '10.0.0.68');

    final alphaEvents = await db.queryEvents(
      const EventFilter(profileId: 'p1'),
    );
    expect(alphaEvents.map((e) => e.kind), ['push_done']);

    final betaEvents = await db.queryEvents(const EventFilter(profileId: 'p2'));
    expect(betaEvents.map((e) => e.kind), ['pull_done']);
  });

  test('the new row keeps the app version', () async {
    // A session row that cannot say which build wrote it is much less use in an
    // investigation.
    final container = makeContainer();
    final notifier = container.read(auditSessionIdProvider.notifier);

    await notifier.recordConnect(alpha);
    final rolled = await notifier.recordConnect(beta);

    expect((await db.sessionById(rolled))?.appVersion, appVersion);
  });

  test('the provider exposes the current row to everything that writes', () async {
    // `DatabaseAuditSink`, the terminal and the operation controllers all read this
    // provider; if it lagged behind, their rows would land on the previous server.
    final container = makeContainer();
    expect(container.read(auditSessionIdProvider), startupSession);

    await container.read(auditSessionIdProvider.notifier).recordConnect(alpha);
    await container.read(auditSessionIdProvider.notifier).recordConnect(beta);

    final current = container.read(auditSessionIdProvider);
    expect(current, isNot(startupSession));
    expect((await db.sessionById(current))?.profileId, 'p2');
  });
}
