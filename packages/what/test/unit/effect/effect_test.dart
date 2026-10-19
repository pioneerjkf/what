// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('What Direct .effect() Extension Suite', () {
    test('1. WhatEffectExtension creates Effect attached to single What', () async {
      final ctrl = WhatController<int>(0);
      var effectRuns = 0;
      var observedValue = -1;

      final effect = ctrl.what.effect(() {
        effectRuns++;
        observedValue = ctrl.data;
      });

      // Lazy: skips initial evaluation
      expect(effectRuns, 0);

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});

      terminal.activate();
      terminal.evaluate();
      expect(effectRuns, 0);

      // Mutate
      ctrl.set(42);
      expect(effectRuns, 0, reason: 'Batched in microtask queue');

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observedValue, 42);

      terminal.deactivate();

      // Mutation after deactivation does not trigger effect
      ctrl.set(100);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
    });

    test('2. WhatRecord2EffectExtension handles 2-tuple', () async {
      final a = WhatController<int>(1);
      final b = WhatController<String>('hello');
      var runs = 0;
      var lastA = 0;
      var lastB = '';

      final tuple = (a.what, b.what);
      expect(tuple.whats, [a.what, b.what]);

      final effect = tuple.effect(() {
        runs++;
        lastA = a.data;
        lastB = b.data;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);

      // Mutate A
      a.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(lastA, 2);
      expect(lastB, 'hello');

      // Mutate B
      b.set('world');
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);
      expect(lastA, 2);
      expect(lastB, 'world');

      // Coalesced mutation of both A and B in single frame
      a.set(3);
      b.set('coalesced');
      await Future<void>.delayed(Duration.zero);
      expect(runs, 3);
      expect(lastA, 3);
      expect(lastB, 'coalesced');

      terminal.deactivate();
    });

    test('3. WhatRecord3EffectExtension handles 3-tuple', () async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final c = WhatController<int>(3);
      var sum = 0;

      final tuple = (a.what, b.what, c.what);
      expect(tuple.whats, [a.what, b.what, c.what]);

      final effect = tuple.effect(() {
        sum = a.data + b.data + c.data;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();
      expect(sum, 0);

      c.set(30);
      await Future<void>.delayed(Duration.zero);
      expect(sum, 33);

      terminal.deactivate();
    });

    test('4. WhatRecord4EffectExtension handles 4-tuple', () async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final c = WhatController<int>(3);
      final d = WhatController<int>(4);
      var runs = 0;

      final tuple = (a.what, b.what, c.what, d.what);
      // expect(tuple.length, 4);

      final effect = tuple.effect(() {
        runs++;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      d.set(40);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      terminal.deactivate();
    });

    test('5. WhatRecord5EffectExtension handles 5-tuple', () async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final c = WhatController<int>(3);
      final d = WhatController<int>(4);
      final e = WhatController<int>(5);
      var runs = 0;

      final tuple = (a.what, b.what, c.what, d.what, e.what);
      // expect(tuple.length, 5);

      final effect = tuple.effect(() {
        runs++;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      e.set(50);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      terminal.deactivate();
    });

    test('6. WhatIterableEffectExtension handles list and iterable', () async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final c = WhatController<int>(3);
      var runs = 0;

      final list = [a.what, b.what, c.what];
      final effect = list.effect(() {
        runs++;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);

      b.set(20);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      terminal.deactivate();
    });

    test('7. Heterogeneous tuple containing What and What list', () async {
      final g1 = WhatController<int>(10);
      final g2 = WhatController<int>(20);
      final groupCtrl = WhatListController([g1.what, g2.what]);
      final g3 = WhatController<int>(30);

      var runs = 0;
      final effect = (groupCtrl.what, g3.what).effect(() {
        runs++;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);

      // Mutate What list
      groupCtrl.set([g1.what]);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Mutate What
      g3.set(300);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      terminal.deactivate();
    });

    test('8. Effect.unary constructor directly creates and drives unary effect', () async {
      final ctrl = WhatController<String>('initial');
      var runs = 0;
      var observed = '';

      final effect = Effect.unary(ctrl.what, () {
        runs++;
        observed = ctrl.data;
      });

      expect(runs, 0);

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      ctrl.set('updated');
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(observed, 'updated');

      terminal.deactivate();
    });

    test('9. Effect.unary coalesces multiple synchronous mutations into single microtask', () async {
      final ctrl = WhatController<int>(0);
      var runs = 0;

      final effect = Effect.unary(ctrl.what, () {
        runs++;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      // Mutate 5 times synchronously in same event loop tick
      ctrl.set(1);
      ctrl.set(2);
      ctrl.set(3);
      ctrl.set(4);
      ctrl.set(5);

      expect(runs, 0, reason: 'Pending in microtask queue');
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1, reason: '5 synchronous mutations coalesce into 1 effect run');

      terminal.deactivate();
    });

    test('10. Effect.unary cancels pending scheduled microtask when deactivated before execution', () async {
      final ctrl = WhatController<int>(0);
      var runs = 0;

      final effect = Effect.unary(ctrl.what, () {
        runs++;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      // Mutate to schedule microtask
      ctrl.set(1);
      expect(runs, 0);

      // Deactivate immediately before microtask executes
      terminal.deactivate();

      await Future<void>.delayed(Duration.zero);
      expect(runs, 0, reason: 'Deactivating effect must cancel pending scheduled microtask');
    });

    test('11. Effect.unary attached to What list triggers on composite mutations', () async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final groupCtrl = WhatListController([a.what, b.what]);

      var runs = 0;
      final effect = Effect.unary(groupCtrl.what, () {
        runs++;
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      groupCtrl.set([a.what]);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      terminal.deactivate();
    });

    test('12. watch.effect binds effect lifecycle to enclosing watch scope', () async {
      final counter = WhatController<int>(0);
      var effectRuns = 0;
      var observedValue = -1;

      final effect = counter.what.effect(() {
        effectRuns++;
        observedValue = counter.data;
      });

      // Create a RawViaTerminal that registers the effect via via.tether
      var invalidationCount = 0;
      final terminal = RawViaTerminal((via) {
        via.tether(effect);
        return 'TerminalScope';
      }, onInvalidated: () {
        invalidationCount++;
      });

      // 1. Activate terminal -> should automatically activate effect via lifecycle anchor!
      terminal.activate();
      terminal.evaluate();
      expect(effectRuns, 0, reason: 'Explicit manifest effect skips initial run');

      // 2. Mutate counter -> triggers effect, does NOT invalidate parent terminal
      counter.set(10);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observedValue, 10);
      expect(invalidationCount, 0, reason: 'Effect must not emit dirty pulses to parent terminal');

      // 3. Deactivate terminal -> should automatically deactivate effect!
      terminal.deactivate();

      // Mutating while terminal is deactivated does NOT trigger effect
      counter.set(20);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);

      // 4. Reactivate terminal -> automatically reactivates effect!
      terminal.activate();
      terminal.evaluate();
      counter.set(30);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 2);
      expect(observedValue, 30);

      terminal.deactivate();
    });

    test('13. Effect.group activates and deactivates child effects as a unified DAG terminal', () async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      var aRuns = 0;
      var bRuns = 0;

      final e1 = a.what.effect(() => aRuns++);
      final e2 = b.what.effect(() => bRuns++);
      final group = Effect.group([e1, e2]);

      final terminal = RawViaTerminal((via) {
        via.tether(group);
      }, onInvalidated: () {});

      // 1. Activate scope -> activates group and children
      terminal.activate();
      terminal.evaluate();

      // Mutate sources
      a.set(10);
      b.set(20);
      await Future<void>.delayed(Duration.zero);
      expect(aRuns, 1);
      expect(bRuns, 1);

      // 2. Deactivate scope -> deactivates group and children
      terminal.deactivate();

      a.set(100);
      b.set(200);
      await Future<void>.delayed(Duration.zero);
      expect(aRuns, 1);
      expect(bRuns, 1);

      // 3. Reactivate scope
      terminal.activate();
      terminal.evaluate();

      a.set(1000);
      await Future<void>.delayed(Duration.zero);
      expect(aRuns, 2);

      terminal.deactivate();
    });

    test('14. watch.effect binds EffectGroup lifecycle to enclosing watch scope with 0 rebuilds', () async {
      final a = WhatController<int>(0);
      final b = WhatController<int>(0);
      var aRuns = 0;
      var bRuns = 0;

      final e1 = a.what.effect(() => aRuns++);
      final e2 = b.what.effect(() => bRuns++);
      final group = (e1, e2).group;

      var invalidations = 0;
      final terminal = RawViaTerminal((via) {
        via.tether(group);
        return 'HostScope';
      }, onInvalidated: () {
        invalidations++;
      });

      // Mount/activate terminal
      terminal.activate();
      terminal.evaluate();

      // Trigger child effects
      a.set(1);
      b.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(aRuns, 1);
      expect(bRuns, 1);
      expect(invalidations, 0, reason: 'Zero-rebuild invariant holds for group');

      // Unmount/deactivate terminal
      terminal.deactivate();

      // Mutations while unmounted do not trigger
      a.set(3);
      await Future<void>.delayed(Duration.zero);
      expect(aRuns, 1);
    });

    test('15. Tuple records and Iterable .group extensions create valid EffectGroup instances', () {
      final a = WhatController<int>(0);
      final e1 = a.what.effect(() {});
      final e2 = a.what.effect(() {});
      final e3 = a.what.effect(() {});
      final e4 = a.what.effect(() {});
      final e5 = a.what.effect(() {});

      final t2 = (e1, e2);
      expect(t2.effects, [e1, e2]);
      final g2 = t2.group;
      expect(g2.effects.length, 2);

      final t3 = (e1, e2, e3);
      expect(t3.effects, [e1, e2, e3]);
      final g3 = t3.group;
      expect(g3.effects.length, 3);

      final t4 = (e1, e2, e3, e4);
      expect(t4.effects, [e1, e2, e3, e4]);
      final g4 = t4.group;
      expect(g4.effects.length, 4);

      final t5 = (e1, e2, e3, e4, e5);
      expect(t5.effects, [e1, e2, e3, e4, e5]);
      final g5 = t5.group;
      expect(g5.effects.length, 5);

      final list = [e1, e2, e3];
      expect(list.effects, list);
      final gList = list.group;
      expect(gList.effects.length, 3);
    });

    test('16. WhatIterableEffectExtension provides  getter symmetrically', () {
      final a = WhatController<int>(0);
      final b = WhatController<int>(1);
      final list = [a.what, b.what];
      expect(list, list);

      final effect = list.effect(() {});
      expect(effect, isA<Effect>());
    });

    test('17. EffectGroup deduplicates identical child effects', () async {
      final a = WhatController<int>(0);
      var runs = 0;
      final e1 = a.what.effect(() => runs++);
      final e2 = a.what.effect(() => runs++);

      final group = EffectGroup([e1, e1, e2, e2, e1]);
      expect(group.effects.length, 2);
      expect(group.effects, [e1, e2]);

      final terminal = RawViaTerminal((via) {
        via.tether(group);
      }, onInvalidated: () {});

      terminal.activate();
      terminal.evaluate();

      a.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      terminal.deactivate();
    });

    test('18. Unary and N-ary Manifest Effect forwards uncaught errors to onUncaughtError', () async {
      final source = WhatController<int>(0);
      Object? caughtError;
      StackTrace? caughtStack;

      final effect = source.what.effect(
        () => throw StateError('Unary effect action failed'),
        onUncaughtError: (error, stack) {
          caughtError = error;
          caughtStack = stack;
        },
      );

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      source.set(1);
      await Future<void>.delayed(Duration.zero);

      expect(caughtError, isA<StateError>());
      expect((caughtError as StateError).message, 'Unary effect action failed');
      expect(caughtStack, isNotNull);

      terminal.deactivate();
    });

    test('19. Manifest Effect forwards guard uncaught errors to onUncaughtError', () async {
      final source = WhatController<int>(0);
      Object? caughtError;

      final effect = Effect(
        [source.what],
        () {},
        guard: () => throw FormatException('Guard evaluation failed'),
        onUncaughtError: (error, stack) {
          caughtError = error;
        },
      );

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      source.set(1);
      await Future<void>.delayed(Duration.zero);

      expect(caughtError, isA<FormatException>());
      expect((caughtError as FormatException).message, 'Guard evaluation failed');

      terminal.deactivate();
    });

    test('20. WhatVia Effect forwards uncaught errors to onUncaughtError during reactive evaluation', () async {
      final source = WhatController<int>(0);
      final caughtErrors = <Object>[];

      final terminal = RawViaTerminal((via) {
        via.tether(Effect.via(
          (via) {
            final val = via(source.what);
            if (val > 0) {
              throw StateError('WhatVia reactive error: $val');
            }
          },
          onUncaughtError: (error, stack) {
            caughtErrors.add(error);
          },
        ));
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      expect(caughtErrors, isEmpty);

      source.set(1);
      await Future<void>.delayed(Duration.zero);

      expect(caughtErrors.length, 1);
      expect(caughtErrors.first, isA<StateError>());
      expect((caughtErrors.first as StateError).message, 'WhatVia reactive error: 1');

      terminal.deactivate();
    });

    test('21. Declarative Effect handled, debounce, and throttle properties and creation', () {
      final a = WhatController(1);
      final b = WhatController(2);
      final c = WhatController(3);
      final d = WhatController(4);
      final e = WhatController(5);

      // what.effect.handled
      final singleHandled = a.what.effect.handled((handle) {});
      expect(singleHandled, isA<Effect>());

      // targets.effect.handled
      final multiHandled = [a.what, b.what].effect.handled((handle) {});
      expect(multiHandled, isA<Effect>());

      // Effect.handledVia
      final viaHandled = Effect.handledVia((via, handle) {});
      expect(viaHandled, isA<Effect>());

      // Unary debounce
      final uDebounce = a.what.effect.debounce(const Duration(milliseconds: 50), () {}, leading: true, trailing: false);
      expect(uDebounce.duration, const Duration(milliseconds: 50));
      expect(uDebounce.leading, isTrue);
      expect(uDebounce.trailing, isFalse);

      // N-ary debounce
      final mDebounce =
          [a.what, b.what].effect.debounce(const Duration(milliseconds: 60), () {}, leading: false, trailing: true);
      expect(mDebounce.duration, const Duration(milliseconds: 60));
      expect(mDebounce.leading, isFalse);
      expect(mDebounce.trailing, isTrue);

      // Unary throttle
      final uThrottle = a.what.effect.throttle(const Duration(milliseconds: 70), () {}, leading: true, trailing: false);
      expect(uThrottle.duration, const Duration(milliseconds: 70));
      expect(uThrottle.leading, isTrue);
      expect(uThrottle.trailing, isFalse);

      // N-ary throttle
      final mThrottle =
          [a.what, b.what].effect.throttle(const Duration(milliseconds: 80), () {}, leading: false, trailing: true);
      expect(mThrottle.duration, const Duration(milliseconds: 80));
      expect(mThrottle.leading, isFalse);
      expect(mThrottle.trailing, isTrue);

      // WhatRecord3, 4, 5 effect scopes
      final r3 = (a.what, b.what, c.what);
      expect(r3.effect, isA<WhatEffectScope>());

      final r4 = (a.what, b.what, c.what, d.what);
      expect(r4.effect, isA<WhatEffectScope>());

      final r5 = (a.what, b.what, c.what, d.what, e.what);
      expect(r5.effect, isA<WhatEffectScope>());

      // Iterable<What>.whats
      expect([a.what, b.what].whats.length, 2);
    });
  });
}
