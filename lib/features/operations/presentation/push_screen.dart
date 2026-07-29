import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/operations/data/local_world_resolver.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/features/operations/data/operations_controller.dart';
import 'package:world_keeper/features/operations/domain/local_world.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';
import 'package:world_keeper/features/operations/presentation/file_pickers.dart';
import 'package:world_keeper/features/operations/presentation/operation_widgets.dart';
import 'package:world_keeper/features/operations/presentation/stepper.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Swapping a world in.
///
/// The most destructive thing this app does, so the flow is deliberately unhurried: pick,
/// see exactly what was found, choose a slot if the filename didn't say, then confirm
/// against a description of what is about to happen.
class PushScreen extends ConsumerStatefulWidget {
  const PushScreen({super.key});

  @override
  ConsumerState<PushScreen> createState() => _PushScreenState();
}

class _PushScreenState extends ConsumerState<PushScreen> {
  List<LocalWorldCandidate> _candidates = const [];
  int? _selectedSlot;
  String? _resolveError;

  /// The slot for a file whose name didn't encode one. Doubles as the way to seed a new
  /// slot from an arbitrary export.
  int _manualSlot = 0;

  static List<StepDef<PushState>> _steps(AppLocalizations l10n) => [
    StepDef(PushState.uploading, l10n.stepUpload),
    StepDef(PushState.checkingService, l10n.stepCheck),
    StepDef(PushState.stopping, l10n.stepStop),
    StepDef(PushState.backingUp, l10n.stepBackUp),
    StepDef(PushState.copying, l10n.stepCopyIn),
    StepDef(PushState.fixingPerms, l10n.stepPerms),
    StepDef(PushState.starting, l10n.stepStart),
    StepDef(PushState.capturingGameId, l10n.stepGameId),
    StepDef(PushState.verifying, l10n.stepVerify),
  ];

  bool get _isUnassigned =>
      _candidates.length == 1 && !_candidates.single.slotInferred;

  LocalWorldCandidate? get _chosen {
    if (_candidates.isEmpty) return null;
    if (_isUnassigned) return _candidates.single.withSlot(_manualSlot);
    return _candidates.where((c) => c.slot == _selectedSlot).firstOrNull;
  }

