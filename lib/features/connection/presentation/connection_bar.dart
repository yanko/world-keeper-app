import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/features/connection/domain/connection_status.dart';
import 'package:world_keeper/features/connection/presentation/host_key_dialog.dart';
import 'package:world_keeper/features/connection/presentation/profile_dialog.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Profile selection, connect/disconnect, and the one-time switch to key auth.
///
/// Everything here is disabled while connected — switching profiles mid-session was
/// never a supported operation, and the original app only enforced that by ignoring the
/// change rather than preventing it.
class ConnectionBar extends ConsumerWidget {
  const ConnectionBar({this.compact = false, super.key});

  /// Laid out as a vertical sheet rather than a horizontal bar.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final connection = ref.watch(connectionProvider);
    final selectedId = ref.watch(selectedProfileIdProvider);

    return config.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('$e', style: TextStyle(color: context.colors.error)),
      ),
      data: (cfg) {
        final selected = selectedId == null
            ? null
            : cfg.profileById(selectedId);
        final children = _controls(context, ref, cfg, selected, connection);

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: child,
                ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        );
      },
    );
  }

  List<Widget> _controls(
    BuildContext context,
    WidgetRef ref,
    AppConfig cfg,
    Profile? selected,
    ConnectionStatus connection,
  ) {
    final canEdit = connection.allowsProfileEditing && selected != null;

    return [
      SizedBox(
        width: compact ? double.infinity : 240,
        child: DropdownButtonFormField<String>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.l10n.connectionProfile,
          ),
          items: [
            for (final p in cfg.profiles)
              DropdownMenuItem(
                value: p.id,
                child: Text(
                  '${p.name}  (${p.user}@${p.host})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: connection.allowsProfileEditing
              ? (v) {
                  if (v != null) {
                    ref.read(selectedProfileIdProvider.notifier).select(v);
                  }
                }
              : null,
        ),
      ),
      OutlinedButton.icon(
        onPressed: connection.allowsProfileEditing
            ? () => _newProfile(context, ref)
            : null,
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.l10n.connectionNew),
      ),
      OutlinedButton.icon(
        onPressed: canEdit ? () => _editProfile(context, ref, selected) : null,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(context.l10n.connectionEdit),
      ),
      OutlinedButton.icon(
        onPressed: canEdit
            ? () => _deleteProfile(context, ref, selected)
            : null,
        icon: const Icon(Icons.delete_outline, size: 18),
        label: Text(context.l10n.connectionDelete),
      ),
      // Only while connected with a password: installing a key needs an authenticated
      // session to install it over, and a profile already on key auth has nothing to
      // gain. Hidden rather than disabled — a permanently greyed button on a
      // key-auth profile is a question nobody can answer.
      if (connection.isConnected && selected?.auth == AuthMethod.password)
        OutlinedButton.icon(
          onPressed: () => _setUpKeyAuth(context, ref, selected!),
          icon: const Icon(Icons.key_outlined, size: 18),
          label: Text(context.l10n.keyAuthSetUp),
        ),
      if (connection.isConnected)
        FilledButton.tonalIcon(
          onPressed: () => ref.read(connectionProvider.notifier).disconnect(),
          icon: const Icon(Icons.link_off, size: 18),
          label: Text(context.l10n.connectionDisconnect),
        )
      else
        FilledButton.icon(
          onPressed: selected == null || connection.isBusy
              ? null
              : () => _connect(context, ref, selected),
          icon: const Icon(Icons.bolt, size: 18),
          label: Text(
            connection.isBusy
                ? context.l10n.connectionConnecting
                : context.l10n.connectionConnect,
          ),
        ),
      if (!compact) ConnectionStatusChip(status: connection),
    ];
  }

  /// Generates a key, installs it on the server, and switches the profile over.
  ///
  /// Confirmed first because it writes to the host — one line appended to
  /// `~/.ssh/authorized_keys` — and because it changes how this profile authenticates
  /// from here on. Neither is destructive, which is why this is an ordinary confirmation
  /// rather than the red one used for stopping a server.
  Future<void> _setUpKeyAuth(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.key_outlined),
        title: Text(l10n.keyAuthConfirmTitle(profile.name)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.keyAuthConfirmBody, style: context.texts.bodyMedium),
              const SizedBox(height: 12),
              Text(
                l10n.keyAuthConfirmDetail,
                style: context.texts.bodySmall?.copyWith(
                  color: context.wk.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.keyAuthConfirmButton),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(connectionProvider.notifier).setUpKeyAuth();
      messenger?.showSnackBar(SnackBar(content: Text(l10n.keyAuthDone)));
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _newProfile(BuildContext context, WidgetRef ref) async {
    final profile = await showProfileDialog(context);
    if (profile == null) return;
    await ref.read(configProvider.notifier).upsertProfile(profile);
    ref.read(selectedProfileIdProvider.notifier).select(profile.id);
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    Profile existing,
  ) async {
    final profile = await showProfileDialog(context, existing: existing);
    if (profile == null) return;
    await ref.read(configProvider.notifier).upsertProfile(profile);
  }

  Future<void> _deleteProfile(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.connectionDeleteTitle(profile.name)),
        content: Text(context.l10n.connectionDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.connectionDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(configProvider.notifier).deleteProfile(profile.id);
    }
  }

  Future<void> _connect(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    String? password;
    if (profile.auth == AuthMethod.password) {
      password = await _askPassword(context, profile);
      if (password == null) return;
      // The password dialog is an async gap; the bar could have been disposed while it
      // was open (a window close, or a navigation away).
      if (!context.mounted) return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(connectionProvider.notifier)
          .connect(
            profile,
            password: password,
            onHostKey:
                ({
                  required host,
                  required port,
                  required type,
                  required fingerprint,
                  required verdict,
                  required pinnedFingerprint,
                }) async {
                  if (!context.mounted) return false;
                  return await showHostKeyDialog(
                    context,
                    host: host,
                    port: port,
                    type: type,
                    fingerprint: fingerprint,
                    verdict: verdict,
                    pinnedFingerprint: pinnedFingerprint,
                  );
                },
          );
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<String?> _askPassword(BuildContext context, Profile profile) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.connectionPasswordTitle(profile.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.connectionPasswordBody(
                '${profile.user}@${profile.host}',
              ),
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.connectionPasswordLabel,
              ),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.connectionConnect),
          ),
        ],
      ),
    );
  }
}

