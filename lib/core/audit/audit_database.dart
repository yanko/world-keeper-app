import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:world_keeper/core/audit/tables.dart';

part 'audit_database.g.dart';

/// The audit log.
///
/// Append-only in spirit: rows are written as things happen and only ever removed
/// wholesale by the explicit "clear log" action. This tool performs destructive remote
/// operations, so "what happened to world 0 on the 24th" and "which step did the swap
/// die on" need to be single queries.
@DriftDatabase(
  tables: [
    AuditSessions,
    AuditEvents,
    AuditFileOps,
    AuditBackups,
    AuditSshCommands,
    AuditErrors,
  ],
)
class AuditDatabase extends _$AuditDatabase {
  AuditDatabase(super.executor);

  /// Verbatim stdout/stderr from `ssh_commands` is capped: the stats poller runs a
  /// `journalctl -n 200` every few seconds, so storing full captures would grow the
  /// database without bound during an ordinary idle session.
  static const int captureTruncateLength = 4000;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      // Off by default in SQLite; the schema declares real foreign keys and they should
      // be enforced.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Truncates a capture at [captureTruncateLength] **bytes**, backing off to a
  /// character boundary so a multi-byte sequence is never cut in half.
  ///
  /// Length is measured in UTF-8 bytes rather than UTF-16 code units to match the Rust
  /// implementation, so both apps truncate identically.
  static String truncateCapture(String s) {
    final bytes = utf8.encode(s);
    if (bytes.length <= captureTruncateLength) return s;

    var end = captureTruncateLength;
    // 0b10xxxxxx is a UTF-8 continuation byte — walk back off it to a lead byte.
    while (end > 0 && (bytes[end] & 0xC0) == 0x80) {
      end--;
    }
    final head = utf8.decode(bytes.sublist(0, end), allowMalformed: true);
    return '$head… [truncated, ${bytes.length} bytes total]';
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  // ---- write side ---------------------------------------------------------------

  /// Opens a session row for this app run and returns its id.
  Future<int> startSession(String appVersion) => into(auditSessions).insert(
    AuditSessionsCompanion.insert(
      startedAt: _nowIso(),
      appVersion: Value(appVersion),
    ),
  );

  /// Fills in connection details once a profile actually connects. The session row is
  /// created at startup, before any of this is known.
  Future<void> recordConnect(
    int sessionId, {
    required String profileId,
    required String host,
    required String sshUser,
    required String authMethod,
  }) async {
    await (update(auditSessions)..where((s) => s.id.equals(sessionId))).write(
      AuditSessionsCompanion(
        profileId: Value(profileId),
        host: Value(host),
        sshUser: Value(sshUser),
        authMethod: Value(authMethod),
      ),
    );
  }

  Future<int> logEvent(
    int sessionId,
    String kind, {
    String? state,
    Map<String, dynamic>? detail,
    bool? ok,
  }) => into(auditEvents).insert(
    AuditEventsCompanion.insert(
      sessionId: Value(sessionId),
      ts: _nowIso(),
      kind: kind,
      state: Value(state),
      detailJson: Value(detail == null ? null : jsonEncode(detail)),
      ok: Value(ok == null ? null : (ok ? 1 : 0)),
    ),
  );

  /// Records one remote command execution — every `exec` fires this, success or
  /// failure. A single choke point is what makes "what exactly did the app run on my
  /// server, and what came back" answerable without asking anyone to reproduce it.
  Future<void> logSshCommand(
    int sessionId, {
    required String command,
    required int? exitCode,
    required String stdout,
    required String stderr,
    required int durationMs,
  }) async {
    await into(auditSshCommands).insert(
      AuditSshCommandsCompanion.insert(
        sessionId: Value(sessionId),
        ts: _nowIso(),
        command: command,
        exitCode: Value(exitCode),
        stdout: Value(truncateCapture(stdout)),
        stderr: Value(truncateCapture(stderr)),
        durationMs: Value(durationMs),
      ),
    );
  }

  /// Operation-level failures, kept separate from the `error`-kind rows in `events` so
  /// failures are their own scannable list rather than buried among state transitions.
  Future<void> logError(
    int sessionId, {
    required String context,
    required String message,
    Map<String, dynamic>? detail,
  }) async {
    await into(auditErrors).insert(
      AuditErrorsCompanion.insert(
        sessionId: Value(sessionId),
        ts: _nowIso(),
        context: context,
        message: message,
        detailJson: Value(detail == null ? null : jsonEncode(detail)),
      ),
    );
  }

  Future<void> logBackup(
    int sessionId, {
    required int slot,
    required String remotePath,
    required int bytes,
    String? gameIdBefore,
    String? note,
  }) async {
    await into(auditBackups).insert(
      AuditBackupsCompanion.insert(
        sessionId: Value(sessionId),
        ts: _nowIso(),
        slot: Value(slot),
        lxcPath: Value(remotePath),
        bytes: Value(bytes),
        gameIdBefore: Value(gameIdBefore),
        note: Value(note),
      ),
    );
  }

  Future<void> logFileOp(
    int eventId, {
    required String op,
    String? src,
    String? dst,
    int? bytes,
    int? slot,
  }) async {
    await into(auditFileOps).insert(
      AuditFileOpsCompanion.insert(
        eventId: Value(eventId),
        op: Value(op),
        src: Value(src),
        dst: Value(dst),
        bytes: Value(bytes),
        slot: Value(slot),
      ),
    );
  }

  // ---- scoping ---------------------------------------------------------------------

  /// The ids of every session recorded against one profile, as a subquery.
  ///
  /// The audit tables carry a session id and nothing else identifying a machine — the
  /// session row is the only place a profile is recorded. So both "show this server's log"
  /// and "clear this server's log" are joins through `sessions`.
  ///
  /// Builds a fresh statement per call: one subquery instance cannot be embedded in two
  /// expressions.
  JoinedSelectStatement<$AuditSessionsTable, AuditSession> sessionIdsForProfile(
    String profileId,
  ) => selectOnly(auditSessions)
    ..addColumns([auditSessions.id])
    ..where(auditSessions.profileId.equals(profileId));

  // ---- destructive ---------------------------------------------------------------

  /// Wipes **one server's** audit trail, leaving every other server's intact.
  ///
  /// The only clear there is. The screen always has exactly one server in scope — the
  /// connected one, or the one picked from the log's own history — so the destructive
  /// action's blast radius is the thing on screen, with nothing to opt into and no
  /// wider mode to reach by mistake. A "clear everything" existed briefly and was removed
  /// with the scope picker that made it unnecessary.
  ///
  /// Keeps the currently-running session's **row**: its id is held in memory for the
  /// lifetime of the app, and deleting it would leave every later write pointing at a
  /// session that no longer exists. That session's rows do go — they are part of this
  /// server's log.
  Future<void> clearAuditLogForProfile(
    String profileId,
    int keepSessionId,
  ) async {
    await transaction(() async {
      // Children first; foreign keys are enforced. `file_ops` hangs off an event rather
      // than a session, so it has to go before the events it references.
      await (delete(auditFileOps)..where(
            (f) => f.eventId.isInQuery(
              selectOnly(auditEvents)
                ..addColumns([auditEvents.id])
                ..where(
                  auditEvents.sessionId.isInQuery(
                    sessionIdsForProfile(profileId),
                  ),
                ),
            ),
          ))
          .go();
      await (delete(auditBackups)..where(
            (b) => b.sessionId.isInQuery(sessionIdsForProfile(profileId)),
          ))
          .go();
      await (delete(auditSshCommands)..where(
            (c) => c.sessionId.isInQuery(sessionIdsForProfile(profileId)),
          ))
          .go();
      await (delete(auditErrors)..where(
            (e) => e.sessionId.isInQuery(sessionIdsForProfile(profileId)),
          ))
          .go();
      await (delete(auditEvents)..where(
            (e) => e.sessionId.isInQuery(sessionIdsForProfile(profileId)),
          ))
          .go();
      await (delete(auditSessions)..where(
            (s) =>
                s.profileId.equals(profileId) &
                s.id.equals(keepSessionId).not(),
          ))
          .go();
    });
    // Recorded against the live session, which belongs to the profile just cleared — so
    // the trace of the clear is the first thing in that server's log.
    await logEvent(
      keepSessionId,
      'audit_cleared',
      detail: {'profileId': profileId},
      ok: true,
    );
  }
}
