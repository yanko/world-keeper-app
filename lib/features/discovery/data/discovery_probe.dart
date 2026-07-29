import 'dart:convert';

import 'package:world_keeper/core/ssh/shell_quote.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/discovery/domain/discovery_result.dart';

/// Answers "how do I stop the server here, and where are its worlds" by asking the host,
/// rather than by asking the user to declare a target type.
///
/// This is what makes the app target-agnostic, and it is deliberately read-only: it runs
/// `cat`, `systemctl list-units`, `docker ps`, `pgrep` and `find`, and changes nothing.
/// Results are **always** returned for confirmation — this class never persists anything
/// and never resolves an ambiguity on the user's behalf.
///
/// Runs against a bare [SshTransport] rather than a `ServerTarget`, because its whole job
/// is to determine the `ServiceKind` a target would need in order to exist. This is the
/// one place allowed to know about systemd, Docker and processes before a target does.
class DiscoveryProbe {
  DiscoveryProbe(this._transport);

  final SshTransport _transport;

  /// Every command this run has issued, in order.
  ///
  /// Instance state, which is why the class is no longer `const`: a probe is built,
  /// used once and thrown away, so there is no run whose transcript could leak into
  /// another's.
  final List<ProbeStep> _trace = [];

  /// Runs a command and records it.
  ///
  /// Every remote call in this file goes through here rather than through
  /// `_transport.exec` directly, so the transcript cannot fall behind the probe by
  /// someone adding a step and forgetting to log it.
  Future<ExecOutput> _exec(
    String command, {
    bool nonZeroIsNormal = false,
  }) async {
    final started = DateTime.now();
    final out = await _transport.exec(command);
    _trace.add(
      ProbeStep(
        command: command,
        exitStatus: out.exitStatus,
        stdout: out.stdout,
        stderr: out.stderr,
        duration: DateTime.now().difference(started),
        nonZeroIsNormal: nonZeroIsNormal,
      ),
    );
    return out;
  }

