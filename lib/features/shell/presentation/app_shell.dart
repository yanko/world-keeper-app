import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/app_info.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/connection/domain/connection_status.dart';
import 'package:world_keeper/features/connection/presentation/connection_bar.dart';
import 'package:world_keeper/features/operations/presentation/operation_widgets.dart';
import 'package:world_keeper/features/operations/presentation/recovery_dialog.dart';
import 'package:world_keeper/features/shell/presentation/app_menu.dart';
import 'package:world_keeper/features/shell/presentation/shortcuts.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// One destination in the app.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.requiresTarget = true,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  /// Whether this screen needs a confirmed target. Discovery and Audit are the
  /// exceptions — one creates the target, the other only needs a connection.
  final bool requiresTarget;
}

/// The responsive navigation shell.
///
/// Flattens the original's nested tabs (`Server > {Stats, Library, …}` plus a sibling
/// `Audit`) into one level. Nested tabs are a desktop-web idiom that translates badly to
/// a phone, and the nesting carried no real information.
///
/// Layout by window size: bottom bar on a phone, icon rail on a small tablet, extended
/// rail with labels on desktop.
///
/// Screens are kept alive across navigation via [IndexedStack]. That is not an
/// optimisation — the terminal holds a live PTY and the operation panels hold in-flight
/// progress, and the original app had real bugs from its tab widget destroying inactive
/// panels.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.destinations, super.key});

  final List<ShellDestination> destinations;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  /// The profile the recovery prompt has already been shown for.
  ///
  /// The provider re-emits on any rebuild that touches the connection, and a dialog that
  /// reopens itself every time is worse than no dialog. Keyed by profile rather than a
  /// bare bool so reconnecting to a *different* interrupted host still asks.
  String? _recoveryShownFor;

  /// Rebuilt each frame because the callbacks close over the current destinations, and
  /// held in a field because the help sheet lists the very bindings that opened it.
  List<AppShortcut> _shortcuts = const [];

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final connection = ref.watch(connectionProvider);
    final hasTarget = connection is ConnectedTarget;

    // Landing on a destination that needs a target while disconnected would show an
    // empty screen with no explanation; fall back to the first available one instead.
    final destinations = widget.destinations;
    final index = _index.clamp(0, destinations.length - 1);

    final body = IndexedStack(
      index: index,
      children: [
        for (final d in destinations)
          _DestinationHost(
            enabled: hasTarget || !d.requiresTarget,
            connection: connection,
            child: Builder(builder: d.builder),
          ),
      ],
    );

    // A destructive operation that never reported a result means the game service may
    // still be stopped on that host. The prompt belongs at the shell, not on a screen —
    // whichever screen happens to be open when a connection lands is arbitrary, and this
    // is the one thing worth interrupting for.
    ref.listen(interruptedOperationProvider, (previous, next) {
      final marker = next.value;
      if (marker == null || _recoveryShownFor == marker.profileId) return;
      _recoveryShownFor = marker.profileId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showRecoveryDialog(context, ref, marker);
      });
    });

    _shortcuts = buildAppShortcuts(
      destinationLabels: [for (final d in destinations) d.label],
      helpDescription: context.l10n.menuShortcuts,
      onSelect: (i) => setState(() => _index = i),
      onHelp: () => showShortcutsHelp(context, _shortcuts),
    );

    final scaffold = _scaffold(context, size, destinations, index, body);

    // Wrapping the whole shell means a shortcut works wherever focus happens to be —
    // except inside a widget that handles the key itself, which is the terminal, and is
    // correct.
    return CallbackShortcuts(
      bindings: bindingsOf(_shortcuts),
      child: Focus(autofocus: true, child: scaffold),
    );
  }

  Widget _scaffold(
    BuildContext context,
    WindowSize size,
    List<ShellDestination> destinations,
    int index,
    Widget body,
  ) {
    if (size.isCompact) {
      return Scaffold(
        appBar: const _CompactAppBar(),
        body: SafeArea(child: body),
        bottomNavigationBar: _CompactNav(
          destinations: destinations,
          selected: index,
          onSelected: (i) => setState(() => _index = i),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: ConnectionBar()),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppMenu(
                    onShowShortcuts: () =>
                        showShortcutsHelp(context, _shortcuts),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    extended: size.hasExtendedRail,
                    minExtendedWidth: 190,
                    selectedIndex: index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The connection controls on a phone, in a sheet that gets out of the way once it has
/// done its job.
///
/// Dismisses itself the moment a connection succeeds. Leaving it up meant the thing you
/// had just connected to was behind the sheet and you had to tap the backdrop to see it —
/// the sheet exists to *make* a connection, and once there is one it is only in the way.
///
/// Only on success: a failed attempt leaves it open, because the error belongs next to the
/// controls that produced it and the next thing you do is fix the profile and try again.
class _ConnectionSheet extends ConsumerWidget {
  const _ConnectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(connectionProvider, (previous, next) {
      // `isCurrent` guards against popping something stacked on top of the sheet — the
      // host-key prompt is a route of its own and is dismissed before this fires, but a
      // sheet that closes the wrong route is a much worse bug than one that stays open.
      final closeable = ModalRoute.of(context)?.isCurrent ?? false;
      if (closeable &&
          shouldCloseConnectionSheet(
            wasConnected: previous?.isConnected ?? false,
            isConnected: next.isConnected,
          )) {
        Navigator.of(context).pop();
      }
    });

    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ConnectionBar(compact: true),
    );
  }
}

/// Whether a connection-state change should dismiss the sheet.
///
/// The *transition*, not the state: the sheet is also how you disconnect, so opening it
/// while already connected must not slam it shut. And only on success — a failed attempt
/// leaves it up, because the error belongs next to the controls that produced it.
///
/// Split out because the connected states hold a real `SshSession` whose constructor is
/// private, so a widget test cannot manufacture one; this is where the decision can
/// actually be checked.
bool shouldCloseConnectionSheet({
  required bool wasConnected,
  required bool isConnected,
}) => isConnected && !wasConnected;

/// The phone's bottom bar: the four most-used destinations, then "More".
///
/// Material caps a `NavigationBar` at five, and seven is not a style quibble at 360 px —
/// each destination gets 51 px, so "Discovery" and "Terminal" are unreadable before any
/// accessibility setting is involved, and at 200% text the bar overflows outright. The
/// rest move into a sheet, which is also where they were in the responsive plan.
///
/// The bar shows "More" as *selected* when the current destination lives in the sheet, so
/// the highlight never contradicts what is on screen.
class _CompactNav extends StatelessWidget {
  const _CompactNav({
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final List<ShellDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Four plus "More" — five slots, Material's ceiling.
  static const int visible = 4;

  bool get _overflows => destinations.length > visible + 1;

  @override
  Widget build(BuildContext context) {
    if (!_overflows) {
      return NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: onSelected,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      );
    }

    final inSheet = selected >= visible;

    return NavigationBar(
      selectedIndex: inSheet ? visible : selected,
      onDestinationSelected: (i) {
        if (i == visible) {
          _showMore(context);
        } else {
          onSelected(i);
        }
      },
      destinations: [
        for (final d in destinations.take(visible))
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz),
          selectedIcon: const Icon(Icons.more_horiz),
          // Naming the destination you are actually on beats a generic "More" that gives
          // no clue what the screen behind the sheet is.
          label: inSheet ? destinations[selected].label : context.l10n.navMore,
        ),
      ],
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = visible; i < destinations.length; i++)
              ListTile(
                leading: Icon(
                  i == selected
                      ? destinations[i].selectedIcon
                      : destinations[i].icon,
                ),
                title: Text(destinations[i].label),
                selected: i == selected,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSelected(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows a screen, or an explanation of why it isn't available yet.
class _DestinationHost extends StatelessWidget {
  const _DestinationHost({
    required this.enabled,
    required this.connection,
    required this.child,
  });

  final bool enabled;
  final ConnectionStatus connection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;

    final l10n = context.l10n;
    final (title, body) = switch (connection) {
      // The error is the server's words, not ours, and stays in whatever language it
      // arrived in — see the note in `l10n.dart` about what is and is not translated.
      Disconnected(:final error) => (
        l10n.commonNotConnectedTitle,
        error ?? l10n.commonNotConnectedBody,
      ),
      Connecting() => (l10n.commonConnectingTitle, l10n.commonConnectingBody),
      ConnectedRaw() => (
        l10n.commonDiscoveryNotConfirmedTitle,
        l10n.commonDiscoveryNotConfirmedBody,
      ),
      ConnectedTarget() => ('', ''),
    };

    return CenteredNotice(icon: Icons.lan_outlined, title: title, body: body);
  }
}

/// On a phone the connection controls collapse to a status chip that opens a sheet —
/// the full bar has far too many controls for 360 px.
class _CompactAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _CompactAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final profile = connection.profile;

    return AppBar(
      titleSpacing: 12,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            profile?.name ?? appName,
            style: context.texts.titleSmall,
            overflow: TextOverflow.ellipsis,
          ),
          if (profile != null)
            Text(
              '${profile.user}@${profile.host}',
              style: monoStyle(
                context,
                fontSize: 11,
                color: context.wk.mutedForeground,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        ConnectionStatusChip(status: connection, dense: true),
        IconButton(
          icon: const Icon(Icons.settings_ethernet),
          tooltip: context.l10n.connectionTooltip,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (sheetContext) => const _ConnectionSheet(),
          ),
        ),
        const AppMenu(compact: true),
      ],
    );
  }
}
