@Tags(['live'])
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/config_repository.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/ssh/host_key_store.dart';
import 'package:world_keeper/core/ssh/shell_quote.dart';
import 'package:world_keeper/core/ssh/ssh_session.dart';
import 'package:world_keeper/core/ssh/ssh_target.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/parsers.dart';
import 'package:world_keeper/features/operations/data/pull_envelope.dart';
import 'package:world_keeper/features/operations/data/push_envelope.dart';
import 'package:world_keeper/features/operations/data/restore_envelope.dart';
import 'package:world_keeper/features/operations/domain/local_world.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

/// Phase 5's exit criteria, against a **real, running game server**.
///
/// This is the only test in the suite that stops a live service and overwrites a world.
/// It is therefore gated twice over — the `live` tag, a named profile, *and* an explicit
/// `WK_LIVE_DESTRUCTIVE=1` — so it can never be reached by `flutter test`, by CI, or even
/// by someone running the ordinary live suite.
///
/// ```bash
/// WK_LIVE_PROFILE="lxc-core-keeper" WK_LIVE_DESTRUCTIVE=1 \
///   flutter test --tags live test/integration/live_destructive_test.dart
/// ```
///
/// Ordered least-dangerous first:
///
/// 1. **Pull** — reads a world out. The only server-side effect is a brief stop.
/// 2. **Push it straight back** — exercises the whole envelope where the worst realistic
///    outcome is restoring the bytes that were already there.
/// 3. **Induce a failure after the point of no return** — a restore that stops the
///    server, takes its safety backup, then fails at the copy step, forcing a genuine
///    rollback and restart.
///
/// ## The world file changes when the server stops — that is not corruption
///
/// A first version of this test asserted the live world stayed byte-identical throughout.
/// It failed, and the app was right: **Core Keeper flushes a save on shutdown**, so the
/// file legitimately differs before and after any stop. Byte-equality across a stop is
/// not an invariant and asserting it would be asserting that the game does not save.
///
/// The real invariants, which this now checks instead:
///
/// * a pull brings down exactly what was on disk at that moment;
/// * a push puts exactly the bytes it uploaded in place, proven by the envelope's own
///   `sha256sum` comparison — completing at all *is* that proof;
/// * after a rollback the live world equals **the safety backup that operation made**,
///   which is precisely what rollback promises;
/// * the same world is still loaded, evidenced by an unchanged game id.
void main() {
  final profileName = Platform.environment['WK_LIVE_PROFILE'];
  final destructiveAllowed = Platform.environment['WK_LIVE_DESTRUCTIVE'] == '1';

  if (profileName == null || profileName.isEmpty || !destructiveAllowed) {
    test('destructive live tests are double-gated', () {
      markTestSkipped(
        'set WK_LIVE_PROFILE=<name> and WK_LIVE_DESTRUCTIVE=1 to run these — '
        'they stop a real server and overwrite a real world',
      );
    });
    return;
  }

  late Profile profile;
  late SshSession session;
  late SshTarget target;
  late AuditDatabase audit;
  late int sessionId;
  late Directory workDir;

  /// Identifies the world itself, independent of save-to-save byte changes. If this is
  /// still the same at the end, the same world is still loaded.
  String? originalGameId;

  /// The digest of the copy pulled in step 1, which step 2 pushes back.
  String? pulledDigest;

  int slot = 0;

  Future<String> remoteDigest(String path) async {
    final out = await session.exec('sha256sum ${shq(path)}');
    return out.stdout.trim().split(RegExp(r'\s+')).first;
  }

  String worldPath() => '${target.worldsPath}/$slot.world.gzip';

  setUpAll(() async {
    final paths = await AppPaths.resolve();
    final config = await ConfigRepository(paths).load();
    profile = config.profiles.firstWhere(
      (p) => p.name == profileName,
      orElse: () => throw StateError('no profile named "$profileName"'),
    );

    final store = HostKeyStore(
      File(p.join(paths.dataDir.path, 'known_hosts.json')),
    );

    session = await SshSession.connectKey(
      host: profile.host,
      port: profile.port,
      username: profile.user,
      privateKeyFile: File(profile.keyPath!),
      verifyHostKey:
          ({
            required host,
            required port,
            required type,
            required fingerprint,
          }) async =>
              await store.verify(
                host: host,
                port: port,
                fingerprint: fingerprint,
              ) ==
              HostKeyVerdict.match,
    );

    final discovered = profile.discovered!;
    target = SshTarget(
      transport: session,
      serviceKind: discovered.serviceKind!,
      worldsPath: discovered.worldsPath!,
      steamUser: discovered.steamUser,
    );

    audit = AuditDatabaseFactory.inMemory();
    sessionId = await audit.startSession('live-destructive');
    workDir = await Directory.systemTemp.createTemp('wk_live_destructive_');

    // ignore: avoid_print
    print('connected to ${profile.user}@${profile.host}');
    // ignore: avoid_print
    print('worlds: ${target.worldsPath}');
  });

  tearDownAll(() async {
    await audit.close();
    await session.close();
    if (workDir.existsSync()) await workDir.delete(recursive: true);
  });

  test(
    '0 — records the starting state',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      final worlds = await PullEnvelope(
        target: target,
        audit: audit,
        sessionId: sessionId,
      ).listRemoteWorlds();
      expect(worlds, isNotEmpty, reason: 'nothing to work with');
      slot = worlds.first.slot;

      originalGameId = findGameId(await target.logsTail(200));
      final status = await target.status();

      // ignore: avoid_print
      print(
        'slot $slot, service $status, game id $originalGameId, '
        'sha256 ${await remoteDigest(worldPath())}',
      );
      expect(status, RunState.running, reason: 'start from a healthy server');
      expect(
        originalGameId,
        isNotNull,
        reason: 'need a game id to compare against',
      );
    },
  );

  test(
    '1 — pull reads the world out and restarts the server',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      final states = <PullState>[];
      final pulled = await PullEnvelope(
        target: target,
        audit: audit,
        sessionId: sessionId,
      ).run(slot, onProgress: (p) => states.add(p.state));

      // ignore: avoid_print
      print('pull states: ${states.map((s) => s.name).join(' → ')}');
      // ignore: avoid_print
      print('pulled ${pulled.bytes} bytes to ${pulled.tempDir}');

      expect(states.last, PullState.done);
      expect(pulled.bytes, greaterThan(0));

      // What came down must match what is on disk *now* — read straight after, while the
      // freshly-restarted server has loaded the world but not yet saved over it.
      pulledDigest = (await sha256.bind(File(pulled.mainPath).openRead()).first)
          .toString();
      // ignore: avoid_print
      print('pulled sha256: $pulledDigest');
      expect(
        await remoteDigest(worldPath()),
        pulledDigest,
        reason: 'the downloaded world must match what is on the server',
      );

      // Keep this copy — it is what step 2 pushes back.
      await File(
        pulled.mainPath,
      ).copy(p.join(workDir.path, '$slot.world.gzip'));
      await Directory(pulled.tempDir).delete(recursive: true);

      expect(await target.status(), RunState.running, reason: 'server back up');
    },
  );

  test(
    '2 — push the same world back through the full envelope',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final source = File(p.join(workDir.path, '$slot.world.gzip'));
      expect(source.existsSync(), isTrue, reason: 'step 1 must have run');

      final states = <PushState>[];
      final result =
          await PushEnvelope(
            target: target,
            audit: audit,
            sessionId: sessionId,
          ).run(
            LocalWorldCandidate(
              slot: slot,
              slotInferred: true,
              mainPath: source.path,
              mainSize: source.lengthSync(),
            ),
            onProgress: (p) => states.add(p.state),
          );

      // ignore: avoid_print
      print('push states: ${states.map((s) => s.name).join(' → ')}');
      // ignore: avoid_print
      print('uploaded ${result.bytesUploaded} bytes');
      // ignore: avoid_print
      print('game id: ${result.gameId}');
      // ignore: avoid_print
      print('backup:  ${result.backupPath}');

      expect(states.last, PushState.done);
      expect(states, isNot(contains(PushState.rollingBack)));
      expect(result.udpListening, isTrue);
      expect(
        result.backupPath,
        isNotNull,
        reason: 'the previous world must have been preserved',
      );

      // Completing at all already proves the transfer: the envelope compares a local
      // streaming SHA-256 against the server's own `sha256sum` and refuses to continue on
      // a mismatch. The backup it made must contain the world it displaced.
      final backedUp = await target.stat(result.backupPath!, '*');
      // ignore: avoid_print
      print('backup holds: ${backedUp.map((e) => e.name).join(', ')}');
      expect(
        backedUp.any((e) => e.name == '$slot.world.gzip'),
        isTrue,
        reason: 'the displaced world must be recoverable',
      );

      expect(await target.status(), RunState.running);
      // The same world is loaded — a different one would report a different id.
      expect(findGameId(await target.logsTail(200)), originalGameId);
    },
  );

  test(
    '3 — a failure after the point of no return rolls back',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      // An empty backup directory: it exists, so the restore proceeds past its guard and
      // past the stop, then fails at the copy step for want of a source file. That is
      // precisely the window the rollback machinery exists for — the server is down and
      // the safety backup is the only way back.
      final decoy = '${target.worldsPath}/.backups/$slot.0000-00-00_000000';
      await session.exec('mkdir -p ${shq(decoy)}');

      final states = <RestoreState>[];
      String? rollbackNote;

      try {
        await RestoreEnvelope(
          target: target,
          audit: audit,
          sessionId: sessionId,
        ).run(decoy, slot, onProgress: (p) => states.add(p.state));
        fail('the restore should have failed — the decoy has no world file');
      } on OperationException catch (e) {
        rollbackNote = e.rollbackNote;
        // ignore: avoid_print
        print('failed at step: ${e.step}');
        // ignore: avoid_print
        print('rollback: $rollbackNote');
      } finally {
        await session.exec('rmdir ${shq(decoy)}');
      }

      // ignore: avoid_print
      print('restore states: ${states.map((s) => s.name).join(' → ')}');

      // It got past the point of no return...
      expect(states, contains(RestoreState.stopping));
      expect(states, contains(RestoreState.backingUp));
      // ...failed...
      expect(states, contains(RestoreState.rollingBack));
      expect(states.last, RestoreState.failed);
      // ...and recovered.
      expect(rollbackNote, contains('restored backup'));
      expect(rollbackNote, contains('restart issued'));

      // THE assertion: after a rollback the live world equals the safety backup that
      // very operation took. That is exactly what rollback promises, and it is
      // deterministic — unlike comparing against a digest from before the stop, which the
      // shutdown save legitimately changes.
      final backups = await RestoreEnvelope(
        target: target,
        audit: audit,
        sessionId: sessionId,
      ).listBackups();
      final safety = backups.firstWhere(
        (b) => b.slot == slot && !b.path.contains('0000-00-00'),
      );
      // ignore: avoid_print
      print('safety backup: ${safety.path}');

      expect(
        await remoteDigest(worldPath()),
        await remoteDigest('${safety.path}/$slot.world.gzip'),
        reason: 'the rolled-back world must match the safety backup exactly',
      );

      // Give the service a moment to finish coming back after the rollback restart.
      for (var i = 0; i < 30; i++) {
        if (await target.status() == RunState.running) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(await target.status(), RunState.running);
    },
  );

  test(
    '4 — the server is healthy and the same world is loaded',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      expect(await target.status(), RunState.running);

      // Wait for the port, which can lag the service by a few seconds after a restart.
      var udp = await target.udpListening();
      for (var i = 0; i < 30 && udp.isEmpty; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        udp = await target.udpListening();
      }
      expect(udp, isNotEmpty);

      final gameId = findGameId(await target.logsTail(200));
      // ignore: avoid_print
      print(
        'final: running, ${udp.length} udp listener(s), game id $gameId, '
        'sha256 ${await remoteDigest(worldPath())}',
      );
      expect(
        gameId,
        originalGameId,
        reason: 'the same world must still be loaded',
      );

      // Report the backups this run created so they can be reviewed or cleaned up by hand.
      final backups = await RestoreEnvelope(
        target: target,
        audit: audit,
        sessionId: sessionId,
      ).listBackups();
      // ignore: avoid_print
      print('backups now on the server: ${backups.length}');
      for (final b in backups.take(5)) {
        // ignore: avoid_print
        print('  ${b.path}  (${b.bytes} bytes)');
      }
    },
  );
}