  Future<DiscoveryResult> probe() async {
    _trace.clear();

    final os = await _probeOs();
    final service = await _probeServiceKind();
    final worlds = await _probeWorldsPath(
      service.serviceKind,
      homeDir: service.homeDir,
      configHome: service.configHome,
      workingDirectory: service.workingDirectory,
      scriptDir: posixDirname(service.launchScript ?? ''),
    );

    return DiscoveryResult(
      os: os,
      serviceKind: service.serviceKind,
      serviceKindCandidates: service.candidates,
      worldsPath: worlds.single,
      worldsPathCandidates: worlds.candidates,
      expectedWorldsPath: worlds.expected,
      steamUser: service.steamUser,
      launchScript: service.launchScript,
      containerRoot: service.containerRoot,
      trace: List.unmodifiable(_trace),
      probedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Step A — identify the OS. Shown to the user, never branched on.
  Future<String?> _probeOs() async {
    final out = await _exec('cat /etc/os-release 2>/dev/null');
    for (final line in out.stdout.split('\n')) {
      if (line.startsWith('PRETTY_NAME=')) {
        final value = line.substring('PRETTY_NAME='.length).trim();
        return _stripQuotes(value);
      }
    }
    return null;
  }

  static String _stripQuotes(String s) =>
      (s.length >= 2 && s.startsWith('"') && s.endsWith('"'))
      ? s.substring(1, s.length - 1)
      : s;

  /// Step B — determine the service kind: systemd, then Docker, then a bare process.
  /// First hit wins, which resolves a host that has both systemd and Docker present.
  Future<_ServiceProbe> _probeServiceKind() async {
    final systemd = await _probeSystemd();
    if (systemd != null) return systemd;

    final docker = await _probeDocker();
    if (docker != null) return docker;

    return await _probeProcess() ?? const _ServiceProbe();
  }

  /// **Filtered in Dart, not in the shell, and stderr is not thrown away.**
  ///
  /// This used to be `systemctl list-units --type=service 2>/dev/null | grep -i core`,
  /// and every part of that hid something:
  ///
  /// * A pipeline's exit status is the *last* command's, so `systemctl` failing and
  ///   `grep` matching nothing both arrive as exit 1.
  /// * `2>/dev/null` discards the one thing that would have said which.
  /// * Filtering in the shell means the transcript never shows what systemd replied, so
  ///   "no unit matched" cannot be told from "no units listed at all".
  ///
  /// The cost of that was a host where the desktop build found two units and the phone
  /// build found none, with identical output in both transcripts: `exit 1`, nothing else.
  /// Whatever the underlying difference turns out to be, a probe that cannot report it is
  /// the first bug to fix.
  ///
  /// `--all` because a Core Keeper service that is *stopped* is exactly the one you want
  /// to find; `--no-legend --plain` because the header, the footer and the failed-unit
  /// bullet are formatting this then has to parse back off.
  Future<_ServiceProbe?> _probeSystemd() async {
    final out = await _exec(
      'systemctl list-units --type=service --all --no-pager --no-legend --plain',
    );

    final units = unitsMatching(out.stdout);
    if (units.isEmpty) return null;

    units.sort((a, b) => specificityRank(a).compareTo(specificityRank(b)));

    if (units.length == 1) {
      final unit = units.single;
      final info = await _probeSystemdUnit(unit);
      return _ServiceProbe(
        serviceKind: SystemdService(unit: unit),
        launchScript: info.execStart,
        steamUser: info.user,
        homeDir: await _homeOf(info.user),
        workingDirectory: info.workingDirectory,
      );
    }

    final candidates = <ServiceKindCandidate>[];
    for (final unit in units) {
      final info = await _probeSystemdUnit(unit);
      candidates.add(
        ServiceKindCandidate(
          kind: SystemdService(unit: unit),
          execStart: info.execStart,
          workingDirectory: info.workingDirectory,
          steamUser: info.user,
        ),
      );
    }
    return _ServiceProbe(candidates: candidates);
  }

  Future<_SystemdUnitInfo> _probeSystemdUnit(String unit) async {
    // Whole unit file, parsed here — same reasoning as `_probeSystemd`. A `grep` in the
    // shell would take the exit status with it and leave a unit that could not be read
    // looking exactly like one with no ExecStart.
    final out = await _exec('systemctl cat ${shq(unit)} --no-pager');

    String? execStart;
    String? workingDirectory;
    String? user;
    for (final raw in out.stdout.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('ExecStart=')) {
        execStart = line.substring('ExecStart='.length).trim();
      } else if (line.startsWith('WorkingDirectory=')) {
        workingDirectory = line.substring('WorkingDirectory='.length).trim();
      } else if (line.startsWith('User=')) {
        user = line.substring('User='.length).trim();
      }
    }
    return _SystemdUnitInfo(
      execStart: execStart,
      workingDirectory: workingDirectory,
      user: user,
    );
  }

  Future<_ServiceProbe?> _probeDocker() async {
    // `docker` is absent on most hosts, which is a normal answer rather than a fault —
    // but the stderr saying so is worth keeping, since "not installed" and "permission
    // denied on the socket" are very different problems and used to look identical.
    final out = await _exec(
      "docker ps --format '{{.Names}} {{.Image}}'",
      nonZeroIsNormal: true,
    );

    final containers = <({String name, String image})>[];
    for (final line in out.stdout.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      final name = parts.firstOrNull;
      if (name == null || name.isEmpty) continue;
      if (!name.toLowerCase().contains('core')) continue;
      containers.add((name: name, image: parts.elementAtOrNull(1) ?? ''));
    }
    if (containers.isEmpty) return null;

    containers.sort(
      (a, b) => specificityRank(a.name).compareTo(specificityRank(b.name)),
    );

    if (containers.length == 1) {
      return _ServiceProbe(
        serviceKind: DockerService(container: containers.single.name),
      );
    }

    return _ServiceProbe(
      candidates: [
        for (final c in containers)
          ServiceKindCandidate(
            kind: DockerService(container: c.name),
            execStart: c.image.isEmpty ? null : c.image,
          ),
      ],
    );
  }

  /// Two processes, two different questions.
  ///
  /// A Core Keeper install is a `_launch.sh` wrapper that execs the game binary, and the
  /// two are **not interchangeable**:
  ///
  /// * The **wrapper** is what to start and stop. Re-running `_launch.sh` is how you bring
  ///   the server back; re-running the binary directly skips whatever the script sets up.
  /// * The **game binary** is what actually writes the worlds, so its environment is the
  ///   one that decides where they go. A launch script is free to `export HOME=…` before
  ///   exec'ing, and then the wrapper's environment — which is the shell's, from before
  ///   the script ran — is the wrong answer to "where does this server save".
  ///
  /// The previous version stopped at the first `pgrep` that matched. On a host with a
  /// wrapper that is always the wrapper, so the binary was never looked at.
  Future<_ServiceProbe?> _probeProcess() async {
    // Deliberately not `A || B`: short-circuiting means the second never runs when the
    // first matches, which is exactly the case that hid the game binary.
    // `pgrep` exits 1 when nothing matches, which is an answer and not a failure.
    final launcher = _serverProcessLine(
      (await _exec('pgrep -af _launch.sh', nonZeroIsNormal: true)).stdout,
    );
    final binary = _serverProcessLine(
      (await _exec('pgrep -af CoreKeeperServer', nonZeroIsNormal: true)).stdout,
    );

    // The wrapper is what to run; fall back to the binary where there is no wrapper.
    final control = launcher ?? binary;
    if (control == null) return null;

    final (_, cmdline) = _splitPgrepLine(control);
    if (cmdline.isEmpty) return null;

    // The binary is what writes; fall back to the wrapper where there is no binary.
    final (environmentPid, _) = _splitPgrepLine(binary ?? control);

    final environment = await _environOf(environmentPid);
    final user = await _userOfPid(environmentPid);
    // Hoisted: this is a remote round trip, and it was being made twice.
    final cwd = await _cwdOf(environmentPid);
    final scriptPath = _scriptPathIn(cmdline);

    return _ServiceProbe(
      serviceKind: ProcessService(
        stopCmd: 'pkill -f ${shq(cmdline)}',
        startCmd: cmdline,
        // Without this a bare-process target has no log at all: `logsTail` throws, the
        // live log panel is empty, and the game id — which is read out of the log — is
        // never captured. systemd and Docker both have a log by construction; a script
        // redirecting to a file is the only shape where it has to be found.
        logPath: await _probeLogPath(cwd: cwd, scriptPath: scriptPath),
      ),
      steamUser: user,
      // In descending order of how much it is worth trusting: the writing process's own
      // `HOME`, then its home per the password database, then nothing.
      homeDir: environment.home ?? await _homeOf(user),
      configHome: environment.configHome,
      workingDirectory: cwd,
      launchScript: scriptPath,
      containerRoot: await _mountRootOf(environmentPid),
    );
  }

  /// `pgrep -af` prints `<pid> <full command line>`.
  static (String pid, String cmdline) _splitPgrepLine(String line) {
    final space = line.indexOf(' ');
    if (space == -1) return (line, '');
    return (line.substring(0, space), line.substring(space + 1));
  }

  /// The server's own line out of `pgrep -af` output.
  ///
  /// Drops the probe's own command, which matches its own pattern. Observed for real: a
  /// `pgrep -af _launch.sh` run over SSH returns both the server and the `bash -c` that
  /// wrapped the pgrep.
  static String? _serverProcessLine(String stdout) {
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.contains('pgrep')) continue;
      return line;
    }
    return null;
  }

  /// The launch script's path, pulled back out of the captured command line.
  ///
  /// `/bin/bash /home/steam/corekeeper/_launch.sh` tells us a directory that certainly
  /// exists on this host and is certainly related to the server — which is worth more as
  /// a search root than any guess about home directories.
  static String? _scriptPathIn(String cmdline) {
    for (final token in cmdline.split(' ')) {
      if (token.endsWith('.sh') && token.startsWith('/')) return token;
    }
    return null;
  }

  /// A log file the server writes, if one is obvious.
  ///
  /// Looks beside the launch script and in the working directory, one level deep — a
  /// `_launch.sh` that redirects output puts the file next to itself or under the server
  /// directory, and searching wider turns up every unrelated log on the box.
  ///
  /// Returns null unless exactly one candidate is found. Guessing between several would
  /// mean the live log panel confidently tailing the wrong file, which is worse than an
  /// empty one — the Discovery screen takes the path by hand for that case.
  Future<String?> _probeLogPath({String? cwd, String? scriptPath}) async {
    final scriptDir = scriptPath == null ? '' : posixDirname(scriptPath);
    final roots = <String>{
      ?cwd,
      if (scriptDir.isNotEmpty) scriptDir,
    }.where((r) => r.isNotEmpty && r != '/').toList();
    if (roots.isEmpty) return null;

    final out = await _exec(
      'find ${roots.map(shq).join(' ')} -maxdepth 2 -type f -name \'*.log\' '
      '2>/dev/null',
    );

    final candidates = _nonEmptyLines(out.stdout);
    return candidates.length == 1 ? candidates.single : null;
  }

  Future<String?> _userOfPid(String pid) async {
    if (pid.isEmpty || int.tryParse(pid) == null) return null;
    final out = await _exec('ps -o user= -p $pid 2>/dev/null');
    final user = out.trimmedStdout;
    return user.isEmpty ? null : user;
  }

  /// `HOME` and `XDG_CONFIG_HOME` as the process itself sees them.
  ///
  /// This is the authoritative answer to "where does Core Keeper write", and everything
  /// else in this file is a guess at it. The game stores worlds under
  /// `$HOME/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds`, and `$HOME` is
  /// whatever the *launch script's environment* says — which a script is free to set to
  /// anything, and which has no obligation to match the password database. On a host
  /// where `ps` reports a bare numeric uid (an unprivileged LXC, where the container's
  /// user has no entry outside it) the password database has no answer at all, and this
  /// is the only source left.
  ///
  /// Readable without privilege for one's own processes, and as root for any.
  Future<({String? home, String? configHome})> _environOf(String pid) async {
    if (pid.isEmpty || int.tryParse(pid) == null) {
      return (home: null, configHome: null);
    }
    final out = await _exec(
      "tr '\\0' '\\n' < /proc/$pid/environ 2>/dev/null | "
      "grep -E '^(HOME|XDG_CONFIG_HOME)='",
    );

    String? valueOf(String key) {
      for (final line in out.stdout.split('\n')) {
        if (line.startsWith('$key=')) {
          final value = line.substring(key.length + 1).trim();
          if (value.isNotEmpty) return value;
        }
      }
      return null;
    }

    return (home: valueOf('HOME'), configHome: valueOf('XDG_CONFIG_HOME'));
  }

  /// The directory the server is actually running in.
  Future<String?> _cwdOf(String pid) async {
    if (pid.isEmpty || int.tryParse(pid) == null) return null;
    final out = await _exec(
      'readlink /proc/$pid/root 2>/dev/null; '
      'readlink /proc/$pid/cwd 2>/dev/null',
    );
    // Two lines: root then cwd. Only the second is wanted here.
    final lines = _nonEmptyLines(out.stdout);
    return lines.length >= 2 ? lines[1] : null;
  }

  /// Non-null when the process lives in a different mount namespace from this session.
  ///
  /// The case that produces it: SSH into a Proxmox host while Core Keeper runs inside an
  /// unprivileged LXC. `pgrep` finds the process and reports the command line it was
  /// started with — `/home/steam/corekeeper/_launch.sh` — but that path means nothing
  /// out here, so every `find` comes back empty and discovery reports "none found" on a
  /// server that is running perfectly well. Naming the situation beats searching harder.
  Future<String?> _mountRootOf(String pid) async {
    if (pid.isEmpty || int.tryParse(pid) == null) return null;
    final out = await _exec('readlink /proc/$pid/root 2>/dev/null');
    final root = out.trimmedStdout;
    return (root.isEmpty || root == '/') ? null : root;
  }

  /// A user's home directory, from the password database rather than assumed to be
  /// `/home/<user>`.
  ///
  /// A fallback for [_environOf], not a first choice: `root` breaks the `/home/<user>`
  /// assumption, and an unprivileged container's uid breaks the password database too —
  /// `getent passwd 101000` on the host returns nothing at all.
  Future<String?> _homeOf(String? user) async {
    if (user == null || user.isEmpty) return null;
    final out = await _exec(
      'getent passwd ${shq(user)} 2>/dev/null | cut -d: -f6',
    );
    final home = out.trimmedStdout;
    return home.isEmpty ? null : home;
  }

  /// Step C — locate the worlds directory.
  ///
  /// Two searches, because "where are the worlds" has two failure modes and only the first
  /// was covered:
  ///
  /// 1. **Worlds that exist.** A directory containing `*.world.gzip` is the worlds
  ///    directory — the strongest evidence available, so it is tried first.
  /// 2. **A worlds directory that is empty.** A server that has been installed and started
  ///    but has never saved has the directory and no files in it, and searching for files
  ///    reports "none found" on a host that is working perfectly well.
  ///
  /// Both run against several roots rather than just `/home`. `/home` alone misses a
  /// server running as `root`, which is the normal shape of a single-purpose LXC
  /// container: the launch script lives in `/home/steam` while `$HOME` is `/root`, so the
  /// worlds are somewhere `find /home` will never look.
  Future<({String? single, List<String> candidates, String? expected})>
  _probeWorldsPath(
    ServiceKind? kind, {
    String? homeDir,
    String? configHome,
    String? workingDirectory,
    String? scriptDir,
  }) async {
    if (kind is DockerService) {
      final docker = await _probeDockerWorldsPath(kind.container);
      return (
        single: docker.single,
        candidates: docker.candidates,
        expected: null,
      );
    }

    final roots = searchRoots(
      homeDir: homeDir,
      configHome: configHome,
      workingDirectory: workingDirectory,
      scriptDir: scriptDir,
    );

    final files = await _findAcross(roots, "-name '*.world.gzip'");
    final fromFiles = dedupeParentDirs(files);
    if (fromFiles.single != null || fromFiles.candidates.isNotEmpty) {
      return (
        single: fromFiles.single,
        candidates: fromFiles.candidates,
        expected: null,
      );
    }

    // `-type d` so an empty worlds directory still answers the question, and `-iname`
    // because the directory's case is the game's business, not ours. Depth-capped:
    // without it this walks every node_modules and every container overlay on the box.
    final dirs = await _findAcross(roots, '-maxdepth 8 -type d -iname worlds');
    final fromDirs = rankWorldsCandidates(_nonEmptyLines(dirs));
    if (fromDirs.single != null || fromDirs.candidates.isNotEmpty) {
      return (
        single: fromDirs.single,
        candidates: fromDirs.candidates,
        expected: null,
      );
    }

    // Nothing at all. Two things are worth doing before giving up, and neither is
    // "search harder".
    //
    // First, list what *is* under the server's home, into the transcript. A server that
    // has never saved has no worlds directory to find, and a search cannot tell that
    // apart from an install laid out somewhere unexpected — a listing can, and it costs
    // one command on the path where the answer was going to be "none found" anyway.
    final home = configHome ?? homeDir;
    if (home != null && home.isNotEmpty) {
      await _exec(
        'find ${shq(home)} -maxdepth 6 -type d 2>/dev/null | head -n 100',
      );
    }

    // Second, work out where it *would* be. Core Keeper's location is fixed given the
    // environment, so with `HOME` in hand this is derivable rather than searchable —
    // which is the only answer available for a server that has not saved yet, since
    // there is genuinely nothing on disk to find.
    return (
      single: null,
      candidates: const <String>[],
      expected: expectedWorldsPath(homeDir: homeDir, configHome: configHome),
    );
  }

  Future<String> _findAcross(List<String> roots, String expression) async {
    final buffer = StringBuffer();
    for (final root in roots) {
      final out = await _exec('find ${shq(root)} $expression 2>/dev/null');
      buffer.write(out.stdout);
      if (!out.stdout.endsWith('\n')) buffer.write('\n');
    }
    return buffer.toString();
  }

  /// A container's worlds path cannot be guessed from its mount *destinations*.
  ///
  /// An earlier version of the Rust app tried exactly that — looking for `unity3d` or
  /// `.config` in the destination path — which only worked because the first Docker
  /// deployment it met happened to bind-mount Unity3D's own config directory 1:1.
  /// `ich777/steamcmd:corekeeper` instead mounts a flat `/serverdata/serverfiles` with
  /// the worlds nested two levels down, and separately mounts an unrelated
  /// `/serverdata/steamcmd`. No naming convention survives that.
  ///
  /// So: search inside every one of the container's host-side mount sources, the same
  /// `find` used everywhere else, just scoped to the mounts. Searching the whole host
  /// would not help — a bind-mount source is rarely under `/home` (Unraid puts them
  /// under `/mnt/user/appdata`).
  Future<({String? single, List<String> candidates})> _probeDockerWorldsPath(
    String container,
  ) async {
    final sources = await _dockerMountSources(container);
    if (sources.isEmpty) return (single: null, candidates: <String>[]);

    final buffer = StringBuffer();
    for (final source in sources) {
      final out = await _exec(
        "find ${shq(source)} -name '*.world.gzip' 2>/dev/null",
      );
      buffer.write(out.stdout);
      if (!out.stdout.endsWith('\n')) buffer.write('\n');
    }
    return dedupeParentDirs(buffer.toString());
  }

  /// Every mount's host-side source, `bind` and named `volume` alike — both are just a
  /// real directory on the host, readable over this same connection.
  Future<List<String>> _dockerMountSources(String container) async {
    // The Go template contains a space. Unquoted, the remote shell splits it into two
    // argv entries before `docker` ever parses `--format`, and the lookup silently
    // returns nothing — a real bug in the Rust app, masked for a long time because that
    // deployment's worlds happened to sit under /home where the fallback found them.
    final out = await _exec(
      'docker inspect ${shq(container)} --format ${shq('{{json .Mounts}}')} '
      '2>/dev/null',
    );

    final text = out.stdout.trim();
    if (text.isEmpty) return const [];

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];

    final sources = <String>[];
    for (final mount in decoded) {
      if (mount is! Map) continue;
      final source = mount['Source'];
      if (source is String && source.isNotEmpty && !sources.contains(source)) {
        sources.add(source);
      }
    }
    return sources;
  }
}

