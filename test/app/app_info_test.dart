import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/app_info.dart';
import 'package:yaml/yaml.dart';

/// `appVersion` is what the About dialog shows and what every audit session row records;
/// `pubspec.yaml` is what the build stamps into the executable, the installer's file name
/// and the release tag check. Two numbers that are meant to be one drift the first time a
/// bump touches only one of them, and a bug report then names a version that never
/// existed.
void main() {
  test('appVersion matches the version in pubspec.yaml', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final version = (pubspec['version'] as String).split('+').first;
    expect(
      appVersion,
      version,
      reason: 'bump lib/app/app_info.dart together with pubspec.yaml',
    );
  });
}
