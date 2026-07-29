import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one permission this app cannot work without.
///
/// Flutter's generated scaffold puts `INTERNET` in `src/debug` and `src/profile` only, for
/// hot reload. A debug build therefore connects fine and a **release** build cannot open a
/// socket at all — it fails at `connect()` with `EPERM`, surfacing as
/// `SocketException: Operation not permitted, errno = 1`, which reads like a firewall or a
/// routing problem rather than a missing manifest entry.
///
/// No widget test can catch that: tests run on the host, release builds are never
/// exercised, and the debug manifest papers over it during every kind of development. So
/// it is asserted against the file.
void main() {
  final main = File('android/app/src/main/AndroidManifest.xml');

  test('the release manifest declares INTERNET', () {
    expect(
      main.existsSync(),
      isTrue,
      reason: 'run from the flutter/ directory',
    );
    expect(
      main.readAsStringSync(),
      contains('android.permission.INTERNET'),
      reason:
          'without this, release APKs fail every connection with errno 1 while debug '
          'builds work — see the comment in the manifest',
    );
  });

  test('the launcher name is the product name, not the package name', () {
    expect(main.readAsStringSync(), contains('android:label="World Keeper"'));
  });

  test('no permission is requested beyond the network', () {
    // An SSH client that also asks for storage or location is an SSH client people are
    // right to distrust. `file_picker` goes through the storage access framework, which
    // needs no permission at all.
    final declared = RegExp(
      r'android:name="android\.permission\.(\w+)"',
    ).allMatches(main.readAsStringSync()).map((m) => m.group(1)).toList();
    expect(declared, ['INTERNET']);
  });
}
