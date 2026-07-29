import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/features/discovery/data/discovery_probe.dart';
import 'package:world_keeper/features/discovery/domain/discovery_result.dart';
import 'package:world_keeper/features/discovery/presentation/discovery_screen.dart';

import '../../support/fake_transport.dart';

/// The probe has to show its work.
///
/// "Worlds path — none found" is a true statement that tells nobody anything: it does not
/// say where it looked, whether `find` ran, or whether the host answered. Those are three
/// different problems, and the app used to make them indistinguishable — the only way to
/// tell them apart was to open an SSH session, which is the thing this screen exists to
/// spare you.
void main() {
  group('the trace records every command', () {
    test('one entry per remote call, in order', () async {
      final transport = FakeTransport();
      final result = await DiscoveryProbe(transport).probe();

      expect(
        result.trace.map((s) => s.command),
        transport.commands,
        reason: 'the transcript must be the commands actually sent, in order',
      );
      expect(result.trace, isNotEmpty);
    });

    test('a probe that finds nothing still explains itself', () async {
      // The exact case from the LXC: everything runs, nothing matches. The screen has to
      // be able to say "here is where I looked" rather than only "none found".
      final result = await DiscoveryProbe(FakeTransport()).probe();

      expect(result.worldsPath, isNull);
      expect(
        result.trace.any((s) => s.command.contains('find')),
        isTrue,
        reason: 'it searched, and the transcript should prove it',
      );
    });

    test('output and exit status are kept, not just the command', () async {
      final transport = FakeTransport();
      transport.stdoutFor(
        'cat /etc/os-release 2>/dev/null',
        'PRETTY_NAME="Debian GNU/Linux 13 (trixie)"\n',
      );

      final result = await DiscoveryProbe(transport).probe();
      final step = result.trace.firstWhere(
        (s) => s.command.startsWith('cat /etc/os-release'),
      );

      expect(step.stdout, contains('trixie'));
      expect(step.exitStatus, 0);
      expect(step.succeeded, isTrue);
    });

    test('a fresh run does not inherit the previous run’s transcript', () async {
      // The screen re-probes on Re-scan, and a transcript that accumulated across runs
      // would show commands that have nothing to do with the result on screen.
      final probe = DiscoveryProbe(FakeTransport());

      final first = await probe.probe();
      final second = await probe.probe();

      expect(second.trace, hasLength(first.trace.length));
    });
  });

  group('a step distinguishes the three outcomes', () {
    ProbeStep step({int exit = 0, String stdout = '', String stderr = ''}) =>
        ProbeStep(
          command: 'find /home -name x',
          exitStatus: exit,
          stdout: stdout,
          stderr: stderr,
          duration: Duration.zero,
        );

    test('ran and found something', () {
      final s = step(stdout: '/home/steam/worlds\n');
      expect(s.succeeded, isTrue);
      expect(s.foundNothing, isFalse);
    });

    test('ran and found nothing — a correct answer', () {
      final s = step();
      expect(s.succeeded, isTrue);
      expect(s.foundNothing, isTrue);
    });

    test('could not run — a broken probe, not an answer', () {
      // These two must never look alike. One means "there is nothing there"; the other
      // means "I could not look", and only the second is the app's fault.
      final s = step(exit: 127, stderr: 'find: not found');
      expect(s.succeeded, isFalse);
      expect(s.foundNothing, isFalse);
    });
  });

  group('preview', () {
    test('caps long output so a find / cannot lock up the list', () {
      final step = ProbeStep(
        command: 'find / -name worlds',
        exitStatus: 0,
        stdout: List.generate(500, (i) => '/path/$i').join('\n'),
        stderr: '',
        duration: Duration.zero,
      );

      final preview = step.preview(maxLines: 10);
      expect('\n'.allMatches(preview).length, 10);
      expect(preview, contains('490 more lines'));
    });

    test('surfaces stderr, which is where a failure explains itself', () {
      const step = ProbeStep(
        command: 'find /nope',
        exitStatus: 1,
        stdout: '',
        stderr: "find: '/nope': No such file or directory",
        duration: Duration.zero,
      );

      expect(step.preview(), contains('No such file or directory'));
    });
  });

  group('transcriptAsText', () {
    test('is a paste-able session, uncapped', () {
      // The on-screen version truncates; this one must not, because the reason to copy it
      // is to send somebody the part that was cut off.
      final trace = [
        ProbeStep(
          command: 'pgrep -af _launch.sh',
          exitStatus: 0,
          stdout: List.generate(200, (i) => 'line $i').join('\n'),
          stderr: '',
          duration: const Duration(milliseconds: 12),
        ),
      ];

      final text = transcriptAsText(trace);

      expect(text, contains(r'$ pgrep -af _launch.sh'));
      expect(text, contains('exit 0 (12 ms)'));
      expect(text, contains('line 199'), reason: 'nothing may be dropped');
    });

    test('marks stderr as stderr', () {
      final text = transcriptAsText([
        const ProbeStep(
          command: 'find /root',
          exitStatus: 1,
          stdout: '',
          stderr: 'Permission denied',
          duration: Duration.zero,
        ),
      ]);

      expect(text, contains('stderr: Permission denied'));
    });
  });

  test('the transcript is not the audit log', () async {
    // Both record commands, and they answer different questions. The audit log is the
    // record of what the app did to a server, kept for reading afterwards; the trace is a
    // working note about the screen in front of you, discarded with the result. Keeping
    // them separate is why the trace can hold full `find` output without bloating a
    // database that is meant to be exported.
    final result = await DiscoveryProbe(FakeTransport()).probe();

    expect(result.trace.first, isA<ProbeStep>());
    expect(result.trace.first.duration, isA<Duration>());
  });

  test('a failing command is recorded rather than swallowed', () async {
    final transport = FakeTransport(
      defaultResponse: const ExecOutput(
        stdout: '',
        stderr: 'sh: find: not found',
        exitStatus: 127,
      ),
    );

    final result = await DiscoveryProbe(transport).probe();

    // `pgrep` and `docker` are marked `nonZeroIsNormal` — exiting non-zero is how they
    // say "nothing matched" and "not installed", which are answers. Everything else
    // failing is a fault and has to read as one.
    expect(result.trace.any((s) => !s.succeeded), isTrue);
    expect(
      result.trace.any((s) => s.stderr.contains('not found')),
      isTrue,
      reason:
          'a host where the probe cannot run must say so, not report "none found"',
    );
  });
}
