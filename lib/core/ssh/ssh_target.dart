import 'dart:io';

import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/ssh/shell_quote.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/parsers.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/core/target/service_kind.dart';

/// The SSH implementation of [ServerTarget].
///
/// **Every** systemd/Docker/process branch in the application lives in this one class.
/// If a `switch` on [ServiceKind] appears anywhere else, something has leaked.
///
/// Note the `shq()` calls on every interpolated value. They are not decoration: the
/// reference worlds path contains spaces, and a real bug in the Rust app came from a
/// single unquoted `docker inspect --format {{json .Mounts}}` being word-split by the
/// remote shell before `docker` ever parsed it.
class SshTarget implements ServerTarget {
  // `prefer_initializing_formals` would have these be `this._transport` etc., but Dart
  // forbids private names for *named* parameters — and named is right here, since four
  // loosely-typed arguments read far better labelled at the call site. The fields stay
  // private so the ServiceKind switch cannot leak outside this class.
  // ignore_for_file: prefer_initializing_formals
  SshTarget({
    required SshTransport transport,
    required ServiceKind serviceKind,
    required String worldsPath,
    String? steamUser,
  }) : _transport = transport,
       _serviceKind = serviceKind,
       _worldsPath = worldsPath,
       _steamUser = steamUser;

  final SshTransport _transport;
  final ServiceKind _serviceKind;
  final String _worldsPath;
  final String? _steamUser;

  /// Cached once probed — see [stat].
  _FindStrategy _findStrategy = _FindStrategy.unknown;

  SshTransport get transport => _transport;

  String? get steamUser => _steamUser;

  @override
  String get worldsPath => _worldsPath;

  @override
  ServiceKind get serviceKind => _serviceKind;

  @override
  Future<ExecOutput> exec(String cmd) => _transport.exec(cmd);

  @override
  Future<int> pushFile(
    File local,
    String remote, {
    void Function(int sent, int total)? onProgress,
  }) => _transport.pushFile(local, remote, onProgress: onProgress);

  @override
  Future<int> pullFile(
    String remote,
    File local, {
    void Function(int received, int? total)? onProgress,
  }) => _transport.pullFile(remote, local, onProgress: onProgress);

  /// Lists one directory level, with sizes and mtimes.
  ///
  /// Prefers GNU findutils' `-printf`, which does the whole job in one round trip. That
  /// is **not portable**: `-printf` does not exist on BusyBox (so: Alpine-based images,
  /// plenty of NAS firmware) or on BSD. This app's entire premise is discovering an
  /// unknown host rather than assuming one, so falling over there would be a real gap —
  /// and the failure mode is nasty, because a host without `-printf` yields *no output*,
  /// which reads as "no worlds found" rather than as an error.
  ///
  /// So the strategy is probed on first use and cached: try `-printf`, and on failure
  /// fall back to `-exec stat -c`. Deciding by result rather than by asking the host what
  /// it is keeps this honest about hosts nobody has met yet.
  @override
  Future<List<FileEntry>> stat(String dir, String glob) async {
    if (_findStrategy == _FindStrategy.posixStat) {
      return parseStatLines((await exec(_posixFindCommand(dir, glob))).stdout);
    }

    final printf = await exec(_printfFindCommand(dir, glob));
    if (printf.stdout.trim().isNotEmpty) {
      _findStrategy = _FindStrategy.gnuPrintf;
      return parseFindPrintf(printf.stdout);
    }
    if (printf.success) {
      // Genuinely nothing matched. `find` exits 0, so `-printf` is supported and this
      // directory is simply empty — don't downgrade the strategy over an empty listing.
      _findStrategy = _FindStrategy.gnuPrintf;
      return const [];
    }

    // Non-zero exit with no output: either the directory is missing, or `-printf` is
    // unsupported. The fallback distinguishes them for us.
    final posix = await exec(_posixFindCommand(dir, glob));
    if (posix.stdout.trim().isNotEmpty) {
      _findStrategy = _FindStrategy.posixStat;
      return parseStatLines(posix.stdout);
    }
    return const [];
  }

  String _printfFindCommand(String dir, String glob) =>
      'find ${shq(dir)} -maxdepth 1 -name ${shq(glob)} '
      r"-printf '%s %T@ %p\n'";

  String _posixFindCommand(String dir, String glob) =>
      'find ${shq(dir)} -maxdepth 1 -name ${shq(glob)} '
      "-exec stat -c '%s %Y %n' {} +";

  @override
  Future<String> logsTail(int lines) async {
    final cmd = switch (_serviceKind) {
      SystemdService(:final unit) =>
        'journalctl -u ${shq(unit)} -n $lines --no-pager',
      DockerService(:final container) =>
        'docker logs --tail $lines ${shq(container)}',
      ProcessService(:final logPath) =>
        logPath == null ? null : 'tail -n $lines ${shq(logPath)}',
    };
    if (cmd == null) {
      // Only reachable for a bare process. systemd has the journal and Docker has its own
      // log by construction; a script that redirects to a file is the one shape where
      // there may be nothing to read — and the fix is a path, not a retry, so the message
      // says where to put one.
      throw const OperationException(
        'no log file is set for this server, so there is nothing to tail — the game id '
        'is read from the log too. Set one on the Discovery screen.',
        operation: 'stats',
        step: 'logsTail',
      );
    }
    return (await exec(cmd)).stdout;
  }

