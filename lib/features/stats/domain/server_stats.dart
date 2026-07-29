/// A snapshot of the server, gathered by read-only commands.
class ServerStats {
  const ServerStats({
    required this.serviceStatus,
    this.activeSince,
    this.serverTime,
    this.udpListening = const [],
    this.memTotalKb,
    this.memAvailableKb,
    this.diskSize,
    this.diskUsed,
    this.diskAvail,
    this.diskUsePct,
    this.uptimeSeconds,
    this.gameId,
    this.recentLogTail = '',
  });

  /// The service manager's own status text (`active`, `running`, pgrep output…).
  /// Kept raw for display; use a normalised `RunState` for decisions.
  final String serviceStatus;

  final String? activeSince;

  /// The server's own wall clock — distinct from uptime, which only measures time since
  /// boot and can't reveal a clock that has drifted.
  final String? serverTime;

  final List<String> udpListening;

  final int? memTotalKb;
  final int? memAvailableKb;

  final String? diskSize;
  final String? diskUsed;
  final String? diskAvail;
  final String? diskUsePct;

  final int? uptimeSeconds;

  /// The currently-loaded world, parsed from the log tail.
  ///
  /// Persistent visibility, not just during a push — knowing which world is live is the
  /// question this app exists to answer, and it should never require running an
  /// operation to find out.
  final String? gameId;

  final String recentLogTail;

  int? get memUsedKb {
    final total = memTotalKb;
    final available = memAvailableKb;
    if (total == null || available == null) return null;
    return total - available;
  }

  bool get isListening => udpListening.isNotEmpty;
}
