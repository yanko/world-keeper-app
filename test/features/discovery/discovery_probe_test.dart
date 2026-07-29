import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/discovery/data/discovery_probe.dart';

import '../../support/fake_transport.dart';

/// A transport that answers nothing — the base case for "this host has no Core Keeper".
FakeTransport emptyHost() => FakeTransport();

void main() {
  group('specificityRank', () {
    test('an exact match ranks best', () {
      expect(specificityRank('corekeeper'), 0);
      expect(specificityRank('core-keeper'), 0);
      expect(specificityRank('core_keeper'), 0);
      expect(specificityRank('CoreKeeper'), 0);
    });

    test('a suffixed lookalike ranks below an exact match', () {
      // The real case: a `corekeeper-api` sidecar next to the real unit.
      expect(specificityRank('corekeeper-api'), 1);
      expect(specificityRank('my-corekeeper'), 1);
      expect(
        specificityRank('corekeeper'),
        lessThan(specificityRank('corekeeper-api')),
      );
    });

    test('an unrelated name ranks worst', () {
      expect(specificityRank('core-network'), 2);
      expect(specificityRank('nginx'), 2);
    });
  });

  group('posixDirname', () {
    test('returns the parent directory', () {
      expect(
        posixDirname('/home/steam/worlds/0.world.gzip'),
        '/home/steam/worlds',
      );
    });

    test('handles paths containing spaces', () {
      expect(
        posixDirname('/home/steam/Core Keeper/worlds/0.world.gzip'),
        '/home/steam/Core Keeper/worlds',
      );
    });

    test('treats backslashes as ordinary characters, not separators', () {
      // Remote paths are POSIX even when this app runs on Windows, so `package:path`'s
      // platform-dependent context would mangle a filename containing a backslash.
      expect(posixDirname(r'/srv/odd\name/0.world.gzip'), r'/srv/odd\name');
    });

    test('handles a root-level file', () {
      expect(posixDirname('/x'), '/');
    });

    test('returns empty for a bare name', () {
      expect(posixDirname('x'), '');
    });
  });

  group('dedupeParentDirs', () {
    test('one directory is a confident answer', () {
      final r = dedupeParentDirs('/w/0.world.gzip\n/w/1.world.gzip\n');
      expect(r.single, '/w');
      expect(r.candidates, isEmpty);
    });

    test('several directories become candidates, never a guess', () {
      final r = dedupeParentDirs('/a/0.world.gzip\n/b/0.world.gzip\n');
      expect(r.single, isNull);
      expect(r.candidates, ['/a', '/b']);
    });

    test('nothing found is neither', () {
      final r = dedupeParentDirs('');
      expect(r.single, isNull);
      expect(r.candidates, isEmpty);
    });

    test('ignores blank lines and duplicates', () {
      final r = dedupeParentDirs(
        '\n/w/0.world.gzip\n\n/w/0.world.gzip.pugbackup\n',
      );
      expect(r.single, '/w');
    });

    test("ignores the app's own backup and staging directories", () {
      // Every push writes a dated copy into `.backups/`, and those copies are
      // `*.world.gzip` files too — so on a host that has been used, `find` returns one
      // directory per backup ever made. Without this filter the reference host offered
      // sixteen candidates, fifteen of them backups of the one real answer.
      const found = '''
/srv/worlds/0.world.gzip
/srv/worlds/.backups/0.2026-07-25_035406/0.world.gzip
/srv/worlds/.backups/0.2026-07-26_182116/0.world.gzip
/srv/worlds/.staging/0.world.gzip
''';
      final r = dedupeParentDirs(found);
      expect(r.single, '/srv/worlds');
      expect(r.candidates, isEmpty);
    });

    test('collapses a nested directory into its containing worlds dir', () {
      const found = '''
/srv/worlds/0.world.gzip
/srv/worlds/0.2026-07-25_221145/0.world.gzip
''';
      expect(dedupeParentDirs(found).single, '/srv/worlds');
    });

    test('keeps a genuinely separate directory as a real choice', () {
      // A sibling backup directory is not inside the worlds dir, so it stays ambiguous
      // — that is a real question only the user can answer.
      const found = '''
/srv/worlds/0.world.gzip
/srv/worlds.bak.2026-07-24/0.world.gzip
''';
      final r = dedupeParentDirs(found);
      expect(r.single, isNull);
      expect(r.candidates, hasLength(2));
      // ...but the one actually named `worlds` is offered first.
      expect(r.candidates.first, '/srv/worlds');
    });

    test('does not mistake ~/.config for a scratch directory', () {
      // The real worlds path lives under a hidden directory, so a blanket
      // "skip anything hidden" rule would discard the correct answer.
      const path =
          '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds';
      expect(dedupeParentDirs('$path/0.world.gzip\n').single, path);
    });

    test('reproduces the reference host exactly', () {
      // Verbatim from a real probe of the reference LXC, which returned sixteen
      // directories. Everything but the live worlds dir is one of this app's own
      // backups, except the sibling `worlds.bak.…` a human made.
      const worlds =
          '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds';
      final found = StringBuffer('$worlds/0.world.gzip\n')
        ..writeln('$worlds.bak.2026-07-24/0.world.gzip')
        ..writeln('$worlds/0.2026-07-25_221145/0.world.gzip')
        ..writeln('$worlds/0.2026-07-25_224235/0.world.gzip');
      for (final ts in [
        '0.2026-07-25_035406',
        '0.2026-07-25_035725',
        '0.2026-07-25_040943',
        '0.2026-07-25_054908',
        '0.2026-07-25_073830',
        '0.2026-07-25_204428',
        '0.2026-07-25_221145',
        '0.2026-07-25_221353',
        '0.2026-07-25_224235',
        '0.2026-07-26_001002',
        '0.2026-07-26_002210',
        '0.2026-07-26_182116',
      ]) {
        found.writeln('$worlds/.backups/$ts/0.world.gzip');
      }

      final r = dedupeParentDirs(found.toString());
      // Sixteen down to two, with the right one pre-selected.
      expect(r.candidates, hasLength(2));
      expect(r.candidates.first, worlds);
      expect(r.candidates[1], '$worlds.bak.2026-07-24');
    });
  });

  group('OS probe', () {
    test('reads PRETTY_NAME and strips quotes', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'os-release',
          'NAME="Debian GNU/Linux"\n'
              'PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"\n'
              'VERSION_ID="12"\n',
        );
      final result = await DiscoveryProbe(t).probe();
      expect(result.os, 'Debian GNU/Linux 12 (bookworm)');
    });

    test('is null when os-release is unavailable', () async {
      final result = await DiscoveryProbe(emptyHost()).probe();
      expect(result.os, isNull);
    });
  });

  group('systemd detection', () {
    test('a single matching unit is selected outright', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'systemctl list-units',
          '  corekeeper.service  loaded active running Core Keeper\n',
        )
        ..stdoutForContaining(
          'systemctl cat',
          'ExecStart=/home/steam/corekeeper/_launch.sh\n'
              'User=steam\n'
              'WorkingDirectory=/home/steam/corekeeper\n',
        )
        ..stdoutForContaining(
          "find '/home'",
          '/home/steam/worlds/0.world.gzip\n',
        );

      final r = await DiscoveryProbe(t).probe();
      expect(r.serviceKind, const SystemdService(unit: 'corekeeper'));
      expect(r.serviceKindCandidates, isEmpty);
      expect(r.steamUser, 'steam');
      expect(r.launchScript, '/home/steam/corekeeper/_launch.sh');
      expect(r.worldsPath, '/home/steam/worlds');
      expect(r.isConclusive, isTrue);
    });

    test('several matches become candidates with the best first', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'systemctl list-units',
          '  corekeeper-api.service  loaded active running API\n'
              '  corekeeper.service      loaded active running Core Keeper\n',
        )
        ..stdoutForContaining(
          'systemctl cat',
          'ExecStart=/usr/bin/something\nUser=steam\n',
        );

      final r = await DiscoveryProbe(t).probe();
      // Refuses to guess...
      expect(r.serviceKind, isNull);
      expect(r.serviceKindCandidates, hasLength(2));
      // ...but orders them so confirming is one click.
      expect(
        r.serviceKindCandidates.first.kind,
        const SystemdService(unit: 'corekeeper'),
      );
      expect(r.isConclusive, isFalse);
    });

    test('handles the leading bullet systemd puts on failed units', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'systemctl list-units',
          '● corekeeper.service loaded failed failed Core Keeper\n',
        );
      final r = await DiscoveryProbe(t).probe();
      expect(r.serviceKind, const SystemdService(unit: 'corekeeper'));
    });

    test('ignores lines that are not units', () async {
      final t = emptyHost()
        ..stdoutForContaining('systemctl list-units', 'some noise\n\n');
      final r = await DiscoveryProbe(t).probe();
      expect(r.serviceKind, isNull);
    });
  });

  group('docker detection', () {
    test('a single container is selected and its mounts are searched', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'docker ps',
          'core-keeper ich777/steamcmd:corekeeper\n',
        )
        ..stdoutForContaining(
          'docker inspect',
          '[{"Type":"bind","Source":"/mnt/user/appdata/ck","Destination":"/serverdata"},'
              '{"Type":"volume","Source":"/var/lib/docker/volumes/x/_data",'
              '"Destination":"/steamcmd"}]',
        )
        ..stdoutForContaining(
          "find '/mnt/user/appdata/ck'",
          '/mnt/user/appdata/ck/Save/worlds/0.world.gzip\n',
        );

      final r = await DiscoveryProbe(t).probe();
      expect(r.serviceKind, const DockerService(container: 'core-keeper'));
      expect(r.worldsPath, '/mnt/user/appdata/ck/Save/worlds');
    });

    test('the docker inspect format string is shell-quoted', () async {
      // It contains a space; unquoted the remote shell splits it into two argv entries
      // before docker parses --format, and the mount lookup silently returns nothing.
      final t = emptyHost()
        ..stdoutForContaining('docker ps', 'core-keeper img\n')
        ..stdoutForContaining('docker inspect', '[]');

      await DiscoveryProbe(t).probe();
      final inspect = t.commands.firstWhere(
        (c) => c.contains('docker inspect'),
      );
      expect(inspect, contains("--format '{{json .Mounts}}'"));
    });

    test('searches named volumes as well as bind mounts', () async {
      final t = emptyHost()
        ..stdoutForContaining('docker ps', 'core-keeper img\n')
        ..stdoutForContaining(
          'docker inspect',
          '[{"Type":"volume","Source":"/var/lib/docker/volumes/ck/_data"}]',
        )
        ..stdoutForContaining(
          'find ',
          '/var/lib/docker/volumes/ck/_data/worlds/0.world.gzip\n',
        );

      final r = await DiscoveryProbe(t).probe();
      expect(r.worldsPath, '/var/lib/docker/volumes/ck/_data/worlds');
    });

    test(
      'several containers become candidates carrying their image names',
      () async {
        final t = emptyHost()
          ..stdoutForContaining(
            'docker ps',
            'core-keeper-backup busybox\ncore-keeper ich777/steamcmd:corekeeper\n',
          );

        final r = await DiscoveryProbe(t).probe();
        expect(r.serviceKind, isNull);
        expect(r.serviceKindCandidates, hasLength(2));
        expect(
          r.serviceKindCandidates.first.kind,
          const DockerService(container: 'core-keeper'),
        );
        expect(
          r.serviceKindCandidates.first.execStart,
          'ich777/steamcmd:corekeeper',
        );
      },
    );

    test(
      'malformed docker inspect JSON yields no path rather than throwing',
      () async {
        final t = emptyHost()
          ..stdoutForContaining('docker ps', 'core-keeper img\n')
          ..stdoutForContaining('docker inspect', 'not json at all');

        final r = await DiscoveryProbe(t).probe();
        expect(r.serviceKind, const DockerService(container: 'core-keeper'));
        expect(r.worldsPath, isNull);
        expect(r.worldsPathCandidates, isEmpty);
      },
    );

    test('a docker target never falls back to searching /home', () async {
      // The container's worlds live under its mounts; searching the host at large would
      // find an unrelated copy at best.
      final t = emptyHost()
        ..stdoutForContaining('docker ps', 'core-keeper img\n')
        ..stdoutForContaining('docker inspect', '[]');

      await DiscoveryProbe(t).probe();
      expect(t.commands.any((c) => c.contains("find '/home'")), isFalse);
    });
  });

  group('bare process detection', () {
    test('builds stop and start commands from the process cmdline', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'pgrep -af',
          '4242 /home/steam/corekeeper/_launch.sh\n',
        );

      final r = await DiscoveryProbe(t).probe();
      final kind = r.serviceKind;
      expect(kind, isA<ProcessService>());
      kind as ProcessService;
      expect(kind.startCmd, '/home/steam/corekeeper/_launch.sh');
      // The cmdline is a *value* here, so it is quoted.
      expect(kind.stopCmd, "pkill -f '/home/steam/corekeeper/_launch.sh'");
      expect(kind.logPath, isNull);
    });

    test('strips only the pid, keeping arguments', () async {
      final t = emptyHost()
        ..stdoutForContaining('pgrep -af', '99 /opt/ck/run.sh --world 0\n');
      final kind =
          (await DiscoveryProbe(t).probe()).serviceKind! as ProcessService;
      expect(kind.startCmd, '/opt/ck/run.sh --world 0');
    });

    test('resolves the user the process actually runs as', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'pgrep -af',
          '4242 /home/steam/corekeeper/_launch.sh\n',
        )
        ..stdoutForContaining('ps -o user= -p 4242', 'steam\n');

      expect((await DiscoveryProbe(t).probe()).steamUser, 'steam');
    });

    test('a malformed pgrep line does not produce a bogus ps lookup', () async {
      final t = emptyHost()
        ..stdoutForContaining('pgrep -af', 'not-a-pid oops\n');
      await DiscoveryProbe(t).probe();
      expect(t.commands.any((c) => c.startsWith('ps -o user=')), isFalse);
    });
  });

  group('worlds path on a non-Docker host', () {
    test('finds worlds under /root when the server runs as root', () async {
      // The shape that broke on a real LXC: `_launch.sh` lives in /home/steam but the
      // process runs as root, so `$HOME` is /root and searching /home finds nothing.
      final t = emptyHost()
        ..stdoutForContaining(
          'pgrep -af',
          '1287462 /bin/bash /home/steam/corekeeper/_launch.sh\n',
        )
        ..stdoutForContaining('ps -o user=', 'root\n')
        ..stdoutForContaining('getent passwd', '/root\n')
        ..stdoutForContaining(
          "find '/root' -name",
          '/root/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds/0.world.gzip\n',
        );

      final r = await DiscoveryProbe(t).probe();
      expect(
        r.worldsPath,
        '/root/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds',
      );
    });

    test('/root is searched even when nothing was resolved', () async {
      // A host where `ps` and `getent` tell us nothing still gets both usual roots.
      final t = emptyHost()..stdoutForContaining('pgrep -af', '1 /run.sh\n');
      await DiscoveryProbe(t).probe();

      expect(t.commands.any((c) => c.contains("find '/home' -name")), isTrue);
      expect(t.commands.any((c) => c.contains("find '/root' -name")), isTrue);
    });

    test('an empty worlds directory is still found', () async {
      // A server installed and started but never saved has the directory and no files in
      // it. Searching only for files reported "none found" on a perfectly healthy host.
      final t = emptyHost()
        ..stdoutForContaining('pgrep -af', '1 /home/steam/run.sh\n')
        ..stdoutForContaining(
          "find '/home' -maxdepth 8 -type d",
          '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds\n',
        );

      final r = await DiscoveryProbe(t).probe();
      expect(
        r.worldsPath,
        '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds',
      );
    });

    test('actual worlds win over an empty directory elsewhere', () async {
      // Files are the stronger evidence, so the directory sweep is not even run.
      final t = emptyHost()
        ..stdoutForContaining('pgrep -af', '1 /home/steam/run.sh\n')
        ..stdoutForContaining(
          "find '/home' -name",
          '/home/steam/w/0.world.gzip\n',
        );

      final r = await DiscoveryProbe(t).probe();
      expect(r.worldsPath, '/home/steam/w');
      expect(
        t.commands.any((c) => c.contains('-type d -name worlds')),
        isFalse,
      );
    });

    test('a systemd unit contributes its WorkingDirectory as a root', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'systemctl list-units',
          '  corekeeper.service loaded\n',
        )
        ..stdoutForContaining(
          'systemctl cat',
          'ExecStart=/opt/ck/run.sh\nUser=steam\nWorkingDirectory=/srv/corekeeper\n',
        );

      await DiscoveryProbe(t).probe();
      expect(
        t.commands.any((c) => c.contains("find '/srv/corekeeper' -name")),
        isTrue,
      );
    });
  });

  group('searchRoots', () {
    test('always covers both a user home and root', () {
      expect(searchRoots(), ['/home', '/root']);
    });

    test('drops a root that lives inside another', () {
      // Otherwise /home gets walked twice for no benefit.
      expect(searchRoots(homeDir: '/home/steam'), ['/home', '/root']);
    });

    test('keeps a home outside the usual places', () {
      expect(
        searchRoots(homeDir: '/srv/ck'),
        containsAll(['/home', '/root', '/srv/ck']),
      );
    });

    test('a trailing slash does not create a second root', () {
      expect(searchRoots(homeDir: '/srv/ck/'), ['/home', '/root', '/srv/ck']);
    });

    test('ignores a home of / rather than searching the whole disk', () {
      expect(searchRoots(homeDir: '/'), ['/home', '/root']);
    });
  });

  group('detection order', () {
    test('systemd wins over docker when both are present', () async {
      final t = emptyHost()
        ..stdoutForContaining(
          'systemctl list-units',
          '  corekeeper.service loaded\n',
        )
        ..stdoutForContaining('docker ps', 'core-keeper img\n');

      final r = await DiscoveryProbe(t).probe();
      expect(r.serviceKind, isA<SystemdService>());
      // Docker is never even asked once systemd answered.
      expect(t.commands.any((c) => c.contains('docker ps')), isFalse);
    });

    test('docker wins over a bare process', () async {
      final t = emptyHost()
        ..stdoutForContaining('docker ps', 'core-keeper img\n')
        ..stdoutForContaining('docker inspect', '[]')
        ..stdoutForContaining('pgrep -af', '1 /run.sh\n');

      final r = await DiscoveryProbe(t).probe();
      expect(r.serviceKind, isA<DockerService>());
    });

    test('a host with nothing reports nothing rather than guessing', () async {
      final r = await DiscoveryProbe(emptyHost()).probe();
      expect(r.serviceKind, isNull);
      expect(r.serviceKindCandidates, isEmpty);
      expect(r.worldsPath, isNull);
      expect(r.foundNothing, isTrue);
      expect(r.isConclusive, isFalse);
    });
  });

  test('the probe is read-only', () async {
    // Discovery runs before the user has confirmed anything about this host. It must
    // never write, move, stop or start.
    final t = emptyHost()
      ..stdoutForContaining(
        'systemctl list-units',
        '  corekeeper.service loaded\n',
      )
      ..stdoutForContaining("find '/home'", '/w/0.world.gzip\n');

    await DiscoveryProbe(t).probe();

    const forbidden = [
      'systemctl stop',
      'systemctl start',
      'systemctl restart',
      'docker stop',
      'docker start',
      'docker rm',
      'rm ',
      'mv ',
      'cp ',
      'chown',
      'chmod',
      'mkdir',
      'tee ',
      'truncate',
    ];
    for (final cmd in t.commands) {
      for (final bad in forbidden) {
        expect(
          cmd.contains(bad),
          isFalse,
          reason: 'discovery ran a non-read-only command: $cmd',
        );
      }
      // Output redirection would write a file. `2>/dev/null` is the one legitimate
      // redirect — it discards stderr — so it is stripped before checking.
      final withoutStderrDiscard = cmd.replaceAll('2>/dev/null', '');
      expect(
        withoutStderrDiscard.contains('>'),
        isFalse,
        reason: 'discovery redirected output to a file: $cmd',
      );
    }
  });

  test('records the probe time as RFC-3339 UTC', () async {
    final r = await DiscoveryProbe(emptyHost()).probe();
    final parsed = DateTime.tryParse(r.probedAt);
    expect(parsed, isNotNull);
    expect(parsed!.isUtc, isTrue);
  });
}
