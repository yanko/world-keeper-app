import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the layering rule the architecture depends on.
///
/// The push/pull/restore envelopes and the SSH transport have to be unit-testable
/// against a fake target with no UI, no plugins and no device. That only stays true if
/// those layers never reach for Flutter, and "never" is the kind of thing that decays
/// silently through one convenient `debugPrint` import. So it's a test.
///
/// This is deliberately scoped rather than blanket: `core/config/app_paths.dart` uses
/// `path_provider` and `core/secrets` uses `flutter_secure_storage` because those *are*
/// platform integrations — there is no pure-Dart way to ask the OS for its keychain.
/// The rule applies to the layers that carry logic, not the ones that carry platform
/// access.
void main() {
  /// Directories whose contents must be free of Flutter and of Flutter-only plugins.
  const pureDirs = <String>[
    'lib/core/target',
    'lib/core/ssh',
    'lib/core/errors',
  ];

  /// Any `domain/` folder under a feature is pure by definition — entities and
  /// repository interfaces, no implementations.
  const featuresRoot = 'lib/features';

  const bannedImports = <String>[
    'package:flutter/',
    'package:flutter_riverpod/',
    'package:path_provider/',
    'package:flutter_secure_storage/',
    'package:file_picker/',
    'package:window_manager/',
    'package:shared_preferences/',
    'package:xterm/',
    'package:go_router/',
  ];

  Iterable<File> dartFilesIn(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'));
  }

  void assertPure(File file) {
    final offending = file
        .readAsLinesSync()
        .where((l) => l.startsWith('import ') || l.startsWith('export '))
        .where((l) => bannedImports.any(l.contains))
        .toList();

    expect(
      offending,
      isEmpty,
      reason:
          '${file.path} must stay free of Flutter so it can be tested headlessly, '
          'but imports:\n${offending.join('\n')}',
    );
  }

  group('layering', () {
    for (final dir in pureDirs) {
      test('$dir is Flutter-free', () {
        final files = dartFilesIn(dir).toList();
        expect(files, isNotEmpty, reason: 'expected Dart files under $dir');
        files.forEach(assertPure);
      });
    }

    test('every features/*/domain layer is Flutter-free', () {
      final root = Directory(featuresRoot);
      if (!root.existsSync()) {
        // No features yet — the rule still holds vacuously, and this test starts
        // enforcing it the moment the first one lands in Phase 3.
        return;
      }
      for (final feature in root.listSync().whereType<Directory>()) {
        dartFilesIn(
          '${feature.path}${Platform.pathSeparator}domain',
        ).forEach(assertPure);
      }
    });

    test('nothing outside lib/ is imported by package path', () {
      // Catches accidental relative escapes like `import '../../../other_app/x.dart'`.
      for (final file in dartFilesIn('lib')) {
        final bad = file
            .readAsLinesSync()
            .where((l) => l.startsWith('import '))
            .where((l) => l.contains("'../") && l.contains('../..'))
            .toList();
        expect(
          bad,
          isEmpty,
          reason: '${file.path} reaches outside lib/:\n$bad',
        );
      }
    });
  });
}
