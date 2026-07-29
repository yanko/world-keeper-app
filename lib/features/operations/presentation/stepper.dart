import 'package:flutter/material.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/operations/domain/operation_progress.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// One stage of a pipeline.
class StepDef<S extends Enum> {
  const StepDef(this.state, this.label);
  final S state;
  final String label;
}

enum StepStatus { pending, active, done, error }

/// The operation pipeline — the app's signature element.
///
/// Turns the frightening part (a destructive remote swap) into something watchable: each
/// stage fills as it completes, the current one shows its live detail, and a failure is
/// pinned to the exact stage it happened in.
///
/// ## Two orientations, one state model
///
/// Nine stages laid out horizontally need roughly 700 px. At 360 px that is 40 px per
/// stage — unreadable, and the original's answer was a horizontal scrollbar, which hides
/// precisely the information you most want during a destructive operation.
///
/// So on a phone it becomes a **vertical timeline**: node and connector down the left
/// gutter, label and detail to the right. That is strictly better there — every label is
/// fully readable, and the current stage's detail gets real width instead of a 40 px
/// column.
class OperationStepper<S extends Enum> extends StatelessWidget {
  const OperationStepper({
    required this.steps,
    required this.log,
    required this.doneState,
    required this.failedStates,
    required this.failedBanner,
    super.key,
  });

  final List<StepDef<S>> steps;
  final List<OperationProgress<S>> log;

  final S doneState;

  /// States that mean it broke. Not stages *in* the pipeline — they are what happens when
  /// it breaks, so they render as a banner rather than as nodes.
  final List<S> failedStates;

  final String failedBanner;

  @override
  Widget build(BuildContext context) {
    final model = _StepperModel<S>.from(
      steps: steps,
      log: log,
      doneState: doneState,
      failedStates: failedStates,
    );

    final vertical = context.windowSize.isCompact;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vertical)
            _VerticalPipeline(steps: steps, model: model)
          else
            _HorizontalPipeline(steps: steps, model: model),
          if (model.showReadout) ...[
            const SizedBox(height: 12),
            _Readout(
              label: model.terminal == _Terminal.failed
                  ? failedBanner
                  : (model.currentIndex >= 0
                        ? steps[model.currentIndex].label
                        : ''),
              detail: log.isEmpty ? null : log.last.detail,
              failed: model.terminal == _Terminal.failed,
            ),
          ],
        ],
      ),
    );
  }
}

enum _Terminal { none, done, failed }

/// Everything the two layouts need, computed once.
class _StepperModel<S extends Enum> {
  const _StepperModel({
    required this.statuses,
    required this.currentIndex,
    required this.terminal,
  });

  factory _StepperModel.from({
    required List<StepDef<S>> steps,
    required List<OperationProgress<S>> log,
    required S doneState,
    required List<S> failedStates,
  }) {
    // Tracks the last *pipeline* stage reached, not simply the last log entry. On failure
    // the log ends with rollingBack/failed, which are not in `steps` — using the raw last
    // entry would make every stage register as pending and erase the visible record of
    // how far it actually got.
    var currentIndex = -1;
    for (final entry in log) {
      final idx = steps.indexWhere((s) => s.state == entry.state);
      if (idx >= 0) currentIndex = idx;
    }

    final terminal = log.isNotEmpty && log.last.state == doneState
        ? _Terminal.done
        : (log.any((l) => failedStates.contains(l.state))
              ? _Terminal.failed
              : _Terminal.none);

    return _StepperModel(
      statuses: [
        for (var i = 0; i < steps.length; i++)
          _statusFor(i, currentIndex, terminal),
      ],
      currentIndex: currentIndex,
      terminal: terminal,
    );
  }

  final List<StepStatus> statuses;
  final int currentIndex;
  final _Terminal terminal;

  bool get showReadout =>
      terminal == _Terminal.failed ||
      (terminal == _Terminal.none && currentIndex >= 0);

  static StepStatus _statusFor(
    int index,
    int currentIndex,
    _Terminal terminal,
  ) {
    if (terminal == _Terminal.done) return StepStatus.done;
    if (terminal == _Terminal.failed) {
      if (index < currentIndex) return StepStatus.done;
      if (index == currentIndex) return StepStatus.error;
      return StepStatus.pending;
    }
    if (index < currentIndex) return StepStatus.done;
    if (index == currentIndex) return StepStatus.active;
    return StepStatus.pending;
  }
}

