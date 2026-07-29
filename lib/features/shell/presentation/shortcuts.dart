/// Keyboard navigation for the desktop shell.
///
/// Deliberately small. Navigation and help are bound; **nothing destructive is**. A
/// keystroke that stops a game server and overwrites world files is a keystroke someone
/// eventually hits by accident, and this app's whole safety story is that every such
/// action is deliberate and confirmed. There is no shortcut for Push, Pull, Restore,
/// Disconnect or Clear, and that is a decision rather than an omission.
///
/// The terminal gets keys first, as it must — `Ctrl+C` there means "interrupt the remote
/// process", not anything of ours. Flutter's shortcut handling bubbles up from the focused
/// widget, so that falls out correctly rather than needing a special case.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// One binding, in a form both the handler map and the help sheet are built from — so the
/// documented shortcut and the working one cannot drift apart.
class AppShortcut {
  const AppShortcut({
    required this.activators,
    required this.keysLabel,
    required this.description,
    required this.onInvoke,
  });

  /// Usually two: the Ctrl form and the macOS Cmd form.
  final List<ShortcutActivator> activators;

  /// How the binding is written in the help sheet.
  final String keysLabel;

  final String description;
  final VoidCallback onInvoke;
}

/// True where a physical keyboard is the assumption rather than the exception.
bool get supportsKeyboardShortcuts =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// The primary modifier, spelled the way the platform spells it.
String get _modifier => Platform.isMacOS ? 'Cmd' : 'Ctrl';

const List<LogicalKeyboardKey> _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// Builds the bindings for the shell.
///
/// [destinationLabels] rather than the destinations themselves: this file has no business
/// knowing what a `ShellDestination` is, and the shell has no business knowing about key
/// codes.
List<AppShortcut> buildAppShortcuts({
  required List<String> destinationLabels,
  required String helpDescription,
  required void Function(int index) onSelect,
  required VoidCallback onHelp,
}) {
  return [
    for (var i = 0; i < destinationLabels.length && i < _digits.length; i++)
      AppShortcut(
        activators: [
          SingleActivator(_digits[i], control: true),
          SingleActivator(_digits[i], meta: true),
        ],
        keysLabel: '$_modifier+${i + 1}',
        description: destinationLabels[i],
        onInvoke: () => onSelect(i),
      ),
    AppShortcut(
      activators: const [SingleActivator(LogicalKeyboardKey.f1)],
      keysLabel: 'F1',
      description: helpDescription,
      onInvoke: onHelp,
    ),
  ];
}

Map<ShortcutActivator, VoidCallback> bindingsOf(List<AppShortcut> shortcuts) =>
    {
      for (final s in shortcuts)
        for (final activator in s.activators) activator: s.onInvoke,
    };

Future<void> showShortcutsHelp(
  BuildContext context,
  List<AppShortcut> shortcuts,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.l10n.shortcutsTitle),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in shortcuts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        s.keysLabel,
                        style: monoStyle(context, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.description,
                        style: context.texts.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Divider(color: context.colors.outline),
            const SizedBox(height: 8),
            Text(
              context.l10n.shortcutsNothingDestructive,
              style: context.texts.bodySmall?.copyWith(
                color: context.wk.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.shortcutsTerminalTakesKeys,
              style: context.texts.bodySmall?.copyWith(
                color: context.wk.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonClose),
      ),
    ],
  ),
);
