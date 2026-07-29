import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/ssh/shell_quote.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';
import 'package:world_keeper/features/operations/domain/local_world.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

/// The safe swap.
///
/// ```
/// Uploading → CheckingService → Stopping → BackingUp → Copying → FixingPerms
///   → Starting → CapturingGameId → Verifying → Done
///                     ↓ any failure from Stopping onward
///             RollingBack → Failed
/// ```
///
/// The ordering is the whole point and is not negotiable: the upload and its checksum
/// happen **before** the server is stopped, and the live world is copied to a dated
/// backup **before** anything overwrites it. A failure at any later step restores that
/// backup and restarts the service.
///
/// Written purely against [ServerTarget], so every branch here — including the ones that
/// are near-impossible to reproduce against a real server — is unit-testable.
class PushEnvelope {
  PushEnvelope({
    required this.target,
    required this.audit,
    required this.sessionId,
    this.timings = const EnvelopeTimings(),
  }) : _service = ServiceControl(target, timings: timings),
       _worlds = WorldOperations(target, timings: timings);

  final ServerTarget target;
  final AuditDatabase audit;

  /// Writes one `file_ops` row, hung off an event of its own.
  ///
  /// Best effort: a transfer that succeeded must not be undone by a failure to write it
  /// down. The bytes are already on the server by this point.
  Future<void> _recordTransfer({
    required String op,
    required String src,
    required String dst,
    required int bytes,
    int? slot,
  }) async {
    try {
      final eventId = await audit.logEvent(
        sessionId,
        'file_transfer',
        detail: {'op': op, 'src': src, 'dst': dst, 'bytes': bytes},
        ok: true,
      );
      await audit.logFileOp(
        eventId,
        op: op,
        src: src,
        dst: dst,
        bytes: bytes,
        slot: slot,
      );
    } on Object {
      // Never let bookkeeping fail an operation that has already moved the data.
    }
  }

  final int sessionId;
  final EnvelopeTimings timings;

  final ServiceControl _service;
  final WorldOperations _worlds;

