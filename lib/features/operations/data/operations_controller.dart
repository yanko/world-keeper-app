import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';
import 'package:world_keeper/features/operations/data/operation_journal.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/features/operations/data/pull_envelope.dart';
import 'package:world_keeper/features/operations/data/push_envelope.dart';
import 'package:world_keeper/features/operations/data/restore_envelope.dart';
import 'package:world_keeper/features/operations/domain/local_world.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

/// Live state of one operation.
class OperationRun<S extends Enum, R> {
  const OperationRun({
    this.running = false,
    this.log = const [],
    this.result,
    this.error,
    this.transferred = 0,
    this.transferTotal = 0,
  });

  final bool running;
  final List<OperationProgress<S>> log;
  final R? result;
  final String? error;

  /// Bytes moved so far, and the expected total, for the transfer bar. Both zero when
  /// nothing is transferring.
  final int transferred;
  final int transferTotal;

  S? get currentState => log.isEmpty ? null : log.last.state;

  bool get hasTransfer => transferTotal > 0 && transferred < transferTotal;

  double get transferFraction =>
      transferTotal == 0 ? 0 : transferred / transferTotal;

  OperationRun<S, R> copyWith({
    bool? running,
    List<OperationProgress<S>>? log,
    R? result,
    String? error,
    int? transferred,
    int? transferTotal,
    bool clearResult = false,
    bool clearError = false,
  }) => OperationRun<S, R>(
    running: running ?? this.running,
    log: log ?? this.log,
    result: clearResult ? null : (result ?? this.result),
    error: clearError ? null : (error ?? this.error),
    transferred: transferred ?? this.transferred,
    transferTotal: transferTotal ?? this.transferTotal,
  );
}

class OperationsState {
  const OperationsState({
    this.active,
    this.push = const OperationRun(),
    this.pull = const OperationRun(),
    this.restore = const OperationRun(),
  });

  /// Which operation is running, if any. **The** cross-screen busy flag.
  final OperationKind? active;

  final OperationRun<PushState, PushResult> push;
  final OperationRun<PullState, PulledWorld> pull;
  final OperationRun<RestoreState, RestoreResult> restore;

  bool get isBusy => active != null;

  OperationsState copyWith({
    OperationKind? active,
    bool clearActive = false,
    OperationRun<PushState, PushResult>? push,
    OperationRun<PullState, PulledWorld>? pull,
    OperationRun<RestoreState, RestoreResult>? restore,
  }) => OperationsState(
    active: clearActive ? null : (active ?? this.active),
    push: push ?? this.push,
    pull: pull ?? this.pull,
    restore: restore ?? this.restore,
  );
}

/// Runs push, pull and restore, and owns the mutual-exclusion lock.
///
/// ## One source of truth for "busy"
///
/// The original had two: a Rust-side mutex that actually prevented overlap, and a
/// separate React flag that greyed out buttons. They could disagree — the UI could look
/// available while the backend refused, or vice versa. Here the UI reads
/// [OperationsState.active], which is set from the same [OperationLock] that gates
/// execution, so a disabled button and a refused call can never disagree.
///
/// ## Why the log lives here
///
/// Progress state outlives the widgets that display it. Navigating away mid-push must not
/// lose the record of what happened — the original had exactly that bug, because its
/// progress state lived inside a tab panel its own tab widget unmounted.
class OperationsController extends Notifier<OperationsState> {
  final _lock = OperationLock();

  /// Records that the service is down on our account, so an interrupted run can be
  /// recovered from rather than merely regretted. See [OperationJournal].
  OperationJournal get _journal => OperationJournal(ref.read(appPathsProvider));

  /// Notes a progress event in the journal, alongside putting it on screen.
  ///
  /// Every operation routes its `onProgress` through here. Doing it at this layer rather
  /// than inside the envelopes keeps them ignorant of profiles and of the filesystem, and
  /// there is exactly one place that can forget.
  void _journalled<S extends Enum>(
    OperationKind kind,
    OperationProgress<S> progress, {
    int? slot,
  }) {
    final profileId = ref.read(connectionProvider).profile?.id;
    if (profileId == null) return;
    _journal
        .record(
          profileId: profileId,
          kind: kind,
          progress: progress,
          slot: slot,
        )
        .ignore();
  }

