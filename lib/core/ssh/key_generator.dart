import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';

/// A freshly generated SSH key, in the two forms it is needed in.
class GeneratedKeyPair {
  const GeneratedKeyPair({
    required this.privateKeyPem,
    required this.publicKeyLine,
  });

  /// OpenSSH private key PEM — `-----BEGIN OPENSSH PRIVATE KEY-----`.
  ///
  /// Unencrypted. A passphrase on a key the app must use unattended would have to be
  /// stored beside it, which protects nothing and adds a second secret to look after.
  /// The file's permissions are the protection; see `SshKeyStore`.
  final String privateKeyPem;

  /// One `authorized_keys` line: `ssh-ed25519 AAAA… comment`.
  final String publicKeyLine;
}

/// Generates the key pair that replaces a password.
///
/// **Ed25519, not RSA.** Small, fast, no key-size decision to get wrong, and supported by
/// every OpenSSH since 6.5 (2014) — which is older than any host this app can talk to,
/// since `dartssh2` itself will not negotiate with anything older.
///
/// The private key never leaves the machine. Only [GeneratedKeyPair.publicKeyLine] is
/// sent, appended to the host's `~/.ssh/authorized_keys`, which is what makes this
/// strictly better than remembering a password: the secret is per-host, revocable from
/// the server side by deleting one line, and never travels.
Future<GeneratedKeyPair> generateEd25519KeyPair({
  required String comment,
}) async {
  final keyPair = await Ed25519().newKeyPair();

  // OpenSSH stores the 32-byte seed and the 32-byte public key concatenated, and that
  // 64-byte value is also what the signing implementation expects. `cryptography` hands
  // them over separately.
  final seed = await keyPair.extractPrivateKeyBytes();
  final publicKey = Uint8List.fromList(
    (await keyPair.extractPublicKey()).bytes,
  );
  final privateKey = Uint8List.fromList([...seed, ...publicKey]);

  final openssh = OpenSSHEd25519KeyPair(publicKey, privateKey, comment);

  return GeneratedKeyPair(
    privateKeyPem: openssh.toPem(),
    publicKeyLine: publicKeyLineFor(openssh, comment: comment),
  );
}

/// Formats a public key the way `authorized_keys` expects it.
///
/// Built from the key pair's own wire encoding rather than assembled by hand: the base64
/// body is `string "ssh-ed25519"` followed by `string <32 bytes>`, not the bare key, and
/// a hand-rolled version that gets that wrong produces a line sshd silently ignores —
/// the failure is a password prompt on the next connect and no error anywhere.
String publicKeyLineFor(
  OpenSSHEd25519KeyPair keyPair, {
  required String comment,
}) {
  final body = base64Encode(keyPair.toPublicKey().encode());
  final trimmed = comment.trim();
  return trimmed.isEmpty ? 'ssh-ed25519 $body' : 'ssh-ed25519 $body $trimmed';
}
