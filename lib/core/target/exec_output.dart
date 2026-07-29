/// Result of running one command on the target host.
///
/// Every discovery and service-control command is a shell one-liner, so the command
/// itself stays a plain `String` and only the result is typed — same trade-off the Rust
/// version made after concluding a typed command builder would buy nothing.
class ExecOutput {
  const ExecOutput({
    required this.stdout,
    required this.stderr,
    required this.exitStatus,
  });

  const ExecOutput.empty() : stdout = '', stderr = '', exitStatus = 0;

  final String stdout;
  final String stderr;
  final int exitStatus;

  bool get success => exitStatus == 0;

  /// stdout with surrounding whitespace removed — almost every caller wants this, since
  /// these are one-line command outputs terminated by a newline.
  String get trimmedStdout => stdout.trim();

  @override
  String toString() =>
      'ExecOutput(exit: $exitStatus, stdout: ${stdout.length}B, stderr: ${stderr.length}B)';
}

/// A file listed on the target host.
class FileEntry {
  const FileEntry({required this.path, required this.size, this.modified});

  final String path;
  final int size;

  /// Unix epoch seconds, when the host's `find`/`stat` could report it.
  final int? modified;

  /// The last path segment. Remote paths are always POSIX, so this deliberately does
  /// not use `package:path` — that would split on `\` when the app runs on Windows and
  /// mangle any remote filename containing a backslash.
  String get name {
    final idx = path.lastIndexOf('/');
    return idx == -1 ? path : path.substring(idx + 1);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileEntry &&
          other.path == path &&
          other.size == size &&
          other.modified == modified);

  @override
  int get hashCode => Object.hash(path, size, modified);

  @override
  String toString() => 'FileEntry($path, $size bytes, mtime: $modified)';
}

/// What to do to the game service.
enum ServiceAction { status, stop, start }

/// A ServiceKind-agnostic read on whether the service is up.
///
/// This normalisation is what keeps the push/pull/restore envelopes target-agnostic:
/// they poll for [running] or [stopped] and never have to know that systemd says
/// `active`/`inactive`/`failed`, Docker says `running`/`exited`/`created`/`dead`/
/// `paused`, and a bare process says nothing at all beyond whether pgrep matched.
enum RunState { running, stopped, failed, unknown }
