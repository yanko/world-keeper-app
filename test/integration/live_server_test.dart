@Tags(['live'])
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/config_repository.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/ssh/host_key_store.dart';
import 'package:world_keeper/core/ssh/ssh_session.dart';
import 'package:world_keeper/core/ssh/ssh_target.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/features/discovery/data/discovery_probe.dart';
import 'package:world_keeper/features/stats/data/stats_service.dart';
import 'package:world_keeper/features/terminal/data/terminal_session.dart';

import '../support/fake_transport.dart';

/// Phase 2's live exit criteria, against a **real server**.
///
/// Opt-in and off by default — it is tagged `live` and additionally requires an
/// environment variable naming which stored profile to use, so it can never fire by
/// accident from `flutter test` or CI and reach into somebody's homelab.
///
/// ```bash
/// # read-only: connect, exec, discover paths, list world files
/// WK_LIVE_PROFILE="lxc-core-keeper" flutter test --tags live test/integration/live_server_test.dart
///
/// # additionally round-trip a temp file through SFTP with a checksum check
/// WK_LIVE_PROFILE="lxc-core-keeper" WK_LIVE_WRITE=1 flutter test --tags live test/integration/live_server_test.dart
/// ```
///
/// The default set is strictly read-only: `uname`, `systemctl is-active`, directory
/// listings. Nothing is stopped, started, or overwritten. The write test is gated behind
/// its own flag and confines itself to a uniquely-named file under `/tmp`, which it
/// removes afterwards.
void main() {
  final profileName = Platform.environment['WK_LIVE_PROFILE'];
  final allowWrites = Platform.environment['WK_LIVE_WRITE'] == '1';

  if (profileName == null || profileName.isEmpty) {
    test('live server tests are opt-in', () {
      markTestSkipped(
        'set WK_LIVE_PROFILE=<profile name> to run these against a real server',
      );
    });
    return;
  }

  late AppPaths paths;
  late Profile profile;
  late SshSession session;

  setUpAll(() async {
    paths = await AppPaths.resolve();
    final config = await ConfigRepository(paths).load();

    final match = config.profiles.where((p) => p.name == profileName);
    if (match.isEmpty) {
      throw StateError(
        'no profile named "$profileName" in ${paths.configFile.path}. '
        'Available: ${config.profiles.map((p) => p.name).join(', ')}',
      );
    }
    profile = match.first;

    // Uses the shared known_hosts file, so a first run pins and later runs verify — the
    // same TOFU path the app itself takes.
    final store = HostKeyStore(
      File('${paths.dataDir.path}${Platform.pathSeparator}known_hosts.json'),
    );

    Future<bool> verify({
      required String host,
      required int port,
      required String type,
      required String fingerprint,
    }) async {
      final verdict = await store.verify(
        host: host,
        port: port,
        fingerprint: fingerprint,
      );
      switch (verdict) {
        case HostKeyVerdict.match:
          return true;
        case HostKeyVerdict.unknown:
          // ignore: avoid_print
          print('pinning host key for $host:$port — $type $fingerprint');
          await store.pin(
            host: host,
            port: port,
            type: type,
            fingerprint: fingerprint,
          );
          return true;
        case HostKeyVerdict.mismatch:
          return false;
      }
    }

    switch (profile.auth) {
      case AuthMethod.key:
        final keyPath = profile.keyPath;
        if (keyPath == null) {
          throw StateError(
            'profile "$profileName" is key auth but has no keyPath',
          );
        }
        session = await SshSession.connectKey(
          host: profile.host,
          port: profile.port,
          username: profile.user,
          privateKeyFile: File(keyPath),
          verifyHostKey: verify,
        );
      case AuthMethod.password:
        final password = Platform.environment['WK_LIVE_PASSWORD'];
        if (password == null || password.isEmpty) {
          throw StateError(
            'profile "$profileName" uses password auth — set WK_LIVE_PASSWORD',
          );
        }
        session = await SshSession.connectPassword(
          host: profile.host,
          port: profile.port,
          username: profile.user,
          password: password,
          verifyHostKey: verify,
        );
    }
    // ignore: avoid_print
    print('connected to ${profile.user}@${profile.host}:${profile.port}');
  });

  tearDownAll(() async => session.close());

  test('exec returns stdout, stderr and an exit status', () async {
    final uname = await session.exec('uname -a');
    expect(uname.success, isTrue);
    expect(uname.stdout, isNotEmpty);
    // ignore: avoid_print
    print('uname: ${uname.trimmedStdout}');

    // A deliberate failure, to prove exit codes and stderr are actually captured rather
    // than assumed.
    final missing = await session.exec('cat /definitely/not/here');
    expect(missing.success, isFalse);
    expect(missing.exitStatus, isNot(0));
    expect(missing.stderr, isNotEmpty);
  });

  test('exec records to the audit sink', () async {
    final sink = RecordingAuditSink();
    session.audit = sink;
    try {
      await session.exec('echo audited');
      // Audit is fire-and-forget so it never delays or fails the command it records.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(sink.commands, isNotEmpty);
      expect(sink.commands.last.command, 'echo audited');
      expect(sink.commands.last.exitCode, 0);
      expect(sink.commands.last.durationMs, greaterThanOrEqualTo(0));
    } finally {
      session.audit = null;
    }
  });

  test('shell quoting survives a path with spaces', () async {
    final out = await session.exec("echo 'Core Keeper/DedicatedServer'");
    expect(out.trimmedStdout, 'Core Keeper/DedicatedServer');
  });

  test('the target reports a real status and log tail', () async {
    final discovered = profile.discovered;
    final kind = discovered?.serviceKind;
    if (kind == null) {
      markTestSkipped('profile "$profileName" has no cached discovery');
      return;
    }

    final target = SshTarget(
      transport: session,
      serviceKind: kind,
      worldsPath: discovered?.worldsPath ?? '/',
      steamUser: discovered?.steamUser,
    );

    final status = await target.status();
    // ignore: avoid_print
    print('${kind.label} -> $status');
    expect(status, isNot(RunState.unknown));

    final logs = await target.logsTail(20);
    // ignore: avoid_print
    print('log tail: ${logs.split('\n').length} line(s)');

    final since = await target.activeSince();
    // ignore: avoid_print
    print('active since: $since');

    final udp = await target.udpListening();
    // ignore: avoid_print
    print('udp listeners: ${udp.length}');
  });

  test('stat lists the real world files', () async {
    final worldsPath = profile.discovered?.worldsPath;
    if (worldsPath == null) {
      markTestSkipped('profile "$profileName" has no discovered worlds path');
      return;
    }

    final target = SshTarget(
      transport: session,
      serviceKind: profile.discovered!.serviceKind!,
      worldsPath: worldsPath,
    );

    final worlds = await target.stat(worldsPath, '*.world.gzip');
    for (final w in worlds) {
      // ignore: avoid_print
      print('  ${w.name}  ${w.size} bytes  mtime=${w.modified}');
    }
    // Proves the `find -printf` strategy (or its POSIX fallback) works on this host and
    // that paths containing spaces survive parsing.
    expect(worlds.every((w) => w.path.startsWith(worldsPath)), isTrue);
    expect(worlds.every((w) => w.size > 0), isTrue);
  });

  test('SFTP round-trips a file with a matching checksum', () async {
    if (!allowWrites) {
      markTestSkipped('set WK_LIVE_WRITE=1 to allow writing a temp file');
      return;
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final remotePath = '/tmp/world-keeper-selftest-$stamp.bin';
    final tempDir = await Directory.systemTemp.createTemp('wk_live');
    final source = File('${tempDir.path}${Platform.pathSeparator}upload.bin');
    final roundTrip = File(
      '${tempDir.path}${Platform.pathSeparator}download.bin',
    );

    // Non-trivial size so chunking and progress reporting are actually exercised.
    final payload = List<int>.generate(512 * 1024, (i) => (i * 31) % 256);
    await source.writeAsBytes(payload);
    final localDigest = sha256.convert(payload).toString();

    try {
      var lastSent = 0;
      final sent = await session.pushFile(
        source,
        remotePath,
        onProgress: (s, t) => lastSent = s,
      );
      expect(sent, payload.length);
      expect(lastSent, greaterThan(0));

      // The same verification the push envelope performs after uploading a world.
      final remote = await session.exec('sha256sum ${_shq(remotePath)}');
      expect(remote.success, isTrue);
      final remoteDigest = remote.stdout.trim().split(RegExp(r'\s+')).first;
      expect(
        remoteDigest,
        localDigest,
        reason: 'remote checksum must match the local file',
      );

      final received = await session.pullFile(remotePath, roundTrip);
      expect(received, payload.length);
      expect(
        sha256.convert(await roundTrip.readAsBytes()).toString(),
        localDigest,
      );
    } finally {
      // Always clean up after ourselves, even on failure.
      await session.exec('rm -f ${_shq(remotePath)}');
      await tempDir.delete(recursive: true);
    }
  });

  test('the discovery probe identifies this host correctly', () async {
    final result = await DiscoveryProbe(session).probe();

    // ignore: avoid_print
    print('os:          ${result.os}');
    // ignore: avoid_print
    print('service:     ${result.serviceKind?.label ?? "(ambiguous)"}');
    // ignore: avoid_print
    print(
      'candidates:  ${result.serviceKindCandidates.map((c) => c.kind.label).toList()}',
    );
    // ignore: avoid_print
    print('worldsPath:  ${result.worldsPath ?? result.worldsPathCandidates}');
    // ignore: avoid_print
    print('steamUser:   ${result.steamUser}');
    // ignore: avoid_print
    print('launch:      ${result.launchScript}');

    expect(result.os, isNotNull);
    expect(
      result.serviceKind ?? result.serviceKindCandidates.firstOrNull?.kind,
      isNotNull,
      reason: 'the probe should find or offer a service on a real host',
    );

    // The probe result should agree with what the Rust app already discovered and
    // cached in the shared config — the strongest available check that the port is
    // faithful, since that value was produced by a completely different implementation.
    final cached = profile.discovered;
    if (cached?.serviceKind != null && result.serviceKind != null) {
      expect(
        result.serviceKind,
        cached!.serviceKind,
        reason: 'probe disagrees with the cached discovery from the Rust app',
      );
    }
    if (cached?.worldsPath != null && result.worldsPath != null) {
      expect(result.worldsPath, cached!.worldsPath);
    }
  });

  test('stats collect a full dashboard from the live host', () async {
    final discovered = profile.discovered;
    if (discovered?.serviceKind == null) {
      markTestSkipped('profile "$profileName" has no cached discovery');
      return;
    }

    final target = SshTarget(
      transport: session,
      serviceKind: discovered!.serviceKind!,
      worldsPath: discovered.worldsPath ?? '/',
      steamUser: discovered.steamUser,
    );

    final stats = await StatsService(target).collect();

    // ignore: avoid_print
    print('status:   ${stats.serviceStatus}');
    // ignore: avoid_print
    print('since:    ${stats.activeSince}');
    // ignore: avoid_print
    print('clock:    ${stats.serverTime}');
    // ignore: avoid_print
    print('mem:      ${stats.memUsedKb} / ${stats.memTotalKb} kB');
    // ignore: avoid_print
    print(
      'disk:     ${stats.diskUsed} / ${stats.diskSize} (${stats.diskUsePct})',
    );
    // ignore: avoid_print
    print('uptime:   ${stats.uptimeSeconds}s');
    // ignore: avoid_print
    print('gameId:   ${stats.gameId}');
    // ignore: avoid_print
    print('udp:      ${stats.udpListening.length} listener(s)');

    expect(stats.serviceStatus, isNotEmpty);
    expect(
      stats.memTotalKb,
      isNotNull,
      reason: '/proc/meminfo should be readable',
    );
    expect(stats.memTotalKb, greaterThan(0));
    expect(stats.uptimeSeconds, isNotNull);
    expect(stats.uptimeSeconds, greaterThan(0));
    expect(stats.serverTime, isNotNull);
    // df is run against the discovered worlds path, which contains spaces on the
    // reference host — an unquoted command would silently return nothing here.
    expect(
      stats.diskSize,
      isNotNull,
      reason: 'df should resolve the worlds path',
    );
  });

  test('an interactive PTY shell works end to end', () async {
    // Distinct from every other SSH call here: a standing bidirectional stream on its own
    // channel, not a request/response `exec`.
    final shell = await TerminalSession.open(session, columns: 100, rows: 30);
    try {
      // Wait for the shell prompt to arrive before typing into it.
      await _waitFor(() => shell.terminal.buffer.lines.length > 1);

      shell.terminal.textInput('echo world-keeper-pty-ok\r');
      await _waitFor(() => _screen(shell).contains('world-keeper-pty-ok'));

      // A resize must reach the far side, or full-screen programs redraw wrongly.
      shell.terminal.resize(120, 40);
      shell.terminal.textInput('tput cols\r');
      await _waitFor(() => _screen(shell).contains('120'));

      // ignore: avoid_print
      print('pty: prompt, command echo and resize all round-tripped');
      expect(_screen(shell), contains('world-keeper-pty-ok'));
      expect(shell.isClosed, isFalse);
    } finally {
      await shell.close();
    }
    expect(shell.isClosed, isTrue);
  });

  test('the shell runs concurrently with ordinary exec traffic', () async {
    // The terminal must keep working *during* stats polling and a running push — that is
    // the whole reason for channel multiplexing.
    final shell = await TerminalSession.open(session);
    try {
      await _waitFor(() => shell.terminal.buffer.lines.length > 1);

      final results = await Future.wait([
        session.exec('echo exec-one'),
        session.exec('echo exec-two'),
      ]);
      shell.terminal.textInput('echo shell-alive\r');
      await _waitFor(() => _screen(shell).contains('shell-alive'));

      expect(results.map((r) => r.trimmedStdout), ['exec-one', 'exec-two']);
      expect(shell.isClosed, isFalse);
    } finally {
      await shell.close();
    }
  });

  test('a second channel works concurrently with the first', () async {
    // The multiplexing guarantee the whole design leans on: stats polling and the
    // terminal have to keep working *during* a long push.
    final results = await Future.wait([
      session.exec('sleep 1; echo first'),
      session.exec('echo second'),
      session.exec('echo third'),
    ]);
    expect(results.map((r) => r.trimmedStdout), ['first', 'second', 'third']);
    expect(results.every((r) => r.success), isTrue);
  });
}

String _shq(String s) => "'${s.replaceAll("'", r"'\''")}'";

/// Everything currently on the terminal screen, as plain text.
///
/// The buffer is a circular structure rather than a list, so it is walked by index.
String _screen(TerminalSession shell) {
  final buffer = StringBuffer();
  final lines = shell.terminal.buffer.lines;
  for (var i = 0; i < lines.length; i++) {
    buffer.writeln(lines[i].getText());
  }
  return buffer.toString();
}

/// Polls until [condition] holds, because a shell answers whenever it feels like it.
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('timed out waiting for the shell to respond');
}