/// Reduces `find -name '*.world.gzip'` output to a worlds-path answer: the parent
/// directory of each match, deduped. Zero found, exactly one (confident), or several
/// (surfaced as candidates — never guessed between).
///
/// ## Why this is more than a dedupe
///
/// A plain dedupe is what the Rust app does, and on a host that has actually been *used*
/// it degrades badly. Every push writes a dated copy of the world into
/// `<worldsPath>/.backups/<slot>.<timestamp>/`, and those copies are `*.world.gzip`
/// files too — so `find` returns one directory per backup ever made. Confirmed against
/// the reference host: **sixteen** candidates, fifteen of them backups of the one real
/// answer, presented as a flat list to choose from.
///
/// So two filters are applied before giving up and calling it ambiguous:
///
/// 1. **Drop the app's own scratch directories.** Anything inside a `.backups` or
///    `.staging` segment is by construction a copy of a world, not a worlds directory.
///    Only those two names are excluded — a general "skip hidden directories" rule would
///    throw away the real answer, which lives under `~/.config`.
/// 2. **Collapse descendants into their ancestor.** If one surviving candidate contains
///    another, the container is the worlds directory and the nested one is something
///    inside it.
///
/// What remains is genuinely ambiguous and is still surfaced for the user to choose,
/// ordered so the likeliest is first.
({String? single, List<String> candidates}) dedupeParentDirs(
  String findStdout,
) => rankWorldsCandidates([
  for (final line in _nonEmptyLines(findStdout))
    if (posixDirname(line).isNotEmpty) posixDirname(line),
]);

