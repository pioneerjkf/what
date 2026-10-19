// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('via.tether Scope Binding & Execution Suite', () {
    test('1. Standalone Effect.via() functor intercepts dirty pulses and shields parent scope', () async {
      final counter = WhatController(0);
      var parentInvalidations = 0;
      var effectRuns = 0;
      var lastObserved = -1;

      final terminal = RawViaTerminal(
        (via) {
          // effect silently registers in this via scope
          via.tether(Effect.via((via) {
            effectRuns++;
            lastObserved = via(counter.what);
          }));
          return 'ParentResult';
        },
        onInvalidated: () {
          parentInvalidations++;
        },
      );

      terminal.activate();
      terminal.evaluate();

      expect(effectRuns, 0);
      expect(parentInvalidations, 0);

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(lastObserved, 0);
      expect(parentInvalidations, 0);

      // Mutate counter: parent must NOT be invalidated!
      counter.data = 42;
      expect(parentInvalidations, 0, reason: 'Parent scope must be completely shielded from dirty pulses');
      expect(effectRuns, 1, reason: 'Effect action is batched and runs in microtask queue');

      // Await scheduler microtask:
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 2);
      expect(lastObserved, 42);
      expect(parentInvalidations, 0);

      terminal.deactivate();
    });

    test('2. via.tether(Effect.via(...)) binds and returns active Effect with lifecycle', () async {
      final text = WhatController('hello');
      Effect? capturedEffect;
      var runs = 0;

      final terminal = RawViaTerminal(
        (via) {
          final effect = via.tether(Effect.via((via) {
            runs++;
            final _ = via(text.what);
          }));
          capturedEffect = effect;
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();

      expect(runs, 0);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(capturedEffect, isNotNull);

      text.data = 'Updated';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      terminal.deactivate();

      text.data = 'WhileDeactivated';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);
    });

    test('3. via.tether(effect) binds and returns active Effect with lifecycle', () async {
      final source = WhatController(100);
      final observed = <int>[];
      Effect? capturedEffect;

      final terminal = RawViaTerminal(
        (via) {
          final effect = via.tether(source.what.effect(() {
            observed.add(source.data);
          }));
          capturedEffect = effect;
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();

      expect(observed, []); // explicit effect skips 0-run
      expect(capturedEffect, isNotNull);

      source.data = 200;
      await Future<void>.delayed(Duration.zero);
      expect(observed, [200]);

      terminal.deactivate();

      source.data = 300;
      await Future<void>.delayed(Duration.zero);
      expect(observed, [200]);
    });

    test('4. Dynamic branch switching prunes unobserved dependencies inside Effect.via', () async {
      final condition = WhatController(true);
      final branchA = WhatController('A1');
      final branchB = WhatController('B1');

      var runs = 0;
      var lastRead = '';

      final terminal = RawViaTerminal(
        (via) {
          via.tether(Effect.via((via) {
            runs++;
            lastRead = via(condition.what) ? via(branchA.what) : via(branchB.what);
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(lastRead, 'A1');

      // Mutate branchB (currently unobserved): must NOT trigger run!
      branchB.data = 'B2';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Switch condition to false: runs and binds to branchB
      condition.data = false;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);
      expect(lastRead, 'B2');

      // Now mutating branchA (pruned) must NOT trigger run!
      branchA.data = 'A2';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      // Mutating branchB triggers run:
      branchB.data = 'B3';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 3);
      expect(lastRead, 'B3');

      terminal.deactivate();
    });

    test('5. Global scheduler cancels pending effect execution when parent deactivates', () async {
      final source = WhatController(1);
      var runs = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether(Effect.via((via) {
            runs++;
            final _ = via(source.what);
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Mutate source: effect is scheduled on _Scheduler.instance
      source.data = 2;

      // Deactivate immediately before microtask tick:
      terminal.deactivate();

      // Wait for scheduler microtask:
      await Future<void>.delayed(Duration.zero);

      // Runs must remain 1: zero ghost execution!
      expect(runs, 1);
    });

    test('6. Microtask batching coalesces rapid consecutive mutations into a single execution', () async {
      final a = WhatController(1);
      final b = WhatController(10);
      var runs = 0;
      var sum = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether(Effect.via((via) {
            runs++;
            sum = via(a.what) + via(b.what);
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(sum, 11);

      // Rapidly mutate both states multiple times synchronously:
      a.data = 2;
      b.data = 20;
      a.data = 3;
      b.data = 30;

      expect(runs, 1, reason: 'Synchronous mutations do not eagerly execute effect');

      await Future<void>.delayed(Duration.zero);

      // Must execute exactly once with the latest resolved values!
      expect(runs, 2);
      expect(sum, 33);

      terminal.deactivate();
    });
  });

  group('Direct .effect() Extension Suite with via.tether(...) (Single, Tuples & Iterable)', () {
    test('1. Single What .effect() skips initial execution (0 initial runs)', () async {
      final cart = WhatController('item_A');
      var runs = 0;
      var lastRecorded = '';

      final terminal = RawViaTerminal(
        (via) {
          via.tether(cart.what.effect(() {
            runs++;
            lastRecorded = cart.data;
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();

      // [Invariant] Crucial: Must be ZERO runs upon construction/mount!
      expect(runs, 0, reason: 'Explicit .effect() MUST skip initial evaluation');
      expect(lastRecorded, '');

      // Mutate cart
      cart.data = 'item_B';
      expect(runs, 0, reason: 'Pending in microtask');

      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(lastRecorded, 'item_B');

      terminal.deactivate();
    });

    test('2. 2-Tuple (cart, coupon).effect() tracks pair and coalesces mutations', () async {
      final cart = WhatController(100);
      final coupon = WhatController(10);
      var runs = 0;
      var total = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether((cart.what, coupon.what).effect(() {
            runs++;
            total = cart.data - coupon.data;
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();

      expect(runs, 0, reason: 'Zero initial execution');

      // Mutate first item
      cart.data = 200;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(total, 190);

      // Mutate second item
      coupon.data = 50;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);
      expect(total, 150);

      // Mutate both synchronously: coalesces to a single execution
      cart.data = 300;
      coupon.data = 30;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 3);
      expect(total, 270);

      terminal.deactivate();
    });

    test('3. 3-Tuple (a, b, c).effect() tracks triplet', () async {
      final a = WhatController(1);
      final b = WhatController(2);
      final c = WhatController(3);
      var runs = 0;
      var product = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether((a.what, b.what, c.what).effect(() {
            runs++;
            product = a.data * b.data * c.data;
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);

      c.data = 10;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(product, 20);

      terminal.deactivate();
    });

    test('4. Dynamic List [a, b].effect() tracks collection', () async {
      final a = WhatController('hello');
      final b = WhatController('world');
      var runs = 0;
      var combined = '';

      final terminal = RawViaTerminal(
        (via) {
          via.tether([a.what, b.what].effect(() {
            runs++;
            combined = '${a.data} ${b.data}';
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);

      a.data = 'super';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(combined, 'super world');

      terminal.deactivate();
    });

    test('5. Untracked execution boundary prevents re-trigger infection', () async {
      final trigger = WhatController('trigger_0');
      final bystander = WhatController('bystander_0');
      var runs = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether(trigger.what.effect(() {
            runs++;
            // Reading bystander inside untracked action scope
            final _ = bystander.data;
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);

      // Mutate trigger: runs 1st time
      trigger.data = 'trigger_1';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Mutate bystander: MUST NOT trigger execution!
      bystander.data = 'bystander_1';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1, reason: 'Bystander read in untracked scope must NOT be a trigger!');

      terminal.deactivate();
    });
  });

  group('Explicit .effect() and via.tether(...) Scope Binding Suite', () {
    test('1. via.tether((cart, coupon).effect(() {})) registers and triggers on pair mutation', () async {
      final cart = WhatController(1);
      final coupon = WhatController(10);

      var runs = 0;
      var lastCart = 0;
      var lastCoupon = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether((cart.what, coupon.what).effect(() {
            runs++;
            lastCart = cart.data;
            lastCoupon = coupon.data;
          }));
          return 'WidgetTree';
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(runs, 0, reason: 'Manifest effect skips initial evaluation');

      cart.data = 2;
      coupon.data = 20;
      await Future<void>.delayed(Duration.zero);

      expect(runs, 1, reason: 'Coalesces mutations into single microtask execution');
      expect(lastCart, 2);
      expect(lastCoupon, 20);

      terminal.deactivate();
    });

    test('2. Pre-declared (a, b).effect() bound via via.tether(plan)', () async {
      final a = WhatController('A');
      final b = WhatController('B');

      var runs = 0;
      // Pre-declared outside any scope
      final plan = (a.what, b.what).effect(() {
        runs++;
      });

      // Mutation before scope mount does not run
      a.data = 'A1';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 0);

      final terminal = RawViaTerminal(
        (via) {
          via.tether(plan);
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();

      a.data = 'A2';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      terminal.deactivate();

      // Mutation after scope deactivation does not run
      b.data = 'B2';
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
    });

    test('3. Single what.effect() with via.tether()', () async {
      final item = WhatController(100);
      var runs = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether(item.what.effect(() => runs++));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);

      item.data = 200;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      terminal.deactivate();
    });

    test('4. (a, b).effect() with via.tether() explicit binding', () async {
      final a = WhatController(10);
      final b = WhatController(20);
      var runs = 0;
      var sum = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether((a.what, b.what).effect(() {
            runs++;
            sum = a.data + b.data;
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      // Explicit effect MUST skip initial evaluation!
      expect(runs, 0);

      a.data = 30;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(sum, 50);

      terminal.deactivate();
    });
  });
}