/// The status dot and label. The one place the signal colour appears in chrome, because
/// "connected and ready" is exactly the live/healthy state it is reserved for.
class ConnectionStatusChip extends StatelessWidget {
  const ConnectionStatusChip({
    required this.status,
    this.dense = false,
    super.key,
  });

  final ConnectionStatus status;

  /// Drops the text and keeps the dot, for the compact app bar.
  ///
  /// "Disconnected" at 200% text scale is ~140 px, which with two icon buttons left the
  /// title 94 px of a 360 px bar and overflowed it by 76. The colour is the signal here
  /// anyway; the words go to [Semantics], so a screen reader still gets the full status
  /// rather than a coloured circle.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = switch (status) {
      Disconnected() => (
        l10n.connectionStatusDisconnected,
        context.wk.mutedForeground,
      ),
      Connecting() => (
        l10n.connectionStatusConnecting,
        context.wk.mutedForeground,
      ),
      ConnectedRaw() => (
        l10n.connectionStatusNeedsDiscovery,
        context.colors.error,
      ),
      ConnectedTarget() => (
        l10n.connectionStatusConnected,
        context.wk.signalText,
      ),
    };

    return Semantics(
      label: l10n.connectionStatusSemantics(label),
      // Without this the label below would be read out twice.
      excludeSemantics: true,
      child: Tooltip(
        message: dense ? label : '',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            color: color.withValues(alpha: 0.10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!dense) ...[
                const SizedBox(width: 8),
                Text(label, style: context.texts.labelMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
