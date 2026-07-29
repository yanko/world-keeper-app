import 'package:flutter/material.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/features/terminal/data/terminal_session.dart';
import 'package:world_keeper/l10n/l10n.dart';
import 'package:xterm/xterm.dart';

/// The keys a software keyboard doesn't have.
///
/// **Not polish.** Without Esc you cannot leave `vim`'s insert mode; without Ctrl you
/// cannot interrupt a runaway process or send EOF; without arrows you cannot move through
/// history or scroll `less`. A mobile shell missing these is a shell you can start and
/// then get stuck inside.
///
/// Ctrl, Alt and Shift are **sticky**: tapping one arms it for the next keypress only, so
/// `Ctrl` then `c` produces `^C` exactly as a physical keyboard would. Armed state is
/// shown, because an invisible mode is a trap.
class AccessoryKeyBar extends StatelessWidget {
  const AccessoryKeyBar({required this.session, super.key});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session.keyboard,
      builder: (context, _) => Material(
        color: context.colors.surface,
        child: SafeArea(
          top: false,
          child: SizedBox(
            // A horizontal ListView needs a bounded height, and a fixed one stops being
            // right the moment the text scale moves — the keys are labelled, so they grow.
            // 36 is the button's minimum height and 12 is the padding above and below.
            height: MediaQuery.textScalerOf(context).scale(36) + 12,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                _ModifierKey(
                  label: 'Ctrl',
                  armed: session.keyboard.ctrl,
                  onTap: session.keyboard.toggleCtrl,
                ),
                _ModifierKey(
                  label: 'Alt',
                  armed: session.keyboard.alt,
                  onTap: session.keyboard.toggleAlt,
                ),
                const _Divider(),
                _Key(
                  label: 'Esc',
                  onTap: () => session.sendKey(TerminalKey.escape),
                ),
                _Key(
                  label: 'Tab',
                  onTap: () => session.sendKey(TerminalKey.tab),
                ),
                // The two most-used control sequences, as one tap each: interrupt, and
                // end-of-input. Reaching them via the sticky Ctrl works too, but these
                // are worth the shortcut.
                // The key legends themselves — Ctrl, Esc, ^C, PgUp — are not translated.
                // They are what is printed on a keyboard and what the shell's own
                // documentation calls them; the tooltips explain what they do.
                _Key(
                  label: '^C',
                  tooltip: context.l10n.terminalKeyInterrupt,
                  onTap: () => session.sendKey(TerminalKey.keyC, ctrl: true),
                ),
                _Key(
                  label: '^D',
                  tooltip: context.l10n.terminalKeyEndOfInput,
                  onTap: () => session.sendKey(TerminalKey.keyD, ctrl: true),
                ),
                _Key(
                  label: '^Z',
                  tooltip: context.l10n.terminalKeySuspend,
                  onTap: () => session.sendKey(TerminalKey.keyZ, ctrl: true),
                ),
                const _Divider(),
                _Key(
                  icon: Icons.keyboard_arrow_left,
                  tooltip: context.l10n.terminalKeyLeft,
                  onTap: () => session.sendKey(TerminalKey.arrowLeft),
                ),
                _Key(
                  icon: Icons.keyboard_arrow_down,
                  tooltip: context.l10n.terminalKeyDown,
                  onTap: () => session.sendKey(TerminalKey.arrowDown),
                ),
                _Key(
                  icon: Icons.keyboard_arrow_up,
                  tooltip: context.l10n.terminalKeyUp,
                  onTap: () => session.sendKey(TerminalKey.arrowUp),
                ),
                _Key(
                  icon: Icons.keyboard_arrow_right,
                  tooltip: context.l10n.terminalKeyRight,
                  onTap: () => session.sendKey(TerminalKey.arrowRight),
                ),
                const _Divider(),
                _Key(
                  label: 'Home',
                  onTap: () => session.sendKey(TerminalKey.home),
                ),
                _Key(
                  label: 'End',
                  onTap: () => session.sendKey(TerminalKey.end),
                ),
                _Key(
                  label: 'PgUp',
                  onTap: () => session.sendKey(TerminalKey.pageUp),
                ),
                _Key(
                  label: 'PgDn',
                  onTap: () => session.sendKey(TerminalKey.pageDown),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.tooltip, required this.onTap});

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          // Comfortably above the 48 dp touch minimum in width, and dense enough that a
          // useful number of keys fit on a 360 px screen.
          minimumSize: const Size(46, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: monoStyle(context, fontSize: 12),
        ),
        child: icon != null
            ? Icon(icon, size: 18)
            : Text(label!, style: monoStyle(context, fontSize: 12)),
      ),
    );

    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _ModifierKey extends StatelessWidget {
  const _ModifierKey({
    required this.label,
    required this.armed,
    required this.onTap,
  });

  final String label;
  final bool armed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        toggled: armed,
        label: context.l10n.terminalModifier(label),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(46, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            // Armed state has to be unmistakable — a modifier you have forgotten about
            // silently changes what the next key does.
            backgroundColor: armed ? context.wk.signal : null,
            foregroundColor: armed ? context.wk.onSignal : null,
            side: BorderSide(
              color: armed ? context.wk.signal : context.colors.outline,
            ),
          ),
          child: Text(label, style: monoStyle(context, fontSize: 12)),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: VerticalDivider(width: 1, color: context.colors.outline),
  );
}
