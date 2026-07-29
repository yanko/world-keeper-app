import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_export.dart';
import 'package:world_keeper/core/audit/audit_queries.dart';
import 'package:world_keeper/features/audit/presentation/audit_screen.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Debounce for the search boxes.
///
/// Every keystroke would otherwise re-query a table with thousands of rows; 300 ms is
/// long enough to coalesce typing and short enough to feel immediate.
const Duration _searchDebounce = Duration(milliseconds: 300);

// ---- events --------------------------------------------------------------------

class EventsView extends AuditView<AuditEvent> {
  const EventsView({
    required super.profileId,
    required super.sessions,
    required super.refreshToken,
    super.key,
  });

  @override
  ConsumerState<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends AuditViewState<EventsView, AuditEvent> {
  EventFilter _filter = const EventFilter();
  List<String> _kinds = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadKinds());
  }

  @override
  void onScopeChanged() => _loadKinds();

  Future<void> _loadKinds() async {
    final kinds = await ref
        .read(auditDatabaseProvider)
        .listEventKinds(profileId: widget.profileId);
    if (mounted) setState(() => _kinds = kinds);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Future<List<AuditEvent>> fetch({required int offset, required int limit}) =>
      ref
          .read(auditDatabaseProvider)
          .queryEvents(
            EventFilter(
              kind: _filter.kind,
              ok: _filter.ok,
              profileId: widget.profileId,
              sessionId: _filter.sessionId,
              search: _filter.search,
              limit: limit,
              offset: offset,
            ),
          );

  void _apply(EventFilter next) {
    setState(() => _filter = next);
    reload();
  }

  void _search(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (mounted) _apply(_filter.copyWith(search: text));
    });
  }

  @override
  String emptyMessage(AppLocalizations l10n) => l10n.auditNoEventsMatch;

  @override
  Widget buildFilters(BuildContext context) {
    final l10n = context.l10n;
    return AuditFilterBar(
      children: [
        _DropdownFilter<String>(
          label: l10n.auditFilterKind,
          allLabel: l10n.auditFilterAllKinds,
          value: _filter.kind,
          options: _kinds,
          // Event kinds are stored identifiers (`push_start`), not prose — shown as they
          // are recorded so a row on screen matches a row in the exported CSV.
          labelOf: (k) => k,
          onChanged: (v) => _apply(_filter.copyWith(kind: v)),
        ),
        SessionFilter(
          sessions: widget.sessions,
          value: _filter.sessionId,
          onChanged: (v) => _apply(_filter.copyWith(sessionId: v)),
        ),
        _DropdownFilter<bool>(
          label: l10n.auditFilterStatus,
          allLabel: l10n.auditFilterAnyStatus,
          value: _filter.ok,
          options: const [true, false],
          labelOf: (v) => v ? l10n.auditStatusOk : l10n.auditStatusFailed,
          onChanged: (v) => _apply(_filter.copyWith(ok: v)),
        ),
        SearchField(hint: l10n.auditSearchEvents, onChanged: _search),
      ],
    );
  }

  @override
  Widget buildRow(
    BuildContext context,
    AuditEvent row, {
    required bool compact,
  }) {
    return ExpandableAuditRow(
      timestamp: row.ts,
      title: row.kind,
      // Event kinds are a closed vocabulary; sized to the longest of them
      // (`legacy_audit_imported`) so the payload sits right next to its event.
      titleWidth: 170,
      subtitle: row.state,
      status: switch (row.ok) {
        null => null,
        1 => true,
        _ => false,
      },
      preview: row.detailJson,
      detail: prettyJson(row.detailJson),
      compact: compact,
    );
  }
}

// ---- ssh commands ----------------------------------------------------------------

class CommandsView extends AuditView<AuditSshCommand> {
  const CommandsView({
    required super.profileId,
    required super.sessions,
    required super.refreshToken,
    super.key,
  });

  @override
  ConsumerState<CommandsView> createState() => _CommandsViewState();
}

class _CommandsViewState extends AuditViewState<CommandsView, AuditSshCommand> {
  CommandFilter _filter = const CommandFilter();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Future<List<AuditSshCommand>> fetch({
    required int offset,
    required int limit,
  }) => ref
      .read(auditDatabaseProvider)
      .queryCommands(
        CommandFilter(
          failedOnly: _filter.failedOnly,
          profileId: widget.profileId,
          sessionId: _filter.sessionId,
          search: _filter.search,
          limit: limit,
          offset: offset,
        ),
      );

