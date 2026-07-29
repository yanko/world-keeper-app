import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// The product name. Not translated in any language — it is a name.
  ///
  /// In en, this message translates to:
  /// **'World Keeper'**
  String get appTitle;

  /// Navigation destination: live server health.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// Navigation destination: probing a host to find out how the server is installed.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get navDiscovery;

  /// Navigation destination: worlds on the server plus every backup taken.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// Navigation destination: send a local world up to the server. Short — it is a nav label under an icon.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get navPush;

  /// Navigation destination: download a world from the server.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get navPull;

  /// No description provided for @navTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get navTerminal;

  /// Navigation destination: the log of everything the app has done.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get navAudit;

  /// The fifth slot in the phone's bottom bar, opening a sheet with the destinations that did not fit.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// Tooltip and menu entry for the theme cycler. Names the CURRENT state, not the next one.
  ///
  /// In en, this message translates to:
  /// **'Theme: {mode}'**
  String menuTheme(String mode);

  /// No description provided for @menuThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'system'**
  String get menuThemeSystem;

  /// No description provided for @menuThemeLight.
  ///
  /// In en, this message translates to:
  /// **'light'**
  String get menuThemeLight;

  /// No description provided for @menuThemeDark.
  ///
  /// In en, this message translates to:
  /// **'dark'**
  String get menuThemeDark;

  /// Tooltip for the language cycler. {language} is already in its own language — 'Français', not 'French'.
  ///
  /// In en, this message translates to:
  /// **'Language: {language}'**
  String menuLanguage(String language);

  /// The language option meaning 'whatever the device is set to'.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get menuLanguageSystem;

  /// No description provided for @menuShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get menuShortcuts;

  /// No description provided for @menuShortcutsWithKey.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts (F1)'**
  String get menuShortcutsWithKey;

  /// No description provided for @menuSafetyNotice.
  ///
  /// In en, this message translates to:
  /// **'Safety notice'**
  String get menuSafetyNotice;

  /// No description provided for @menuAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get menuAbout;

  /// Tooltip on the phone's overflow menu button.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get menuMore;

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @shortcutsNothingDestructive.
  ///
  /// In en, this message translates to:
  /// **'Nothing destructive has a shortcut. Push, Pull, Restore, Disconnect and Clear are all reachable only by pressing the button and confirming — a keystroke that stops your server is one you would eventually hit by accident.'**
  String get shortcutsNothingDestructive;

  /// No description provided for @shortcutsTerminalTakesKeys.
  ///
  /// In en, this message translates to:
  /// **'While the terminal has focus it takes keys first, so Ctrl+C reaches the remote process rather than this app.'**
  String get shortcutsTerminalTakesKeys;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get commonEmpty;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonNotConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get commonNotConnectedTitle;

  /// No description provided for @commonNotConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile and connect to see this.'**
  String get commonNotConnectedBody;

  /// No description provided for @commonConnectingTitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get commonConnectingTitle;

  /// No description provided for @commonConnectingBody.
  ///
  /// In en, this message translates to:
  /// **'One moment.'**
  String get commonConnectingBody;

  /// No description provided for @commonDiscoveryNotConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discovery not confirmed'**
  String get commonDiscoveryNotConfirmedTitle;

  /// No description provided for @commonDiscoveryNotConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm what was found on this host before operating on it.'**
  String get commonDiscoveryNotConfirmedBody;

  /// Tooltip on the phone app bar button that opens the connection sheet.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionTooltip;

  /// No description provided for @connectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get connectionProfile;

  /// No description provided for @connectionNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get connectionNew;

  /// No description provided for @connectionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get connectionEdit;

  /// No description provided for @connectionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get connectionDelete;

  /// No description provided for @connectionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectionConnect;

  /// No description provided for @connectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionConnecting;

  /// No description provided for @connectionDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get connectionDisconnect;

  /// No description provided for @connectionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String connectionDeleteTitle(String name);

  /// No description provided for @connectionDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Removes the profile, its cached discovery, and the SSH key this app generated for it. Any password you saved in the OS keychain is left alone, and so is the key\'s line in the server\'s authorized_keys — delete that on the server if you want to revoke access. This cannot be undone from here.'**
  String get connectionDeleteBody;

  /// No description provided for @connectionPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to {name}'**
  String connectionPasswordTitle(String name);

  /// {target} is user@host — an address, never translated.
  ///
  /// In en, this message translates to:
  /// **'Password for {target}. Not stored.'**
  String connectionPasswordBody(String target);

  /// No description provided for @connectionPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get connectionPasswordLabel;

  /// No description provided for @connectionStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectionStatusDisconnected;

  /// No description provided for @connectionStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionStatusConnecting;

  /// Authenticated, but the host has not been probed yet, so no operation can run.
  ///
  /// In en, this message translates to:
  /// **'Needs discovery'**
  String get connectionStatusNeedsDiscovery;

  /// No description provided for @connectionStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionStatusConnected;

  /// Screen-reader label for the status chip, which is otherwise a coloured dot.
  ///
  /// In en, this message translates to:
  /// **'Connection status: {status}'**
  String connectionStatusSemantics(String status);

  /// No description provided for @profileNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profileNewTitle;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String profileEditTitle(String name);

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get profileHost;

  /// No description provided for @profilePort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get profilePort;

  /// No description provided for @profileUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileUser;

  /// No description provided for @profileAuthPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get profileAuthPassword;

  /// Authentication by SSH key, as opposed to by password.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get profileAuthKey;

  /// No description provided for @profileKeyPath.
  ///
  /// In en, this message translates to:
  /// **'Private key path'**
  String get profileKeyPath;

  /// No description provided for @profileKeyPathRequired.
  ///
  /// In en, this message translates to:
  /// **'Required for key auth'**
  String get profileKeyPathRequired;

  /// No description provided for @profileFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get profileFieldRequired;

  /// No description provided for @profileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSaveChanges;

  /// No description provided for @profileAdd.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get profileAdd;

  /// No description provided for @hostKeyNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust this host?'**
  String get hostKeyNewTitle;

  /// The capitals are deliberate — this is the one screen in the app that might be showing an interception in progress.
  ///
  /// In en, this message translates to:
  /// **'Host key has CHANGED'**
  String get hostKeyChangedTitle;

  /// No description provided for @hostKeyNewBody.
  ///
  /// In en, this message translates to:
  /// **'This is the first connection to {target}. Verify the fingerprint matches the server, then trust it — later connections will be checked against it.'**
  String hostKeyNewBody(String target);

  /// No description provided for @hostKeyChangedBody.
  ///
  /// In en, this message translates to:
  /// **'The key presented by {target} does not match the one previously pinned. This means either the server was rebuilt, or something is intercepting the connection. Do not continue unless you know which.'**
  String hostKeyChangedBody(String target);

  /// No description provided for @hostKeyPreviouslyPinned.
  ///
  /// In en, this message translates to:
  /// **'Previously pinned'**
  String get hostKeyPreviouslyPinned;

  /// No description provided for @hostKeyPresentedNow.
  ///
  /// In en, this message translates to:
  /// **'Presented now'**
  String get hostKeyPresentedNow;

  /// {type} is the SSH key algorithm, e.g. ssh-ed25519. Not translated.
  ///
  /// In en, this message translates to:
  /// **'{type} fingerprint'**
  String hostKeyFingerprintOf(String type);

  /// No description provided for @hostKeyVerifyWith.
  ///
  /// In en, this message translates to:
  /// **'Verify on the server with:'**
  String get hostKeyVerifyWith;

  /// No description provided for @hostKeyAcceptNew.
  ///
  /// In en, this message translates to:
  /// **'Accept the new key'**
  String get hostKeyAcceptNew;

  /// No description provided for @hostKeyTrustAndConnect.
  ///
  /// In en, this message translates to:
  /// **'Trust and connect'**
  String get hostKeyTrustAndConnect;

  /// No description provided for @hostKeyCopyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Copy fingerprint'**
  String get hostKeyCopyFingerprint;

  /// No description provided for @discoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get discoveryTitle;

  /// No description provided for @discoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only probe. Nothing is saved until you confirm.'**
  String get discoverySubtitle;

  /// No description provided for @discoveryConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect to a host to run discovery.'**
  String get discoveryConnectFirst;

  /// No description provided for @discoveryRunProbe.
  ///
  /// In en, this message translates to:
  /// **'Run probe'**
  String get discoveryRunProbe;

  /// No description provided for @discoveryRescan.
  ///
  /// In en, this message translates to:
  /// **'Re-scan'**
  String get discoveryRescan;

  /// No description provided for @discoveryRunProbeHint.
  ///
  /// In en, this message translates to:
  /// **'Run the probe to identify how this server is run and where its worlds live.'**
  String get discoveryRunProbeHint;

  /// No description provided for @discoveryOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'Operating system'**
  String get discoveryOperatingSystem;

  /// No description provided for @discoveryUnknownOs.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get discoveryUnknownOs;

  /// No description provided for @discoveryService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get discoveryService;

  /// No description provided for @discoveryServiceSeveral.
  ///
  /// In en, this message translates to:
  /// **'Service — several matched, pick the real one'**
  String get discoveryServiceSeveral;

  /// No description provided for @discoveryServiceNone.
  ///
  /// In en, this message translates to:
  /// **'Service — nothing auto-detected'**
  String get discoveryServiceNone;

  /// No description provided for @discoverySystemdUnitName.
  ///
  /// In en, this message translates to:
  /// **'systemd unit name'**
  String get discoverySystemdUnitName;

  /// No description provided for @discoveryWorldsPath.
  ///
  /// In en, this message translates to:
  /// **'Worlds path'**
  String get discoveryWorldsPath;

  /// No description provided for @discoveryWorldsPathSeveral.
  ///
  /// In en, this message translates to:
  /// **'Worlds path — several found, pick one'**
  String get discoveryWorldsPathSeveral;

  /// No description provided for @discoveryWorldsPathNone.
  ///
  /// In en, this message translates to:
  /// **'Worlds path — none found'**
  String get discoveryWorldsPathNone;

  /// No description provided for @discoveryWorldsPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path to the worlds directory'**
  String get discoveryWorldsPathLabel;

  /// No description provided for @discoveryPickService.
  ///
  /// In en, this message translates to:
  /// **'Pick or enter a service first.'**
  String get discoveryPickService;

  /// No description provided for @discoveryPickWorldsPath.
  ///
  /// In en, this message translates to:
  /// **'Pick or enter a worlds path first.'**
  String get discoveryPickWorldsPath;

  /// No description provided for @discoverySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get discoverySaving;

  /// No description provided for @discoveryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get discoveryConfirm;

  /// Shown in place of the service state when the server reported nothing at all.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get statsUnknown;

  /// No description provided for @statsSince.
  ///
  /// In en, this message translates to:
  /// **'since {time}'**
  String statsSince(String time);

  /// No description provided for @statsUptime.
  ///
  /// In en, this message translates to:
  /// **'uptime {duration}'**
  String statsUptime(String duration);

  /// No description provided for @statsServerClock.
  ///
  /// In en, this message translates to:
  /// **'server clock {time}'**
  String statsServerClock(String time);

  /// Single-letter abbreviation for days, appended straight to the number: 4d.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get statsUnitDays;

  /// Single-letter abbreviation for hours: 3h.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get statsUnitHours;

  /// Single-letter abbreviation for minutes: 12m.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get statsUnitMinutes;

  /// No description provided for @statsCurrentWorld.
  ///
  /// In en, this message translates to:
  /// **'Current world'**
  String get statsCurrentWorld;

  /// The game id is Core Keeper's own identifier for a world; the app reads it out of the server log.
  ///
  /// In en, this message translates to:
  /// **'no game id in the recent log'**
  String get statsNoGameId;

  /// No description provided for @statsCopyGameId.
  ///
  /// In en, this message translates to:
  /// **'Copy game id'**
  String get statsCopyGameId;

  /// No description provided for @statsGameIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Game id copied.'**
  String get statsGameIdCopied;

  /// No description provided for @statsMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get statsMemory;

  /// No description provided for @statsDiskWorlds.
  ///
  /// In en, this message translates to:
  /// **'Disk (worlds)'**
  String get statsDiskWorlds;

  /// No description provided for @statsUdpListening.
  ///
  /// In en, this message translates to:
  /// **'listening'**
  String get statsUdpListening;

  /// No description provided for @statsUdpNotDetected.
  ///
  /// In en, this message translates to:
  /// **'not detected'**
  String get statsUdpNotDetected;

  /// No description provided for @statsUdpListeners.
  ///
  /// In en, this message translates to:
  /// **'UDP listeners'**
  String get statsUdpListeners;

  /// No description provided for @statsRecentLog.
  ///
  /// In en, this message translates to:
  /// **'Recent log'**
  String get statsRecentLog;

  /// No description provided for @statsLiveLog.
  ///
  /// In en, this message translates to:
  /// **'Live log'**
  String get statsLiveLog;

  /// Says out loud that this is a poll, not a real `journalctl -f` stream.
  ///
  /// In en, this message translates to:
  /// **'polling every {seconds}s'**
  String statsPollingEvery(int seconds);

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get commonUnknown;

  /// The operation, named inside a sentence: 'A push is in progress'. Lower case.
  ///
  /// In en, this message translates to:
  /// **'push'**
  String get opPush;

  /// No description provided for @opPull.
  ///
  /// In en, this message translates to:
  /// **'pull'**
  String get opPull;

  /// No description provided for @opRestore.
  ///
  /// In en, this message translates to:
  /// **'restore'**
  String get opRestore;

  /// Push, pull and restore share one server and can never overlap.
  ///
  /// In en, this message translates to:
  /// **'A {operation} is in progress — it stops and restarts the same server, so wait for it to finish.'**
  String opOtherInProgress(String operation);

  /// Mobile only. Backgrounding suspends the isolate and kills the socket, which can strand the server mid-swap.
  ///
  /// In en, this message translates to:
  /// **'Keep the app open. Switching away can interrupt the transfer and leave the server stopped.'**
  String get opKeepAppOpen;

  /// No description provided for @stepUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get stepUpload;

  /// Pipeline step: confirm the service is in the state the operation expects. One or two words — these sit under 26px circles in a row.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get stepCheck;

  /// No description provided for @stepStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stepStop;

  /// No description provided for @stepBackUp.
  ///
  /// In en, this message translates to:
  /// **'Back up'**
  String get stepBackUp;

  /// No description provided for @stepCopyIn.
  ///
  /// In en, this message translates to:
  /// **'Copy in'**
  String get stepCopyIn;

  /// Pipeline step: restore file ownership and permissions after copying. Abbreviated 'permissions'.
  ///
  /// In en, this message translates to:
  /// **'Perms'**
  String get stepPerms;

  /// No description provided for @stepStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get stepStart;

  /// No description provided for @stepGameId.
  ///
  /// In en, this message translates to:
  /// **'Game id'**
  String get stepGameId;

  /// No description provided for @stepVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get stepVerify;

  /// No description provided for @stepDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get stepDownload;

  /// No description provided for @stepRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get stepRestart;

  /// Screen-reader label for a step marker, which is otherwise only a coloured circle.
  ///
  /// In en, this message translates to:
  /// **'Step done'**
  String get stepStatusDone;

  /// No description provided for @stepStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Step running'**
  String get stepStatusActive;

  /// No description provided for @stepStatusError.
  ///
  /// In en, this message translates to:
  /// **'Step failed'**
  String get stepStatusError;

  /// No description provided for @stepStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Step not started'**
  String get stepStatusPending;

  /// One row in a list of world slots.
  ///
  /// In en, this message translates to:
  /// **'slot {slot} — {size}, {modified}'**
  String slotOption(int slot, String size, String modified);

  /// A string rather than an int because an unparseable backup name shows '?' here.
  ///
  /// In en, this message translates to:
  /// **'slot {slot}'**
  String slotNumber(String slot);

  /// No description provided for @resultGameId.
  ///
  /// In en, this message translates to:
  /// **'game id {id}'**
  String resultGameId(String id);

  /// No description provided for @worldsNoneOnServer.
  ///
  /// In en, this message translates to:
  /// **'No worlds found on the server.'**
  String get worldsNoneOnServer;

  /// No description provided for @worldsNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No worlds found.'**
  String get worldsNoneFound;

  /// No description provided for @pushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push a world'**
  String get pushTitle;

  /// No description provided for @pushSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stops the server, backs up what is live, swaps yours in, restarts and verifies. Keep your own backups — this is a homelab tool, not a certified backup product.'**
  String get pushSubtitle;

  /// No description provided for @pushChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file (.zip or .world.gzip)'**
  String get pushChooseFile;

  /// No description provided for @pushChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get pushChooseFolder;

  /// No description provided for @pushButton.
  ///
  /// In en, this message translates to:
  /// **'Push this world'**
  String get pushButton;

  /// No description provided for @pushButtonIntoSlot.
  ///
  /// In en, this message translates to:
  /// **'Push into slot {slot}'**
  String pushButtonIntoSlot(int slot);

  /// No description provided for @pushUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get pushUploading;

  /// No description provided for @pushSlot.
  ///
  /// In en, this message translates to:
  /// **'Slot'**
  String get pushSlot;

  /// No description provided for @pushUnassignedSlot.
  ///
  /// In en, this message translates to:
  /// **'This file\'s name doesn\'t say which slot it belongs to. Name it N.world.gzip to have that detected automatically, or pick a slot below — which is also how you seed a brand-new slot.'**
  String get pushUnassignedSlot;

  /// No description provided for @pushFoundWorlds.
  ///
  /// In en, this message translates to:
  /// **'Found {count} worlds — pick one:'**
  String pushFoundWorlds(int count);

  /// No description provided for @pushPugbackupNote.
  ///
  /// In en, this message translates to:
  /// **'↳ Core Keeper\'s own rolling backup was found alongside — both travel together.'**
  String get pushPugbackupNote;

  /// No description provided for @pushConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap in world {slot}?'**
  String pushConfirmTitle(int slot);

  /// No description provided for @pushConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This stops the live Core Keeper server, backs up the current world (dated and restorable), copies yours in, restarts, and verifies. If anything fails it restores the backup and restarts automatically.'**
  String get pushConfirmBody;

  /// No description provided for @pushConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Stop server & push'**
  String get pushConfirmButton;

  /// No description provided for @pushDoneToast.
  ///
  /// In en, this message translates to:
  /// **'World {slot} swapped in.'**
  String pushDoneToast(int slot);

  /// No description provided for @pushFailedBanner.
  ///
  /// In en, this message translates to:
  /// **'Rolled back — the server was restarted automatically'**
  String get pushFailedBanner;

  /// No description provided for @pushResultLive.
  ///
  /// In en, this message translates to:
  /// **'World {slot} is live'**
  String pushResultLive(int slot);

  /// No description provided for @pushResultUploaded.
  ///
  /// In en, this message translates to:
  /// **'{size} uploaded'**
  String pushResultUploaded(String size);

  /// No description provided for @pushResultBackedUpTo.
  ///
  /// In en, this message translates to:
  /// **'previous world backed up to {path}'**
  String pushResultBackedUpTo(String path);

  /// No description provided for @pullTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull a world'**
  String get pullTitle;

  /// No description provided for @pullSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stops the server just long enough to copy a consistent world, restarts immediately, then lets you save it.'**
  String get pullSubtitle;

  /// No description provided for @pullButton.
  ///
  /// In en, this message translates to:
  /// **'Pull world'**
  String get pullButton;

  /// No description provided for @pullButtonSlot.
  ///
  /// In en, this message translates to:
  /// **'Pull world {slot}'**
  String pullButtonSlot(int slot);

  /// No description provided for @pullDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get pullDownloading;

  /// No description provided for @pullConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull world {slot}?'**
  String pullConfirmTitle(int slot);

  /// No description provided for @pullConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Briefly stops the server so the world can be copied while nothing is writing to it, then restarts it immediately. Nothing on the server is modified.'**
  String get pullConfirmBody;

  /// No description provided for @pullConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Stop server & pull'**
  String get pullConfirmButton;

  /// No description provided for @pullFailedBanner.
  ///
  /// In en, this message translates to:
  /// **'Failed — a restart was attempted regardless'**
  String get pullFailedBanner;

  /// No description provided for @pullSavePrompt.
  ///
  /// In en, this message translates to:
  /// **'{size} downloaded — the server is already running again. Save world {slot} as:'**
  String pullSavePrompt(String size, int slot);

  /// No description provided for @pullSaveAsFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder…'**
  String get pullSaveAsFolder;

  /// No description provided for @pullSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String pullSavedTo(String path);

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'World library'**
  String get libraryTitle;

  /// No description provided for @librarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What is live on the server, and every dated backup that can be restored.'**
  String get librarySubtitle;

  /// No description provided for @libraryLiveOnServer.
  ///
  /// In en, this message translates to:
  /// **'Live on server'**
  String get libraryLiveOnServer;

  /// No description provided for @libraryBackups.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get libraryBackups;

  /// No description provided for @libraryBackupsCount.
  ///
  /// In en, this message translates to:
  /// **'Backups ({count})'**
  String libraryBackupsCount(int count);

  /// No description provided for @libraryNoBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'None yet — your first push or restore creates one.'**
  String get libraryNoBackupsYet;

  /// No description provided for @libraryRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get libraryRestore;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore world {slot} from this backup?'**
  String restoreConfirmTitle(int slot);

  /// No description provided for @restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Stops the server, backs up whatever is live right now (so this restore is itself undoable), copies the backup into place, restarts and verifies.'**
  String get restoreConfirmBody;

  /// No description provided for @restoreConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Stop server & restore'**
  String get restoreConfirmButton;

  /// No description provided for @restoreDoneToast.
  ///
  /// In en, this message translates to:
  /// **'World {slot} restored.'**
  String restoreDoneToast(int slot);

  /// No description provided for @restoreFailedBanner.
  ///
  /// In en, this message translates to:
  /// **'Rolled back — the safety backup was restored and the server restarted'**
  String get restoreFailedBanner;

  /// No description provided for @restoreResult.
  ///
  /// In en, this message translates to:
  /// **'Restored world {slot}'**
  String restoreResult(int slot);

  /// No description provided for @restoreSafetyBackup.
  ///
  /// In en, this message translates to:
  /// **'safety backup: {path}'**
  String restoreSafetyBackup(String path);

  /// Title bar of the OS file dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose a world file or .zip'**
  String get pickerChooseFile;

  /// No description provided for @pickerChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder containing worlds'**
  String get pickerChooseFolder;

  /// No description provided for @pickerSaveInto.
  ///
  /// In en, this message translates to:
  /// **'Save the world into…'**
  String get pickerSaveInto;

  /// No description provided for @pickerSaveZip.
  ///
  /// In en, this message translates to:
  /// **'Save world as .zip'**
  String get pickerSaveZip;

  /// No description provided for @auditTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get auditTitle;

  /// Header summary for the server on screen.
  ///
  /// In en, this message translates to:
  /// **'{sessions} sessions · {events} events · {commands} commands · {errors} errors'**
  String auditCounts(int sessions, int events, int commands, int errors);

  /// No description provided for @auditExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get auditExport;

  /// No description provided for @auditExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get auditExporting;

  /// No description provided for @auditExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export the audit log'**
  String get auditExportDialogTitle;

  /// No description provided for @auditExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String auditExportedTo(String path);

  /// No description provided for @auditClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get auditClear;

  /// No description provided for @auditLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get auditLoadMore;

  /// No description provided for @auditScopeServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get auditScopeServer;

  /// Reading one machine's log while operating on another is how you convince yourself the wrong thing happened.
  ///
  /// In en, this message translates to:
  /// **'Locked to the connected server. Disconnect to read another.'**
  String get auditScopeLocked;

  /// A profile can be deleted; its history stays, because the record of what was done to a machine is not the profile's to take with it.
  ///
  /// In en, this message translates to:
  /// **'Deleted profile'**
  String get auditDeletedProfile;

  /// No description provided for @auditNothingYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet — connect to a server and it will be.'**
  String get auditNothingYetSubtitle;

  /// No description provided for @auditNothingYetTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get auditNothingYetTitle;

  /// No description provided for @auditNothingYetBody.
  ///
  /// In en, this message translates to:
  /// **'The log is kept per server, and no server has been connected to yet. Connect one and everything this app does to it lands here — every session, command and error.\n\nOnce there is history you can read it without connecting, which is usually when you want it.'**
  String get auditNothingYetBody;

  /// No description provided for @auditTabEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get auditTabEvents;

  /// No description provided for @auditTabCommands.
  ///
  /// In en, this message translates to:
  /// **'SSH commands'**
  String get auditTabCommands;

  /// No description provided for @auditTabErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get auditTabErrors;

  /// Filters events by their recorded kind, e.g. push_start.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get auditFilterKind;

  /// No description provided for @auditFilterAllKinds.
  ///
  /// In en, this message translates to:
  /// **'All kinds'**
  String get auditFilterAllKinds;

  /// No description provided for @auditFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get auditFilterStatus;

  /// No description provided for @auditFilterAnyStatus.
  ///
  /// In en, this message translates to:
  /// **'Any status'**
  String get auditFilterAnyStatus;

  /// No description provided for @auditStatusOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get auditStatusOk;

  /// No description provided for @auditStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get auditStatusFailed;

  /// Filters SSH commands by exit code.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get auditFilterExit;

  /// No description provided for @auditFilterAnyExit.
  ///
  /// In en, this message translates to:
  /// **'Any exit code'**
  String get auditFilterAnyExit;

  /// No description provided for @auditExitZero.
  ///
  /// In en, this message translates to:
  /// **'Exit 0'**
  String get auditExitZero;

  /// No description provided for @auditExitNonzero.
  ///
  /// In en, this message translates to:
  /// **'Nonzero'**
  String get auditExitNonzero;

  /// Filters errors by where in the app they were raised.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get auditFilterContext;

  /// No description provided for @auditFilterAllContexts.
  ///
  /// In en, this message translates to:
  /// **'All contexts'**
  String get auditFilterAllContexts;

  /// No description provided for @auditFilterSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get auditFilterSession;

  /// No description provided for @auditFilterAllSessions.
  ///
  /// In en, this message translates to:
  /// **'All sessions'**
  String get auditFilterAllSessions;

  /// No description provided for @auditSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get auditSearch;

  /// No description provided for @auditSearchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search kind, state, detail…'**
  String get auditSearchEvents;

  /// No description provided for @auditSearchCommands.
  ///
  /// In en, this message translates to:
  /// **'Search command, stdout, stderr…'**
  String get auditSearchCommands;

  /// No description provided for @auditSearchErrors.
  ///
  /// In en, this message translates to:
  /// **'Search message, detail…'**
  String get auditSearchErrors;

  /// No description provided for @auditNoEventsMatch.
  ///
  /// In en, this message translates to:
  /// **'No events for this server match these filters.'**
  String get auditNoEventsMatch;

  /// No description provided for @auditNoCommandsMatch.
  ///
  /// In en, this message translates to:
  /// **'No commands for this server match these filters.'**
  String get auditNoCommandsMatch;

  /// No description provided for @auditNoErrorsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No errors recorded for this server. That is the good outcome.'**
  String get auditNoErrorsRecorded;

  /// Badge for a command that never returned an exit code at all — a transport failure, which counts as a failure.
  ///
  /// In en, this message translates to:
  /// **'no exit'**
  String get auditNoExitCode;

  /// Screen-reader label on the status dot. Colour alone says nothing to a screen reader, or to a red/green-deficient reader.
  ///
  /// In en, this message translates to:
  /// **'succeeded'**
  String get auditSucceeded;

  /// No description provided for @auditFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get auditFailed;

  /// No description provided for @auditClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the audit log for {name}?'**
  String auditClearTitle(String name);

  /// No description provided for @auditClearBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes every session, event, SSH command, error, file operation and backup record for {where} — all of it, not just what is filtered. Other servers are left alone. This cannot be undone.'**
  String auditClearBody(String where);

  /// No description provided for @auditClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, clear it'**
  String get auditClearConfirm;

  /// No description provided for @auditClearSecondTitle.
  ///
  /// In en, this message translates to:
  /// **'Really? This is the black box.'**
  String get auditClearSecondTitle;

  /// No description provided for @auditClearSecondBody.
  ///
  /// In en, this message translates to:
  /// **'Every \"why did the server die at 3am\" you could have answered — gone. Every rollback you were quietly glad of — no record it happened. The log does not get better with age, but it is the only thing that remembers.\n\nBackups on the server are NOT affected: the World Library reads those from the filesystem, so restoring still works either way.'**
  String get auditClearSecondBody;

  /// No description provided for @auditClearSecondConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete it'**
  String get auditClearSecondConfirm;

  /// No description provided for @auditClearedToast.
  ///
  /// In en, this message translates to:
  /// **'Cleared the audit log for {name}.'**
  String auditClearedToast(String name);

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalTitle;

  /// No description provided for @terminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A real shell over the same connection — the same trust level as ssh to this host, and not sandboxed.'**
  String get terminalSubtitle;

  /// No description provided for @terminalCloseSession.
  ///
  /// In en, this message translates to:
  /// **'Close session'**
  String get terminalCloseSession;

  /// No description provided for @terminalStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get terminalStartSession;

  /// No description provided for @terminalOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening…'**
  String get terminalOpening;

  /// No description provided for @terminalNoSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'No session'**
  String get terminalNoSessionTitle;

  /// No description provided for @terminalNoSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Start one to get a shell on this host. Nothing is opened automatically.'**
  String get terminalNoSessionBody;

  /// No description provided for @terminalOperationWarning.
  ///
  /// In en, this message translates to:
  /// **'A {operation} is running. Commands typed here can race its own stop/start sequence — best to wait it out.'**
  String terminalOperationWarning(String operation);

  /// Tooltip on the ^C key of the mobile accessory bar. The key legends themselves (Ctrl, Esc, ^C) are not translated — they are what is printed on a keyboard.
  ///
  /// In en, this message translates to:
  /// **'Interrupt'**
  String get terminalKeyInterrupt;

  /// No description provided for @terminalKeyEndOfInput.
  ///
  /// In en, this message translates to:
  /// **'End of input'**
  String get terminalKeyEndOfInput;

  /// No description provided for @terminalKeySuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get terminalKeySuspend;

  /// No description provided for @terminalKeyLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get terminalKeyLeft;

  /// No description provided for @terminalKeyDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get terminalKeyDown;

  /// No description provided for @terminalKeyUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get terminalKeyUp;

  /// No description provided for @terminalKeyRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get terminalKeyRight;

  /// Screen-reader label for a sticky modifier key, which reports its armed state separately.
  ///
  /// In en, this message translates to:
  /// **'{key} modifier'**
  String terminalModifier(String key);

  /// No description provided for @disclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerBody1.
  ///
  /// In en, this message translates to:
  /// **'This tool stops your Core Keeper server and overwrites world files on a remote host you control. It takes a backup before every destructive step and rolls back on failure.'**
  String get disclaimerBody1;

  /// No description provided for @disclaimerBody2.
  ///
  /// In en, this message translates to:
  /// **'It is a homelab tool, not a certified backup product. It comes with no guarantee against data loss or corruption.'**
  String get disclaimerBody2;

  /// No description provided for @disclaimerBody3.
  ///
  /// In en, this message translates to:
  /// **'Keep your own independent backups of anything you cannot afford to lose.'**
  String get disclaimerBody3;

  /// No description provided for @disclaimerBody4.
  ///
  /// In en, this message translates to:
  /// **'Every command it runs on your server is listed under About, and every one it has run is in the audit log.'**
  String get disclaimerBody4;

  /// No description provided for @disclaimerAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get disclaimerAcknowledge;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About {app}'**
  String aboutTitle(String app);

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Manages a Core Keeper dedicated server’s worlds over SSH.'**
  String get aboutTagline;

  /// No description provided for @aboutDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Where your data lives'**
  String get aboutDataTitle;

  /// No description provided for @aboutDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The same locations the original desktop app uses, so both can read them.'**
  String get aboutDataSubtitle;

  /// No description provided for @aboutPathConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get aboutPathConfiguration;

  /// No description provided for @aboutPathAuditDatabase.
  ///
  /// In en, this message translates to:
  /// **'Audit database'**
  String get aboutPathAuditDatabase;

  /// No description provided for @aboutPathImportedFrom.
  ///
  /// In en, this message translates to:
  /// **'Imported from'**
  String get aboutPathImportedFrom;

  /// No description provided for @aboutPathImportedNote.
  ///
  /// In en, this message translates to:
  /// **'read-only — the original app keeps writing here'**
  String get aboutPathImportedNote;

  /// No description provided for @aboutPathKeys.
  ///
  /// In en, this message translates to:
  /// **'Generated SSH keys'**
  String get aboutPathKeys;

  /// No description provided for @aboutShowInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get aboutShowInFolder;

  /// No description provided for @aboutFolderOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the folder — path copied instead.'**
  String get aboutFolderOpenFailed;

  /// No description provided for @aboutCommandsTitle.
  ///
  /// In en, this message translates to:
  /// **'What it runs on your server'**
  String get aboutCommandsTitle;

  /// No description provided for @aboutCommandsSubtitleDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected, so values it has not discovered yet show as <placeholders> and all three service kinds are listed.'**
  String get aboutCommandsSubtitleDisconnected;

  /// No description provided for @aboutCommandsSubtitleConnected.
  ///
  /// In en, this message translates to:
  /// **'Filtered to the {kind} target it found, with the discovered values filled in and quoted exactly as they are sent.'**
  String aboutCommandsSubtitleConnected(String kind);

  /// No description provided for @aboutCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get aboutCopyAll;

  /// No description provided for @aboutCopied.
  ///
  /// In en, this message translates to:
  /// **'{what} — copied.'**
  String aboutCopied(String what);

  /// How many commands a group holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step} other{{count} steps}}'**
  String aboutStepCount(int count);

  /// A proper noun — the Linux service manager. Not translated.
  ///
  /// In en, this message translates to:
  /// **'systemd'**
  String get targetKindSystemd;

  /// No description provided for @targetKindDocker.
  ///
  /// In en, this message translates to:
  /// **'Docker'**
  String get targetKindDocker;

  /// The server run directly from a script, with no service manager supervising it.
  ///
  /// In en, this message translates to:
  /// **'bare process'**
  String get targetKindProcess;

  /// No description provided for @cmdGroupDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get cmdGroupDiscovery;

  /// No description provided for @cmdIdentifyOs.
  ///
  /// In en, this message translates to:
  /// **'Identify the OS'**
  String get cmdIdentifyOs;

  /// No description provided for @cmdFindSystemdUnits.
  ///
  /// In en, this message translates to:
  /// **'Find Core Keeper systemd units'**
  String get cmdFindSystemdUnits;

  /// No description provided for @cmdInspectUnit.
  ///
  /// In en, this message translates to:
  /// **'Inspect a matched unit'**
  String get cmdInspectUnit;

  /// No description provided for @cmdFindDockerContainers.
  ///
  /// In en, this message translates to:
  /// **'Find Core Keeper docker containers'**
  String get cmdFindDockerContainers;

  /// No description provided for @cmdListContainerMounts.
  ///
  /// In en, this message translates to:
  /// **'List a matched container\'s mounts'**
  String get cmdListContainerMounts;

  /// No description provided for @cmdSearchMounts.
  ///
  /// In en, this message translates to:
  /// **'Search each mount for world files'**
  String get cmdSearchMounts;

  /// No description provided for @cmdFindBareProcess.
  ///
  /// In en, this message translates to:
  /// **'Find a bare Core Keeper process'**
  String get cmdFindBareProcess;

  /// No description provided for @cmdSearchHome.
  ///
  /// In en, this message translates to:
  /// **'Search /home for world files (non-Docker targets)'**
  String get cmdSearchHome;

  /// No description provided for @cmdGroupListing.
  ///
  /// In en, this message translates to:
  /// **'Listing files'**
  String get cmdGroupListing;

  /// No description provided for @cmdListPreferred.
  ///
  /// In en, this message translates to:
  /// **'Preferred — one round trip, GNU findutils only'**
  String get cmdListPreferred;

  /// No description provided for @cmdListFallback.
  ///
  /// In en, this message translates to:
  /// **'Fallback, probed once and cached — for BusyBox and BSD hosts, where -printf does not exist'**
  String get cmdListFallback;

  /// No description provided for @cmdGroupStats.
  ///
  /// In en, this message translates to:
  /// **'Server stats'**
  String get cmdGroupStats;

  /// No description provided for @cmdCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get cmdCheckStatus;

  /// No description provided for @cmdRunningSince.
  ///
  /// In en, this message translates to:
  /// **'Since when it has been running'**
  String get cmdRunningSince;

  /// No description provided for @cmdServerClock.
  ///
  /// In en, this message translates to:
  /// **'Server wall-clock time'**
  String get cmdServerClock;

  /// No description provided for @cmdUdpListening.
  ///
  /// In en, this message translates to:
  /// **'UDP port listening?'**
  String get cmdUdpListening;

  /// No description provided for @cmdUdpHostNetwork.
  ///
  /// In en, this message translates to:
  /// **'UDP port listening? — 1. host network mode'**
  String get cmdUdpHostNetwork;

  /// No description provided for @cmdUdpPublishedPorts.
  ///
  /// In en, this message translates to:
  /// **'UDP port listening? — 2. published ports'**
  String get cmdUdpPublishedPorts;

  /// No description provided for @cmdUdpThoseHostPorts.
  ///
  /// In en, this message translates to:
  /// **'UDP port listening? — 2b. then look for those host ports'**
  String get cmdUdpThoseHostPorts;

  /// No description provided for @cmdUdpInsideContainer.
  ///
  /// In en, this message translates to:
  /// **'UDP port listening? — 3. inside the container'**
  String get cmdUdpInsideContainer;

  /// No description provided for @cmdUdpProcFallback.
  ///
  /// In en, this message translates to:
  /// **'UDP port listening? — 4. last resort, /proc (ss is absent from most minimal images)'**
  String get cmdUdpProcFallback;

  /// No description provided for @cmdMemoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Memory usage'**
  String get cmdMemoryUsage;

  /// No description provided for @cmdDiskUsage.
  ///
  /// In en, this message translates to:
  /// **'Disk usage of the worlds path'**
  String get cmdDiskUsage;

  /// No description provided for @cmdHostUptime.
  ///
  /// In en, this message translates to:
  /// **'Host uptime'**
  String get cmdHostUptime;

  /// No description provided for @cmdLogTail.
  ///
  /// In en, this message translates to:
  /// **'Recent log tail (game id + live log drawer)'**
  String get cmdLogTail;

  /// No description provided for @cmdGroupPush.
  ///
  /// In en, this message translates to:
  /// **'Push a world'**
  String get cmdGroupPush;

  /// No description provided for @cmdCreateStaging.
  ///
  /// In en, this message translates to:
  /// **'Create a staging directory'**
  String get cmdCreateStaging;

  /// No description provided for @cmdUploadToStaging.
  ///
  /// In en, this message translates to:
  /// **'Upload the world file(s) to staging'**
  String get cmdUploadToStaging;

  /// No description provided for @cmdVerifyChecksum.
  ///
  /// In en, this message translates to:
  /// **'Verify the upload\'s checksum'**
  String get cmdVerifyChecksum;

  /// No description provided for @cmdStopService.
  ///
  /// In en, this message translates to:
  /// **'Stop the service'**
  String get cmdStopService;

  /// No description provided for @cmdListExistingWorld.
  ///
  /// In en, this message translates to:
  /// **'List the slot\'s existing world file, if any'**
  String get cmdListExistingWorld;

  /// No description provided for @cmdCreateBackupDir.
  ///
  /// In en, this message translates to:
  /// **'Create a dated backup directory'**
  String get cmdCreateBackupDir;

  /// No description provided for @cmdCopyIntoBackup.
  ///
  /// In en, this message translates to:
  /// **'Copy the existing world file(s) into the backup'**
  String get cmdCopyIntoBackup;

  /// No description provided for @cmdMoveIntoPlace.
  ///
  /// In en, this message translates to:
  /// **'Move the staged upload into place'**
  String get cmdMoveIntoPlace;

  /// No description provided for @cmdFixOwnership.
  ///
  /// In en, this message translates to:
  /// **'Fix ownership (only when a Steam user is configured)'**
  String get cmdFixOwnership;

  /// No description provided for @cmdStartService.
  ///
  /// In en, this message translates to:
  /// **'Start the service'**
  String get cmdStartService;

  /// No description provided for @cmdCaptureGameId.
  ///
  /// In en, this message translates to:
  /// **'Capture the game id (polls the log tail)'**
  String get cmdCaptureGameId;

  /// No description provided for @cmdVerifyStatus.
  ///
  /// In en, this message translates to:
  /// **'Verify: re-check status and UDP listening'**
  String get cmdVerifyStatus;

  /// No description provided for @cmdRollBack.
  ///
  /// In en, this message translates to:
  /// **'On failure — roll back to the safety backup'**
  String get cmdRollBack;

  /// No description provided for @cmdGroupPull.
  ///
  /// In en, this message translates to:
  /// **'Pull a world'**
  String get cmdGroupPull;

  /// No description provided for @cmdListWorldsToPull.
  ///
  /// In en, this message translates to:
  /// **'List worlds available to pull'**
  String get cmdListWorldsToPull;

  /// No description provided for @cmdDownloadWorld.
  ///
  /// In en, this message translates to:
  /// **'Download the chosen slot\'s world file(s)'**
  String get cmdDownloadWorld;

  /// No description provided for @cmdPackageLocally.
  ///
  /// In en, this message translates to:
  /// **'Package locally as a folder or zip'**
  String get cmdPackageLocally;

  /// No description provided for @cmdGroupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup (World Library)'**
  String get cmdGroupRestore;

  /// No description provided for @cmdListBackups.
  ///
  /// In en, this message translates to:
  /// **'List backups'**
  String get cmdListBackups;

  /// No description provided for @cmdSizeBackup.
  ///
  /// In en, this message translates to:
  /// **'Size a backup\'s contents'**
  String get cmdSizeBackup;

  /// No description provided for @cmdBackUpLiveFirst.
  ///
  /// In en, this message translates to:
  /// **'Back up the currently-live world first (same step Push uses)'**
  String get cmdBackUpLiveFirst;

  /// No description provided for @cmdCopyBackupWorld.
  ///
  /// In en, this message translates to:
  /// **'Copy the chosen backup\'s world file into place'**
  String get cmdCopyBackupWorld;

  /// No description provided for @cmdCopyBackupPugbackup.
  ///
  /// In en, this message translates to:
  /// **'Copy the chosen backup\'s pugbackup into place, if present'**
  String get cmdCopyBackupPugbackup;

  /// No description provided for @cmdCaptureThenVerify.
  ///
  /// In en, this message translates to:
  /// **'Capture the game id, then verify'**
  String get cmdCaptureThenVerify;

  /// No description provided for @cmdGroupTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get cmdGroupTerminal;

  /// No description provided for @cmdOpenShell.
  ///
  /// In en, this message translates to:
  /// **'Open an interactive shell'**
  String get cmdOpenShell;

  /// No description provided for @cmdGroupSetup.
  ///
  /// In en, this message translates to:
  /// **'One-time setup'**
  String get cmdGroupSetup;

  /// No description provided for @cmdInstallPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Install this app\'s generated public key (idempotent)'**
  String get cmdInstallPublicKey;

  /// The OS user the game server process runs as; used for the chown after a world is copied in.
  ///
  /// In en, this message translates to:
  /// **'Runs as'**
  String get discoverySteamUser;

  /// No description provided for @discoveryConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmed — this server is ready'**
  String get discoveryConfirmedTitle;

  /// No description provided for @discoveryConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'Saved against this profile. Stats, Library, Push, Pull and Restore are now available.'**
  String get discoveryConfirmedBody;

  /// No description provided for @discoveryConfirmedToast.
  ///
  /// In en, this message translates to:
  /// **'Discovery confirmed.'**
  String get discoveryConfirmedToast;

  /// No description provided for @discoveryChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get discoveryChange;

  /// No description provided for @discoveryTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'What the probe did'**
  String get discoveryTranscriptTitle;

  /// No description provided for @discoveryTranscriptSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 command} other{{count} commands}}, all ran'**
  String discoveryTranscriptSummary(int count);

  /// A command that fails is a broken probe; one that runs and finds nothing is a correct answer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 command} other{{count} commands}}, {failures} could not run'**
  String discoveryTranscriptSummaryFailures(int count, int failures);

  /// No description provided for @discoveryTranscriptExit.
  ///
  /// In en, this message translates to:
  /// **'exit {code}'**
  String discoveryTranscriptExit(int code);

  /// No description provided for @discoveryTranscriptNoOutput.
  ///
  /// In en, this message translates to:
  /// **'no output'**
  String get discoveryTranscriptNoOutput;

  /// No description provided for @discoveryTranscriptCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy the transcript'**
  String get discoveryTranscriptCopy;

  /// No description provided for @discoveryTranscriptCopied.
  ///
  /// In en, this message translates to:
  /// **'Transcript copied.'**
  String get discoveryTranscriptCopied;

  /// Shown when the game process was found but its filesystem is not reachable from the SSH session — typically SSH'd into a Proxmox host while Core Keeper runs in an unprivileged LXC.
  ///
  /// In en, this message translates to:
  /// **'The server is inside a container'**
  String get discoveryDifferentNamespaceTitle;

  /// No description provided for @discoveryDifferentNamespaceBody.
  ///
  /// In en, this message translates to:
  /// **'Its process is visible from here, but its files are not — the paths it was started with belong to the container, so nothing this session searches can find them. Connect this profile to the container itself instead, or enter the worlds path as this session sees it. The container\'s root is:'**
  String get discoveryDifferentNamespaceBody;

  /// No description provided for @discoveryWorldsPathExpected.
  ///
  /// In en, this message translates to:
  /// **'Nothing was found on disk, so this is the standard location for a Core Keeper dedicated server, worked out from the environment the process is running in. It is where the server will save — the directory appears the first time it does. Confirm it if that matches your install.'**
  String get discoveryWorldsPathExpected;

  /// Generates an SSH key, installs its public half on the server, and switches the profile to key auth so a password is never asked for again.
  ///
  /// In en, this message translates to:
  /// **'Set up key auth'**
  String get keyAuthSetUp;

  /// No description provided for @keyAuthConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up key authentication for {name}?'**
  String keyAuthConfirmTitle(String name);

  /// No description provided for @keyAuthConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Generates a new SSH key, appends its public half to this host\'s ~/.ssh/authorized_keys, and switches this profile to key auth. You will not be asked for a password again.'**
  String get keyAuthConfirmBody;

  /// No description provided for @keyAuthConfirmDetail.
  ///
  /// In en, this message translates to:
  /// **'The private key stays on this device and is never sent. Nothing on the server is removed or changed apart from that one added line — delete it there to revoke access.'**
  String get keyAuthConfirmDetail;

  /// No description provided for @keyAuthConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Generate and install'**
  String get keyAuthConfirmButton;

  /// No description provided for @keyAuthDone.
  ///
  /// In en, this message translates to:
  /// **'Key installed — this profile no longer needs a password.'**
  String get keyAuthDone;

  /// Collects a fresh reading immediately instead of waiting for the next poll. Paired with pull-to-refresh, which is the same action for touch.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get statsRefresh;

  /// The wrapper script is what to start and stop; the binary is what writes the worlds, so its environment is the one that matters.
  ///
  /// In en, this message translates to:
  /// **'Find the game binary the launcher started'**
  String get cmdFindGameBinary;

  /// No description provided for @cmdReadProcessEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Read HOME and XDG_CONFIG_HOME from the running process'**
  String get cmdReadProcessEnvironment;

  /// No description provided for @cmdReadProcessPaths.
  ///
  /// In en, this message translates to:
  /// **'Read the process\'s filesystem root and working directory'**
  String get cmdReadProcessPaths;

  /// Shown on reconnecting to a server whose last push, pull or restore never reported a result — the app may have left the game service stopped.
  ///
  /// In en, this message translates to:
  /// **'An operation was interrupted'**
  String get recoveryTitle;

  /// No description provided for @recoveryBody.
  ///
  /// In en, this message translates to:
  /// **'A {operation} on this server stopped part-way, at “{phase}”. Push, pull and restore all stop the game service and start it again, so it may still be down.'**
  String recoveryBody(String operation, String phase);

  /// No description provided for @recoveryChecking.
  ///
  /// In en, this message translates to:
  /// **'Asking the server…'**
  String get recoveryChecking;

  /// No description provided for @recoveryStopped.
  ///
  /// In en, this message translates to:
  /// **'The service is stopped.'**
  String get recoveryStopped;

  /// No description provided for @recoveryRunning.
  ///
  /// In en, this message translates to:
  /// **'The service is running — nothing to do.'**
  String get recoveryRunning;

  /// No description provided for @recoveryRestoreHint.
  ///
  /// In en, this message translates to:
  /// **'Starting it brings the server back with whatever world files are in place. If the swap was cut off half-way, restore the most recent backup from the World Library instead.'**
  String get recoveryRestoreHint;

  /// No description provided for @recoveryStartServer.
  ///
  /// In en, this message translates to:
  /// **'Start the server'**
  String get recoveryStartServer;

  /// No description provided for @recoveryDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get recoveryDismiss;

  /// Only shown for a bare-process target. systemd and Docker each have a log by construction; a launch script redirecting to a file does not.
  ///
  /// In en, this message translates to:
  /// **'Log file'**
  String get discoveryLogPath;

  /// No description provided for @discoveryLogPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path to the server\'s log file'**
  String get discoveryLogPathLabel;

  /// No description provided for @discoveryLogPathHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, but without it there is no live log and no game id — the id is read out of the log. Usually wherever the launch script redirects its output.'**
  String get discoveryLogPathHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