List<String> _nonEmptyLines(String s) => [
  for (final raw in s.split('\n'))
    if (raw.trim().isNotEmpty) raw.trim(),
];

/// Where to look for a worlds directory on a non-Docker host.
///
/// `/home` and `/root` always, because the server may run as either an ordinary user or
/// as root; plus whatever the probe actually learned — the running user's real home from
/// the password database, and a systemd unit's `WorkingDirectory`.
///
/// Roots that sit inside another root are dropped, so a resolved home of `/home/steam`
/// does not make the whole of `/home` get walked twice.
/// Where to look for the worlds directory, best evidence first.
///
/// `/home` and `/root` are the blind guesses at the end. Everything passed in beats them,
/// because each is something the host actually told us: the process's own `$HOME` and
/// `XDG_CONFIG_HOME`, the directory it is running in, and the directory holding the launch
/// script that started it. A root that is inside another is dropped — searching `/home`
/// and `/home/steam` walks the same tree twice.
List<String> searchRoots({
  String? homeDir,
  String? configHome,
  String? workingDirectory,
  String? scriptDir,
}) {
  final roots = <String>['/home', '/root'];
  for (final extra in [homeDir, configHome, workingDirectory, scriptDir]) {
    final path = extra?.trim();
    if (path == null || path.isEmpty || path == '/') continue;
    final normalized = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    if (!roots.contains(normalized)) roots.add(normalized);
  }

  return roots
      .where(
        (r) => !roots.any((other) => other != r && _isDescendantOf(r, other)),
      )
      .toList();
}

