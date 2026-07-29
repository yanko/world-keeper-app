import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/ssh/key_generator.dart';
import 'package:world_keeper/core/ssh/ssh_key_store.dart';

/// Key generation is the one thing here that cannot be checked by looking at it.
///
/// A key pair that is subtly malformed still writes a file, still uploads a line, and
/// still leaves the profile switched to key auth — and fails on the *next* connect, by
/// which point the password may be the thing you no longer have. So the tests round-trip
/// through the same parser the connection uses, and verify a real signature.
void main() {
  test('the private key parses with the parser the connection uses', () async {
    // `SshSession.connectWithKey` calls `SSHKeyPair.fromPem`. If that cannot read what we
    // wrote, every future connect fails with "could not parse private key" and the
    // password path has already been given up.
    final generated = await generateEd25519KeyPair(comment: 'world-keeper');

    final identities = SSHKeyPair.fromPem(generated.privateKeyPem);

    expect(identities, hasLength(1));
    expect(identities.single.type, 'ssh-ed25519');
  });

  test(
    'it is an OpenSSH key, not some other PEM that happens to parse',
    () async {
      final generated = await generateEd25519KeyPair(comment: 'world-keeper');

      expect(
        generated.privateKeyPem,
        startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'),
      );
      expect(
        generated.privateKeyPem.trimRight(),
        endsWith('-----END OPENSSH PRIVATE KEY-----'),
      );
    },
  );

  test('it is unencrypted, because nothing could supply a passphrase', () async {
    // The app connects unattended. A passphrase would have to be stored beside the key,
    // which protects nothing — and `SshSession` refuses an encrypted key outright.
    final generated = await generateEd25519KeyPair(comment: 'world-keeper');

    expect(SSHKeyPair.isEncryptedPem(generated.privateKeyPem), isFalse);
  });

  test('the private key signs, and its public half verifies the signature', () async {
    // The real contract. Everything above checks the file is well-formed; this checks the
    // two halves are actually a pair, which is what the server tests on first connect.
    //
    // Verified with `cryptography` rather than with dartssh2, deliberately: dartssh2 both
    // generated and signed here, so asking it to check its own work would pass even if
    // its notion of an Ed25519 key disagreed with everyone else's. An independent library
    // agreeing is the assertion worth making.
    final generated = await generateEd25519KeyPair(comment: 'world-keeper');
    final identity = SSHKeyPair.fromPem(generated.privateKeyPem).single;

    final message = Uint8List.fromList(utf8.encode('the quick brown fox'));
    final signature = identity.sign(message);

    // Both blobs are `string <type> || string <payload>`, and the type is 11 bytes.
    const payloadOffset = 4 + 11 + 4;
    final publicKeyBytes = identity.toPublicKey().encode().sublist(
      payloadOffset,
    );
    final signatureBytes = signature.encode().sublist(payloadOffset);

    expect(publicKeyBytes, hasLength(32));
    expect(signatureBytes, hasLength(64));

    final verified = await Ed25519().verify(
      message,
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      ),
    );

    expect(verified, isTrue);
  });

  group('the authorized_keys line', () {
    test('is the three-field form sshd expects', () async {
      final generated = await generateEd25519KeyPair(comment: 'world-keeper');
      final fields = generated.publicKeyLine.split(' ');

      expect(fields, hasLength(3));
      expect(fields[0], 'ssh-ed25519');
      expect(fields[2], 'world-keeper');
    });

    test('carries the wire encoding, not the bare key', () async {
      // The base64 body is `string "ssh-ed25519"` then `string <32 bytes>`. A hand-rolled
      // version that emits only the 32 bytes produces a line sshd silently ignores — no
      // error anywhere, just a password prompt on the next connect.
      final generated = await generateEd25519KeyPair(comment: 'wk');
      final body = base64Decode(generated.publicKeyLine.split(' ')[1]);

      expect(body, hasLength(51)); // 4 + 11 + 4 + 32
      expect(utf8.decode(body.sublist(4, 15)), 'ssh-ed25519');
    });

    test('matches the public half of the private key', () async {
      final generated = await generateEd25519KeyPair(comment: 'wk');
      final identity = SSHKeyPair.fromPem(generated.privateKeyPem).single;

      expect(
        generated.publicKeyLine.split(' ')[1],
        base64Encode(identity.toPublicKey().encode()),
      );
    });

    test(
      'an empty comment yields two fields rather than a trailing space',
      () async {
        final generated = await generateEd25519KeyPair(comment: '   ');
        expect(generated.publicKeyLine.split(' '), hasLength(2));
      },
    );
  });

  test('every generated key is different', () async {
    final a = await generateEd25519KeyPair(comment: 'wk');
    final b = await generateEd25519KeyPair(comment: 'wk');

    expect(a.privateKeyPem, isNot(b.privateKeyPem));
    expect(a.publicKeyLine, isNot(b.publicKeyLine));
  });

  group('SshKeyStore', () {
    late Directory tempDir;
    late SshKeyStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wk_keys_test');
      store = SshKeyStore(AppPaths.forTesting(tempDir));
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('names the file the way the Rust app does', () {
      expect(store.keyFileFor('abc-123').path, endsWith('abc-123_ed25519'));
    });

    test('writes a key that reads back byte-identical', () async {
      final generated = await generateEd25519KeyPair(comment: 'wk');
      final path = await store.write('p1', generated.privateKeyPem);

      expect(File(path).readAsStringSync(), generated.privateKeyPem);
      expect(store.hasKeyFor('p1'), isTrue);
    });

    test('creates the keys directory if it is not there yet', () async {
      // First run on a fresh install: nothing has created `keys/` yet.
      expect(store.keyFileFor('p1').parent.existsSync(), isFalse);

      await store.write('p1', 'pem');
      expect(store.keyFileFor('p1').parent.existsSync(), isTrue);
    });

    test('keys are per profile, so removing one leaves the others', () async {
      await store.write('p1', 'one');
      await store.write('p2', 'two');

      await store.delete('p1');

      expect(store.hasKeyFor('p1'), isFalse);
      expect(store.hasKeyFor('p2'), isTrue);
    });

    test('deleting a key that was never written is not an error', () async {
      await expectLater(store.delete('never'), completes);
    });

    test(
      'a missing key names the file rather than failing as bad auth',
      () async {
        // Otherwise the failure surfaces as an authentication error, which sends you to
        // look at the server for a problem that is entirely on this machine.
        await expectLater(
          requireKeyFile(store.keyFileFor('gone')),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('gone_ed25519'),
            ),
          ),
        );
      },
    );
  });
}
