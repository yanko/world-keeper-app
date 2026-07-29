import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:world_keeper/core/errors/exceptions.dart';

/// Resolves the app's on-disk locations.
///
/// On desktop these deliberately reproduce **Tauri's** path resolution rather than
/// `path_provider`'s, so this app lands on the exact same directory the Rust app already
/// uses. That is what lets the two share `config.json` and the generated SSH keys, and
/// what makes an existing install's audit history importable without asking the user
/// where anything is.
///
/// Tauri v2 resolves `app_config_dir()` as `dirs::config_dir()/{identifier}` and
/// `app_data_dir()` as `dirs::data_dir()/{identifier}`:
///
/// | Platform | config_dir                        | data_dir                     |
/// |----------|-----------------------------------|------------------------------|
/// | Windows  | `%APPDATA%` (Roaming)             | `%APPDATA%` (Roaming) — same |
/// | macOS    | `~/Library/Application Support`   | same                         |
/// | Linux    | `$XDG_CONFIG_HOME` ?? `~/.config` | `$XDG_DATA_HOME` ?? `~/.local/share` |
///
/// Note that on Windows and macOS config and data are the *same* directory, which is
/// why `config.json` and `ckmanager.db` sit side by side there.
///
/// `path_provider` cannot be used for this: its Windows implementation returns
/// `%APPDATA%/<company>/<product>` derived from the executable's version resource,
/// which would never match Tauri's `%APPDATA%/com.civortech.worldkeeper`.
///
/// On mobile there is no Tauri app to be compatible with, so `path_provider`'s
/// sandboxed application-support directory is used directly.
class AppPaths {
  const AppPaths._({required this.configDir, required this.dataDir});

  /// The bundle identifier from the Rust app's `tauri.conf.json`. Changing this orphans
  /// every existing install's config, so it is not a knob.
  static const String tauriIdentifier = 'com.civortech.worldkeeper';

  /// Filename the Rust app's `tauri-plugin-store` writes.
  static const String configFileName = 'config.json';

  /// The Rust app's SQLite audit database.
  static const String legacyDatabaseFileName = 'ckmanager.db';

  /// This app's own audit database. Deliberately a **different** filename: the legacy db
  /// is imported from, never written to, so a user can go back to the Rust app with its
  /// history intact.
  static const String databaseFileName = 'world_keeper.db';

  final Directory configDir;
  final Directory dataDir;

  static Future<AppPaths> resolve() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationSupportDirectory();
      return AppPaths._(configDir: dir, dataDir: dir);
    }
    return AppPaths._(
      configDir: Directory(p.join(_desktopConfigRoot(), tauriIdentifier)),
      dataDir: Directory(p.join(_desktopDataRoot(), tauriIdentifier)),
    );
  }

  /// Escape hatch for tests: point every path at a temp directory.
  static AppPaths forTesting(Directory root) =>
      AppPaths._(configDir: root, dataDir: root);

  File get configFile => File(p.join(configDir.path, configFileName));

  File get databaseFile => File(p.join(dataDir.path, databaseFileName));

  /// The Rust app's database, if this machine has one. Read-only, import source.
  File get legacyDatabaseFile =>
      File(p.join(dataDir.path, legacyDatabaseFileName));

  /// Where generated SSH keys live (`keys/<profileId>_ed25519`) — the same layout the
  /// Rust app uses, so keys it generated keep working and vice versa.
  Directory get keysDir => Directory(p.join(dataDir.path, 'keys'));

  Future<void> ensureCreated() async {
    await configDir.create(recursive: true);
    await dataDir.create(recursive: true);
  }

  static String _desktopConfigRoot() {
    if (Platform.isWindows) return _requireEnv('APPDATA');
    if (Platform.isMacOS) {
      return p.join(_requireEnv('HOME'), 'Library', 'Application Support');
    }
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) return xdg;
    return p.join(_requireEnv('HOME'), '.config');
  }

  static String _desktopDataRoot() {
    // Windows and macOS collapse config and data onto one directory, matching
    // `dirs::data_dir()`.
    if (Platform.isWindows || Platform.isMacOS) return _desktopConfigRoot();
    final xdg = Platform.environment['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) return xdg;
    return p.join(_requireEnv('HOME'), '.local', 'share');
  }

  static String _requireEnv(String name) {
    final value = Platform.environment[name];
    if (value == null || value.isEmpty) {
      throw ConfigException('environment variable $name is not set');
    }
    return value;
  }

  @override
  String toString() =>
      'AppPaths(config: ${configDir.path}, data: ${dataDir.path})';
}
