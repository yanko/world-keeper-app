import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/ssh/host_key_store.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Asks the user to accept a host key.
///
/// Two very different situations share this dialog, and they are styled to look
/// different on purpose:
///
/// * **Unknown** — first connection. Routine, but the fingerprint is shown in the same
///   `SHA256:…` form `ssh-keygen -lf` prints so it can actually be compared against the
///   server, and it is copyable for exactly that reason.
/// * **Changed** — the pinned key no longer matches. Either the server was rebuilt or the
///   connection is being intercepted, and nothing here can tell which. Accepting is
///   deliberately made deliberate: destructive styling, both fingerprints shown, and no
///   default focus on the accept button.
Future<bool> showHostKeyDialog(
  BuildContext context, {
  required String host,
  required int port,
  required String type,
  required String fingerprint,
  required HostKeyVerdict verdict,
  required String? pinnedFingerprint,
}) async {
  final changed = verdict == HostKeyVerdict.mismatch;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(
        changed ? Icons.gpp_maybe : Icons.gpp_good_outlined,
        color: changed ? context.colors.error : context.wk.signalText,
      ),
      title: Text(
        changed
            ? context.l10n.hostKeyChangedTitle
            : context.l10n.hostKeyNewTitle,
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              changed
                  ? context.l10n.hostKeyChangedBody('$host:$port')
                  : context.l10n.hostKeyNewBody('$host:$port'),
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: 16),
            if (changed && pinnedFingerprint != null) ...[
              _FingerprintRow(
                label: context.l10n.hostKeyPreviouslyPinned,
                value: pinnedFingerprint,
                color: context.wk.mutedForeground,
              ),
              const SizedBox(height: 8),
            ],
            _FingerprintRow(
              label: changed
                  ? context.l10n.hostKeyPresentedNow
                  // The key type is protocol vocabulary ("ssh-ed25519"), so it goes in
                  // as a value rather than being folded into the sentence.
                  : context.l10n.hostKeyFingerprintOf(type),
              value: fingerprint,
              color: changed ? context.colors.error : null,
            ),
            if (!changed) ...[
              const SizedBox(height: 16),
              SelectableText(
                '${context.l10n.hostKeyVerifyWith}\n'
                'ssh-keygen -lf /etc/ssh/ssh_host_${type.replaceFirst('ssh-', '')}_key.pub',
                style: monoStyle(
                  context,
                  fontSize: 11,
                  color: context.wk.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        if (changed)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.hostKeyAcceptNew),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.hostKeyTrustAndConnect),
          ),
      ],
    ),
  );

  return accepted ?? false;
}

class _FingerprintRow extends StatelessWidget {
  const _FingerprintRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: context.wk.mutedForeground,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: monoStyle(context, fontSize: 12, color: color),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: context.l10n.hostKeyCopyFingerprint,
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            ),
          ],
        ),
      ],
    );
  }
}