  void _apply(CommandFilter next) {
    setState(() => _filter = next);
    reload();
  }

  void _search(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (mounted) _apply(_filter.copyWith(search: text));
    });
  }

  @override
  String emptyMessage(AppLocalizations l10n) => l10n.auditNoCommandsMatch;

  @override
  Widget buildFilters(BuildContext context) {
    final l10n = context.l10n;
    return AuditFilterBar(
      children: [
        SessionFilter(
          sessions: widget.sessions,
          value: _filter.sessionId,
          onChanged: (v) => _apply(_filter.copyWith(sessionId: v)),
        ),
        _DropdownFilter<bool>(
          label: l10n.auditFilterExit,
          allLabel: l10n.auditFilterAnyExit,
          value: _filter.failedOnly,
          options: const [false, true],
          labelOf: (v) => v ? l10n.auditExitNonzero : l10n.auditExitZero,
          onChanged: (v) => _apply(_filter.copyWith(failedOnly: v)),
        ),
        SearchField(hint: l10n.auditSearchCommands, onChanged: _search),
      ],
    );
  }

  @override
  Widget buildRow(
    BuildContext context,
    AuditSshCommand row, {
    required bool compact,
  }) {
    final failed = row.exitCode == null || row.exitCode != 0;
    return ExpandableAuditRow(
      timestamp: row.ts,
      title: row.command,
      monoTitle: true,
      // The command *is* the content here, so it keeps the larger share; its output is
      // the supporting detail.
      titleFlex: 3,
      // `ms` is the SI symbol, the same in every language.
      subtitle: row.durationMs == null ? null : '${row.durationMs} ms',
      // A null exit code means the command never returned one — a transport failure,
      // which is a failure, so it must not read as success.
      status: !failed,
      badge: row.exitCode?.toString() ?? context.l10n.auditNoExitCode,
      preview: row.stdout?.trim().isNotEmpty ?? false ? row.stdout : row.stderr,
      // `stdout` and `stderr` are the streams' names, not words about them.
      detail:
          'stdout:\n${_orEmpty(context, row.stdout)}\n\n'
          'stderr:\n${_orEmpty(context, row.stderr)}',
      compact: compact,
    );
  }

  static String _orEmpty(BuildContext context, String? s) =>
      (s == null || s.isEmpty) ? context.l10n.commonEmpty : s;
}

// ---- errors ------------------------------------------------------------------------

class ErrorsView extends AuditView<AuditError> {
  const ErrorsView({
    required super.profileId,
    required super.sessions,
    required super.refreshToken,
    super.key,
  });

  @override
  ConsumerState<ErrorsView> createState() => _ErrorsViewState();
}

class _ErrorsViewState extends AuditViewState<ErrorsView, AuditError> {
  ErrorFilter _filter = const ErrorFilter();
  List<String> _contexts = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContexts());
  }

  @override
  void onScopeChanged() => _loadContexts();

  Future<void> _loadContexts() async {
    final contexts = await ref
        .read(auditDatabaseProvider)
        .listErrorContexts(profileId: widget.profileId);
    if (mounted) setState(() => _contexts = contexts);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Future<List<AuditError>> fetch({required int offset, required int limit}) =>
      ref
          .read(auditDatabaseProvider)
          .queryErrors(
            ErrorFilter(
              context: _filter.context,
              profileId: widget.profileId,
              sessionId: _filter.sessionId,
              search: _filter.search,
              limit: limit,
              offset: offset,
            ),
          );

  void _apply(ErrorFilter next) {
    setState(() => _filter = next);
    reload();
  }

  void _search(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (mounted) _apply(_filter.copyWith(search: text));
    });
  }

  @override
  String emptyMessage(AppLocalizations l10n) => l10n.auditNoErrorsRecorded;

  @override
  Widget buildFilters(BuildContext context) {
    final l10n = context.l10n;
    return AuditFilterBar(
      children: [
        _DropdownFilter<String>(
          label: l10n.auditFilterContext,
          allLabel: l10n.auditFilterAllContexts,
          value: _filter.context,
          options: _contexts,
          // Stored identifiers again, for the same reason as event kinds.
          labelOf: (c) => c,
          onChanged: (v) => _apply(_filter.copyWith(context: v)),
        ),
        SessionFilter(
          sessions: widget.sessions,
          value: _filter.sessionId,
          onChanged: (v) => _apply(_filter.copyWith(sessionId: v)),
        ),
        SearchField(hint: l10n.auditSearchErrors, onChanged: _search),
      ],
    );
  }

  @override
  Widget buildRow(
    BuildContext context,
    AuditError row, {
    required bool compact,
  }) {
    return ExpandableAuditRow(
      timestamp: row.ts,
      title: row.message,
      badge: row.context,
      status: false,
      detail: row.detailJson == null
          ? row.message
          : '${row.message}\n\n${prettyJson(row.detailJson)}',
      compact: compact,
    );
  }
}

