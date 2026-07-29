import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:world_keeper/core/target/service_kind.dart';

part 'models.freezed.dart';
part 'models.g.dart';

/// Connection profile config, persisted as plain JSON.
///
/// **The JSON here is byte-compatible with the Rust app's `config.json` on purpose.**
/// The two apps read and write the same file at the same path, so an existing install's
/// profiles and cached discovery carry over with no migration step and either app can
/// be run against the same setup during the transition.
///
/// That compatibility is load-bearing and easy to break, so the serde rules being
/// mirrored are spelled out per field below. The two that matter most:
///
/// * Rust's `#[serde(skip_serializing_if = "Option::is_none")]` means the key must be
///   **absent**, not `null` — mirrored with `includeIfNull: false`.
/// * Rust's `#[serde(default)]` means the field may be **missing on read** — mirrored
///   by giving the Dart parameter a default value.
///
/// Fields without either annotation are required by serde and must always be written,
/// or the Rust app will fail to parse the file.

/// How to authenticate. Serialises as `"key"` / `"password"` (Rust:
/// `#[serde(rename_all = "lowercase")]`).
@JsonEnum()
enum AuthMethod {
  @JsonValue('key')
  key,
  @JsonValue('password')
  password,
}

/// Results of the discovery probe, cached on the profile.
///
/// Written by the probe and confirmed by the user — never typed in from scratch. Unlike
/// [Profile], none of these fields are skip-if-none in Rust, so nulls **are** written
/// out, which is json_serializable's default behaviour.
@freezed
abstract class Discovered with _$Discovered {
  const factory Discovered({
    String? os,
    ServiceKind? serviceKind,
    String? worldsPath,

    /// The user the game server runs as, for `chown` on systemd targets.
    String? steamUser,
    String? launchScript,

    /// ISO-8601 / RFC-3339 UTC timestamp of the probe.
    required String probedAt,
  }) = _Discovered;

  factory Discovered.fromJson(Map<String, dynamic> json) =>
      _$DiscoveredFromJson(json);
}

@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String id,
    required String name,
    required String host,

    /// Rust: `#[serde(default = "default_port")]`.
    @Default(22) int port,
    required String user,
    required AuthMethod auth,

    /// Rust: `skip_serializing_if = "Option::is_none"` — omitted, not null.
    @JsonKey(includeIfNull: false) String? keyPath,

    /// Rust: `#[serde(default)]`.
    /// Part of the shared config file's shape, not a feature of this app.
    ///
    /// The Rust build writes this key and `config.json` is read by both, so dropping it
    /// would mean a profile that does not round-trip — which `real_install_compat_test`
    /// exists to catch. It is carried, never acted on: the answer to "stop asking me for
    /// a password" here is `Set up key auth`, which is per-host, revocable from the
    /// server side, and never puts the secret anywhere.
    @Default(false) bool savePassword,

    /// Rust: `skip_serializing_if = "Option::is_none"` — omitted, not null.
    @JsonKey(includeIfNull: false) Discovered? discovered,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

/// Glob patterns used to spot world files on the target. Configurable but effectively
/// always the default.
@freezed
abstract class WorldDetection with _$WorldDetection {
  const factory WorldDetection({
    @Default(<String>['*.world.gzip']) List<String> patterns,
  }) = _WorldDetection;

  factory WorldDetection.fromJson(Map<String, dynamic> json) =>
      _$WorldDetectionFromJson(json);
}

@freezed
abstract class AppConfig with _$AppConfig {
  const factory AppConfig({
    /// Rust: `#[serde(default)]`.
    @Default(<Profile>[]) List<Profile> profiles,

    /// Rust: `#[serde(default)]`.
    @Default(WorldDetection()) WorldDetection worldDetection,

    /// No skip-if-none in Rust, so this is written as an explicit `null`.
    String? activeProfileId,
  }) = _AppConfig;

  const AppConfig._();

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);

  Profile? get activeProfile {
    final id = activeProfileId;
    if (id == null) return null;
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Profile? profileById(String id) {
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }
}
