import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/breakpoints.dart';

void main() {
  group('WindowSize.fromWidth', () {
    test('classifies the real device widths the layouts are proven at', () {
      // Phone portrait
      expect(WindowSize.fromWidth(360), WindowSize.compact);
      expect(WindowSize.fromWidth(390), WindowSize.compact);
      // Phone landscape / small tablet
      expect(WindowSize.fromWidth(640), WindowSize.medium);
      expect(WindowSize.fromWidth(768), WindowSize.medium);
      // Small desktop
      expect(WindowSize.fromWidth(1024), WindowSize.expanded);
      expect(WindowSize.fromWidth(1280), WindowSize.expanded);
      // Desktop
      expect(WindowSize.fromWidth(1440), WindowSize.large);
      expect(WindowSize.fromWidth(1920), WindowSize.large);
    });

    test('boundaries are inclusive at the lower bound', () {
      expect(WindowSize.fromWidth(599.9), WindowSize.compact);
      expect(WindowSize.fromWidth(600), WindowSize.medium);
      expect(WindowSize.fromWidth(1023.9), WindowSize.medium);
      expect(WindowSize.fromWidth(1024), WindowSize.expanded);
      expect(WindowSize.fromWidth(1439.9), WindowSize.expanded);
      expect(WindowSize.fromWidth(1440), WindowSize.large);
    });

    test('the minimum desktop window still classifies as a rail layout', () {
      // window_manager pins a minimum of 800x600, so the desktop layout never has to
      // survive below this.
      expect(WindowSize.fromWidth(800).hasRail, isTrue);
    });
  });

  group('layout capabilities', () {
    test('only compact uses the bottom bar', () {
      expect(WindowSize.compact.hasRail, isFalse);
      expect(WindowSize.compact.isCompact, isTrue);
      for (final s in [
        WindowSize.medium,
        WindowSize.expanded,
        WindowSize.large,
      ]) {
        expect(s.hasRail, isTrue, reason: '$s should use a rail');
        expect(s.isCompact, isFalse);
      }
    });

    test('labels appear beside rail icons only from expanded up', () {
      expect(WindowSize.medium.hasExtendedRail, isFalse);
      expect(WindowSize.expanded.hasExtendedRail, isTrue);
      expect(WindowSize.large.hasExtendedRail, isTrue);
    });

    test('two-pane is reserved for the widest class', () {
      expect(WindowSize.large.isTwoPane, isTrue);
      for (final s in [
        WindowSize.compact,
        WindowSize.medium,
        WindowSize.expanded,
      ]) {
        expect(s.isTwoPane, isFalse);
      }
    });

    test('touch targets grow on a phone', () {
      expect(WindowSize.compact.minTapTarget, greaterThanOrEqualTo(48));
      expect(
        WindowSize.expanded.minTapTarget,
        lessThan(WindowSize.compact.minTapTarget),
      );
    });
  });
}
