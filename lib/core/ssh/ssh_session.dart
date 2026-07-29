import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/server_target.dart';

/// A live SSH connection.
///
/// Transport-level only: this knows nothing about systemd, Docker, or world files. It
/// exposes exec, SFTP and a shell channel, and records every command it runs.
///
/// One [SSHClient] multiplexes independent channels, so a long-running push, the stats
/// poller and an interactive terminal all share this single authenticated connection
/// concurrently rather than queueing behind each other or opening new TCP sessions.
class SshSession implements SshTransport {
  SshSession._(this._client, this.host, this.port, this.username);

  final SSHClient _client;

  @override
  final String host;

  final int port;
  final String username;

  /// The audit trail every command is recorded to.
  ///
  /// Assigned once, immediately after connecting and before the session is handed to
  /// discovery or wrapped in a target, so that **every** command from that point on is
  /// recorded — this is the single choke point all remote traffic passes through.
  SshCommandAuditSink? audit;

  bool _closed = false;

  /// Connects and authenticates with a password.
  static Future<SshSession> connectPassword({
    required String host,
    required int port,
    required String username,
    required String password,
    required HostKeyVerifier verifyHostKey,
  }) => _connect(
    host: host,
    port: port,
    username: username,
    verifyHostKey: verifyHostKey,
    configure: (socket, onVerify) => SSHClient(
      socket,
      username: username,
      onVerifyHostKey: onVerify,
      onPasswordRequest: () => password,
    ),
  );

  /// Connects and authenticates with an OpenSSH private key file.
  static Future<SshSession> connectKey({
    required String host,
    required int port,
    required String username,
    required File privateKeyFile,
    String? passphrase,
    required HostKeyVerifier verifyHostKey,
  }) async {
    if (!privateKeyFile.existsSync()) {
      throw AuthException('private key not found: ${privateKeyFile.path}');
    }

    final String pem;
    try {
      pem = await privateKeyFile.readAsString();
    } on IOException catch (e) {
      throw AuthException(
        'could not read private key ${privateKeyFile.path}',
        cause: e,
      );
    }

    if (passphrase == null && SSHKeyPair.isEncryptedPem(pem)) {
      throw AuthException(
        'private key ${privateKeyFile.path} is passphrase-protected',
      );
    }

    final List<SSHKeyPair> identities;
    try {
      identities = SSHKeyPair.fromPem(pem, passphrase);
    } on Object catch (e) {
      throw AuthException(
        'could not parse private key ${privateKeyFile.path}',
        cause: e,
      );
    }

    return _connect(
      host: host,
      port: port,
      username: username,
      verifyHostKey: verifyHostKey,
      configure: (socket, onVerify) => SSHClient(
        socket,
        username: username,
        onVerifyHostKey: onVerify,
        identities: identities,
      ),
    );
  }

  static Future<SshSession> _connect({
    required String host,
    required int port,
    required String username,
    required HostKeyVerifier verifyHostKey,
    required SSHClient Function(SSHSocket, SSHHostkeyVerifyHandler) configure,
  }) async {
    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(host, port);
    } on Object catch (e) {
      throw SshException(
        'could not connect to $host:$port',
        host: host,
        cause: e,
      );
    }

    // dartssh2 hands the fingerprint over as UTF-8 bytes of the `SHA256:<base64>` string
    // — the same text `ssh-keygen -lf` prints, so it can be shown to a user verbatim.
    Object? verifyFailure;
    FutureOr<bool> onVerify(String type, Uint8List fingerprintBytes) async {
      final fingerprint = utf8.decode(fingerprintBytes);
      try {
        return await verifyHostKey(
          host: host,
          port: port,
          type: type,
          fingerprint: fingerprint,
        );
      } on Object catch (e) {
        // Throwing out of this callback would surface as an opaque transport error, so
        // capture the real reason and reject; it is rethrown below.
        verifyFailure = e;
        return false;
      }
    }

    final client = configure(socket, onVerify);

    try {
      await client.authenticated;
    } on Object catch (e) {
      client.close();
      final captured = verifyFailure;
      if (captured != null) {
        throw captured is WkException
            ? captured
            : SshException(
                'host key verification failed',
                host: host,
                cause: captured,
              );
      }
      if (e is SSHAuthAbortError || e is SSHAuthFailError) {
        throw AuthException(
          'authentication rejected for $username@$host',
          cause: e,
        );
      }
      throw SshException(
        'could not establish an SSH session with $host:$port',
        host: host,
        cause: e,
      );
    }

