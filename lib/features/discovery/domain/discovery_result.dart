import 'package:world_keeper/core/target/service_kind.dart';

/// A service that matched "looks like Core Keeper" but could not be auto-selected
/// because it was not the only match.
///
/// Carries enough identifying detail for a human to tell the real unit from a lookalike
/// — a `corekeeper-api` sidecar next to the real `corekeeper` unit is a case seen for
/// real, and the same grep-can-match-twice risk applies to the Docker probe.
class ServiceKindCandidate {
  const ServiceKindCandidate({
    required this.kind,
    this.execStart,
    this.workingDirectory,
    this.steamUser,
  });

  final ServiceKind kind;

  /// What this actually runs: systemd's literal `ExecStart=` line, or a container's
  /// image name. Both answer the same question, so they share a field.
  final String? execStart;

  final String? workingDirectory;
  final String? steamUser;
}

/// One command the probe ran, and what came back.
///
/// Kept so the Discovery screen can show its own work. "Worlds path — none found" is a
/// true statement and a useless one: it does not say where it looked, whether `find` even
/// ran, or whether the host answered at all. Every one of those is a different problem
/// with a different fix, and without the transcript the only way to tell them apart is to
/// SSH in yourself — which defeats the point of a discovery screen.
///
/// This is not the audit log. That records what the app *did* to a server, for reading
/// afterwards; this is a working note for the screen you are looking at right now, and it
/// is discarded with the result.
class ProbeStep {
  const ProbeStep({
    required this.command,
    required this.exitStatus,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.nonZeroIsNormal = false,
  });

  final String command;
  final int exitStatus;
  final String stdout;
  final String stderr;
  final Duration duration;

  /// Whether a non-zero exit is an answer rather than a fault.
  ///
  /// `pgrep` exits 1 when nothing matched and `docker` exits non-zero when it is not
  /// installed — both are perfectly good answers, and marking them as failures would
  /// have the panel report "3 commands could not run" on a healthy systemd host.
  final bool nonZeroIsNormal;

  bool get succeeded => exitStatus == 0 || nonZeroIsNormal;

  /// True when the command ran fine and simply found nothing.
  ///
  /// Worth distinguishing on screen: `find` exiting 0 with no output means "searched,
  /// nothing there", and exiting non-zero means "could not search" — the second is a
  /// broken probe and the first is a correct answer you may not like.
  bool get foundNothing => succeeded && stdout.trim().isEmpty;

  /// The output, capped for display.
  ///
  /// A `find /` across a full disk can return thousands of lines, and rendering all of
  /// them into an expansion tile is how you turn a diagnostic into a hang.
  String preview({int maxLines = 40}) {
    final text = [
      stdout.trimRight(),
      if (stderr.trim().isNotEmpty) 'stderr: ${stderr.trim()}',
    ].where((s) => s.isNotEmpty).join('\n');

    final lines = text.split('\n');
    if (lines.length <= maxLines) return text;
    return '${lines.take(maxLines).join('\n')}\n… ${lines.length - maxLines} more lines';
  }
}

/// The result of probing a host.
///
/// Note what this type makes impossible: when several services matched, [serviceKind] is
/// null and [serviceKindCandidates] is populated — there is no representation of "we
/// guessed". Same for [worldsPath] and [worldsPathCandidates]. Findings are always shown
/// for confirmation before anything is saved.
class DiscoveryResult {
  const DiscoveryResult({
    this.os,
    this.serviceKind,
    this.serviceKindCandidates = const [],
    this.worldsPath,
    this.worldsPathCandidates = const [],
    this.steamUser,
    this.launchScript,
    this.containerRoot,
    this.expectedWorldsPath,
    this.trace = const [],
    required this.probedAt,
  });

  /// `PRETTY_NAME` from `/etc/os-release`. Informational — never branched on.
  final String? os;

  /// Set only when exactly one service matched.
  final ServiceKind? serviceKind;

  /// Populated instead of [serviceKind] when more than one matched.
  final List<ServiceKindCandidate> serviceKindCandidates;

  /// Set only when exactly one worlds directory was found.
  final String? worldsPath;

  /// Populated instead of [worldsPath] when several were found.
  final List<String> worldsPathCandidates;

  /// Where the worlds *would* live, derived from the server's environment.
  ///
  /// Set only when the search found nothing, and deliberately kept separate from
  /// [worldsPath] and [worldsPathCandidates] — those are things the host confirmed exist,
  /// and this is not. A server that has been installed and started but has never saved
  /// has no worlds directory to find, so this is the only answer available; it is offered
  /// as a pre-filled suggestion to confirm, never selected automatically.
  final String? expectedWorldsPath;

  final String? steamUser;
  final String? launchScript;

  /// Set when the server process lives in another mount namespace than the SSH session —
  /// the value is `/proc/<pid>/root`.
  ///
  /// The situation it names: connected to a Proxmox host while Core Keeper runs inside an
  /// unprivileged LXC. `pgrep` finds the process and reports the command line it was
  /// started with, so the service looks perfectly detected — but every path in it belongs
  /// to the container's filesystem and means nothing out here, so every `find` returns
  /// empty and the screen says "none found" about a server that is running fine.
  ///
  /// No amount of searching fixes that. Saying so does.
  final String? containerRoot;

  /// True when the service was found but its filesystem is not reachable from here.
  bool get isInAnotherNamespace => containerRoot != null;

  /// Every command the probe ran, in order. See [ProbeStep].
  final List<ProbeStep> trace;

  /// RFC-3339 UTC.
  final String probedAt;

  /// Whether the probe found a single unambiguous answer for both questions.
  bool get isConclusive => serviceKind != null && worldsPath != null;

  bool get foundNothing => serviceKind == null && serviceKindCandidates.isEmpty;
}
