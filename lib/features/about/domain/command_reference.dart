/// Every remote command this app can issue, as documentation.
///
/// The app stops a game server, overwrites world files and starts it again, over SSH, on
/// a machine it discovered rather than one it was told about. That is a lot of trust to
/// ask for on the strength of a button labelled "Push". This list is the answer to "what
/// will it actually run on my box", answerable *before* running it.
///
/// Nothing here executes. Each entry mirrors a command string built in `discovery_probe`,
/// `ssh_target`, `stats_service` or one of the envelopes, grouped and ordered the way the
/// real operation runs them. Values discovered from the live connection are substituted in
/// — shell-quoted exactly as they would be sent, so a line can be copied straight into a
/// terminal — and anything not yet known shows as a `<placeholder>`.
///
/// Deliberately a static list rather than a database table: it documents the code, not
/// user data, so it needs no migration and is untouched by "Clear audit log".
///
/// Keeping it truthful is a manual discipline — a command changed in `ssh_target.dart`
/// and not here makes this worse than nothing. `command_reference_test.dart` pins the
/// shapes that can be checked mechanically.
library;

import 'package:world_keeper/core/ssh/shell_quote.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Which service-manager variant an entry documents.
///
/// `null` on an entry means it runs the same way regardless — `df -h`, `cat /proc/meminfo`
/// — and it is always shown. The rest are filtered down to the discovered kind once there
/// is one, because three variants of "Stop the service" is noise when only one of them
/// will ever run against your server.
enum TargetKind {
  systemd('systemd'),
  docker('Docker'),
  process('bare process');

  const TargetKind(this.label);

  /// The English name, used by [commandReferenceAsText] — the copy-all output sits
  /// alongside shell commands and stays in one language regardless of the interface.
  /// For anything on screen use [targetKindLabel].
  final String label;
}

/// The display name of a target kind.
///
/// `systemd` and `Docker` are proper nouns and identical in every language; "bare process"
/// is a description and is not.
String targetKindLabel(AppLocalizations l10n, TargetKind kind) =>
    switch (kind) {
      TargetKind.systemd => l10n.targetKindSystemd,
      TargetKind.docker => l10n.targetKindDocker,
      TargetKind.process => l10n.targetKindProcess,
    };

class CommandRefEntry {
  CommandRefEntry(this.label, this.command, [this.targetKind]);

  /// What this step is for, in plain language.
  final String label;

  /// The command as it would be sent — or a parenthesised note where the step is not a
  /// shell command at all (an SFTP transfer, a local file write, an interactive PTY).
  final String command;

  final TargetKind? targetKind;

  /// True when [command] is a note rather than something runnable.
  bool get isNote => command.startsWith('(');
}

class CommandRefGroup {
  const CommandRefGroup(this.group, this.entries);

  final String group;
  final List<CommandRefEntry> entries;
}

/// What the live connection knows so far — every field null when disconnected.
class KnownValues {
  const KnownValues({this.worldsPath, this.serviceKind, this.steamUser});

  final String? worldsPath;
  final ServiceKind? serviceKind;

  /// Only ever used for one best-effort `chown` on systemd targets.
  final String? steamUser;

  TargetKind? get targetKind => switch (serviceKind) {
    SystemdService() => TargetKind.systemd,
    DockerService() => TargetKind.docker,
    ProcessService() => TargetKind.process,
    null => null,
  };
}

/// A real value, shell-quoted so the line is copy-pasteable, or a bare `<placeholder>`.
///
/// Placeholders are left unquoted on purpose: `find '<worlds_path>'` looks like something
/// you could run, and it is not.
String _or(String? value, String placeholder) =>
    (value == null || value.isEmpty) ? '<$placeholder>' : shq(value);

