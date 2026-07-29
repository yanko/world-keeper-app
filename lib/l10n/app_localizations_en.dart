// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'World Keeper';

  @override
  String get navStats => 'Stats';

  @override
  String get navDiscovery => 'Discovery';

  @override
  String get navLibrary => 'Library';

  @override
  String get navPush => 'Push';

  @override
  String get navPull => 'Pull';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navAudit => 'Audit';

  @override
  String get navMore => 'More';

  @override
  String menuTheme(String mode) {
    return 'Theme: $mode';
  }

  @override
  String get menuThemeSystem => 'system';

  @override
  String get menuThemeLight => 'light';

  @override
  String get menuThemeDark => 'dark';

  @override
  String menuLanguage(String language) {
    return 'Language: $language';
  }

  @override
  String get menuLanguageSystem => 'System';

  @override
  String get menuShortcuts => 'Keyboard shortcuts';

  @override
  String get menuShortcutsWithKey => 'Keyboard shortcuts (F1)';

  @override
  String get menuSafetyNotice => 'Safety notice';

  @override
  String get menuAbout => 'About';

  @override
  String get menuMore => 'More';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutsNothingDestructive =>
      'Nothing destructive has a shortcut. Push, Pull, Restore, Disconnect and Clear are all reachable only by pressing the button and confirming — a keystroke that stops your server is one you would eventually hit by accident.';

  @override
  String get shortcutsTerminalTakesKeys =>
      'While the terminal has focus it takes keys first, so Ctrl+C reaches the remote process rather than this app.';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonEmpty => '(empty)';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonNotConnectedTitle => 'Not connected';

  @override
  String get commonNotConnectedBody =>
      'Pick a profile and connect to see this.';

  @override
  String get commonConnectingTitle => 'Connecting…';

  @override
  String get commonConnectingBody => 'One moment.';

  @override
  String get commonDiscoveryNotConfirmedTitle => 'Discovery not confirmed';

  @override
  String get commonDiscoveryNotConfirmedBody =>
      'Confirm what was found on this host before operating on it.';

  @override
  String get connectionTooltip => 'Connection';

  @override
  String get connectionProfile => 'Profile';

  @override
  String get connectionNew => 'New';

  @override
  String get connectionEdit => 'Edit';

  @override
  String get connectionDelete => 'Delete';

  @override
  String get connectionConnect => 'Connect';

  @override
  String get connectionConnecting => 'Connecting…';

  @override
  String get connectionDisconnect => 'Disconnect';

  @override
  String connectionDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get connectionDeleteBody =>
      'Removes the profile, its cached discovery, and the SSH key this app generated for it. Any password you saved in the OS keychain is left alone, and so is the key\'s line in the server\'s authorized_keys — delete that on the server if you want to revoke access. This cannot be undone from here.';

  @override
  String connectionPasswordTitle(String name) {
    return 'Connect to $name';
  }

  @override
  String connectionPasswordBody(String target) {
    return 'Password for $target. Not stored.';
  }

  @override
  String get connectionPasswordLabel => 'Password';

  @override
  String get connectionStatusDisconnected => 'Disconnected';

  @override
  String get connectionStatusConnecting => 'Connecting…';

  @override
  String get connectionStatusNeedsDiscovery => 'Needs discovery';

  @override
  String get connectionStatusConnected => 'Connected';

  @override
  String connectionStatusSemantics(String status) {
    return 'Connection status: $status';
  }

  @override
  String get profileNewTitle => 'New profile';

  @override
  String profileEditTitle(String name) {
    return 'Edit $name';
  }

  @override
  String get profileName => 'Name';

  @override
  String get profileHost => 'Host';

  @override
  String get profilePort => 'Port';

  @override
  String get profileUser => 'User';

  @override
  String get profileAuthPassword => 'Password';

  @override
  String get profileAuthKey => 'Key';

  @override
  String get profileKeyPath => 'Private key path';

  @override
  String get profileKeyPathRequired => 'Required for key auth';

  @override
  String get profileFieldRequired => 'Required';

  @override
  String get profileSaveChanges => 'Save changes';

  @override
  String get profileAdd => 'Add profile';

  @override
  String get hostKeyNewTitle => 'Trust this host?';

  @override
  String get hostKeyChangedTitle => 'Host key has CHANGED';

  @override
  String hostKeyNewBody(String target) {
    return 'This is the first connection to $target. Verify the fingerprint matches the server, then trust it — later connections will be checked against it.';
  }

  @override
  String hostKeyChangedBody(String target) {
    return 'The key presented by $target does not match the one previously pinned. This means either the server was rebuilt, or something is intercepting the connection. Do not continue unless you know which.';
  }

  @override
  String get hostKeyPreviouslyPinned => 'Previously pinned';

  @override
  String get hostKeyPresentedNow => 'Presented now';

  @override
  String hostKeyFingerprintOf(String type) {
    return '$type fingerprint';
  }

  @override
  String get hostKeyVerifyWith => 'Verify on the server with:';

  @override
  String get hostKeyAcceptNew => 'Accept the new key';

  @override
  String get hostKeyTrustAndConnect => 'Trust and connect';

  @override
  String get hostKeyCopyFingerprint => 'Copy fingerprint';

  @override
  String get discoveryTitle => 'Discovery';

  @override
  String get discoverySubtitle =>
      'Read-only probe. Nothing is saved until you confirm.';

  @override
  String get discoveryConnectFirst => 'Connect to a host to run discovery.';

  @override
  String get discoveryRunProbe => 'Run probe';

  @override
  String get discoveryRescan => 'Re-scan';

  @override
  String get discoveryRunProbeHint =>
      'Run the probe to identify how this server is run and where its worlds live.';

  @override
  String get discoveryOperatingSystem => 'Operating system';

  @override
  String get discoveryUnknownOs => 'unknown';

  @override
  String get discoveryService => 'Service';

  @override
  String get discoveryServiceSeveral =>
      'Service — several matched, pick the real one';

  @override
  String get discoveryServiceNone => 'Service — nothing auto-detected';

  @override
  String get discoverySystemdUnitName => 'systemd unit name';

  @override
  String get discoveryWorldsPath => 'Worlds path';

  @override
  String get discoveryWorldsPathSeveral =>
      'Worlds path — several found, pick one';

  @override
  String get discoveryWorldsPathNone => 'Worlds path — none found';

  @override
  String get discoveryWorldsPathLabel => 'Path to the worlds directory';

  @override
  String get discoveryPickService => 'Pick or enter a service first.';

  @override
  String get discoveryPickWorldsPath => 'Pick or enter a worlds path first.';

  @override
  String get discoverySaving => 'Saving…';

  @override
  String get discoveryConfirm => 'Confirm';

  @override
  String get statsUnknown => 'unknown';

  @override
  String statsSince(String time) {
    return 'since $time';
  }

  @override
  String statsUptime(String duration) {
    return 'uptime $duration';
  }

  @override
  String statsServerClock(String time) {
    return 'server clock $time';
  }

  @override
  String get statsUnitDays => 'd';

  @override
  String get statsUnitHours => 'h';

  @override
  String get statsUnitMinutes => 'm';

  @override
  String get statsCurrentWorld => 'Current world';

  @override
  String get statsNoGameId => 'no game id in the recent log';

  @override
  String get statsCopyGameId => 'Copy game id';

  @override
  String get statsGameIdCopied => 'Game id copied.';

  @override
  String get statsMemory => 'Memory';

  @override
  String get statsDiskWorlds => 'Disk (worlds)';

  @override
  String get statsUdpListening => 'listening';

  @override
  String get statsUdpNotDetected => 'not detected';

  @override
  String get statsUdpListeners => 'UDP listeners';

  @override
  String get statsRecentLog => 'Recent log';

  @override
  String get statsLiveLog => 'Live log';

  @override
  String statsPollingEvery(int seconds) {
    return 'polling every ${seconds}s';
  }

  @override
  String get commonUnknown => 'unknown';

  @override
  String get opPush => 'push';

  @override
  String get opPull => 'pull';

  @override
  String get opRestore => 'restore';

  @override
  String opOtherInProgress(String operation) {
    return 'A $operation is in progress — it stops and restarts the same server, so wait for it to finish.';
  }

  @override
  String get opKeepAppOpen =>
      'Keep the app open. Switching away can interrupt the transfer and leave the server stopped.';

  @override
  String get stepUpload => 'Upload';

  @override
  String get stepCheck => 'Check';

  @override
  String get stepStop => 'Stop';

  @override
  String get stepBackUp => 'Back up';

  @override
  String get stepCopyIn => 'Copy in';

  @override
  String get stepPerms => 'Perms';

  @override
  String get stepStart => 'Start';

  @override
  String get stepGameId => 'Game id';

  @override
  String get stepVerify => 'Verify';

  @override
  String get stepDownload => 'Download';

  @override
  String get stepRestart => 'Restart';

  @override
  String get stepStatusDone => 'Step done';

  @override
  String get stepStatusActive => 'Step running';

  @override
  String get stepStatusError => 'Step failed';

  @override
  String get stepStatusPending => 'Step not started';

  @override
  String slotOption(int slot, String size, String modified) {
    return 'slot $slot — $size, $modified';
  }

  @override
  String slotNumber(String slot) {
    return 'slot $slot';
  }

  @override
  String resultGameId(String id) {
    return 'game id $id';
  }

  @override
  String get worldsNoneOnServer => 'No worlds found on the server.';

  @override
  String get worldsNoneFound => 'No worlds found.';

  @override
  String get pushTitle => 'Push a world';

  @override
  String get pushSubtitle =>
      'Stops the server, backs up what is live, swaps yours in, restarts and verifies. Keep your own backups — this is a homelab tool, not a certified backup product.';

  @override
  String get pushChooseFile => 'Choose file (.zip or .world.gzip)';

  @override
  String get pushChooseFolder => 'Choose folder';

  @override
  String get pushButton => 'Push this world';

  @override
  String pushButtonIntoSlot(int slot) {
    return 'Push into slot $slot';
  }

  @override
  String get pushUploading => 'Uploading';

  @override
  String get pushSlot => 'Slot';

  @override
  String get pushUnassignedSlot =>
      'This file\'s name doesn\'t say which slot it belongs to. Name it N.world.gzip to have that detected automatically, or pick a slot below — which is also how you seed a brand-new slot.';

  @override
  String pushFoundWorlds(int count) {
    return 'Found $count worlds — pick one:';
  }

  @override
  String get pushPugbackupNote =>
      '↳ Core Keeper\'s own rolling backup was found alongside — both travel together.';

  @override
  String pushConfirmTitle(int slot) {
    return 'Swap in world $slot?';
  }

  @override
  String get pushConfirmBody =>
      'This stops the live Core Keeper server, backs up the current world (dated and restorable), copies yours in, restarts, and verifies. If anything fails it restores the backup and restarts automatically.';

  @override
  String get pushConfirmButton => 'Stop server & push';

  @override
  String pushDoneToast(int slot) {
    return 'World $slot swapped in.';
  }

  @override
  String get pushFailedBanner =>
      'Rolled back — the server was restarted automatically';

  @override
  String pushResultLive(int slot) {
    return 'World $slot is live';
  }

  @override
  String pushResultUploaded(String size) {
    return '$size uploaded';
  }

  @override
  String pushResultBackedUpTo(String path) {
    return 'previous world backed up to $path';
  }

  @override
  String get pullTitle => 'Pull a world';

  @override
  String get pullSubtitle =>
      'Stops the server just long enough to copy a consistent world, restarts immediately, then lets you save it.';

  @override
  String get pullButton => 'Pull world';

  @override
  String pullButtonSlot(int slot) {
    return 'Pull world $slot';
  }

  @override
  String get pullDownloading => 'Downloading';

  @override
  String pullConfirmTitle(int slot) {
    return 'Pull world $slot?';
  }

  @override
  String get pullConfirmBody =>
      'Briefly stops the server so the world can be copied while nothing is writing to it, then restarts it immediately. Nothing on the server is modified.';

  @override
  String get pullConfirmButton => 'Stop server & pull';

  @override
  String get pullFailedBanner => 'Failed — a restart was attempted regardless';

  @override
  String pullSavePrompt(String size, int slot) {
    return '$size downloaded — the server is already running again. Save world $slot as:';
  }

  @override
  String get pullSaveAsFolder => 'Folder…';

  @override
  String pullSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get libraryTitle => 'World library';

  @override
  String get librarySubtitle =>
      'What is live on the server, and every dated backup that can be restored.';

  @override
  String get libraryLiveOnServer => 'Live on server';

  @override
  String get libraryBackups => 'Backups';

  @override
  String libraryBackupsCount(int count) {
    return 'Backups ($count)';
  }

  @override
  String get libraryNoBackupsYet =>
      'None yet — your first push or restore creates one.';

  @override
  String get libraryRestore => 'Restore';

  @override
  String restoreConfirmTitle(int slot) {
    return 'Restore world $slot from this backup?';
  }

  @override
  String get restoreConfirmBody =>
      'Stops the server, backs up whatever is live right now (so this restore is itself undoable), copies the backup into place, restarts and verifies.';

  @override
  String get restoreConfirmButton => 'Stop server & restore';

  @override
  String restoreDoneToast(int slot) {
    return 'World $slot restored.';
  }

  @override
  String get restoreFailedBanner =>
      'Rolled back — the safety backup was restored and the server restarted';

  @override
  String restoreResult(int slot) {
    return 'Restored world $slot';
  }

  @override
  String restoreSafetyBackup(String path) {
    return 'safety backup: $path';
  }

  @override
  String get pickerChooseFile => 'Choose a world file or .zip';

  @override
  String get pickerChooseFolder => 'Choose a folder containing worlds';

  @override
  String get pickerSaveInto => 'Save the world into…';

  @override
  String get pickerSaveZip => 'Save world as .zip';

  @override
  String get auditTitle => 'Audit log';

  @override
  String auditCounts(int sessions, int events, int commands, int errors) {
    return '$sessions sessions · $events events · $commands commands · $errors errors';
  }

  @override
  String get auditExport => 'Export';

  @override
  String get auditExporting => 'Exporting…';

  @override
  String get auditExportDialogTitle => 'Export the audit log';

  @override
  String auditExportedTo(String path) {
    return 'Exported to $path';
  }

  @override
  String get auditClear => 'Clear';

  @override
  String get auditLoadMore => 'Load more';

  @override
  String get auditScopeServer => 'Server';

  @override
  String get auditScopeLocked =>
      'Locked to the connected server. Disconnect to read another.';

  @override
  String get auditDeletedProfile => 'Deleted profile';

  @override
  String get auditNothingYetSubtitle =>
      'Nothing recorded yet — connect to a server and it will be.';

  @override
  String get auditNothingYetTitle => 'Nothing recorded yet';

  @override
  String get auditNothingYetBody =>
      'The log is kept per server, and no server has been connected to yet. Connect one and everything this app does to it lands here — every session, command and error.\n\nOnce there is history you can read it without connecting, which is usually when you want it.';

  @override
  String get auditTabEvents => 'Events';

  @override
  String get auditTabCommands => 'SSH commands';

  @override
  String get auditTabErrors => 'Errors';

  @override
  String get auditFilterKind => 'Kind';

  @override
  String get auditFilterAllKinds => 'All kinds';

  @override
  String get auditFilterStatus => 'Status';

  @override
  String get auditFilterAnyStatus => 'Any status';

  @override
  String get auditStatusOk => 'OK';

  @override
  String get auditStatusFailed => 'Failed';

  @override
  String get auditFilterExit => 'Exit';

  @override
  String get auditFilterAnyExit => 'Any exit code';

  @override
  String get auditExitZero => 'Exit 0';

  @override
  String get auditExitNonzero => 'Nonzero';

  @override
  String get auditFilterContext => 'Context';

  @override
  String get auditFilterAllContexts => 'All contexts';

  @override
  String get auditFilterSession => 'Session';

  @override
  String get auditFilterAllSessions => 'All sessions';

  @override
  String get auditSearch => 'Search';

  @override
  String get auditSearchEvents => 'Search kind, state, detail…';

  @override
  String get auditSearchCommands => 'Search command, stdout, stderr…';

  @override
  String get auditSearchErrors => 'Search message, detail…';

  @override
  String get auditNoEventsMatch =>
      'No events for this server match these filters.';

  @override
  String get auditNoCommandsMatch =>
      'No commands for this server match these filters.';

  @override
  String get auditNoErrorsRecorded =>
      'No errors recorded for this server. That is the good outcome.';

  @override
  String get auditNoExitCode => 'no exit';

  @override
  String get auditSucceeded => 'succeeded';

  @override
  String get auditFailed => 'failed';

  @override
  String auditClearTitle(String name) {
    return 'Clear the audit log for $name?';
  }

  @override
  String auditClearBody(String where) {
    return 'Deletes every session, event, SSH command, error, file operation and backup record for $where — all of it, not just what is filtered. Other servers are left alone. This cannot be undone.';
  }

  @override
  String get auditClearConfirm => 'Yes, clear it';

  @override
  String get auditClearSecondTitle => 'Really? This is the black box.';

  @override
  String get auditClearSecondBody =>
      'Every \"why did the server die at 3am\" you could have answered — gone. Every rollback you were quietly glad of — no record it happened. The log does not get better with age, but it is the only thing that remembers.\n\nBackups on the server are NOT affected: the World Library reads those from the filesystem, so restoring still works either way.';

  @override
  String get auditClearSecondConfirm => 'Delete it';

  @override
  String auditClearedToast(String name) {
    return 'Cleared the audit log for $name.';
  }

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalSubtitle =>
      'A real shell over the same connection — the same trust level as ssh to this host, and not sandboxed.';

  @override
  String get terminalCloseSession => 'Close session';

  @override
  String get terminalStartSession => 'Start session';

  @override
  String get terminalOpening => 'Opening…';

  @override
  String get terminalNoSessionTitle => 'No session';

  @override
  String get terminalNoSessionBody =>
      'Start one to get a shell on this host. Nothing is opened automatically.';

  @override
  String terminalOperationWarning(String operation) {
    return 'A $operation is running. Commands typed here can race its own stop/start sequence — best to wait it out.';
  }

  @override
  String get terminalKeyInterrupt => 'Interrupt';

  @override
  String get terminalKeyEndOfInput => 'End of input';

  @override
  String get terminalKeySuspend => 'Suspend';

  @override
  String get terminalKeyLeft => 'Left';

  @override
  String get terminalKeyDown => 'Down';

  @override
  String get terminalKeyUp => 'Up';

  @override
  String get terminalKeyRight => 'Right';

  @override
  String terminalModifier(String key) {
    return '$key modifier';
  }

  @override
  String get disclaimerTitle => 'Before you start';

  @override
  String get disclaimerBody1 =>
      'This tool stops your Core Keeper server and overwrites world files on a remote host you control. It takes a backup before every destructive step and rolls back on failure.';

  @override
  String get disclaimerBody2 =>
      'It is a homelab tool, not a certified backup product. It comes with no guarantee against data loss or corruption.';

  @override
  String get disclaimerBody3 =>
      'Keep your own independent backups of anything you cannot afford to lose.';

  @override
  String get disclaimerBody4 =>
      'Every command it runs on your server is listed under About, and every one it has run is in the audit log.';

  @override
  String get disclaimerAcknowledge => 'I understand';

  @override
  String aboutTitle(String app) {
    return 'About $app';
  }

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutTagline =>
      'Manages a Core Keeper dedicated server’s worlds over SSH.';

  @override
  String get aboutDataTitle => 'Where your data lives';

  @override
  String get aboutDataSubtitle =>
      'The same locations the original desktop app uses, so both can read them.';

  @override
  String get aboutPathConfiguration => 'Configuration';

  @override
  String get aboutPathAuditDatabase => 'Audit database';

  @override
  String get aboutPathImportedFrom => 'Imported from';

  @override
  String get aboutPathImportedNote =>
      'read-only — the original app keeps writing here';

  @override
  String get aboutPathKeys => 'Generated SSH keys';

  @override
  String get aboutShowInFolder => 'Show in folder';

  @override
  String get aboutFolderOpenFailed =>
      'Could not open the folder — path copied instead.';

  @override
  String get aboutCommandsTitle => 'What it runs on your server';

  @override
  String get aboutCommandsSubtitleDisconnected =>
      'Not connected, so values it has not discovered yet show as <placeholders> and all three service kinds are listed.';

  @override
  String aboutCommandsSubtitleConnected(String kind) {
    return 'Filtered to the $kind target it found, with the discovered values filled in and quoted exactly as they are sent.';
  }

  @override
  String get aboutCopyAll => 'Copy all';

  @override
  String aboutCopied(String what) {
    return '$what — copied.';
  }

  @override
  String aboutStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String get targetKindSystemd => 'systemd';

  @override
  String get targetKindDocker => 'Docker';

  @override
  String get targetKindProcess => 'bare process';

  @override
  String get cmdGroupDiscovery => 'Discovery';

  @override
  String get cmdIdentifyOs => 'Identify the OS';

  @override
  String get cmdFindSystemdUnits => 'Find Core Keeper systemd units';

  @override
  String get cmdInspectUnit => 'Inspect a matched unit';

  @override
  String get cmdFindDockerContainers => 'Find Core Keeper docker containers';

  @override
  String get cmdListContainerMounts => 'List a matched container\'s mounts';

  @override
  String get cmdSearchMounts => 'Search each mount for world files';

  @override
  String get cmdFindBareProcess => 'Find a bare Core Keeper process';

  @override
  String get cmdSearchHome =>
      'Search /home for world files (non-Docker targets)';

  @override
  String get cmdGroupListing => 'Listing files';

  @override
  String get cmdListPreferred =>
      'Preferred — one round trip, GNU findutils only';

  @override
  String get cmdListFallback =>
      'Fallback, probed once and cached — for BusyBox and BSD hosts, where -printf does not exist';

  @override
  String get cmdGroupStats => 'Server stats';

  @override
  String get cmdCheckStatus => 'Check status';

  @override
  String get cmdRunningSince => 'Since when it has been running';

  @override
  String get cmdServerClock => 'Server wall-clock time';

  @override
  String get cmdUdpListening => 'UDP port listening?';

  @override
  String get cmdUdpHostNetwork => 'UDP port listening? — 1. host network mode';

  @override
  String get cmdUdpPublishedPorts => 'UDP port listening? — 2. published ports';

  @override
  String get cmdUdpThoseHostPorts =>
      'UDP port listening? — 2b. then look for those host ports';

  @override
  String get cmdUdpInsideContainer =>
      'UDP port listening? — 3. inside the container';

  @override
  String get cmdUdpProcFallback =>
      'UDP port listening? — 4. last resort, /proc (ss is absent from most minimal images)';

  @override
  String get cmdMemoryUsage => 'Memory usage';

  @override
  String get cmdDiskUsage => 'Disk usage of the worlds path';

  @override
  String get cmdHostUptime => 'Host uptime';

  @override
  String get cmdLogTail => 'Recent log tail (game id + live log drawer)';

  @override
  String get cmdGroupPush => 'Push a world';

  @override
  String get cmdCreateStaging => 'Create a staging directory';

  @override
  String get cmdUploadToStaging => 'Upload the world file(s) to staging';

  @override
  String get cmdVerifyChecksum => 'Verify the upload\'s checksum';

  @override
  String get cmdStopService => 'Stop the service';

  @override
  String get cmdListExistingWorld =>
      'List the slot\'s existing world file, if any';

  @override
  String get cmdCreateBackupDir => 'Create a dated backup directory';

  @override
  String get cmdCopyIntoBackup =>
      'Copy the existing world file(s) into the backup';

  @override
  String get cmdMoveIntoPlace => 'Move the staged upload into place';

  @override
  String get cmdFixOwnership =>
      'Fix ownership (only when a Steam user is configured)';

  @override
  String get cmdStartService => 'Start the service';

  @override
  String get cmdCaptureGameId => 'Capture the game id (polls the log tail)';

  @override
  String get cmdVerifyStatus => 'Verify: re-check status and UDP listening';

  @override
  String get cmdRollBack => 'On failure — roll back to the safety backup';

  @override
  String get cmdGroupPull => 'Pull a world';

  @override
  String get cmdListWorldsToPull => 'List worlds available to pull';

  @override
  String get cmdDownloadWorld => 'Download the chosen slot\'s world file(s)';

  @override
  String get cmdPackageLocally => 'Package locally as a folder or zip';

  @override
  String get cmdGroupRestore => 'Restore from a backup (World Library)';

  @override
  String get cmdListBackups => 'List backups';

  @override
  String get cmdSizeBackup => 'Size a backup\'s contents';

  @override
  String get cmdBackUpLiveFirst =>
      'Back up the currently-live world first (same step Push uses)';

  @override
  String get cmdCopyBackupWorld =>
      'Copy the chosen backup\'s world file into place';

  @override
  String get cmdCopyBackupPugbackup =>
      'Copy the chosen backup\'s pugbackup into place, if present';

  @override
  String get cmdCaptureThenVerify => 'Capture the game id, then verify';

  @override
  String get cmdGroupTerminal => 'Terminal';

  @override
  String get cmdOpenShell => 'Open an interactive shell';

  @override
  String get cmdGroupSetup => 'One-time setup';

  @override
  String get cmdInstallPublicKey =>
      'Install this app\'s generated public key (idempotent)';

  @override
  String get discoverySteamUser => 'Runs as';

  @override
  String get discoveryConfirmedTitle => 'Confirmed — this server is ready';

  @override
  String get discoveryConfirmedBody =>
      'Saved against this profile. Stats, Library, Push, Pull and Restore are now available.';

  @override
  String get discoveryConfirmedToast => 'Discovery confirmed.';

  @override
  String get discoveryChange => 'Change';

  @override
  String get discoveryTranscriptTitle => 'What the probe did';

  @override
  String discoveryTranscriptSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commands',
      one: '1 command',
    );
    return '$_temp0, all ran';
  }

  @override
  String discoveryTranscriptSummaryFailures(int count, int failures) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commands',
      one: '1 command',
    );
    return '$_temp0, $failures could not run';
  }

  @override
  String discoveryTranscriptExit(int code) {
    return 'exit $code';
  }

  @override
  String get discoveryTranscriptNoOutput => 'no output';

  @override
  String get discoveryTranscriptCopy => 'Copy the transcript';

  @override
  String get discoveryTranscriptCopied => 'Transcript copied.';

  @override
  String get discoveryDifferentNamespaceTitle =>
      'The server is inside a container';

  @override
  String get discoveryDifferentNamespaceBody =>
      'Its process is visible from here, but its files are not — the paths it was started with belong to the container, so nothing this session searches can find them. Connect this profile to the container itself instead, or enter the worlds path as this session sees it. The container\'s root is:';

  @override
  String get discoveryWorldsPathExpected =>
      'Nothing was found on disk, so this is the standard location for a Core Keeper dedicated server, worked out from the environment the process is running in. It is where the server will save — the directory appears the first time it does. Confirm it if that matches your install.';

  @override
  String get keyAuthSetUp => 'Set up key auth';

  @override
  String keyAuthConfirmTitle(String name) {
    return 'Set up key authentication for $name?';
  }

  @override
  String get keyAuthConfirmBody =>
      'Generates a new SSH key, appends its public half to this host\'s ~/.ssh/authorized_keys, and switches this profile to key auth. You will not be asked for a password again.';

  @override
  String get keyAuthConfirmDetail =>
      'The private key stays on this device and is never sent. Nothing on the server is removed or changed apart from that one added line — delete it there to revoke access.';

  @override
  String get keyAuthConfirmButton => 'Generate and install';

  @override
  String get keyAuthDone =>
      'Key installed — this profile no longer needs a password.';

  @override
  String get statsRefresh => 'Refresh now';

  @override
  String get cmdFindGameBinary => 'Find the game binary the launcher started';

  @override
  String get cmdReadProcessEnvironment =>
      'Read HOME and XDG_CONFIG_HOME from the running process';

  @override
  String get cmdReadProcessPaths =>
      'Read the process\'s filesystem root and working directory';

  @override
  String get recoveryTitle => 'An operation was interrupted';

  @override
  String recoveryBody(String operation, String phase) {
    return 'A $operation on this server stopped part-way, at “$phase”. Push, pull and restore all stop the game service and start it again, so it may still be down.';
  }

  @override
  String get recoveryChecking => 'Asking the server…';

  @override
  String get recoveryStopped => 'The service is stopped.';

  @override
  String get recoveryRunning => 'The service is running — nothing to do.';

  @override
  String get recoveryRestoreHint =>
      'Starting it brings the server back with whatever world files are in place. If the swap was cut off half-way, restore the most recent backup from the World Library instead.';

  @override
  String get recoveryStartServer => 'Start the server';

  @override
  String get recoveryDismiss => 'Dismiss';

  @override
  String get discoveryLogPath => 'Log file';

  @override
  String get discoveryLogPathLabel => 'Path to the server\'s log file';

  @override
  String get discoveryLogPathHint =>
      'Optional, but without it there is no live log and no game id — the id is read out of the log. Usually wherever the launch script redirects its output.';
}