// ---- shared widgets ------------------------------------------------------------------

/// Filters wrap rather than scroll, so nothing is hidden off-screen on a phone.
class AuditFilterBar extends StatelessWidget {
  const AuditFilterBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class SessionFilter extends StatelessWidget {
  const SessionFilter({
    required this.sessions,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<AuditSession> sessions;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => _DropdownFilter<int>(
    label: context.l10n.auditFilterSession,
    allLabel: context.l10n.auditFilterAllSessions,
    value: value,
    options: [for (final s in sessions) s.id],
    labelOf: (id) {
      final s = sessions.firstWhere((s) => s.id == id);
      // `user@host`, the order used everywhere else in the app and by ssh itself.
      final where = [
        s.sshUser,
        s.host,
      ].where((v) => v != null && v.isNotEmpty).join('@');
      return where.isEmpty ? '#${s.id}' : '#${s.id} $where';
    },
    onChanged: onChanged,
  );
}

/// A dropdown whose "no filter" choice is a real, selectable entry rather than a magic
/// sentinel value the caller has to know about.
class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;

  /// The "no filter" entry, supplied whole rather than built from [label].
  ///
  /// It used to be `'All ${label.toLowerCase()}'`, which reads fine in English and is not
  /// a sentence any other language would assemble that way — lower-casing a noun and
  /// prefixing a word is English grammar hard-coded into a widget.
  final String allLabel;
  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<T?>(child: Text(allLabel)),
          for (final o in options)
            DropdownMenuItem<T?>(
              value: o,
              child: Text(labelOf(o), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({required this.hint, required this.onChanged, super.key});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        decoration: InputDecoration(
          labelText: context.l10n.auditSearch,
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 18),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// One log row, collapsed to a single line and expandable to the full record.
///
/// A log is scanned far more often than it is read, so the collapsed row is built to be
/// scannable: fixed-width timestamp, then title, then a preview of the payload, all on
/// one line at consistent offsets so the eye can run down a column instead of re-finding
/// each field per row. Nothing wraps; anything too long is ellipsized and available in
/// full on tap.
///
/// **Every row expands**, even one with no payload — the expanded view always carries the
/// exact stored timestamp, which the compact column deliberately abbreviates.
class ExpandableAuditRow extends StatefulWidget {
  const ExpandableAuditRow({
    required this.timestamp,
    required this.title,
    this.subtitle,
    this.badge,
    this.status,
    this.preview,
    this.detail,
    this.monoTitle = false,
    this.titleWidth,
    this.titleFlex = 3,
    required this.compact,
    super.key,
  });

  final String timestamp;
  final String title;
  final String? subtitle;
  final String? badge;

  /// `true` succeeded, `false` failed, `null` not applicable.
  final bool? status;

  final String? preview;
  final String? detail;
  final bool monoTitle;
  final bool compact;

  /// Fixed width for the title column, for views whose titles are short and bounded.
  ///
  /// Event kinds are a closed vocabulary — the longest is `legacy_audit_imported` — so a
  /// fixed column keeps every payload starting at the same offset *and* keeps it right
  /// beside its event. Giving the title a share of the remaining width instead pushed
  /// `app_start`'s payload halfway across a 1440 px window.
  ///
  /// Left null where the title *is* the content and needs the room — a command string or
  /// an error message — in which case [titleFlex] applies.
  final double? titleWidth;

  /// Share of the leftover width given to the title when [titleWidth] is null.
  final int titleFlex;

  @override
  State<ExpandableAuditRow> createState() => _ExpandableAuditRowState();
}

class _ExpandableAuditRowState extends State<ExpandableAuditRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (widget.status) {
      null => context.wk.mutedForeground,
      true => context.wk.signalText,
      false => context.colors.error,
    };

    final preview = widget.preview?.trim().replaceAll(RegExp(r'\s+'), ' ');
    final hasPreview = preview != null && preview.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: widget.compact
                  ? _compactBody(context, statusColor, preview, hasPreview)
                  : _wideBody(context, statusColor, preview, hasPreview),
            ),
          ),
          if (_expanded) _detailPanel(context),
        ],
      ),
    );
  }

  /// Desktop: one line, fixed offsets, nothing wraps.
  Widget _wideBody(
    BuildContext context,
    Color statusColor,
    String? preview,
    bool hasPreview,
  ) {
    return Row(
      children: [
        _dot(context, statusColor),
        // Fixed width so the column lines up down the whole list. Sized for
        // `07-28  13:51:33` at 11 px mono with room to spare.
        SizedBox(
          width: 108,
          child: Text(
            formatAuditTimestamp(widget.timestamp),
            maxLines: 1,
            softWrap: false,
            style: monoStyle(
              context,
              fontSize: 11,
              color: context.wk.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // The title column has a fixed offset either way, so payloads line up down the
        // list rather than starting wherever each title happens to end.
        _titleColumn(context, hasPreview),
        if (hasPreview) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              preview!,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(
                context,
                fontSize: 11,
                color: context.wk.mutedForeground,
              ),
            ),
          ),
        ],
        if (widget.subtitle != null) ...[
          const SizedBox(width: 10),
          Text(
            widget.subtitle!,
            style: context.texts.labelSmall?.copyWith(
              color: context.wk.mutedForeground,
            ),
          ),
        ],
        if (widget.badge != null) ...[
          const SizedBox(width: 10),
          _Badge(text: widget.badge!, color: statusColor),
        ],
        Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: context.wk.mutedForeground,
        ),
      ],
    );
  }

  /// Phone: time and title on one line, payload beneath. There is no width for three
  /// columns at 360 px, but the time still leads so rows remain scannable.
  Widget _compactBody(
    BuildContext context,
    Color statusColor,
    String? preview,
    bool hasPreview,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _dot(context, statusColor),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    formatAuditTimestamp(widget.timestamp, timeOnly: true),
                    style: monoStyle(
                      context,
                      fontSize: 11,
                      color: context.wk.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: widget.monoTitle
                          ? monoStyle(context, fontSize: 12)
                          : context.texts.bodyMedium,
                    ),
                  ),
                  if (widget.badge != null) ...[
                    const SizedBox(width: 8),
                    _Badge(text: widget.badge!, color: statusColor),
                  ],
                ],
              ),
              if (hasPreview)
                Text(
                  preview!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(
                    context,
                    fontSize: 10,
                    color: context.wk.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
        Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: context.wk.mutedForeground,
        ),
      ],
    );
  }

  Widget _titleColumn(BuildContext context, bool hasPreview) {
    final text = Text(
      widget.title,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: widget.monoTitle
          ? monoStyle(context, fontSize: 12)
          : context.texts.bodyMedium,
    );

    final width = widget.titleWidth;
    if (width != null && hasPreview) return SizedBox(width: width, child: text);
    // With no payload beside it, the title may use the whole row.
    return Expanded(flex: hasPreview ? widget.titleFlex : 1, child: text);
  }

  /// The success/failure signal.
  ///
  /// Colour is the whole of it visually, which means it is nothing at all to a screen
  /// reader or to the ~8% of men with a red/green deficiency — and this is a forensic log
  /// where "did that step succeed" is the question being asked. The label says it in
  /// words; the dot stays as it is for everyone else.
  Widget _dot(BuildContext context, Color color) {
    final dot = Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    final meaning = switch (widget.status) {
      null => null,
      true => context.l10n.auditSucceeded,
      false => context.l10n.auditFailed,
    };
    return meaning == null ? dot : Semantics(label: meaning, child: dot);
  }

  /// The full record. Always includes the exact stored timestamp, since the row above
  /// deliberately shows an abbreviated one.
  Widget _detailPanel(BuildContext context) {
    final detail = widget.detail?.trim();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 340),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              formatAuditTimestampFull(widget.timestamp),
              style: monoStyle(
                context,
                fontSize: 11,
                color: context.wk.mutedForeground,
              ),
            ),
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: context.colors.outline),
              const SizedBox(height: 8),
              // Wide command output scrolls inside its own box; the page never scrolls
              // sideways.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  detail,
                  style: monoStyle(context, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: context.texts.labelSmall?.copyWith(color: color)),
  );
}
