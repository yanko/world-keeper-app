import 'package:drift/drift.dart';
import 'package:world_keeper/core/audit/audit_database.dart';

/// The read side of the audit log.
///
/// Everything else in `core/audit` writes; nothing has read any of it back until now.
/// Kept as typed drift queries rather than raw SQL handed to the UI — the same reasoning
/// as the original's "all real logic stays in the backend", except here the compiler
/// checks the column names too.
///
/// Free-text search uses `LIKE '%term%'`, so `%` and `_` typed by the user act as
/// wildcards. That matches the original's behaviour and is arguably useful in a search
/// box; it is deliberate rather than overlooked.
extension AuditQueries on AuditDatabase {
  static const int defaultLimit = 200;
  static const int maxLimit = 1000;

  Future<List<AuditEvent>> queryEvents(EventFilter filter) {
    final q = select(auditEvents);

    final profileId = filter.profileId;
    if (profileId != null) {
      q.where((e) => e.sessionId.isInQuery(sessionIdsForProfile(profileId)));
    }
    if (filter.kind != null) {
      q.where((e) => e.kind.equals(filter.kind!));
    }
    if (filter.sessionId != null) {
      q.where((e) => e.sessionId.equals(filter.sessionId!));
    }
    if (filter.ok != null) {
      q.where((e) => e.ok.equals(filter.ok! ? 1 : 0));
    }
    if (filter.since != null) {
      q.where((e) => e.ts.isBiggerOrEqualValue(filter.since!));
    }
    if (filter.until != null) {
      q.where((e) => e.ts.isSmallerOrEqualValue(filter.until!));
    }
    final search = filter.search;
    if (search != null && search.isNotEmpty) {
      final pattern = '%$search%';
      q.where(
        (e) =>
            e.kind.like(pattern) |
            e.state.like(pattern) |
            e.detailJson.like(pattern),
      );
    }

    // Newest first, and by id rather than timestamp: two rows written in the same second
    // must still come back in the order they happened.
    q
      ..orderBy([(e) => OrderingTerm.desc(e.id)])
      ..limit(filter.effectiveLimit, offset: filter.offset);
    return q.get();
  }

  Future<List<AuditSshCommand>> queryCommands(CommandFilter filter) {
    final q = select(auditSshCommands);

    final profileId = filter.profileId;
    if (profileId != null) {
      q.where((c) => c.sessionId.isInQuery(sessionIdsForProfile(profileId)));
    }
    if (filter.sessionId != null) {
      q.where((c) => c.sessionId.equals(filter.sessionId!));
    }
    if (filter.failedOnly != null) {
      q.where(
        (c) => filter.failedOnly!
            // A null exit code means the command never returned one — a transport
            // failure. That is a failure, so it belongs in the failed set.
            ? c.exitCode.isNull() | c.exitCode.equals(0).not()
            : c.exitCode.equals(0),
      );
    }
    if (filter.since != null) {
      q.where((c) => c.ts.isBiggerOrEqualValue(filter.since!));
    }
    if (filter.until != null) {
      q.where((c) => c.ts.isSmallerOrEqualValue(filter.until!));
    }
    final search = filter.search;
    if (search != null && search.isNotEmpty) {
      final pattern = '%$search%';
      q.where(
        (c) =>
            c.command.like(pattern) |
            c.stdout.like(pattern) |
            c.stderr.like(pattern),
      );
    }

    q
      ..orderBy([(c) => OrderingTerm.desc(c.id)])
      ..limit(filter.effectiveLimit, offset: filter.offset);
    return q.get();
  }

  Future<List<AuditError>> queryErrors(ErrorFilter filter) {
    final q = select(auditErrors);

    final profileId = filter.profileId;
    if (profileId != null) {
      q.where((e) => e.sessionId.isInQuery(sessionIdsForProfile(profileId)));
    }
    if (filter.sessionId != null) {
      q.where((e) => e.sessionId.equals(filter.sessionId!));
    }
    if (filter.context != null) {
      q.where((e) => e.context.equals(filter.context!));
    }
    if (filter.since != null) {
      q.where((e) => e.ts.isBiggerOrEqualValue(filter.since!));
    }
    if (filter.until != null) {
      q.where((e) => e.ts.isSmallerOrEqualValue(filter.until!));
    }
    final search = filter.search;
    if (search != null && search.isNotEmpty) {
      final pattern = '%$search%';
      q.where(
        (e) =>
            e.context.like(pattern) |
            e.message.like(pattern) |
            e.detailJson.like(pattern),
      );
    }

    q
      ..orderBy([(e) => OrderingTerm.desc(e.id)])
      ..limit(filter.effectiveLimit, offset: filter.offset);
    return q.get();
  }

