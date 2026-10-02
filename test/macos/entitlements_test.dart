import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against the App Sandbox coming back on macOS.
///
/// Flutter's macOS template turns the sandbox on and grants no outbound network, so a
/// release build cannot open the SSH connection that is the whole app — the same trap as
/// the Android `INTERNET` permission, and just as invisible to every test that runs on the
/// host. Adding `network.client` alone would not be enough either: a sandboxed app has its
/// `~/Library/Application Support` redirected into its container, so it would stop sharing
/// `config.json` and the audit database with the Tauri build, which is the reason
/// `AppPaths` exists.
///
/// The app is distributed directly, not through the Mac App Store, so nothing requires the
/// sandbox. It is asserted against the files because nothing else can catch it.
void main() {
  for (final name in ['Release', 'DebugProfile']) {
    test('$name.entitlements does not enable the App Sandbox', () {
      final file = File('macos/Runner/$name.entitlements');
      expect(file.existsSync(), isTrue, reason: 'run from the project root');
      expect(
        file.readAsStringSync(),
        isNot(contains('com.apple.security.app-sandbox')),
        reason:
            'a sandboxed build cannot connect out and does not share config.json with '
            'the Tauri app — see the comment at the top of this test',
      );
    });
  }
}
