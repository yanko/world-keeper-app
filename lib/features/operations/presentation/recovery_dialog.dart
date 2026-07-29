import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/features/operations/data/operation_journal.dart';
import 'package:world_keeper/features/operations/presentation/operation_widgets.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Offers to finish what an interrupted operation left undone.
///
/// Shown on connecting to a server whose last operation never reported a result. The app
/// cannot know whether it left the service stopped — the process may have been killed a
/// millisecond before or after the start command — so it does not guess: it asks the
/// server, and reports what it finds.
///
/// Deliberately **not** a resume. Re-running a half-finished swap without knowing which
/// half finished is how you overwrite a world with a partial copy. Starting a stopped
/// service is safe, obvious and almost always the whole fix; anything more is a restore
/// from the World Library, which is a decision with its own two confirmations.
Future<void> showRecoveryDialog(
  BuildContext context,
  WidgetRef ref,
  InterruptedOperation marker,
) => showDialog<void>(
  context: context,
  builder: (_) => _RecoveryDialog(marker: marker),
);

class _RecoveryDialog extends ConsumerStatefulWidget {
  const _RecoveryDialog({required this.marker});

  final InterruptedOperation marker;

  @override
  ConsumerState<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends ConsumerState<_RecoveryDialog> {
  RunState? _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  /// Asks the server what state it is actually in.
  ///
  /// The marker says an operation was interrupted, not that the service is down — those
  /// are different claims, and only the server can settle the second one.
  Future<void> _check() async {
    final target = ref.read(targetProvider);
    if (target == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await target.status();
      if (mounted) setState(() => _status = status);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final target = ref.read(targetProvider);
    if (target == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await target.serviceControl(ServiceAction.start);
      await ref
          .read(auditDatabaseProvider)
          .logEvent(
            ref.read(auditSessionIdProvider),
            'recovery_start',
            detail: {
              'kind': widget.marker.kind.name,
              'interruptedAt': widget.marker.phase,
            },
            ok: true,
          );
      await _check();
      // Only once the service is up is the app no longer responsible for it being down.
      if (_status == RunState.running) await _dismiss();
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Clears the marker and closes.
  ///
  /// Dismissing is allowed even with the service still down: the user may want to look at
  /// the Terminal or the Library first, and a prompt that cannot be closed is a prompt
  /// people learn to fear rather than read.
  Future<void> _dismiss() async {
    // Deliberately no `ref.invalidate` of the provider that produced this marker. The
    // shell already refuses to re-show a prompt for the same profile, and re-running a
    // provider from inside the widget it is closing is how a dialog ends up racing its
    // own dismissal.
    await OperationJournal(ref.read(appPathsProvider)).clear();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stopped = _status == RunState.stopped || _status == RunState.failed;

    return AlertDialog(
      icon: Icon(Icons.restart_alt, color: context.colors.error),
      title: Text(l10n.recoveryTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recoveryBody(
                operationName(l10n, widget.marker.kind),
                widget.marker.phase,
              ),
              style: context.texts.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_busy && _status == null)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(l10n.recoveryChecking, style: context.texts.bodySmall),
                ],
              )
            else if (_status != null)
              Text(
                stopped ? l10n.recoveryStopped : l10n.recoveryRunning,
                style: context.texts.bodyMedium?.copyWith(
                  color: stopped ? context.colors.error : context.wk.signalText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (stopped) ...[
              const SizedBox(height: 8),
              Text(
                l10n.recoveryRestoreHint,
                style: context.texts.bodySmall?.copyWith(
                  color: context.wk.mutedForeground,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _dismiss,
          child: Text(l10n.recoveryDismiss),
        ),
        if (stopped)
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 18),
            label: Text(l10n.recoveryStartServer),
          ),
      ],
    );
  }
}