/// Builds the reference, filtered to [known]'s service kind when there is one.
List<CommandRefGroup> buildCommandReference(
  AppLocalizations l10n, [
  KnownValues known = const KnownValues(),
]) {
  final worlds = _or(known.worldsPath, 'worlds_path');
  final user = _or(known.steamUser, 'user');

  // `startCmd` appears two different ways and the difference is not cosmetic. Running the
  // process means sending its captured command line verbatim — it *is* a shell command,
  // not a value inside one. Asking whether it is running means passing that same text to
  // `pgrep` as an argument, where it must be quoted or a command containing a space
  // becomes several arguments. `startPattern` is that second form.
  final (
    unit,
    container,
    startCmd,
    startPattern,
    stopCmd,
    logPath,
  ) = switch (known.serviceKind) {
    SystemdService(:final unit) => (
      shq(unit),
      '<container>',
      '<start_cmd>',
      '<start_cmd>',
      '<stop_cmd>',
      '<log_path>',
    ),
    DockerService(:final container) => (
      '<unit>',
      shq(container),
      '<start_cmd>',
      '<start_cmd>',
      '<stop_cmd>',
      '<log_path>',
    ),
    ProcessService(:final startCmd, :final stopCmd, :final logPath) => (
      '<unit>',
      '<container>',
      startCmd,
      shq(startCmd),
      stopCmd,
      _or(logPath, 'log_path'),
    ),
    null => (
      '<unit>',
      '<container>',
      '<start_cmd>',
      '<start_cmd>',
      '<stop_cmd>',
      '<log_path>',
    ),
  };

  final groups = <CommandRefGroup>[
    _discovery(l10n),
    _listing(l10n),
    _stats(l10n, worlds, unit, container, startPattern, logPath),
    _push(l10n, worlds, user, unit, container, startCmd, startPattern, stopCmd),
    _pull(l10n, worlds, unit, container, startCmd, startPattern, stopCmd),
    _restore(
      l10n,
      worlds,
      user,
      unit,
      container,
      startCmd,
      startPattern,
      stopCmd,
    ),
    _terminal(l10n),
    _setup(l10n),
  ];

  final kind = known.targetKind;
  if (kind == null) return groups;
  return [
    for (final g in groups)
      CommandRefGroup(g.group, [
        for (final e in g.entries)
          if (e.targetKind == null || e.targetKind == kind) e,
      ]),
  ];
}

CommandRefGroup _discovery(
  AppLocalizations l10n,
) => CommandRefGroup(l10n.cmdGroupDiscovery, [
  CommandRefEntry(l10n.cmdIdentifyOs, 'cat /etc/os-release 2>/dev/null'),
  CommandRefEntry(
    l10n.cmdFindSystemdUnits,
    'systemctl list-units --type=service --all --no-pager --no-legend --plain',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdInspectUnit,
    'systemctl cat <unit> --no-pager',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdFindDockerContainers,
    "docker ps --format '{{.Names}} {{.Image}}'",
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdListContainerMounts,
    "docker inspect <container> --format '{{json .Mounts}}' 2>/dev/null",
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdSearchMounts,
    "find <mount_source> -name '*.world.gzip' 2>/dev/null",
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdFindBareProcess,
    'pgrep -af _launch.sh',
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdFindGameBinary,
    'pgrep -af CoreKeeperServer',
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdReadProcessEnvironment,
    // Raw string: the reference has to show the two escapes `tr` is actually handed, and
    // in an ordinary Dart literal `\n` would become a newline before it ever got here.
    r"tr '\0' '\n' < /proc/<pid>/environ 2>/dev/null | "
    r"grep -E '^(HOME|XDG_CONFIG_HOME)='",
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdReadProcessPaths,
    'readlink /proc/<pid>/root; readlink /proc/<pid>/cwd',
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdSearchHome,
    "find /home -name '*.world.gzip' 2>/dev/null",
  ),
]);

/// The one place the two listing strategies are spelled out; the operation groups below
/// show their concrete `find` lines and inherit the same fallback.
CommandRefGroup _listing(AppLocalizations l10n) =>
    CommandRefGroup(l10n.cmdGroupListing, [
      CommandRefEntry(
        l10n.cmdListPreferred,
        r"find <dir> -maxdepth 1 -name <glob> -printf '%s %T@ %p\n'",
      ),
      CommandRefEntry(
        l10n.cmdListFallback,
        "find <dir> -maxdepth 1 -name <glob> -exec stat -c '%s %Y %n' {} +",
      ),
    ]);

