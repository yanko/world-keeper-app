import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/app.dart';
import 'package:world_keeper/features/about/presentation/about_dialog.dart';
import 'package:world_keeper/features/about/presentation/disclaimer_dialog.dart';
import 'package:world_keeper/features/shell/presentation/shortcuts.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// App-level chrome: theme, language and About.
///
/// Separate from the connection bar because none of it is about a connection — it stays
/// usable when nothing is connected and unaffected by whether a profile is selected.
///
/// Two shapes, same actions. Desktop shows them as icon buttons in the bar; a phone folds
/// them into the app bar's overflow, because 360 px is already spent on the connection
/// status and the profile name.
class AppMenu extends ConsumerWidget {
  const AppMenu({this.compact = false, this.onShowShortcuts, super.key});

  final bool compact;

  /// Supplied by the shell, which owns the bindings. Null where there is no keyboard to
  /// document — the entry is then absent rather than present and useless.
  final VoidCallback? onShowShortcuts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final shortcuts = supportsKeyboardShortcuts ? onShowShortcuts : null;

    final themeText = l10n.menuTheme(themeLabel(l10n, mode));
    final languageText = l10n.menuLanguage(languageLabel(l10n, locale));

    if (compact) {
      return PopupMenuButton<_MenuAction>(
        icon: const Icon(Icons.more_vert),
        tooltip: l10n.menuMore,
        onSelected: (action) => _run(context, ref, action),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _MenuAction.cycleTheme,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(themeIcon(mode)),
              title: Text(themeText),
            ),
          ),
          PopupMenuItem(
            value: _MenuAction.cycleLanguage,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: LanguageGlyph(locale: locale),
              title: Text(languageText),
            ),
          ),
          if (shortcuts != null)
            PopupMenuItem(
              value: _MenuAction.shortcuts,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.keyboard_outlined),
                title: Text(l10n.menuShortcuts),
              ),
            ),
          PopupMenuItem(
            value: _MenuAction.disclaimer,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber),
              title: Text(l10n.menuSafetyNotice),
            ),
          ),
          PopupMenuItem(
            value: _MenuAction.about,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.menuAbout),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(themeIcon(mode)),
          // The tooltip names the *current* state rather than the next one: a toggle that
          // announces where it will take you is unreadable once there are three states.
          tooltip: themeText,
          onPressed: () => _run(context, ref, _MenuAction.cycleTheme),
        ),
        IconButton(
          icon: LanguageGlyph(locale: locale),
          tooltip: languageText,
          onPressed: () => _run(context, ref, _MenuAction.cycleLanguage),
        ),
        if (shortcuts != null)
          IconButton(
            icon: const Icon(Icons.keyboard_outlined),
            tooltip: l10n.menuShortcutsWithKey,
            onPressed: shortcuts,
          ),
        IconButton(
          icon: const Icon(Icons.warning_amber),
          // Reachable again on purpose: a warning you can only ever read once is a worse
          // warning, and the original app had no way back to it at all.
          tooltip: l10n.menuSafetyNotice,
          onPressed: () => _run(context, ref, _MenuAction.disclaimer),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: l10n.menuAbout,
          onPressed: () => _run(context, ref, _MenuAction.about),
        ),
      ],
    );
  }

  void _run(BuildContext context, WidgetRef ref, _MenuAction action) {
    switch (action) {
      case _MenuAction.cycleTheme:
        ref.read(themeModeProvider.notifier).cycle().ignore();
      case _MenuAction.cycleLanguage:
        ref.read(localeProvider.notifier).cycle().ignore();
      case _MenuAction.shortcuts:
        onShowShortcuts?.call();
      case _MenuAction.disclaimer:
        showDisclaimer(context);
      case _MenuAction.about:
        showWorldKeeperAbout(context);
    }
  }
}

enum _MenuAction { cycleTheme, cycleLanguage, shortcuts, disclaimer, about }

IconData themeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};

String themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l10n.menuThemeSystem,
  ThemeMode.light => l10n.menuThemeLight,
  ThemeMode.dark => l10n.menuThemeDark,
};

/// The language control's face: the code it is pinned to, or the translate glyph while it
/// is following the device.
///
/// It used to be that glyph in all three states, with the current language only in the
/// tooltip — and a tooltip needs a mouse and a pause, which is no feedback on a phone and
/// almost none on a desktop. Worse, the first press of the cycle moves *system → English*,
/// which on an English machine changes nothing on screen: the control read as broken
/// because for one press in three it genuinely looked it.
///
/// The theme button gets away with a cycle because each of its states has its own glyph.
/// This is the same idea with the only symbol a language has — its code.
class LanguageGlyph extends StatelessWidget {
  const LanguageGlyph({required this.locale, super.key});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final pinned = locale;
    if (pinned == null) return const Icon(Icons.translate_outlined);

    return Text(
      pinned.languageCode.toUpperCase(),
      // Scales with the text scale like everything else — this *is* text, and a fixed
      // size here would be the same accessibility bug the Phase 8 pass found four of.
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1),
    );
  }
}

/// What to call the current language setting.
///
/// The name of a language is in that language — "Français", never "French". Someone who
/// has cycled one step too far and cannot read the interface any more is looking for the
/// word they would recognise, and a translated language name is the one thing that will
/// not be it. "System" is the exception: it names a setting, not a language.
String languageLabel(AppLocalizations l10n, Locale? locale) => locale == null
    ? l10n.menuLanguageSystem
    : localeNativeNames[locale.languageCode] ?? locale.languageCode;
