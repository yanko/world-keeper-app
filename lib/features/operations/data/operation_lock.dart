import 'dart:async';

import 'package:world_keeper/core/errors/exceptions.dart';

/// Which destructive operation is running.
enum OperationKind { push, pull, restore }

/// Mutual exclusion for push, pull and restore.
///
/// These three all stop and restart the same service and write to the same directory, so
/// overlapping two of them is a genuine corruption risk rather than merely confusing:
/// two interleaved stop → backup → copy → start sequences can back up a half-written
/// world, or restart the server midway through the other's copy.
///
/// **Fails fast rather than queueing.** A queue would be worse than useless here — the
/// second operation would begin minutes later against a server whose state has completely
/// changed, having been silently accepted at a moment the user has long forgotten. This
/// mirrors the original's `try_lock`.
///
/// Reads deliberately do *not* take this lock. Stats polling, the log tail and the
/// terminal must keep working **during** a push — watching what a swap is doing is the
/// entire point — so they never contend with it.
class OperationLock {
  OperationKind? _current;

  /// What is running, or `null`.
  OperationKind? get current => _current;

  bool get isBusy => _current != null;

  /// Runs [body] while holding the lock.
  ///
  /// Throws [OperationBusyException] immediately if another operation holds it. The lock
  /// is released whether [body] succeeds or throws — a failed push must not wedge the app
  /// into a state where nothing can be started again.
  Future<T> run<T>(OperationKind kind, Future<T> Function() body) async {
    final running = _current;
    if (running != null) {
      throw OperationBusyException('a ${running.name} is already in progress');
    }

    // Assigned synchronously, before the first `await`. Two callers racing from the same
    // event-loop turn must not both see `null` and both proceed.
    _current = kind;
    try {
      return await body();
    } finally {
      _current = null;
    }
  }
}
