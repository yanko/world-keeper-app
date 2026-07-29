import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/target/server_target.dart';

/// Binds the SSH layer's audit interface to the real database.
///
/// The indirection exists so `core/ssh` never imports drift: the transport can then be
/// exercised in tests with a recording fake and no database at all, and the audit schema
/// can change without touching the transport.
class DatabaseAuditSink implements SshCommandAuditSink {
  const DatabaseAuditSink(this._db, this._sessionId);

  final AuditDatabase _db;
  final int _sessionId;

  @override
  Future<void> recordCommand({
    required String command,
    required int? exitCode,
    required String stdout,
    required String stderr,
    required int durationMs,
  }) => _db.logSshCommand(
    _sessionId,
    command: command,
    exitCode: exitCode,
    stdout: stdout,
    stderr: stderr,
    durationMs: durationMs,
  );

  @override
  Future<void> recordError({
    required String context,
    required String message,
  }) => _db.logError(_sessionId, context: context, message: message);
}
