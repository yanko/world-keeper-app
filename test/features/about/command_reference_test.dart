import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/ssh/ssh_target.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/about/domain/command_reference.dart';

import '../../support/fake_transport.dart';
import '../../support/l10n.dart';

/// The reference exists to answer "what will this app run on my box" *before* it runs.
/// A wrong answer is worse than no answer, so the parts that can be checked mechanically
/// are — including, at the bottom, that the strings still match what `SshTarget` builds.
void main() {
  // The English table: the assertions below are on the source copy, so a French
  // mistranslation shows up as a translation bug rather than as this file failing.
  final l10n = l10nFor();

  const systemd = SystemdService(unit: 'corekeeper.service');
  const docker = DockerService(container: 'core-keeper');
  const process = ProcessService(
    startCmd: '/opt/ck/_launch.sh &',
    stopCmd: 'pkill -f CoreKeeperServer',
    logPath: '/opt/ck/server.log',
  );

  List<String> commandsIn(List<CommandRefGroup> groups) => [
    for (final g in groups)
      for (final e in g.entries) e.command,
  ];

  group('disconnected', () {
    final groups = buildCommandReference(l10n);

    test('still lists every group — the dialog works before connecting', () {
      expect(groups.map((g) => g.group), [
        'Discovery',
        'Listing files',
        'Server stats',
        'Push a world',
        'Pull a world',
        'Restore from a backup (World Library)',
        'Terminal',
        'One-time setup',
      ]);
    });

    test('shows placeholders where nothing is known yet', () {
      final all = commandsIn(groups).join('\n');
      expect(all, contains('<worlds_path>'));
      expect(all, contains('<unit>'));
      expect(all, contains('<container>'));
    });

    test('shows all three service kinds, since none has been ruled out', () {
      final kinds = {
        for (final g in groups)
          for (final e in g.entries)
            if (e.targetKind != null) e.targetKind!,
      };
      expect(kinds, {
        TargetKind.systemd,
        TargetKind.docker,
        TargetKind.process,
      });
    });
  });

  group('filtered to the discovered kind', () {
    test('systemd hides Docker and bare-process variants', () {
      final groups = buildCommandReference(
        l10n,
        const KnownValues(serviceKind: systemd),
      );
      final kinds = {
        for (final g in groups)
          for (final e in g.entries)
            if (e.targetKind != null) e.targetKind!,
      };
      expect(kinds, {TargetKind.systemd});

      final all = commandsIn(groups).join('\n');
      expect(all, isNot(contains('docker ')));
      expect(all, isNot(contains('pgrep')));
    });

    test('docker hides the rest', () {
      final groups = buildCommandReference(
        l10n,
        const KnownValues(serviceKind: docker),
      );
      final all = commandsIn(groups).join('\n');
      expect(all, contains('docker stop'));
      expect(all, isNot(contains('systemctl stop')));
    });

    test('kind-independent entries survive every filter', () {
      // `df -h` and `cat /proc/meminfo` run the same way everywhere; filtering them out
      // with the variants would leave the reference incomplete.
      for (final kind in [systemd, docker, process]) {
        final all = commandsIn(
          buildCommandReference(l10n, KnownValues(serviceKind: kind)),
        ).join('\n');
        expect(all, contains('cat /proc/meminfo'), reason: '$kind');
        expect(all, contains('df -h'), reason: '$kind');
      }
    });
  });

  group('substitution', () {
    test('quotes discovered values so a line can be pasted into a terminal', () {
      // The reference worlds path really does contain a space.
      final groups = buildCommandReference(
        l10n,
        const KnownValues(
          worldsPath: '/home/steam/Core Keeper/worlds',
          serviceKind: systemd,
        ),
      );
      final all = commandsIn(groups).join('\n');

      expect(all, contains("'/home/steam/Core Keeper/worlds'"));
      expect(all, isNot(contains('<worlds_path>')));
      // Unquoted, `find /home/steam/Core Keeper/worlds` searches three wrong paths.
      expect(all, isNot(contains('find /home/steam/Core Keeper')));
    });

    test('leaves placeholders unquoted — they are not runnable either way', () {
      final all = commandsIn(buildCommandReference(l10n)).join('\n');
      expect(all, isNot(contains("'<worlds_path>'")));
    });

    test("a bare process's captured commands are shown verbatim", () {
      // They are shell commands in their own right, not values interpolated into one, so
      // quoting them would misrepresent what gets sent.
      final all = commandsIn(
        buildCommandReference(l10n, const KnownValues(serviceKind: process)),
      ).join('\n');

      expect(all, contains('pkill -f CoreKeeperServer'));
      expect(all, isNot(contains("'pkill -f CoreKeeperServer'")));
    });

    test('substitutes the steam user into the chown', () {
      final all = commandsIn(
        buildCommandReference(
          l10n,
          const KnownValues(serviceKind: systemd, steamUser: 'steam'),
        ),
      ).join('\n');
      expect(all, contains("chown -R 'steam':'steam'"));
    });

    test('a process target with no log path still renders', () {
      final all = commandsIn(
        buildCommandReference(
          l10n,
          const KnownValues(
            serviceKind: ProcessService(startCmd: 'run.sh', stopCmd: 'stop.sh'),
          ),
        ),
      ).join('\n');
      expect(all, contains('tail -n <lines> <log_path>'));
    });
  });

  group('notes', () {
    test('steps that are not shell commands are marked as notes', () {
      final groups = buildCommandReference(l10n);
      final notes = [
        for (final g in groups)
          for (final e in g.entries)
            if (e.isNote) e.command,
      ];
      // Transfers, local packaging and the PTY. Rendering these as if they were runnable
      // would be the one actively misleading thing this dialog could do.
      expect(notes.where((n) => n.contains('SFTP')), hasLength(2));
      expect(notes.any((n) => n.contains('local file I/O only')), isTrue);
      expect(notes.any((n) => n.contains('real PTY')), isTrue);
    });
  });

  group('copy all', () {
    final text = commandReferenceAsText(
      buildCommandReference(l10n, const KnownValues(serviceKind: systemd)),
    );

    test('carries the group headings and every command', () {
      expect(text, contains('## Discovery'));
      expect(text, contains('## Push a world'));
      expect(text, contains("systemctl is-active 'corekeeper.service'"));
    });

    test('labels which service kind a variant belongs to', () {
      expect(text, contains('[systemd]'));
    });

    test('kind-independent entries carry no label', () {
      expect(text, contains('# Memory usage\ncat /proc/meminfo'));
    });
  });

  // ---- the part that keeps this honest ------------------------------------------------

  group('still matches what SshTarget actually sends', () {
    /// Runs the real target methods against a recording transport and asserts every
    /// command it produced appears verbatim in the reference.
    ///
    /// Without this, the reference is a comment: it would keep claiming whatever it said
    /// on the day it was written while `ssh_target.dart` moved on underneath it, and a
    /// user reading it before approving a destructive operation would be misled by
    /// something that looks authoritative.
    Future<void> checkKind(
      ServiceKind kind, {
      required String worldsPath,
    }) async {
      final transport = FakeTransport();
      final target = SshTarget(
        transport: transport,
        serviceKind: kind,
        worldsPath: worldsPath,
        steamUser: 'steam',
      );

      await target.status();
      await target.activeSince();
      await target.serviceControl(ServiceAction.stop);
      await target.serviceControl(ServiceAction.start);
      await target.fixPerms(worldsPath);

      final reference = commandsIn(
        buildCommandReference(
          l10n,
          KnownValues(
            worldsPath: worldsPath,
            serviceKind: kind,
            steamUser: 'steam',
          ),
        ),
      ).join('\n');

      for (final sent in transport.commands) {
        expect(
          reference,
          contains(sent),
          reason:
              'SshTarget sends "$sent" but the command reference does not list it',
        );
      }
    }

    test('systemd', () async {
      await checkKind(systemd, worldsPath: '/home/steam/Core Keeper/worlds');
    });

    test('docker', () async {
      await checkKind(docker, worldsPath: '/worlds');
    });

    test('bare process', () async {
      await checkKind(process, worldsPath: '/worlds');
    });

    test('the stats commands match too', () async {
      final transport = FakeTransport();
      final target = SshTarget(
        transport: transport,
        serviceKind: systemd,
        worldsPath: '/worlds',
      );

      await target.stat('/worlds', '*.world.gzip');
      await target.udpListening();

      final reference = commandsIn(
        buildCommandReference(
          l10n,
          const KnownValues(worldsPath: '/worlds', serviceKind: systemd),
        ),
      ).join('\n');

      // `stat` renders with <dir>/<glob> placeholders in the Listing files group, so it is
      // matched on its distinctive shape rather than verbatim.
      expect(reference, contains(r"-printf '%s %T@ %p\n'"));
      expect(reference, contains("-exec stat -c '%s %Y %n' {} +"));
      expect(reference, contains('ss -ulnp 2>/dev/null | grep -i corekeeper'));
    });
  });
}
