import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/features/operations/data/operations_controller.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';
import 'package:world_keeper/features/operations/presentation/file_pickers.dart';
import 'package:world_keeper/features/operations/presentation/operation_widgets.dart';
import 'package:world_keeper/features/operations/presentation/stepper.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Copying a world off the server.
///
/// Two distinct phases, and keeping them visually separate matters: the *server* part is
/// over in seconds, and only then does the user get asked where to keep the file. Making
/// someone answer a save dialog while their server is down would be the wrong shape
/// entirely.
class PullScreen extends ConsumerStatefulWidget {
  const PullScreen({super.key});

  @override
  ConsumerState<PullScreen> createState() => _PullScreenState();
}

class _PullScreenState extends ConsumerState<PullScreen> {
  List<RemoteWorldInfo>? _worlds;
  int? _selectedSlot;
  String? _listError;
  bool _loading = false;
  String? _savedPath;

  static List<StepDef<PullState>> _steps(AppLocalizations l10n) => [
    StepDef(PullState.checkingService, l10n.stepCheck),
    StepDef(PullState.stopping, l10n.stepStop),
    StepDef(PullState.downloading, l10n.stepDownload),
    StepDef(PullState.starting, l10n.stepRestart),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _listError = null;
    });
    try {
      final worlds = await ref
          .read(operationsProvider.notifier)
          .listRemoteWorlds();
      if (!mounted) return;
      setState(() {
        _worlds = worlds;
        _selectedSlot ??= worlds.firstOrNull?.slot;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _listError = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndPull() async {
    final slot = _selectedSlot;
    if (slot == null) return;

    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.pullConfirmTitle(slot),
      message: l10n.pullConfirmBody,
      confirmLabel: l10n.pullConfirmButton,
    );
    if (!confirmed || !mounted) return;

    setState(() => _savedPath = null);
    try {
      await ref.read(operationsProvider.notifier).startPull(slot);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _save({required bool asZip}) async {
    final pulled = ref.read(operationsProvider).pull.result;
    if (pulled == null) return;

    final l10n = context.l10n;
    final destination = asZip
        ? await FilePickers.saveZip(
            'world-${pulled.slot}.zip',
            dialogTitle: l10n.pickerSaveZip,
          )
        : await FilePickers.pickSaveFolder(dialogTitle: l10n.pickerSaveInto);
    if (destination == null || !mounted) return;

    try {
      final path = await ref
          .read(operationsProvider.notifier)
          .packagePulled(
            pulled: pulled,
            destination: destination,
            asZip: asZip,
          );
      if (mounted) setState(() => _savedPath = path);
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
    final run = ops.pull;
    final busy = ops.isBusy;
    final worlds = _worlds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          l10n.pullTitle,
          subtitle: l10n.pullSubtitle,
          trailing: OutlinedButton.icon(
            onPressed: busy || _loading ? null : _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(_loading ? l10n.commonLoading : l10n.commonRefresh),
          ),
        ),
        const SizedBox(height: 16),

        if (ops.active != null && ops.active != OperationKind.pull) ...[
          OtherOperationBanner(active: ops.active!),
          const SizedBox(height: 12),
        ],

        if (_listError != null)
          Text(
            _listError!,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.error,
            ),
          )
        else if (worlds == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (worlds.isEmpty)
          Text(
            l10n.worldsNoneOnServer,
            style: context.texts.bodySmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.outline),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (final w in worlds)
                  RadioListTile<int>(
                    value: w.slot,
                    // ignore: deprecated_member_use
                    groupValue: _selectedSlot,
                    // ignore: deprecated_member_use
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _selectedSlot = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.slotOption(
                        w.slot,
                        formatBytes(w.size),
                        formatEpoch(l10n, w.modified),
                      ),
                      style: monoStyle(context, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (MobileInterruptionWarning.isRelevant) ...[
            const MobileInterruptionWarning(),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: busy || _selectedSlot == null ? null : _confirmAndPull,
            icon: const Icon(Icons.download, size: 18),
            label: Text(
              _selectedSlot == null
                  ? l10n.pullButton
                  : l10n.pullButtonSlot(_selectedSlot!),
            ),
          ),
        ],

        if (run.running && run.transferTotal > 0) ...[
          const SizedBox(height: 16),
          TransferProgress(
            label: l10n.pullDownloading,
            transferred: run.transferred,
            total: run.transferTotal,
          ),
        ],

        if (run.log.isNotEmpty) ...[
          const SizedBox(height: 16),
          OperationStepper<PullState>(
            steps: _steps(l10n),
            log: run.log,
            doneState: PullState.done,
            failedStates: const [PullState.failed],
            failedBanner: l10n.pullFailedBanner,
          ),
        ],

        // The server is already back up by this point; saving is purely local.
        if (!run.running && run.result != null && _savedPath == null) ...[
          const SizedBox(height: 16),
          _SavePrompt(
            slot: run.result!.slot,
            bytes: run.result!.bytes,
            onSaveFolder: FilePickers.supportsFolders
                ? () => _save(asZip: false)
                : null,
            onSaveZip: () => _save(asZip: true),
          ),
        ],

        if (_savedPath != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.wk.signalSurface,
              border: Border.all(color: context.wk.signalBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: context.wk.signalText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    l10n.pullSavedTo(_savedPath!),
                    style: monoStyle(context, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
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

class _SavePrompt extends StatelessWidget {
  const _SavePrompt({
    required this.slot,
    required this.bytes,
    required this.onSaveFolder,
    required this.onSaveZip,
  });

  final int slot;
  final int bytes;
  final VoidCallback? onSaveFolder;
  final VoidCallback onSaveZip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.pullSavePrompt(formatBytes(bytes), slot),
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Saving "as a folder" has no meaning on a phone, so the option is absent
              // there rather than present and confusing.
              if (onSaveFolder != null)
                OutlinedButton.icon(
                  onPressed: onSaveFolder,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(context.l10n.pullSaveAsFolder),
                ),
              OutlinedButton.icon(
                onPressed: onSaveZip,
                icon: const Icon(Icons.archive_outlined, size: 18),
                // A file extension, not a word.
                label: const Text('.zip…'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