  Future<PushResult> run(
    LocalWorldCandidate candidate, {
    ProgressSink<PushState>? onProgress,
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    await audit.logEvent(
      sessionId,
      'push_begin',
      detail: {'slot': candidate.slot, 'source': candidate.mainPath},
    );

    final worldsPath = target.worldsPath;
    var bytesUploaded = 0;
    String? backupPath;

    void emit(PushState state, {String? detail, bool? ok}) {
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

    try {
      // Everything up to and including the upload is non-destructive: the server keeps
      // running, and a failure here costs nothing but time.
      emit(PushState.uploading);
      bytesUploaded = await _uploadToStaging(candidate, onUploadProgress);

      emit(PushState.checkingService);
      // Recorded for the trail, not branched on — but knowing whether the service was
      // already down before the swap is exactly the kind of thing you want afterwards.
      final priorState = await _statusOrUnknown();

      emit(PushState.stopping);
      await _service.stopAndWait();

      // ---- past this line, a failure means rollback ----

      emit(PushState.backingUp);
      backupPath = await _worlds.backUpLiveWorld(candidate.slot);
      if (backupPath != null) {
        await audit.logBackup(
          sessionId,
          slot: candidate.slot,
          remotePath: backupPath,
          bytes: await _worlds.sizeOf(backupPath),
        );
      }

      emit(PushState.copying);
      await _moveStagedIntoPlace(candidate);

      emit(PushState.fixingPerms);
      await target.fixPerms(worldsPath);

      emit(PushState.starting);
      await _service.startAndWait();

      emit(PushState.capturingGameId);
      final gameId = await _worlds.captureGameId();

      emit(PushState.verifying);
      final udpOk = await _worlds.waitForUdpListening();
      final running = await _statusOrUnknown() == RunState.running;
      if (!running || !udpOk) {
        throw OperationException(
          'verification failed (service running: $running, udp listening: $udpOk)',
          operation: 'push',
          step: PushState.verifying.name,
        );
      }

      emit(PushState.done, ok: true);
      await audit.logEvent(
        sessionId,
        'push_done',
        detail: {
          'slot': candidate.slot,
          'gameId': gameId,
          'bytesUploaded': bytesUploaded,
          'backupPath': backupPath,
          'priorState': priorState.name,
        },
        ok: true,
      );

      return PushResult(
        slot: candidate.slot,
        bytesUploaded: bytesUploaded,
        gameId: gameId,
        backupPath: backupPath,
        udpListening: udpOk,
      );
    } on Object catch (e) {
      final message = e is WkException ? e.message : e.toString();

      emit(PushState.rollingBack, detail: message);
      final rollbackNote = await _worlds.rollback(backupPath: backupPath);
      emit(PushState.failed, detail: message, ok: false);

      await audit.logEvent(
        sessionId,
        'error',
        detail: {
          'slot': candidate.slot,
          'reason': message,
          'rollback': rollbackNote,
        },
        ok: false,
      );
      await audit.logError(
        sessionId,
        context: 'push',
        message: message,
        detail: {'slot': candidate.slot, 'rollback': rollbackNote},
      );

      throw OperationException(
        message,
        operation: 'push',
        step: e is OperationException ? e.step : 'push',
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

  /// Uploads into `<worldsPath>/.staging/`, verifying each file's checksum.
  ///
  /// Staging first is what keeps the destructive window small: by the time the server is
  /// stopped, the bytes are already on the far side and verified, so the swap itself is
  /// a `mv`.
  ///
  /// The remote name is **always** canonical — `<slot>.world.gzip` — regardless of what
  /// the local file was called. That is what lets an arbitrarily-named export be pushed
  /// into a chosen slot.
  Future<int> _uploadToStaging(
    LocalWorldCandidate candidate,
    void Function(int sent, int total)? onUploadProgress,
  ) async {
    final staging = _worlds.stagingDir;
    final mkdir = await target.exec('mkdir -p ${shq(staging)}');
    if (!mkdir.success) {
      throw OperationException(
        'could not create the staging directory: ${mkdir.stderr.trim()}',
        operation: 'push',
        step: PushState.uploading.name,
      );
    }

    var total = 0;
    total += await _uploadVerified(
      File(candidate.mainPath),
      '$staging/${_worlds.mainFileName(candidate.slot)}',
      onUploadProgress,
    );

    final pugbackup = candidate.pugbackupPath;
    if (pugbackup != null) {
      total += await _uploadVerified(
        File(pugbackup),
        '$staging/${_worlds.pugbackupFileName(candidate.slot)}',
        onUploadProgress,
      );
    }
    return total;
  }

  /// Uploads one file and proves it arrived intact.
  ///
  /// The local digest is computed by **streaming** the file rather than reading it into
  /// memory. Worlds are a few megabytes today and nothing bounds that; on a phone a large
  /// one read twice over would be a real memory event.
  Future<int> _uploadVerified(
    File local,
    String remote,
    void Function(int sent, int total)? onUploadProgress,
  ) async {
    if (!local.existsSync()) {
      throw LocalWorldException('file no longer exists: ${local.path}');
    }

    final localDigest = (await sha256.bind(local.openRead()).first).toString();
    final bytes = await target.pushFile(
      local,
      remote,
      onProgress: onUploadProgress,
    );

    // The one step of a push that leaves no trace anywhere else. Every other action is a
    // shell command and lands in `ssh_commands`; an SFTP transfer is not a command, so
    // without this the audit log records that a push happened and never records the file
    // actually moving. `file_ops` is the table the Rust app used for exactly this.
    await _recordTransfer(
      op: 'upload',
      src: local.path,
      dst: remote,
      bytes: bytes,
    );

    final out = await target.exec('sha256sum ${shq(remote)}');
    final remoteDigest =
        out.stdout.trim().split(RegExp(r'\s+')).firstOrNull ?? '';
    if (remoteDigest.isEmpty) {
      throw OperationException(
        'could not verify the upload of $remote — sha256sum produced no output',
        operation: 'push',
        step: PushState.uploading.name,
      );
    }
    if (remoteDigest != localDigest) {
      throw OperationException(
        'checksum mismatch for $remote: local $localDigest, remote $remoteDigest',
        operation: 'push',
        step: PushState.uploading.name,
      );
    }
    return bytes;
  }

  /// Moves the staged files into place.
  ///
  /// If the incoming world has no `.pugbackup`, the slot's existing one is left alone
  /// rather than deleted or guessed at. It is already preserved in the dated backup, and
  /// Core Keeper regenerates it on the next save cycle.
  Future<void> _moveStagedIntoPlace(LocalWorldCandidate candidate) async {
    final staging = _worlds.stagingDir;
    final worlds = target.worldsPath;
    final slot = candidate.slot;

    Future<void> move(String name) async {
      final out = await target.exec(
        'mv ${shq('$staging/$name')} ${shq('$worlds/$name')}',
      );
      if (!out.success) {
        throw OperationException(
          'moving $name into place failed: ${out.stderr.trim()}',
          operation: 'push',
          step: PushState.copying.name,
        );
      }
    }

    await move(_worlds.mainFileName(slot));
    if (candidate.hasPugbackup) {
      await move(_worlds.pugbackupFileName(slot));
    }
  }
}