  @override
  OperationsState build() {
    ref.onDispose(_releaseWakelock);
    return const OperationsState();
  }

  ServerTarget _requireTarget() {
    final target = ref.read(targetProvider);
    if (target == null) {
      throw const NotConnectedException(
        'not connected, or discovery has not been confirmed yet',
      );
    }
    return target;
  }

  ({PushEnvelope push, PullEnvelope pull, RestoreEnvelope restore}) _envelopes(
    ServerTarget target,
  ) {
    final audit = ref.read(auditDatabaseProvider);
    final sessionId = ref.read(auditSessionIdProvider);
    final timings = ref.read(envelopeTimingsProvider);
    return (
      push: PushEnvelope(
        target: target,
        audit: audit,
        sessionId: sessionId,
        timings: timings,
      ),
      pull: PullEnvelope(
        target: target,
        audit: audit,
        sessionId: sessionId,
        timings: timings,
      ),
      restore: RestoreEnvelope(
        target: target,
        audit: audit,
        sessionId: sessionId,
        timings: timings,
      ),
    );
  }

  // ---- push ----------------------------------------------------------------------

  Future<void> startPush(LocalWorldCandidate candidate) async {
    final target = _requireTarget();
    state = state.copyWith(
      push: OperationRun(running: true, transferTotal: _totalBytes(candidate)),
      active: OperationKind.push,
    );
    await _guard(OperationKind.push, () async {
      try {
        final result = await _envelopes(target).push.run(
          candidate,
          onProgress: (p) {
            _journalled(OperationKind.push, p, slot: candidate.slot);
            state = state.copyWith(
              push: state.push.copyWith(log: [...state.push.log, p]),
            );
          },
          onUploadProgress: (sent, total) => state = state.copyWith(
            push: state.push.copyWith(transferred: sent, transferTotal: total),
          ),
        );
        state = state.copyWith(
          push: state.push.copyWith(running: false, result: result),
        );
      } on Object catch (e) {
        state = state.copyWith(
          push: state.push.copyWith(running: false, error: _describe(e)),
        );
        rethrow;
      }
    });
  }

  static int _totalBytes(LocalWorldCandidate c) =>
      c.mainSize + (c.pugbackupSize ?? 0);

  void resetPush() => state = state.copyWith(push: const OperationRun());

  // ---- pull ----------------------------------------------------------------------

  Future<List<RemoteWorldInfo>> listRemoteWorlds() =>
      _envelopes(_requireTarget()).pull.listRemoteWorlds();

  Future<void> startPull(int slot) async {
    final target = _requireTarget();
    state = state.copyWith(
      pull: const OperationRun(running: true),
      active: OperationKind.pull,
    );
    await _guard(OperationKind.pull, () async {
      try {
        final result = await _envelopes(target).pull.run(
          slot,
          onProgress: (p) {
            // Pull stops the service too — briefly, but a phone backgrounded in that
            // gap leaves the server down exactly as a push would.
            _journalled(OperationKind.pull, p, slot: slot);
            state = state.copyWith(
              pull: state.pull.copyWith(log: [...state.pull.log, p]),
            );
          },
          onDownloadProgress: (received, total) => state = state.copyWith(
            pull: state.pull.copyWith(
              transferred: received,
              transferTotal: total ?? 0,
            ),
          ),
        );
        state = state.copyWith(
          pull: state.pull.copyWith(running: false, result: result),
        );
      } on Object catch (e) {
        state = state.copyWith(
          pull: state.pull.copyWith(running: false, error: _describe(e)),
        );
        rethrow;
      }
    });
  }

  /// Saves a pulled world. Local only — the server is already running again.
  Future<String> packagePulled({
    required PulledWorld pulled,
    required String destination,
    required bool asZip,
  }) async {
    final path = await PullEnvelope.package(
      pulled,
      destination: destination,
      asZip: asZip,
    );
    // The temp copy is gone, so the result must not stay on offer.
    state = state.copyWith(pull: const OperationRun());
    return path;
  }

  void resetPull() => state = state.copyWith(pull: const OperationRun());

  // ---- restore -------------------------------------------------------------------

