import 'dart:convert';
import 'dart:typed_data';

/// Readers and writers for the SSH wire encoding from RFC 4251 §5.
///
/// Two types matter here:
///
/// * `uint32` — 4 bytes, big-endian (network byte order).
/// * `string` — a `uint32` byte count followed by that many raw bytes. Despite the name
///   it is a byte string, not text; public key blobs and MPINTs use the same framing.
///
/// This exists for SSH **key generation**. No Dart package writes the OpenSSH private
/// key format (`openssh-key-v1`), and that format is built almost entirely out of these
/// two primitives, so they are separated out here — small, total, and exhaustively
/// testable on their own, which is what keeps a subtly malformed key from becoming an
/// authentication failure discovered days later.
class SshWireWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  int get length => _out.length;

  void writeByte(int value) => _out.addByte(value & 0xFF);

  void writeRawBytes(List<int> bytes) => _out.add(bytes);

  /// Big-endian 32-bit unsigned integer.
  void writeUint32(int value) {
    if (value < 0 || value > 0xFFFFFFFF) {
      throw ArgumentError.value(value, 'value', 'does not fit in a uint32');
    }
    _out.add([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  /// Length-prefixed byte string.
  void writeString(List<int> bytes) {
    writeUint32(bytes.length);
    _out.add(bytes);
  }

  /// Length-prefixed UTF-8 string. Used for algorithm names and key comments.
  void writeStringUtf8(String value) => writeString(utf8.encode(value));

  Uint8List toBytes() => _out.toBytes();
}

/// The inverse of [SshWireWriter] — used to verify generated keys by parsing them back.
class SshWireReader {
  SshWireReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  int get offset => _offset;

  int get remaining => _bytes.length - _offset;

  bool get isAtEnd => remaining <= 0;

  int readByte() {
    _require(1);
    return _bytes[_offset++];
  }

  Uint8List readRawBytes(int count) {
    _require(count);
    final out = Uint8List.sublistView(_bytes, _offset, _offset + count);
    _offset += count;
    return out;
  }

  int readUint32() {
    _require(4);
    final value =
        (_bytes[_offset] << 24) |
        (_bytes[_offset + 1] << 16) |
        (_bytes[_offset + 2] << 8) |
        _bytes[_offset + 3];
    _offset += 4;
    return value;
  }

  Uint8List readString() => readRawBytes(readUint32());

  String readStringUtf8() => utf8.decode(readString());

  void _require(int count) {
    if (remaining < count) {
      throw FormatException(
        'truncated SSH wire data: wanted $count byte(s) at offset $_offset, '
        'only $remaining remain',
      );
    }
  }
}
