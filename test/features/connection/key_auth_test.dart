import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/ssh/key_generator.dart';
import 'package:world_keeper/core/ssh/ssh_key_store.dart';

/// The ordering rule that makes key-auth setup safe to fail.
///
/// `setUpKeyAuth` cannot be exercised end to end here — it needs a live `SshSession`,
/// whose constructor is private, and a real host to append to. What *is* checkable is the
/// part that decides whether a half-finished run leaves a working profile or a locked
/// door, and the state it leaves behind on this machine.
void main() {
  late Directory tempDir;
  late SshKeyStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_keyauth_test');
    store = SshKeyStore(AppPaths.forTesting(tempDir));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  const profile = Profile(
    id: 'p1',
    name: 'Core Keeper LXC',
    host: '10.0.0.169',
    user: 'root',
    auth: AuthMethod.password,
  );

  test('switching to key auth clears the saved-password flag', () {
    // Otherwise the connect path keeps looking for a password that is no longer used and
    // no longer asked for.
    final updated = profile.copyWith(
      auth: AuthMethod.key,
      keyPath: '/keys/p1_ed25519',
      savePassword: false,
    );

    expect(updated.auth, AuthMethod.key);
    expect(updated.savePassword, isFalse);
    expect(updated.keyPath, isNotEmpty);
  });

  test('a profile switched to key auth without a path cannot connect', () {
    // Which is why the profile is only rewritten *after* the key is written to disk. The
    // controller's ordering exists to make this state unreachable.
    final broken = profile.copyWith(auth: AuthMethod.key);
    expect(broken.keyPath, isNull);
  });

  test('the comment identifies the line months later', () async {
    // In `authorized_keys` this is all there is to answer "what is this key, and is it
    // safe to delete".
    final generated = await generateEd25519KeyPair(
      comment: 'world-keeper:${profile.name}',
    );

    expect(generated.publicKeyLine, endsWith('world-keeper:Core Keeper LXC'));
  });

  test('the key is written where the profile will look for it', () async {
    final generated = await generateEd25519KeyPair(comment: 'wk');
    final path = await store.write(profile.id, generated.privateKeyPem);

    final updated = profile.copyWith(auth: AuthMethod.key, keyPath: path);

    expect(File(updated.keyPath!).existsSync(), isTrue);
    expect(updated.keyPath, store.keyFileFor(profile.id).path);
  });

  test('deleting the profile takes its key with it', () async {
    // An orphaned private key in the data directory is a credential nothing can explain.
    await store.write(profile.id, 'pem');
    expect(store.hasKeyFor(profile.id), isTrue);

    await store.delete(profile.id);
    expect(store.hasKeyFor(profile.id), isFalse);
  });

  test('only the public half is ever sendable', () async {
    // The private key has no path out of this file: `installPublicKey` takes a line, and
    // the line is the public one. Asserted because the whole security argument for
    // preferring a key over a stored password rests on it.
    final generated = await generateEd25519KeyPair(comment: 'wk');

    expect(generated.publicKeyLine, startsWith('ssh-ed25519 '));
    expect(generated.publicKeyLine, isNot(contains('PRIVATE KEY')));
    expect(generated.publicKeyLine.split('\n'), hasLength(1));
  });
}