  Future<List<BackupInfo>> listBackups() async {
    final backups = await _envelopes(_requireTarget()).restore.listBackups();
    return _enrichFromAudit(backups);
  }

  /// Attaches the note and prior game id the audit database happens to hold for a
  /// backup. Best-effort enrichment only — a real backup with no database record still
  /// lists, which is the whole reason the listing comes from the filesystem.
  Future<List<BackupInfo>> _enrichFromAudit(List<BackupInfo> backups) async {
    final host = ref.read(connectionProvider).profile?.host;
    if (host == null) return backups;

    try {
      final db = ref.read(auditDatabaseProvider);
      final rows = await db.select(db.auditBackups).get();
      final byPath = {
        for (final r in rows)
          if (r.lxcPath != null) r.lxcPath!: r,
      };
      return [
        for (final b in backups)
          if (byPath[b.path] case final row?)
            BackupInfo(
              path: b.path,
              slot: b.slot,
              bytes: b.bytes,
              modified: b.modified,
              note: row.note,
              gameIdBefore: row.gameIdBefore,
            )
          else
            b,
      ];
    } on Object {
      return backups;
    }
  }

  Future<void> startRestore(String backupPath, int slot) async {
    final target = _requireTarget();
    state = state.copyWith(
      restore: const OperationRun(running: true),
      active: OperationKind.restore,
    );
    await _guard(OperationKind.restore, () async {
      try {
        final result = await _envelopes(target).restore.run(
          backupPath,
          slot,
          onProgress: (p) {
            _journalled(OperationKind.restore, p, slot: slot);
            state = state.copyWith(
              restore: state.restore.copyWith(log: [...state.restore.log, p]),
            );
          },
        );
        state = state.copyWith(
          restore: state.restore.copyWith(running: false, result: result),
        );
      } on Object catch (e) {
        state = state.copyWith(
          restore: state.restore.copyWith(running: false, error: _describe(e)),
        );
        rethrow;
      }
    });
  }

  void resetRestore() => state = state.copyWith(restore: const OperationRun());

  // ---- shared --------------------------------------------------------------------

  /// Takes the lock, keeps the screen awake, and always clears both afterwards.
  Future<void> _guard(OperationKind kind, Future<void> Function() body) async {
    try {
      await _lock.run(kind, () async {
        await _acquireWakelock();
        await body();
      });
    } on OperationBusyException {
      // The UI already disables the triggers, so reaching this means a genuine race
      // slipped past. Surface it rather than swallowing it, but don't clobber the state
      // of whatever is legitimately running.
      rethrow;
    } finally {
      state = state.copyWith(clearActive: true);
      await _releaseWakelock();
    }
  }

  static String _describe(Object e) =>
      e is WkException ? e.message : e.toString();

  /// Keeps the screen on for the duration.
  ///
  /// On mobile, backgrounding the app suspends the isolate and kills the socket. If that
  /// lands between stopping the service and copying the world in, the server is left
  /// **stopped with no rollback** — the worst outcome this app can produce. The wakelock
  /// does not prevent a deliberate switch away, so the UI also warns; see the banner in
  /// the operation panels.
  Future<void> _acquireWakelock() async {
    if (!_supportsWakelock) return;
    try {
      await WakelockPlus.enable();
    } on Object {
      // Never let a nice-to-have stop an operation from running.
    }
  }

  Future<void> _releaseWakelock() async {
    if (!_supportsWakelock) return;
    try {
      await WakelockPlus.disable();
    } on Object {
      // Ditto.
    }
  }

  static bool get _supportsWakelock =>
      !kIsTest && (Platform.isAndroid || Platform.isIOS);
}

/// True inside `flutter test`, where plugin channels have no implementation.
///
/// Checked rather than mocked so a widget test that happens to start an operation does
/// not fail on a missing plugin — the wakelock is incidental to what those tests assert.
final bool kIsTest = Platform.environment.containsKey('FLUTTER_TEST');

final operationsProvider =
    NotifierProvider<OperationsController, OperationsState>(
      OperationsController.new,
    );

/// Overridable so tests can run the envelopes with millisecond timeouts.
final envelopeTimingsProvider = Provider<EnvelopeTimings>(
  (ref) => const EnvelopeTimings(),
);
