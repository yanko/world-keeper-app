import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/core/audit/audit_sink.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/ssh/host_key_store.dart';
import 'package:world_keeper/core/ssh/key_generator.dart';
import 'package:world_keeper/core/ssh/ssh_key_store.dart';
import 'package:world_keeper/core/ssh/ssh_session.dart';
import 'package:world_keeper/core/ssh/ssh_target.dart';
import 'package:world_keeper/features/connection/domain/connection_status.dart';

/// Asked to approve a host key the app has not seen before, or one that has changed.
///
/// Returning `false` aborts the connection. Deliberately a callback supplied by the UI
/// rather than a policy baked in here: a changed fingerprint is a question only a human
/// can answer, and it must never resolve itself.
typedef HostKeyPrompt =
    Future<bool> Function({
      required String host,
      required int port,
      required String type,
      required String fingerprint,
      required HostKeyVerdict verdict,
      required String? pinnedFingerprint,
    });

/// Owns the single active connection.
///
/// One at a time, matching the original design. Connecting while already connected
/// disconnects first, so there is never a leaked session.
class ConnectionController extends Notifier<ConnectionStatus> {
  /// Mirrors the session held by [state].
  ///
  /// Riverpod forbids reading `state` inside a lifecycle callback, so `onDispose` cannot
  /// look it up when the container is torn down — and without this the SSH connection
  /// would simply leak. Every state assignment goes through [_setState] to keep the two
  /// in step.
  SshSession? _openSession;

  /// Watches for the app coming back from the background.
  AppLifecycleListener? _lifecycle;

  /// The last state seen, so a *transition* can be recognised rather than a state.
  AppLifecycleState? _lastLifecycleState;

