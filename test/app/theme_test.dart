import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/theme.dart';

/// Relative luminance per WCAG 2.x.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('oklch conversion', () {
    test('produces an achromatic grey when chroma is zero', () {
      final grey = oklch(0.5, 0, 0);
      expect((grey.r - grey.g).abs(), lessThan(0.01));
      expect((grey.g - grey.b).abs(), lessThan(0.01));
    });

    test('lightness 1 with no chroma is white, 0 is black', () {
      final white = oklch(1, 0, 0);
      expect(white.r, closeTo(1.0, 0.02));
      expect(white.b, closeTo(1.0, 0.02));

      final black = oklch(0, 0, 0);
      expect(black.r, closeTo(0.0, 0.02));
    });

    test('the signal hue really is teal — green and blue over red', () {
      final signal = oklch(0.72, 0.13, 175);
      expect(signal.g, greaterThan(signal.r));
      expect(signal.b, greaterThan(signal.r));
    });

    test(
      'clamps out-of-gamut values rather than producing invalid channels',
      () {
        final extreme = oklch(0.9, 0.4, 20);
        for (final channel in [extreme.r, extreme.g, extreme.b]) {
          expect(channel, inInclusiveRange(0.0, 1.0));
        }
      },
    );

    test('applies opacity', () {
      expect(oklch(0.5, 0, 0, 0.25).a, closeTo(0.25, 0.01));
    });
  });

  group('theme construction', () {
    test('both brightnesses carry the WkColors extension', () {
      expect(WkTheme.light().extension<WkColors>(), isNotNull);
      expect(WkTheme.dark().extension<WkColors>(), isNotNull);
      expect(WkTheme.light().wk.signal, isNot(WkTheme.dark().wk.signal));
    });

    test('the signal colour is never the scheme primary', () {
      // The whole discipline: teal means live. Putting it in `primary` would leak it
      // onto every button and destroy that meaning.
      for (final theme in [WkTheme.light(), WkTheme.dark()]) {
        expect(theme.colorScheme.primary, isNot(theme.wk.signal));
      }
    });

    test('backgrounds are tinted slate, never pure black or white', () {
      final dark = WkTheme.dark();
      final bg = dark.scaffoldBackgroundColor;
      expect(bg.r, greaterThan(0.0));
      expect(bg.b, greaterThan(bg.r), reason: 'should lean cool/blue');

      final light = WkTheme.light();
      expect(light.scaffoldBackgroundColor.r, lessThan(1.0));
    });

    test('error and signal are clearly distinct in both themes', () {
      for (final theme in [WkTheme.light(), WkTheme.dark()]) {
        final signal = theme.wk.signal;
        final error = theme.colorScheme.error;
        // Red vs teal: the red channel dominance must be opposite.
        expect(error.r, greaterThan(error.g));
        expect(signal.g, greaterThan(signal.r));
      }
    });
  });

  group('contrast', () {
    test('body text on the background meets WCAG AA in both themes', () {
      for (final theme in [WkTheme.light(), WkTheme.dark()]) {
        final ratio = _contrast(
          theme.colorScheme.onSurface,
          theme.scaffoldBackgroundColor,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness} body text contrast was $ratio',
        );
      }
    });

    test('muted text still meets AA — it carries real information', () {
      // Paths, timestamps and sizes are rendered muted; they are not decoration.
      for (final theme in [WkTheme.light(), WkTheme.dark()]) {
        final ratio = _contrast(
          theme.wk.mutedForeground,
          theme.scaffoldBackgroundColor,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness} muted text contrast was $ratio',
        );
      }
    });

    test('signalText meets AA on the background in both themes', () {
      // Flagged in the plan as the risky pair, and it turned out to be real: the badge
      // teal reaches only ~2.3:1 on the light background, so a separate darker variant
      // exists for text and icons. This test is what forces them apart.
      for (final theme in [WkTheme.light(), WkTheme.dark()]) {
        final ratio = _contrast(
          theme.wk.signalText,
          theme.scaffoldBackgroundColor,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness} signalText contrast was $ratio',
        );
      }
    });

    test('the fill signal is legible against its own foreground', () {
      // `signal` is a fill — a badge background or a filled stepper node — so what has
      // to be readable is `onSignal` on top of it, not `signal` on the page.
      for (final theme in [WkTheme.light(), WkTheme.dark()]) {
        final ratio = _contrast(theme.wk.onSignal, theme.wk.signal);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness} onSignal-on-signal contrast was $ratio',
        );
      }
    });

    test('light theme genuinely darkens signalText; dark theme need not', () {
      final light = WkTheme.light();
      expect(
        _luminance(light.wk.signalText),
        lessThan(_luminance(light.wk.signal)),
      );
      // On graphite the bright teal is already high-contrast, so they coincide.
      final dark = WkTheme.dark();
      expect(dark.wk.signalText, dark.wk.signal);
    });

    test('error text meets AA too — failures must be readable', () {
      for (final theme in [WkTheme.light(), WkTheme.dark()]) {
        final ratio = _contrast(
          theme.colorScheme.error,
          theme.scaffoldBackgroundColor,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.0),
          reason: '${theme.brightness} error contrast was $ratio',
        );
      }
    });
  });
}
