import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/errors/exceptions.dart';

/// Where generated private keys live on this machine.
///
/// One key per profile, named `<profileId>_ed25519` — the same layout the Rust app uses,
/// so both can read the same directory. A key per profile rather than one shared key:
/// removing a server's access should be deleting one line on that server, not rotating a
/// credential that every other host also trusts.
class SshKeyStore {
  const SshKeyStore(this._paths);

  final AppPaths _paths;

  File keyFileFor(String profileId) =>
      File(p.join(_paths.keysDir.path, '${profileId}_ed25519'));

  bool hasKeyFor(String profileId) => keyFileFor(profileId).existsSync();

  /// Writes the private key, readable only by this user where the OS can express that.
  ///
  /// Returns the path, which is what goes into the profile's `keyPath`.
  Future<String> write(String profileId, String privateKeyPem) async {
    final file = keyFileFor(profileId);
    await file.parent.create(recursive: true);
    await file.writeAsString(privateKeyPem, flush: true);

    await _restrictPermissions(file);
    return file.path;
  }

  /// Deletes the key, if there is one. Safe to call when there is not.
  Future<void> delete(String profileId) async {
    final file = keyFileFor(profileId);
    if (file.existsSync()) await file.delete();
  }

  /// `chmod 600`, best effort.
  ///
  /// Dart cannot set file modes directly, so this shells out — on POSIX only, since
  /// Windows has no equivalent and its ACLs already restrict `%APPDATA%` to the user.
  ///
  /// Deliberately not fatal. The key is inside the app's own data directory either way,
  /// and failing the whole setup because a `chmod` did not run would trade a working
  /// key-auth flow for a slightly tighter mode bit. `dartssh2` reads the file itself, so
  /// unlike `ssh(1)` it does not refuse a world-readable key.
  static Future<void> _restrictPermissions(File file) async {
    if (Platform.isWindows) return;
    try {
      await Process.run('chmod', ['600', file.path]);
    } on Object {
      // Nothing to do about it, and nothing that depends on it.
    }
  }
}

/// Reads a stored key back, failing loudly when it is missing.
///
/// A profile set to key auth whose key file has been deleted is the one case worth its
/// own message: the connection error would otherwise be an authentication failure, which
/// sends you looking at the server.
Future<String> requireKeyFile(File file) async {
  if (!file.existsSync()) {
    throw AuthException(
      'the private key for this profile is missing: ${file.path}',
    );
  }
  return file.readAsString();
}