/// Core-Keeper-looking service units in `systemctl list-units` output.
///
/// The match moved out of the shell so the transcript keeps the full listing — see
/// `_probeSystemd`. Pure, so the parsing can be tested against real `systemctl` output
/// without a host.
List<String> unitsMatching(String listUnitsOutput, {String needle = 'core'}) {
  final units = <String>[];
  for (final raw in listUnitsOutput.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    final fields = line.split(RegExp(r'\s+'));
    // `--plain` suppresses the failed-unit bullet, but an older systemd ignores the flag
    // and prints it anyway, so it is still skipped rather than assumed absent.
    final name = (fields.first == '●' || fields.first == '*')
        ? fields.elementAtOrNull(1)
        : fields.first;

    if (name == null || !name.endsWith('.service')) continue;
    if (!name.toLowerCase().contains(needle)) continue;

    final unit = name.substring(0, name.length - '.service'.length);
    if (unit.isNotEmpty && !units.contains(unit)) units.add(unit);
  }
  return units;
}

/// Where Core Keeper would put its worlds, given the environment its server runs in.
///
/// Not a search result — nothing has confirmed this exists. It is offered when the search
/// found nothing, because a server that has been installed and started but has **never
/// saved** has no worlds directory at all, and no amount of searching can produce a path
/// that is not yet on disk. Leaving the field blank in that case asks the user to know a
/// Unity convention by heart; filling it in asks them to confirm one.
///
/// The layout is Unity's, not the game's choice: `XDG_CONFIG_HOME` (or `HOME/.config`)
/// then `unity3d/<company>/<product>`. Pugstorm ships the dedicated server under its own
/// subdirectory of that.
String? expectedWorldsPath({String? homeDir, String? configHome}) {
  final config = (configHome != null && configHome.trim().isNotEmpty)
      ? configHome.trim()
      : (homeDir != null && homeDir.trim().isNotEmpty)
      ? '${homeDir.trim()}/.config'
      : null;
  if (config == null) return null;

  final base = config.endsWith('/')
      ? config.substring(0, config.length - 1)
      : config;
  return '$base/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds';
}