  /// The servers this log actually has rows for, newest first.
  ///
  /// Derived from the log rather than from `config.json` on purpose. The question the
  /// picker answers is "whose history can I read", and a profile configured this morning
  /// has none — offering it is a dead end. It also keeps a *deleted* profile's history
  /// reachable, which matters: deleting a profile is not meant to destroy the record of
  /// what was done to that machine.
  ///
  /// Sessions with no profile — a run that never connected — are excluded, since there is
  /// no server they could be attributed to.
  Future<List<AuditedProfile>> listAuditedProfiles() async {
    final rows = await customSelect(
      'SELECT profile_id, '
      '       MAX(id) AS last_session, '
      '       COUNT(*) AS sessions, '
      // The most recent non-null host/user wins, so a renamed or re-addressed server shows
      // where it is now rather than where it first was.
      '       (SELECT host FROM sessions s2 '
      '         WHERE s2.profile_id = s.profile_id AND s2.host IS NOT NULL '
      '         ORDER BY s2.id DESC LIMIT 1) AS host, '
      '       (SELECT ssh_user FROM sessions s3 '
      '         WHERE s3.profile_id = s.profile_id AND s3.ssh_user IS NOT NULL '
      '         ORDER BY s3.id DESC LIMIT 1) AS ssh_user '
      '  FROM sessions s '
      ' WHERE profile_id IS NOT NULL '
      ' GROUP BY profile_id '
      ' ORDER BY last_session DESC',
      readsFrom: {auditSessions},
    ).get();

    return [
      for (final r in rows)
        AuditedProfile(
          profileId: r.read<String>('profile_id'),
          host: r.read<String?>('host'),
          sshUser: r.read<String?>('ssh_user'),
          sessions: r.read<int>('sessions'),
        ),
    ];
  }

