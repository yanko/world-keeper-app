import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

/// A record that a destructive operation is part-way through, written to disk.
///
/// Push, pull and restore all **stop the game service and start it again**. Between those
/// two points the server is down, and if the app stops running in that window — the phone
/// is backgrounded and Android freezes the process, a laptop lid closes, the process is
/// killed — nothing restarts it. The server stays stopped, and the next thing the user
/// knows is that nobody can join.
///
/// This is the marker that makes that recoverable. It is written when the window opens,
/// updated as the operation moves through it, and deleted when it closes — so its mere
/// existence at startup means "the last operation did not finish".
class InterruptedOperation {
  const InterruptedOperation({
    required this.profileId,
    required this.kind,
    required this.phase,
    required this.startedAt,
    this.slot,
  });

  factory InterruptedOperation.fromJson(Map<String, dynamic> json) =>
      InterruptedOperation(
        profileId: json['profileId'] as String,
        kind: OperationKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => OperationKind.push,
        ),
        phase: json['phase'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        slot: json['slot'] as int?,
      );

  /// Which server. A marker from another profile is not this one's to act on — the whole
  /// point is to say "*this* host may be down", and offering to start a service on the
  /// wrong machine would be worse than saying nothing.
  final String profileId;

  final OperationKind kind;

  /// The last phase entered, e.g. `copying`. Shown to the user, because "interrupted
  /// while copying the world in" and "interrupted while starting it again" call for
  /// different amounts of worry.
  final String phase;

  final DateTime startedAt;

  /// The world slot, where the operation had one.
  final int? slot;

  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'kind': kind.name,
    'phase': phase,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (slot != null) 'slot': slot,
  };
}

/// Tracks whether the service is currently stopped on our account.
///
/// Deliberately a **file**, not a row in the audit database. Two reasons: the audit log is
/// clearable by the user, and losing recovery information as a side effect of tidying a
/// log would be a nasty surprise; and this has to survive a process that was killed
/// outright, where a database write that was still buffered would not have landed.
///
/// One file, because [OperationLock] already guarantees there is at most one operation in
/// flight across the whole app.
class OperationJournal {
  OperationJournal(this._paths);

  final AppPaths _paths;

  /// The phase at which the server goes down.
  ///
  /// Every envelope names it `stopping`, which is checked by a test rather than assumed —
  /// three separate enums agreeing is a coincidence until something enforces it.
  static const String dangerOpens = 'stopping';

  /// The phases at which the window is closed either way.
  ///
  /// `done` means the service was started and verified. `failed` means the envelope's own
  /// rollback ran, which restarts the service as its last act — so by the time either is
  /// reported, the app is no longer responsible for a stopped server.
  static const Set<String> dangerCloses = {'done', 'failed'};

  File get file =>
      File(p.join(_paths.dataDir.path, 'interrupted-operation.json'));

  /// Records progress, opening or closing the window as the phase demands.
  ///
  /// Called for every progress event, which is a handful of small writes per operation —
  /// cheap next to the SFTP transfer happening alongside, and the alternative is a marker
  /// that names a phase the operation left minutes ago.
  Future<void> record<S extends Enum>({
    required String profileId,
    required OperationKind kind,
    required OperationProgress<S> progress,
    int? slot,
  }) async {
    final phase = progress.state.name;

    if (dangerCloses.contains(phase)) {
      await clear();
      return;
    }

    // Nothing before `stopping` can leave the server down: the upload goes to a staging
    // directory and the service is still running. Writing a marker for those phases would
    // mean warning about an interruption that cost nothing.
    if (phase == dangerOpens || await _isOpen()) {
      await _write(
        InterruptedOperation(
          profileId: profileId,
          kind: kind,
          phase: phase,
          startedAt: await _startedAt() ?? DateTime.now().toUtc(),
          slot: slot,
        ),
      );
    }
  }

  /// The marker, if there is one and it parses.
  ///
  /// A corrupt file is treated as no marker and deleted. The alternative — refusing to
  /// start, or nagging forever about a file nobody can read — is worse than losing one
  /// recovery prompt.
  Future<InterruptedOperation?> read() async {
    try {
      if (!file.existsSync()) return null;
      final json = jsonDecode(await file.readAsString());
      return InterruptedOperation.fromJson(json as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      if (file.existsSync()) await file.delete();
    } on Object {
      // A marker that cannot be deleted would re-prompt forever, which is annoying;
      // failing the operation over it would be worse.
    }
  }

  Future<bool> _isOpen() async => file.existsSync();

  /// Preserved across updates so the prompt can say when it started, not when it stalled.
  Future<DateTime?> _startedAt() async => (await read())?.startedAt;

  Future<void> _write(InterruptedOperation operation) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(operation.toJson()), flush: true);
  }
}
