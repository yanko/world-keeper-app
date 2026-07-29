import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_export.dart';
import 'package:world_keeper/core/audit/audit_queries.dart';
import 'package:world_keeper/features/audit/presentation/audit_rows.dart';
import 'package:world_keeper/features/operations/presentation/file_pickers.dart';
import 'package:world_keeper/features/operations/presentation/operation_widgets.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// The forensic trail, for the server you are connected to.
///
/// This app performs destructive operations on a remote server, so "what happened to
/// world 0 on the 24th" and "which step did the swap die on" have to be answerable after
/// the fact.
///
/// Scoped to the live connection ([auditScopeProvider]) rather than showing everything:
/// the database spans every machine the app has ever touched, and rows from one server
/// read as another's unless something says which is which. Connecting loads that host's
/// history; disconnecting leaves nothing to show, because there is no longer a server the
/// screen could be about.
///
/// Export is the deliberate exception — it writes the complete log, every server, and
/// stays available while disconnected. That matters: the times you most want the record
/// are exactly the times the host is unreachable.
class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen>
    with SingleTickerProviderStateMixin {
  /// Built eagerly rather than lazily: the tabs only exist while connected, so a screen
  /// that never saw a connection would otherwise *construct* its controller inside
  /// `dispose`, where `SingleTickerProviderStateMixin` can no longer reach `TickerMode`.
  late final TabController _tabs;

  List<AuditSession> _sessions = const [];
  AuditCounts? _counts;
  bool _exporting = false;

  /// Bumped to force the three views to re-query — after a clear, or a manual refresh.
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHeader());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadHeader() async {
    final db = ref.read(auditDatabaseProvider);
    final profileId = ref.read(auditScopeProvider)?.profileId;
    if (profileId == null) {
      if (mounted) {
        setState(() {
          _sessions = const [];
          _counts = null;
        });
      }
      return;
    }
    try {
      final sessions = await db.listSessions(profileId: profileId);
      final counts = await db.counts(profileId: profileId);
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _counts = counts;
        });
      }
    } on Object {
      // The header is decoration; the tables below report their own failures.
    }
  }

  void _refresh() {
    setState(() => _refreshToken++);
    _loadHeader();
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    final destination = await FilePickers.saveZip(
      defaultAuditExportName(),
      dialogTitle: l10n.auditExportDialogTitle,
    );
    if (destination == null || !mounted) return;

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final paths = ref.read(appPathsProvider);
      final path = await AuditExporter(
        ref.read(auditDatabaseProvider),
      ).exportTo(destination, databaseFile: paths.databaseFile);
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.auditExportedTo(path))),
      );
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Two confirmations, because this is the one destructive action whose damage stays
  /// invisible until the day you need what it deleted.
  ///
  /// Always scoped to the server on screen. There is now always exactly one — connected it
  /// is the connected host, disconnected it is whichever was picked — so Clear has a single
  /// meaning and needs no opt-in, no widening checkbox and no third prompt. That is what
  /// the picker bought: a destructive action whose blast radius is the thing you are
  /// looking at.
  Future<void> _clear(AuditScope scope) async {
    final l10n = context.l10n;
    final first = await confirmDestructive(
      context,
      title: l10n.auditClearTitle(scope.name),
      message: l10n.auditClearBody(scope.where),
      confirmLabel: l10n.auditClearConfirm,
    );
    if (!first || !mounted) return;

    final second = await confirmDestructive(
      context,
      title: l10n.auditClearSecondTitle,
      message: l10n.auditClearSecondBody,
      confirmLabel: l10n.auditClearSecondConfirm,
    );
    if (!second || !mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(auditDatabaseProvider)
          .clearAuditLogForProfile(
            scope.profileId,
            ref.read(auditSessionIdProvider),
          );
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.auditClearedToast(scope.name))),
      );
      ref.invalidate(auditedProfilesProvider);
      _refresh();
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // The scope drives every query, so a change to it — connecting, disconnecting, or
    // picking another server — re-queries without anyone pressing Refresh.
    ref.listen(auditScopeProvider, (previous, next) {
      if (previous?.profileId != next?.profileId) _refresh();
    });

    final l10n = context.l10n;
    final scope = ref.watch(auditScopeProvider);
    final counts = _counts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SectionHeader(
            l10n.auditTitle,
            subtitle: switch ((scope, counts)) {
              (null, _) => l10n.auditNothingYetSubtitle,
              // Until the counts arrive, `user@host` says which server this is — the one
              // thing the header must never be ambiguous about.
              (final s?, null) => s.where,
              (_?, final c?) => l10n.auditCounts(
                c.sessions,
                c.events,
                c.commands,
                c.errors,
              ),
            },
            trailing: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (scope != null) _ScopePicker(scope: scope),
                OutlinedButton.icon(
                  onPressed: _exporting ? null : _export,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(
                    _exporting ? l10n.auditExporting : l10n.auditExport,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.commonRefresh),
                ),
                OutlinedButton.icon(
                  onPressed: scope == null ? null : () => _clear(scope),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.error,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.auditClear),
                ),
              ],
            ),
          ),
        ),
        if (scope == null)
          const Expanded(child: _NothingRecordedNotice())
        else ...[
          TabBar(
            controller: _tabs,
            tabs: [
              // Material fixes a text-only tab at 46 dp regardless of the text scale, so
              // at 200% the label overflows its own tab by 10 px. Scaling the height the
              // same way the label scales is the fix.
              for (final label in [
                l10n.auditTabEvents,
                l10n.auditTabCommands,
                l10n.auditTabErrors,
              ])
                Tab(
                  height: MediaQuery.textScalerOf(context).scale(46),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                EventsView(
                  profileId: scope.profileId,
                  sessions: _sessions,
                  refreshToken: _refreshToken,
                ),
                CommandsView(
                  profileId: scope.profileId,
                  sessions: _sessions,
                  refreshToken: _refreshToken,
                ),
                ErrorsView(
                  profileId: scope.profileId,
                  sessions: _sessions,
                  refreshToken: _refreshToken,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Which server's log is on screen.
///
/// Locked to the connection while there is one — reading one machine's log while operating
/// on another is how you convince yourself the wrong thing happened. Free to choose while
/// disconnected, which is the case the record is most often wanted in: the host is
/// unreachable and you want to know what was done to it.
class _ScopePicker extends ConsumerWidget {
  const _ScopePicker({required this.scope});

  final AuditScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles =
        ref.watch(auditedProfilesProvider).asData?.value ?? const [];

    if (scope.locked) {
      return Tooltip(
        message: context.l10n.auditScopeLocked,
        child: InputChip(
          avatar: const Icon(Icons.lock_outline, size: 16),
          label: Text('${scope.name}  ·  ${scope.where}'),
          onPressed: null,
        ),
      );
    }

    // The dropdown asserts unless its value is among the items, and the list arrives
    // asynchronously — so the scoped server is added explicitly when it is not there yet.
    // Without this the picker throws on the frame between the scope resolving and the
    // query returning.
    final listed = profiles.any((p) => p.profileId == scope.profileId);

    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: scope.profileId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.l10n.auditScopeServer,
          isDense: true,
        ),
        items: [
          if (!listed)
            DropdownMenuItem(
              value: scope.profileId,
              child: Text(
                '${scope.name}  ·  ${scope.where}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          for (final p in profiles)
            DropdownMenuItem(
              value: p.profileId,
              child: Text(
                '${_nameOf(context, ref, p)}  ·  ${p.where}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) {
          if (id != null) ref.read(auditScopeProvider.notifier).select(id);
        },
      ),
    );
  }

  /// A deleted profile keeps its history — the record of what was done to a machine is not
  /// the profile's to take with it — so it needs a name that says so rather than a bare id.
  String _nameOf(BuildContext context, WidgetRef ref, AuditedProfile p) =>
      ref.watch(configProvider).asData?.value.profileById(p.profileId)?.name ??
      context.l10n.auditDeletedProfile;
}

/// Shown when the log holds nothing for any server at all.
class _NothingRecordedNotice extends StatelessWidget {
  const _NothingRecordedNotice();

  @override
  Widget build(BuildContext context) {
    return CenteredNotice(
      icon: Icons.receipt_long_outlined,
      title: context.l10n.auditNothingYetTitle,
      maxWidth: 460,
      body: context.l10n.auditNothingYetBody,
    );
  }
}

/// Shared scaffolding for the three views: filter bar, results, paging, empty state.
///
/// The three differ only in their filters and how a row renders, so the querying,
/// debouncing and paging live here once.
abstract class AuditView<T> extends ConsumerStatefulWidget {
  const AuditView({
    required this.profileId,
    required this.sessions,
    required this.refreshToken,
    super.key,
  });

  /// The connected server. Every query is scoped to it — see [AuditScreen].
  final String profileId;

  final List<AuditSession> sessions;
  final int refreshToken;
}

abstract class AuditViewState<W extends AuditView<T>, T>
    extends ConsumerState<W> {
  List<T> rows = const [];
  bool loading = false;
  String? error;
  bool hasMore = false;
  int offset = 0;

  /// How many rows a page holds. Small enough to stay responsive on a phone, large
  /// enough that scrolling is the normal way to browse rather than paging.
  static const int pageSize = 100;

  Future<List<T>> fetch({required int offset, required int limit});

  Widget buildFilters(BuildContext context);

  Widget buildRow(BuildContext context, T row, {required bool compact});

  /// Why the list is empty. Takes the string table rather than reading it off a context,
  /// because the subclasses that implement it have no widget of their own to ask.
  String emptyMessage(AppLocalizations l10n);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.profileId != widget.profileId) {
      reload();
      onScopeChanged();
    }
  }

  /// Hook for per-view filter options that are themselves scoped — the kind and context
  /// dropdowns list what exists *on this server*, so they have to be re-read too.
  void onScopeChanged() {}

  /// Re-runs the query from the first page. Called whenever a filter changes.
  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
      offset = 0;
    });
    try {
      final page = await fetch(offset: 0, limit: pageSize);
      if (!mounted) return;
      setState(() {
        rows = page;
        hasMore = page.length == pageSize;
      });
    } on Object catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    setState(() => loading = true);
    try {
      final next = offset + pageSize;
      final page = await fetch(offset: next, limit: pageSize);
      if (!mounted) return;
      setState(() {
        rows = [...rows, ...page];
        offset = next;
        hasMore = page.length == pageSize;
      });
    } on Object catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// One scroll region, filters included.
  ///
  /// They used to be a fixed block above an `Expanded` list, which is fine until the
  /// filters are taller than the space there is: four wrapped controls at 200% text on a
  /// 360 px phone come to ~364 px inside a ~298 px tab view, and the column overflowed.
  /// Scrolling them away with the list fixes it at every scale, and on a phone it hands
  /// the rows the room they want anyway.
  @override
  Widget build(BuildContext context) {
    final compact = context.windowSize.isCompact;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: buildFilters(context),
          ),
        ),
        if (error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                error!,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ),
          ),
        if (loading && rows.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  emptyMessage(context.l10n),
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.wk.mutedForeground,
                  ),
                ),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) =>
                  buildRow(context, rows[index], compact: compact),
            ),
          ),
          if (hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton(
                  onPressed: loading ? null : loadMore,
                  child: Text(
                    loading
                        ? context.l10n.commonLoading
                        : context.l10n.auditLoadMore,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
