import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/ssh/ssh_session.dart';
import 'package:world_keeper/core/ssh/ssh_target.dart';

/// The connection lifecycle, as a sealed type.
///
/// Mirrors the Rust app's two-state `Connection` enum, with the transient states it kept
/// implicitly in the React layer promoted into the same type. Sealed, so a `switch` over
/// it must be exhaustive — adding a state later is a compile error at every site that
/// cares, rather than a silently missing branch in the UI.
///
/// The distinction that matters is [ConnectedRaw] versus [ConnectedTarget]: authenticated
/// but not yet discovered, versus discovery confirmed and ready to operate. Only the
/// latter can produce a target, which is what stops any operation from running against a
/// host whose service and worlds path are still unknown.
sealed class ConnectionStatus {
  const ConnectionStatus();

  /// The profile this state relates to, or `null` when disconnected.
  Profile? get profile => switch (this) {
    Disconnected() => null,
    Connecting(:final profile) => profile,
    ConnectedRaw(:final profile) => profile,
    ConnectedTarget(:final profile) => profile,
  };

  SshSession? get session => switch (this) {
    Disconnected() || Connecting() => null,
    ConnectedRaw(:final session) => session,
    ConnectedTarget(:final session) => session,
  };

  /// The confirmed target, available only once discovery has been accepted.
  SshTarget? get target => switch (this) {
    ConnectedTarget(:final target) => target,
    Disconnected() || Connecting() || ConnectedRaw() => null,
  };

  bool get isConnected => this is ConnectedRaw || this is ConnectedTarget;

  bool get isBusy => this is Connecting;

  /// Profile selection, editing and deletion are locked while connected — switching
  /// profiles mid-session was never a supported operation.
  bool get allowsProfileEditing => this is Disconnected;
}

final class Disconnected extends ConnectionStatus {
  const Disconnected({this.error});

  /// Why the last attempt failed, if it did. Cleared when the next one starts.
  final String? error;
}

final class Connecting extends ConnectionStatus {
  const Connecting(this.profile);

  @override
  final Profile profile;
}

/// Authenticated, but discovery has not been confirmed for this profile yet.
final class ConnectedRaw extends ConnectionStatus {
  const ConnectedRaw({required this.profile, required this.session});

  @override
  final Profile profile;

  @override
  final SshSession session;
}

/// Authenticated and confirmed — the only state that can act on the server.
final class ConnectedTarget extends ConnectionStatus {
  const ConnectedTarget({
    required this.profile,
    required this.session,
    required this.target,
  });

  @override
  final Profile profile;

  @override
  final SshSession session;

  @override
  final SshTarget target;
}
