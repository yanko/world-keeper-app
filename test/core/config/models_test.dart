import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/target/service_kind.dart';

/// A `config.json` exactly as the Rust app's serde writes it, including the
/// `tauri-plugin-store` `"config"` wrapper.
///
/// The whole point of these tests is that this document survives a parse/serialise round
/// trip unchanged, because both apps read and write the same file. If this fixture ever
/// needs editing to make a test pass, that is a compatibility break, not a test problem.
const String rustConfigJson = '''
{
  "config": {
    "profiles": [
      {
        "id": "ck-lxc-1",
        "name": "Core Keeper LXC",
        "host": "10.0.0.68",
        "port": 22,
        "user": "root",
        "auth": "password",
        "savePassword": false,
        "discovered": {
          "os": "Debian GNU/Linux 12 (bookworm)",
          "serviceKind": {
            "type": "systemd",
            "unit": "corekeeper"
          },
          "worldsPath": "/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds",
          "steamUser": "steam",
          "launchScript": "/home/steam/corekeeper/_launch.sh",
          "probedAt": "2026-07-24T23:40:00+00:00"
        }
      },
      {
        "id": "unraid-docker",
        "name": "Unraid",
        "host": "10.0.0.12",
        "port": 22,
        "user": "root",
        "auth": "key",
        "keyPath": "C:\\\\Users\\\\yanko\\\\AppData\\\\Roaming\\\\com.civortech.worldkeeper\\\\keys\\\\unraid-docker_ed25519",
        "savePassword": false,
        "discovered": {
          "os": "Unraid 7.0",
          "serviceKind": {
            "type": "docker",
            "container": "core-keeper"
          },
          "worldsPath": "/mnt/user/appdata/corekeeper/Save/worlds",
          "steamUser": null,
          "launchScript": null,
          "probedAt": "2026-07-26T09:12:00+00:00"
        }
      }
    ],
    "worldDetection": {
      "patterns": [
        "*.world.gzip"
      ]
    },
    "activeProfileId": "ck-lxc-1"
  }
}
''';

