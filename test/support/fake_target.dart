import 'dart:io';

import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/server_target.dart';
import 'package:world_keeper/core/target/service_kind.dart';

/// A programmable [ServerTarget] with no SSH, no network and no server.
///
/// This exists for Phase 4: the push/pull/restore envelopes are written purely against
/// [ServerTarget], so every branch that is otherwise almost impossible to exercise —
/// a stop that times out, a service that enters `failed` while starting, a checksum
/// mismatch, a download that fails *and* a restart that fails after it, a rollback with
/// no backup to restore — becomes an ordinary unit test.
///
/// The Rust app could not do this, and has no tests.
class FakeTarget implements ServerTarget {
  FakeTarget({
    required this.serviceKind,
    this.worldsPath = '/home/steam/worlds',
    RunState initialState = RunState.running,
  }) : _state = initialState;

  @override
  final ServiceKind serviceKind;

  @override
  final String worldsPath;

  RunState _state;

  // ---- scripting ----------------------------------------------------------------

  /// Exact-match command responses.
  final Map<String, ExecOutput> responses = {};

  /// Substring-matched responses, for commands whose exact text can't be predicted —
  /// a dated backup directory embeds a timestamp, for instance. Checked after
  /// [responses]; first match wins, in insertion order.
  final List<({String contains, ExecOutput output})> responsePatterns = [];

  /// Substring-matched failures, for the same reason.
  final List<({String contains, Object error})> failurePatterns = [];

  /// Files present per directory, keyed by directory path.
  final Map<String, List<FileEntry>> files = {};

  /// Log tail returned by [logsTail].
  String logTail = '';

  /// UDP listener lines returned by [udpListening].
  List<String> udpLines = const [];

  String? activeSinceValue;

  /// Run states handed out by successive [status] calls, then [_state] forever after.
  /// Lets a test script a stop that takes three polls, or one that never settles.
  final List<RunState> scriptedStates = [];

  /// Commands that should throw instead of returning, keyed by exact command.
  final Map<String, Object> failures = {};

  /// What a stop or start request should do to the reported state. Set to `null` to model a
  /// service that ignores the request — which is how a stop-timeout is tested.
  RunState? stateAfterStop = RunState.stopped;
  RunState? stateAfterStart = RunState.running;

  bool fixPermsThrows = false;

  // ---- recording ----------------------------------------------------------------

  final List<String> commands = [];
  final List<ServiceAction> serviceActions = [];
  final List<({File local, String remote})> uploads = [];
  final List<({String remote, File local})> downloads = [];

  int get statusCallCount => _statusCalls;
  int _statusCalls = 0;

  // ---- ServerTarget ---------------------------------------------------------------

  @override
  Future<ExecOutput> exec(String cmd) async {
    commands.add(cmd);

    final failure = failures[cmd];
    if (failure != null) throw failure;
    for (final f in failurePatterns) {
      if (cmd.contains(f.contains)) throw f.error;
    }

    final exact = responses[cmd];
    if (exact != null) return exact;
    for (final r in responsePatterns) {
      if (cmd.contains(r.contains)) return r.output;
    }
    return const ExecOutput.empty();
  }

  /// Registers a substring-matched non-zero exit.
  void failCommandsContaining(String fragment, {String stderr = 'failed'}) =>
      responsePatterns.add((
        contains: fragment,
        output: ExecOutput(stdout: '', stderr: stderr, exitStatus: 1),
      ));

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
    await local.parent.create(recursive: true);
    await local.writeAsBytes(const []);
    onProgress?.call(0, 0);
    return 0;
  }

  @override
  Future<List<FileEntry>> stat(String dir, String glob) async {
    final inDir = files[dir] ?? const <FileEntry>[];
    final regex = _globToRegExp(glob);
    return inDir.where((f) => regex.hasMatch(f.name)).toList();
  }

  @override
  Future<String> logsTail(int lines) async => logTail;

  @override
  Future<ExecOutput> serviceControl(ServiceAction action) async {
    serviceActions.add(action);
    switch (action) {
      case ServiceAction.stop:
        final next = stateAfterStop;
        if (next != null) _state = next;
      case ServiceAction.start:
        final next = stateAfterStart;
        if (next != null) _state = next;
      case ServiceAction.status:
        break;
    }
    return const ExecOutput.empty();
  }

  @override
  Future<RunState> status() async {
    _statusCalls++;
    if (scriptedStates.isNotEmpty) return scriptedStates.removeAt(0);
    return _state;
  }

  @override
  Future<String?> activeSince() async => activeSinceValue;

  @override
  Future<List<String>> udpListening() async => udpLines;

  @override
  Future<void> fixPerms(String path) async {
    if (fixPermsThrows) {
      throw const OperationFailure('chown failed');
    }
  }

  /// Convenience for seeding a directory listing.
  void addFile(String dir, String name, {int size = 1024, int? modified}) {
    files
        .putIfAbsent(dir, () => [])
        .add(FileEntry(path: '$dir/$name', size: size, modified: modified));
  }

  static RegExp _globToRegExp(String glob) {
    final buffer = StringBuffer('^');
    for (final ch in glob.split('')) {
      buffer.write(switch (ch) {
        '*' => '.*',
        '?' => '.',
        _ => RegExp.escape(ch),
      });
    }
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }
}

/// Minimal throwable for fake failures, so tests don't need the real exception types.
class OperationFailure implements Exception {
  const OperationFailure(this.message);
  final String message;
  @override
  String toString() => 'OperationFailure: $message';
}
