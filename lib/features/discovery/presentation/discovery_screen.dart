import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/discovery/data/discovery_probe.dart';
import 'package:world_keeper/features/discovery/domain/discovery_result.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Runs the discovery probe and asks the user to confirm what it found.
///
/// **Nothing is saved until confirmed.** That is the rule the whole target-agnostic
/// design rests on: the probe reports, the user decides. Where the probe found several
/// plausible services it presents all of them with the likeliest first, and where it
/// found nothing it takes manual input — but it never picks for you.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  DiscoveryResult? _result;
  Object? _error;
  bool _probing = false;
  bool _saving = false;

  /// What was written the last time Confirm succeeded, or null.
  ///
  /// Confirm used to write the discovery, unlock every other screen, and show nothing at
  /// all — the only visible change was an 8px dot at the top of the app bar going from
  /// red to teal. Holding the saved value here lets the screen say what it did.
  Discovered? _confirmed;

  ServiceKind? _chosenKind;
  String? _chosenWorldsPath;
  final _manualUnit = TextEditingController();
  final _manualWorldsPath = TextEditingController();

  /// Where a bare-process server writes its log.
  ///
  /// Only shown for a process target, because systemd has the journal and Docker has its
  /// own log by construction. Without it that target has no live log *and* no game id,
  /// since the id is parsed out of the log.
  final _logPath = TextEditingController();

  @override
  void dispose() {
    _manualUnit.dispose();
    _manualWorldsPath.dispose();
    _logPath.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    final session = ref.read(connectionProvider).session;
    if (session == null) return;

    setState(() {
      _probing = true;
      _error = null;
    });

    try {
      final result = await DiscoveryProbe(session).probe();
      if (!mounted) return;
      setState(() {
        _result = result;
        // A derived path is a suggestion to confirm, not a finding — so it goes into the
        // manual field rather than being selected as though the host had reported it.
        // Blank is the wrong default here: it asks the user to know a Unity directory
        // layout by heart on the one screen where they have least context.
        if (result.expectedWorldsPath != null &&
            _manualWorldsPath.text.trim().isEmpty) {
          _manualWorldsPath.text = result.expectedWorldsPath!;
        }
        final found = result.serviceKind;
        if (found is ProcessService && found.logPath != null) {
          _logPath.text = found.logPath!;
        }
        // A fresh probe supersedes whatever was confirmed before it; leaving the old
        // success panel up would claim the new findings had been saved.
        _confirmed = null;
        // Pre-select the best guess so confirming is one click, never a coin flip.
        _chosenKind =
            result.serviceKind ??
            result.serviceKindCandidates.firstOrNull?.kind;
        _chosenWorldsPath =
            result.worldsPath ?? result.worldsPathCandidates.firstOrNull;
      });

      await ref
          .read(auditDatabaseProvider)
          .logEvent(
            ref.read(auditSessionIdProvider),
            'discover',
            detail: {
              'os': result.os,
              'serviceKind': result.serviceKind?.label,
              'candidates': result.serviceKindCandidates.length,
              'worldsPath': result.worldsPath,
            },
            ok: true,
          );
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  ServiceKind? get _resolvedKind {
    final chosen = _chosenKind;
    // The log path is edited separately from the service that was discovered, so it is
    // folded back in here rather than mutating the probe's finding.
    if (chosen is ProcessService) {
      final log = _logPath.text.trim();
      return ProcessService(
        startCmd: chosen.startCmd,
        stopCmd: chosen.stopCmd,
        logPath: log.isEmpty ? null : log,
      );
    }
    if (chosen != null) return chosen;

    final manual = _manualUnit.text.trim();
    if (manual.isNotEmpty) return SystemdService(unit: manual);
    return null;
  }

  String? get _resolvedWorldsPath {
    final chosen = _chosenWorldsPath;
    if (chosen != null && chosen.isNotEmpty) return chosen;
    final manual = _manualWorldsPath.text.trim();
    return manual.isEmpty ? null : manual;
  }

  Future<void> _confirm() async {
    final result = _result;
    final kind = _resolvedKind;
    final worldsPath = _resolvedWorldsPath;
    final connection = ref.read(connectionProvider);
    final profile = connection.profile;
    if (result == null || profile == null) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (kind == null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.discoveryPickService)),
      );
      return;
    }
    if (worldsPath == null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.discoveryPickWorldsPath)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final discovered = Discovered(
        os: result.os,
        serviceKind: kind,
        worldsPath: worldsPath,
        steamUser: _steamUserFor(kind, result),
        launchScript: result.launchScript,
        probedAt: result.probedAt,
      );

      await ref
          .read(configProvider.notifier)
          .setDiscovered(profile.id, discovered);
      ref.read(connectionProvider.notifier).applyDiscovery(discovered);

      await ref
          .read(auditDatabaseProvider)
          .logEvent(
            ref.read(auditSessionIdProvider),
            'discover_confirmed',
            detail: {
              'profileId': profile.id,
              'serviceKind': kind.label,
              'worldsPath': worldsPath,
            },
            ok: true,
          );

      if (mounted) setState(() => _confirmed = discovered);
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.discoveryConfirmedToast)),
      );
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The steam user comes from whichever candidate was actually selected, not from the
  /// top-level result — picking the second candidate must not inherit the first's user.
  String? _steamUserFor(ServiceKind kind, DiscoveryResult result) {
    for (final c in result.serviceKindCandidates) {
      if (c.kind == kind) return c.steamUser;
    }
    return result.steamUser;
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);
    final l10n = context.l10n;
    if (!connection.isConnected) {
      return _Centered(l10n.discoveryConnectFirst);
    }

    final result = _result;
    final confirmed = _confirmed;

    // Once it is saved the form has nothing left to ask, and leaving it up invites a
    // second Confirm on the same values.
    if (confirmed != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConfirmedPanel(
            discovered: confirmed,
            onChange: () => setState(() => _confirmed = null),
          ),
          if (result != null) ...[
            const SizedBox(height: 16),
            ProbeTranscript(trace: result.trace),
          ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.discoveryTitle, style: context.texts.titleLarge),
                  Text(
                    l10n.discoverySubtitle,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.wk.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _probing ? null : _probe,
              icon: _probing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar, size: 18),
              label: Text(
                result == null ? l10n.discoveryRunProbe : l10n.discoveryRescan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_error != null)
          _Banner(
            color: context.colors.error,
            icon: Icons.error_outline,
            child: Text('$_error'),
          )
        else if (result == null)
          _Banner(
            color: context.wk.mutedForeground,
            icon: Icons.help_outline,
            child: Text(l10n.discoveryRunProbeHint),
          )
        else ...[
          _Field(
            label: l10n.discoveryOperatingSystem,
            child: Text(
              result.os ?? l10n.discoveryUnknownOs,
              style: monoStyle(context, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          _serviceSection(result),
          if (_resolvedKind is ProcessService) ...[
            const SizedBox(height: 16),
            _Field(
              label: l10n.discoveryLogPath,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _logPath,
                    decoration: InputDecoration(
                      labelText: l10n.discoveryLogPathLabel,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.discoveryLogPathHint,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.wk.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _worldsSection(result),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _confirm,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(
                  _saving ? l10n.discoverySaving : l10n.discoveryConfirm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ProbeTranscript(trace: result.trace),
        ],
      ],
    );
  }

  Widget _serviceSection(DiscoveryResult result) {
    final l10n = context.l10n;
    if (result.serviceKind != null) {
      return _Field(
        label: l10n.discoveryService,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.serviceKind!.label,
              style: monoStyle(context, fontSize: 13),
            ),
            if (result.launchScript != null)
              Text(
                result.launchScript!,
                style: monoStyle(
                  context,
                  fontSize: 11,
                  color: context.wk.mutedForeground,
                ),
              ),
          ],
        ),
      );
    }

    if (result.serviceKindCandidates.isNotEmpty) {
      return _Field(
        label: l10n.discoveryServiceSeveral,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in result.serviceKindCandidates)
              RadioListTile<ServiceKind>(
                value: c.kind,
                // ignore: deprecated_member_use
                groupValue: _chosenKind,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _chosenKind = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  c.kind.label,
                  style: monoStyle(context, fontSize: 13),
                ),
                subtitle: c.execStart == null
                    ? null
                    : Text(
                        c.execStart!,
                        style: monoStyle(
                          context,
                          fontSize: 11,
                          color: context.wk.mutedForeground,
                        ),
                      ),
              ),
          ],
        ),
      );
    }

    return _Field(
      label: l10n.discoveryServiceNone,
      child: TextField(
        controller: _manualUnit,
        decoration: InputDecoration(
          labelText: l10n.discoverySystemdUnitName,
          // A plausible unit name, not prose.
          hintText: 'corekeeper',
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _worldsSection(DiscoveryResult result) {
    final l10n = context.l10n;
    if (result.worldsPath != null) {
      return _Field(
        label: l10n.discoveryWorldsPath,
        child: SelectableText(
          result.worldsPath!,
          style: monoStyle(context, fontSize: 13),
        ),
      );
    }

    if (result.worldsPathCandidates.isNotEmpty) {
      return _Field(
        label: l10n.discoveryWorldsPathSeveral,
        child: Column(
          children: [
            for (final path in result.worldsPathCandidates)
              RadioListTile<String>(
                value: path,
                // ignore: deprecated_member_use
                groupValue: _chosenWorldsPath,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _chosenWorldsPath = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(path, style: monoStyle(context, fontSize: 12)),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "None found" is the wrong thing to say when the server's filesystem was never
        // reachable in the first place. It sends you looking for a missing directory
        // instead of at the one thing that would fix it.
        if (result.isInAnotherNamespace) ...[
          _Banner(
            color: context.colors.error,
            icon: Icons.layers_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.discoveryDifferentNamespaceTitle,
                  style: context.texts.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(l10n.discoveryDifferentNamespaceBody),
                const SizedBox(height: 6),
                SelectableText(
                  result.containerRoot!,
                  style: monoStyle(context, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _Field(
          label: l10n.discoveryWorldsPathNone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _manualWorldsPath,
                decoration: InputDecoration(
                  labelText: l10n.discoveryWorldsPathLabel,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (result.expectedWorldsPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.discoveryWorldsPathExpected,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.wk.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.texts.labelMedium?.copyWith(
            color: context.wk.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: context.texts.bodySmall ?? const TextStyle(),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      message,
      style: context.texts.bodyMedium?.copyWith(
        color: context.wk.mutedForeground,
      ),
    ),
  );
}

/// What Confirm actually wrote. Public for the same reason as [ProbeTranscript].
///
/// The screen's job was over the moment the value was saved, and it used to end by simply
/// looking unchanged. This is the receipt: the exact three values now stored against the
/// profile, and a way back if any of them is wrong.
class ConfirmedPanel extends StatelessWidget {
  const ConfirmedPanel({
    required this.discovered,
    required this.onChange,
    super.key,
  });

  final Discovered discovered;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.wk.signalSurface,
        border: Border.all(color: context.wk.signalBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: context.wk.signalText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.discoveryConfirmedTitle,
                  style: context.texts.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.discoveryConfirmedBody,
            style: context.texts.bodySmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          // Both are nullable on the model because `Discovered` is also what the config
          // file deserialises into, and an older file can be missing either. Reaching
          // here they are always set — `_confirm` refuses to save without them.
          _SavedValue(
            label: l10n.discoveryService,
            value: discovered.serviceKind?.label ?? l10n.commonUnknown,
          ),
          _SavedValue(
            label: l10n.discoveryWorldsPath,
            value: discovered.worldsPath ?? l10n.commonUnknown,
          ),
          if (discovered.steamUser != null)
            _SavedValue(
              label: l10n.discoverySteamUser,
              value: discovered.steamUser!,
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.discoveryChange),
          ),
        ],
      ),
    );
  }
}

class _SavedValue extends StatelessWidget {
  const _SavedValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: context.wk.mutedForeground,
          ),
        ),
        SelectableText(value, style: monoStyle(context, fontSize: 12)),
      ],
    ),
  );
}

/// Every command the probe ran, collapsed.
///
/// Public so it can be pumped on its own — the screen around it needs a live SSH session
/// to reach this state, and a panel whose whole job is explaining a failure should be
/// testable without one.
///
/// "Worlds path — none found" is true and useless on its own: it does not say where it
/// looked, whether `find` ran at all, or whether the host answered. Those are three
/// different problems with three different fixes, and telling them apart used to mean
/// opening an SSH session yourself — which is the thing this screen exists to avoid.
///
/// Collapsed by default because on a host where discovery works nobody needs it, and one
/// tap away because on a host where it does not, it is the only thing that matters.
class ProbeTranscript extends StatelessWidget {
  const ProbeTranscript({required this.trace, super.key});

  final List<ProbeStep> trace;

  @override
  Widget build(BuildContext context) {
    if (trace.isEmpty) return const SizedBox.shrink();

    final failures = trace.where((s) => !s.succeeded).length;

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(
          failures > 0 ? Icons.error_outline : Icons.terminal,
          size: 20,
          color: failures > 0
              ? context.colors.error
              : context.wk.mutedForeground,
        ),
        title: Text(
          context.l10n.discoveryTranscriptTitle,
          style: context.texts.titleSmall,
        ),
        subtitle: Text(
          failures > 0
              ? context.l10n.discoveryTranscriptSummaryFailures(
                  trace.length,
                  failures,
                )
              : context.l10n.discoveryTranscriptSummary(trace.length),
          style: context.texts.bodySmall?.copyWith(
            color: failures > 0
                ? context.colors.error
                : context.wk.mutedForeground,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final copied = context.l10n.discoveryTranscriptCopied;
                await Clipboard.setData(
                  ClipboardData(text: transcriptAsText(trace)),
                );
                messenger?.showSnackBar(SnackBar(content: Text(copied)));
              },
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: Text(context.l10n.discoveryTranscriptCopy),
            ),
          ),
          for (final step in trace) _TranscriptStep(step: step),
        ],
      ),
    );
  }
}

class _TranscriptStep extends StatelessWidget {
  const _TranscriptStep({required this.step});

  final ProbeStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Three outcomes, not two. A command that ran and found nothing is a correct answer;
    // one that could not run is a broken probe, and they must not look alike.
    final (icon, colour) = switch ((step.succeeded, step.foundNothing)) {
      (false, _) => (Icons.close, context.colors.error),
      (true, true) => (Icons.remove, context.wk.mutedForeground),
      (true, false) => (Icons.check, context.wk.signalText),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 14, color: colour),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    step.command,
                    style: monoStyle(context, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.discoveryTranscriptExit(step.exitStatus),
                style: context.texts.labelSmall?.copyWith(color: colour),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: step.preview().isEmpty
                ? Text(
                    l10n.discoveryTranscriptNoOutput,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.wk.mutedForeground,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      step.preview(),
                      style: monoStyle(
                        context,
                        fontSize: 10,
                        color: context.wk.mutedForeground,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The transcript as plain text, for pasting into a bug report.
///
/// Untruncated on purpose: the on-screen version caps each command's output so a
/// `find /` cannot lock up the list, but the whole point of copying it is to send
/// somebody the part that got cut off.
String transcriptAsText(List<ProbeStep> trace) {
  final buffer = StringBuffer();
  for (final step in trace) {
    buffer.writeln('\$ ${step.command}');
    buffer.writeln(
      '# exit ${step.exitStatus} (${step.duration.inMilliseconds} ms)',
    );
    if (step.stdout.trim().isNotEmpty) buffer.writeln(step.stdout.trimRight());
    if (step.stderr.trim().isNotEmpty) {
      buffer.writeln('stderr: ${step.stderr.trimRight()}');
    }
    buffer.writeln();
  }
  return buffer.toString();
}