/// Reduces a set of candidate directories to one answer, or to a list to choose from.
({String? single, List<String> candidates}) rankWorldsCandidates(
  List<String> found,
) {
  var dirs = <String>[];
  for (final dir in found) {
    if (dir.isNotEmpty && !dirs.contains(dir)) dirs.add(dir);
  }

  final withoutScratch = dirs.where((d) => !_isInsideScratchDir(d)).toList();
  // If *everything* was scratch, the host only has backups; fall back rather than
  // report nothing at all.
  if (withoutScratch.isNotEmpty) dirs = withoutScratch;

  dirs = dirs
      .where(
        (d) => !dirs.any((other) => other != d && _isDescendantOf(d, other)),
      )
      .toList();

  dirs.sort(_worldsPathPreference);

  return switch (dirs.length) {
    0 => (single: null, candidates: <String>[]),
    1 => (single: dirs.single, candidates: <String>[]),
    _ => (single: null, candidates: dirs),
  };
}

/// Directories this app creates inside the worlds directory.
const _scratchSegments = {'.backups', '.staging'};

bool _isInsideScratchDir(String path) =>
    path.split('/').any(_scratchSegments.contains);

bool _isDescendantOf(String path, String maybeAncestor) =>
    path.startsWith('$maybeAncestor/');

