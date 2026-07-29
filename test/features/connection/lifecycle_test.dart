import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/features/connection/data/connection_controller.dart';

/// When the app comes back, is the connection still real?
///
/// Android freezes a backgrounded process and the OS tears down its sockets without
/// telling anything in the app. On return the state still says "Connected", the chip is
/// still teal, and the next command fails with a transport error that reads like the
/// server's fault. That is the platform working as designed — the fixable part is the app
/// claiming a connection it no longer has.
///
/// `AppLifecycleListener` cannot be driven without a widget tree, so the decision lives in
/// a pure function and this is where it is pinned.
void main() {
  group('a check is worth a round trip only on a real resume', () {
    test('returning from paused', () {
      // The Android case: the process was frozen, so the socket is very likely gone.
      expect(
        shouldVerifyConnection(
          AppLifecycleState.paused,
          AppLifecycleState.resumed,
        ),
        isTrue,
      );
    });

    test('returning from detached', () {
      expect(
        shouldVerifyConnection(
          AppLifecycleState.detached,
          AppLifecycleState.resumed,
        ),
        isTrue,
      );
    });

    test('merely regaining focus does not', () {
      // `inactive` is every notification shade pull and every desktop alt-tab. Running a
      // command over SSH each time somebody clicks back into the window is noise, and the
      // process was never stopped, so the socket cannot have died from it.
      expect(
        shouldVerifyConnection(
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ),
        isFalse,
      );
    });

    test('being hidden and shown again does not', () {
      expect(
        shouldVerifyConnection(
          AppLifecycleState.hidden,
          AppLifecycleState.resumed,
        ),
        isFalse,
      );
    });

    test('going *into* the background does not', () {
      // Nothing to check while suspended, and the process is about to stop running.
      expect(
        shouldVerifyConnection(
          AppLifecycleState.resumed,
          AppLifecycleState.paused,
        ),
        isFalse,
      );
    });

    test('the very first state change does not', () {
      // Launch reports a transition from nothing. There is no connection yet either.
      expect(shouldVerifyConnection(null, AppLifecycleState.resumed), isFalse);
    });
  });
}
