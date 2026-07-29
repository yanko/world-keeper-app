import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_queries.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/config_repository.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/ssh/host_key_store.dart';
import 'package:world_keeper/core/ssh/ssh_key_store.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/features/connection/data/connection_controller.dart';
import 'package:world_keeper/features/connection/domain/connection_status.dart';
import 'package:world_keeper/features/operations/data/operation_journal.dart';
import 'package:world_keeper/features/stats/data/stats_service.dart';
import 'package:world_keeper/features/stats/domain/server_stats.dart';

/// Application-wide providers.
///
/// Written by hand rather than generated: `riverpod_generator` and `drift_dev` pin
/// incompatible `analyzer` majors and cannot co-resolve, and drift's codegen is the more
/// valuable of the two — it buys database migrations, where Riverpod's buys syntax sugar.

/// Overridden in `main()` once the real paths are resolved.
final appPathsProvider = Provider<AppPaths>(
  (ref) => throw UnimplementedError('appPathsProvider must be overridden'),
);

/// Overridden in `main()` with the opened database.
final auditDatabaseProvider = Provider<AuditDatabase>(
  (ref) => throw UnimplementedError('auditDatabaseProvider must be overridden'),
);

/// Overridden in `main()` with the session row opened at startup.
final initialAuditSessionIdProvider = Provider<int>(
  (ref) => throw UnimplementedError(
    'initialAuditSessionIdProvider must be overridden',
  ),
);

/// The audit session row everything currently writes against.
///
/// One row per *(app run × server)*, not per app run. [AuditDatabase.recordConnect] fills
/// the profile and host into the row opened at startup — so connecting to a second profile
/// in the same run would relabel a row that already holds the first server's events,
/// attributing them to the wrong machine and hiding them from the first. Rolling to a
/// fresh row instead is what lets [auditScopeProvider] honestly claim "this server's log".
class AuditSessionController extends Notifier<int> {
  @override
  int build() => ref.watch(initialAuditSessionIdProvider);

  /// Records a connection and returns the session id to write against, rolling to a new
  /// row first when this run has already been connected somewhere else.
  Future<int> recordConnect(Profile profile) async {
    final db = ref.read(auditDatabaseProvider);
    final current = await db.sessionById(state);
    final claimed = current?.profileId;

    if (claimed != null && claimed != profile.id) {
      state = await db.startSession(current?.appVersion ?? '');
    }

    await db.recordConnect(
      state,
      profileId: profile.id,
      host: profile.host,
      sshUser: profile.user,
      authMethod: profile.auth.name,
    );
    return state;
  }
}

final auditSessionIdProvider = NotifierProvider<AuditSessionController, int>(
  AuditSessionController.new,
);

/// The server whose audit history the log screen shows.
///
/// The log spans every machine this app has ever touched, and reading one server's rows
/// while looking at another is worse than useless in a forensic record — so there is
/// always exactly one server in scope, and the screen names it.
///
/// **Connected, it is the connected one and cannot be changed.** Operating on one machine
/// while reading another's log is how you convince yourself the wrong thing happened.
///
/// **Disconnected, it is whichever the user picks** from the servers that have logs. That
/// is the case the record is most often wanted in: the host is unreachable and you want to
/// know what was done to it. Defaults to the most recently used.
///
/// Keyed on the profile id rather than the host, because two profiles can point at the
/// same machine as different users, and the id is what `recordConnect` writes.
class AuditScopeController extends Notifier<AuditScope?> {
  /// Only meaningful while disconnected; a connection overrides it.
  String? _picked;

  @override
  AuditScope? build() {
    final status = ref.watch(connectionProvider);
    final profiles =
        ref.watch(auditedProfilesProvider).asData?.value ?? const [];

    // `isConnected` covers the pre-discovery state too: a host you have authenticated
    // against but not probed still has a history worth reading.
    if (status.isConnected) {
      final profile = status.profile!;
      return AuditScope(
        profileId: profile.id,
        name: profile.name,
        where: '${profile.user}@${profile.host}',
        locked: true,
      );
    }

    if (profiles.isEmpty) return null;

    final config = ref.watch(configProvider).asData?.value;
    final chosen =
        profiles.firstWhereOrNull((p) => p.profileId == _picked) ??
        profiles.first;

    return AuditScope(
      profileId: chosen.profileId,
      // The configured name when the profile still exists; otherwise say plainly that it
      // does not, rather than showing a bare id and letting the user wonder.
      name: config?.profileById(chosen.profileId)?.name ?? 'Deleted profile',
      where: chosen.where,
      locked: false,
    );
  }

  /// Picks a server to read. Ignored while connected — the connection wins.
  void select(String profileId) {
    if (state?.locked ?? false) return;
    _picked = profileId;
    ref.invalidateSelf();
  }
}

final auditScopeProvider = NotifierProvider<AuditScopeController, AuditScope?>(
  AuditScopeController.new,
);

/// The servers the audit log has rows for, for the picker.
final auditedProfilesProvider = FutureProvider<List<AuditedProfile>>(
  (ref) => ref.watch(auditDatabaseProvider).listAuditedProfiles(),
);

class AuditScope {
  const AuditScope({
    required this.profileId,
    required this.name,
    required this.where,
    required this.locked,
  });

  final String profileId;
  final String name;

  /// `user@host`, for the header line.
  final String where;

  /// True when a live connection is dictating the scope, so the picker is read-only.
  final bool locked;

  @override
  bool operator ==(Object other) =>
      other is AuditScope &&
      other.profileId == profileId &&
      other.name == name &&
      other.where == where &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(profileId, name, where, locked);
}

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepository(ref.watch(appPathsProvider)),
);

