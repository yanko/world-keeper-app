import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/operations/data/operations_controller.dart';
import 'package:world_keeper/features/operations/presentation/operation_widgets.dart';
import 'package:world_keeper/features/terminal/data/terminal_controller.dart';
import 'package:world_keeper/features/terminal/data/terminal_session.dart';
import 'package:world_keeper/features/terminal/presentation/accessory_key_bar.dart';
import 'package:world_keeper/l10n/l10n.dart';
import 'package:xterm/xterm.dart';

/// A real shell over the same SSH connection.
///
/// Deliberately manual to start: this is an unsandboxed shell as whatever user the
/// profile connects as, so it opens because someone asked, never because a tab rendered.
///
/// The session survives navigation — the shell holds live state (a half-typed command, a
/// running `top`, scrollback) that would be lost if the screen were rebuilt. The app
/// shell keeps every destination mounted precisely for cases like this.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final _controller = TerminalController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await ref.read(terminalProvider.notifier).openSession();
      // Deliberately no `requestFocus()` here — see `_LiveTerminal`.
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
    final state = ref.watch(terminalProvider);
    final connected = ref.watch(connectionProvider).isConnected;
    final activeOperation = ref.watch(operationsProvider).active;

    return Column(
      children: [
        _Header(
          state: state,
          connected: connected,
          onStart: _start,
          onStop: () => ref.read(terminalProvider.notifier).closeSession(),
        ),
        const Divider(height: 1),

        if (activeOperation != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _OperationWarning(
              operation: operationName(context.l10n, activeOperation),
            ),
          ),

        Expanded(
          child: switch (state) {
            ShellOpening() => const Center(child: CircularProgressIndicator()),
            ShellOpen(:final session) => _LiveTerminal(
              session: session,
              controller: _controller,
            ),
            ShellClosed(:final error) => _Idle(error: error),
          },
        ),

        // The keys a software keyboard does not have. Without these a mobile shell is
        // something you can get stuck inside.
        if (state case ShellOpen(:final session))
          if (context.windowSize.isCompact) AccessoryBarHost(session: session),
      ],
    );
  }
}

/// Kept separate so the import stays honest about what it is for.
class AccessoryBarHost extends StatelessWidget {
  const AccessoryBarHost({required this.session, super.key});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) => AccessoryKeyBar(session: session);
}

/// Whether to take input straight from hardware key events instead of a platform
/// text-input connection.
///
/// **Desktop must.** xterm 4.0.0 opens a text-input connection with the pre-multi-view
/// `TextInput.attach` API, which Flutter 3.44 rejects on Windows:
///
/// ```
/// PlatformException(Bad Arguments, Could not set client, view ID is null.)
///   at _PlatformTextInputControl.attach
/// ```
///
/// The attach fails, `updateEditingValue` is therefore never called, and ordinary
/// characters have no route into the terminal at all. Key events take a different path
/// (a plain `Focus` widget) and need no connection — which is why Enter appeared to work
/// while letters did nothing, a symptom that looks like a focus problem and is not.
///
/// With this flag xterm swaps in `CustomKeyboardListener`, which reads `KeyEvent.character`
/// directly. That is arguably the better desktop behaviour anyway: it is the character the
/// OS says the key produced, so keyboard layouts and dead keys are respected rather than
/// being re-derived from a US-centric key table.
///
/// **Mobile must not.** A soft keyboard produces no hardware key events, so on Android and
/// iOS the text-input connection is the only route — and it works there, which is exactly
/// why this bug was invisible until a desktop build was typed into.
bool get useHardwareKeyboardOnly =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class _LiveTerminal extends StatelessWidget {
  const _LiveTerminal({required this.session, required this.controller});

  final TerminalSession session;
  final TerminalController controller;

  @override
  Widget build(BuildContext context) {
    final compact = context.windowSize.isCompact;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: TerminalView(
        session.terminal,
        controller: controller,
        autofocus: true,
        hardwareKeyboardOnly: useHardwareKeyboardOnly,
        padding: const EdgeInsets.all(6),
        // `autoResize` reports the real character grid back through `onResize`, which the
        // session forwards as a window-change so full-screen programs redraw correctly.
        backgroundOpacity: 1,
        theme: _theme(context),
        textStyle: TerminalStyle(
          fontSize: compact ? 12 : 13,
          fontFamily: monoFontFallback.first,
          fontFamilyFallback: monoFontFallback.sublist(1),
        ),
      ),
    );
  }

  /// Terminal colours follow the app theme rather than xterm's default, so a light-mode
  /// user does not get a black rectangle bolted onto a pale UI.
  TerminalTheme _theme(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark
        ? TerminalThemes.defaultTheme
        : TerminalThemes.whiteOnBlack;
    return TerminalTheme(
      cursor: context.wk.signal,
      selection: context.wk.signal.withValues(alpha: 0.35),
      foreground: dark ? base.foreground : context.colors.onSurface,
      background: dark
          ? context.colors.surfaceContainerLowest
          : context.colors.surface,
      black: base.black,
      red: base.red,
      green: base.green,
      yellow: base.yellow,
      blue: base.blue,
      magenta: base.magenta,
      cyan: base.cyan,
      white: base.white,
      brightBlack: base.brightBlack,
      brightRed: base.brightRed,
      brightGreen: base.brightGreen,
      brightYellow: base.brightYellow,
      brightBlue: base.brightBlue,
      brightMagenta: base.brightMagenta,
      brightCyan: base.brightCyan,
      brightWhite: base.brightWhite,
      searchHitBackground: base.searchHitBackground,
      searchHitBackgroundCurrent: base.searchHitBackgroundCurrent,
      searchHitForeground: base.searchHitForeground,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.connected,
    required this.onStart,
    required this.onStop,
  });

  final ShellState state;
  final bool connected;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SectionHeader(
        context.l10n.terminalTitle,
        subtitle: context.l10n.terminalSubtitle,
        trailing: state.isOpen
            ? OutlinedButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(context.l10n.terminalCloseSession),
              )
            : FilledButton.icon(
                onPressed: connected && !state.isOpening ? onStart : null,
                icon: const Icon(Icons.terminal, size: 18),
                label: Text(
                  state.isOpening
                      ? context.l10n.terminalOpening
                      : context.l10n.terminalStartSession,
                ),
              ),
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return CenteredNotice(
      icon: Icons.terminal_outlined,
      title: context.l10n.terminalNoSessionTitle,
      // The error came off the wire; it stays in the language it arrived in.
      body: [context.l10n.terminalNoSessionBody, ?error].join('\n\n'),
    );
  }
}

class _OperationWarning extends StatelessWidget {
  const _OperationWarning({required this.operation});

  final String operation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.08),
        border: Border.all(color: context.colors.error.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 16, color: context.colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.terminalOperationWarning(operation),
              style: context.texts.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
