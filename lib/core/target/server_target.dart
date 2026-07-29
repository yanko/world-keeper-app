import 'dart:io';

import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';

/// The transport-and-control surface the push/pull/restore envelopes are written
/// against.
///
/// This is the seam the whole "target-agnostic" design rests on: the envelopes call only
/// these methods and never learn whether they are talking to systemd, Docker, or a bare
/// process. All of that branching lives in one implementation (`SshTarget`).
///
/// Two things follow from that, and both matter:
///
/// * A Windows or agent-based target would be a second implementation of this interface,
///   added without touching a single line of envelope logic.
/// * The envelopes are testable against a fake, with no server and no network — which is
///   how the rollback, timeout and verification paths get covered at all.
///
/// The SSH implementation is `SshTarget` in `core/ssh/ssh_target.dart`.
abstract interface class ServerTarget {
  /// Runs one shell command on the target host.
  Future<ExecOutput> exec(String cmd);

  /// Uploads [local] to the remote path [remote], returning the byte count.
  ///
  /// [onProgress] reports bytes transferred so far, for a progress bar.
  Future<int> pushFile(
    File local,
    String remote, {
    void Function(int sent, int total)? onProgress,
  });

  /// Downloads [remote] to [local], returning the byte count.
  Future<int> pullFile(
    String remote,
    File local, {
    void Function(int received, int? total)? onProgress,
  });

  /// Lists files directly inside [dir] matching a shell [glob] (e.g. `*.world.gzip`).
  ///
  /// Non-recursive by design — every caller wants one directory level.
  Future<List<FileEntry>> stat(String dir, String glob);

  /// The most recent [lines] of the service's log, however this target's kind exposes
  /// logs (journalctl / docker logs / a file tail).
  Future<String> logsTail(int lines);

  Future<ExecOutput> serviceControl(ServiceAction action);

  /// Normalised run state, for control-flow decisions.
  ///
  /// Distinct from `serviceControl(ServiceAction.status)`, which returns the kind's raw
  /// status text — useful to display, useless for "is it safe to proceed".
  Future<RunState> status();

  /// When the service last (re)started, if this kind can report it. `null` for a bare
  /// process, which has nothing to ask.
  Future<String?> activeSince();

  /// Raw lines evidencing the game's UDP port bound and listening.
  ///
  /// Genuinely kind-specific: the "grep the process name" check that works for systemd
  /// finds nothing under Docker, where the host may only ever see `docker-proxy`.
  Future<List<String>> udpListening();

  /// Fixes ownership after writing world files. A no-op where it doesn't apply.
  Future<void> fixPerms(String path);

  String get worldsPath;

  ServiceKind get serviceKind;
}

/// The raw SSH capabilities `SshTarget` needs, with no knowledge of Core Keeper,
/// service kinds, or world files.
///
/// Extracted as its own interface purely so the per-kind command matrix can be tested by
/// asserting the exact command strings a fake receives. That matters more than it might
/// sound: those strings are the entire contract with the remote host, and a typo in one
/// of them is a production failure that no type checker catches.
abstract interface class SshTransport {
  Future<ExecOutput> exec(String cmd);

  Future<int> pushFile(
    File local,
    String remote, {
    void Function(int sent, int total)? onProgress,
  });

  Future<int> pullFile(
    String remote,
    File local, {
    void Function(int received, int? total)? onProgress,
  });

  /// The host this transport is connected to, for scoping audit and backup records.
  String get host;
}

/// Where [SshTransport] implementations record what they ran.
///
/// An interface rather than a direct dependency on the audit database, so `core/ssh`
/// stays free of drift (and of Flutter) and can be exercised headlessly.
abstract interface class SshCommandAuditSink {
  Future<void> recordCommand({
    required String command,
    required int? exitCode,
    required String stdout,
    required String stderr,
    required int durationMs,
  });

  Future<void> recordError({required String context, required String message});
}