void main() {
  group('ServiceKind JSON', () {
    test('systemd round-trips with a lowercase tag', () {
      const kind = SystemdService(unit: 'corekeeper');
      expect(kind.toJson(), {'type': 'systemd', 'unit': 'corekeeper'});
      expect(ServiceKind.fromJson(kind.toJson()), kind);
    });

    test('docker round-trips', () {
      const kind = DockerService(container: 'core-keeper');
      expect(kind.toJson(), {'type': 'docker', 'container': 'core-keeper'});
      expect(ServiceKind.fromJson(kind.toJson()), kind);
    });

    test('process uses camelCase fields under a lowercase tag', () {
      // The Rust enum renames variant tags to lowercase but overrides struct-variant
      // fields back to camelCase — this asymmetry is deliberate and load-bearing.
      const kind = ProcessService(
        stopCmd: "pkill -f '/home/steam/corekeeper/_launch.sh'",
        startCmd: '/home/steam/corekeeper/_launch.sh',
        logPath: null,
      );
      expect(kind.toJson(), {
        'type': 'process',
        'stopCmd': "pkill -f '/home/steam/corekeeper/_launch.sh'",
        'startCmd': '/home/steam/corekeeper/_launch.sh',
        'logPath': null,
      });
      expect(ServiceKind.fromJson(kind.toJson()), kind);
    });

    test('process keeps a non-null logPath', () {
      const kind = ProcessService(
        stopCmd: 'stop',
        startCmd: 'start',
        logPath: '/var/log/ck.log',
      );
      expect(ServiceKind.fromJson(kind.toJson()), kind);
    });

    test('rejects an unknown tag rather than guessing', () {
      expect(
        () => ServiceKind.fromJson({'type': 'kubernetes'}),
        throwsFormatException,
      );
    });

    test('exposes a human label per variant', () {
      expect(const SystemdService(unit: 'ck').label, 'systemd: ck');
      expect(const DockerService(container: 'ck').label, 'docker: ck');
      expect(
        const ProcessService(stopCmd: 's', startCmd: 'run.sh').label,
        'process: run.sh',
      );
    });

    test('equality is by value, so config comparisons work', () {
      expect(
        const SystemdService(unit: 'a'),
        equals(const SystemdService(unit: 'a')),
      );
      expect(
        const SystemdService(unit: 'a'),
        isNot(equals(const SystemdService(unit: 'b'))),
      );
      // Different variants that happen to carry the same string are not equal.
      expect(
        const SystemdService(unit: 'a'),
        isNot(equals(const DockerService(container: 'a'))),
      );
    });
  });

  group('AppConfig byte-compatibility with the Rust app', () {
    late Map<String, dynamic> originalSection;
    late AppConfig config;

    setUp(() {
      final root = jsonDecode(rustConfigJson) as Map<String, dynamic>;
      originalSection = root['config'] as Map<String, dynamic>;
      config = AppConfig.fromJson(originalSection);
    });

    test('parses a real Rust-written config', () {
      expect(config.profiles, hasLength(2));
      expect(config.activeProfileId, 'ck-lxc-1');
      expect(config.worldDetection.patterns, ['*.world.gzip']);

      final lxc = config.profiles.first;
      expect(lxc.name, 'Core Keeper LXC');
      expect(lxc.port, 22);
      expect(lxc.auth, AuthMethod.password);
      expect(lxc.keyPath, isNull);
      expect(lxc.savePassword, isFalse);
      expect(
        lxc.discovered!.serviceKind,
        const SystemdService(unit: 'corekeeper'),
      );
      expect(lxc.discovered!.steamUser, 'steam');
      expect(
        lxc.discovered!.worldsPath,
        '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds',
      );

      final unraid = config.profiles[1];
      expect(unraid.auth, AuthMethod.key);
      expect(unraid.keyPath, contains('unraid-docker_ed25519'));
      expect(
        unraid.discovered!.serviceKind,
        const DockerService(container: 'core-keeper'),
      );
      expect(unraid.discovered!.steamUser, isNull);
    });

    test('re-serialises to an identical document', () {
      // The compatibility guarantee, stated as one assertion: what we write back is
      // exactly what Rust wrote, key for key and value for value.
      expect(config.toJson(), equals(originalSection));
    });

    test('omits keyPath entirely when null, rather than writing null', () {
      // Rust: #[serde(skip_serializing_if = "Option::is_none")]. Writing an explicit
      // null here would still parse, but it changes the file the other app wrote.
      final json = config.profiles.first.toJson();
      expect(json.containsKey('keyPath'), isFalse);
      expect(json.containsKey('discovered'), isTrue);
    });

    test('omits discovered entirely when null', () {
      const fresh = Profile(
        id: 'new',
        name: 'New',
        host: 'h',
        user: 'root',
        auth: AuthMethod.password,
      );
      final json = fresh.toJson();
      expect(json.containsKey('discovered'), isFalse);
      expect(json.containsKey('keyPath'), isFalse);
      // These two have serde defaults but are always written out.
      expect(json['port'], 22);
      expect(json['savePassword'], false);
    });

    test('writes activeProfileId as an explicit null when unset', () {
      // Rust has no skip_serializing_if on this one, so null must be present.
      const empty = AppConfig();
      final json = empty.toJson();
      expect(json.containsKey('activeProfileId'), isTrue);
      expect(json['activeProfileId'], isNull);
    });

    test('writes discovered nulls explicitly', () {
      // Discovered has no skip_serializing_if on any field.
      const d = Discovered(probedAt: '2026-01-01T00:00:00+00:00');
      final json = d.toJson();
      for (final key in [
        'os',
        'serviceKind',
        'worldsPath',
        'steamUser',
        'launchScript',
      ]) {
        expect(json.containsKey(key), isTrue, reason: '$key should be present');
        expect(json[key], isNull);
      }
    });
  });

  group('AppConfig serde defaults on read', () {
    test('applies the default port when the key is missing', () {
      final p = Profile.fromJson({
        'id': 'x',
        'name': 'X',
        'host': 'h',
        'user': 'root',
        'auth': 'key',
      });
      expect(p.port, 22);
      expect(p.savePassword, isFalse);
    });

    test('tolerates a config with no profiles or worldDetection', () {
      final c = AppConfig.fromJson({});
      expect(c.profiles, isEmpty);
      expect(c.worldDetection.patterns, ['*.world.gzip']);
      expect(c.activeProfileId, isNull);
    });

    test('ignores unknown keys instead of failing', () {
      // Forward compatibility in the other direction: a newer Rust build adding a field
      // must not stop this app from loading the file.
      final c = AppConfig.fromJson({
        'profiles': <dynamic>[],
        'activeProfileId': null,
        'somethingNew': {'nested': true},
      });
      expect(c.profiles, isEmpty);
    });
  });

  group('AppConfig lookups', () {
    const a = Profile(
      id: 'a',
      name: 'A',
      host: 'h',
      user: 'root',
      auth: AuthMethod.key,
    );
    const b = Profile(
      id: 'b',
      name: 'B',
      host: 'h',
      user: 'root',
      auth: AuthMethod.key,
    );

    test('activeProfile resolves the id', () {
      const c = AppConfig(profiles: [a, b], activeProfileId: 'b');
      expect(c.activeProfile, b);
    });

    test('activeProfile is null when unset or dangling', () {
      expect(const AppConfig(profiles: [a]).activeProfile, isNull);
      expect(
        const AppConfig(profiles: [a], activeProfileId: 'gone').activeProfile,
        isNull,
      );
    });

    test('profileById finds and misses correctly', () {
      const c = AppConfig(profiles: [a, b]);
      expect(c.profileById('a'), a);
      expect(c.profileById('nope'), isNull);
    });
  });
}
