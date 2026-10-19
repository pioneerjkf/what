import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('PushScope Coverage', () {
    test('Phase 2 Terminal Flush Error (line 100)', () {
      final ctrl = WhatController(0);

      Object? caughtError;
      final t1 = RawWhatTerminal<int>(
        ctrl.what,
        onInvalidated: () {
          throw StateError('Invalidate Error');
        },
        onUncaughtError: (e, s) {
          caughtError = e;
        },
      );

      t1.activate();
      ctrl.set(1);

      expect(caughtError, isA<StateError>().having((e) => e.message, 'message', 'Invalidate Error'));
    });

    test('Multiple terminals queue flush tail coverage (line 61)', () {
      final ctrl = WhatController(0);
      final t1 = RawWhatTerminal<int>(ctrl.what, onInvalidated: () {});
      final t2 = RawWhatTerminal<int>(ctrl.what, onInvalidated: () {});

      t1.activate();
      t2.activate();

      ctrl.set(1);

      expect(ctrl.what.peek, 1);
    });

    test('Multiple terminals push origin tail coverage (line 36)', () {
      final ctrl = WhatController(0);
      final ctrl1 = WhatController(0);
      final ctrl2 = WhatController(0);

      final t = RawWhatTerminal<int>(ctrl.what, onInvalidated: () {
        print('onInvalidated called!');
        print('Setting ctrl1...');
        ctrl1.set(1);
        print('Setting ctrl2...');
        ctrl2.set(1);
        print('Done setting inside onInvalidated.');
      });
      t.activate();

      print('Triggering drain...');
      ctrl.set(1);
      print('Done triggering drain.');

      expect(ctrl1.what.peek, 1);
      expect(ctrl2.what.peek, 1);
    });
  });
}
