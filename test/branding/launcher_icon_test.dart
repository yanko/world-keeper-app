import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:yaml/yaml.dart';

/// The launcher icons are generated once and committed, so nothing here runs the
/// generator. What these tests defend is the part a build cannot notice: that the config
/// still agrees with the app it is branding, and that every slot we ship actually has a
/// file in it.
///
/// Staleness — art changed, generator not re-run — is checked in CI instead, by
/// regenerating and asserting the working tree is unchanged. That is exact, where anything
/// this test could do would be a heuristic.
void main() {
  final root = Directory.current;
  File file(String relative) => File('${root.path}/$relative');

  late YamlMap config;

  setUpAll(() {
    final yaml = loadYaml(
      file('flutter_launcher_icons.yaml').readAsStringSync(),
    );
    config = (yaml as YamlMap)['flutter_launcher_icons'] as YamlMap;
  });

  test('the adaptive background is the app’s own dark background', () {
    // An icon sitting on a colour the app never uses looks like someone else's icon. The
    // launcher draws this behind the badge on every Android 8+ home screen, so it is the
    // first pixel of the app anybody sees.
    final expected = WkTheme.dark().scaffoldBackgroundColor;
    final hex =
        '#${(expected.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    expect(config['adaptive_icon_background'], hex);
  });

  test('the foreground inset keeps the badge inside the mask', () {
    // The launcher picks the mask, not us. The smallest one that must still show
    // everything is a 72dp circle on the 108dp layer — 66.7%. An inset of N% per side
    // leaves 100 - 2N, so anything below 17 lets a circle mask cut the lettering that
    // runs around the top of the badge.
    final inset = config['adaptive_icon_foreground_inset'] as int;

    expect(inset, greaterThanOrEqualTo(17));
    // And an upper bound, because the other failure is a badge so small it reads as a
    // dot with a lot of background around it.
    expect(inset, lessThanOrEqualTo(25));
  });

  test('the source art is square and big enough for the largest slot', () {
    // macOS asks for 1024, Android xxxhdpi for 192, Windows for 256. Upscaling shows.
    final png = file(config['image_path'] as String);
    expect(png.existsSync(), isTrue, reason: '${png.path} is missing');

    final (width, height) = _pngSize(png);
    expect(
      width,
      height,
      reason: 'a non-square source is cropped, not letterboxed',
    );
    expect(width, greaterThanOrEqualTo(512));
  });

  group('every slot we ship has a file in it', () {
    test('Android, all five densities plus the adaptive layers', () {
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(
          file(
            'android/app/src/main/res/mipmap-$density/ic_launcher.png',
          ).existsSync(),
          isTrue,
          reason: 'mipmap-$density is empty — pre-Android-8 launchers use it',
        );
        expect(
          file(
            'android/app/src/main/res/drawable-$density/ic_launcher_foreground.png',
          ).existsSync(),
          isTrue,
          reason: 'drawable-$density has no adaptive foreground',
        );
      }

      final xml = file(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      expect(xml.existsSync(), isTrue, reason: 'no adaptive icon at all');
      expect(xml.readAsStringSync(), contains('ic_launcher_foreground'));

      final colors = file('android/app/src/main/res/values/colors.xml');
      expect(
        colors.readAsStringSync(),
        contains(config['adaptive_icon_background'] as String),
        reason: 'colors.xml disagrees with the config it was generated from',
      );
    });

    test('Windows', () {
      expect(
        file('windows/runner/resources/app_icon.ico').existsSync(),
        isTrue,
      );
    });

    test('macOS', () {
      // Not a build target today, but the runner is in the tree and shipping it with the
      // Flutter template's icon would be worse than not shipping it.
      for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
        expect(
          file(
            'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png',
          ).existsSync(),
          isTrue,
          reason: 'missing the ${size}px macOS icon',
        );
      }
    });
  });
}

/// Width and height straight out of the PNG header.
///
/// Decoding the whole image would mean a dependency for two big-endian integers: the IHDR
/// chunk is always first and always at a fixed offset.
(int, int) _pngSize(File png) {
  final bytes = png.readAsBytesSync();
  final header = bytes.buffer.asByteData();

  expect(bytes.sublist(1, 4), [
    0x50,
    0x4E,
    0x47,
  ], reason: '${png.path} is not a PNG');

  return (header.getUint32(16), header.getUint32(20));
}