class _HorizontalPipeline<S extends Enum> extends StatelessWidget {
  const _HorizontalPipeline({required this.steps, required this.model});

  final List<StepDef<S>> steps;
  final _StepperModel<S> model;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          SizedBox(
            width: 72,
            child: Column(
              children: [
                _StepNode(status: model.statuses[i]),
                const SizedBox(height: 6),
                Text(
                  steps[i].label,
                  textAlign: TextAlign.center,
                  style: context.texts.labelSmall?.copyWith(
                    color: model.statuses[i] == StepStatus.pending
                        ? context.wk.mutedForeground
                        : context.colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
                child: _Connector(
                  status: model.statuses[i],
                  axis: Axis.horizontal,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _VerticalPipeline<S extends Enum> extends StatelessWidget {
  const _VerticalPipeline({required this.steps, required this.model});

  final List<StepDef<S>> steps;
  final _StepperModel<S> model;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    _StepNode(status: model.statuses[i]),
                    if (i < steps.length - 1)
                      Expanded(
                        child: _Connector(
                          status: model.statuses[i],
                          axis: Axis.vertical,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    // Aligns the label with the node, and leaves breathing room before
                    // the next row.
                    padding: EdgeInsets.only(
                      top: 3,
                      bottom: i < steps.length - 1 ? 14 : 0,
                    ),
                    child: Text(
                      steps[i].label,
                      style: context.texts.bodyMedium?.copyWith(
                        color: model.statuses[i] == StepStatus.pending
                            ? context.wk.mutedForeground
                            : context.colors.onSurface,
                        fontWeight: model.statuses[i] == StepStatus.active
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({required this.status});

  final StepStatus status;

  @override
  Widget build(BuildContext context) {
    final (border, fill, foreground) = switch (status) {
      StepStatus.done => (
        context.wk.signal,
        context.wk.signal,
        context.wk.onSignal,
      ),
      StepStatus.active => (
        context.wk.signal,
        Colors.transparent,
        context.wk.signalText,
      ),
      StepStatus.error => (
        context.colors.error,
        context.colors.error,
        context.colors.onError,
      ),
      StepStatus.pending => (
        context.colors.outline,
        Colors.transparent,
        context.wk.mutedForeground,
      ),
    };

    // Reduced motion is respected: the spinner becomes a static glyph rather than
    // disappearing, so the current stage is still identifiable.
    final animate =
        status == StepStatus.active && !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      // The node is a coloured circle with a glyph in it; without this a screen reader
      // gets the step's name and no indication of whether it has run.
      label: switch (status) {
        StepStatus.done => context.l10n.stepStatusDone,
        StepStatus.active => context.l10n.stepStatusActive,
        StepStatus.error => context.l10n.stepStatusError,
        StepStatus.pending => context.l10n.stepStatusPending,
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: border, width: 2),
        ),
        child: Center(
          child: switch (status) {
            StepStatus.done => Icon(Icons.check, size: 15, color: foreground),
            StepStatus.error => Icon(Icons.close, size: 15, color: foreground),
            StepStatus.active =>
              animate
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Icon(Icons.more_horiz, size: 14, color: foreground),
            StepStatus.pending => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.status, required this.axis});

  final StepStatus status;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StepStatus.pending => context.colors.outline,
      StepStatus.error => context.colors.error,
      StepStatus.done || StepStatus.active => context.wk.signal,
    };

    return Container(
      width: axis == Axis.horizontal ? null : 2,
      height: axis == Axis.horizontal ? 2 : null,
      margin: axis == Axis.horizontal
          ? const EdgeInsets.symmetric(horizontal: 2)
          : const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// The live readout under the pipeline: which stage, and whatever it has to say.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.detail,
    required this.failed,
  });

  final String label;
  final String? detail;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final accent = failed ? context.colors.error : context.wk.signalText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(
              color: accent,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: SelectableText(
                  detail!,
                  style: monoStyle(context, fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
