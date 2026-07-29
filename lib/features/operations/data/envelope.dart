import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/ssh/shell_quote.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/parsers.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

/// Timings for the safe envelope.
///
/// Injectable so tests can exercise the timeout paths in milliseconds instead of waiting
/// out the real ones. The defaults are the production values.
class EnvelopeTimings {
  const EnvelopeTimings({
    this.pollInterval = const Duration(milliseconds: 1500),
    this.stopStartTimeout = const Duration(seconds: 30),
    this.gameIdTimeout = const Duration(seconds: 90),
    this.verifyTimeout = const Duration(seconds: 90),
  });

  /// How often to re-check whether a stop or start has settled.
  final Duration pollInterval;

  /// How long to wait for the service to reach the requested state.
  final Duration stopStartTimeout;

  /// How long to watch the log for the game id.
  ///
  /// 90 s, not 30: `docker start` reports a container "running" as soon as its entrypoint
  /// is alive, well before Core Keeper has finished loading a freshly-swapped world. The
  /// shorter window failed verification on servers that were merely still starting.
  final Duration gameIdTimeout;

  /// How long to wait for the UDP port to appear, for the same reason.
  final Duration verifyTimeout;

  /// Near-instant timings for tests.
  static const fast = EnvelopeTimings(
    pollInterval: Duration(milliseconds: 1),
    stopStartTimeout: Duration(milliseconds: 30),
    gameIdTimeout: Duration(milliseconds: 30),
    verifyTimeout: Duration(milliseconds: 30),
  );
}

/// Stop and start, with the "did it actually settle" semantics both push and pull need.
///
/// Target-agnostic: written purely against [ServerTarget.status], so it never learns
/// whether it is waiting on systemd, Docker or a bare process.
class ServiceControl {
  const ServiceControl(this.target, {this.timings = const EnvelopeTimings()});

  final ServerTarget target;
  final EnvelopeTimings timings;

  Future<void> stopAndWait() async {
    await target.serviceControl(ServiceAction.stop);
    await waitFor(RunState.stopped, operation: 'stop');
  }

  Future<void> startAndWait() async {
    await target.serviceControl(ServiceAction.start);
    await waitFor(RunState.running, operation: 'start');
  }

  /// Polls until the service reaches [want], or gives up.
  ///
  /// Two things make this more than a sleep loop:
  ///
  /// * A service that enters `failed` while we are waiting for `running` bails
  ///   **immediately** rather than burning the full timeout — it is never going to
  ///   arrive, and the sooner the log is surfaced the better.
  /// * Both failure paths attach a 50-line log tail. "Timed out" on its own is useless;
  ///   the reason is almost always in the last few journal lines.
  Future<void> waitFor(
    RunState want, {
    required String operation,
    Duration? timeout,
  }) async {
    final deadline = DateTime.now().add(timeout ?? timings.stopStartTimeout);

    while (true) {
      final state = await _statusOrUnknown();
      if (state == want) return;

      if (state == RunState.failed && want == RunState.running) {
        throw OperationException(
          'the service entered a failed state\n\nRecent log:\n${await _tail()}',
          operation: operation,
          step: operation,
        );
      }

      if (!DateTime.now().isBefore(deadline)) {
        throw OperationException(
          'timed out waiting for the service to be ${want.name} '
          '(still ${state.name})\n\nRecent log:\n${await _tail()}',
          operation: operation,
          step: operation,
        );
      }

      await Future<void>.delayed(timings.pollInterval);
    }
  }

  Future<RunState> _statusOrUnknown() async {
    try {
      return await target.status();
    } on Object {
      // A status check can fail transiently while a service is coming up or down; treat
      // it as "don't know yet" and keep polling rather than aborting the envelope.
      return RunState.unknown;
    }
  }

  Future<String> _tail() async {
    try {
      return await target.logsTail(50);
    } on Object {
      return '(log unavailable)';
    }
  }
}

/// Backup, rollback and verification — the parts push and restore genuinely share.
///
/// Not "similar enough to factor out": these are the same operations. Backing up the live
/// world before overwriting it, restarting and hoping after a failure, and polling for the
/// game id are identical whether the incoming world came from this machine or from a
/// dated backup already on the server.
class WorldOperations {
  const WorldOperations(this.target, {this.timings = const EnvelopeTimings()});

  final ServerTarget target;
  final EnvelopeTimings timings;

  static const String mainSuffix = '.world.gzip';
  static const String pugbackupSuffix = '.world.gzip.pugbackup';

  String mainFileName(int slot) => '$slot$mainSuffix';
  String pugbackupFileName(int slot) => '$slot$pugbackupSuffix';

  String get stagingDir => '${target.worldsPath}/.staging';
  String get backupsDir => '${target.worldsPath}/.backups';

