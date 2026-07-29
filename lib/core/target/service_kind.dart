/// How the game server is controlled on the target host.
///
/// Discovered on connect, never declared by the user — see the discovery probe. This is
/// the type the whole "target-agnostic" design hangs off: the push/pull/restore
/// envelopes never look at it, only the SSH target implementation branches on it.
///
/// Hand-written rather than generated because the JSON representation has to match the
/// Rust app's `#[serde(tag = "type", rename_all = "lowercase")]` output byte for byte,
/// so an existing `config.json` keeps working:
///
/// ```json
/// {"type": "systemd", "unit": "corekeeper"}
/// {"type": "docker",  "container": "core-keeper"}
/// {"type": "process", "stopCmd": "...", "startCmd": "...", "logPath": null}
/// ```
///
/// Note the asymmetry, which is faithful to the original: the variant tag is lowercase
/// but the struct-variant fields are camelCase.
sealed class ServiceKind {
  const ServiceKind();

  factory ServiceKind.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    return switch (type) {
      'systemd' => SystemdService(unit: json['unit'] as String),
      'docker' => DockerService(container: json['container'] as String),
      'process' => ProcessService(
        stopCmd: json['stopCmd'] as String,
        startCmd: json['startCmd'] as String,
        logPath: json['logPath'] as String?,
      ),
      _ => throw FormatException('unknown ServiceKind type: $type'),
    };
  }

  Map<String, dynamic> toJson();

  /// Short human label, e.g. `systemd: corekeeper`. Used in the discovery confirmation
  /// UI and the command reference.
  String get label;
}

final class SystemdService extends ServiceKind {
  const SystemdService({required this.unit});

  final String unit;

  @override
  Map<String, dynamic> toJson() => {'type': 'systemd', 'unit': unit};

  @override
  String get label => 'systemd: $unit';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SystemdService && other.unit == unit);

  @override
  int get hashCode => Object.hash(SystemdService, unit);

  @override
  String toString() => 'SystemdService(unit: $unit)';
}

final class DockerService extends ServiceKind {
  const DockerService({required this.container});

  final String container;

  @override
  Map<String, dynamic> toJson() => {'type': 'docker', 'container': container};

  @override
  String get label => 'docker: $container';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DockerService && other.container == container);

  @override
  int get hashCode => Object.hash(DockerService, container);

  @override
  String toString() => 'DockerService(container: $container)';
}

final class ProcessService extends ServiceKind {
  const ProcessService({
    required this.stopCmd,
    required this.startCmd,
    this.logPath,
  });

  final String stopCmd;
  final String startCmd;

  /// `null` when discovery couldn't find a log file — the target's log-tail operation
  /// has nothing to read in that case and says so rather than inventing a path.
  final String? logPath;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'process',
    'stopCmd': stopCmd,
    'startCmd': startCmd,
    'logPath': logPath,
  };

  @override
  String get label => 'process: $startCmd';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessService &&
          other.stopCmd == stopCmd &&
          other.startCmd == startCmd &&
          other.logPath == logPath);

  @override
  int get hashCode => Object.hash(ProcessService, stopCmd, startCmd, logPath);

  @override
  String toString() =>
      'ProcessService(stopCmd: $stopCmd, startCmd: $startCmd, logPath: $logPath)';
}
