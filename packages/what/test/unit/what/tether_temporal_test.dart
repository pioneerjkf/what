// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Tether Throttle, Debounce & Scope Effect Extensions Suite', () {
    test('1. ThrottleEffect.unary throttles mutations within scope lifecycle', () async {
      final clicks = WhatController(0);
      int runs = 0;

      final effect = ThrottleEffect.unary(
        clicks.what,
        const Duration(milliseconds: 50),
        () => runs++,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      clicks.data = 1;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      clicks.data = 2;
      clicks.data = 3;
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 2);

      terminal.deactivate();
    });

    test('2. DebounceEffect.unary debounces mutations within scope lifecycle', () async {
      final text = WhatController('');
      final observed = <String>[];

      final effect = DebounceEffect.unary(
        text.what,
        const Duration(milliseconds: 50),
        () => observed.add(text.data),
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      text.data = 'a';
      await Future<void>.delayed(const Duration(milliseconds: 20));
      text.data = 'ab';
      await Future<void>.delayed(const Duration(milliseconds: 20));
      text.data = 'abc';

      expect(observed, []);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(observed, ['abc']);

      terminal.deactivate();
    });

    test('3. Multi-target DebounceEffect([min, max])', () async {
      final min = WhatController(10);
      final max = WhatController(100);
      int runs = 0;

      final effect = DebounceEffect(
        [min.what, max.what],
        const Duration(milliseconds: 50),
        () => runs++,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      min.data = 15;
      max.data = 95;
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 1);

      terminal.deactivate();
    });

    test('4. Effect.unary(take: n) auto-deactivates after limit', () async {
      final count = WhatController(0);
      int runs = 0;

      final effect = Effect.unary(count.what, () {
        runs++;
      }, take: 1);
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      count.data = 1;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      count.data = 2;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      terminal.deactivate();
    });

    test('5. Scope-bound via.tether(what.throttle(...)) throttles within scope lifecycle', () async {
      final clicks = WhatController(0);
      int runs = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether(clicks.what.effect.throttle(
            const Duration(milliseconds: 50),
            () => runs++,
          ));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();

      clicks.data = 1;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      clicks.data = 2;
      clicks.data = 3;
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 2);

      terminal.deactivate();
    });

    test('6. Scope-bound via.tether(what.debounce(...)) debounces within scope lifecycle', () async {
      final text = WhatController('');
      final observed = <String>[];

      final terminal = RawViaTerminal(
        (via) {
          via.tether(text.what.effect.debounce(
            const Duration(milliseconds: 50),
            () => observed.add(text.data),
          ));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();

      text.data = 'a';
      await Future<void>.delayed(const Duration(milliseconds: 20));
      text.data = 'ab';
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(observed, ['ab']);

      terminal.deactivate();
    });
  });
}
