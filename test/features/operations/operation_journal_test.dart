import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/operations/data/operation_journal.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

/// The marker that makes an interrupted operation recoverable.
///
/// Push, pull and restore all stop the game service and start it again. Between those two
/// points the server is down, and if the app stops running — Android freezing a
/// backgrounded process, a laptop lid, a kill — nothing starts it back up. This file is
/// how the app finds out afterwards that it owes somebody a running server.
void main() {
  late Directory tempDir;
  late OperationJournal journal;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_journal_test');
    journal = OperationJournal(AppPaths.forTesting(tempDir));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> record(PushState state, {int? slot = 0}) => journal.record(
    profileId: 'p1',
    kind: OperationKind.push,
    progress: OperationProgress(state),
    slot: slot,
  );

  group('the window opens when the server goes down, not before', () {
    test('uploading writes nothing', () async {
      // The upload lands in a staging directory with the service still running. An
      // interruption there costs time and nothing else, and warning about it would train
      // people to dismiss the warning that matters.
      await record(PushState.uploading);
      expect(await journal.read(), isNull);
    });

    test('checking the service writes nothing', () async {
      await record(PushState.checkingService);
      expect(await journal.read(), isNull);
    });

    test('stopping opens it', () async {
      await record(PushState.stopping);

      final marker = await journal.read();
      expect(marker, isNotNull);
      expect(marker!.phase, 'stopping');
      expect(marker.kind, OperationKind.push);
      expect(marker.slot, 0);
    });

    test('every phase after it keeps it open and current', () async {
      await record(PushState.stopping);
      await record(PushState.backingUp);
      await record(PushState.copying);

      expect((await journal.read())?.phase, 'copying');
    });
  });

  group('the window closes', () {
    test('on success', () async {
      await record(PushState.stopping);
      await record(PushState.copying);
      await record(PushState.done);

      expect(await journal.read(), isNull);
      expect(journal.file.existsSync(), isFalse);
    });

    test('on failure, because the envelope rolls back and restarts', () async {
      // `failed` is reported *after* the rollback has run, and rollback's last act is to
      // start the service. By then the app no longer owes anyone a running server.
      await record(PushState.stopping);
      await record(PushState.failed);

      expect(await journal.read(), isNull);
    });
  });

  test('the start time is when it started, not when it stalled', () async {
    // The prompt says "a push interrupted 40 minutes ago". Rewriting the timestamp on
    // every phase would make it say the interruption was seconds old, every time.
    await record(PushState.stopping);
    final opened = (await journal.read())!.startedAt;

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await record(PushState.copying);

    expect((await journal.read())!.startedAt, opened);
  });

  test('it survives a round trip through the file', () async {
    await record(PushState.copying); // no window open yet
    await record(PushState.stopping);
    await record(PushState.copying);

    final written =
        jsonDecode(journal.file.readAsStringSync()) as Map<String, dynamic>;
    final restored = InterruptedOperation.fromJson(written);

    expect(restored.profileId, 'p1');
    expect(restored.kind, OperationKind.push);
    expect(restored.phase, 'copying');
    expect(restored.slot, 0);
  });

  test('a corrupt marker is discarded rather than nagged about', () async {
    // Refusing to start, or prompting forever about a file nobody can read, are both
    // worse than losing one recovery prompt.
    await journal.file.parent.create(recursive: true);
    await journal.file.writeAsString('not json at all');

    expect(await journal.read(), isNull);
    expect(journal.file.existsSync(), isFalse);
  });

  test(
    'it names the profile, so it cannot be acted on for another server',
    () async {
      // Offering to start a service on the wrong machine would be worse than saying nothing.
      await record(PushState.stopping);
      expect((await journal.read())!.profileId, 'p1');
    },
  );

  group('every envelope agrees on the phase names', () {
    // The journal keys off `stopping`, `done` and `failed` by name across three unrelated
    // enums. That agreement is a coincidence until something enforces it — rename one and
    // the marker silently never opens for that operation.

    test('each envelope has the phase that opens the window', () {
      expect(
        PushState.values.map((s) => s.name),
        contains(OperationJournal.dangerOpens),
      );
      expect(
        PullState.values.map((s) => s.name),
        contains(OperationJournal.dangerOpens),
      );
      expect(
        RestoreState.values.map((s) => s.name),
        contains(OperationJournal.dangerOpens),
      );
    });

    test('each envelope has a phase that closes it', () {
      for (final names in [
        PushState.values.map((s) => s.name).toSet(),
        PullState.values.map((s) => s.name).toSet(),
        RestoreState.values.map((s) => s.name).toSet(),
      ]) {
        expect(
          names.intersection(OperationJournal.dangerCloses),
          isNotEmpty,
          reason:
              'an operation with no closing phase would leave the marker forever',
        );
      }
    });

    test('pull opens the window too', () async {
      // Pull stops the service only briefly, but a phone backgrounded in that gap leaves
      // the server down exactly as a push would.
      await journal.record(
        profileId: 'p1',
        kind: OperationKind.pull,
        progress: const OperationProgress(PullState.stopping),
        slot: 0,
      );

      expect((await journal.read())?.kind, OperationKind.pull);
    });

    test('restore opens the window too', () async {
      await journal.record(
        profileId: 'p1',
        kind: OperationKind.restore,
        progress: const OperationProgress(RestoreState.stopping),
        slot: 0,
      );

      expect((await journal.read())?.kind, OperationKind.restore);
    });
  });
}
