/// Typed failures.
///
/// The Rust app flattens every error to a `String` at the Tauri IPC boundary, which
/// loses the structure — "which step of the envelope died" ends up embedded in prose.
/// There is no IPC boundary here, so the failing step stays a *field*: the UI can render
/// it structurally and the audit log gets a real column instead of a substring.
sealed class WkException implements Exception {
  const WkException(this.message, {this.cause});

  final String message;
  final Object? cause;

  /// Short machine-readable context, matching the Rust `errors.context` column so the
  /// audit trail stays continuous across the rewrite: `connect`, `discovery`, `push`,
  /// `pull`, `restore`, `ssh_exec`, `config`, `audit`, `keygen`.
  String get context;

  @override
  String toString() => cause == null
      ? '$context: $message'
      : '$context: $message (caused by: $cause)';
}

/// Transport-level failure: connect, auth, channel, SFTP.
final class SshException extends WkException {
  const SshException(super.message, {super.cause, this.host});

  final String? host;

  @override
  String get context => 'ssh_exec';
}

/// Authentication was rejected — kept separate from [SshException] because the UI
/// response differs: re-prompt for a password rather than surface a network error.
final class AuthException extends WkException {
  const AuthException(super.message, {super.cause});

  @override
  String get context => 'connect';
}

/// The remote host key changed or is untrusted (TOFU pinning).
final class HostKeyException extends WkException {
  const HostKeyException(
    super.message, {
    required this.expectedFingerprint,
    required this.actualFingerprint,
    super.cause,
  });

  final String? expectedFingerprint;
  final String actualFingerprint;

  @override
  String get context => 'connect';
}

final class DiscoveryException extends WkException {
  const DiscoveryException(super.message, {super.cause});

  @override
  String get context => 'discovery';
}

/// A push/pull/restore failed. [step] names the envelope state it died in, and
/// [rollbackNote] carries the best-effort recovery outcome.
final class OperationException extends WkException {
  const OperationException(
    super.message, {
    required this.operation,
    required this.step,
    this.rollbackNote,
    super.cause,
  });

  /// `push` | `pull` | `restore`.
  final String operation;

  /// The envelope state that failed, e.g. `stopping`, `copying`, `verifying`.
  final String step;

  final String? rollbackNote;

  @override
  String get context => operation;
}

/// Another destructive operation already holds the lock. Mirrors the Rust `BUSY`
/// constant — push/pull/restore all stop and restart the same service, so overlapping
/// them is a genuine corruption risk, not merely confusing.
final class OperationBusyException extends WkException {
  const OperationBusyException([
    super.message = 'another operation is already in progress',
  ]);

  @override
  String get context => 'operation';
}

/// Config file missing, malformed, or not writable.
final class ConfigException extends WkException {
  const ConfigException(super.message, {super.cause, this.path});

  final String? path;

  @override
  String get context => 'config';
}

final class AuditException extends WkException {
  const AuditException(super.message, {super.cause});

  @override
  String get context => 'audit';
}

/// Local world file resolution failed — nothing recognisable in the chosen file,
/// folder, or zip.
final class LocalWorldException extends WkException {
  const LocalWorldException(super.message, {super.cause});

  @override
  String get context => 'push';
}

final class KeygenException extends WkException {
  const KeygenException(super.message, {super.cause});

  @override
  String get context => 'keygen';
}

/// Not connected, or connected but discovery hasn't been confirmed yet.
final class NotConnectedException extends WkException {
  const NotConnectedException([super.message = 'not connected']);

  @override
  String get context => 'connect';
}
