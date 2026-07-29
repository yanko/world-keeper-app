/// Progress reporting for the three destructive operations.
///
/// Each has its own state enum rather than one shared superset, because the sets
/// genuinely differ — pull has no backup or permissions step, and only push uploads —
/// and a shared enum would let a pull emit `backingUp` with nothing to stop it.
library;

/// The push envelope's states.
///
/// The linear path is `uploading` → … → `verifying` → [done]. [rollingBack] and [failed]
/// are not stages *in* the pipeline; they are what happens when it breaks, which is why
/// the UI shows them as a banner rather than as steps.
enum PushState {
  uploading,
  checkingService,
  stopping,
  backingUp,
  copying,
  fixingPerms,
  starting,
  capturingGameId,
  verifying,
  done,
  rollingBack,
  failed,
}

/// The pull envelope's states.
///
/// Deliberately shorter: pulling never modifies the remote world files, so there is no
/// backup, no permissions fix and nothing to roll back.
enum PullState {
  checkingService,
  stopping,
  downloading,
  starting,
  done,
  failed,
}

/// The restore envelope's states — push's, minus the upload.
enum RestoreState {
  checkingService,
  stopping,
  backingUp,
  copying,
  fixingPerms,
  starting,
  capturingGameId,
  verifying,
  done,
  rollingBack,
  failed,
}

/// One progress event.
class OperationProgress<S extends Enum> {
  const OperationProgress(this.state, {this.detail, this.ok});

  final S state;

  /// Free text for the current stage — an error message on failure, or a note such as
  /// the rollback outcome.
  final String? detail;

  /// `true` succeeded, `false` failed, `null` in progress.
  final bool? ok;

  @override
  String toString() =>
      'OperationProgress(${state.name}${ok == null ? '' : ', ok: $ok'}'
      '${detail == null ? '' : ', $detail'})';
}

typedef PushProgress = OperationProgress<PushState>;
typedef PullProgress = OperationProgress<PullState>;
typedef RestoreProgress = OperationProgress<RestoreState>;

/// Receives progress as an operation runs.
///
/// A callback passed in at call time, deliberately not a broadcast stream the caller
/// subscribes to afterwards. The original app emitted global events and required
/// listeners to attach *before* invoking — events fired with nobody listening were
/// simply lost, which is what made switching tabs mid-push look like the operation had
/// vanished. A sink handed over at the start cannot have that failure mode.
typedef ProgressSink<S extends Enum> =
    void Function(OperationProgress<S> progress);

class PushResult {
  const PushResult({
    required this.slot,
    required this.bytesUploaded,
    this.gameId,
    this.backupPath,
    required this.udpListening,
  });

  final int slot;
  final int bytesUploaded;

  /// `null` when the game id never appeared in the log within the timeout. Not a
  /// failure — some packagings log it in a format not yet recognised.
  final String? gameId;

  /// Where the previous world was saved. `null` only when the slot was empty, i.e. a
  /// first push — never as a way of skipping a failed backup.
  final String? backupPath;

  final bool udpListening;
}

/// A world downloaded to a local temp directory, before the user has chosen where to
/// keep it.
class PulledWorld {
  const PulledWorld({
    required this.slot,
    required this.tempDir,
    required this.mainPath,
    this.pugbackupPath,
    required this.bytes,
  });

  final int slot;
  final String tempDir;
  final String mainPath;
  final String? pugbackupPath;
  final int bytes;
}

class RestoreResult {
  const RestoreResult({required this.slot, this.gameId, this.backupPath});

  final int slot;
  final String? gameId;

  /// The safety copy taken of whatever was live *before* this restore, so the restore
  /// itself can be undone.
  final String? backupPath;
}

/// A world available on the server.
class RemoteWorldInfo {
  const RemoteWorldInfo({
    required this.slot,
    required this.size,
    this.modified,
  });

  final int slot;
  final int size;
  final int? modified;
}

/// A dated backup as it exists on the server right now.
///
/// Listed from the filesystem rather than from the audit database. The database was the
/// original source and it was wrong: it only ever knew about backups *this app* made, and
/// clearing the audit log made real, restorable backups invisible — a log wipe silently
/// crippling an unrelated feature. The filesystem is the actual source of truth for "what
/// can I restore"; the database now only enriches an entry with why it was made.
class BackupInfo {
  const BackupInfo({
    required this.path,
    this.slot,
    required this.bytes,
    this.modified,
    this.note,
    this.gameIdBefore,
  });

  final String path;

  /// Parsed from the directory name (`<slot>.<timestamp>`). `null` if it doesn't
  /// follow that shape, in which case it cannot be restored without a slot.
  final int? slot;

  final int bytes;
  final int? modified;

  /// From the audit database, when a record happens to match. Absent is normal.
  final String? note;
  final String? gameIdBefore;
}
