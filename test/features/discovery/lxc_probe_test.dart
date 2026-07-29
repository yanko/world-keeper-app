import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/discovery/data/discovery_probe.dart';

import '../../support/fake_transport.dart';

/// Regression tests written from a real transcript.
///
/// A Debian 13 host with Core Keeper running from `/home/steam/corekeeper/_launch.sh`
/// reported "Worlds path — none found" while the server was up and healthy. The
/// transcript from that host is reproduced below and drove every fix here — three
/// separate faults, only one of which was the one being looked for.
void main() {
  /// The host as it actually answered.
  FakeTransport lxcHost({
    String psUser = '101000',
    String environ = '',
    String procRoot = '/',
  }) {
    final t = FakeTransport();

    t.stdoutFor(
      'cat /etc/os-release 2>/dev/null',
      'PRETTY_NAME="Debian GNU/Linux 13 (trixie)"\nID=debian\n',
    );
    // Both greps exited 1 on the real host: nothing matched.
    t.respondToContaining(
      'systemctl list-units',
      const ExecOutput(stdout: '', stderr: '', exitStatus: 1),
    );
    t.respondToContaining(
      'docker ps',
      const ExecOutput(stdout: '', stderr: '', exitStatus: 1),
    );

    // The real server *and* the probe's own pgrep, which matches its own pattern.
    t.stdoutForContaining(
      'pgrep -af _launch.sh',
      '1287462 /bin/bash /home/steam/corekeeper/_launch.sh\n'
          '2093839 bash -c pgrep -af _launch.sh 2>/dev/null || '
          'pgrep -af CoreKeeperServer 2>/dev/null\n',
    );
    t.stdoutForContaining('ps -o user=', '$psUser\n');
    t.stdoutForContaining('getent passwd', '');
    t.stdoutForContaining('/environ', environ);
    t.stdoutForContaining('readlink /proc/', procRoot);

    return t;
  }

  group('the probe no longer finds itself', () {
    test('the pgrep line matching our own command is discarded', () async {
      // `pgrep -f` matches the whole command line, and the command line contains the
      // pattern — so the probe and the server come back together. Whichever lands first
      // is down to pid ordering, and picking ours builds a target whose "start the
      // server" command is a pgrep and whose stop command kills our own shell.
      final result = await DiscoveryProbe(lxcHost()).probe();
      final kind = result.serviceKind;

      expect(kind, isA<ProcessService>());
      final process = kind! as ProcessService;

      expect(process.startCmd, '/bin/bash /home/steam/corekeeper/_launch.sh');
      expect(process.startCmd, isNot(contains('pgrep')));
      expect(process.stopCmd, isNot(contains('pgrep')));
    });

    test(
      'a host where only our own pgrep matches is not a Core Keeper host',
      () async {
        final t = FakeTransport();
        t.stdoutForContaining(
          'pgrep -af _launch.sh',
          '999 bash -c pgrep -af _launch.sh 2>/dev/null\n',
        );

        final result = await DiscoveryProbe(t).probe();
        expect(
          result.serviceKind,
          isNull,
          reason: 'finding only ourselves is finding nothing',
        );
      },
    );
  });

  group('the home directory comes from the process, not the password database', () {
    test('a numeric uid with no passwd entry is not a dead end', () async {
      // What the LXC returned: `ps -o user=` printed `101000`, the host-side uid of an
      // unprivileged container's user, and `getent passwd 101000` printed nothing. The
      // old probe gave up there and searched only /home and /root.
      final t = lxcHost(
        environ: 'HOME=/home/steam\nXDG_CONFIG_HOME=/home/steam/.config\n',
      );

      await DiscoveryProbe(t).probe();

      expect(
        t.commands.any((c) => c.contains('/environ')),
        isTrue,
        reason: 'the process environment is the authoritative source for HOME',
      );
    });

    test('XDG_CONFIG_HOME is searched when the launch script sets it', () async {
      // Core Keeper writes under `$XDG_CONFIG_HOME/unity3d/...` when it is set, which a
      // launch script is free to point anywhere. Searching only `$HOME` misses it.
      final t = lxcHost(
        environ: 'HOME=/home/steam\nXDG_CONFIG_HOME=/srv/ck-config\n',
      );

      await DiscoveryProbe(t).probe();

      expect(
        t.commands.any((c) => c.contains("find '/srv/ck-config'")),
        isTrue,
      );
    });
  });

  test('the launch script’s own directory becomes a search root', () {
    // `/bin/bash /home/steam/corekeeper/_launch.sh` names a directory that certainly
    // exists and is certainly related to the server. That is worth more than a guess.
    final roots = searchRoots(scriptDir: '/home/steam/corekeeper');

    // Dropped as a descendant of /home, which is already searched — the point is that it
    // is considered, and that a script outside /home would be added.
    expect(roots, contains('/home'));

    final elsewhere = searchRoots(scriptDir: '/opt/corekeeper');
    expect(elsewhere, contains('/opt/corekeeper'));
  });

  group('a server in another mount namespace', () {
    test('is reported as such rather than as "none found"', () async {
      // SSH into a Proxmox host, Core Keeper inside an unprivileged LXC: `pgrep` sees the
      // process and reports the command line it was started with, but those paths belong
      // to the container. Every find comes back empty on a server that is running fine,
      // and no amount of searching harder fixes it.
      final result = await DiscoveryProbe(
        lxcHost(procRoot: '/var/lib/lxc/103/rootfs\n'),
      ).probe();

      expect(result.isInAnotherNamespace, isTrue);
      expect(result.containerRoot, '/var/lib/lxc/103/rootfs');
      expect(
        result.serviceKind,
        isNotNull,
        reason: 'the service was found; only its filesystem was not',
      );
    });

    test('the ordinary case is not flagged', () async {
      final result = await DiscoveryProbe(lxcHost()).probe();
      expect(result.isInAnotherNamespace, isFalse);
    });
  });

  test('every search root reached the host', () async {
    // The transcript is the contract: whatever the probe decided to search, it must be
    // visible as a command that was actually sent.
    final t = lxcHost(environ: 'HOME=/home/steam\n');
    final result = await DiscoveryProbe(t).probe();

    final finds = result.trace.where((s) => s.command.startsWith('find'));
    expect(finds, isNotEmpty);
    for (final f in finds) {
      expect(t.commands, contains(f.command));
    }
  });

  group('a server that has never saved', () {
    // The second transcript from the same host: HOME=/home/steam, /proc/pid/root is `/`
    // so nothing is containerised, every find ran cleanly and returned nothing. There is
    // no worlds directory because the server has not written one — and no search can
    // produce a path that is not on disk.

    test('the expected path is derived from HOME', () {
      expect(
        expectedWorldsPath(homeDir: '/home/steam'),
        '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds',
      );
    });

    test('XDG_CONFIG_HOME wins over HOME, as Unity resolves it', () {
      expect(
        expectedWorldsPath(homeDir: '/home/steam', configHome: '/srv/cfg'),
        '/srv/cfg/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds',
      );
    });

    test('a trailing slash does not double up', () {
      expect(
        expectedWorldsPath(configHome: '/srv/cfg/'),
        startsWith('/srv/cfg/unity3d'),
      );
    });

    test('no environment means no guess', () {
      // Better to leave the field blank than to invent a path from nothing.
      expect(expectedWorldsPath(), isNull);
    });

    test('it is offered as a suggestion, never as a finding', () async {
      final result = await DiscoveryProbe(
        lxcHost(environ: 'HOME=/home/steam\n'),
      ).probe();

      expect(
        result.worldsPath,
        isNull,
        reason: 'nothing was confirmed to exist',
      );
      expect(result.worldsPathCandidates, isEmpty);
      expect(
        result.expectedWorldsPath,
        '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds',
      );
    });

    test(
      'the home directory is listed into the transcript before giving up',
      () async {
        // A search cannot tell "never saved" from "installed somewhere unexpected"; a
        // listing can, and it only costs a command on the path that was going to say
        // "none found" anyway.
        final t = lxcHost(environ: 'HOME=/home/steam\n');
        await DiscoveryProbe(t).probe();

        expect(
          t.commands.any(
            (c) => c.contains("find '/home/steam' -maxdepth 6 -type d"),
          ),
          isTrue,
        );
      },
    );

    test('a host that did find worlds gets no suggestion', () async {
      final t = lxcHost(environ: 'HOME=/home/steam\n');
      t.stdoutForContaining(
        "-name '*.world.gzip'",
        '/home/steam/worlds/0.world.gzip\n',
      );

      final result = await DiscoveryProbe(t).probe();

      expect(result.worldsPath, '/home/steam/worlds');
      expect(
        result.expectedWorldsPath,
        isNull,
        reason: 'suggesting a path beside a real one would be noise',
      );
    });
  });

  test('the game binary is probed, not only the wrapper', () async {
    // `_launch.sh` execs the game, and it is the game that writes the worlds. A launch
    // script may export HOME before doing so, in which case the wrapper's environment —
    // the shell's, from before the script ran — is the wrong answer entirely.
    final t = FakeTransport();
    t.stdoutForContaining(
      'pgrep -af _launch.sh',
      '100 /bin/bash /home/steam/corekeeper/_launch.sh\n',
    );
    t.stdoutForContaining(
      'pgrep -af CoreKeeperServer',
      '200 ./CoreKeeperServer -batchmode\n',
    );
    t.stdoutForContaining('/proc/200/environ', 'HOME=/srv/ck\n');
    t.stdoutForContaining('/proc/100/environ', 'HOME=/root\n');

    final result = await DiscoveryProbe(t).probe();

    expect(
      (result.serviceKind! as ProcessService).startCmd,
      '/bin/bash /home/steam/corekeeper/_launch.sh',
      reason: 'the wrapper is what you restart',
    );
    expect(
      result.expectedWorldsPath,
      startsWith('/srv/ck/.config'),
      reason: "the binary's environment is what decides where worlds go",
    );
  });

  group('unit matching moved out of the shell', () {
    // It used to be `systemctl ... 2>/dev/null | grep -i core`, where the pipeline's exit
    // status is grep's and stderr is gone — so systemctl failing and no unit matching
    // arrived identically as `exit 1`, nothing else. That is exactly the shape of the
    // report from a host where the desktop build found two units and the phone build
    // found none.
    const listing =
        '  corekeeper.service      loaded active   running Core Keeper Dedicated Server\n'
        '  corekeeper-api.service  loaded active   running Core Keeper API\n'
        '  cron.service            loaded active   running Regular background program\n'
        '  dbus.service            loaded active   running D-Bus System Message Bus\n';

    test('finds the units a grep would have', () {
      expect(unitsMatching(listing), ['corekeeper', 'corekeeper-api']);
    });

    test('ignores everything else on the host', () {
      expect(unitsMatching(listing), isNot(contains('cron')));
      expect(unitsMatching(listing), isNot(contains('dbus')));
    });

    test('handles the failed-unit bullet an older systemd still prints', () {
      // `--plain` should suppress it; a systemd that ignores the flag must not produce a
      // unit called "*".
      expect(
        unitsMatching(
          '* corekeeper.service loaded failed failed Core Keeper\n',
        ),
        ['corekeeper'],
      );
    });

    test('an empty listing is no units, not a crash', () {
      expect(unitsMatching(''), isEmpty);
      expect(unitsMatching('\n\n  \n'), isEmpty);
    });

    test('non-service units are not services', () {
      expect(
        unitsMatching(
          'corekeeper.timer loaded active waiting\n'
          'corekeeper.socket loaded active listening\n',
        ),
        isEmpty,
      );
    });

    test('the command no longer filters or silences anything', () async {
      final t = lxcHost();
      await DiscoveryProbe(t).probe();

      final listUnits = t.commands.firstWhere(
        (c) => c.startsWith('systemctl list-units'),
      );

      expect(listUnits, isNot(contains('grep')));
      expect(
        listUnits,
        isNot(contains('2>/dev/null')),
        reason:
            'stderr is the only thing that says why a probe came back empty',
      );
      expect(
        listUnits,
        contains('--all'),
        reason: 'a stopped service still counts',
      );
    });

    test('a stopped Core Keeper service is still discovered', () async {
      // `--all`. A server you are about to push to may well be down — that is often the
      // reason the app was opened.
      final t = lxcHost();
      // An exact match, which `FakeTransport` consults before its substring patterns —
      // `lxcHost` already registers an empty substring response for this command.
      t.stdoutFor(
        'systemctl list-units --type=service --all --no-pager --no-legend --plain',
        'corekeeper.service loaded inactive dead Core Keeper Dedicated Server\n',
      );

      final result = await DiscoveryProbe(t).probe();

      expect(result.serviceKind, isA<SystemdService>());
      expect((result.serviceKind! as SystemdService).unit, 'corekeeper');
    });
  });

  test('docker being absent is an answer, not a failed probe', () async {
    // Most hosts have no docker. Reporting that as "1 command could not run" would put a
    // red error marker on every healthy systemd box.
    final t = FakeTransport(
      defaultResponse: const ExecOutput(
        stdout: '',
        stderr: 'sh: docker: not found',
        exitStatus: 127,
      ),
    );

    final result = await DiscoveryProbe(t).probe();
    final docker = result.trace.firstWhere(
      (s) => s.command.startsWith('docker ps'),
    );

    expect(docker.exitStatus, 127);
    expect(docker.succeeded, isTrue, reason: 'not installed is not a fault');
    expect(
      docker.stderr,
      contains('not found'),
      reason:
          '"not installed" and "permission denied on the socket" must stay '
          'distinguishable',
    );
  });

  group('a bare process needs its log found', () {
    // systemd has the journal and Docker has its own log by construction. A script
    // redirecting to a file is the one shape where there may be nothing to read — and
    // without a log there is no live log panel *and* no game id, because the id is parsed
    // out of the log.

    test('one log beside the launch script is taken', () async {
      final t = lxcHost();
      t.stdoutForContaining(
        "-name '*.log'",
        '/home/steam/corekeeper/server.log\n',
      );

      final result = await DiscoveryProbe(t).probe();

      expect(
        (result.serviceKind! as ProcessService).logPath,
        '/home/steam/corekeeper/server.log',
      );
    });

    test('several candidates are left unset rather than guessed', () async {
      // A live log panel confidently tailing the wrong file is worse than an empty one.
      // The Discovery screen takes the path by hand for this case.
      final t = lxcHost();
      t.stdoutForContaining(
        "-name '*.log'",
        '/home/steam/corekeeper/server.log\n'
            '/home/steam/corekeeper/steamcmd.log\n',
      );

      final result = await DiscoveryProbe(t).probe();

      expect((result.serviceKind! as ProcessService).logPath, isNull);
    });

    test('no log at all is not a failure', () async {
      final result = await DiscoveryProbe(lxcHost()).probe();
      expect((result.serviceKind! as ProcessService).logPath, isNull);
    });

    test(
      'it searches beside the script and in the working directory',
      () async {
        final t = lxcHost();
        await DiscoveryProbe(t).probe();

        final find = t.commands.firstWhere(
          (c) => c.contains("-name '*.log'"),
          orElse: () => '',
        );

        expect(find, contains('/home/steam/corekeeper'));
        expect(
          find,
          contains('-maxdepth 2'),
          reason: 'searching wider turns up every unrelated log on the box',
        );
      },
    );
  });
}
