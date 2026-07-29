import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:world_keeper/app/app_info.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/about/presentation/disclaimer_dialog.dart';
import 'package:world_keeper/features/audit/presentation/audit_screen.dart';
import 'package:world_keeper/features/discovery/presentation/discovery_screen.dart';
import 'package:world_keeper/features/operations/presentation/library_screen.dart';
import 'package:world_keeper/features/operations/presentation/pull_screen.dart';
import 'package:world_keeper/features/operations/presentation/push_screen.dart';
import 'package:world_keeper/features/shell/presentation/app_shell.dart';
import 'package:world_keeper/features/stats/presentation/stats_screen.dart';
import 'package:world_keeper/features/terminal/presentation/terminal_screen.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Theme preference: system, light or dark. Persisted across launches.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'wk.themeMode';

  SharedPreferences? _prefs;

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getString(_key);
    state = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Cycles system → light → dark, matching the original's toggle.
  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    state = next;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_key, next.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Interface language: the device's, or one the user picked. Persisted across launches.
///
/// `null` means follow the device, and is the default — an app that ignores a system
/// setting the user already made is an app they have to configure twice. The override
/// exists because the device language and the language you want your tools in are not
/// always the same, particularly for a tool whose subject matter is English-shaped.
class LocaleController extends Notifier<Locale?> {
  static const _key = 'wk.locale';

  SharedPreferences? _prefs;

  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getString(_key);
    // An unrecognised code means the app once shipped a language it no longer does.
    // Falling back to the device beats showing a language nothing can render.
    state = supportedLocales.firstWhereOrNull((l) => l.languageCode == stored);
  }

  /// Cycles system → each supported language → system, matching the theme toggle.
  ///
  /// A cycler rather than a menu because there are three states and one of them is
  /// "system"; a dropdown for that is more chrome than the choice deserves.
  Future<void> cycle() async {
    final index = state == null
        ? 0
        : supportedLocales.indexWhere(
                (l) => l.languageCode == state!.languageCode,
              ) +
              1;

    await select(
      index >= supportedLocales.length ? null : supportedLocales[index],
    );
  }

  Future<void> select(Locale? locale) async {
    state = locale;
    _prefs ??= await SharedPreferences.getInstance();
    if (locale == null) {
      await _prefs?.remove(_key);
    } else {
      await _prefs?.setString(_key, locale.languageCode);
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class WorldKeeperApp extends ConsumerWidget {
  const WorldKeeperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      // Not localised: this is the product name, and on desktop it is also the window
      // title and the taskbar entry.
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: WkTheme.light(),
      darkTheme: WkTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: supportedLocales,
      localizationsDelegates: localizationsDelegates,
      // A `Builder` because the destination labels are localised, and `Localizations` is
      // installed by `MaterialApp` itself — the context this method was called with sits
      // above it and has no string table in scope.
      home: Builder(
        builder: (context) => DisclaimerGate(
          // The safety notice comes before any screen is usable — it is meant to be read
          // before the first push, not alongside it.
          child: AppShell(destinations: appDestinations(context.l10n)),
        ),
      ),
    );
  }
}

/// The seven top-level destinations, flattened from the original's nested tabs.
///
/// A function of the string table rather than a `const` list: the labels are the primary
/// navigation and have to change with the language. Everything else about a destination is
/// fixed, so the list is rebuilt only when `Localizations` changes.
List<ShellDestination> appDestinations(AppLocalizations l10n) => [
  ShellDestination(
    label: l10n.navStats,
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
    builder: (_) => const StatsScreen(),
  ),
  ShellDestination(
    label: l10n.navDiscovery,
    icon: Icons.radar_outlined,
    selectedIcon: Icons.radar,
    // The one connected screen that must work *before* a target exists — it is what
    // creates one.
    requiresTarget: false,
    builder: (_) => const DiscoveryScreen(),
  ),
  ShellDestination(
    label: l10n.navLibrary,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    builder: (_) => const LibraryScreen(),
  ),
  ShellDestination(
    label: l10n.navPush,
    icon: Icons.upload_outlined,
    selectedIcon: Icons.upload,
    builder: (_) => const PushScreen(),
  ),
  ShellDestination(
    label: l10n.navPull,
    icon: Icons.download_outlined,
    selectedIcon: Icons.download,
    builder: (_) => const PullScreen(),
  ),
  ShellDestination(
    label: l10n.navTerminal,
    icon: Icons.terminal_outlined,
    selectedIcon: Icons.terminal,
    builder: (_) => const TerminalScreen(),
  ),
  ShellDestination(
    label: l10n.navAudit,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    // Reachable before discovery: the log is scoped to the *connection*, not to a
    // confirmed target, and a host you have only authenticated against still has a
    // history worth reading. Disconnected, the screen explains itself.
    requiresTarget: false,
    builder: (_) => const AuditScreen(),
  ),
];
