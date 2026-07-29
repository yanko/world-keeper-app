/// The instrument palette.
///
/// Ported from the Tauri app's CSS tokens, which are authored in OKLCH. Rather than
/// transcribing hand-converted hex values — where a single wrong digit silently shifts
/// the palette — the OKLCH triples are kept verbatim and converted at startup by
/// [oklch]. The numbers below are literally the ones in `src/App.css`.
///
/// The discipline the palette encodes matters more than the hues:
///
/// * **Signal** (phosphor teal) means *live / healthy / done*. Nothing else may use it.
///   It is deliberately not `ColorScheme.primary`, because that would leak it onto every
///   button and destroy the "teal means running" contract.
/// * **Destructive** red is reserved for stop, rollback and failure.
/// * Everything else is cool slate — a faint blue-leaning tint rather than neutral grey,
///   and never pure black, so it reads as instrumentation rather than a generic dark UI.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Converts an OKLCH colour to sRGB.
///
/// Implements the standard OKLab pipeline: polar → cartesian, OKLab → linear sRGB via
/// Björn Ottosson's matrices, then the sRGB transfer function.
Color oklch(double l, double c, double hDegrees, [double opacity = 1]) {
  final h = hDegrees * math.pi / 180.0;
  final a = c * math.cos(h);
  final b = c * math.sin(h);

  final lp = l + 0.3963377774 * a + 0.2158037573 * b;
  final mp = l - 0.1055613458 * a - 0.0638541728 * b;
  final sp = l - 0.0894841775 * a - 1.2914855480 * b;

  final lc = lp * lp * lp;
  final mc = mp * mp * mp;
  final sc = sp * sp * sp;

  final r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc;
  final g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc;
  final bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc;

  return Color.from(
    alpha: opacity,
    red: _encodeSrgb(r),
    green: _encodeSrgb(g),
    blue: _encodeSrgb(bl),
  );
}

double _encodeSrgb(double channel) {
  final v = channel <= 0.0031308
      ? 12.92 * channel
      : 1.055 * math.pow(channel, 1 / 2.4) - 0.055;
  return v.clamp(0.0, 1.0).toDouble();
}

/// Colours that have no slot in Material's [ColorScheme].
///
/// Kept as a [ThemeExtension] specifically so reaching for the signal colour stays a
/// deliberate act — `Theme.of(context).wk.signal` — rather than something that happens
/// by accident because it was sitting in `primary`.
@immutable
class WkColors extends ThemeExtension<WkColors> {
  const WkColors({
    required this.signal,
    required this.signalText,
    required this.onSignal,
    required this.signalSurface,
    required this.signalBorder,
    required this.mutedForeground,
    required this.mono,
  });

  /// Live / healthy / done. Nothing else.
  ///
  /// This is the **fill** value — status dots, badge backgrounds, the stepper's filled
  /// nodes — where [onSignal] supplies the contrast. Do not use it for text on a normal
  /// surface; use [signalText].
  final Color signal;

  /// The same meaning as [signal], darkened enough to be legible **as text**.
  ///
  /// On a light background the badge teal only reaches about 2.3:1, well under WCAG AA,
  /// so using it for labels and icons would make exactly the information the palette
  /// exists to highlight the hardest to read. On a dark background no adjustment is
  /// needed and this is simply [signal]. Enforced by a contrast test.
  final Color signalText;

  final Color onSignal;

  /// A faint signal-tinted fill, for "operation in progress" banners.
  final Color signalSurface;
  final Color signalBorder;

  /// Secondary text: labels, timestamps, paths.
  final Color mutedForeground;

  /// Machine data — paths, sizes, game ids, log output.
  final Color mono;

  static final light = WkColors(
    signal: oklch(0.72, 0.13, 175),
    // Same hue, dropped to L 0.45 so it clears AA against the near-white background.
    signalText: oklch(0.45, 0.10, 175),
    onSignal: oklch(0.16, 0.02, 175),
    signalSurface: oklch(0.72, 0.13, 175, 0.10),
    signalBorder: oklch(0.72, 0.13, 175, 0.40),
    mutedForeground: oklch(0.556, 0.008, 250),
    mono: oklch(0.17, 0.005, 250),
  );

  static final dark = WkColors(
    signal: oklch(0.78, 0.15, 175),
    // Already high-contrast against a graphite background — no adjustment needed.
    signalText: oklch(0.78, 0.15, 175),
    onSignal: oklch(0.16, 0.02, 175),
    signalSurface: oklch(0.78, 0.15, 175, 0.12),
    signalBorder: oklch(0.78, 0.15, 175, 0.40),
    mutedForeground: oklch(0.708, 0.01, 250),
    mono: oklch(0.97, 0.004, 250),
  );

