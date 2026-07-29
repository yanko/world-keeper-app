import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/stats/domain/server_stats.dart';
import 'package:world_keeper/features/stats/presentation/log_drawer.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// The read-only server dashboard.
///
/// Stays live during a push, pull or restore — it is a read over the same connection and
/// deliberately outside the operation lock, so watching what a swap is doing never has to
/// contend with the swap itself.
/// Collects a fresh set of stats now, rather than waiting out the poll interval.
///
/// Invalidating restarts the stream, which re-runs `collect()` immediately. The awaited
/// future is what a `RefreshIndicator` needs: it completes when the new numbers land, so
/// the spinner tracks the actual round trip rather than a fixed animation.
///
/// Errors are swallowed on purpose. A refresh during a restart legitimately fails, and
/// the screen keeps showing the last good reading with its own error handling — throwing
/// out of here would additionally leave the pull gesture stuck.
Future<void> refreshStats(WidgetRef ref) async {
  if (ref.read(targetProvider) == null) return;
  ref.invalidate(statsProvider);
  try {
    await ref.read(statsProvider.future);
  } on Object {
    // The stream reports its own failures; this only drives the gesture.
  }
}

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final size = context.windowSize;

    // The nullable `value` rather than `when`, so a refresh does not blank the panel it is
    // refreshing. Riverpod reports a re-fetch as loading *with* the previous value still
    // attached; rendering the spinner then would replace a screenful of readings with an
    // empty box every five seconds a manual refresh happened to overlap a poll.
    final current = stats.value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: switch ((current, stats.error)) {
        (final s?, _) => _StatsBody(
          stats: s,
          twoPane: size.isTwoPane,
          refreshing: stats.isLoading,
        ),
        (null, final e?) => _CentredScroll(
          child: Text('$e', style: TextStyle(color: context.colors.error)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: size.isCompact
          ? FloatingActionButton.small(
              tooltip: context.l10n.statsLiveLog,
              onPressed: () => showLogDrawer(context),
              child: const Icon(Icons.terminal),
            )
          : null,
    );
  }
}

/// An error that still scrolls, so pull-to-refresh works from it.
///
/// A `Center` here would mean the one screen you most want to retry from is the one
/// screen the gesture does not reach.
class _CentredScroll extends StatelessWidget {
  const _CentredScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    ),
  );
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({
    required this.stats,
    required this.twoPane,
    required this.refreshing,
  });

  final ServerStats stats;
  final bool twoPane;
  final bool refreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ListView(
      padding: const EdgeInsets.all(16),
      // Without this the pull does nothing whenever the content happens to fit, which is
      // most of this screen on a tall phone — the gesture would appear to work sometimes.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _StatusRow(stats: stats, refreshing: refreshing),
        const SizedBox(height: 16),
        _CurrentWorld(gameId: stats.gameId),
        const SizedBox(height: 16),
        _MetricGrid(stats: stats),
        const SizedBox(height: 16),
        _UdpSection(lines: stats.udpListening),
        if (!twoPane) ...[
          const SizedBox(height: 16),
          _LogPreview(text: stats.recentLogTail),
        ],
      ],
    );

    // Both gestures, because they are for different hands. Pull-to-refresh is what a
    // phone user reaches for and is invisible to a mouse; the button in the status row is
    // the reverse. Neither is redundant on the device the other was built for.
    final refreshable = RefreshIndicator(
      onRefresh: () => refreshStats(ref),
      child: panel,
    );

    if (!twoPane) return refreshable;

    // On a wide screen the log earns permanent space rather than living behind a button.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: refreshable),
        const VerticalDivider(width: 1),
        const Expanded(child: LiveLogPanel()),
      ],
    );
  }
}

