import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/stats/data/stats_service.dart';

import '../../support/fake_target.dart';

FakeTarget targetWith({String worldsPath = '/home/steam/Core Keeper/worlds'}) =>
    FakeTarget(
      serviceKind: const SystemdService(unit: 'corekeeper'),
      worldsPath: worldsPath,
    );

void main() {
  group('collect', () {
    test('gathers every figure from a healthy host', () async {
      final t = targetWith()
        ..logTail = 'starting…\nGameID: ABCD-1234\n'
        ..udpLines = ['UNCONN 0 0 0.0.0.0:56967 users:(("CoreKeeperServe"))']
        ..activeSinceValue = 'Sun 2026-07-26 18:21:14 UTC'
        ..responses['cat /proc/meminfo 2>/dev/null'] = const ExecOutput(
          stdout: 'MemTotal:  8039424 kB\nMemAvailable: 6100992 kB\n',
          stderr: '',
          exitStatus: 0,
        )
        ..responses['cat /proc/uptime 2>/dev/null'] = const ExecOutput(
          stdout: '843512.42 1600000.00\n',
          stderr: '',
          exitStatus: 0,
        )
        ..responses['date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null'] =
            const ExecOutput(
              stdout: '2026-07-28T01:00:00Z\n',
              stderr: '',
              exitStatus: 0,
            );

      t.responses[t.commands.isEmpty ? '' : ''] = const ExecOutput.empty();
      t.responses["df -h --output=size,used,avail,pcent '/home/steam/Core Keeper/worlds' 2>/dev/null | tail -n 1"] =
          const ExecOutput(
            stdout: '  9.8G  4.1G  5.2G  44%\n',
            stderr: '',
            exitStatus: 0,
          );

      final stats = await StatsService(t).collect();

      expect(stats.gameId, 'ABCD-1234');
      expect(stats.memTotalKb, 8039424);
      expect(stats.memAvailableKb, 6100992);
      expect(stats.memUsedKb, 8039424 - 6100992);
      expect(stats.uptimeSeconds, 843512);
      expect(stats.serverTime, '2026-07-28T01:00:00Z');
      expect(stats.activeSince, 'Sun 2026-07-26 18:21:14 UTC');
      expect(stats.diskSize, '9.8G');
      expect(stats.diskUsed, '4.1G');
      expect(stats.diskUsePct, '44%');
      expect(stats.isListening, isTrue);
    });

    test('quotes the worlds path in the df command', () async {
      // The reference path contains spaces; unquoted, df would be handed three arguments.
      final t = targetWith();
      await StatsService(t).collect();
      expect(
        t.commands.any(
          (c) =>
              c.contains('df -h') &&
              c.contains("'/home/steam/Core Keeper/worlds'"),
        ),
        isTrue,
      );
    });

    test('fetches a wide log window for the game id', () async {
      // A short tail silently loses the id on a noisy Docker startup — the symptom is a
      // blank field rather than an error, which is why the window is deliberately wide.
      expect(StatsService.logTailLines, greaterThanOrEqualTo(200));
    });

    test(
      'one failing command blanks one figure, not the whole dashboard',
      () async {
        final t = targetWith()
          ..logTail = 'GameID: STILL-HERE\n'
          ..failures['cat /proc/meminfo 2>/dev/null'] = Exception(
            'no /proc here',
          );

        final stats = await StatsService(t).collect();

        expect(stats.memTotalKb, isNull);
        // Everything else still arrived.
        expect(stats.gameId, 'STILL-HERE');
      },
    );

    test('survives a target whose log tail throws', () async {
      final t = FakeTarget(
        serviceKind: const ProcessService(stopCmd: 's', startCmd: 'r'),
      );
      // A process target with no log path has nothing to tail.
      final stats = await StatsService(t).collect();
      expect(stats.recentLogTail, '');
      expect(stats.gameId, isNull);
    });

    test('reports the raw service status verbatim for display', () async {
      final t = targetWith();
      t.responses['x'] = const ExecOutput.empty();
      final stats = await StatsService(t).collect();
      // FakeTarget's serviceControl returns an empty output; the point is that whatever
      // the service manager said is passed through untouched rather than normalised.
      expect(stats.serviceStatus, '');
    });

    test('a missing game id is null, not an empty string', () async {
      final t = targetWith()..logTail = 'nothing interesting here\n';
      expect((await StatsService(t).collect()).gameId, isNull);
    });

    test('takes the newest game id when the tail spans a restart', () async {
      final t = targetWith()
        ..logTail = 'GameID: OLD-0000\nrestarting\nGameID: NEW-1111\n';
      expect((await StatsService(t).collect()).gameId, 'NEW-1111');
    });
  });

  group('ServerStats', () {
    test('memUsedKb is null unless both figures are known', () async {
      final t = targetWith();
      final stats = await StatsService(t).collect();
      expect(stats.memTotalKb, isNull);
      expect(stats.memUsedKb, isNull);
    });

    test('isListening reflects the udp lines', () async {
      final t = targetWith()..udpLines = const [];
      expect((await StatsService(t).collect()).isListening, isFalse);
    });
  });
}