final hostKeyStoreProvider = Provider<HostKeyStore>((ref) {
  final paths = ref.watch(appPathsProvider);
  return HostKeyStore(
    File('${paths.dataDir.path}${Platform.pathSeparator}known_hosts.json'),
  );
});

/// A destructive operation that never reported a result, if there is one for the server
/// currently connected.
///
/// Scoped to the connection on purpose: the marker names a profile, and a stale one from
/// another host is not this server's problem. Offering to start a service on the wrong
/// machine would be worse than saying nothing at all.
final interruptedOperationProvider = FutureProvider<InterruptedOperation?>((
  ref,
) async {
  final profileId = ref.watch(connectionProvider).profile?.id;
  if (profileId == null) return null;

  final marker = await OperationJournal(ref.read(appPathsProvider)).read();
  return marker?.profileId == profileId ? marker : null;
});

/// The stored configuration, reloaded from disk on every mutation so the file stays the
/// single source of truth — the Rust app may be editing it too.
class ConfigController extends AsyncNotifier<AppConfig> {
  ConfigRepository get _repo => ref.read(configRepositoryProvider);

  @override
  Future<AppConfig> build() => _repo.load();

  Future<void> upsertProfile(Profile profile) async {
    state = AsyncData(await _repo.upsertProfile(profile));
  }

  /// Removes the profile and the private key generated for it.
  ///
  /// The key goes too because it exists only to authenticate to this profile's host, and
  /// leaving it behind would accumulate orphaned credentials in the data directory with
  /// nothing left to say what they were for. The corresponding line in the host's
  /// `authorized_keys` is *not* removed — this app cannot reach a server it no longer has
  /// a profile for, and pretending otherwise would be worse than saying so. Deleting that
  /// line is the user's to do, and the delete dialog says as much.
  Future<void> deleteProfile(String profileId) async {
    state = AsyncData(await _repo.deleteProfile(profileId));
    await SshKeyStore(ref.read(appPathsProvider)).delete(profileId);
  }

  Future<void> setActiveProfile(String profileId) async {
    state = AsyncData(await _repo.setActiveProfile(profileId));
  }

  Future<void> setDiscovered(String profileId, Discovered discovered) async {
    state = AsyncData(await _repo.setDiscovered(profileId, discovered));
  }

  Future<void> reload() async {
    state = AsyncData(await _repo.load());
  }
}

final configProvider = AsyncNotifierProvider<ConfigController, AppConfig>(
  ConfigController.new,
);

final connectionProvider =
    NotifierProvider<ConnectionController, ConnectionStatus>(
      ConnectionController.new,
    );

/// Which profile the connection bar has selected. Distinct from
/// [AppConfig.activeProfileId], which is the persisted preference — this is the
/// in-session selection, and it is what Connect acts on.
final selectedProfileIdProvider = NotifierProvider<SelectedProfileId, String?>(
  SelectedProfileId.new,
);

class SelectedProfileId extends Notifier<String?> {
  @override
  String? build() {
    // Defaults to the persisted active profile, then to the first one that exists.
    final config = ref.watch(configProvider).asData?.value;
    if (config == null) return null;
    final active = config.activeProfileId;
    if (active != null && config.profileById(active) != null) return active;
    return config.profiles.firstOrNull?.id;
  }

  void select(String profileId) {
    state = profileId;
    // Best-effort persistence; a failure here must not block connecting.
    ref.read(configProvider.notifier).setActiveProfile(profileId).ignore();
  }
}

/// The confirmed target, or `null` when not connected or not yet discovered.
///
/// Everything that operates on the server depends on *this* rather than on
/// [connectionProvider] directly. That keeps those layers indifferent to how a connection
/// was established — and makes them testable, since a fake target can be substituted
/// without constructing a real SSH session.
final targetProvider = Provider<ServerTarget?>(
  (ref) => ref.watch(connectionProvider).target,
);

/// A live stats stream, polled while anything is watching it.
///
/// `autoDispose` matters: the poll stops the moment the stats screen is no longer
/// mounted, rather than hammering the server from a background timer nobody is reading.
final statsProvider = StreamProvider.autoDispose<ServerStats>((ref) async* {
  final target = ref.watch(targetProvider);
  if (target == null) return;

  final service = StatsService(target);

  // Guards against out-of-order responses. `collect()` is several sequential round
  // trips and can be slow on a Docker target, so a manual refresh and a scheduled poll
  // can easily overlap — without this, whichever *resolves* last wins rather than
  // whichever was *sent* last, and the panel appears to freeze on stale data.
  var generation = 0;

  while (true) {
    final mine = ++generation;
    try {
      final stats = await service.collect();
      if (mine == generation) yield stats;
    } on Object {
      // Transient failures are normal during a stop/start; keep polling rather than
      // killing the stream.
    }
    await Future<void>.delayed(statsPollInterval);
  }
});

const Duration statsPollInterval = Duration(seconds: 5);
const Duration logDrawerPollInterval = Duration(seconds: 2);
const int logDrawerLines = 300;

/// The live log tail, polled only while the drawer is open.
///
/// Deliberately separate from [statsProvider] so watching the log does not also re-fetch
/// memory, disk and uptime on every tick.
final logTailProvider = StreamProvider.autoDispose<String>((ref) async* {
  final target = ref.watch(targetProvider);
  if (target == null) return;

  while (true) {
    try {
      yield await target.logsTail(logDrawerLines);
    } on Object {
      // Keep polling — a tail can fail mid-restart and recover on its own.
    }
    await Future<void>.delayed(logDrawerPollInterval);
  }
});