  @override
  WkColors copyWith({
    Color? signal,
    Color? signalText,
    Color? onSignal,
    Color? signalSurface,
    Color? signalBorder,
    Color? mutedForeground,
    Color? mono,
  }) => WkColors(
    signal: signal ?? this.signal,
    signalText: signalText ?? this.signalText,
    onSignal: onSignal ?? this.onSignal,
    signalSurface: signalSurface ?? this.signalSurface,
    signalBorder: signalBorder ?? this.signalBorder,
    mutedForeground: mutedForeground ?? this.mutedForeground,
    mono: mono ?? this.mono,
  );

  @override
  WkColors lerp(WkColors? other, double t) {
    if (other == null) return this;
    return WkColors(
      signal: Color.lerp(signal, other.signal, t)!,
      signalText: Color.lerp(signalText, other.signalText, t)!,
      onSignal: Color.lerp(onSignal, other.onSignal, t)!,
      signalSurface: Color.lerp(signalSurface, other.signalSurface, t)!,
      signalBorder: Color.lerp(signalBorder, other.signalBorder, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      mono: Color.lerp(mono, other.mono, t)!,
    );
  }
}

extension WkThemeAccess on ThemeData {
  WkColors get wk => extension<WkColors>()!;
}

extension WkContextTheme on BuildContext {
  ThemeData get theme => Theme.of(this);
  WkColors get wk => Theme.of(this).wk;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}

/// The monospace stack used for all machine data.
///
/// Uses each platform's own monospace face rather than vendoring Geist Mono / JetBrains
/// Mono, which is a decision rather than a gap: fontsource ships them as `.woff2` only,
/// which Flutter cannot load, so matching the original app exactly would mean either
/// converting the files or pulling new binaries into the repo. Neither buys enough to be
/// worth it — every platform here already has a good monospace face, and using it looks
/// native instead of nearly-right.
///
/// Named in one place so reversing that decision stays a single change rather than a hunt
/// through widgets.
const List<String> monoFontFallback = <String>[
  'Cascadia Mono',
  'Consolas',
  'SF Mono',
  'Menlo',
  'DejaVu Sans Mono',
  'monospace',
];

abstract final class WkTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final wk = isDark ? WkColors.dark : WkColors.light;

    final background = isDark
        ? oklch(0.16, 0.008, 250)
        : oklch(0.99, 0.002, 250);
    final surface = isDark ? oklch(0.205, 0.01, 250) : oklch(1, 0.002, 250);
    final foreground = isDark
        ? oklch(0.97, 0.004, 250)
        : oklch(0.17, 0.005, 250);
    final border = isDark
        ? oklch(0.97, 0.004, 250, 0.12)
        : oklch(0.922, 0.003, 250);
    final destructive = isDark
        ? oklch(0.704, 0.191, 22.216)
        : oklch(0.577, 0.245, 27.325);
    final muted = isDark ? oklch(0.269, 0.01, 250) : oklch(0.97, 0.003, 250);

    final scheme = ColorScheme(
      brightness: brightness,
      // Neutral slate, deliberately *not* the signal colour — see the class docs.
      primary: isDark ? oklch(0.922, 0.004, 250) : oklch(0.205, 0.006, 250),
      onPrimary: isDark ? oklch(0.205, 0.01, 250) : oklch(0.985, 0, 0),
      secondary: muted,
      onSecondary: foreground,
      error: destructive,
      onError: isDark ? oklch(0.16, 0.008, 250) : oklch(0.985, 0, 0),
      surface: surface,
      onSurface: foreground,
      surfaceContainerLowest: background,
      surfaceContainerHighest: muted,
      onSurfaceVariant: wk.mutedForeground,
      outline: border,
      outlineVariant: border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: <ThemeExtension<dynamic>>[wk],
    );

    return base.copyWith(
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: isDark ? oklch(0.97, 0.004, 250, 0.06) : surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
      ),
      // 48dp minimum touch targets — the source app's controls are mouse-sized.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: wk.signalSurface,
        selectedIconTheme: IconThemeData(color: wk.signalText),
        selectedLabelTextStyle: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        unselectedIconTheme: IconThemeData(color: wk.mutedForeground),
        unselectedLabelTextStyle: TextStyle(color: wk.mutedForeground),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: wk.signalSurface,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? wk.signalText
                : wk.mutedForeground,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: foreground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}

/// A text style for machine data — paths, sizes, ids, log output.
TextStyle monoStyle(BuildContext context, {double? fontSize, Color? color}) =>
    TextStyle(
      fontFamily: monoFontFallback.first,
      fontFamilyFallback: monoFontFallback.sublist(1),
      fontSize: fontSize ?? 12,
      color: color ?? context.wk.mono,
      height: 1.4,
    );
