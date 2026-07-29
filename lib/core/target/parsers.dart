import 'package:world_keeper/core/target/exec_output.dart';

/// Parsers for remote command output.
///
/// Deliberately pure functions in their own module: this is where the real bug density
/// lives — every one of these turns loosely-structured text from a machine we don't
/// control into a typed value, and every one of them has at least one edge case that was
/// found the hard way rather than reasoned about up front.

/// Parses `find … -printf '%s %T@ %p\n'` output.
///
/// Splits on the **first two spaces only**. Paths contain spaces — the reference worlds
/// path is `…/Pugstorm/Core Keeper/DedicatedServer/worlds` — so a naive whitespace split
/// truncates every real path at "Core".
///
/// `%T@` is a float (`1753564800.0000000000`); it is truncated to whole epoch seconds.
List<FileEntry> parseFindPrintf(String stdout) {
  final entries = <FileEntry>[];
  for (final line in stdout.split('\n')) {
    if (line.trim().isEmpty) continue;

    final firstSpace = line.indexOf(' ');
    if (firstSpace <= 0) continue;
    final secondSpace = line.indexOf(' ', firstSpace + 1);
    if (secondSpace <= firstSpace) continue;

    final size = int.tryParse(line.substring(0, firstSpace)) ?? 0;
    final mtime = double.tryParse(line.substring(firstSpace + 1, secondSpace));
    final path = line.substring(secondSpace + 1);
    if (path.isEmpty) continue;

    entries.add(FileEntry(path: path, size: size, modified: mtime?.truncate()));
  }
  return entries;
}

/// Parses the POSIX fallback form, `find … -exec stat -c '%s %Y %n' {} +`.
///
/// Same shape as [parseFindPrintf] — size, epoch seconds, path — except `%Y` is already
/// an integer. Used on hosts without GNU findutils (BusyBox, and therefore many minimal
/// container images and NAS firmwares), where `-printf` does not exist.
List<FileEntry> parseStatLines(String stdout) => parseFindPrintf(stdout);

/// Finds Core Keeper's game id in a log tail.
///
/// Scans **in reverse** so the newest match wins: a restart leaves the previous run's id
/// sitting in the same tail window, and taking the first match would report the world
/// that was just replaced.
///
/// Three marker formats have been seen in the wild, from three different packagings —
/// the reference LXC, one Docker image, and `ich777/steamcmd:corekeeper`'s own launch
/// wrapper. Expect to add more; that every packaging logs this differently is the
/// pattern, not the exception.
///
/// `GameID path: …` deliberately does **not** match: the marker requires the colon
/// immediately after `GameID`, so the two can coexist without one shadowing the other.
String? findGameId(String text) {
  const markers = <String>[
    'GameID:',
    'Started session with info:',
    'Server Game ID:',
  ];

  final lines = text.split('\n');
  for (var i = lines.length - 1; i >= 0; i--) {
    final line = lines[i];
    for (final marker in markers) {
      final idx = line.indexOf(marker);
      if (idx == -1) continue;
      final id = line.substring(idx + marker.length).trim();
      if (id.isNotEmpty) return id;
    }
  }
  return null;
}

/// A world file's slot number, and whether it is Core Keeper's own rolling backup.
///
/// Recognises exactly `N.world.gzip` and `N.world.gzip.pugbackup`. Returns `null` for
/// anything else — including `0.world.gzip.old`, `.backup`, and hand-made copies like
/// `0.world.gzip.manual-2026-07-26`, which share the prefix but are emphatically not
/// "the world".
({int slot, bool isPugbackup})? parseWorldFilename(String name) {
  const pugSuffix = '.world.gzip.pugbackup';
  const mainSuffix = '.world.gzip';

  final String digits;
  final bool isPugbackup;
  if (name.endsWith(pugSuffix)) {
    digits = name.substring(0, name.length - pugSuffix.length);
    isPugbackup = true;
  } else if (name.endsWith(mainSuffix)) {
    digits = name.substring(0, name.length - mainSuffix.length);
    isPugbackup = false;
  } else {
    return null;
  }

  if (digits.isEmpty) return null;
  // int.tryParse accepts a leading sign and surrounding whitespace; a slot is plain
  // digits and nothing else.
  for (final unit in digits.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return null;
  }
  final slot = int.tryParse(digits);
  return slot == null ? null : (slot: slot, isPugbackup: isPugbackup);
}

