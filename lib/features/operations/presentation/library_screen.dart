import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';
import 'package:world_keeper/features/operations/data/operations_controller.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';
import 'package:world_keeper/features/operations/presentation/operation_widgets.dart';
import 'package:world_keeper/features/operations/presentation/stepper.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// What is live on the server, and every dated backup that can be restored.
///
/// The backup list comes from the **filesystem**, not the audit database. The database
/// was the original source and it was wrong: it only ever knew about backups this app
/// made, so clearing the audit log made real, restorable backups invisible — a log wipe
/// silently crippling an unrelated feature. The database is now consulted only to
/// annotate an entry with why it was made.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<RemoteWorldInfo>? _worlds;
  List<BackupInfo>? _backups;
  String? _error;
  bool _loading = false;

  static List<StepDef<RestoreState>> _steps(AppLocalizations l10n) => [
    StepDef(RestoreState.checkingService, l10n.stepCheck),
    StepDef(RestoreState.stopping, l10n.stepStop),
    StepDef(RestoreState.backingUp, l10n.stepBackUp),
    StepDef(RestoreState.copying, l10n.stepCopyIn),
    StepDef(RestoreState.fixingPerms, l10n.stepPerms),
    StepDef(RestoreState.starting, l10n.stepStart),
    StepDef(RestoreState.capturingGameId, l10n.stepGameId),
    StepDef(RestoreState.verifying, l10n.stepVerify),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ops = ref.read(operationsProvider.notifier);
      final worlds = await ops.listRemoteWorlds();
      final backups = await ops.listBackups();
      if (!mounted) return;
      setState(() {
        _worlds = worlds;
        _backups = backups;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(BackupInfo backup) async {
    final slot = backup.slot;
    if (slot == null) return;

    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.restoreConfirmTitle(slot),
      message: l10n.restoreConfirmBody,
      detail: backup.path,
      confirmLabel: l10n.restoreConfirmButton,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(operationsProvider.notifier)
          .startRestore(backup.path, slot);
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(l10n.restoreDoneToast(slot))));
        await _refresh();
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
    final run = ops.restore;
    final busy = ops.isBusy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          l10n.libraryTitle,
          subtitle: l10n.librarySubtitle,
          trailing: OutlinedButton.icon(
            onPressed: busy || _loading ? null : _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(_loading ? l10n.commonLoading : l10n.commonRefresh),
          ),
        ),
        const SizedBox(height: 16),

        if (ops.active != null && ops.active != OperationKind.restore) ...[
          OtherOperationBanner(active: ops.active!),
          const SizedBox(height: 12),
        ],

        if (_error != null)
          Text(
            _error!,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.error,
            ),
          ),

        _LiveWorlds(worlds: _worlds),
        const SizedBox(height: 20),
        _Backups(backups: _backups, busy: busy, onRestore: _restore),

        if (run.log.isNotEmpty) ...[
          const SizedBox(height: 16),
          OperationStepper<RestoreState>(
            steps: _steps(l10n),
            log: run.log,
            doneState: RestoreState.done,
            failedStates: const [RestoreState.rollingBack, RestoreState.failed],
            failedBanner: l10n.restoreFailedBanner,
          ),
        ],

        if (!run.running && run.result != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.wk.signalSurface,
              border: Border.all(color: context.wk.signalBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.restoreResult(run.result!.slot) +
                      (run.result!.gameId == null
                          ? ''
                          : ' · ${l10n.resultGameId(run.result!.gameId!)}'),
                  style: context.texts.bodyMedium,
                ),
                if (run.result!.backupPath != null)
                  SelectableText(
                    l10n.restoreSafetyBackup(run.result!.backupPath!),
                    style: monoStyle(
                      context,
                      fontSize: 11,
                      color: context.wk.mutedForeground,
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

class _LiveWorlds extends StatelessWidget {
  const _LiveWorlds({required this.worlds});

  final List<RemoteWorldInfo>? worlds;

  @override
  Widget build(BuildContext context) {
    final list = worlds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.libraryLiveOnServer,
          style: context.texts.labelMedium?.copyWith(
            color: context.wk.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        if (list == null)
          const LinearProgressIndicator()
        else if (list.isEmpty)
          Text(
            context.l10n.worldsNoneFound,
            style: context.texts.bodySmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          )
        else
          for (final w in list)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    context.l10n.slotNumber('${w.slot}'),
                    style: monoStyle(context, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '${formatBytes(w.size)} · ${formatEpoch(context.l10n, w.modified)}',
                    style: context.texts.bodySmall?.copyWith(
                      color: context.wk.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Backups extends StatelessWidget {
  const _Backups({
    required this.backups,
    required this.busy,
    required this.onRestore,
  });

  final List<BackupInfo>? backups;
  final bool busy;
  final ValueChanged<BackupInfo> onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = backups;
    final compact = context.windowSize.isCompact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          list == null
              ? l10n.libraryBackups
              : l10n.libraryBackupsCount(list.length),
          style: context.texts.labelMedium?.copyWith(
            color: context.wk.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        if (list == null)
          const LinearProgressIndicator()
        else if (list.isEmpty)
          Text(
            l10n.libraryNoBackupsYet,
            style: context.texts.bodySmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          )
        else
          for (final b in list)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Flex(
                // On a phone the restore button goes full width beneath the detail
                // rather than being squeezed into a row.
                direction: compact ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: compact ? 0 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.slotNumber('${b.slot ?? '?'}'),
                              style: monoStyle(context, fontSize: 13),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              formatEpoch(l10n, b.modified),
                              style: context.texts.bodySmall?.copyWith(
                                color: context.wk.mutedForeground,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              formatBytes(b.bytes),
                              style: context.texts.bodySmall?.copyWith(
                                color: context.wk.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: monoStyle(
                            context,
                            fontSize: 10,
                            color: context.wk.mutedForeground,
                          ),
                        ),
                        if (b.note != null)
                          Text(
                            b.note!,
                            style: context.texts.bodySmall?.copyWith(
                              color: context.wk.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (compact) const SizedBox(height: 8),
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: OutlinedButton(
                      // A backup whose name has no parseable slot cannot be restored
                      // without one, so the action is disabled rather than guessing.
                      onPressed: busy || b.slot == null
                          ? null
                          : () => onRestore(b),
                      child: Text(l10n.libraryRestore),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
