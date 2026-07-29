import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Native file dialogs, with the platform differences made explicit.
///
/// Desktop and mobile do not share a file-system model, and pretending otherwise produces
/// flows that technically run and make no sense. "Pick the folder containing my worlds"
/// and "save this as a folder" are desktop ideas; a phone has a document provider, not a
/// browsable tree the user reasons about.
///
/// So folder flows are **gated on platform, not on window width** — a tablet is
/// compact-width but still has no folder semantics worth exposing.
abstract final class FilePickers {
  /// Whether folder-based flows should be offered at all.
  static bool get supportsFolders =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Picks a world archive or file.
  ///
  /// The filter is deliberately loose. Core Keeper's own files end in `.gzip`, but this
  /// app accepts any file whose *name* contains `.world.gzip` — including renamed exports
  /// — so an over-tight filter would hide files the app can actually use. `any` on mobile
  /// because document providers handle extension filtering inconsistently.
  ///
  /// The dialog title comes from the caller rather than from a string table reached
  /// through a `BuildContext`: these are native OS dialogs opened from a static utility,
  /// and threading a context down here only to look up one label would put a widget
  /// dependency in the one file that has no widgets in it.
  static Future<String?> pickWorldFile({required String dialogTitle}) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: supportsFolders ? FileType.custom : FileType.any,
      allowedExtensions: supportsFolders ? const ['zip', 'gzip'] : null,
    );
    return result?.files.singleOrNull?.path;
  }

  /// Picks a folder to scan for worlds. Desktop only.
  static Future<String?> pickWorldFolder({required String dialogTitle}) =>
      FilePicker.getDirectoryPath(dialogTitle: dialogTitle);

  /// Picks a folder to save a pulled world into. Desktop only.
  static Future<String?> pickSaveFolder({required String dialogTitle}) =>
      FilePicker.getDirectoryPath(dialogTitle: dialogTitle);

  /// Chooses where to write a `.zip`.
  ///
  /// Works everywhere: on mobile this routes through the document provider, which is the
  /// idiomatic way to hand a file to the user there.
  static Future<String?> saveZip(
    String defaultName, {
    required String dialogTitle,
  }) => FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: defaultName,
    type: FileType.custom,
    allowedExtensions: const ['zip'],
  );
}
