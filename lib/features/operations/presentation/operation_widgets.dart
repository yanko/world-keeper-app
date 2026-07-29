import 'dart:io';

import 'package:flutter/material.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Shown when a *different* destructive operation is already running.
///
/// Push, pull and restore all stop and restart the same service, so they can never
/// safely overlap. The lock enforces that; this explains it.
class OtherOperationBanner extends StatelessWidget {
  const OtherOperationBanner({required this.active, super.key});

  final OperationKind active;

  @override
  Widget build(BuildContext context) => _Banner(
    color: context.colors.error,
    icon: Icons.hourglass_top,
    child: Text(
      context.l10n.opOtherInProgress(operationName(context.l10n, active)),
    ),
  );
}

/// What to call an operation inside a sentence.
///
/// Lower case: every use is mid-sentence ("A push is in progress"), and the enum's own
/// `.name` was already being spliced in that way before it was translated.
String operationName(AppLocalizations l10n, OperationKind kind) =>
    switch (kind) {
      OperationKind.push => l10n.opPush,
      OperationKind.pull => l10n.opPull,
      OperationKind.restore => l10n.opRestore,
    };

/// Warns that backgrounding the app on a phone can interrupt an operation.
///
/// This is the honest version of a real limitation rather than a decoration. Backgrounding
/// suspends the isolate and kills the socket; if that lands between stopping the service
/// and copying the world in, the server is left **stopped with no rollback**. The wakelock
/// keeps the screen on, but nothing stops a deliberate switch away, so it is worth saying
/// out loud before someone starts a swap and then answers a phone call.
class MobileInterruptionWarning extends StatelessWidget {
  const MobileInterruptionWarning({super.key});

  static bool get isRelevant => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    if (!isRelevant) return const SizedBox.shrink();
    return _Banner(
      color: context.wk.signalText,
      icon: Icons.phonelink_ring,
      child: Text(context.l10n.opKeepAppOpen),
    );
  }
}

/// A labelled progress bar for a byte transfer.
class TransferProgress extends StatelessWidget {
  const TransferProgress({
    required this.label,
    required this.transferred,
    required this.total,
    super.key,
  });

  final String label;
  final int transferred;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? null : (transferred / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.texts.labelSmall?.copyWith(
                  color: context.wk.mutedForeground,
                ),
              ),
            ),
            Text(
              total == 0
                  ? formatBytes(transferred)
                  : '${formatBytes(transferred)} / ${formatBytes(total)}',
              style: monoStyle(context, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: context.colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(context.wk.signal),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.child});

  final Color color;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: DefaultTextStyle.merge(
              style: context.texts.bodySmall ?? const TextStyle(fontSize: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with optional trailing actions.
///
/// On a phone the actions move **below** the title rather than beside it. Several screens
/// carry three buttons here, which simply do not fit next to a heading at 360 px — the
/// first version overflowed by 152 px, pushing the rightmost action off-screen entirely.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.subtitle, this.trailing, super.key});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.texts.titleMedium),
        if (subtitle != null)
          Text(
            subtitle!,
            style: context.texts.bodySmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          ),
      ],
    );

    if (trailing == null) return text;

    if (context.windowSize.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: 10), trailing!],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: 12),
        // `Flexible`, not a bare child: callers pass a `Wrap`, and a Wrap given unbounded
        // width lays everything on one line and then overflows rather than wrapping. It
        // looked fine only because no header had enough in it — the audit server picker
        // pushed it 253 px over.
        Flexible(child: trailing!),
      ],
    );
  }
}

String formatBytes(int n) {
  if (n < 1024) return '$n B';
  final mb = n / (1024 * 1024);
  return mb < 1024
      ? '${mb.toStringAsFixed(1)} MiB'
      : '${(mb / 1024).toStringAsFixed(2)} GiB';
}

/// A centred empty state that scrolls rather than overflowing.
///
/// `Center` inside a bounded box is fine until the text doubles. At 200% scale on a 360 px
/// phone these notices are taller than the space they sit in, and `Center` clips — so the
/// user with large text set is exactly the user who cannot read the explanation of why the
/// screen is empty. Scrolling keeps "centred when it fits" and adds "reachable when it
/// does not".
class CenteredNotice extends StatelessWidget {
  const CenteredNotice({
    required this.icon,
    required this.title,
    this.body,
    this.maxWidth = 420,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 40, color: context.wk.mutedForeground),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: context.texts.titleMedium,
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        body!,
                        textAlign: TextAlign.center,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.wk.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatEpoch(AppLocalizations l10n, int? epochSeconds) {
  if (epochSeconds == null) return l10n.commonUnknown;
  return DateTime.fromMillisecondsSinceEpoch(
    epochSeconds * 1000,
  ).toLocal().toString().split('.').first;
}

/// A confirmation dialog for something destructive.
///
/// Full-screen on a phone so the consequences are actually legible, rather than an inset
/// box competing with the keyboard.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? detail,
  bool fullScreen = false,
}) async {
  final content = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message, style: context.texts.bodyMedium),
      if (detail != null) ...[
        const SizedBox(height: 12),
        SelectableText(detail, style: monoStyle(context, fontSize: 11)),
      ],
    ],
  );

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.warning_amber, color: context.colors.error),
      title: Text(title),
      content: fullScreen
          ? content
          : SizedBox(width: 460, child: SingleChildScrollView(child: content)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.error,
            foregroundColor: context.colors.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
