import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/ssh/ssh_wire.dart';

void main() {
  group('SshWireWriter', () {
    test('writes uint32 big-endian', () {
      final w = SshWireWriter()..writeUint32(0x01020304);
      expect(w.toBytes(), [0x01, 0x02, 0x03, 0x04]);
    });

    test('writes uint32 boundary values', () {
      expect((SshWireWriter()..writeUint32(0)).toBytes(), [0, 0, 0, 0]);
      expect((SshWireWriter()..writeUint32(0xFFFFFFFF)).toBytes(), [
        0xFF,
        0xFF,
        0xFF,
        0xFF,
      ]);
    });

    test('rejects values outside uint32 range', () {
      expect(() => SshWireWriter().writeUint32(-1), throwsArgumentError);
      expect(
        () => SshWireWriter().writeUint32(0x1_0000_0000),
        throwsArgumentError,
      );
    });

    test('writes a length-prefixed string', () {
      final w = SshWireWriter()..writeStringUtf8('ssh-ed25519');
      // 11 bytes of payload, so a 4-byte length of 0x0000000B first.
      expect(w.toBytes().sublist(0, 4), [0, 0, 0, 11]);
      expect(utf8.decode(w.toBytes().sublist(4)), 'ssh-ed25519');
    });

    test('writes an empty string as a bare zero length', () {
      final w = SshWireWriter()..writeStringUtf8('');
      expect(w.toBytes(), [0, 0, 0, 0]);
    });

    test('length prefix counts UTF-8 bytes, not characters', () {
      // A key comment can contain anything the user typed.
      final w = SshWireWriter()..writeStringUtf8('wörld');
      expect(w.toBytes().sublist(0, 4), [0, 0, 0, 6]); // 5 chars, 6 bytes
    });

    test('tracks length as bytes are written', () {
      final w = SshWireWriter();
      expect(w.length, 0);
      w.writeUint32(1);
      expect(w.length, 4);
      w.writeStringUtf8('ab');
      expect(w.length, 10); // 4 + (4 + 2)
    });
  });

  group('SshWireReader', () {
    test('round-trips the shape of an openssh-key-v1 public key blob', () {
      // [string "ssh-ed25519"][string pub(32)] — the exact structure key generation
      // has to emit, so round-tripping it is the check that matters.
      final pub = Uint8List.fromList(List.generate(32, (i) => i));
      final bytes =
          (SshWireWriter()
                ..writeStringUtf8('ssh-ed25519')
                ..writeString(pub))
              .toBytes();

      final r = SshWireReader(bytes);
      expect(r.readStringUtf8(), 'ssh-ed25519');
      expect(r.readString(), pub);
      expect(r.isAtEnd, isTrue);
    });

    test('round-trips the private section framing', () {
      const check = 0xDEADBEEF;
      final pub = Uint8List.fromList(List.filled(32, 7));
      final priv = Uint8List.fromList(List.filled(64, 9));

      final bytes =
          (SshWireWriter()
                ..writeUint32(check)
                ..writeUint32(check)
                ..writeStringUtf8('ssh-ed25519')
                ..writeString(pub)
                ..writeString(priv)
                ..writeStringUtf8('world-keeper'))
              .toBytes();

      final r = SshWireReader(bytes);
      expect(r.readUint32(), check);
      expect(r.readUint32(), check);
      expect(r.readStringUtf8(), 'ssh-ed25519');
      expect(r.readString(), pub);
      expect(r.readString(), priv);
      expect(r.readStringUtf8(), 'world-keeper');
      expect(r.isAtEnd, isTrue);
    });

    test('reads bytes and tracks offset', () {
      final r = SshWireReader(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(r.readByte(), 1);
      expect(r.offset, 1);
      expect(r.readRawBytes(2), [2, 3]);
      expect(r.remaining, 2);
    });

    test('throws a descriptive FormatException on truncated data', () {
      // Length prefix claims 8 bytes but only 2 follow — the failure mode of a
      // corrupted or half-written key file.
      final r = SshWireReader(Uint8List.fromList([0, 0, 0, 8, 1, 2]));
      expect(
        r.readString,
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('truncated'), contains('8')),
          ),
        ),
      );
    });

    test('throws rather than reading past the end', () {
      final r = SshWireReader(Uint8List.fromList([1, 2]));
      expect(r.readUint32, throwsFormatException);
    });
  });
}
