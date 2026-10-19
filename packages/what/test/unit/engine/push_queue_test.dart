import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  test('Multiple origins queued during Phase 2 (covers _pushOriginTail!._nextPushOrigin = origin; line 36)', () {
    final ctrl1 = WhatController(0);
    final ctrl2 = WhatController(0);
    final ctrl3 = WhatController(0);

    final t1 = RawWhatTerminal<int>(ctrl1.what, onInvalidated: () {
      // Called during Phase 2.
      // queueOrigin called for ctrl2 (tail was null, becomes ctrl2)
      ctrl2.set(1);
      // queueOrigin called for ctrl3 (tail is ctrl2, so line 36 hits)
      ctrl3.set(1);
    });
    t1.activate();

    ctrl1.set(1);

    expect(ctrl2.what.peek, 1);
    expect(ctrl3.what.peek, 1);
  });
}
