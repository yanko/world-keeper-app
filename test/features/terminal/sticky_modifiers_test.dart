import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/features/terminal/data/terminal_session.dart';
import 'package:xterm/xterm.dart';

/// Records what it was asked to encode, so the modifier plumbing can be checked without
/// a shell, a socket or a rendered widget.
class _RecordingHandler extends TerminalInputHandler {
  final events = <TerminalKeyboardEvent>[];

  @override
  String? call(TerminalKeyboardEvent event) {
    events.add(event);
    return null;
  }
}

void main() {
  late _RecordingHandler inner;
  late StickyModifiers keyboard;
  late Terminal terminal;

  setUp(() {
    inner = _RecordingHandler();
    keyboard = StickyModifiers(inner);
    // A real Terminal supplies the `state` an event carries — cheaper and more faithful
    // than stubbing an interface with a dozen getters.
    terminal = Terminal();
  });

  TerminalKeyboardEvent press(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) => TerminalKeyboardEvent(
    key: key,
    ctrl: ctrl,
    alt: alt,
    shift: shift,
    state: terminal,
    altBuffer: false,
    platform: TerminalTargetPlatform.linux,
  );

  group('sticky modifiers', () {
    test('start disarmed and pass keys through untouched', () {
      expect(keyboard.anyArmed, isFalse);

      keyboard.call(press(TerminalKey.keyC));

      expect(inner.events.single.ctrl, isFalse);
      expect(inner.events.single.alt, isFalse);
    });

    test('an armed Ctrl is injected into the next key', () {
      // The whole reason the bar exists: a phone keyboard has no Ctrl, so `Ctrl` then
      // `c` has to produce what a physical Ctrl+C would.
      keyboard.toggleCtrl();
      expect(keyboard.ctrl, isTrue);

      keyboard.call(press(TerminalKey.keyC));

      expect(inner.events.single.ctrl, isTrue);
      expect(inner.events.single.key, TerminalKey.keyC);
    });

    test('applies to exactly one keypress, then clears', () {
      // Latching would make the *next* ordinary letter behave surprisingly — type `ls`
      // after a forgotten Ctrl and you have sent Ctrl+L.
      keyboard.toggleCtrl();
      keyboard.call(press(TerminalKey.keyC));
      keyboard.consume();

      keyboard.call(press(TerminalKey.keyL));

      expect(inner.events[0].ctrl, isTrue);
      expect(inner.events[1].ctrl, isFalse, reason: 'must not stay latched');
      expect(keyboard.anyArmed, isFalse);
    });

    test('tapping twice disarms', () {
      keyboard.toggleCtrl();
      keyboard.toggleCtrl();
      expect(keyboard.ctrl, isFalse);
    });

    test('modifiers combine', () {
      keyboard
        ..toggleCtrl()
        ..toggleAlt()
        ..toggleShift();

      keyboard.call(press(TerminalKey.keyX));

      final event = inner.events.single;
      expect(event.ctrl, isTrue);
      expect(event.alt, isTrue);
      expect(event.shift, isTrue);
    });

    test('composes with a real hardware modifier rather than replacing it', () {
      // A desktop user with a physical Ctrl must be unaffected by this wrapper.
      keyboard.toggleAlt();
      keyboard.call(press(TerminalKey.keyC, ctrl: true));

      final event = inner.events.single;
      expect(event.ctrl, isTrue, reason: 'the hardware modifier survives');
      expect(event.alt, isTrue, reason: 'the armed one is added');
    });

    test('a hardware key alone is untouched when nothing is armed', () {
      keyboard.call(press(TerminalKey.keyC, ctrl: true));
      expect(inner.events.single.ctrl, isTrue);
      expect(inner.events.single.alt, isFalse);
    });

    test('notifies listeners so the bar can show armed state', () {
      // An invisible mode is a trap; the UI has to be able to render it.
      var notifications = 0;
      keyboard.addListener(() => notifications++);

      keyboard.toggleCtrl();
      expect(notifications, 1);

      keyboard.consume();
      expect(notifications, 2);
    });

    test('consume is a no-op when nothing is armed', () {
      var notifications = 0;
      keyboard.addListener(() => notifications++);

      keyboard.consume();

      expect(notifications, 0, reason: 'no spurious rebuilds');
    });
  });
}