/// Orders candidates so the most plausible worlds directory sorts first: one actually
/// named `worlds`, then the shallowest, then alphabetically for stability.
int _worldsPathPreference(String a, String b) {
  int rank(String p) => p.split('/').last == 'worlds' ? 0 : 1;
  final byName = rank(a).compareTo(rank(b));
  if (byName != 0) return byName;
  final byDepth = a.split('/').length.compareTo(b.split('/').length);
  if (byDepth != 0) return byDepth;
  return a.compareTo(b);
}

/// The parent of a **POSIX** path.
///
/// Deliberately not `package:path`: its default context follows the *host* platform, so
/// running on Windows it would treat `\` as a separator and mangle any remote filename
/// containing a backslash. Remote paths are always POSIX regardless of what this app
/// runs on.
String posixDirname(String path) {
  final trimmed = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  final idx = trimmed.lastIndexOf('/');
  if (idx < 0) return '';
  if (idx == 0) return '/';
  return trimmed.substring(0, idx);
}

/// How closely a discovered name matches "core keeper" — lower is closer.
///
/// Used **only to order** candidates so the likeliest sorts first and confirming is one
/// click instead of a coin flip. It never auto-selects: a rank-0 match among several is
/// still shown for confirmation.
///
/// Hyphen, underscore and case insensitive, so `core-keeper` and `corekeeper` tie at 0
/// while a suffixed lookalike like `core-keeper-api` ranks below.
int specificityRank(String name) {
  final normalized = name
      .split('')
      .where((c) => RegExp(r'[a-zA-Z0-9]').hasMatch(c))
      .join()
      .toLowerCase();
  if (normalized == 'corekeeper') return 0;
  if (normalized.startsWith('corekeeper') ||
      normalized.endsWith('corekeeper')) {
    return 1;
  }
  return 2;
}

class _ServiceProbe {
  const _ServiceProbe({
    this.serviceKind,
    this.candidates = const [],
    this.launchScript,
    this.steamUser,
    this.homeDir,
    this.configHome,
    this.workingDirectory,
    this.containerRoot,
  });

  final ServiceKind? serviceKind;
  final List<ServiceKindCandidate> candidates;
  final String? launchScript;
  final String? steamUser;

  /// The home directory of whoever runs the server — where Core Keeper puts its worlds.
  final String? homeDir;

  /// `XDG_CONFIG_HOME`, when the launch script sets it. Overrides `$HOME/.config`, so a
  /// server whose script points it elsewhere is invisible to a search of the home
  /// directory.
  final String? configHome;

  final String? workingDirectory;

  /// Set when the process is in another mount namespace — see `_mountRootOf`.
  final String? containerRoot;
}

class _SystemdUnitInfo {
  const _SystemdUnitInfo({this.execStart, this.workingDirectory, this.user});
  final String? execStart;
  final String? workingDirectory;
  final String? user;
}