  @override
  Future<ExecOutput> serviceControl(ServiceAction action) {
    final cmd = switch ((_serviceKind, action)) {
      (SystemdService(:final unit), ServiceAction.status) =>
        'systemctl is-active ${shq(unit)}',
      (SystemdService(:final unit), ServiceAction.stop) =>
        'systemctl stop ${shq(unit)}',
      (SystemdService(:final unit), ServiceAction.start) =>
        'systemctl start ${shq(unit)}',
      (DockerService(:final container), ServiceAction.status) =>
        'docker inspect -f {{.State.Status}} ${shq(container)}',
      (DockerService(:final container), ServiceAction.stop) =>
        'docker stop ${shq(container)}',
      (DockerService(:final container), ServiceAction.start) =>
        'docker start ${shq(container)}',
      // A bare process has no service manager, so discovery captured literal commands
      // to run. They are used verbatim and deliberately not quoted — they *are* shell
      // commands, not values being interpolated into one.
      (ProcessService(:final startCmd), ServiceAction.status) =>
        'pgrep -af ${shq(startCmd)}',
      (ProcessService(:final stopCmd), ServiceAction.stop) => stopCmd,
      (ProcessService(:final startCmd), ServiceAction.start) => startCmd,
    };
    return exec(cmd);
  }

  @override
  Future<RunState> status() async {
    switch (_serviceKind) {
      case SystemdService(:final unit):
        final out = await exec('systemctl is-active ${shq(unit)}');
        return parseSystemdStatus(out.stdout);
      case DockerService(:final container):
        final out = await exec(
          'docker inspect -f {{.State.Status}} ${shq(container)}',
        );
        return parseDockerStatus(out.stdout);
      case ProcessService(:final startCmd):
        final out = await exec('pgrep -f ${shq(startCmd)}');
        return out.stdout.trim().isEmpty ? RunState.stopped : RunState.running;
    }
  }

  @override
  Future<String?> activeSince() async {
    final cmd = switch (_serviceKind) {
      SystemdService(:final unit) =>
        'systemctl show -p ActiveEnterTimestamp --value ${shq(unit)}',
      DockerService(:final container) =>
        'docker inspect -f {{.State.StartedAt}} ${shq(container)}',
      ProcessService() => null,
    };
    if (cmd == null) return null;
    final value = (await exec(cmd)).trimmedStdout;
    return value.isEmpty ? null : value;
  }

  /// Evidence that the game's UDP port is bound.
  ///
  /// Straightforward for systemd and a bare process. Docker needs four tiers, each of
  /// which exists because a real deployment defeated the previous one:
  ///
  /// 1. **Host netns.** Game servers commonly run `--network host` to avoid NAT
  ///    overhead, in which case the process appears on the host exactly like a native
  ///    one. Cheapest check, so it goes first.
  /// 2. **Published ports.** With bridge networking the host only ever sees
  ///    `docker-proxy`, never a process named after the game — so resolve the published
  ///    host ports and look for those instead.
  /// 3. **`ss` inside the container.**
  /// 4. **`/proc/net/udp` inside the container**, because `ss` is absent from most
  ///    minimal images while `cat` and `sh` are not.
  ///
  /// Tier 4 checks `udp6` as well: .NET/Unity on Linux commonly binds a dual-stack IPv6
  /// socket that never appears in `udp`. It also cannot match a specific port, because
  /// Core Keeper binds an OS-assigned **ephemeral** port (observed: 56967) rather than
  /// the widely-assumed 27015 — so any bound UDP socket counts, which is sound for a
  /// container running only this one server.
  @override
  Future<List<String>> udpListening() async {
    switch (_serviceKind) {
      case SystemdService():
      case ProcessService():
        return _lines((await exec(_hostSideUdpCommand)).stdout);

      case DockerService(:final container):
        final hostSide = await exec(_hostSideUdpCommand);
        if (hostSide.stdout.trim().isNotEmpty) return _lines(hostSide.stdout);

        final ports = parseDockerUdpPorts(
          (await exec(
            'docker port ${shq(container)} 2>/dev/null | grep -i udp',
          )).stdout,
        );
        if (ports.isNotEmpty) {
          final pattern = ':(${ports.join('|')})\\b';
          final out = await exec(
            'ss -uln 2>/dev/null | grep -E ${shq(pattern)}',
          );
          return _lines(out.stdout);
        }

        final inContainer = await exec(
          'docker exec ${shq(container)} ss -uln 2>/dev/null',
        );
        // The success check is load-bearing: some OCI runtimes print their "exec failed"
        // message to *stdout* despite the redirect, and without this that error text
        // would be returned as if it were listener data.
        if (inContainer.success) {
          return inContainer.stdout
              .split('\n')
              .where(
                (l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('State'),
              )
              .toList();
        }

        final procNet = await exec(
          'docker exec ${shq(container)} sh -c '
          "'cat /proc/net/udp /proc/net/udp6 2>/dev/null'",
        );
        if (procNet.success) {
          final listeners = parseProcNetUdp(procNet.stdout);
          if (listeners.isNotEmpty) return listeners;
        }

        return const [];
    }
  }

  static const String _hostSideUdpCommand =
      'ss -ulnp 2>/dev/null | grep -i corekeeper';

  static List<String> _lines(String s) =>
      s.split('\n').where((l) => l.trim().isNotEmpty).toList();

  /// Restores ownership after writing world files.
  ///
  /// Only meaningful for systemd targets running the game as a dedicated user. Docker
  /// and bare-process targets are a no-op: the container's UID mapping already owns
  /// these files, and guessing would be worse than doing nothing.
  @override
  Future<void> fixPerms(String path) async {
    final user = _steamUser;
    if (_serviceKind is! SystemdService || user == null || user.isEmpty) return;

    final out = await exec('chown -R ${shq(user)}:${shq(user)} ${shq(path)}');
    if (!out.success) {
      throw OperationException(
        'chown failed: ${out.stderr.trim()}',
        operation: 'push',
        step: 'fixPerms',
      );
    }
  }
}

enum _FindStrategy { unknown, gnuPrintf, posixStat }
