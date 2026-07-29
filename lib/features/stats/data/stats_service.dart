import 'package:world_keeper/core/ssh/shell_quote.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/parsers.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/features/stats/domain/server_stats.dart';

/// Collects the read-only stats dashboard.
///
/// Written entirely against [ServerTarget], so it knows nothing about systemd, Docker or
/// processes — and can be tested against a fake.
///
/// Every command here is safe: no writes, no service control. It is polled on a timer
/// while the stats screen is visible, including *during* a push, which is exactly why it
/// must never contend with the operation lock.
class StatsService {
  const StatsService(this._target);

  final ServerTarget _target;

  /// How many log lines to fetch when looking for the game id.
  ///
  /// 200, not a short window: a noisy startup — Docker in particular logs dozens of
  /// allocator lines before the game id appears — pushes it out of a small tail, and the
  /// symptom is a silently absent game id rather than an error.
  static const int logTailLines = 200;

  Future<ServerStats> collect() async {
    final status = await _target.serviceControl(ServiceAction.status);
    final activeSince = await _safe(_target.activeSince);
    final serverTime = await _firstLine(
      'date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null',
    );
    final udp = await _safeList(_target.udpListening);

    final meminfo = parseMeminfo(
      (await _exec('cat /proc/meminfo 2>/dev/null')).stdout,
    );

    final df = parseDf(
      (await _exec(
        'df -h --output=size,used,avail,pcent ${shq(_target.worldsPath)} '
        '2>/dev/null | tail -n 1',
      )).stdout.trim(),
    );

    final uptime = _parseUptime(
      (await _exec('cat /proc/uptime 2>/dev/null')).stdout,
    );

    final logTail = await _safeString(() => _target.logsTail(logTailLines));

    return ServerStats(
      serviceStatus: status.trimmedStdout,
      activeSince: activeSince,
      serverTime: serverTime,
      udpListening: udp,
      memTotalKb: meminfo.totalKb,
      memAvailableKb: meminfo.availableKb,
      diskSize: df.size,
      diskUsed: df.used,
      diskAvail: df.avail,
      diskUsePct: df.usePct,
      uptimeSeconds: uptime,
      gameId: findGameId(logTail),
      recentLogTail: logTail,
    );
  }

  /// `/proc/uptime`'s first field is seconds as a float.
  static int? _parseUptime(String stdout) {
    final token = stdout.trim().split(RegExp(r'\s+')).firstOrNull;
    if (token == null) return null;
    return double.tryParse(token)?.truncate();
  }

  // A stats panel is a *dashboard*. One command failing — a container without
  // `/proc/meminfo`, a `df` on a path that briefly vanished mid-swap — should blank that
  // one figure, not tear down the whole poll and replace the screen with an error.
  Future<ExecOutput> _exec(String cmd) async {
    try {
      return await _target.exec(cmd);
    } on Object {
      return const ExecOutput.empty();
    }
  }

  Future<String?> _firstLine(String cmd) async {
    final value = (await _exec(cmd)).trimmedStdout;
    return value.isEmpty ? null : value;
  }

  Future<String?> _safe(Future<String?> Function() f) async {
    try {
      return await f();
    } on Object {
      return null;
    }
  }

  Future<List<String>> _safeList(Future<List<String>> Function() f) async {
    try {
      return await f();
    } on Object {
      return const [];
    }
  }

  Future<String> _safeString(Future<String> Function() f) async {
    try {
      return await f();
    } on Object {
      return '';
    }
  }
}
