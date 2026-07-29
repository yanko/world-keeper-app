import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/audit/audit_queries.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/features/connection/data/connection_controller.dart';
import 'package:world_keeper/features/connection/domain/connection_status.dart';

/// Which server the audit screen is about.
///
/// There is always exactly one, and where it comes from depends on whether anything is
/// connected. Only the states that can be built without a live socket are covered here —
/// the two connected states hold a real `SshSession` whose constructor is private, so the
/// locked branch is exercised through the screen's widget tests.
class _FakeConnection extends ConnectionController {
  _FakeConnection(this._status);

  final ConnectionStatus _status;

  @override
  ConnectionStatus build() => _status;
}

void main() {
  late Directory tempDir;
  late AuditDatabase db;

  const alpha = Profile(
    id: 'p1',
    name: 'alpha',
    host: '10.0.0.68',
    user: 'root',
    auth: AuthMethod.key,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_scope_test');
    db = AuditDatabaseFactory.inMemory();
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Records a session for [profileId] so it shows up in the picker.
  Future<void> seed(
    String profileId, {
    required String host,
    String user = 'root',
  }) async {
    final id = await db.startSession('1.0.0');
    await db.recordConnect(
      id,
      profileId: profileId,
      host: host,
      sshUser: user,
      authMethod: 'key',
    );
    await db.logEvent(id, 'connect', ok: true);
  }

  Future<ProviderContainer> containerFor(ConnectionStatus status) async {
    final container = ProviderContainer(
      overrides: [
        appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
        auditDatabaseProvider.overrideWithValue(db),
        connectionProvider.overrideWith(() => _FakeConnection(status)),
      ],
    );
    addTearDown(container.dispose);
    // The picker is fed by an async query; let it resolve before reading the scope.
    await container.read(auditedProfilesProvider.future);
    return container;
  }

  group('with no history at all', () {
    test('there is no scope, and nothing to pick', () async {
      final container = await containerFor(const Disconnected());
      expect(container.read(auditScopeProvider), isNull);
    });
  });

  group('disconnected', () {
    test('defaults to the most recently used server', () async {
      // The one you were last working on is the one you are almost certainly asking about.
      await seed('p1', host: '10.0.0.68');
      await seed('p2', host: '10.0.0.99', user: 'admin');

      final container = await containerFor(const Disconnected());
      expect(container.read(auditScopeProvider)?.profileId, 'p2');
    });

    test('the scope is not locked, so it can be changed', () async {
      await seed('p1', host: '10.0.0.68');
      final container = await containerFor(const Disconnected());
      expect(container.read(auditScopeProvider)?.locked, isFalse);
    });

    test('selecting another server changes the scope', () async {
      await seed('p1', host: '10.0.0.68');
      await seed('p2', host: '10.0.0.99', user: 'admin');

      final container = await containerFor(const Disconnected());
      container.read(auditScopeProvider.notifier).select('p1');

      final scope = container.read(auditScopeProvider);
      expect(scope?.profileId, 'p1');
      expect(scope?.where, 'root@10.0.0.68');
    });

    test('a failed connection still leaves the picker usable', () async {
      // This is exactly when the log is wanted, so a failure must not lock it out.
      await seed('p1', host: '10.0.0.68');
      final container = await containerFor(
        const Disconnected(error: 'auth failed'),
      );
      expect(container.read(auditScopeProvider), isNotNull);
    });

    test('connecting has no scope yet — nothing has authenticated', () async {
      await seed('p1', host: '10.0.0.68');
      final container = await containerFor(const Connecting(alpha));
      // A profile is selected and an attempt is in flight; `Connecting` is not connected,
      // so the picker branch applies and offers what has history.
      expect(container.read(auditScopeProvider)?.locked, isFalse);
    });

    test('a deleted profile keeps its history, and says it is deleted', () async {
      // Deleting a profile is not meant to destroy the record of what was done to that
      // machine, so its log stays readable — with a name that explains itself rather than
      // a bare id.
      await seed('gone', host: '10.0.0.5');
      final container = await containerFor(const Disconnected());

      final scope = container.read(auditScopeProvider);
      expect(scope?.profileId, 'gone');
      expect(scope?.name, 'Deleted profile');
      expect(scope?.where, 'root@10.0.0.5');
    });
  });

  group('listAuditedProfiles', () {
    test('offers only servers that actually have history', () async {
      // A profile configured this morning has nothing to read; offering it is a dead end.
      await seed('p1', host: '10.0.0.68');
      expect((await db.listAuditedProfiles()).map((p) => p.profileId), ['p1']);
    });

    test('excludes runs that never connected anywhere', () async {
      await db.startSession('1.0.0');
      await seed('p1', host: '10.0.0.68');

      final profiles = await db.listAuditedProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.single.profileId, 'p1');
    });

    test('one entry per server, however many sessions it has', () async {
      await seed('p1', host: '10.0.0.68');
      await seed('p1', host: '10.0.0.68');
      await seed('p1', host: '10.0.0.68');

      final profiles = await db.listAuditedProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.single.sessions, 3);
    });

    test('shows where a server is now, not where it first was', () async {
      // A re-addressed host should read as its current address.
      await seed('p1', host: '10.0.0.68');
      await seed('p1', host: '10.0.0.200');

      expect((await db.listAuditedProfiles()).single.where, 'root@10.0.0.200');
    });

    test('newest first', () async {
      await seed('old', host: '10.0.0.1');
      await seed('new', host: '10.0.0.2');

      expect((await db.listAuditedProfiles()).map((p) => p.profileId), [
        'new',
        'old',
      ]);
    });
  });

  group('AuditScope', () {
    test('two scopes for the same server are equal', () {
      // The screen watches this; without value equality every unrelated connection-state
      // rebuild would re-run all three queries.
      const a = AuditScope(
        profileId: 'p1',
        name: 'alpha',
        where: 'root@10.0.0.68',
        locked: true,
      );
      const b = AuditScope(
        profileId: 'p1',
        name: 'alpha',
        where: 'root@10.0.0.68',
        locked: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('locked and unlocked are not the same scope', () {
      // They render differently and permit different things, so they must not compare
      // equal or the picker would not swap when a connection drops.
      const locked = AuditScope(
        profileId: 'p1',
        name: 'alpha',
        where: 'root@10.0.0.68',
        locked: true,
      );
      expect(
        locked,
        isNot(
          const AuditScope(
            profileId: 'p1',
            name: 'alpha',
            where: 'root@10.0.0.68',
            locked: false,
          ),
        ),
      );
    });
  });
}
