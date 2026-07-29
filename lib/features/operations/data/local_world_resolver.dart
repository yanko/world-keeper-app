import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/parsers.dart';
import 'package:world_keeper/features/operations/domain/local_world.dart';

/// Turns whatever the file picker returned — a folder, a `.zip`, or a single file — into
/// pushable world candidates.
///
/// ## Recognition is by filename only, deliberately
///
/// Despite the extension, `*.world.gzip` files are **not** gzip. Confirmed directly: the
/// reference `gzip -t` utility rejects a real `0.world.gzip` as "not in gzip format", and
/// the leading bytes are not `1F 8B`. An earlier attempt at a content check — magic bytes
/// plus a trial decompression — rejected *every* real world file, strictly-named ones
/// included, because it was validating against a format these files do not use.
///
/// The decompressed format is an undocumented, proprietary Unity-serialised structure;
/// the most complete community world editor reads the running game's memory rather than
/// the file, which says everything about how far it has been reverse-engineered. There is
/// no signature to check for, so the name is genuinely the only signal available.
class LocalWorldResolver {
  const LocalWorldResolver();

  /// Resolves [selectedPath] into one or more candidates.
  ///
  /// Throws [LocalWorldException] when nothing recognisable is found — the caller should
  /// show that message rather than an empty list, because "no worlds here" and "I found
  /// three" need very different UI.
  Future<List<LocalWorldCandidate>> resolve(String selectedPath) async {
    final directory = Directory(selectedPath);
    if (directory.existsSync()) return _scanStrict(directory);

    final file = File(selectedPath);
    if (!file.existsSync()) {
      throw LocalWorldException('no such file or folder: $selectedPath');
    }

    if (p.extension(selectedPath).toLowerCase() == '.zip') {
      // Described as the zip rather than the extraction directory: "no worlds in
      // my-save.zip" is actionable, "no worlds under C:\…\wk-extract-7e4d9d2d" is not.
      return _scanStrict(
        await _extractToTemp(file),
        describeAs: p.basename(selectedPath),
      );
    }

    final name = p.basename(selectedPath);

    // A strictly-named file: scan its whole directory instead of taking it alone, so the
    // sibling `.pugbackup` — and any other slots sitting beside it — are picked up too,
    // exactly as choosing the containing folder would.
    if (parseWorldFilename(name) != null) {
      return _scanStrict(file.parent);
    }

    // Not the naming convention, but it mentions the extension somewhere: a manual
    // export, a file shared by someone else, something renamed along the way. Accepted
    // with no inferable slot, which the UI turns into a slot field rather than an
    // assumption. This is also how a brand-new slot gets seeded from an arbitrary file.
    if (name.toLowerCase().contains('.world.gzip')) {
      final stat = file.statSync();
      return [
        LocalWorldCandidate(
          slot: 0,
          slotInferred: false,
          mainPath: file.path,
          mainSize: stat.size,
          mainModified: stat.modified.millisecondsSinceEpoch ~/ 1000,
        ),
      ];
    }

    throw LocalWorldException(
      '"$name" is not a folder, a .zip, or a .world.gzip file',
    );
  }

  /// Walks a directory tree for strictly-named world files, grouped by slot.
  ///
  /// Anything not named `N.world.gzip[.pugbackup]` is simply not found here — pick such a
  /// file directly to get the loose-match path above.
  Future<List<LocalWorldCandidate>> _scanStrict(
    Directory root, {
    String? describeAs,
  }) async {
    final mains = <int, FileSystemEntity>{};
    final pugbackups = <int, FileSystemEntity>{};

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final parsed = parseWorldFilename(p.basename(entity.path));
      if (parsed == null) continue;
      (parsed.isPugbackup ? pugbackups : mains)[parsed.slot] = entity;
    }

    final candidates = <LocalWorldCandidate>[];
    for (final slot in mains.keys.toList()..sort()) {
      final main = File(mains[slot]!.path);
      final mainStat = main.statSync();
      final pugbackup = pugbackups[slot] == null
          ? null
          : File(pugbackups[slot]!.path);

      candidates.add(
        LocalWorldCandidate(
          slot: slot,
          slotInferred: true,
          mainPath: main.path,
          mainSize: mainStat.size,
          mainModified: mainStat.modified.millisecondsSinceEpoch ~/ 1000,
          pugbackupPath: pugbackup?.path,
          pugbackupSize: pugbackup?.statSync().size,
        ),
      );
    }

    if (candidates.isEmpty) {
      throw LocalWorldException(
        'no *.world.gzip files found in ${describeAs ?? root.path}',
      );
    }
    return candidates;
  }

  /// Unpacks a zip into a fresh temp directory.
  ///
  /// The extracted copy is what gets uploaded, so the archive itself is never modified.
  ///
  /// A malformed archive is checked for explicitly, because `extractFileToDisk` does not
  /// throw on one — it simply extracts nothing. Without this the user would be told "no
  /// worlds found" and shown an internal temp path, when the real problem is that the
  /// file isn't a readable zip at all.
  Future<Directory> _extractToTemp(File zip) async {
    final dest = await Directory.systemTemp.createTemp('wk-extract-');
    try {
      await extractFileToDisk(zip.path, dest.path);
    } on Object catch (e) {
      throw LocalWorldException(
        'could not read the zip ${p.basename(zip.path)}',
        cause: e,
      );
    }

    if (dest.listSync().isEmpty) {
      throw LocalWorldException(
        'could not read the zip ${p.basename(zip.path)} — it is empty or corrupt',
      );
    }
    return dest;
  }
}