  /// Copies the live world pair to a dated backup directory before anything overwrites
  /// it. Returns `null` only when the slot is genuinely empty — a first push — never as a
  /// way of skipping a failure.
  ///
  /// Names the **two exact files** rather than globbing `<slot>.world.gzip*`. That glob
  /// looks equivalent and is not: the `ich777/steamcmd:corekeeper` image keeps its own
  /// `.old`/`.old2`/`.backup` snapshots beside the real files, and users keep their own
  /// (a real `0.world.gzip.manual-2026-07-26` was swept into a backup this way). Sweeping
  /// those in means a later restore silently overwrites something unrelated that merely
  /// shared a prefix. `N.world.gzip` plus its `.pugbackup` is the world; nothing else is.
  Future<String?> backUpLiveWorld(int slot) async {
    final existing = <FileEntry>[
      ...await target.stat(target.worldsPath, mainFileName(slot)),
      ...await target.stat(target.worldsPath, pugbackupFileName(slot)),
    ];
    if (existing.isEmpty) return null;

    final backupDir = '$backupsDir/$slot.${timestampNow()}';
    final mkdir = await target.exec('mkdir -p ${shq(backupDir)}');
    if (!mkdir.success) {
      throw OperationException(
        'could not create the backup directory: ${mkdir.stderr.trim()}',
        operation: 'backup',
        step: 'backingUp',
      );
    }

    for (final entry in existing) {
      final out = await target.exec(
        'cp -a ${shq(entry.path)} ${shq(backupDir)}/',
      );
      if (!out.success) {
        throw OperationException(
          'backing up ${entry.path} failed: ${out.stderr.trim()}',
          operation: 'backup',
          step: 'backingUp',
        );
      }
    }
    return backupDir;
  }

  /// Total bytes of a backup directory's *contents*, for the audit record.
  ///
  /// `find <dir> -maxdepth 1 -name '*'` matches `<dir>` itself at depth 0, so a naive sum
  /// includes the directory's own inode size and overstates every backup by ~4 KB. Small,
  /// but it makes the recorded figure disagree with what the files actually weigh.
  Future<int> sizeOf(String dir) async {
    try {
      final normalized = dir.replaceAll(RegExp(r'/+$'), '');
      final entries = await target.stat(dir, '*');
      return entries
          .where((e) => e.path.replaceAll(RegExp(r'/+$'), '') != normalized)
          .fold<int>(0, (sum, e) => sum + e.size);
    } on Object {
      return 0;
    }
  }

  /// Best-effort recovery. Never throws — it is called *because* something already
  /// failed, and a rollback that itself blows up leaves the user with nothing to read.
  /// Returns a human-readable note for the audit trail.
  ///
  /// Always attempts the restart, even when there was no backup to restore. Leaving a
  /// game server stopped and silent is the worst possible outcome of a failed swap.
  Future<String> rollback({String? backupPath}) async {
    final notes = <String>[];

    if (backupPath == null) {
      notes.add('no backup existed to restore');
    } else {
      try {
        final out = await target.exec(
          'cp -a ${shq(backupPath)}/. ${shq(target.worldsPath)}/',
        );
        notes.add(
          out.success
              ? 'restored backup'
              : 'restore failed: ${out.stderr.trim()}',
        );
      } on Object catch (e) {
        notes.add('restore error: $e');
      }
      try {
        await target.fixPerms(target.worldsPath);
      } on Object catch (e) {
        notes.add('fixing permissions after restore failed: $e');
      }
    }

    try {
      final out = await target.serviceControl(ServiceAction.start);
      notes.add(
        out.success
            ? 'restart issued'
            : 'restart command failed: ${out.stderr.trim()}',
      );
    } on Object catch (e) {
      notes.add('restart error: $e');
    }

    return notes.join('; ');
  }

  /// Polls the log for the game id.
  ///
  /// Returns `null` on timeout, which is **not** a failure: not every packaging logs the
  /// id in a format this recognises, and refusing to complete a perfectly good swap over
  /// a cosmetic field would be worse than reporting it as unknown.
  Future<String?> captureGameId() async {
    final deadline = DateTime.now().add(timings.gameIdTimeout);
    while (true) {
      try {
        final id = findGameId(await target.logsTail(200));
        if (id != null) return id;
      } on Object {
        // Logs can be briefly unavailable right after a restart.
      }
      if (!DateTime.now().isBefore(deadline)) return null;
      await Future<void>.delayed(timings.pollInterval);
    }
  }

  /// Waits for the game's UDP port to appear.
  Future<bool> waitForUdpListening() async {
    final deadline = DateTime.now().add(timings.verifyTimeout);
    while (true) {
      try {
        if ((await target.udpListening()).isNotEmpty) return true;
      } on Object {
        // Keep trying until the deadline.
      }
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(timings.pollInterval);
    }
  }

  /// Lists the dated backups on the server.
  Future<List<BackupInfo>> listBackups() async {
    final entries = await target.stat(backupsDir, '*');

    final out = <BackupInfo>[];
    for (final entry in entries) {
      // `find <dir> -maxdepth 1 -name '*'` matches the directory itself at depth 0, and
      // `.backups` matches `*` like anything else — skip it rather than listing the
      // backups folder as a backup of itself.
      if (entry.path.replaceAll(RegExp(r'/+$'), '') == backupsDir) continue;

      final name = entry.name;
      final slot = int.tryParse(name.split('.').first);
      out.add(
        BackupInfo(
          path: entry.path,
          slot: slot,
          bytes: await sizeOf(entry.path),
          modified: entry.modified,
        ),
      );
    }

    // Newest first. `<slot>.YYYY-MM-DD_HHMMSS` sorts lexicographically the same as
    // chronologically, so this needs no date parsing.
    out.sort((a, b) => b.path.compareTo(a.path));
    return out;
  }

  /// The dated-backup directory name component: `YYYY-MM-DD_HHMMSS`, UTC.
  static String timestampNow([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
