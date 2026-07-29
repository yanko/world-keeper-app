import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/ssh/shell_quote.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

/// Putting a dated backup back.
///
/// Push's envelope minus the upload — the source is already on the remote host, so there
/// is nothing to transfer in. Everything else is the same safety posture, including the
/// part that matters most: **whatever is currently live is backed up first**, so a restore
/// that turns out to be the wrong choice can itself be undone.
class RestoreEnvelope {
  RestoreEnvelope({
    required this.target,
    required this.audit,
    required this.sessionId,
    this.timings = const EnvelopeTimings(),
  }) : _service = ServiceControl(target, timings: timings),
       _worlds = WorldOperations(target, timings: timings);

  final ServerTarget target;
  final AuditDatabase audit;
  final int sessionId;
  final EnvelopeTimings timings;

  final ServiceControl _service;
  final WorldOperations _worlds;

  Future<List<BackupInfo>> listBackups() => _worlds.listBackups();

  Future<RestoreResult> run(
    String sourceBackupPath,
    int slot, {
    ProgressSink<RestoreState>? onProgress,
  }) async {
    await audit.logEvent(
      sessionId,
      'restore_begin',
      detail: {'slot': slot, 'source': sourceBackupPath},
    );

    final worldsPath = target.worldsPath;

    // Checked **before** anything is stopped. A stale list or a direct API misuse could
    // hand over a path belonging to an entirely different server; refusing up front means
    // the worst case is an error message rather than a stopped service and a world
    // restored from somewhere else.
    if (!_isInside(sourceBackupPath, worldsPath)) {
      const message =
          'that backup does not belong to this server\'s worlds directory — '
          'refusing to restore across targets';
      await audit.logError(
        sessionId,
        context: 'restore',
        message: message,
        detail: {
          'slot': slot,
          'source': sourceBackupPath,
          'worldsPath': worldsPath,
        },
      );
      throw const OperationException(
        message,
        operation: 'restore',
        step: 'checkingService',
      );
    }

    void emit(RestoreState state, {String? detail, bool? ok}) {
      onProgress?.call(OperationProgress(state, detail: detail, ok: ok));
      audit
          .logEvent(
            sessionId,
            'state_enter',
            state: state.name,
            detail: detail == null ? null : {'message': detail},
            ok: ok,
          )
          .ignore();
    }

    String? safetyBackupPath;

    try {
      emit(RestoreState.checkingService);
      try {
        await target.status();
      } on Object {
        // Recorded for parity with push; not branched on.
      }

      emit(RestoreState.stopping);
      await _service.stopAndWait();

      emit(RestoreState.backingUp);
      safetyBackupPath = await _worlds.backUpLiveWorld(slot);
      if (safetyBackupPath != null) {
        await audit.logBackup(
          sessionId,
          slot: slot,
          remotePath: safetyBackupPath,
          bytes: await _worlds.sizeOf(safetyBackupPath),
          note: 'pre-restore safety backup',
        );
      }

      emit(RestoreState.copying);
      await _copyBackupIntoPlace(sourceBackupPath, slot);

      emit(RestoreState.fixingPerms);
      await target.fixPerms(worldsPath);

      emit(RestoreState.starting);
      await _service.startAndWait();

      emit(RestoreState.capturingGameId);
      final gameId = await _worlds.captureGameId();

      emit(RestoreState.verifying);
      final udpOk = await _worlds.waitForUdpListening();
      final running = await _statusOrUnknown() == RunState.running;
      if (!running || !udpOk) {
        throw OperationException(
          'verification failed (service running: $running, udp listening: $udpOk)',
          operation: 'restore',
          step: RestoreState.verifying.name,
        );
      }

      emit(RestoreState.done, ok: true);
      await audit.logEvent(
        sessionId,
        'restore_done',
        detail: {'slot': slot, 'gameId': gameId, 'source': sourceBackupPath},
        ok: true,
      );

      return RestoreResult(
        slot: slot,
        gameId: gameId,
        backupPath: safetyBackupPath,
      );
    } on Object catch (e) {
      final message = e is WkException ? e.message : e.toString();

      emit(RestoreState.rollingBack, detail: message);
      final rollbackNote = await _worlds.rollback(backupPath: safetyBackupPath);
      emit(RestoreState.failed, detail: message, ok: false);

      await audit.logEvent(
        sessionId,
        'error',
        detail: {'slot': slot, 'reason': message, 'rollback': rollbackNote},
        ok: false,
      );
      await audit.logError(
        sessionId,
        context: 'restore',
        message: message,
        detail: {'slot': slot, 'rollback': rollbackNote},
      );

      throw OperationException(
        message,
        operation: 'restore',
        step: e is OperationException ? e.step : 'restore',
        rollbackNote: rollbackNote,
        cause: e,
      );
    }
  }

  Future<RunState> _statusOrUnknown() async {
    try {
      return await target.status();
    } on Object {
      return RunState.unknown;
    }
  }

  /// Whether [path] is the worlds directory or something beneath it.
  static bool _isInside(String path, String root) =>
      path == root || path.startsWith('$root/');

  /// Copies the world pair out of the backup and into place.
  ///
  /// **Cherry-picks the two files by exact name** rather than copying the directory's
  /// contents. Backups made before the exact-pair rule existed, or against a deployment
  /// that keeps its own `.old`/`.backup` snapshots beside the real files, can contain
  /// more than the pair — and restoring those would overwrite things that merely share a
  /// prefix. This also makes it forward-compatible with those older, over-inclusive
  /// backups: it takes the real pair back out and ignores the rest.
  ///
  /// Copies rather than moves, so the backup survives the restore and can be used again.
  Future<void> _copyBackupIntoPlace(String sourceBackupPath, int slot) async {
    final mainName = _worlds.mainFileName(slot);

    final entries = <FileEntry>[
      ...await target.stat(sourceBackupPath, mainName),
    ];
    if (entries.isEmpty) {
      throw OperationException(
        'that backup contains no $mainName — there is nothing to restore',
        operation: 'restore',
        step: RestoreState.copying.name,
      );
    }
    entries.addAll(
      await target.stat(sourceBackupPath, _worlds.pugbackupFileName(slot)),
    );

    for (final entry in entries) {
      final out = await target.exec(
        'cp -a ${shq(entry.path)} ${shq(target.worldsPath)}/',
      );
      if (!out.success) {
        throw OperationException(
          'copying ${entry.name} into place failed: ${out.stderr.trim()}',
          operation: 'restore',
          step: RestoreState.copying.name,
        );
      }
    }
  }
}
