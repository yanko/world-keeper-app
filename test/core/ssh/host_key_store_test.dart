import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/ssh/host_key_store.dart';

void main() {
  late Directory tempDir;
  late File file;
  late HostKeyStore store;

  const fpA = 'SHA256:abc123def456ghi789jkl012mno345pqr678stu901v';
  const fpB = 'SHA256:zzz999yyy888xxx777www666vvv555uuu444ttt333s';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_hostkey_test');
    file = File('${tempDir.path}${Platform.pathSeparator}known_hosts.json');
    store = HostKeyStore(file);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('an unseen host is unknown — trust on first use', () async {
    expect(
      await store.verify(host: '10.0.0.68', port: 22, fingerprint: fpA),
      HostKeyVerdict.unknown,
    );
    expect(await store.pinnedFingerprint('10.0.0.68', 22), isNull);
  });

  test('a pinned host matching its key verifies', () async {
    await store.pin(
      host: '10.0.0.68',
      port: 22,
      type: 'ssh-ed25519',
      fingerprint: fpA,
    );
    expect(
      await store.verify(host: '10.0.0.68', port: 22, fingerprint: fpA),
      HostKeyVerdict.match,
    );
  });

  test('a changed key is a mismatch, never a silent re-pin', () async {
    // The whole point: either the server was rebuilt or the connection is being
    // intercepted, and only a human can tell which.
    await store.pin(
      host: '10.0.0.68',
      port: 22,
      type: 'ssh-ed25519',
      fingerprint: fpA,
    );
    expect(
      await store.verify(host: '10.0.0.68', port: 22, fingerprint: fpB),
      HostKeyVerdict.mismatch,
    );
    // And the stored value is untouched by a failed verification.
    expect(await store.pinnedFingerprint('10.0.0.68', 22), fpA);
  });

  test('pins are scoped by host AND port', () async {
    await store.pin(host: 'h', port: 22, type: 'ssh-ed25519', fingerprint: fpA);
    expect(
      await store.verify(host: 'h', port: 2222, fingerprint: fpA),
      HostKeyVerdict.unknown,
    );
  });

  test('survives a round trip through disk', () async {
    await store.pin(host: 'h', port: 22, type: 'ssh-ed25519', fingerprint: fpA);

    final reopened = HostKeyStore(file);
    expect(await reopened.pinnedFingerprint('h', 22), fpA);
  });

  test('forget allows a legitimately rebuilt server to re-pin', () async {
    await store.pin(host: 'h', port: 22, type: 'ssh-ed25519', fingerprint: fpA);
    await store.forget('h', 22);

    expect(
      await store.verify(host: 'h', port: 22, fingerprint: fpB),
      HostKeyVerdict.unknown,
    );
  });

  test('re-pinning replaces rather than duplicating', () async {
    await store.pin(host: 'h', port: 22, type: 'ssh-ed25519', fingerprint: fpA);
    await store.pin(host: 'h', port: 22, type: 'ssh-rsa', fingerprint: fpB);
    expect(await store.pinnedFingerprint('h', 22), fpB);
  });

  test(
    'a corrupt store degrades to first-use rather than bricking the app',
    () async {
      await file.writeAsString('{not json at all');
      final fresh = HostKeyStore(file);
      expect(
        await fresh.verify(host: 'h', port: 22, fingerprint: fpA),
        HostKeyVerdict.unknown,
      );
    },
  );

  test('creates its directory on first pin', () async {
    final nested = HostKeyStore(
      File(
        '${tempDir.path}${Platform.pathSeparator}sub'
        '${Platform.pathSeparator}known_hosts.json',
      ),
    );
    await nested.pin(host: 'h', port: 22, type: 't', fingerprint: fpA);
    expect(await nested.pinnedFingerprint('h', 22), fpA);
  });

  test('records the key type and pin time for display', () async {
    await store.pin(host: 'h', port: 22, type: 'ssh-ed25519', fingerprint: fpA);
    final raw = await file.readAsString();
    expect(raw, contains('ssh-ed25519'));
    expect(raw, contains('pinnedAt'));
    expect(raw, contains('h:22'));
  });
}