CommandRefGroup _stats(
  AppLocalizations l10n,
  String worlds,
  String unit,
  String container,
  String startPattern,
  String logPath,
) => CommandRefGroup(l10n.cmdGroupStats, [
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'systemctl is-active $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'docker inspect -f {{.State.Status}} $container',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'pgrep -f $startPattern',
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdRunningSince,
    'systemctl show -p ActiveEnterTimestamp --value $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdRunningSince,
    'docker inspect -f {{.State.StartedAt}} $container',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdServerClock,
    'date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null',
  ),
  CommandRefEntry(
    l10n.cmdUdpListening,
    'ss -ulnp 2>/dev/null | grep -i corekeeper',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdUdpListening,
    'ss -ulnp 2>/dev/null | grep -i corekeeper',
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdUdpHostNetwork,
    'ss -ulnp 2>/dev/null | grep -i corekeeper',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdUdpPublishedPorts,
    'docker port $container 2>/dev/null | grep -i udp',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdUdpThoseHostPorts,
    "ss -uln 2>/dev/null | grep -E ':(<port>|<port>)\\b'",
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdUdpInsideContainer,
    'docker exec $container ss -uln 2>/dev/null',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdUdpProcFallback,
    'docker exec $container sh -c '
    "'cat /proc/net/udp /proc/net/udp6 2>/dev/null'",
    TargetKind.docker,
  ),
  CommandRefEntry(l10n.cmdMemoryUsage, 'cat /proc/meminfo 2>/dev/null'),
  CommandRefEntry(
    l10n.cmdDiskUsage,
    'df -h --output=size,used,avail,pcent $worlds 2>/dev/null | tail -n 1',
  ),
  CommandRefEntry(l10n.cmdHostUptime, 'cat /proc/uptime 2>/dev/null'),
  CommandRefEntry(
    l10n.cmdLogTail,
    'journalctl -u $unit -n <lines> --no-pager',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdLogTail,
    'docker logs --tail <lines> $container',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdLogTail,
    'tail -n <lines> $logPath',
    TargetKind.process,
  ),
]);

CommandRefGroup _push(
  AppLocalizations l10n,
  String worlds,
  String user,
  String unit,
  String container,
  String startCmd,
  String startPattern,
  String stopCmd,
) => CommandRefGroup(l10n.cmdGroupPush, [
  CommandRefEntry(l10n.cmdCreateStaging, 'mkdir -p $worlds/.staging'),
  CommandRefEntry(
    l10n.cmdUploadToStaging,
    '(SFTP over the same SSH connection — a binary transfer, not a shell command)',
  ),
  CommandRefEntry(
    l10n.cmdVerifyChecksum,
    'sha256sum $worlds/.staging/<slot>.world.gzip',
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'systemctl is-active $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'docker inspect -f {{.State.Status}} $container',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'pgrep -af $startPattern',
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdStopService,
    'systemctl stop $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdStopService,
    'docker stop $container',
    TargetKind.docker,
  ),
  CommandRefEntry(l10n.cmdStopService, stopCmd, TargetKind.process),
  CommandRefEntry(
    l10n.cmdListExistingWorld,
    "find $worlds -maxdepth 1 -name '<slot>.world.gzip' "
    r"-printf '%s %T@ %p\n'",
  ),
  CommandRefEntry(
    l10n.cmdCreateBackupDir,
    'mkdir -p $worlds/.backups/<slot>.<timestamp>',
  ),
  CommandRefEntry(
    l10n.cmdCopyIntoBackup,
    'cp -a $worlds/<slot>.world.gzip $worlds/.backups/<slot>.<timestamp>/',
  ),
  CommandRefEntry(
    l10n.cmdMoveIntoPlace,
    'mv $worlds/.staging/<slot>.world.gzip $worlds/<slot>.world.gzip',
  ),
  CommandRefEntry(
    l10n.cmdFixOwnership,
    'chown -R $user:$user $worlds',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdStartService,
    'systemctl start $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdStartService,
    'docker start $container',
    TargetKind.docker,
  ),
  CommandRefEntry(l10n.cmdStartService, startCmd, TargetKind.process),
  CommandRefEntry(
    l10n.cmdCaptureGameId,
    'journalctl -u $unit -n 200 --no-pager',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdCaptureGameId,
    'docker logs --tail 200 $container',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdVerifyStatus,
    '(reuses the Server stats checks above)',
  ),
  CommandRefEntry(
    l10n.cmdRollBack,
    'cp -a $worlds/.backups/<slot>.<timestamp>/. $worlds/',
  ),
]);

