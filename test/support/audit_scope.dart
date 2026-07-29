import 'package:world_keeper/app/providers.dart';

/// Pins the audit screen to one server in a widget test.
///
/// The real controller derives its scope from [connectionProvider], and every connected
/// state holds an `SshSession` whose constructor is private — so a test cannot produce a
/// *locked* scope through the front door. Tests that care about the derivation itself
/// override `connectionProvider` and `auditedProfilesProvider` and use the real controller;
/// this is for tests that only need a server to be in scope.
class FixedAuditScope extends AuditScopeController {
  FixedAuditScope(this._scope);

  final AuditScope? _scope;

  @override
  AuditScope? build() => _scope;
}

/// A movable scope, for tests that watch the screen react to connect and disconnect.
class MovableAuditScope extends AuditScopeController {
  MovableAuditScope([this._initial]);

  final AuditScope? _initial;

  @override
  AuditScope? build() => _initial;

  // ignore: use_setters_to_change_properties — reads as an action at the call site.
  void moveTo(AuditScope? scope) => state = scope;
}
