import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/ssh/ssh_target.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';

import '../../support/fake_transport.dart';

/// The per-ServiceKind command matrix, asserted literally.
///
/// These strings are the entire contract with the remote host. Nothing in the type
/// system protects them, and a single wrong character means a destructive operation
/// misfires against a live server — so they are pinned here rather than trusted.

const systemd = SystemdService(unit: 'corekeeper');
const docker = DockerService(container: 'core-keeper');
const process = ProcessService(
  stopCmd: "pkill -f '/home/steam/corekeeper/_launch.sh'",
  startCmd: '/home/steam/corekeeper/_launch.sh',
  logPath: '/var/log/corekeeper.log',
);

/// The reference path, with the spaces that make quoting non-optional.
const worldsPath =
    '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds';

SshTarget targetFor(
  ServiceKind kind, {
  FakeTransport? transport,
  String? steamUser,
  String path = worldsPath,
}) => SshTarget(
  transport: transport ?? FakeTransport(),
  serviceKind: kind,
  worldsPath: path,
  steamUser: steamUser,
);

void main() {
  group('serviceControl', () {
    test('systemd', () async {
      for (final (action, expected) in [
        (ServiceAction.status, "systemctl is-active 'corekeeper'"),
        (ServiceAction.stop, "systemctl stop 'corekeeper'"),
        (ServiceAction.start, "systemctl start 'corekeeper'"),
      ]) {
        final t = FakeTransport();
        await targetFor(systemd, transport: t).serviceControl(action);
        expect(t.onlyCommand, expected);
      }
    });

    test('docker', () async {
      for (final (action, expected) in [
        (
          ServiceAction.status,
          "docker inspect -f {{.State.Status}} 'core-keeper'",
        ),
        (ServiceAction.stop, "docker stop 'core-keeper'"),
        (ServiceAction.start, "docker start 'core-keeper'"),
      ]) {
        final t = FakeTransport();
        await targetFor(docker, transport: t).serviceControl(action);
        expect(t.onlyCommand, expected);
      }
    });

    test('process runs the discovered commands verbatim', () async {
      // These are shell commands captured by discovery, not values interpolated into
      // one, so they must not be quoted.
      final stop = FakeTransport();
      await targetFor(
        process,
        transport: stop,
      ).serviceControl(ServiceAction.stop);
      expect(stop.onlyCommand, process.stopCmd);

      final start = FakeTransport();
      await targetFor(
        process,
        transport: start,
      ).serviceControl(ServiceAction.start);
      expect(start.onlyCommand, process.startCmd);
    });

    test('process status greps for the start command', () async {
      // Status is a value being interpolated into a command, so unlike stop/start it
      // *is* quoted.
      final t = FakeTransport();
      await targetFor(
        process,
        transport: t,
      ).serviceControl(ServiceAction.status);
      expect(t.onlyCommand, "pgrep -af '/home/steam/corekeeper/_launch.sh'");
    });
  });

  group('status normalisation', () {
    test('systemd active/inactive/failed', () async {
      for (final (raw, expected) in [
        ('active\n', RunState.running),
        ('inactive\n', RunState.stopped),
        ('failed\n', RunState.failed),
        ('activating\n', RunState.unknown),
      ]) {
        final t = FakeTransport()
          ..stdoutForContaining('systemctl is-active', raw);
        expect(await targetFor(systemd, transport: t).status(), expected);
      }
    });

    test('docker running/exited', () async {
      final t = FakeTransport()
        ..stdoutForContaining('docker inspect', 'running\n');
      expect(await targetFor(docker, transport: t).status(), RunState.running);

      final t2 = FakeTransport()
        ..stdoutForContaining('docker inspect', 'exited\n');
      expect(await targetFor(docker, transport: t2).status(), RunState.stopped);
    });

    test('process is running iff pgrep matched', () async {
      final matched = FakeTransport()
        ..stdoutForContaining('pgrep -f', '4242\n');
      expect(
        await targetFor(process, transport: matched).status(),
        RunState.running,
      );

      final empty = FakeTransport()..stdoutForContaining('pgrep -f', '');
      expect(
        await targetFor(process, transport: empty).status(),
        RunState.stopped,
      );
    });
  });

  group('logsTail', () {
    test('systemd uses journalctl', () async {
      final t = FakeTransport();
      await targetFor(systemd, transport: t).logsTail(200);
      expect(t.onlyCommand, "journalctl -u 'corekeeper' -n 200 --no-pager");
    });

    test('docker uses docker logs', () async {
      final t = FakeTransport();
      await targetFor(docker, transport: t).logsTail(50);
      expect(t.onlyCommand, "docker logs --tail 50 'core-keeper'");
    });

    test('process tails its log file', () async {
      final t = FakeTransport();
      await targetFor(process, transport: t).logsTail(100);
      expect(t.onlyCommand, "tail -n 100 '/var/log/corekeeper.log'");
    });

    test(
      'process with no log path fails clearly instead of inventing one',
      () async {
        const noLog = ProcessService(stopCmd: 'stop', startCmd: 'start');
        await expectLater(
          targetFor(noLog).logsTail(10),
          throwsA(isA<OperationException>()),
        );
      },
    );
  });

  group('activeSince', () {
    test('systemd', () async {
      final t = FakeTransport()
        ..stdoutForContaining(
          'ActiveEnterTimestamp',
          'Sat 2026-07-26 12:00:00 UTC\n',
        );
      final result = await targetFor(systemd, transport: t).activeSince();
      expect(
        t.onlyCommand,
        "systemctl show -p ActiveEnterTimestamp --value 'corekeeper'",
      );
      expect(result, 'Sat 2026-07-26 12:00:00 UTC');
    });

    test('docker', () async {
      final t = FakeTransport()
        ..stdoutForContaining('StartedAt', '2026-07-26T12:00:00.000Z\n');
      expect(
        await targetFor(docker, transport: t).activeSince(),
        '2026-07-26T12:00:00.000Z',
      );
    });

    test('process reports null without running anything', () async {
      final t = FakeTransport();
      expect(await targetFor(process, transport: t).activeSince(), isNull);
      expect(t.commands, isEmpty);
    });

    test('empty output becomes null, not an empty string', () async {
      final t = FakeTransport()
        ..stdoutForContaining('ActiveEnterTimestamp', '\n');
      expect(await targetFor(systemd, transport: t).activeSince(), isNull);
    });
  });

  group('stat', () {
    test('quotes the directory and glob, and parses the listing', () async {
      final t = FakeTransport()
        ..stdoutForContaining(
          'find',
          '5046105 1753564800.0 $worldsPath/0.world.gzip\n',
        );
      final entries = await targetFor(
        systemd,
        transport: t,
      ).stat(worldsPath, '*.world.gzip');

      expect(
        t.onlyCommand,
        "find '$worldsPath' -maxdepth 1 -name '*.world.gzip' "
        r"-printf '%s %T@ %p\n'",
      );
      expect(entries.single.name, '0.world.gzip');
      expect(entries.single.size, 5046105);
    });

    test('an empty but successful listing is not a fallback trigger', () async {
      final t = FakeTransport(defaultResponse: const ExecOutput.empty());
      expect(
        await targetFor(systemd, transport: t).stat('/w', '*.gz'),
        isEmpty,
      );
      // Exit 0 means -printf worked and the directory is simply empty.
      expect(t.commands, hasLength(1));
    });

    test('falls back to POSIX stat when -printf is unsupported', () async {
      // BusyBox `find` has no -printf: it exits non-zero and prints nothing, which
      // otherwise reads as "no worlds found" rather than as an error.
      final t = FakeTransport(
        defaultResponse: const ExecOutput(
          stdout: '',
          stderr: 'find: unrecognized: -printf',
          exitStatus: 1,
        ),
      )..stdoutForContaining('-exec stat', '999 1753564800 /w/0.world.gzip\n');

      final entries = await targetFor(systemd, transport: t).stat('/w', '*.gz');

      expect(entries.single.size, 999);
      expect(t.commands, hasLength(2));
      expect(t.commands.first, contains('-printf'));
      expect(
        t.commands.last,
        "find '/w' -maxdepth 1 -name '*.gz' -exec stat -c '%s %Y %n' {} +",
      );
    });

    test('remembers the fallback instead of re-probing every call', () async {
      final t = FakeTransport(
        defaultResponse: const ExecOutput(
          stdout: '',
          stderr: 'nope',
          exitStatus: 1,
        ),
      )..stdoutForContaining('-exec stat', '1 2 /w/a\n');
      final target = targetFor(systemd, transport: t);

      await target.stat('/w', '*');
      t.clear();
      await target.stat('/w', '*');

      // Second call goes straight to the working form.
      expect(t.commands, hasLength(1));
      expect(t.onlyCommand, contains('-exec stat'));
    });
  });

  group('fixPerms', () {
    test('systemd with a steam user chowns recursively', () async {
      final t = FakeTransport();
      await targetFor(
        systemd,
        transport: t,
        steamUser: 'steam',
      ).fixPerms(worldsPath);
      expect(t.onlyCommand, "chown -R 'steam':'steam' '$worldsPath'");
    });

    test('systemd without a steam user is a no-op', () async {
      final t = FakeTransport();
      await targetFor(systemd, transport: t).fixPerms(worldsPath);
      expect(t.commands, isEmpty);
    });

    test('docker and process are no-ops', () async {
      for (final kind in <ServiceKind>[docker, process]) {
        final t = FakeTransport();
        await targetFor(
          kind,
          transport: t,
          steamUser: 'steam',
        ).fixPerms(worldsPath);
        expect(t.commands, isEmpty, reason: '$kind should not chown');
      }
    });

    test('a failed chown is surfaced, not swallowed', () async {
      final t = FakeTransport(
        defaultResponse: const ExecOutput(
          stdout: '',
          stderr: 'chown: invalid user',
          exitStatus: 1,
        ),
      );
      await expectLater(
        targetFor(
          systemd,
          transport: t,
          steamUser: 'nope',
        ).fixPerms(worldsPath),
        throwsA(
          isA<OperationException>().having((e) => e.step, 'step', 'fixPerms'),
        ),
      );
    });
  });

  group('udpListening', () {
    test('systemd greps ss on the host', () async {
      final t = FakeTransport()
        ..stdoutForContaining(
          'ss -ulnp',
          'UNCONN 0 0 0.0.0.0:56967 users:(("CoreKeeperServe"))\n',
        );
      final lines = await targetFor(systemd, transport: t).udpListening();
      expect(t.onlyCommand, 'ss -ulnp 2>/dev/null | grep -i corekeeper');
      expect(lines, hasLength(1));
    });

    test(
      'docker tier 1: host network mode is found by the cheap host check',
      () async {
        final t = FakeTransport()
          ..stdoutForContaining(
            'ss -ulnp',
            'UNCONN 0 0 0.0.0.0:56967 users:(("CoreKeeperServe"))\n',
          );
        final lines = await targetFor(docker, transport: t).udpListening();
        expect(lines, hasLength(1));
        // Stops at tier 1 — no need to shell into the container.
        expect(t.commands, hasLength(1));
      },
    );

    test('docker tier 2: published ports', () async {
      final t = FakeTransport()
        ..stdoutForContaining('ss -ulnp', '')
        ..stdoutForContaining('docker port', '27015/udp -> 0.0.0.0:27015\n')
        ..stdoutForContaining('grep -E', 'UNCONN 0 0 0.0.0.0:27015\n');

      final lines = await targetFor(docker, transport: t).udpListening();
      expect(lines, hasLength(1));
      expect(
        t.commands[1],
        "docker port 'core-keeper' 2>/dev/null | grep -i udp",
      );
      expect(t.commands[2], contains(r"grep -E ':(27015)\b'"));
    });

    test('docker tier 3: ss inside the container', () async {
      final t = FakeTransport()
        ..stdoutForContaining('ss -ulnp', '')
        ..stdoutForContaining('docker port', '')
        ..stdoutForContaining(
          'docker exec',
          'State  Recv-Q Send-Q Local Address:Port\nUNCONN 0 0 0.0.0.0:56967\n',
        );

      final lines = await targetFor(docker, transport: t).udpListening();
      expect(lines, hasLength(1));
      expect(lines.single, contains('56967'));
      expect(t.commands.last, "docker exec 'core-keeper' ss -uln 2>/dev/null");
    });

    test(
      'docker tier 3 does not mistake an exec error on stdout for data',
      () async {
        // Some OCI runtimes print "exec failed" to *stdout* despite the redirect. Without
        // the success check that text would be returned as if it were listener lines.
        final t = FakeTransport()
          ..stdoutForContaining('ss -ulnp', '')
          ..stdoutForContaining('docker port', '')
          ..respondToContaining(
            'ss -uln 2>/dev/null',
            const ExecOutput(
              stdout: 'OCI runtime exec failed: exec: "ss": not found',
              stderr: '',
              exitStatus: 126,
            ),
          )
          ..respondToContaining(
            '/proc/net/udp',
            const ExecOutput(
              stdout:
                  '  sl  local_address\n  0: 00000000:DE47 00000000:0000 07\n',
              stderr: '',
              exitStatus: 0,
            ),
          );

        final lines = await targetFor(docker, transport: t).udpListening();
        expect(lines, hasLength(1));
        expect(lines.single, isNot(contains('exec failed')));
        expect(lines.single, contains('DE47'));
      },
    );

    test('docker tier 4: /proc/net/udp when ss is missing', () async {
      final t = FakeTransport()
        ..stdoutForContaining('ss -ulnp', '')
        ..stdoutForContaining('docker port', '')
        ..respondToContaining(
          'ss -uln 2>/dev/null',
          const ExecOutput(stdout: '', stderr: 'not found', exitStatus: 127),
        )
        ..respondToContaining(
          '/proc/net/udp',
          const ExecOutput(
            stdout:
                '  sl  local_address rem_address\n  1: 00000000:0044 00000000:0000\n',
            stderr: '',
            exitStatus: 0,
          ),
        );

      final lines = await targetFor(docker, transport: t).udpListening();
      expect(lines, hasLength(1));
      expect(
        t.commands.last,
        "docker exec 'core-keeper' sh -c "
        "'cat /proc/net/udp /proc/net/udp6 2>/dev/null'",
      );
    });

    test('docker returns empty when every tier comes up dry', () async {
      final t = FakeTransport(
        defaultResponse: const ExecOutput(
          stdout: '',
          stderr: '',
          exitStatus: 1,
        ),
      );
      expect(await targetFor(docker, transport: t).udpListening(), isEmpty);
      expect(t.commands, hasLength(4));
    });
  });

  group('quoting', () {
    test('every interpolated value is single-quoted', () async {
      // A unit name containing a quote is absurd but survivable; a path containing a
      // space is routine and must be.
      const awkward = SystemdService(unit: "core'keeper");
      final t = FakeTransport();
      await targetFor(awkward, transport: t).serviceControl(ServiceAction.stop);
      expect(t.onlyCommand, r"systemctl stop 'core'\''keeper'");
    });

    test('the worlds path with spaces is quoted in stat', () async {
      final t = FakeTransport();
      await targetFor(systemd, transport: t).stat(worldsPath, '*.world.gzip');
      expect(t.onlyCommand, contains("'$worldsPath'"));
    });
  });
}
