import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/parsers.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/features/operations/data/envelope.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';

/// Copying a world off the server.
///
/// ```
/// CheckingService → Stopping → Downloading → Starting → Done   (Failed on error)
/// ```
///
/// Deliberately shorter than push: nothing on the server is modified, so there is no
/// backup, no permissions fix and nothing to roll back. The service is stopped only long
/// enough to copy a file that isn't being written to, and restarted immediately —
/// local packaging happens afterwards, off the critical path, once the server is already
/// back up.
class PullEnvelope {
  PullEnvelope({
    required this.target,
    required this.audit,
    required this.sessionId,
    this.timings = const EnvelopeTimings(),
  }) : _service = ServiceControl(target, timings: timings);

  final ServerTarget target;
  final AuditDatabase audit;
  final int sessionId;

  /// Writes one `file_ops` row, hung off an event of its own.
  ///
  /// Best effort: the bytes are already on this machine by the time this runs, and losing
  /// the note is a smaller problem than failing a download that worked.
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

  final EnvelopeTimings timings;

  final ServiceControl _service;

  /// Worlds available to pull.
  ///
  /// Only the main file per slot. A bare `.pugbackup` with no live world beside it is not
  /// something to offer as "world N" — it is one save cycle behind by definition.
  Future<List<RemoteWorldInfo>> listRemoteWorlds() async {
    final entries = await target.stat(target.worldsPath, '*.world.gzip');

    final worlds = <RemoteWorldInfo>[];
    for (final entry in entries) {
      final parsed = parseWorldFilename(entry.name);
      if (parsed == null || parsed.isPugbackup) continue;
      worlds.add(
        RemoteWorldInfo(
          slot: parsed.slot,
          size: entry.size,
          modified: entry.modified,
        ),
      );
    }
    worlds.sort((a, b) => a.slot.compareTo(b.slot));
    return worlds;
  }