class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.stats, required this.refreshing});

  final ServerStats stats;
  final bool refreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Only a genuinely running service gets the signal colour.
    final running = _isRunning(stats.serviceStatus);
    final color = running ? context.wk.signalText : context.colors.error;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            // `serviceStatus` is systemd's or Docker's own word for the state
            // ("active", "running"), reported rather than restated.
            stats.serviceStatus.isEmpty
                ? l10n.statsUnknown
                : stats.serviceStatus,
            style: context.texts.labelMedium?.copyWith(color: color),
          ),
        ),
        if (stats.activeSince != null)
          _Meta(l10n.statsSince(stats.activeSince!)),
        if (stats.uptimeSeconds != null)
          _Meta(l10n.statsUptime(formatUptime(l10n, stats.uptimeSeconds!))),
        if (stats.serverTime != null)
          _Meta(l10n.statsServerClock(stats.serverTime!)),
        // In the same `Wrap` as the metadata so it reflows with everything else instead
        // of pinning a fixed-height row at 200% text scale.
        IconButton(
          icon: refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          tooltip: l10n.statsRefresh,
          visualDensity: VisualDensity.compact,
          onPressed: refreshing ? null : () => refreshStats(ref),
        ),
      ],
    );
  }

  static bool _isRunning(String raw) {
    final s = raw.trim().toLowerCase();
    return s == 'active' || s == 'running' || s.contains('running');
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: monoStyle(context, fontSize: 11, color: context.wk.mutedForeground),
  );
}

class _CurrentWorld extends StatelessWidget {
  const _CurrentWorld({required this.gameId});

  final String? gameId;

  @override
  Widget build(BuildContext context) {
    final id = gameId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.statsCurrentWorld,
          style: context.texts.labelMedium?.copyWith(
            color: context.wk.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        if (id == null)
          Text(
            context.l10n.statsNoGameId,
            style: context.texts.bodySmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          )
        else
          Row(
            children: [
              Flexible(
                child: SelectableText(
                  id,
                  style: monoStyle(context, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: context.l10n.statsCopyGameId,
                onPressed: () async {
                  final copied = context.l10n.statsGameIdCopied;
                  await Clipboard.setData(ClipboardData(text: id));
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(
                      context,
                    )?.showSnackBar(SnackBar(content: Text(copied)));
                  }
                },
              ),
            ],
          ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.stats});

  final ServerStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tile-width driven rather than a hard column count, so it reflows sensibly at
        // every width instead of only at the named breakpoints.
        final columns = (constraints.maxWidth / 260).floor().clamp(1, 3);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.0,
          children: [
            _MetricTile(
              label: context.l10n.statsMemory,
              value: stats.memUsedKb == null
                  ? '—'
                  : '${formatKb(stats.memUsedKb)} / ${formatKb(stats.memTotalKb)}',
            ),
            _MetricTile(
              label: context.l10n.statsDiskWorlds,
              value:
                  '${stats.diskUsed ?? "—"} / ${stats.diskSize ?? "—"}'
                  '${stats.diskUsePct == null ? "" : "  (${stats.diskUsePct})"}',
            ),
            _MetricTile(
              label: 'UDP',
              value: stats.isListening
                  ? context.l10n.statsUdpListening
                  : context.l10n.statsUdpNotDetected,
              highlight: stats.isListening,
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: monoStyle(
                context,
                fontSize: 13,
                color: highlight ? context.wk.signalText : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UdpSection extends StatelessWidget {
  const _UdpSection({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.statsUdpListeners,
          style: context.texts.labelMedium?.copyWith(
            color: context.wk.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          // Wide command output scrolls inside its own box; the page never scrolls
          // sideways.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              lines.join('\n'),
              style: monoStyle(context, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogPreview extends StatelessWidget {
  const _LogPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.trim().split('\n');
    final preview = lines.length > 12
        ? lines.sublist(lines.length - 12).join('\n')
        : text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.statsRecentLog,
                style: context.texts.labelMedium?.copyWith(
                  color: context.wk.mutedForeground,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => showLogDrawer(context),
              icon: const Icon(Icons.open_in_full, size: 16),
              label: Text(context.l10n.statsLiveLog),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            preview.isEmpty ? context.l10n.commonEmpty : preview,
            style: monoStyle(context, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

String formatKb(int? kb) {
  if (kb == null) return '—';
  final mb = kb / 1024;
  return mb < 1024
      ? '${mb.toStringAsFixed(0)} MiB'
      : '${(mb / 1024).toStringAsFixed(2)} GiB';
}

/// Compact uptime: `4d 3h 12m`.
///
/// The unit letters are localised because they are abbreviated *words* — French shortens
/// "jour" to `j`, not `d`. Hours and minutes happen to agree across both languages the app
/// ships, which is why they are still keys rather than literals: the next language added
/// should not have to come back and find them.
String formatUptime(AppLocalizations l10n, int seconds) {
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return [
    if (d > 0) '$d${l10n.statsUnitDays}',
    if (h > 0) '$h${l10n.statsUnitHours}',
    '$m${l10n.statsUnitMinutes}',
  ].join(' ');
}
