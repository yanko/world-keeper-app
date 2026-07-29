import 'dart:convert';
import 'dart:io';

/// Trust-on-first-use host key pinning.
///
/// The Rust app accepts **any** host key (`check_server_key` returns `Ok(true)`), which
/// makes the connection trivially interceptable. That was a defensible call for a tool
/// that only ever ran on a home LAN. It stops being defensible once the same app runs on
/// a phone that roams onto networks nobody controls — and there is a root shell and a set
/// of destructive file operations at the far end of this connection.
///
/// So: remember the key the first time, and refuse loudly if it ever changes.
///
/// ## Why a separate file rather than a field on the profile
///
/// `config.json` is shared byte-for-byte with the Rust app, and that compatibility is
/// asserted by a round-trip test against a real install. Adding a field would mean this
/// app rewrites a file the other app owns with keys it does not know. Host keys live in
/// their own file instead — which is also exactly how OpenSSH does it.
///
/// Fingerprints are the `SHA256:<base64>` form that `ssh-keygen -lf` prints, so a user
/// can verify one against their server by eye.
class HostKeyStore {
  HostKeyStore(this._file);

  final File _file;

  Map<String, _PinnedKey>? _cache;

  static String keyFor(String host, int port) => '$host:$port';

  Future<Map<String, _PinnedKey>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    if (!_file.existsSync()) return _cache = <String, _PinnedKey>{};

    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return _cache = <String, _PinnedKey>{};
      }
      return _cache = decoded.map(
        (k, v) => MapEntry(k, _PinnedKey.fromJson(v as Map<String, dynamic>)),
      );
    } on Object {
      // A corrupt known-hosts file must not brick the app. Treating it as empty
      // degrades to trust-on-first-use, which is the same posture as a fresh install —
      // and the user still gets prompted on the next connect.
      return _cache = <String, _PinnedKey>{};
    }
  }

  Future<void> _save(Map<String, _PinnedKey> keys) async {
    await _file.parent.create(recursive: true);
    final payload = keys.map((k, v) => MapEntry(k, v.toJson()));
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    await temp.rename(_file.path);
    _cache = keys;
  }

  /// The pinned fingerprint for a host, or `null` if it has never been seen.
  Future<String?> pinnedFingerprint(String host, int port) async {
    final keys = await _load();
    return keys[keyFor(host, port)]?.fingerprint;
  }

  Future<void> pin({
    required String host,
    required int port,
    required String type,
    required String fingerprint,
  }) async {
    final keys = Map<String, _PinnedKey>.from(await _load());
    keys[keyFor(host, port)] = _PinnedKey(
      type: type,
      fingerprint: fingerprint,
      pinnedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _save(keys);
  }

  /// Forgets a host, so the next connect re-pins. The deliberate escape hatch for a
  /// server that was legitimately rebuilt.
  Future<void> forget(String host, int port) async {
    final keys = Map<String, _PinnedKey>.from(await _load());
    keys.remove(keyFor(host, port));
    await _save(keys);
  }

  /// Compares a presented key against what is pinned.
  Future<HostKeyVerdict> verify({
    required String host,
    required int port,
    required String fingerprint,
  }) async {
    final known = await pinnedFingerprint(host, port);
    if (known == null) return HostKeyVerdict.unknown;
    return known == fingerprint
        ? HostKeyVerdict.match
        : HostKeyVerdict.mismatch;
  }
}

enum HostKeyVerdict {
  /// Never seen — trust on first use, after telling the user what is being trusted.
  unknown,

  /// Matches what was pinned.
  match,

  /// **Changed.** Either the server was rebuilt or the connection is being intercepted.
  /// Never resolve this automatically.
  mismatch,
}

class _PinnedKey {
  const _PinnedKey({
    required this.type,
    required this.fingerprint,
    required this.pinnedAt,
  });

  factory _PinnedKey.fromJson(Map<String, dynamic> json) => _PinnedKey(
    type: json['type'] as String? ?? '',
    fingerprint: json['fingerprint'] as String? ?? '',
    pinnedAt: json['pinnedAt'] as String? ?? '',
  );

  /// Key algorithm, e.g. `ssh-ed25519`.
  final String type;

  /// `SHA256:<base64>`, as `ssh-keygen -lf` prints it.
  final String fingerprint;

  final String pinnedAt;

  Map<String, dynamic> toJson() => {
    'type': type,
    'fingerprint': fingerprint,
    'pinnedAt': pinnedAt,
  };
}
