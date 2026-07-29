import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/config_repository.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/service_kind.dart';

import 'models_test.dart' show rustConfigJson;

void main() {
  late Directory tempDir;
  late AppPaths paths;
  late ConfigRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_config_test');
    paths = AppPaths.forTesting(tempDir);
    repo = ConfigRepository(paths);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> writeRaw(String contents) =>
      paths.configFile.writeAsString(contents);

  group('load', () {
    test('returns defaults when the file does not exist', () async {
      final config = await repo.load();
      expect(config.profiles, isEmpty);
      expect(config.activeProfileId, isNull);
    });

    test('returns defaults for an empty file', () async {
      await writeRaw('');
      expect((await repo.load()).profiles, isEmpty);
    });

    test(
      'reads a real Rust-written config through the store wrapper',
      () async {
        await writeRaw(rustConfigJson);
        final config = await repo.load();
        expect(config.profiles, hasLength(2));
        expect(config.activeProfileId, 'ck-lxc-1');
      },
    );

    test('returns defaults when the "config" key is absent', () async {
      // A store file that exists but has never had our key written to it.
      await writeRaw('{"someOtherPlugin": {}}');
      expect((await repo.load()).profiles, isEmpty);
    });

    test('throws rather than silently discarding a malformed file', () async {
      // Replacing an unparseable file with defaults would destroy every stored profile
      // the moment anything wrote bad JSON.
      await writeRaw('{not json');
      await expectLater(repo.load(), throwsA(isA<ConfigException>()));
    });

    test('throws when the root is not an object', () async {
      await writeRaw('[1, 2, 3]');
      await expectLater(repo.load(), throwsA(isA<ConfigException>()));
    });

    test('throws when the config section is not an object', () async {
      await writeRaw('{"config": "nope"}');
      await expectLater(repo.load(), throwsA(isA<ConfigException>()));
    });
  });

  group('save', () {
    test('writes the tauri-plugin-store wrapper, not a bare config', () async {
      await repo.save(const AppConfig(activeProfileId: 'x'));
      final root =
          jsonDecode(await paths.configFile.readAsString())
              as Map<String, dynamic>;
      expect(root.keys, contains('config'));
      expect((root['config']! as Map)['activeProfileId'], 'x');
    });

    test('round-trips a Rust config byte for byte', () async {
      await writeRaw(rustConfigJson);
      final loaded = await repo.load();
      await repo.save(loaded);

      final before = jsonDecode(rustConfigJson) as Map<String, dynamic>;
      final after =
          jsonDecode(await paths.configFile.readAsString())
              as Map<String, dynamic>;
      expect(after, equals(before));
    });

    test('preserves keys belonging to other consumers of the store', () async {
      await writeRaw(
        '{"config": {"profiles": []}, "otherPlugin": {"keep": 1}}',
      );
      await repo.load();
      await repo.save(const AppConfig());

      final root =
          jsonDecode(await paths.configFile.readAsString())
              as Map<String, dynamic>;
      expect(root['otherPlugin'], {'keep': 1});
    });

    test('creates the config directory if missing', () async {
      final nested = AppPaths.forTesting(
        Directory('${tempDir.path}${Platform.pathSeparator}deep'),
      );
      await ConfigRepository(nested).save(const AppConfig());
      expect(nested.configFile.existsSync(), isTrue);
    });

    test('leaves no temp file behind', () async {
      await repo.save(const AppConfig());
      final leftovers = tempDir
          .listSync()
          .where((e) => e.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });

  group('profile mutations', () {
    const profile = Profile(
      id: 'p1',
      name: 'LXC',
      host: '10.0.0.68',
      user: 'root',
      auth: AuthMethod.password,
    );

    test('upsert adds then replaces in place, preserving order', () async {
      await repo.upsertProfile(profile);
      await repo.upsertProfile(
        const Profile(
          id: 'p2',
          name: 'Second',
          host: 'h',
          user: 'root',
          auth: AuthMethod.key,
        ),
      );
      await repo.upsertProfile(profile.copyWith(name: 'Renamed'));

      final config = await repo.load();
      expect(config.profiles.map((p) => p.id), ['p1', 'p2']);
      expect(config.profiles.first.name, 'Renamed');
    });

    test('upsert preserves fields the edit form does not show', () async {
      // The Rust UI spreads the original profile so auth/keyPath/savePassword/discovered
      // survive an edit; the same must hold here.
      const withDiscovery = Profile(
        id: 'p1',
        name: 'LXC',
        host: 'h',
        user: 'root',
        auth: AuthMethod.key,
        keyPath: '/keys/id_ed25519',
        savePassword: true,
        discovered: Discovered(
          probedAt: '2026-01-01T00:00:00+00:00',
          serviceKind: SystemdService(unit: 'corekeeper'),
        ),
      );
      await repo.upsertProfile(withDiscovery);
      await repo.upsertProfile(withDiscovery.copyWith(host: '10.0.0.99'));

      final saved = (await repo.load()).profileById('p1')!;
      expect(saved.host, '10.0.0.99');
      expect(saved.keyPath, '/keys/id_ed25519');
      expect(saved.savePassword, isTrue);
      expect(
        saved.discovered!.serviceKind,
        const SystemdService(unit: 'corekeeper'),
      );
    });

    test(
      'delete removes the profile and clears a dangling active id',
      () async {
        await repo.upsertProfile(profile);
        await repo.setActiveProfile('p1');
        expect((await repo.load()).activeProfileId, 'p1');

        final after = await repo.deleteProfile('p1');
        expect(after.profiles, isEmpty);
        expect(after.activeProfileId, isNull);
      },
    );

    test('delete leaves an unrelated active id alone', () async {
      await repo.upsertProfile(profile);
      await repo.upsertProfile(
        const Profile(
          id: 'p2',
          name: 'B',
          host: 'h',
          user: 'root',
          auth: AuthMethod.key,
        ),
      );
      await repo.setActiveProfile('p2');

      final after = await repo.deleteProfile('p1');
      expect(after.activeProfileId, 'p2');
    });

    test('setDiscovered attaches a probe result', () async {
      await repo.upsertProfile(profile);
      const discovered = Discovered(
        os: 'Debian GNU/Linux 12 (bookworm)',
        serviceKind: DockerService(container: 'core-keeper'),
        worldsPath: '/mnt/user/appdata/corekeeper/Save/worlds',
        probedAt: '2026-07-26T09:12:00+00:00',
      );

      final after = await repo.setDiscovered('p1', discovered);
      expect(after.profileById('p1')!.discovered, discovered);

      // And it survives a real reload from disk.
      final reloaded = await repo.load();
      expect(
        reloaded.profileById('p1')!.discovered!.serviceKind,
        const DockerService(container: 'core-keeper'),
      );
    });

    test('setDiscovered throws for an unknown profile', () async {
      await expectLater(
        repo.setDiscovered('nope', const Discovered(probedAt: 'now')),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