  @override
  ConnectionStatus build() {
    // A headless unit test has no `WidgetsBinding`, and `AppLifecycleListener` reaches
    // for it in its constructor. Letting that throw would mean this controller could not
    // be built without a widget tree — and it is read, directly or transitively, by most
    // of the suite. There is no lifecycle to observe in a test anyway, so failing to
    // attach is the correct outcome rather than a swallowed error.
    try {
      _lifecycle = AppLifecycleListener(
        onStateChange: (next) {
          final previous = _lastLifecycleState;
          _lastLifecycleState = next;
          if (shouldVerifyConnection(previous, next)) _verifyStillConnected();
        },
      );
    } on Object {
      _lifecycle = null;
    }

    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
      _openSession?.close().ignore();
      _openSession = null;
    });
    return const Disconnected();
  }

  /// Checks the connection is still real after the app was suspended.
  ///
  /// Android freezes a backgrounded process: the isolate stops and the TCP socket is torn
  /// down by the OS, without anything in this app being told. On return, the state still
  /// says "Connected", the status chip is still teal, and every command fails with a
  /// transport error that reads like the server's fault.
  ///
  /// This is **not** a bug in the SSH layer and cannot be fixed there — it is the platform
  /// doing what it is designed to do, and is the same reason push and pull carry a "keep
  /// the app open" warning. What is fixable is the app claiming a connection it no longer
  /// has.
  ///
  /// One cheap round trip decides it. `true` is the smallest possible command and touches
  /// nothing.
  Future<void> _verifyStillConnected() async {
    final session = _openSession;
    if (session == null) return;

    try {
      final out = await session
          .exec('true')
          .timeout(const Duration(seconds: 8));
      if (out.exitStatus == 0) return;
    } on Object {
      // Any failure at all is the answer: the socket is gone.
    }

    // Deliberately not an automatic reconnect. A password profile has no password to
    // reconnect with, and reconnecting silently would re-run the host-key check without
    // anyone watching. The Connect button is one tap away and says what happened.
    await disconnect(reason: _backgroundDropReason);
  }

  void _setState(ConnectionStatus next) {
    _openSession = next.session;
    state = next;
  }

  /// Connects using [profile], prompting via [onHostKey] when the key is unknown or has
  /// changed.
  ///
  /// [password] is required for password profiles and ignored otherwise.
  Future<void> connect(
    Profile profile, {
    String? password,
    required HostKeyPrompt onHostKey,
  }) async {
    if (state.isBusy) return;
    await disconnect();

    _setState(Connecting(profile));

    final store = ref.read(hostKeyStoreProvider);

    Future<bool> verify({
      required String host,
      required int port,
      required String type,
      required String fingerprint,
    }) async {
      final pinned = await store.pinnedFingerprint(host, port);
      final verdict = await store.verify(
        host: host,
        port: port,
        fingerprint: fingerprint,
      );
      if (verdict == HostKeyVerdict.match) return true;

      final accepted = await onHostKey(
        host: host,
        port: port,
        type: type,
        fingerprint: fingerprint,
        verdict: verdict,
        pinnedFingerprint: pinned,
      );
      if (!accepted) {
        throw HostKeyException(
          verdict == HostKeyVerdict.mismatch
              ? 'the host key for $host:$port has changed'
              : 'the host key for $host:$port was not accepted',
          expectedFingerprint: pinned,
          actualFingerprint: fingerprint,
        );
      }
      // Only pinned once a human has said yes — trust on first *confirmed* use.
      await store.pin(
        host: host,
        port: port,
        type: type,
        fingerprint: fingerprint,
      );
      return true;
    }

    try {
      final session = switch (profile.auth) {
        AuthMethod.password => await _connectPassword(
          profile,
          password,
          verify,
        ),
        AuthMethod.key => await _connectKey(profile, verify),
      };

      final db = ref.read(auditDatabaseProvider);
      // Rolls the session row when this run was previously connected elsewhere, so the
      // two servers' rows never share one session — see [AuditSessionController].
      final sessionId = await ref
          .read(auditSessionIdProvider.notifier)
          .recordConnect(profile);
      session.audit = DatabaseAuditSink(db, sessionId);

      await db.logEvent(
        sessionId,
        'connect',
        detail: {'host': profile.host, 'user': profile.user},
        ok: true,
      );

      // A profile with cached discovery goes straight to a usable target; otherwise the
      // UI routes to the discovery screen.
      final discovered = profile.discovered;
      final kind = discovered?.serviceKind;
      _setState(
        kind == null
            ? ConnectedRaw(profile: profile, session: session)
            : ConnectedTarget(
                profile: profile,
                session: session,
                target: SshTarget(
                  transport: session,
                  serviceKind: kind,
                  worldsPath: discovered?.worldsPath ?? '',
                  steamUser: discovered?.steamUser,
                ),
              ),
      );
    } on Object catch (e) {
      final message = e is WkException ? e.message : e.toString();
      _setState(Disconnected(error: message));
      await _logConnectFailure(profile, message);
      rethrow;
    }
  }

  Future<SshSession> _connectPassword(
    Profile profile,
    String? password,
    HostKeyVerifier verify,
  ) {
    if (password == null || password.isEmpty) {
      throw const AuthException('a password is required for this profile');
    }
    return SshSession.connectPassword(
      host: profile.host,
      port: profile.port,
      username: profile.user,
      password: password,
      verifyHostKey: verify,
    );
  }

  Future<SshSession> _connectKey(Profile profile, HostKeyVerifier verify) {
    final keyPath = profile.keyPath;
    if (keyPath == null || keyPath.isEmpty) {
      throw const AuthException(
        'this profile is set to key auth but has no key path',
      );
    }
    return SshSession.connectKey(
      host: profile.host,
      port: profile.port,
      username: profile.user,
      privateKeyFile: File(keyPath),
      verifyHostKey: verify,
    );
  }

  Future<void> _logConnectFailure(Profile profile, String message) async {
    try {
      await ref
          .read(auditDatabaseProvider)
          .logError(
            ref.read(auditSessionIdProvider),
            context: 'connect',
            message: message,
            detail: {
              'host': profile.host,
              'user': profile.user,
              'authMethod': profile.auth.name,
            },
          );
    } on Object {
      // Never let an audit write mask the connection error the user actually needs.
    }
  }

  /// Promotes a raw connection to a confirmed target once discovery is accepted.
  void applyDiscovery(Discovered discovered) {
    final current = state;
    if (current is! ConnectedRaw && current is! ConnectedTarget) return;

    final kind = discovered.serviceKind;
    if (kind == null) return;

    final session = current.session!;
    final profile = current.profile!;

    _setState(
      ConnectedTarget(
        profile: profile.copyWith(discovered: discovered),
        session: session,
        target: SshTarget(
          transport: session,
          serviceKind: kind,
          worldsPath: discovered.worldsPath ?? '',
          steamUser: discovered.steamUser,
        ),
      ),
    );
  }

  /// Replaces this profile's password with a key, so it never asks again.
  ///
  /// The answer to "remember my password", and a better one than remembering it. A key is
  /// per-host, it is revoked by deleting one line on that host, and the secret never
  /// travels — only the public half is sent. A stored password is the same secret,
  /// reusable anywhere the user reused it, sitting in a credential store.
  ///
  /// Runs over the connection that is already open, which is the whole reason it is
  /// offered here rather than in the profile editor: authenticating with the password one
  /// last time is what earns the right to install the key.
  ///
  /// **Ordered so a failure is never worse than not having tried.** The key is installed
  /// on the server *before* the profile is switched to key auth, because the reverse
  /// leaves a profile that cannot connect at all — key auth against a host that never
  /// received the key, with the password no longer being asked for. Installing a key that
  /// then goes unused is harmless; the opposite is a locked door.
  Future<void> setUpKeyAuth() async {
    final current = state;
    final session = current.session;
    final profile = current.profile;
    if (session == null || profile == null) {
      throw const AuthException('not connected');
    }

    final generated = await generateEd25519KeyPair(
      // Identifies the line in `authorized_keys` months later, when the question is
      // "what is this key and can I delete it".
      comment: 'world-keeper:${profile.name}',
    );

    // Server first — see above.
    await session.installPublicKey(generated.publicKeyLine);

    final keyPath = await SshKeyStore(
      ref.read(appPathsProvider),
    ).write(profile.id, generated.privateKeyPem);

    final updated = profile.copyWith(
      auth: AuthMethod.key,
      keyPath: keyPath,
      // Any password saved for this profile is now dead weight, and the flag has to go
      // with it or the connect path would keep looking for one.
      savePassword: false,
    );
    await ref.read(configProvider.notifier).upsertProfile(updated);

    await ref
        .read(auditDatabaseProvider)
        .logEvent(
          ref.read(auditSessionIdProvider),
          'key_auth_installed',
          detail: {
            'profileId': profile.id,
            'host': profile.host,
            'user': profile.user,
            // The public key, which is public. Recorded because "when did this host start
            // trusting this key" is exactly the question an audit log should answer.
            'publicKey': generated.publicKeyLine,
          },
          ok: true,
        );

    // The live session keeps its password authentication — it is already open, and
    // re-authenticating would drop a connection that is working. The profile is what
    // changed, so the state carries the new one.
    _setState(switch (current) {
      ConnectedTarget(:final target) => ConnectedTarget(
        profile: updated,
        session: session,
        target: target,
      ),
      _ => ConnectedRaw(profile: updated, session: session),
    });
  }

  /// Drops back to the pre-discovery state so the probe can be re-run.
  void rescan() {
    final current = state;
    if (current is! ConnectedTarget) return;
    _setState(ConnectedRaw(profile: current.profile, session: current.session));
  }

  /// Marker for the one disconnect that needs explaining rather than announcing.
  static const String _backgroundDropReason = 'background';

  /// Shown in place of a connection error, because there was no error — the OS simply
  /// stopped the process. Not localised for the same reason other connection errors are
  /// not: it lands in the audit log's `Disconnected` state alongside messages that came
  /// off the wire. See `l10n.dart`.
  static const String _backgroundDropMessage =
      'The connection dropped while the app was in the background — Android suspends '
      'the process and the socket with it. Connect again to carry on.';

  Future<void> disconnect({String? reason}) async {
    final current = state;
    final session = current.session;
    // A dropped connection is a `Disconnected` carrying an explanation, so the screens
    // that gate on a connection say why they are empty instead of just being empty.
    final ended = reason == _backgroundDropReason
        ? const Disconnected(error: _backgroundDropMessage)
        : const Disconnected();

    if (session == null) {
      if (current is! Disconnected) _setState(ended);
      return;
    }

    _setState(ended);
    try {
      await ref
          .read(auditDatabaseProvider)
          .logEvent(
            ref.read(auditSessionIdProvider),
            'disconnect',
            detail: {'profileId': current.profile?.id, 'reason': ?reason},
            ok: true,
          );
    } on Object {
      // Disconnecting must always succeed from the user's point of view.
    }
    await session.close();
  }
}

/// Whether coming back to [next] means the SSH connection has to be re-checked.
///
/// A *transition*, not a state. `resumed` is reported on every window focus on desktop and
/// on every return from the app switcher, and re-running a command over SSH each time
/// somebody alt-tabs is noise. Only `paused` and `detached` mean the process was actually
/// frozen, and only then can the socket have died underneath us.
///
/// Split out because `AppLifecycleListener` cannot be driven from a unit test without a
/// widget tree, and this is the part worth being sure of.
bool shouldVerifyConnection(
  AppLifecycleState? previous,
  AppLifecycleState next,
) =>
    next == AppLifecycleState.resumed &&
    (previous == AppLifecycleState.paused ||
        previous == AppLifecycleState.detached);