  Future<void> _pick({required bool folder}) async {
    final l10n = context.l10n;
    final path = folder
        ? await FilePickers.pickWorldFolder(
            dialogTitle: l10n.pickerChooseFolder,
          )
        : await FilePickers.pickWorldFile(dialogTitle: l10n.pickerChooseFile);
    if (path == null) return;

    try {
      final found = await const LocalWorldResolver().resolve(path);
      if (!mounted) return;
      setState(() {
        _candidates = found;
        _selectedSlot = found.first.slot;
        _manualSlot = 0;
        _resolveError = null;
      });
      ref.read(operationsProvider.notifier).resetPush();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _candidates = const [];
        _resolveError = e is Exception ? '$e'.replaceFirst('push: ', '') : '$e';
      });
    }
  }

  Future<void> _confirmAndPush() async {
    final candidate = _chosen;
    if (candidate == null) return;

    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.pushConfirmTitle(candidate.slot),
      message: l10n.pushConfirmBody,
      detail: candidate.mainPath,
      confirmLabel: l10n.pushConfirmButton,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(operationsProvider.notifier).startPush(candidate);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l10n.pushDoneToast(candidate.slot))),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ops = ref.watch(operationsProvider);
    final run = ops.push;
    // Disabled while *any* operation runs, not just this one — they cannot overlap.
    final busy = ops.isBusy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(l10n.pushTitle, subtitle: l10n.pushSubtitle),
        const SizedBox(height: 16),

        if (ops.active != null && ops.active != OperationKind.push) ...[
          OtherOperationBanner(active: ops.active!),
          const SizedBox(height: 12),
        ],

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : () => _pick(folder: false),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(l10n.pushChooseFile),
            ),
            // Folder picking is a desktop idea; a phone has a document provider, not a
            // browsable tree, so the button is hidden rather than shown broken.
            if (FilePickers.supportsFolders)
              OutlinedButton.icon(
                onPressed: busy ? null : () => _pick(folder: true),
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(l10n.pushChooseFolder),
              ),
          ],
        ),

        if (_resolveError != null) ...[
          const SizedBox(height: 12),
          Text(
            _resolveError!,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.error,
            ),
          ),
        ],

        if (_candidates.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CandidatePicker(
            candidates: _candidates,
            isUnassigned: _isUnassigned,
            selectedSlot: _selectedSlot,
            manualSlot: _manualSlot,
            onSelectSlot: (s) => setState(() => _selectedSlot = s),
            onManualSlot: (s) => setState(() => _manualSlot = s),
          ),
          const SizedBox(height: 12),
          if (MobileInterruptionWarning.isRelevant) ...[
            const MobileInterruptionWarning(),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: busy || _chosen == null ? null : _confirmAndPush,
            icon: const Icon(Icons.upload, size: 18),
            label: Text(
              _chosen == null
                  ? l10n.pushButton
                  : l10n.pushButtonIntoSlot(_chosen!.slot),
            ),
          ),
        ],

        if (run.running && run.transferTotal > 0) ...[
          const SizedBox(height: 16),
          TransferProgress(
            label: l10n.pushUploading,
            transferred: run.transferred,
            total: run.transferTotal,
          ),
        ],

        if (run.log.isNotEmpty) ...[
          const SizedBox(height: 16),
          OperationStepper<PushState>(
            steps: _steps(l10n),
            log: run.log,
            doneState: PushState.done,
            failedStates: const [PushState.rollingBack, PushState.failed],
            failedBanner: l10n.pushFailedBanner,
          ),
        ],

        if (!run.running && run.result != null) ...[
          const SizedBox(height: 16),
          _PushResultCard(result: run.result!),
        ],

        if (!run.running && run.error != null) ...[
          const SizedBox(height: 16),
          Text(
            run.error!,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _CandidatePicker extends StatelessWidget {
  const _CandidatePicker({
    required this.candidates,
    required this.isUnassigned,
    required this.selectedSlot,
    required this.manualSlot,
    required this.onSelectSlot,
    required this.onManualSlot,
  });

  final List<LocalWorldCandidate> candidates;
  final bool isUnassigned;
  final int? selectedSlot;
  final int manualSlot;
  final ValueChanged<int> onSelectSlot;
  final ValueChanged<int> onManualSlot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUnassigned) ...[
            Text(
              l10n.pushUnassignedSlot,
              style: context.texts.bodySmall?.copyWith(
                color: context.wk.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.pushSlot),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    initialValue: '$manualSlot',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => onManualSlot(int.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
          ] else if (candidates.length > 1) ...[
            Text(
              l10n.pushFoundWorlds(candidates.length),
              style: context.texts.bodySmall?.copyWith(
                color: context.wk.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            for (final c in candidates)
              RadioListTile<int>(
                value: c.slot,
                // ignore: deprecated_member_use
                groupValue: selectedSlot,
                // ignore: deprecated_member_use
                onChanged: (v) => v == null ? null : onSelectSlot(v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.slotOption(
                    c.slot,
                    formatBytes(c.mainSize),
                    formatEpoch(l10n, c.mainModified),
                  ),
                  style: monoStyle(context, fontSize: 12),
                ),
              ),
          ],

          if (candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              (isUnassigned
                      ? candidates.single
                      : candidates
                                .where((c) => c.slot == selectedSlot)
                                .firstOrNull ??
                            candidates.first)
                  .mainPath,
              style: monoStyle(
                context,
                fontSize: 11,
                color: context.wk.mutedForeground,
              ),
            ),
            if ((isUnassigned
                        ? candidates.single
                        : candidates
                              .where((c) => c.slot == selectedSlot)
                              .firstOrNull)
                    ?.hasPugbackup ??
                false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.pushPugbackupNote,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.wk.mutedForeground,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PushResultCard extends StatelessWidget {
  const _PushResultCard({required this.result});

  final PushResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(Icons.check_circle, size: 18, color: context.wk.signalText),
              const SizedBox(width: 8),
              Text(
                l10n.pushResultLive(result.slot),
                style: context.texts.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.pushResultUploaded(formatBytes(result.bytesUploaded)) +
                (result.gameId == null
                    ? ''
                    : ' · ${l10n.resultGameId(result.gameId!)}'),
            style: context.texts.bodySmall,
          ),
          if (result.backupPath != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              l10n.pushResultBackedUpTo(result.backupPath!),
              style: monoStyle(
                context,
                fontSize: 11,
                color: context.wk.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