  /// One session row by id — used to tell whether the live session already belongs to a
  /// different server before [AuditDatabase.recordConnect] relabels it.
  Future<AuditSession?> sessionById(int id) =>
      (select(auditSessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Sessions, newest first, for the session filter.
  Future<List<AuditSession>> listSessions({
    int limit = 100,
    String? profileId,
  }) {
    final q = select(auditSessions);
    if (profileId != null) q.where((s) => s.profileId.equals(profileId));
    q
      ..orderBy([(s) => OrderingTerm.desc(s.id)])
      ..limit(limit);
    return q.get();
  }

  /// The distinct event kinds actually present, so the filter offers only what exists
  /// rather than a hard-coded list that drifts from reality.
  Future<List<String>> listEventKinds({String? profileId}) async {
    final rows = await customSelect(
      'SELECT DISTINCT kind FROM events'
      '${profileId == null ? '' : ' WHERE $_bySession'} ORDER BY kind',
      variables: _scopeVariables(profileId),
      readsFrom: {auditEvents},
    ).get();
    return [for (final r in rows) r.read<String>('kind')];
  }

  Future<List<String>> listErrorContexts({String? profileId}) async {
    final rows = await customSelect(
      'SELECT DISTINCT context FROM errors'
      '${profileId == null ? '' : ' WHERE $_bySession'} ORDER BY context',
      variables: _scopeVariables(profileId),
      readsFrom: {auditErrors},
    ).get();
    return [for (final r in rows) r.read<String>('context')];
  }

  /// Row counts per table, for the summary line. Scoped to one server when [profileId] is
  /// given, so the header describes what is actually on screen.
  Future<AuditCounts> counts({String? profileId}) async {
    final variables = _scopeVariables(profileId);

    Future<int> countOf(String table, String scope) async {
      final row = await customSelect(
        'SELECT COUNT(*) AS c FROM $table'
        '${profileId == null ? '' : ' WHERE $scope'}',
        variables: variables,
      ).getSingle();
      return row.read<int>('c');
    }

    return AuditCounts(
      sessions: await countOf('sessions', 'profile_id = ?'),
      events: await countOf('events', _bySession),
      commands: await countOf('ssh_commands', _bySession),
      errors: await countOf('errors', _bySession),
      backups: await countOf('backups', _bySession),
      // `file_ops` hangs off an event rather than a session, so it scopes one hop further
      // out.
      fileOps: await countOf('file_ops', _byEvent),
    );
  }

  static List<Variable<Object>> _scopeVariables(String? profileId) =>
      profileId == null ? const [] : [Variable<String>(profileId)];
}

const String _bySession =
    'session_id IN (SELECT id FROM sessions WHERE profile_id = ?)';
const String _byEvent = 'event_id IN (SELECT id FROM events WHERE $_bySession)';

/// A server the audit log holds rows for.
class AuditedProfile {
  const AuditedProfile({
    required this.profileId,
    required this.host,
    required this.sshUser,
    required this.sessions,
  });

  final String profileId;
  final String? host;
  final String? sshUser;
  final int sessions;

  /// `user@host`, or the raw id when a session was recorded before either was known.
  String get where {
    final parts = [sshUser, host].where((v) => v != null && v.isNotEmpty);
    return parts.isEmpty ? profileId : parts.join('@');
  }
}

class AuditCounts {
  const AuditCounts({
    required this.sessions,
    required this.events,
    required this.commands,
    required this.errors,
    required this.backups,
    required this.fileOps,
  });

  final int sessions;
  final int events;
  final int commands;
  final int errors;
  final int backups;
  final int fileOps;

  int get total => events + commands + errors + backups + fileOps;
}

/// Shared paging and time-range fields.
abstract class _BaseFilter {
  const _BaseFilter({
    this.profileId,
    this.sessionId,
    this.search,
    this.since,
    this.until,
    this.limit,
    this.offset = 0,
  });

  /// Restricts the result to sessions recorded against one profile.
  ///
  /// Not a filter the user sets — it comes from the live connection, and it is what makes
  /// the audit screen show *this* server's history rather than every machine the app has
  /// ever touched. Null means unscoped, which is what the export uses.
  final String? profileId;

  final int? sessionId;
  final String? search;

  /// Inclusive ISO-8601 bounds on the timestamp.
  final String? since;
  final String? until;

  final int? limit;
  final int offset;

  /// Clamped, so a caller cannot ask for the whole table by accident.
  int get effectiveLimit =>
      (limit ?? AuditQueries.defaultLimit).clamp(1, AuditQueries.maxLimit);
}

class EventFilter extends _BaseFilter {
  const EventFilter({
    this.kind,
    this.ok,
    super.profileId,
    super.sessionId,
    super.search,
    super.since,
    super.until,
    super.limit,
    super.offset,
  });

  final String? kind;

  /// `true` succeeded, `false` failed, `null` either.
  final bool? ok;

  EventFilter copyWith({
    Object? kind = _unset,
    Object? ok = _unset,
    Object? sessionId = _unset,
    String? search,
    int? offset,
  }) => EventFilter(
    kind: kind == _unset ? this.kind : kind as String?,
    ok: ok == _unset ? this.ok : ok as bool?,
    profileId: profileId,
    sessionId: sessionId == _unset ? this.sessionId : sessionId as int?,
    search: search ?? this.search,
    since: since,
    until: until,
    limit: limit,
    offset: offset ?? this.offset,
  );
}

class CommandFilter extends _BaseFilter {
  const CommandFilter({
    this.failedOnly,
    super.profileId,
    super.sessionId,
    super.search,
    super.since,
    super.until,
    super.limit,
    super.offset,
  });

  /// `true` only non-zero (or missing) exits, `false` only exit 0, `null` either.
  final bool? failedOnly;

  CommandFilter copyWith({
    Object? failedOnly = _unset,
    Object? sessionId = _unset,
    String? search,
    int? offset,
  }) => CommandFilter(
    failedOnly: failedOnly == _unset ? this.failedOnly : failedOnly as bool?,
    profileId: profileId,
    sessionId: sessionId == _unset ? this.sessionId : sessionId as int?,
    search: search ?? this.search,
    since: since,
    until: until,
    limit: limit,
    offset: offset ?? this.offset,
  );
}

class ErrorFilter extends _BaseFilter {
  const ErrorFilter({
    this.context,
    super.profileId,
    super.sessionId,
    super.search,
    super.since,
    super.until,
    super.limit,
    super.offset,
  });

  final String? context;

  ErrorFilter copyWith({
    Object? context = _unset,
    Object? sessionId = _unset,
    String? search,
    int? offset,
  }) => ErrorFilter(
    context: context == _unset ? this.context : context as String?,
    profileId: profileId,
    sessionId: sessionId == _unset ? this.sessionId : sessionId as int?,
    search: search ?? this.search,
    since: since,
    until: until,
    limit: limit,
    offset: offset ?? this.offset,
  );
}

/// Sentinel distinguishing "not passed" from an explicit `null`, so a filter can be
/// *cleared* through `copyWith` rather than only replaced.
const Object _unset = Object();
