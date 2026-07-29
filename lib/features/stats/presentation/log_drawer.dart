import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// The live log.
///
/// Polls rather than holding a real `journalctl -f` / `docker logs -f` stream. A true
/// follow needs a dedicated long-lived channel with its own lifecycle; polling every two
/// seconds gets almost all of the "watch it happen" feel for a fraction of the machinery.
/// Promoting it to a real stream is tracked as a later improvement.
class LiveLogPanel extends ConsumerStatefulWidget {
  const LiveLogPanel({super.key});

  @override
  ConsumerState<LiveLogPanel> createState() => _LiveLogPanelState();
}

class _LiveLogPanelState extends ConsumerState<LiveLogPanel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    if (!_scroll.hasClients) return;
    // Only follow if already at the bottom — never yank the view away from someone
    // reading back through history.
    final position = _scroll.position;
    final nearBottom = position.maxScrollExtent - position.pixels < 80;
    if (!nearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(logTailProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.terminal, size: 16, color: context.wk.mutedForeground),
              const SizedBox(width: 8),
              Text(context.l10n.statsLiveLog, style: context.texts.titleSmall),
              const Spacer(),
              Text(
                context.l10n.statsPollingEvery(logDrawerPollInterval.inSeconds),
                style: context.texts.labelSmall?.copyWith(
                  color: context.wk.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: log.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '$e',
                  style: TextStyle(color: context.colors.error),
                ),
              ),
            ),
            data: (text) {
              _autoScroll();
              return Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    text.trim().isEmpty ? context.l10n.commonEmpty : text,
                    style: monoStyle(context, fontSize: 11),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Opens the live log as a sheet — a phone has no room for a permanent panel.
Future<void> showLogDrawer(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) =>
      const FractionallySizedBox(heightFactor: 0.85, child: LiveLogPanel()),
);
