import 'dart:io';

import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/server_target.dart';

/// A scripted [SshTransport] that records every command it is asked to run.
///
/// This is what makes the per-ServiceKind command matrix testable at all. Those command
/// strings are the entire contract with the remote host — a typo in one is a production
/// failure no type checker catches — so they are asserted literally rather than trusted.
class FakeTransport implements SshTransport {
  FakeTransport({
    this.host = 'test-host',
    Map<String, ExecOutput>? responses,
    this.defaultResponse = const ExecOutput.empty(),
  }) : _responses = responses ?? <String, ExecOutput>{};

  @override
  final String host;

  final Map<String, ExecOutput> _responses;

  /// Returned when nothing more specific matches.
  final ExecOutput defaultResponse;

  /// Substring-matched responses, for commands whose exact text isn't the point of the
  /// assertion. First match wins, in insertion order.
  final List<({String contains, ExecOutput output})> _patterns = [];

  /// Every command run, in order.
  final List<String> commands = [];

  final List<({File local, String remote})> uploads = [];
  final List<({String remote, File local})> downloads = [];

  /// Registers an exact-match response.
  void respondTo(String command, ExecOutput output) =>
      _responses[command] = output;

  /// Registers a substring-match response.
  void respondToContaining(String fragment, ExecOutput output) =>
      _patterns.add((contains: fragment, output: output));

  /// Convenience for the common "succeeded, here's stdout" case.
  void stdoutFor(String command, String stdout) =>
      respondTo(command, ExecOutput(stdout: stdout, stderr: '', exitStatus: 0));

  void stdoutForContaining(String fragment, String stdout) =>
      respondToContaining(
        fragment,
        ExecOutput(stdout: stdout, stderr: '', exitStatus: 0),
      );

  /// The single command run, asserting exactly one was.
  String get onlyCommand {
    if (commands.length != 1) {
      throw StateError(
        'expected exactly 1 command, got ${commands.length}: $commands',
      );
    }
    return commands.single;
  }

  String get lastCommand => commands.last;

  void clear() {
    commands.clear();
    uploads.clear();
    downloads.clear();
  }

  @override
  Future<ExecOutput> exec(String cmd) async {
    commands.add(cmd);
    final exact = _responses[cmd];
    if (exact != null) return exact;
    for (final p in _patterns) {
      if (cmd.contains(p.contains)) return p.output;
    }
    return defaultResponse;
  }

  @override
  Future<int> pushFile(
    File local,
    String remote, {
    void Function(int sent, int total)? onProgress,
  }) async {
    uploads.add((local: local, remote: remote));
    final total = local.existsSync() ? local.lengthSync() : 0;
    onProgress?.call(total, total);
    return total;
  }

  @override
  Future<int> pullFile(
    String remote,
    File local, {
    void Function(int received, int? total)? onProgress,
  }) async {
    downloads.add((remote: remote, local: local));
    onProgress?.call(0, 0);
    return 0;
  }
}

/// Records what the transport reports to the audit trail, without a database.
class RecordingAuditSink implements SshCommandAuditSink {
  final List<
    ({
      String command,
      int? exitCode,
      String stdout,
      String stderr,
      int durationMs,
    })
  >
  commands = [];

  final List<({String context, String message})> errors = [];

  @override
  Future<void> recordCommand({
    required String command,
    required int? exitCode,
    required String stdout,
    required String stderr,
    required int durationMs,
  }) async {
    commands.add((
      command: command,
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      durationMs: durationMs,
    ));
  }

  @override
  Future<void> recordError({
    required String context,
    required String message,
  }) async {
    errors.add((context: context, message: message));
  }
}
