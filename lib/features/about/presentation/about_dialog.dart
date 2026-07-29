import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:world_keeper/app/app_info.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/about/domain/command_reference.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// What this app is, where it keeps things, and what it runs on your server.
///
/// The third of those is the point. Everything else here is conventional; the command
/// reference is the part that lets someone decide whether to trust a button labelled
/// "Push" with a machine they care about — before pressing it, not by reading the audit
/// log afterwards.
Future<void> showWorldKeeperAbout(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _AboutDialog());

class _AboutDialog extends ConsumerWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(appPathsProvider);
    final connection = ref.watch(connectionProvider);
    final target = connection.target;

    final known = KnownValues(
      worldsPath: target?.worldsPath,
      serviceKind: target?.serviceKind,
      steamUser: target?.steamUser,
    );
    final groups = buildCommandReference(context.l10n, known);

    final body = _Body(paths: paths, known: known, groups: groups);

    // A phone has no room for an inset dialog holding a scrollable reference; a desktop
    // window would look absurd with a full-screen one.
    if (context.windowSize.isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.aboutTitle(appName)),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: body,
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.aboutTitle(appName),
                      style: context.texts.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.commonClose,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.paths, required this.known, required this.groups});

  final AppPaths paths;
  final KnownValues known;
  final List<CommandRefGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Text(context.l10n.aboutTagline, style: context.texts.bodyMedium),
        const SizedBox(height: 4),
        Text(
          context.l10n.aboutVersion(appVersion),
          style: monoStyle(
            context,
            fontSize: 11,
            color: context.wk.mutedForeground,
          ),
        ),
        const SizedBox(height: 20),

        _Heading(
          context.l10n.aboutDataTitle,
          subtitle: context.l10n.aboutDataSubtitle,
        ),
        _PathRow(
          label: context.l10n.aboutPathConfiguration,
          file: paths.configFile,
        ),
        _PathRow(
          label: context.l10n.aboutPathAuditDatabase,
          file: paths.databaseFile,
        ),
        if (paths.legacyDatabaseFile.existsSync())
          _PathRow(
            label: context.l10n.aboutPathImportedFrom,
            file: paths.legacyDatabaseFile,
            note: context.l10n.aboutPathImportedNote,
          ),
        _PathRow(label: context.l10n.aboutPathKeys, directory: paths.keysDir),

        const SizedBox(height: 24),
        _Heading(
          context.l10n.aboutCommandsTitle,
          subtitle: known.targetKind == null
              ? context.l10n.aboutCommandsSubtitleDisconnected
              : context.l10n.aboutCommandsSubtitleConnected(
                  targetKindLabel(context.l10n, known.targetKind!),
                ),
          trailing: _CopyButton(
            label: context.l10n.aboutCopyAll,
            text: () => commandReferenceAsText(groups),
          ),
        ),
        for (final group in groups) _Group(group: group),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.texts.titleSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: context.texts.bodySmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: trailing == null
          ? text
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: text),
                const SizedBox(width: 12),
                trailing!,
              ],
            ),
    );
  }
}

/// One resolved on-disk location, with a button to open its folder.
///
/// Reveals the *containing directory* rather than the file: opening `config.json` would
/// hand it to whatever the OS thinks edits JSON, which is not what "show me where this is"
/// means.
class _PathRow extends StatelessWidget {
  const _PathRow({required this.label, this.file, this.directory, this.note})
    : assert(file != null || directory != null, 'needs a file or a directory');

  final String label;
  final File? file;
  final Directory? directory;
  final String? note;

  String get _path => file?.path ?? directory!.path;

  String get _revealTarget => directory?.path ?? file!.parent.path;

  Future<void> _reveal(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Read before the await, same as the messenger: by the time `launchUrl` returns, this
    // widget may be gone and the context unusable.
    final failureMessage = context.l10n.aboutFolderOpenFailed;
    try {
      final opened = await launchUrl(Uri.file(_revealTarget));
      if (!opened) throw const FileSystemException('the file manager declined');
    } on Object {
      // Headless CI, an unusual desktop, a sandboxed mobile build — the path itself is
      // still the useful part, so hand it over rather than just failing.
      await Clipboard.setData(ClipboardData(text: _revealTarget));
      messenger?.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note == null ? label : '$label  ·  $note',
                  style: context.texts.labelSmall?.copyWith(
                    color: context.wk.mutedForeground,
                  ),
                ),
                SelectableText(_path, style: monoStyle(context, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            tooltip: context.l10n.aboutShowInFolder,
            onPressed: () => _reveal(context),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group});

  final CommandRefGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(group.group, style: context.texts.titleSmall),
        subtitle: Text(
          context.l10n.aboutStepCount(group.entries.length),
          style: context.texts.bodySmall?.copyWith(
            color: context.wk.mutedForeground,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final entry in group.entries) _Entry(entry: entry)],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry});

  final CommandRefEntry entry;

  @override
  Widget build(BuildContext context) {
    final kind = entry.targetKind;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kind == null
                      ? entry.label
                      : '${entry.label}  [${targetKindLabel(context.l10n, kind)}]',
                  style: context.texts.bodySmall,
                ),
              ),
              // Notes are prose, not something to paste into a shell.
              if (!entry.isNote)
                _CopyButton(
                  label: context.l10n.commonCopy,
                  text: () => entry.command,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 2),
          // Long commands scroll inside their own box; the dialog never scrolls sideways.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                entry.command,
                style: monoStyle(
                  context,
                  fontSize: 11,
                  color: entry.isNote ? context.wk.mutedForeground : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copies to the clipboard and says it did.
///
/// [text] is a callback rather than a value so "copy all" does not render the entire
/// reference to a string on every rebuild of the dialog.
class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.label,
    required this.text,
    this.dense = false,
  });

  final String label;
  final String Function() text;
  final bool dense;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = context.l10n.aboutCopied(label);
    await Clipboard.setData(ClipboardData(text: text()));
    messenger?.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    if (dense) {
      return IconButton(
        icon: const Icon(Icons.copy_all_outlined, size: 16),
        tooltip: label,
        visualDensity: VisualDensity.compact,
        onPressed: () => _copy(context),
      );
    }
    return OutlinedButton.icon(
      icon: const Icon(Icons.copy_all_outlined, size: 16),
      label: Text(label),
      onPressed: () => _copy(context),
    );
  }
}