CommandRefGroup _pull(
  AppLocalizations l10n,
  String worlds,
  String unit,
  String container,
  String startCmd,
  String startPattern,
  String stopCmd,
) => CommandRefGroup(l10n.cmdGroupPull, [
  CommandRefEntry(
    l10n.cmdListWorldsToPull,
    "find $worlds -maxdepth 1 -name '*.world.gzip' "
    r"-printf '%s %T@ %p\n'",
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'systemctl is-active $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'docker inspect -f {{.State.Status}} $container',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'pgrep -af $startPattern',
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdStopService,
    'systemctl stop $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdStopService,
    'docker stop $container',
    TargetKind.docker,
  ),
  CommandRefEntry(l10n.cmdStopService, stopCmd, TargetKind.process),
  CommandRefEntry(
    l10n.cmdDownloadWorld,
    '(SFTP over the same SSH connection — a binary transfer, not a shell command)',
  ),
  CommandRefEntry(
    l10n.cmdStartService,
    'systemctl start $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdStartService,
    'docker start $container',
    TargetKind.docker,
  ),
  CommandRefEntry(l10n.cmdStartService, startCmd, TargetKind.process),
  CommandRefEntry(
    l10n.cmdPackageLocally,
    '(local file I/O only — nothing runs on the server)',
  ),
]);

CommandRefGroup _restore(
  AppLocalizations l10n,
  String worlds,
  String user,
  String unit,
  String container,
  String startCmd,
  String startPattern,
  String stopCmd,
) => CommandRefGroup(l10n.cmdGroupRestore, [
  CommandRefEntry(
    l10n.cmdListBackups,
    "find $worlds/.backups -maxdepth 1 -name '*' "
    r"-printf '%s %T@ %p\n'",
  ),
  CommandRefEntry(
    l10n.cmdSizeBackup,
    "find <backup_path> -maxdepth 1 -name '*' "
    r"-printf '%s %T@ %p\n'",
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'systemctl is-active $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'docker inspect -f {{.State.Status}} $container',
    TargetKind.docker,
  ),
  CommandRefEntry(
    l10n.cmdCheckStatus,
    'pgrep -af $startPattern',
    TargetKind.process,
  ),
  CommandRefEntry(
    l10n.cmdStopService,
    'systemctl stop $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdStopService,
    'docker stop $container',
    TargetKind.docker,
  ),
  CommandRefEntry(l10n.cmdStopService, stopCmd, TargetKind.process),
  CommandRefEntry(
    l10n.cmdBackUpLiveFirst,
    'cp -a $worlds/<slot>.world.gzip $worlds/.backups/<slot>.<timestamp>/',
  ),
  CommandRefEntry(
    l10n.cmdCopyBackupWorld,
    'cp -a <backup_path>/<slot>.world.gzip $worlds/',
  ),
  CommandRefEntry(
    l10n.cmdCopyBackupPugbackup,
    'cp -a <backup_path>/<slot>.world.gzip.pugbackup $worlds/',
  ),
  CommandRefEntry(
    l10n.cmdFixOwnership,
    'chown -R $user:$user $worlds',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdStartService,
    'systemctl start $unit',
    TargetKind.systemd,
  ),
  CommandRefEntry(
    l10n.cmdStartService,
    'docker start $container',
    TargetKind.docker,
  ),
  CommandRefEntry(l10n.cmdStartService, startCmd, TargetKind.process),
  CommandRefEntry(
    l10n.cmdCaptureThenVerify,
    '(reuses the Push a world steps above)',
  ),
  CommandRefEntry(
    l10n.cmdRollBack,
    'cp -a $worlds/.backups/<slot>.<timestamp>/. $worlds/',
  ),
]);

CommandRefGroup _terminal(AppLocalizations l10n) =>
    CommandRefGroup(l10n.cmdGroupTerminal, [
      CommandRefEntry(
        l10n.cmdOpenShell,
        '(a real PTY over SSH — whatever you type is sent as-is, exactly like '
        '`ssh user@host`. There is no fixed command string)',
      ),
    ]);

CommandRefGroup _setup(
  AppLocalizations l10n,
) => CommandRefGroup(l10n.cmdGroupSetup, [
  CommandRefEntry(
    l10n.cmdInstallPublicKey,
    'mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && '
    'chmod 600 ~/.ssh/authorized_keys && '
    "(grep -qF '<public_key>' ~/.ssh/authorized_keys || "
    "echo '<public_key>' >> ~/.ssh/authorized_keys)",
  ),
]);

/// The whole reference as plain text, for "copy all".
String commandReferenceAsText(List<CommandRefGroup> groups) {
  final buffer = StringBuffer();
  for (final group in groups) {
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.writeln('## ${group.group}');
    for (final entry in group.entries) {
      buffer.writeln();
      final kind = entry.targetKind;
      buffer.writeln(
        '# ${entry.label}${kind == null ? '' : ' [${kind.label}]'}',
      );
      buffer.writeln(entry.command);
    }
  }
  return buffer.toString();
}
