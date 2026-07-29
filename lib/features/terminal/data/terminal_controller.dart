import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/features/terminal/data/terminal_session.dart';

/// Owns the single shell session.
///
/// One at a time, mirroring "one connection at a time". Opening again replaces the
/// previous session rather than accumulating shells nobody can see.
///
/// **Never opened automatically.** This is a real root shell; it exists because the user
/// asked for it, not because a tab was rendered.
///
/// Named `ShellSessionController` rather than the obvious `TerminalController` because
/// xterm exports a widget-level `TerminalController` of its own, and two types with the
/// same name in the same file is a readability tax paid on every future edit.
class ShellSessionController extends Notifier<ShellState> {
  TerminalSession? _session;

  @override
  ShellState build() {
    // Disconnecting must take the shell with it — a session whose transport has gone is
    // a dead rectangle that still looks alive.
    ref.listen(connectionProvider, (previous, next) {
      if (!next.isConnected && _session != null) {
        closeSession();
      }
    });
    ref.onDispose(() {
      _session?.close();
      _session = null;
    });
    return const ShellState.closed();
  }

  TerminalSession? get session => _session;

  Future<void> openSession({int columns = 80, int rows = 24}) async {
    final sshSession = ref.read(connectionProvider).session;
    if (sshSession == null) {
      throw const NotConnectedException('connect before opening a terminal');
    }
    if (state.isOpening) return;

    await closeSession();
    state = const ShellState.opening();

    try {
      final session = await TerminalSession.open(
        sshSession,
        columns: columns,
        rows: rows,
      );
      _session = session;
      state = ShellState.open(session);

      // The remote side can end the session on its own — `exit`, a timeout, the
      // connection dropping. Reflect that rather than showing a live-looking shell.
      unawaited(
        session.closed.then((_) {
          if (identical(_session, session)) {
            _session = null;
            state = const ShellState.closed();
          }
        }),
      );

      await ref
          .read(auditDatabaseProvider)
          .logEvent(
            ref.read(auditSessionIdProvider),
            'terminal_open',
            ok: true,
          );
    } on Object catch (e) {
      state = ShellState.closed(error: e is WkException ? e.message : '$e');
      rethrow;
    }
  }

  Future<void> closeSession() async {
    final session = _session;
    _session = null;
    state = const ShellState.closed();
    if (session == null) return;

    await session.close();
    try {
      await ref
          .read(auditDatabaseProvider)
          .logEvent(
            ref.read(auditSessionIdProvider),
            'terminal_close',
            ok: true,
          );
    } on Object {
      // Closing must always succeed from the user's point of view.
    }
  }
}

sealed class ShellState {
  const ShellState();

  const factory ShellState.closed({String? error}) = ShellClosed;
  const factory ShellState.opening() = ShellOpening;
  const factory ShellState.open(TerminalSession session) = ShellOpen;

  bool get isOpen => this is ShellOpen;
  bool get isOpening => this is ShellOpening;

  TerminalSession? get sessionOrNull => switch (this) {
    ShellOpen(:final session) => session,
    ShellClosed() || ShellOpening() => null,
  };
}

final class ShellClosed extends ShellState {
  const ShellClosed({this.error});

  /// Why the last attempt failed, if it did.
  final String? error;
}

final class ShellOpening extends ShellState {
  const ShellOpening();
}

final class ShellOpen extends ShellState {
  const ShellOpen(this.session);
  final TerminalSession session;
}

final terminalProvider = NotifierProvider<ShellSessionController, ShellState>(
  ShellSessionController.new,
);
