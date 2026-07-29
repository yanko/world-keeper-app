// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'World Keeper';

  @override
  String get navStats => 'Statistiques';

  @override
  String get navDiscovery => 'Détection';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navPush => 'Envoyer';

  @override
  String get navPull => 'Récupérer';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navAudit => 'Audit';

  @override
  String get navMore => 'Plus';

  @override
  String menuTheme(String mode) {
    return 'Thème : $mode';
  }

  @override
  String get menuThemeSystem => 'système';

  @override
  String get menuThemeLight => 'clair';

  @override
  String get menuThemeDark => 'sombre';

  @override
  String menuLanguage(String language) {
    return 'Langue : $language';
  }

  @override
  String get menuLanguageSystem => 'Système';

  @override
  String get menuShortcuts => 'Raccourcis clavier';

  @override
  String get menuShortcutsWithKey => 'Raccourcis clavier (F1)';

  @override
  String get menuSafetyNotice => 'Avertissement de sécurité';

  @override
  String get menuAbout => 'À propos';

  @override
  String get menuMore => 'Plus';

  @override
  String get shortcutsTitle => 'Raccourcis clavier';

  @override
  String get shortcutsNothingDestructive =>
      'Aucune action destructive n\'a de raccourci. Envoyer, Récupérer, Restaurer, Déconnecter et Vider passent tous par un bouton et une confirmation — une frappe qui arrête votre serveur est une frappe que vous finiriez par faire par accident.';

  @override
  String get shortcutsTerminalTakesKeys =>
      'Tant que le terminal a le focus, il reçoit les touches en premier : Ctrl+C va au processus distant, pas à cette application.';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get commonEmpty => '(vide)';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCopied => 'Copié';

  @override
  String get commonNotConnectedTitle => 'Non connecté';

  @override
  String get commonNotConnectedBody =>
      'Choisissez un profil et connectez-vous pour voir cet écran.';

  @override
  String get commonConnectingTitle => 'Connexion…';

  @override
  String get commonConnectingBody => 'Un instant.';

  @override
  String get commonDiscoveryNotConfirmedTitle => 'Détection non confirmée';

  @override
  String get commonDiscoveryNotConfirmedBody =>
      'Confirmez ce qui a été trouvé sur cet hôte avant d\'opérer dessus.';

  @override
  String get connectionTooltip => 'Connexion';

  @override
  String get connectionProfile => 'Profil';

  @override
  String get connectionNew => 'Nouveau';

  @override
  String get connectionEdit => 'Modifier';

  @override
  String get connectionDelete => 'Supprimer';

  @override
  String get connectionConnect => 'Connecter';

  @override
  String get connectionConnecting => 'Connexion…';

  @override
  String get connectionDisconnect => 'Déconnecter';

  @override
  String connectionDeleteTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get connectionDeleteBody =>
      'Supprime le profil, sa détection mise en cache et la clé SSH générée par cette application pour lui. Tout mot de passe enregistré dans le trousseau du système reste intact, de même que la ligne de la clé dans le fichier authorized_keys du serveur — supprimez-la sur le serveur pour révoquer l\'accès. Action irréversible depuis cet écran.';

  @override
  String connectionPasswordTitle(String name) {
    return 'Connexion à $name';
  }

  @override
  String connectionPasswordBody(String target) {
    return 'Mot de passe pour $target. Non enregistré.';
  }

  @override
  String get connectionPasswordLabel => 'Mot de passe';

  @override
  String get connectionStatusDisconnected => 'Déconnecté';

  @override
  String get connectionStatusConnecting => 'Connexion…';

  @override
  String get connectionStatusNeedsDiscovery => 'Détection requise';

  @override
  String get connectionStatusConnected => 'Connecté';

  @override
  String connectionStatusSemantics(String status) {
    return 'État de la connexion : $status';
  }

  @override
  String get profileNewTitle => 'Nouveau profil';

  @override
  String profileEditTitle(String name) {
    return 'Modifier $name';
  }

  @override
  String get profileName => 'Nom';

  @override
  String get profileHost => 'Hôte';

  @override
  String get profilePort => 'Port';

  @override
  String get profileUser => 'Utilisateur';

  @override
  String get profileAuthPassword => 'Mot de passe';

  @override
  String get profileAuthKey => 'Clé';

  @override
  String get profileKeyPath => 'Chemin de la clé privée';

  @override
  String get profileKeyPathRequired => 'Requis pour l\'auth. par clé';

  @override
  String get profileFieldRequired => 'Requis';

  @override
  String get profileSaveChanges => 'Enregistrer';

  @override
  String get profileAdd => 'Ajouter le profil';

  @override
  String get hostKeyNewTitle => 'Faire confiance à cet hôte ?';

  @override
  String get hostKeyChangedTitle => 'La clé de l\'hôte a CHANGÉ';

  @override
  String hostKeyNewBody(String target) {
    return 'C\'est la première connexion à $target. Vérifiez que l\'empreinte correspond à celle du serveur, puis accordez votre confiance — les connexions suivantes seront comparées à celle-ci.';
  }

  @override
  String hostKeyChangedBody(String target) {
    return 'La clé présentée par $target ne correspond pas à celle enregistrée. Soit le serveur a été réinstallé, soit quelqu\'un intercepte la connexion. Ne continuez pas sans savoir laquelle des deux.';
  }

  @override
  String get hostKeyPreviouslyPinned => 'Clé enregistrée';

  @override
  String get hostKeyPresentedNow => 'Clé présentée maintenant';

  @override
  String hostKeyFingerprintOf(String type) {
    return 'Empreinte $type';
  }

  @override
  String get hostKeyVerifyWith => 'Vérifiez sur le serveur avec :';

  @override
  String get hostKeyAcceptNew => 'Accepter la nouvelle clé';

  @override
  String get hostKeyTrustAndConnect => 'Faire confiance et connecter';

  @override
  String get hostKeyCopyFingerprint => 'Copier l\'empreinte';

  @override
  String get discoveryTitle => 'Détection';

  @override
  String get discoverySubtitle =>
      'Sonde en lecture seule. Rien n\'est enregistré tant que vous ne confirmez pas.';

  @override
  String get discoveryConnectFirst =>
      'Connectez-vous à un hôte pour lancer la détection.';

  @override
  String get discoveryRunProbe => 'Lancer la sonde';

  @override
  String get discoveryRescan => 'Redétecter';

  @override
  String get discoveryRunProbeHint =>
      'Lancez la sonde pour identifier comment ce serveur est exécuté et où se trouvent ses mondes.';

  @override
  String get discoveryOperatingSystem => 'Système d\'exploitation';

  @override
  String get discoveryUnknownOs => 'inconnu';

  @override
  String get discoveryService => 'Service';

  @override
  String get discoveryServiceSeveral =>
      'Service — plusieurs correspondances, choisissez le bon';

  @override
  String get discoveryServiceNone =>
      'Service — rien de détecté automatiquement';

  @override
  String get discoverySystemdUnitName => 'nom de l\'unité systemd';

  @override
  String get discoveryWorldsPath => 'Chemin des mondes';

  @override
  String get discoveryWorldsPathSeveral =>
      'Chemin des mondes — plusieurs trouvés, choisissez-en un';

  @override
  String get discoveryWorldsPathNone => 'Chemin des mondes — aucun trouvé';

  @override
  String get discoveryWorldsPathLabel => 'Chemin du dossier des mondes';

  @override
  String get discoveryPickService =>
      'Choisissez ou saisissez d\'abord un service.';

  @override
  String get discoveryPickWorldsPath =>
      'Choisissez ou saisissez d\'abord un chemin de mondes.';

  @override
  String get discoverySaving => 'Enregistrement…';

  @override
  String get discoveryConfirm => 'Confirmer';

  @override
  String get statsUnknown => 'inconnu';

  @override
  String statsSince(String time) {
    return 'depuis $time';
  }

  @override
  String statsUptime(String duration) {
    return 'disponibilité $duration';
  }

  @override
  String statsServerClock(String time) {
    return 'horloge serveur $time';
  }

  @override
  String get statsUnitDays => 'j';

  @override
  String get statsUnitHours => 'h';

  @override
  String get statsUnitMinutes => 'm';

  @override
  String get statsCurrentWorld => 'Monde actuel';

  @override
  String get statsNoGameId =>
      'aucun identifiant de partie dans le journal récent';

  @override
  String get statsCopyGameId => 'Copier l\'identifiant de partie';

  @override
  String get statsGameIdCopied => 'Identifiant de partie copié.';

  @override
  String get statsMemory => 'Mémoire';

  @override
  String get statsDiskWorlds => 'Disque (mondes)';

  @override
  String get statsUdpListening => 'à l\'écoute';

  @override
  String get statsUdpNotDetected => 'non détecté';

  @override
  String get statsUdpListeners => 'Ports UDP à l\'écoute';

  @override
  String get statsRecentLog => 'Journal récent';

  @override
  String get statsLiveLog => 'Journal en direct';

  @override
  String statsPollingEvery(int seconds) {
    return 'actualisation toutes les $seconds s';
  }

  @override
  String get commonUnknown => 'inconnu';

  @override
  String get opPush => 'envoi';

  @override
  String get opPull => 'récupération';

  @override
  String get opRestore => 'restauration';

  @override
  String opOtherInProgress(String operation) {
    return 'Une opération ($operation) est en cours — elle arrête et redémarre le même serveur, attendez qu\'elle se termine.';
  }

  @override
  String get opKeepAppOpen =>
      'Gardez l\'application ouverte. Passer à une autre application peut interrompre le transfert et laisser le serveur arrêté.';

  @override
  String get stepUpload => 'Envoi';

  @override
  String get stepCheck => 'Vérif.';

  @override
  String get stepStop => 'Arrêt';

  @override
  String get stepBackUp => 'Sauvegarde';

  @override
  String get stepCopyIn => 'Copie';

  @override
  String get stepPerms => 'Droits';

  @override
  String get stepStart => 'Démarrage';

  @override
  String get stepGameId => 'Ident. partie';

  @override
  String get stepVerify => 'Vérification';

  @override
  String get stepDownload => 'Téléch.';

  @override
  String get stepRestart => 'Redémarrage';

  @override
  String get stepStatusDone => 'Étape terminée';

  @override
  String get stepStatusActive => 'Étape en cours';

  @override
  String get stepStatusError => 'Étape en échec';

  @override
  String get stepStatusPending => 'Étape non commencée';

  @override
  String slotOption(int slot, String size, String modified) {
    return 'emplacement $slot — $size, $modified';
  }

  @override
  String slotNumber(String slot) {
    return 'emplacement $slot';
  }

  @override
  String resultGameId(String id) {
    return 'identifiant de partie $id';
  }

  @override
  String get worldsNoneOnServer => 'Aucun monde trouvé sur le serveur.';

  @override
  String get worldsNoneFound => 'Aucun monde trouvé.';

  @override
  String get pushTitle => 'Envoyer un monde';

  @override
  String get pushSubtitle =>
      'Arrête le serveur, sauvegarde ce qui est en ligne, installe le vôtre, redémarre et vérifie. Conservez vos propres sauvegardes — c\'est un outil de homelab, pas un produit de sauvegarde certifié.';

  @override
  String get pushChooseFile => 'Choisir un fichier (.zip ou .world.gzip)';

  @override
  String get pushChooseFolder => 'Choisir un dossier';

  @override
  String get pushButton => 'Envoyer ce monde';

  @override
  String pushButtonIntoSlot(int slot) {
    return 'Envoyer vers l\'emplacement $slot';
  }

  @override
  String get pushUploading => 'Envoi en cours';

  @override
  String get pushSlot => 'Emplacement';

  @override
  String get pushUnassignedSlot =>
      'Le nom de ce fichier n\'indique pas à quel emplacement il appartient. Nommez-le N.world.gzip pour une détection automatique, ou choisissez un emplacement ci-dessous — c\'est aussi ainsi que l\'on crée un tout nouvel emplacement.';

  @override
  String pushFoundWorlds(int count) {
    return '$count mondes trouvés — choisissez-en un :';
  }

  @override
  String get pushPugbackupNote =>
      '↳ La sauvegarde continue propre à Core Keeper a été trouvée à côté — les deux voyagent ensemble.';

  @override
  String pushConfirmTitle(int slot) {
    return 'Installer le monde $slot ?';
  }

  @override
  String get pushConfirmBody =>
      'Ceci arrête le serveur Core Keeper en direct, sauvegarde le monde actuel (daté et restaurable), installe le vôtre, redémarre et vérifie. En cas d\'échec, la sauvegarde est restaurée et le serveur redémarré automatiquement.';

  @override
  String get pushConfirmButton => 'Arrêter le serveur et envoyer';

  @override
  String pushDoneToast(int slot) {
    return 'Le monde $slot a été installé.';
  }

  @override
  String get pushFailedBanner =>
      'Annulé — le serveur a été redémarré automatiquement';

  @override
  String pushResultLive(int slot) {
    return 'Le monde $slot est en ligne';
  }

  @override
  String pushResultUploaded(String size) {
    return '$size envoyés';
  }

  @override
  String pushResultBackedUpTo(String path) {
    return 'monde précédent sauvegardé dans $path';
  }

  @override
  String get pullTitle => 'Récupérer un monde';

  @override
  String get pullSubtitle =>
      'Arrête le serveur juste le temps de copier un monde cohérent, le redémarre immédiatement, puis vous laisse l\'enregistrer.';

  @override
  String get pullButton => 'Récupérer le monde';

  @override
  String pullButtonSlot(int slot) {
    return 'Récupérer le monde $slot';
  }

  @override
  String get pullDownloading => 'Téléchargement';

  @override
  String pullConfirmTitle(int slot) {
    return 'Récupérer le monde $slot ?';
  }

  @override
  String get pullConfirmBody =>
      'Arrête brièvement le serveur pour copier le monde pendant que rien n\'y écrit, puis le redémarre immédiatement. Rien n\'est modifié sur le serveur.';

  @override
  String get pullConfirmButton => 'Arrêter le serveur et récupérer';

  @override
  String get pullFailedBanner =>
      'Échec — un redémarrage a été tenté malgré tout';

  @override
  String pullSavePrompt(String size, int slot) {
    return '$size téléchargés — le serveur fonctionne déjà de nouveau. Enregistrer le monde $slot comme :';
  }

  @override
  String get pullSaveAsFolder => 'Dossier…';

  @override
  String pullSavedTo(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get libraryTitle => 'Bibliothèque de mondes';

  @override
  String get librarySubtitle =>
      'Ce qui est en ligne sur le serveur, et chaque sauvegarde datée pouvant être restaurée.';

  @override
  String get libraryLiveOnServer => 'En ligne sur le serveur';

  @override
  String get libraryBackups => 'Sauvegardes';

  @override
  String libraryBackupsCount(int count) {
    return 'Sauvegardes ($count)';
  }

  @override
  String get libraryNoBackupsYet =>
      'Aucune pour l\'instant — votre premier envoi ou restauration en créera une.';

  @override
  String get libraryRestore => 'Restaurer';

  @override
  String restoreConfirmTitle(int slot) {
    return 'Restaurer le monde $slot à partir de cette sauvegarde ?';
  }

  @override
  String get restoreConfirmBody =>
      'Arrête le serveur, sauvegarde ce qui est en ligne à cet instant (pour que cette restauration soit elle-même annulable), met la sauvegarde en place, redémarre et vérifie.';

  @override
  String get restoreConfirmButton => 'Arrêter le serveur et restaurer';

  @override
  String restoreDoneToast(int slot) {
    return 'Monde $slot restauré.';
  }

  @override
  String get restoreFailedBanner =>
      'Annulé — la sauvegarde de sécurité a été restaurée et le serveur redémarré';

  @override
  String restoreResult(int slot) {
    return 'Monde $slot restauré';
  }

  @override
  String restoreSafetyBackup(String path) {
    return 'sauvegarde de sécurité : $path';
  }

  @override
  String get pickerChooseFile => 'Choisir un fichier de monde ou un .zip';

  @override
  String get pickerChooseFolder => 'Choisir un dossier contenant des mondes';

  @override
  String get pickerSaveInto => 'Enregistrer le monde dans…';

  @override
  String get pickerSaveZip => 'Enregistrer le monde en .zip';

  @override
  String get auditTitle => 'Journal d\'audit';

  @override
  String auditCounts(int sessions, int events, int commands, int errors) {
    return '$sessions sessions · $events événements · $commands commandes · $errors erreurs';
  }

  @override
  String get auditExport => 'Exporter';

  @override
  String get auditExporting => 'Exportation…';

  @override
  String get auditExportDialogTitle => 'Exporter le journal d\'audit';

  @override
  String auditExportedTo(String path) {
    return 'Exporté vers $path';
  }

  @override
  String get auditClear => 'Vider';

  @override
  String get auditLoadMore => 'Charger plus';

  @override
  String get auditScopeServer => 'Serveur';

  @override
  String get auditScopeLocked =>
      'Verrouillé sur le serveur connecté. Déconnectez-vous pour en consulter un autre.';

  @override
  String get auditDeletedProfile => 'Profil supprimé';

  @override
  String get auditNothingYetSubtitle =>
      'Rien d\'enregistré pour l\'instant — connectez-vous à un serveur et cela viendra.';

  @override
  String get auditNothingYetTitle => 'Rien d\'enregistré pour l\'instant';

  @override
  String get auditNothingYetBody =>
      'Le journal est tenu par serveur, et aucun serveur n\'a encore été contacté. Connectez-vous à un serveur et tout ce que cette application y fait apparaîtra ici — chaque session, chaque commande, chaque erreur.\n\nUne fois l\'historique constitué, vous pourrez le consulter sans être connecté, ce qui est justement le moment où l\'on en a besoin.';

  @override
  String get auditTabEvents => 'Événements';

  @override
  String get auditTabCommands => 'Commandes SSH';

  @override
  String get auditTabErrors => 'Erreurs';

  @override
  String get auditFilterKind => 'Type';

  @override
  String get auditFilterAllKinds => 'Tous les types';

  @override
  String get auditFilterStatus => 'Statut';

  @override
  String get auditFilterAnyStatus => 'Tout statut';

  @override
  String get auditStatusOk => 'OK';

  @override
  String get auditStatusFailed => 'Échec';

  @override
  String get auditFilterExit => 'Sortie';

  @override
  String get auditFilterAnyExit => 'Tout code de sortie';

  @override
  String get auditExitZero => 'Sortie 0';

  @override
  String get auditExitNonzero => 'Non nulle';

  @override
  String get auditFilterContext => 'Contexte';

  @override
  String get auditFilterAllContexts => 'Tous les contextes';

  @override
  String get auditFilterSession => 'Session';

  @override
  String get auditFilterAllSessions => 'Toutes les sessions';

  @override
  String get auditSearch => 'Rechercher';

  @override
  String get auditSearchEvents => 'Rechercher type, état, détail…';

  @override
  String get auditSearchCommands => 'Rechercher commande, stdout, stderr…';

  @override
  String get auditSearchErrors => 'Rechercher message, détail…';

  @override
  String get auditNoEventsMatch =>
      'Aucun événement de ce serveur ne correspond à ces filtres.';

  @override
  String get auditNoCommandsMatch =>
      'Aucune commande de ce serveur ne correspond à ces filtres.';

  @override
  String get auditNoErrorsRecorded =>
      'Aucune erreur enregistrée pour ce serveur. C\'est la bonne nouvelle.';

  @override
  String get auditNoExitCode => 'sans code';

  @override
  String get auditSucceeded => 'réussi';

  @override
  String get auditFailed => 'échoué';

  @override
  String auditClearTitle(String name) {
    return 'Vider le journal d\'audit de $name ?';
  }

  @override
  String auditClearBody(String where) {
    return 'Supprime chaque session, événement, commande SSH, erreur, opération sur fichier et enregistrement de sauvegarde pour $where — la totalité, pas seulement ce qui est filtré. Les autres serveurs ne sont pas touchés. Action irréversible.';
  }

  @override
  String get auditClearConfirm => 'Oui, tout vider';

  @override
  String get auditClearSecondTitle => 'Vraiment ? C\'est la boîte noire.';

  @override
  String get auditClearSecondBody =>
      'Chaque « pourquoi le serveur est-il tombé à 3 h du matin » que vous auriez pu élucider — disparu. Chaque annulation dont vous étiez discrètement soulagé — aucune trace. Le journal ne s\'améliore pas avec l\'âge, mais c\'est la seule chose qui se souvienne.\n\nLes sauvegardes sur le serveur ne sont PAS affectées : la bibliothèque de mondes les lit depuis le système de fichiers, la restauration fonctionne donc toujours.';

  @override
  String get auditClearSecondConfirm => 'Supprimer';

  @override
  String auditClearedToast(String name) {
    return 'Journal d\'audit de $name vidé.';
  }

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalSubtitle =>
      'Un vrai shell sur la même connexion — le même niveau de confiance qu\'un ssh vers cet hôte, et sans isolation.';

  @override
  String get terminalCloseSession => 'Fermer la session';

  @override
  String get terminalStartSession => 'Démarrer une session';

  @override
  String get terminalOpening => 'Ouverture…';

  @override
  String get terminalNoSessionTitle => 'Aucune session';

  @override
  String get terminalNoSessionBody =>
      'Démarrez-en une pour obtenir un shell sur cet hôte. Rien ne s\'ouvre automatiquement.';

  @override
  String terminalOperationWarning(String operation) {
    return 'Une opération ($operation) est en cours. Les commandes tapées ici peuvent entrer en conflit avec sa propre séquence d\'arrêt/démarrage — mieux vaut attendre.';
  }

  @override
  String get terminalKeyInterrupt => 'Interrompre';

  @override
  String get terminalKeyEndOfInput => 'Fin d\'entrée';

  @override
  String get terminalKeySuspend => 'Suspendre';

  @override
  String get terminalKeyLeft => 'Gauche';

  @override
  String get terminalKeyDown => 'Bas';

  @override
  String get terminalKeyUp => 'Haut';

  @override
  String get terminalKeyRight => 'Droite';

  @override
  String terminalModifier(String key) {
    return 'Modificateur $key';
  }

  @override
  String get disclaimerTitle => 'Avant de commencer';

  @override
  String get disclaimerBody1 =>
      'Cet outil arrête votre serveur Core Keeper et écrase des fichiers de monde sur un hôte distant que vous contrôlez. Il effectue une sauvegarde avant chaque étape destructive et annule en cas d\'échec.';

  @override
  String get disclaimerBody2 =>
      'C\'est un outil de homelab, pas un produit de sauvegarde certifié. Il est fourni sans aucune garantie contre la perte ou la corruption de données.';

  @override
  String get disclaimerBody3 =>
      'Conservez vos propres sauvegardes indépendantes de tout ce que vous ne pouvez pas vous permettre de perdre.';

  @override
  String get disclaimerBody4 =>
      'Chaque commande qu\'il exécute sur votre serveur est listée dans « À propos », et chaque commande qu\'il a exécutée figure dans le journal d\'audit.';

  @override
  String get disclaimerAcknowledge => 'J\'ai compris';

  @override
  String aboutTitle(String app) {
    return 'À propos de $app';
  }

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutTagline =>
      'Gère les mondes d\'un serveur dédié Core Keeper via SSH.';

  @override
  String get aboutDataTitle => 'Où vos données sont stockées';

  @override
  String get aboutDataSubtitle =>
      'Les mêmes emplacements que l\'application de bureau d\'origine, pour que les deux puissent les lire.';

  @override
  String get aboutPathConfiguration => 'Configuration';

  @override
  String get aboutPathAuditDatabase => 'Base de données d\'audit';

  @override
  String get aboutPathImportedFrom => 'Importé depuis';

  @override
  String get aboutPathImportedNote =>
      'lecture seule — l\'application d\'origine continue d\'y écrire';

  @override
  String get aboutPathKeys => 'Clés SSH générées';

  @override
  String get aboutShowInFolder => 'Afficher dans le dossier';

  @override
  String get aboutFolderOpenFailed =>
      'Impossible d\'ouvrir le dossier — chemin copié à la place.';

  @override
  String get aboutCommandsTitle => 'Ce qu\'il exécute sur votre serveur';

  @override
  String get aboutCommandsSubtitleDisconnected =>
      'Non connecté : les valeurs non encore détectées apparaissent comme des <espaces réservés> et les trois types de service sont listés.';

  @override
  String aboutCommandsSubtitleConnected(String kind) {
    return 'Filtré sur la cible $kind détectée, avec les valeurs découvertes insérées et échappées exactement comme elles sont envoyées.';
  }

  @override
  String get aboutCopyAll => 'Tout copier';

  @override
  String aboutCopied(String what) {
    return '$what — copié.';
  }

  @override
  String aboutStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '1 étape',
    );
    return '$_temp0';
  }

  @override
  String get targetKindSystemd => 'systemd';

  @override
  String get targetKindDocker => 'Docker';

  @override
  String get targetKindProcess => 'processus simple';

  @override
  String get cmdGroupDiscovery => 'Détection';

  @override
  String get cmdIdentifyOs => 'Identifier le système d\'exploitation';

  @override
  String get cmdFindSystemdUnits => 'Trouver les unités systemd de Core Keeper';

  @override
  String get cmdInspectUnit => 'Inspecter une unité trouvée';

  @override
  String get cmdFindDockerContainers =>
      'Trouver les conteneurs Docker de Core Keeper';

  @override
  String get cmdListContainerMounts =>
      'Lister les montages d\'un conteneur trouvé';

  @override
  String get cmdSearchMounts =>
      'Chercher des fichiers de monde dans chaque montage';

  @override
  String get cmdFindBareProcess =>
      'Trouver un processus Core Keeper lancé directement';

  @override
  String get cmdSearchHome =>
      'Chercher des fichiers de monde dans /home (cibles non-Docker)';

  @override
  String get cmdGroupListing => 'Lister les fichiers';

  @override
  String get cmdListPreferred =>
      'Préféré — un seul aller-retour, GNU findutils uniquement';

  @override
  String get cmdListFallback =>
      'Repli, sondé une fois puis mis en cache — pour les hôtes BusyBox et BSD, où -printf n\'existe pas';

  @override
  String get cmdGroupStats => 'Statistiques du serveur';

  @override
  String get cmdCheckStatus => 'Vérifier l\'état';

  @override
  String get cmdRunningSince => 'Depuis quand il fonctionne';

  @override
  String get cmdServerClock => 'Heure du serveur';

  @override
  String get cmdUdpListening => 'Port UDP à l\'écoute ?';

  @override
  String get cmdUdpHostNetwork =>
      'Port UDP à l\'écoute ? — 1. mode réseau hôte';

  @override
  String get cmdUdpPublishedPorts =>
      'Port UDP à l\'écoute ? — 2. ports publiés';

  @override
  String get cmdUdpThoseHostPorts =>
      'Port UDP à l\'écoute ? — 2b. puis chercher ces ports côté hôte';

  @override
  String get cmdUdpInsideContainer =>
      'Port UDP à l\'écoute ? — 3. à l\'intérieur du conteneur';

  @override
  String get cmdUdpProcFallback =>
      'Port UDP à l\'écoute ? — 4. en dernier recours, /proc (ss est absent de la plupart des images minimales)';

  @override
  String get cmdMemoryUsage => 'Utilisation de la mémoire';

  @override
  String get cmdDiskUsage => 'Utilisation du disque pour le chemin des mondes';

  @override
  String get cmdHostUptime => 'Disponibilité de l\'hôte';

  @override
  String get cmdLogTail =>
      'Fin du journal récent (identifiant de partie + journal en direct)';

  @override
  String get cmdGroupPush => 'Envoyer un monde';

  @override
  String get cmdCreateStaging => 'Créer un dossier de transit';

  @override
  String get cmdUploadToStaging =>
      'Envoyer le ou les fichiers de monde vers le transit';

  @override
  String get cmdVerifyChecksum => 'Vérifier la somme de contrôle de l\'envoi';

  @override
  String get cmdStopService => 'Arrêter le service';

  @override
  String get cmdListExistingWorld =>
      'Lister le fichier de monde existant de l\'emplacement, s\'il y en a un';

  @override
  String get cmdCreateBackupDir => 'Créer un dossier de sauvegarde daté';

  @override
  String get cmdCopyIntoBackup =>
      'Copier le ou les fichiers de monde existants dans la sauvegarde';

  @override
  String get cmdMoveIntoPlace =>
      'Déplacer l\'envoi en transit à sa place définitive';

  @override
  String get cmdFixOwnership =>
      'Corriger le propriétaire (uniquement si un utilisateur Steam est configuré)';

  @override
  String get cmdStartService => 'Démarrer le service';

  @override
  String get cmdCaptureGameId =>
      'Capturer l\'identifiant de partie (interroge la fin du journal)';

  @override
  String get cmdVerifyStatus =>
      'Vérifier : re-contrôler l\'état et l\'écoute UDP';

  @override
  String get cmdRollBack =>
      'En cas d\'échec — revenir à la sauvegarde de sécurité';

  @override
  String get cmdGroupPull => 'Récupérer un monde';

  @override
  String get cmdListWorldsToPull => 'Lister les mondes disponibles à récupérer';

  @override
  String get cmdDownloadWorld =>
      'Télécharger le ou les fichiers de monde de l\'emplacement choisi';

  @override
  String get cmdPackageLocally => 'Empaqueter localement en dossier ou en zip';

  @override
  String get cmdGroupRestore =>
      'Restaurer depuis une sauvegarde (bibliothèque de mondes)';

  @override
  String get cmdListBackups => 'Lister les sauvegardes';

  @override
  String get cmdSizeBackup => 'Mesurer la taille du contenu d\'une sauvegarde';

  @override
  String get cmdBackUpLiveFirst =>
      'Sauvegarder d\'abord le monde actuellement en ligne (même étape que pour l\'envoi)';

  @override
  String get cmdCopyBackupWorld =>
      'Copier le fichier de monde de la sauvegarde choisie à sa place';

  @override
  String get cmdCopyBackupPugbackup =>
      'Copier le pugbackup de la sauvegarde choisie à sa place, s\'il existe';

  @override
  String get cmdCaptureThenVerify =>
      'Capturer l\'identifiant de partie, puis vérifier';

  @override
  String get cmdGroupTerminal => 'Terminal';

  @override
  String get cmdOpenShell => 'Ouvrir un shell interactif';

  @override
  String get cmdGroupSetup => 'Configuration initiale';

  @override
  String get cmdInstallPublicKey =>
      'Installer la clé publique générée par cette application (idempotent)';

  @override
  String get discoverySteamUser => 'Exécuté par';

  @override
  String get discoveryConfirmedTitle => 'Confirmé — ce serveur est prêt';

  @override
  String get discoveryConfirmedBody =>
      'Enregistré pour ce profil. Statistiques, Bibliothèque, Envoyer, Récupérer et Restaurer sont désormais disponibles.';

  @override
  String get discoveryConfirmedToast => 'Détection confirmée.';

  @override
  String get discoveryChange => 'Modifier';

  @override
  String get discoveryTranscriptTitle => 'Ce que la sonde a fait';

  @override
  String discoveryTranscriptSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes',
      one: '1 commande',
    );
    return '$_temp0, toutes exécutées';
  }

  @override
  String discoveryTranscriptSummaryFailures(int count, int failures) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes',
      one: '1 commande',
    );
    return '$_temp0, $failures n\'ont pas pu s\'exécuter';
  }

  @override
  String discoveryTranscriptExit(int code) {
    return 'sortie $code';
  }

  @override
  String get discoveryTranscriptNoOutput => 'aucune sortie';

  @override
  String get discoveryTranscriptCopy => 'Copier la transcription';

  @override
  String get discoveryTranscriptCopied => 'Transcription copiée.';

  @override
  String get discoveryDifferentNamespaceTitle =>
      'Le serveur est dans un conteneur';

  @override
  String get discoveryDifferentNamespaceBody =>
      'Son processus est visible d\'ici, mais pas ses fichiers — les chemins avec lesquels il a été lancé appartiennent au conteneur, donc rien de ce que cette session recherche ne peut les trouver. Connectez plutôt ce profil au conteneur lui-même, ou saisissez le chemin des mondes tel que cette session le voit. La racine du conteneur est :';

  @override
  String get discoveryWorldsPathExpected =>
      'Rien n\'a été trouvé sur le disque : voici donc l\'emplacement standard d\'un serveur dédié Core Keeper, déduit de l\'environnement du processus. C\'est là que le serveur enregistrera — le dossier apparaîtra à la première sauvegarde. Confirmez si cela correspond à votre installation.';

  @override
  String get keyAuthSetUp => 'Configurer l\'auth. par clé';

  @override
  String keyAuthConfirmTitle(String name) {
    return 'Configurer l\'authentification par clé pour $name ?';
  }

  @override
  String get keyAuthConfirmBody =>
      'Génère une nouvelle clé SSH, ajoute sa partie publique au fichier ~/.ssh/authorized_keys de cet hôte et bascule ce profil vers l\'auth. par clé. Le mot de passe ne vous sera plus demandé.';

  @override
  String get keyAuthConfirmDetail =>
      'La clé privée reste sur cet appareil et n\'est jamais envoyée. Rien n\'est supprimé ni modifié sur le serveur en dehors de cette seule ligne ajoutée — supprimez-la là-bas pour révoquer l\'accès.';

  @override
  String get keyAuthConfirmButton => 'Générer et installer';

  @override
  String get keyAuthDone =>
      'Clé installée — ce profil n\'a plus besoin de mot de passe.';

  @override
  String get statsRefresh => 'Actualiser maintenant';

  @override
  String get cmdFindGameBinary =>
      'Trouver le binaire du jeu lancé par le script';

  @override
  String get cmdReadProcessEnvironment =>
      'Lire HOME et XDG_CONFIG_HOME du processus en cours';

  @override
  String get cmdReadProcessPaths =>
      'Lire la racine du système de fichiers et le dossier de travail du processus';

  @override
  String get recoveryTitle => 'Une opération a été interrompue';

  @override
  String recoveryBody(String operation, String phase) {
    return 'Une opération ($operation) sur ce serveur s\'est arrêtée en cours de route, à l\'étape « $phase ». Envoyer, récupérer et restaurer arrêtent tous le service du jeu puis le redémarrent : il est donc peut-être encore hors service.';
  }

  @override
  String get recoveryChecking => 'Interrogation du serveur…';

  @override
  String get recoveryStopped => 'Le service est arrêté.';

  @override
  String get recoveryRunning => 'Le service fonctionne — rien à faire.';

  @override
  String get recoveryRestoreHint =>
      'Le démarrer relance le serveur avec les fichiers de monde en place. Si l\'installation a été coupée en plein milieu, restaurez plutôt la sauvegarde la plus récente depuis la bibliothèque de mondes.';

  @override
  String get recoveryStartServer => 'Démarrer le serveur';

  @override
  String get recoveryDismiss => 'Ignorer';

  @override
  String get discoveryLogPath => 'Fichier journal';

  @override
  String get discoveryLogPathLabel => 'Chemin du fichier journal du serveur';

  @override
  String get discoveryLogPathHint =>
      'Facultatif, mais sans lui il n\'y a ni journal en direct ni identifiant de partie — l\'identifiant est lu dans le journal. Généralement là où le script de lancement redirige sa sortie.';
}
