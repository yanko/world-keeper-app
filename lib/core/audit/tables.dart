import 'package:drift/drift.dart';

/// Audit schema — a forensic trail of every session, connection, remote command, state
/// transition, backup and error.
///
/// Column names and types mirror the Rust app's SQLite schema exactly, so an existing
/// `ckmanager.db` can be imported row for row (see `legacy_import.dart`). Notably
/// `backups.lxc_path` keeps its historical name even though targets are no longer
/// LXC-specific — renaming it would break the import for no benefit.
///
/// The one structural difference: this schema is versioned and migrated by drift. The
/// Rust version issues `CREATE TABLE IF NOT EXISTS` and has no migration mechanism at
/// all, so adding a column later would silently not exist on an existing install and
/// throw at query time.
///
/// Secrets are never recorded — only *which* key or user was used.

@DataClassName('AuditSession')
class AuditSessions extends Table {
  @override
  String get tableName => 'sessions';

  IntColumn get id => integer().autoIncrement()();

  /// RFC-3339 UTC.
  TextColumn get startedAt => text().named('started_at')();
  TextColumn get appVersion => text().named('app_version').nullable()();
  TextColumn get profileId => text().named('profile_id').nullable()();
  TextColumn get host => text().nullable()();
  TextColumn get sshUser => text().named('ssh_user').nullable()();

  /// `key` | `password`.
  TextColumn get authMethod => text().named('auth_method').nullable()();
}

@DataClassName('AuditEvent')
class AuditEvents extends Table {
  @override
  String get tableName => 'events';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().named('session_id').nullable().references(AuditSessions, #id)();
  TextColumn get ts => text()();

  /// `app_start`, `connect`, `disconnect`, `discover`, `discover_confirmed`,
  /// `key_auth_setup`, `push_begin`, `push_done`, `pull_begin`, `pull_done`,
  /// `restore_begin`, `restore_done`, `state_enter`, `error`, `audit_cleared`.
  TextColumn get kind => text()();

  /// The envelope state, when [kind] is `state_enter`.
  TextColumn get state => text().nullable()();

  /// Structured payload, stored as a JSON string.
  TextColumn get detailJson => text().named('detail_json').nullable()();

  /// 1 success / 0 failure / NULL not applicable.
  IntColumn get ok => integer().nullable()();
}

@DataClassName('AuditFileOp')
class AuditFileOps extends Table {
  @override
  String get tableName => 'file_ops';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId =>
      integer().named('event_id').nullable().references(AuditEvents, #id)();

  /// `upload`, `download`, `backup`, `copy`, `chown`, `delete`.
  TextColumn get op => text().nullable()();
  TextColumn get src => text().nullable()();
  TextColumn get dst => text().nullable()();
  IntColumn get bytes => integer().nullable()();
  IntColumn get slot => integer().nullable()();
}

@DataClassName('AuditBackup')
class AuditBackups extends Table {
  @override
  String get tableName => 'backups';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().named('session_id').nullable().references(AuditSessions, #id)();
  TextColumn get ts => text()();
  IntColumn get slot => integer().nullable()();

  /// Remote path of the dated backup directory. Historical column name — see the class
  /// doc; the value is just a remote path, LXC or otherwise.
  TextColumn get lxcPath => text().named('lxc_path').nullable()();
  IntColumn get bytes => integer().nullable()();
  TextColumn get gameIdBefore => text().named('game_id_before').nullable()();
  TextColumn get note => text().nullable()();
}

@DataClassName('AuditSshCommand')
class AuditSshCommands extends Table {
  @override
  String get tableName => 'ssh_commands';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().named('session_id').nullable().references(AuditSessions, #id)();
  TextColumn get ts => text()();
  TextColumn get command => text()();

  /// NULL when the command never returned an exit status (transport failure).
  IntColumn get exitCode => integer().named('exit_code').nullable()();

  /// Truncated — see `AuditDatabase.captureTruncateLength`.
  TextColumn get stdout => text().nullable()();
  TextColumn get stderr => text().nullable()();
  IntColumn get durationMs => integer().named('duration_ms').nullable()();
}

@DataClassName('AuditError')
class AuditErrors extends Table {
  @override
  String get tableName => 'errors';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().named('session_id').nullable().references(AuditSessions, #id)();
  TextColumn get ts => text()();

  /// Which operation failed: `connect`, `discovery`, `push`, `pull`, `restore`,
  /// `ssh_exec`, … — matches `WkException.context`.
  TextColumn get context => text()();
  TextColumn get message => text()();
  TextColumn get detailJson => text().named('detail_json').nullable()();
}