  Future<PulledWorld> run(
    int slot, {
    ProgressSink<PullState>? onProgress,
    void Function(int received, int? total)? onDownloadProgress,
  }) async {
    await audit.logEvent(sessionId, 'pull_begin', detail: {'slot': slot});

    void emit(PullState state, {String? detail, bool? ok}) {
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

    emit(PullState.checkingService);
    try {
      await target.status();
    } on Object {
      // Recorded for parity with push; not branched on.
    }

    emit(PullState.stopping);
    try {
      await _service.stopAndWait();
    } on Object catch (e) {
      return _fail(slot, e, emit);
    }

    emit(PullState.downloading);
    Object? downloadFailure;
    PulledWorld? downloaded;
    try {
      downloaded = await _download(slot, onDownloadProgress);
    } on Object catch (e) {
      downloadFailure = e;
    }

    // The restart is issued **regardless** of whether the download worked. Leaving a game
    // server stopped because a copy failed compounds one problem into two, and the whole
    // rationale for this flow is minimum downtime.
    emit(PullState.starting);
    Object? restartFailure;
    try {
      await _service.startAndWait();
    } on Object catch (e) {
      restartFailure = e;
    }

    if (downloadFailure != null) {
      // The download error is the one the user acted on, so it leads; a failed restart is
      // appended because it is the more urgent problem to actually go and fix.
      final message = restartFailure == null
          ? _messageOf(downloadFailure)
          : '${_messageOf(downloadFailure)} '
                '(and the restart afterwards also failed: ${_messageOf(restartFailure)})';
      return _fail(
        slot,
        OperationException(
          message,
          operation: 'pull',
          step: PullState.downloading.name,
        ),
        emit,
      );
    }

    if (restartFailure != null) {
      return _fail(slot, restartFailure, emit);
    }

    emit(PullState.done, ok: true);
    await audit.logEvent(
      sessionId,
      'pull_done',
      detail: {'slot': slot, 'bytes': downloaded!.bytes},
      ok: true,
    );
    return downloaded;
  }

  Never _fail(
    int slot,
    Object error,
    void Function(PullState, {String? detail, bool? ok}) emit,
  ) {
    final message = _messageOf(error);
    emit(PullState.failed, detail: message, ok: false);
    audit
        .logEvent(
          sessionId,
          'error',
          detail: {'slot': slot, 'reason': message},
          ok: false,
        )
        .ignore();
    audit
        .logError(
          sessionId,
          context: 'pull',
          message: message,
          detail: {'slot': slot},
        )
        .ignore();

    throw OperationException(
      message,
      operation: 'pull',
      step: error is OperationException ? error.step : 'pull',
      cause: error,
    );
  }

  static String _messageOf(Object e) =>
      e is WkException ? e.message : e.toString();

  /// Downloads a slot's files into a temp directory.
  ///
  /// Uses the inclusive `<slot>.world.gzip*` glob, unlike backup's exact pair. The
  /// asymmetry is intended: a backup must not sweep in unrelated files it would later
  /// restore over something, but a pull is read-only and taking whatever sits alongside
  /// is a courtesy, not a risk.
  Future<PulledWorld> _download(
    int slot,
    void Function(int received, int? total)? onDownloadProgress,
  ) async {
    final entries = await target.stat(target.worldsPath, '$slot.world.gzip*');
    if (entries.isEmpty) {
      throw OperationException(
        'no world files found for slot $slot',
        operation: 'pull',
        step: PullState.downloading.name,
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('wk-pull-');

    String? mainPath;
    String? pugbackupPath;
    var total = 0;

    for (final entry in entries) {
      final local = File(p.join(tempDir.path, entry.name));
      final bytes = await target.pullFile(
        entry.path,
        local,
        onProgress: onDownloadProgress,
      );
      total += bytes;

      // Same reasoning as the push: an SFTP transfer is not a shell command, so without
      // this the log records a pull and never records the file coming across.
      await _recordTransfer(
        op: 'download',
        src: entry.path,
        dst: local.path,
        bytes: bytes,
        slot: slot,
      );
      if (entry.name.endsWith('.pugbackup')) {
        pugbackupPath = local.path;
      } else if (entry.name.endsWith('.world.gzip')) {
        mainPath = local.path;
      }
    }

    if (mainPath == null) {
      throw OperationException(
        'no $slot.world.gzip found for slot $slot — only a .pugbackup?',
        operation: 'pull',
        step: PullState.downloading.name,
      );
    }

    return PulledWorld(
      slot: slot,
      tempDir: tempDir.path,
      mainPath: mainPath,
      pugbackupPath: pugbackupPath,
      bytes: total,
    );
  }

  /// Saves a pulled world where the user chose, then removes the temp copy.
  ///
  /// Purely local and off the critical path — the server is already running again by the
  /// time this is called. The temp directory is cleaned up either way, success or not.
  static Future<String> package(
    PulledWorld pulled, {
    required String destination,
    required bool asZip,
  }) async {
    try {
      return asZip
          ? await _packageAsZip(pulled, destination)
          : await _packageAsFolder(pulled, destination);
    } finally {
      final temp = Directory(pulled.tempDir);
      if (temp.existsSync()) {
        try {
          await temp.delete(recursive: true);
        } on Object {
          // A leftover temp directory is not worth failing a completed save over.
        }
      }
    }
  }

  static Future<String> _packageAsFolder(
    PulledWorld pulled,
    String destination,
  ) async {
    final dir = Directory(destination);
    await dir.create(recursive: true);

    // Written under canonical names, so a folder saved from an oddly-named source is
    // immediately pushable again.
    await File(
      pulled.mainPath,
    ).copy(p.join(dir.path, '${pulled.slot}.world.gzip'));

    final pugbackup = pulled.pugbackupPath;
    if (pugbackup != null) {
      await File(
        pugbackup,
      ).copy(p.join(dir.path, '${pulled.slot}.world.gzip.pugbackup'));
    }
    return dir.path;
  }

  static Future<String> _packageAsZip(
    PulledWorld pulled,
    String destination,
  ) async {
    final encoder = ZipFileEncoder()..create(destination);
    try {
      await encoder.addFile(File(pulled.mainPath), '${pulled.slot}.world.gzip');
      final pugbackup = pulled.pugbackupPath;
      if (pugbackup != null) {
        await encoder.addFile(
          File(pugbackup),
          '${pulled.slot}.world.gzip.pugbackup',
        );
      }
    } finally {
      await encoder.close();
    }
    return destination;
  }
}
