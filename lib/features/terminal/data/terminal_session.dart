import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/ssh/ssh_session.dart';
import 'package:xterm/xterm.dart';

/// A live interactive shell.
///
/// Architecturally unlike everything else in this app. Every other SSH interaction is
/// request/response — `exec` sends one command, waits for it to exit, returns the output.
/// This is a standing bidirectional stream on its own channel, concurrent with and
/// independent of the stats poller and any running push.
///
/// **This is a real, unsandboxed shell as whatever user the profile connects as** — root
/// on the reference host. That is the same trust level as `ssh root@host`, not a new
/// privilege, but it is not a toy either, which is why it is never opened automatically.
class TerminalSession {
  // Dart forbids private names for *named* parameters, so `this._shell` is not an
  // option here and the lint's suggestion cannot be followed.
  // ignore_for_file: prefer_initializing_formals
  TerminalSession._({
    required this.terminal,
    required this.keyboard,
    required SSHSession shell,
  }) : _shell = shell;

  final Terminal terminal;

  /// Sticky modifier state, shared with the on-screen key bar.
  final StickyModifiers keyboard;

  final SSHSession _shell;
  final List<StreamSubscription<void>> _subscriptions = [];

  bool _closed = false;
  bool get isClosed => _closed;

  /// Fires when the remote side ends the session — `exit`, or the connection dropping.
  final _onClosed = Completer<void>();
  Future<void> get closed => _onClosed.future;

  static Future<TerminalSession> open(
    SshSession session, {
    int columns = 80,
    int rows = 24,
    int maxLines = 10000,
  }) async {
    final keyboard = StickyModifiers(defaultInputHandler);
    final terminal = Terminal(maxLines: maxLines, inputHandler: keyboard);

    final SSHSession shell;
    try {
      shell = await session.openShell(columns: columns, rows: rows);
    } on Object catch (e) {
      throw SshException('could not open a shell', cause: e);
    }

    final self = TerminalSession._(
      terminal: terminal,
      keyboard: keyboard,
      shell: shell,
    );

    // Keystrokes out. `onOutput` is xterm's name for "the user typed something",
    // confusingly — it is the terminal's output *towards the host*.
    terminal.onOutput = (data) {
      if (self._closed) return;
      shell.write(utf8.encode(data));
      // A sticky modifier applies to exactly one keypress, then clears — holding it
      // latched would make the next ordinary letter behave surprisingly.
      keyboard.consume();
    };

    // Window changes out, so full-screen programs redraw at the right size.
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      if (self._closed) return;
      shell.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };

    // Bytes in. stdout and stderr both go to the screen — a terminal makes no
    // distinction, and hiding stderr would hide most error output.
    //
    // `allowMalformed` because a shell can emit arbitrary bytes (a stray binary, a
    // mis-set locale) and a decode failure must not tear down the session.
    const decoder = Utf8Decoder(allowMalformed: true);
    self._subscriptions.addAll([
      shell.stdout.cast<List<int>>().transform(decoder).listen(terminal.write),
      shell.stderr.cast<List<int>>().transform(decoder).listen(terminal.write),
    ]);

    unawaited(shell.done.then((_) => self._handleRemoteClose()));

    return self;
  }

  void _handleRemoteClose() {
    if (_closed) return;
    _closed = true;
    terminal.write('\r\n\x1b[31m[session closed]\x1b[0m\r\n');
    if (!_onClosed.isCompleted) _onClosed.complete();
  }

  /// Sends a key as though it had been pressed, honouring the sticky modifiers.
  ///
  /// Used by the on-screen key bar for keys a software keyboard does not offer.
  void sendKey(TerminalKey key, {bool ctrl = false, bool alt = false}) {
    if (_closed) return;
    terminal.keyInput(
      key,
      ctrl: ctrl || keyboard.ctrl,
      alt: alt || keyboard.alt,
      shift: keyboard.shift,
    );
    keyboard.consume();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    try {
      _shell.close();
    } on Object {
      // Already gone.
    }
    if (!_onClosed.isCompleted) _onClosed.complete();
  }
}

/// Modifier keys that can be tapped rather than held.
///
/// A phone keyboard has no Ctrl or Alt, so they are offered as buttons. Tapping one arms
/// it for the **next** keypress only, which is what makes `Ctrl` then `C` produce `^C`
/// the way a physical keyboard would.
///
/// Wraps xterm's default input handler and injects the armed modifiers into each event,
/// so it composes with real hardware keys rather than replacing them — a desktop user
/// with a physical Ctrl is unaffected.
class StickyModifiers extends TerminalInputHandler with ChangeNotifier {
  StickyModifiers(this._inner);

  final TerminalInputHandler _inner;

  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;

  bool get ctrl => _ctrl;
  bool get alt => _alt;
  bool get shift => _shift;

  bool get anyArmed => _ctrl || _alt || _shift;

  void toggleCtrl() {
    _ctrl = !_ctrl;
    notifyListeners();
  }

  void toggleAlt() {
    _alt = !_alt;
    notifyListeners();
  }

  void toggleShift() {
    _shift = !_shift;
    notifyListeners();
  }

  /// Clears the armed modifiers after they have been applied to one keypress.
  void consume() {
    if (!anyArmed) return;
    _ctrl = false;
    _alt = false;
    _shift = false;
    notifyListeners();
  }

  @override
  String? call(TerminalKeyboardEvent event) => _inner.call(
    event.copyWith(
      ctrl: event.ctrl || _ctrl,
      alt: event.alt || _alt,
      shift: event.shift || _shift,
    ),
  );
}
