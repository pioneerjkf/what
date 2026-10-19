// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Effect Guard & Ticket Preservation Suite', () {
    // =========================================================================
    // 1. Explicit Manifest Effect with Guard & Ticket Preservation
    // =========================================================================
    group('1. Explicit Manifest Effect with Guard', () {
      test('1.1 guard == false skips action execution', () async {
        final target = WhatController<int>(0);
        bool isAllowed = false;
        int actionRunCount = 0;

        final effect = Effect.unary(
          target.what,
          () => actionRunCount++,
          guard: () => isAllowed,
        );
        final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
          ..activate()
          ..evaluate();

        // Initial creation does not fire manifest effect
        expect(actionRunCount, 0);

        // Mutate while blocked
        target.set(1);
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 0);

        target.set(2);
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 0);

        // Unblock
        isAllowed = true;
        target.set(3);
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 1);

        // Re-block
        isAllowed = false;
        target.set(4);
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 1);

        terminal.deactivate();
      });

      test('1.2 Ticket Preservation: blocked execution does not consume take limit', () async {
        final target = WhatController<int>(10);
        bool isAllowed = false;
        int actionRunCount = 0;

        final effect = Effect.unary(
          target.what,
          () => actionRunCount++,
          take: 2,
          guard: () => isAllowed,
        );
        final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
          ..activate()
          ..evaluate();

        // Fire 5 mutations while blocked
        for (int i = 0; i < 5; i++) {
          target.set(i);
        }
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 0);

        // First allowed execution (ticket 1 of 2 consumed)
        isAllowed = true;
        target.set(100);
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 1);

        // Block again
        isAllowed = false;
        target.set(200);
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 1);

        // Second allowed execution (ticket 2 of 2 consumed -> deactivates)
        isAllowed = true;
        target.set(300);
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 2);

        // Further mutations do nothing
        target.set(400);
        await Future<void>.delayed(Duration.zero);
        expect(actionRunCount, 2);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 2. Multi-Target List with Guard
    // =========================================================================
    group('2. Multi-Target List with Guard', () {
      test('2.1 Multi-target list effect respects guard', () async {
        final a = WhatController<int>(1);
        final b = WhatController<int>(2);
        bool allowed = false;
        int runs = 0;

        final effect = Effect(
          [a.what, b.what],
          () => runs++,
          guard: () => allowed,
        );
        final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
          ..activate()
          ..evaluate();

        a.set(10);
        b.set(20);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 0);

        allowed = true;
        a.set(100);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 1);

        b.set(200);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 2);

        terminal.deactivate();
      });

      test('2.2 Multi-target effects respect guard and ticket preservation', () async {
        final a = WhatController<int>(1);
        final b = WhatController<int>(2);
        final c = WhatController<int>(3);

        bool allowed = false;
        int runs3 = 0;

        final effect3 = Effect([a.what, b.what, c.what], () => runs3++, take: 1, guard: () => allowed);
        final terminal = RawViaTerminal((via) => via.tether(effect3), onInvalidated: () {})
          ..activate()
          ..evaluate();

        a.set(10);
        await Future<void>.delayed(Duration.zero);
        expect(runs3, 0);

        allowed = true;
        a.set(20);
        await Future<void>.delayed(Duration.zero);
        expect(runs3, 1);

        // Subsequent mutations do nothing (exhausted take: 1)
        b.set(30);
        await Future<void>.delayed(Duration.zero);
        expect(runs3, 1);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. Reactive Effect with Guard & Dynamic Tracking
    // =========================================================================
    group('3. Reactive Effect with Guard & Dynamic Tracking', () {
      test('3.1 Guard dependencies are dynamically tracked in effect', () async {
        final gate = WhatController<bool>(false);
        final payload = WhatController<String>('Initial');
        int executionCount = 0;
        String? observed;

        final effect = Effect.via(
          (via) {
            executionCount++;
            observed = via(payload.what);
          },
          guard: (via) => via(gate.what),
        );
        final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
          ..activate()
          ..evaluate();

        // Initial evaluation: guard is false, body does NOT run
        expect(executionCount, 0);
        expect(observed, isNull);

        // Mutating payload while gate is false: body does not run
        payload.data = 'UpdatedWhileBlocked';
        await Future<void>.delayed(Duration.zero);
        expect(executionCount, 0);

        // Open the gate: since gate was read inside guard, mutating gate triggers re-evaluation!
        gate.data = true;
        await Future<void>.delayed(Duration.zero);
        expect(executionCount, 1);
        expect(observed, 'UpdatedWhileBlocked');

        // Now mutate payload while gate is true
        payload.data = 'ActivePayload';
        await Future<void>.delayed(Duration.zero);
        expect(executionCount, 2);
        expect(observed, 'ActivePayload');

        // Close the gate: re-evaluates, guard is false, body does not run
        gate.data = false;
        await Future<void>.delayed(Duration.zero);
        expect(executionCount, 2);

        // Mutating payload while closed does nothing
        payload.data = 'BlockedAgain';
        await Future<void>.delayed(Duration.zero);
        expect(executionCount, 2);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 4. Debounce & Throttle Effects with Guard
    // =========================================================================
    group('4. Debounce & Throttle Effects with Guard', () {
      test('4.1 ThrottleEffect respects guard and preserves take tickets', () async {
        final target = WhatController<int>(0);
        bool allowed = false;
        int runs = 0;

        final effect = ThrottleEffect.unary(
          target.what,
          const Duration(milliseconds: 20),
          () => runs++,
          take: 1,
          guard: () => allowed,
        );
        final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
          ..activate()
          ..evaluate();

        target.set(1);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(runs, 0);

        allowed = true;
        target.set(2);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(runs, 1);

        // Further mutation ignored due to take: 1
        target.set(3);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(runs, 1);

        terminal.deactivate();
      });

      test('4.2 DebounceEffect respects guard and preserves take tickets', () async {
        final target = WhatController<int>(0);
        bool allowed = false;
        int runs = 0;

        final effect = DebounceEffect.unary(
          target.what,
          const Duration(milliseconds: 20),
          () => runs++,
          take: 1,
          guard: () => allowed,
        );
        final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
          ..activate()
          ..evaluate();

        target.set(1);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(runs, 0);

        allowed = true;
        target.set(2);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(runs, 1);

        // Further mutation ignored due to take: 1
        target.set(3);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(runs, 1);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 5. Declarative Effect and RawViaTerminal with Guard
    // =========================================================================
    group('5. Declarative Effect and RawViaTerminal with Guard', () {
      test('5.1 Declarative target.effect mounted via RawViaTerminal respects guard', () async {
        final target = WhatController<int>(0);
        bool allowed = false;
        int runs = 0;

        final effect = target.what.effect(
          () => runs++,
          take: 1,
          guard: () => allowed,
        );

        final terminal = RawViaTerminal((via) {
          via.tether(effect);
        }, onInvalidated: () {});

        terminal.activate();
        terminal.evaluate();
        expect(runs, 0);

        // Blocked mutation
        target.set(1);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 0);

        // Allowed mutation
        allowed = true;
        target.set(2);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 1);

        // Take limit reached: further mutation does not fire
        target.set(3);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 1);

        terminal.deactivate();
      });

      test('5.2 Effect.via with guard in RawViaTerminal', () async {
        final gate = WhatController<bool>(false);
        final val = WhatController<int>(100);
        int runs = 0;

        final terminal = RawViaTerminal((via) {
          via.tether(Effect.via(
            (via) {
              runs++;
              final _ = via(val.what);
            },
            guard: (via) => via(gate.what),
          ));
        }, onInvalidated: () {});

        terminal.activate();
        terminal.evaluate();

        // Initial evaluation: guard is false, body does not run
        expect(runs, 0);

        // Gate becomes true
        gate.set(true);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 1);

        // Mutate val while gate is true
        val.set(200);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 2);

        // Gate becomes false
        gate.set(false);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 2);

        // Mutate val while gate is false -> body does not run
        val.set(300);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 2);

        terminal.deactivate();
      });
    });
  });
}
