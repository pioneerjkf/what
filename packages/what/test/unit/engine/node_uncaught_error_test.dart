import 'dart:async';
import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  test('Node _handleUncaughtError covers downstream and empty terminals (lines 140-157, 191-208)', () {
    final comp = What.managed<int>(
        create: (via) => 42,
        dispose: (value) {
          throw Exception('Dispose Error');
        });

    Object? zoneError;
    runZonedGuarded(() {
      final t1 = RawWhatTerminal<int>(comp, onInvalidated: () {});
      t1.activate();
      expect(comp.peek, 42); // pull to create the resource

      // Deactivate will trigger dispose, which throws.
      // Since t1 is deactivated, comp has no terminals, so it falls back to Zone handler.
      t1.deactivate();
    }, (e, s) {
      zoneError = e;
    });

    expect(zoneError, isA<Exception>().having((e) => e.toString(), 'message', contains('Dispose Error')));
  });

  test('Node _handleUncaughtError dispatches to downstream terminals (lines 198-203)', () {
    final ctrl = WhatController(true);
    final comp = managed<int>(
        guard: (via) => via(ctrl.what).guarded(),
        create: (WhatVia via) => 1,
        dispose: (value) {
          throw Exception('Downstream Dispose Error');
        });

    Object? terminalError;
    final t1 = RawWhatTerminal<int>(comp, onInvalidated: () {}, onUncaughtError: (e, s) {});
    final t2 = RawWhatTerminal<int>(comp, onInvalidated: () {}, onUncaughtError: (e, s) {
      terminalError = e;
    });

    t1.activate();
    t2.activate();
    expect(comp.peek, 1); // pull to create the resource

    // ctrl.set(false) triggers update. guard becomes false.
    // _disposeCurrent is called. dispose throws 'Downstream Dispose Error'.
    // _handleUncaughtError is called. terminals are still active.
    ctrl.set(false);
    expect(comp.peekState.isEmpty, true); // state should transition to empty due to guard

    expect(
        terminalError, isA<Exception>().having((e) => e.toString(), 'message', contains('Downstream Dispose Error')));
  });
}
