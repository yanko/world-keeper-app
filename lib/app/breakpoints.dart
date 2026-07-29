import 'package:flutter/widgets.dart';

/// Material 3 window size classes, as the single source of truth for layout decisions.
///
/// Desktop-first: the layouts are designed at [expanded] and then proven down to
/// [compact], never the other way round. Mobile-first would flatten the information
/// density the desktop layout depends on.
enum WindowSize {
  /// < 600 — phone portrait. Bottom navigation bar.
  compact,

  /// >= 600 — phone landscape / small tablet. Collapsed navigation rail.
  medium,

  /// >= 1024 — small desktop. Extended navigation rail with labels.
  expanded,

  /// >= 1440 — desktop. Extended rail plus two-pane content where it earns its keep.
  large;

  static const double mediumMin = 600;
  static const double expandedMin = 1024;
  static const double largeMin = 1440;

  /// Resolves from the current width.
  ///
  /// Uses `MediaQuery.sizeOf` rather than `MediaQuery.of`, so a widget reading this only
  /// rebuilds when the size actually changes — not on every metric change, which
  /// includes the software keyboard opening on every keystroke.
  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width >= largeMin) return WindowSize.large;
    if (width >= expandedMin) return WindowSize.expanded;
    if (width >= mediumMin) return WindowSize.medium;
    return WindowSize.compact;
  }

  /// Phone-shaped: bottom navigation, full-screen dialogs, single-column content.
  bool get isCompact => this == WindowSize.compact;

  /// Any rail layout — i.e. not a phone in portrait.
  bool get hasRail => this != WindowSize.compact;

  /// Rail shows labels beside icons rather than icons alone.
  bool get hasExtendedRail =>
      this == WindowSize.expanded || this == WindowSize.large;

  /// Enough width to put two panels side by side.
  bool get isTwoPane => this == WindowSize.large;

  /// Touch-sized hit targets. Desktop can be denser.
  double get minTapTarget => isCompact ? 48 : 36;
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize => WindowSize.of(this);
}
