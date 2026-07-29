import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Where the acknowledgement is remembered.
///
/// The `.v1` suffix is load-bearing rather than decoration: bump it whenever the warning
/// changes materially and everyone is shown the new one. Someone who agreed to a different
/// version of a warning has not agreed to this one.
const String disclaimerStorageKey = 'wk.disclaimer-acknowledged.v1';

/// Whether the safety notice has been acknowledged on this machine.
class DisclaimerController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(disclaimerStorageKey) ?? false;
  }

  Future<void> acknowledge() async {
    // Optimistic: the dialog is already gone, and failing to persist should mean seeing
    // the notice again next launch, not blocking on a write.
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(disclaimerStorageKey, true);
  }
}

final disclaimerAcknowledgedProvider =
    AsyncNotifierProvider<DisclaimerController, bool>(DisclaimerController.new);

/// Shows the safety notice once, then gets out of the way.
///
/// Wraps the shell rather than living inside it so the notice is up before any screen is
/// usable — the point is to be read *before* the first push, not alongside it.
class DisclaimerGate extends ConsumerStatefulWidget {
  const DisclaimerGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DisclaimerGate> createState() => _DisclaimerGateState();
}

class _DisclaimerGateState extends ConsumerState<DisclaimerGate> {
  /// Guards against a second dialog while the first is still up — `build` runs again for
  /// reasons that have nothing to do with this.
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final acknowledged = ref
        .watch(disclaimerAcknowledgedProvider)
        .asData
        ?.value;
    if (!_shown && acknowledged == false) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    }
    return widget.child;
  }

  Future<void> _show() async {
    if (!mounted) return;
    await showDisclaimer(context, mustAcknowledge: true);
    if (!mounted) return;
    await ref.read(disclaimerAcknowledgedProvider.notifier).acknowledge();
  }
}

/// The notice itself.
///
/// [mustAcknowledge] on first run: no barrier dismiss, no close button, one way out. When
/// re-opened from the menu it is an ordinary dialog — a warning you cannot re-read is a
/// worse warning, and the original app had no way back to it at all.
Future<void> showDisclaimer(
  BuildContext context, {
  bool mustAcknowledge = false,
}) => showDialog<void>(
  context: context,
  barrierDismissible: !mustAcknowledge,
  builder: (context) => PopScope(
    canPop: !mustAcknowledge,
    child: AlertDialog(
      icon: Icon(Icons.warning_amber, color: context.colors.error),
      title: Text(context.l10n.disclaimerTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.disclaimerBody1,
                style: context.texts.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.disclaimerBody2,
                style: context.texts.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.disclaimerBody3,
                style: context.texts.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.disclaimerBody4,
                style: context.texts.bodySmall?.copyWith(
                  color: context.wk.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!mustAcknowledge)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonClose),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.disclaimerAcknowledge),
        ),
      ],
    ),
  ),
);
