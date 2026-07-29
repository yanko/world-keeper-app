import 'dart:convert';
import 'dart:io';

import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/errors/exceptions.dart';

/// Reads and writes the shared `config.json`.
///
/// ## File format
///
/// The Rust app stores this through `tauri-plugin-store`, which serialises the store as
/// a JSON object of key → value. It puts the whole config under a single `"config"` key,
/// so the file on disk is:
///
/// ```json
/// { "config": { "profiles": [...], "worldDetection": {...}, "activeProfileId": null } }
/// ```
///
/// **not** the config object at the top level. Getting this wrapper wrong is the easiest
/// way to silently orphan an existing install, so it is asserted by the round-trip test.
///
/// ## Concurrency
///
/// Both apps may be installed at once, so writes are atomic (write to a sibling temp
/// file, then rename) — a torn write here costs the user every stored profile. Renames
/// within a directory are atomic on NTFS, APFS and ext4.
///
/// Unknown keys are preserved: if a future version of either app adds a sibling key next
/// to `"config"`, this rewrites it untouched rather than dropping it.
class ConfigRepository {
  ConfigRepository(this._paths);

  final AppPaths _paths;

  static const String _storeKey = 'config';

  /// Everything in the store file other than our own key, kept so writes don't discard
  /// state belonging to another consumer of the same file.
  Map<String, dynamic> _foreignKeys = <String, dynamic>{};

  /// Loads the config, returning defaults when the file doesn't exist yet.
  ///
  /// A missing file is a normal first run, not an error. A file that exists but cannot
  /// be parsed **is** an error: silently replacing it with defaults would destroy real
  /// profiles the moment anything wrote malformed JSON.
  Future<AppConfig> load() async {
    final file = _paths.configFile;
    // Sync existence checks throughout: `dart:io`'s async File metadata methods are
    // measurably slower than their sync counterparts (see `avoid_slow_async_io`), and
    // these are one-shot checks, not hot loops.
    if (!file.existsSync()) {
      _foreignKeys = <String, dynamic>{};
      return const AppConfig();
    }

    final String raw;
    try {
      raw = await file.readAsString();
    } on IOException catch (e) {
      throw ConfigException(
        'could not read config file',
        path: file.path,
        cause: e,
      );
    }

    if (raw.trim().isEmpty) {
      _foreignKeys = <String, dynamic>{};
      return const AppConfig();
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw ConfigException(
        'config file is not valid JSON',
        path: file.path,
        cause: e,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ConfigException(
        'config file root is ${decoded.runtimeType}, expected a JSON object',
        path: file.path,
      );
    }

    _foreignKeys = Map<String, dynamic>.from(decoded)..remove(_storeKey);

    final section = decoded[_storeKey];
    if (section == null) return const AppConfig();
    if (section is! Map<String, dynamic>) {
      throw ConfigException(
        'config."$_storeKey" is ${section.runtimeType}, expected a JSON object',
        path: file.path,
      );
    }

    try {
      return AppConfig.fromJson(section);
    } on Object catch (e) {
      throw ConfigException(
        'config file could not be parsed',
        path: file.path,
        cause: e,
      );
    }
  }

  Future<void> save(AppConfig config) async {
    await _paths.ensureCreated();
    final file = _paths.configFile;

    final payload = <String, dynamic>{
      ..._foreignKeys,
      _storeKey: config.toJson(),
    };
    // Two-space indent matches what tauri-plugin-store writes, so switching between the
    // two apps doesn't produce a spurious whole-file diff for anyone tracking it in git.
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);

    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(file.path);
    } on IOException catch (e) {
      // Best-effort cleanup; the original file is still intact either way.
      try {
        if (temp.existsSync()) temp.deleteSync();
      } on IOException {
        // Nothing useful to do — the write error below is the one that matters.
      }
      throw ConfigException(
        'could not write config file',
        path: file.path,
        cause: e,
      );
    }
  }

  /// Inserts or replaces a profile by id, preserving list order for existing entries.
  Future<AppConfig> upsertProfile(Profile profile) async {
    final config = await load();
    final profiles = [...config.profiles];
    final idx = profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      profiles[idx] = profile;
    } else {
      profiles.add(profile);
    }
    final updated = config.copyWith(profiles: profiles);
    await save(updated);
    return updated;
  }

  /// Removes a profile, clearing [AppConfig.activeProfileId] if it pointed at it.
  ///
  /// Matches the Rust behaviour of deliberately leaving any keyring entry alone — the
  /// secret outliving its profile is preferable to silently destroying a credential.
  Future<AppConfig> deleteProfile(String profileId) async {
    final config = await load();
    final updated = config.copyWith(
      profiles: config.profiles.where((p) => p.id != profileId).toList(),
      activeProfileId: config.activeProfileId == profileId
          ? null
          : config.activeProfileId,
    );
    await save(updated);
    return updated;
  }

  Future<AppConfig> setActiveProfile(String profileId) async {
    final config = await load();
    final updated = config.copyWith(activeProfileId: profileId);
    await save(updated);
    return updated;
  }

  /// Persists a confirmed discovery result onto a profile.
  Future<AppConfig> setDiscovered(
    String profileId,
    Discovered discovered,
  ) async {
    final config = await load();
    final profile = config.profileById(profileId);
    if (profile == null) {
      throw ConfigException('no such profile: $profileId');
    }
    return upsertProfile(profile.copyWith(discovered: discovered));
  }
}
