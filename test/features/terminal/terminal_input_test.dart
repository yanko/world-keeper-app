import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/l10n/l10n.dart';
import 'package:xterm/xterm.dart';

/// Regression tests for typing into the terminal.
///
/// Phase 6 shipped a terminal where **Enter worked but letters did nothing on desktop**,
/// while the same build was fine on Android. Two separate problems, found in that order:
///
/// 1. A `focusNode` focused before `TerminalView` mounted. xterm opens its text-input
///    connection from a focus-change *listener*, and `CustomTextEdit.initState` only
///    subscribes — it never opens the connection for a node that is already focused.
/// 2. The real desktop cause: xterm 4.0.0 attaches with the pre-multi-view
///    `TextInput.attach` API, which Flutter 3.44 rejects on Windows with
///    `PlatformException(Bad Arguments, Could not set client, view ID is null.)`. The
///    connection can never open there at all, whatever the focus does. The fix is
///    `hardwareKeyboardOnly: true` on desktop, which reads `KeyEvent.character` instead.
///
/// Both routes are covered here, because the app uses a different one per platform and a
/// test of only one would have missed this exactly as the original tests did.
void main() {
  late Terminal terminal;
  late List<String> output;

  setUp(() {
    terminal = Terminal();
    output = [];
    terminal.onOutput = output.add;
  });

  /// Mirrors the app's own configuration.
  Future<void> pumpTerminal(
    WidgetTester tester, {
    FocusNode? focusNode,
    bool hardwareKeyboardOnly = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        theme: WkTheme.dark(),
        home: Scaffold(
          body: TerminalView(
            terminal,
            autofocus: true,
            focusNode: focusNode,
            hardwareKeyboardOnly: hardwareKeyboardOnly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('desktop route — hardware key events', () {
    testWidgets('typed characters reach the terminal', (tester) async {
      // THE desktop regression. `CustomKeyboardListener` reads `KeyEvent.character`, so
      // no platform text-input connection is involved and the failing attach is bypassed.
      await pumpTerminal(tester, hardwareKeyboardOnly: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();

      expect(output.join(), 'ls');
    });

    testWidgets('opens no text-input connection at all', (tester) async {
      // The whole point on desktop: xterm 4.0.0's attach fails there, so the connection
      // must not be attempted.
      await pumpTerminal(tester, hardwareKeyboardOnly: true);
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    testWidgets('Enter still works', (tester) async {
      await pumpTerminal(tester, hardwareKeyboardOnly: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(output.join(), contains('\r'));
    });

    testWidgets('Ctrl+C is encoded as an interrupt, not a letter', (
      tester,
    ) async {
      await pumpTerminal(tester, hardwareKeyboardOnly: true);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(output.join(), contains('\x03'));
      expect(output.join(), isNot(contains('c')));
    });

    testWidgets('arrow keys emit escape sequences', (tester) async {
      await pumpTerminal(tester, hardwareKeyboardOnly: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(output.join(), contains('\x1b'));
    });
  });

  group('mobile route — platform text input', () {
    testWidgets('a text-input connection is opened', (tester) async {
      // The connection is the thing that was missing. If nothing registers as a text
      // input client, characters have no route into the terminal at all.
      await pumpTerminal(tester);
      expect(
        tester.testTextInput.hasAnyClients,
        isTrue,
        reason: 'the terminal must be attached to platform text input',
      );
    });

    testWidgets('typed characters reach the terminal', (tester) async {
      await pumpTerminal(tester);

      tester.testTextInput.enterText('ls');
      await tester.pump();

      expect(
        output.join(),
        contains('ls'),
        reason: 'THE regression — letters must be sent to the shell',
      );
    });

    testWidgets('characters continue to work after several inputs', (
      tester,
    ) async {
      await pumpTerminal(tester);

      tester.testTextInput.enterText('a');
      await tester.pump();
      tester.testTextInput.enterText('ab');
      await tester.pump();

      expect(output.join(), contains('a'));
      expect(output.join(), contains('b'));
    });

    testWidgets('Enter still works — it takes the other route', (tester) async {
      // Enter goes through the Focus widget's key handling, not the text connection.
      // Both paths have to work; only one of them was broken.
      await pumpTerminal(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(output.join(), contains('\r'));
    });

    testWidgets('both routes work in the same session', (tester) async {
      await pumpTerminal(tester);

      tester.testTextInput.enterText('id');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      final sent = output.join();
      expect(sent, contains('id'));
      expect(sent, contains('\r'));
    });
  });

  group('the shape of the original bug', () {
    testWidgets('a focus node already focused before mount breaks text input', (
      tester,
    ) async {
      // Pinned deliberately. This documents *why* the app must not supply a
      // pre-focused node: if a future change reintroduces one and this stops failing,
      // the upstream behaviour has changed and the workaround can be revisited.
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      // Focus before the view exists — exactly what the buggy `_start()` did.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          home: Scaffold(
            body: Focus(focusNode: focusNode, child: const SizedBox.expand()),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      await pumpTerminal(tester, focusNode: focusNode);

      tester.testTextInput.enterText('ls');
      await tester.pump();

      expect(
        output.join(),
        isNot(contains('ls')),
        reason:
            'if this now passes text through, xterm has changed and the app can '
            'go back to supplying its own focus node',
      );
    });
  });
}