/// Total and available memory in kB, from `/proc/meminfo`.
///
/// `MemAvailable` rather than `MemFree` on purpose: free memory excludes reclaimable
/// page cache and reads alarmingly low on any healthy server.
({int? totalKb, int? availableKb}) parseMeminfo(String text) {
  int? total;
  int? available;
  for (final line in text.split('\n')) {
    if (line.startsWith('MemTotal:')) {
      total = _firstInt(line.substring('MemTotal:'.length));
    } else if (line.startsWith('MemAvailable:')) {
      available = _firstInt(line.substring('MemAvailable:'.length));
    }
  }
  return (totalKb: total, availableKb: available);
}

int? _firstInt(String s) {
  final token = s.trim().split(RegExp(r'\s+')).firstOrNull;
  return token == null ? null : int.tryParse(token);
}

/// Disk figures from `df -h --output=size,used,avail,pcent … | tail -n 1`.
///
/// Values stay strings: `df -h` already formatted them for humans (`9.8G`, `43%`), and
/// re-parsing only to re-format would lose the host's own rounding for no gain.
({String? size, String? used, String? avail, String? usePct}) parseDf(
  String line,
) {
  final parts = line
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  return (
    size: parts.elementAtOrNull(0),
    used: parts.elementAtOrNull(1),
    avail: parts.elementAtOrNull(2),
    usePct: parts.elementAtOrNull(3),
  );
}

/// Host-side UDP ports from `docker port <container> | grep -i udp`.
///
/// Lines look like `27015/udp -> 0.0.0.0:27015`, and the host port is what is wanted:
/// the part after `->`, then after the **last** `:` — last, not first, because an IPv6
/// binding renders as `[::]:27015` and splitting on the first colon yields nothing
/// useful.
List<String> parseDockerUdpPorts(String stdout) {
  final ports = <String>[];
  for (final line in stdout.split('\n')) {
    final arrow = line.indexOf('->');
    if (arrow == -1) continue;
    final rhs = line.substring(arrow + 2).trim();
    if (rhs.isEmpty) continue;
    final colon = rhs.lastIndexOf(':');
    final port = (colon == -1 ? rhs : rhs.substring(colon + 1)).trim();
    if (port.isNotEmpty && !ports.contains(port)) ports.add(port);
  }
  return ports;
}

/// Maps `systemctl is-active` output onto a [RunState].
RunState parseSystemdStatus(String stdout) => switch (stdout.trim()) {
  'active' => RunState.running,
  'inactive' => RunState.stopped,
  'failed' => RunState.failed,
  _ => RunState.unknown,
};

/// Maps `docker inspect -f {{.State.Status}}` output onto a [RunState].
///
/// `restarting` maps to [RunState.unknown], not [RunState.running]: a container caught
/// in a crash loop reports `restarting`, and treating that as "up" would let the
/// envelope declare a start successful moments before the next crash.
RunState parseDockerStatus(String stdout) => switch (stdout.trim()) {
  'running' => RunState.running,
  'exited' || 'created' || 'dead' || 'paused' => RunState.stopped,
  _ => RunState.unknown,
};

/// Whether `/proc/net/udp` (or `udp6`) shows any bound socket.
///
/// Drops the `sl  local_address …` header and blank lines. Used as the last-resort
/// listener check inside a container image with no `ss`; `cat` and `sh` are close to
/// universal where `ss` is not.
List<String> parseProcNetUdp(String stdout) => stdout
    .split('\n')
    .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('sl'))
    .toList();