    return SshSession._(client, host, port, username);
  }

  @override
  Future<ExecOutput> exec(String cmd) async {
    final started = DateTime.now();
    ExecOutput? result;
    Object? failure;

    try {
      result = await _execInner(cmd);
      return result;
    } on Object catch (e) {
      failure = e;
      rethrow;
    } finally {
      final elapsedMs = DateTime.now().difference(started).inMilliseconds;
      final sink = audit;
      if (sink != null) {
        // Audit must never be able to fail the command it is recording.
        unawaited(
          _record(sink, cmd, result, failure, elapsedMs).catchError((_) {}),
        );
      }
    }
  }

  Future<void> _record(
    SshCommandAuditSink audit,
    String cmd,
    ExecOutput? result,
    Object? failure,
    int elapsedMs,
  ) async {
    if (result != null) {
      await audit.recordCommand(
        command: cmd,
        exitCode: result.exitStatus,
        stdout: result.stdout,
        stderr: result.stderr,
        durationMs: elapsedMs,
      );
      return;
    }
    // A transport failure has no exit status — recording a fake 0 or 1 would be worse
    // than recording nothing, so the column stays null and the error is its own row.
    await audit.recordCommand(
      command: cmd,
      exitCode: null,
      stdout: '',
      stderr: '',
      durationMs: elapsedMs,
    );
    await audit.recordError(context: 'ssh_exec', message: '$failure');
  }

  Future<ExecOutput> _execInner(String cmd) async {
    if (_closed) throw const NotConnectedException('SSH session is closed');

    final SSHSession session;
    try {
      session = await _client.execute(cmd);
    } on Object catch (e) {
      throw SshException('could not run: $cmd', host: host, cause: e);
    }

    final stdoutBuf = BytesBuilder(copy: false);
    final stderrBuf = BytesBuilder(copy: false);

    // Drain both streams concurrently. Waiting on stdout first would deadlock on a
    // command that fills the stderr window before finishing — `find /home` printing
    // thousands of permission errors is exactly that shape.
    await Future.wait([
      session.stdout.forEach(stdoutBuf.add),
      session.stderr.forEach(stderrBuf.add),
    ]);
    await session.done;

    return ExecOutput(
      // Remote output is not guaranteed to be valid UTF-8 (log files pick up stray
      // bytes), and a decode failure must not take down a whole operation.
      stdout: utf8.decode(stdoutBuf.toBytes(), allowMalformed: true),
      stderr: utf8.decode(stderrBuf.toBytes(), allowMalformed: true),
      exitStatus: session.exitCode ?? 0,
    );
  }

  @override
  Future<int> pushFile(
    File local,
    String remote, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (_closed) throw const NotConnectedException('SSH session is closed');

    final total = local.lengthSync();
    final sftp = await _sftp();
    SftpFile? handle;
    try {
      handle = await sftp.open(
        remote,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );
      // Streamed, not read into memory first: a world is megabytes today and nothing
      // bounds that, and on a phone a large one would be a real memory event.
      await handle
          .write(
            local.openRead().cast<Uint8List>(),
            onProgress: onProgress == null
                ? null
                : (sent) => onProgress(sent, total),
          )
          .done;
      return total;
    } on Object catch (e) {
      throw SshException(
        'could not upload ${local.path} to $remote',
        host: host,
        cause: e,
      );
    } finally {
      await handle?.close();
      await sftp.close();
    }
  }

  @override
  Future<int> pullFile(
    String remote,
    File local, {
    void Function(int received, int? total)? onProgress,
  }) async {
    if (_closed) throw const NotConnectedException('SSH session is closed');

    final sftp = await _sftp();
    SftpFile? handle;
    IOSink? sink;
    try {
      handle = await sftp.open(remote);
      final total = (await handle.stat()).size;

      await local.parent.create(recursive: true);
      sink = local.openWrite();

      var received = 0;
      await for (final chunk in handle.read()) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      return received;
    } on Object catch (e) {
      throw SshException(
        'could not download $remote to ${local.path}',
        host: host,
        cause: e,
      );
    } finally {
      await sink?.close();
      await handle?.close();
      await sftp.close();
    }
  }

  Future<SftpClient> _sftp() async {
    try {
      return await _client.sftp();
    } on Object catch (e) {
      throw SshException(
        'could not start an SFTP session',
        host: host,
        cause: e,
      );
    }
  }

  /// Opens an interactive shell on its own channel, for the terminal.
  ///
  /// Concurrent with, and independent of, ordinary exec traffic on the same connection.
  Future<SSHSession> openShell({
    int columns = 80,
    int rows = 24,
    String terminalType = 'xterm-256color',
  }) async {
    if (_closed) throw const NotConnectedException('SSH session is closed');
    try {
      return await _client.shell(
        pty: SSHPtyConfig(type: terminalType, width: columns, height: rows),
      );
    } on Object catch (e) {
      throw SshException('could not open a shell', host: host, cause: e);
    }
  }

  /// Appends a public key to the remote `~/.ssh/authorized_keys`.
  ///
  /// Idempotent — safe to run again with the same key.
  Future<void> installPublicKey(String publicKeyLine) async {
    final line = publicKeyLine.trim();
    final quoted = "'${line.replaceAll("'", r"'\''")}'";
    final out = await exec(
      'mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && '
      'chmod 600 ~/.ssh/authorized_keys && '
      '(grep -qF $quoted ~/.ssh/authorized_keys || echo $quoted >> ~/.ssh/authorized_keys)',
    );
    if (!out.success) {
      throw SshException(
        'installing the public key failed: ${out.stderr.trim()}',
        host: host,
      );
    }
  }

  bool get isClosed => _closed;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _client.close();
    try {
      await _client.done;
    } on Object {
      // Already torn down, or the peer vanished — nothing useful to report on close.
    }
  }
}

/// Decides whether to accept a host key.
///
/// Returning `false` rejects the connection; throwing a [WkException] rejects it *and*
/// surfaces that specific reason to the user, which is what a changed fingerprint
/// warrants.
typedef HostKeyVerifier =
    FutureOr<bool> Function({
      required String host,
      required int port,
      required String type,
      required String fingerprint,
    });
