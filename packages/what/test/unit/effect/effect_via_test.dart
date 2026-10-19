// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Effect Engine Tests', () {
    test('1. Intercepts and completely blocks dirty pulses from propagating downstream', () async {
      final normalSource = WhatController<int>(10);
      final effectSource = WhatController<int>(100);

      var terminalInvalidatedCount = 0;
      var effectRunCount = 0;
      var effectObservedValue = 0;

      final terminal = RawViaTerminal(
        (via) {
          // Normal via read: should invalidate terminal on mutation
          final normalValue = via(normalSource.what);

          // Tethered effect via read: should NOT invalidate terminal on mutation
          via.tether(Effect.via((via) {
            effectRunCount++;
            effectObservedValue = via(effectSource.what);
          }));

          return 'Terminal-$normalValue';
        },
        onInvalidated: () {
          terminalInvalidatedCount++;
        },
      );

      terminal.activate();
      expect(terminal.evaluate(), 'Terminal-10');
      expect(effectRunCount, 0, reason: 'Deferred: Effect does not evaluate on activation callstack');

      await Future<void>.delayed(Duration.zero);
      expect(effectRunCount, 1);
      expect(effectObservedValue, 100);
      expect(terminalInvalidatedCount, 0);

      // 1. Mutate the effect source:
      effectSource.set(200);

      // Verify that the terminal was NOT invalidated synchronously:
      expect(terminalInvalidatedCount, 0, reason: 'Parent terminal must NOT be marked dirty by Effect');

      // Wait for microtask queue:
      await Future<void>.delayed(Duration.zero);

      // Effect action executed in background without waking up parent terminal:
      expect(terminalInvalidatedCount, 0);
      expect(effectRunCount, 2);
      expect(effectObservedValue, 200);

      // 2. Mutate normal source: terminal MUST be invalidated:
      normalSource.set(20);
      expect(terminalInvalidatedCount, 1, reason: 'Normal dependency mutation still invalidates terminal');

      terminal.deactivate();
    });

    test('2. Lifecycle coupling: deactivating parent terminal deactivates Effect', () async {
      final effectSource = WhatController<String>('Initial');

      var effectRunCount = 0;
      var observed = '';

      final terminal = RawViaTerminal(
        (via) {
          via.tether(Effect.via((via) {
            effectRunCount++;
            observed = via(effectSource.what);
          }));
          return 'UI';
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(effectRunCount, 0);

      await Future<void>.delayed(Duration.zero);
      expect(effectRunCount, 1);
      expect(observed, 'Initial');

      // Mutate while active:
      effectSource.set('Updated');
      await Future<void>.delayed(Duration.zero);
      expect(effectRunCount, 2);
      expect(observed, 'Updated');

      // Deactivate parent terminal:
      terminal.deactivate();

      // Mutate while deactivated: Effect action must NOT run:
      effectSource.set('WhileDeactivated');
      await Future<void>.delayed(Duration.zero);
      expect(effectRunCount, 2);
      expect(observed, 'Updated');
    });

    test('3. Dynamic branch switching prunes unread dependencies during Effect re-evaluation', () async {
      final toggle = WhatController<bool>(true);
      final branchA = WhatController<int>(1);
      final branchB = WhatController<int>(2);

      var observedValue = 0;

      final terminal = RawViaTerminal(
        (via) {
          via.tether(Effect.via((via) {
            if (via(toggle.what)) {
              observedValue = via(branchA.what);
            } else {
              observedValue = via(branchB.what);
            }
          }));
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(observedValue, 0);

      await Future<void>.delayed(Duration.zero);
      expect(observedValue, 1);

      // 1. Mutate branch A (currently active branch): Effect MUST re-evaluate:
      branchA.set(10);
      await Future<void>.delayed(Duration.zero);
      expect(observedValue, 10);

      // 2. Mutate branch B (inactive branch): Effect MUST NOT re-evaluate:
      branchB.set(20);
      await Future<void>.delayed(Duration.zero);
      expect(observedValue, 10);

      // 3. Switch branches: toggle -> false:
      toggle.set(false);
      await Future<void>.delayed(Duration.zero);
      expect(observedValue, 20);

      // 4. Mutate branch A (now inactive branch): Effect MUST NOT re-evaluate:
      branchA.set(100);
      await Future<void>.delayed(Duration.zero);
      expect(observedValue, 20);

      terminal.deactivate();
    });

    test('4. Parent terminal sweeps Effect when conditionally branch-swapped', () async {
      final condition = WhatController<bool>(true);
      final source = WhatController<int>(1);

      var runs = 0;
      final terminal = RawViaTerminal(
        (via) {
          if (via(condition.what)) {
            via.tether(Effect.via((via) {
              runs++;
              final _ = via(source.what);
            }));
          }
          return true;
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      expect(runs, 0);

      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      source.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      // Switch condition to false -> terminal re-evaluates and sweeps the previous Effect!
      condition.set(false);
      terminal.evaluate();

      // Mutating source MUST NOT trigger runs because the old Effect was swept & auto-deactivated!
      source.set(3);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      terminal.deactivate();
    });

    test('5. Global scheduler cancels pending effect execution when deactivated before tick', () async {
      final source = WhatController<int>(1);

      var runs = 0;
      final terminal = RawViaTerminal(
        (via) {
          via.tether(Effect.via((via) {
            runs++;
            final _ = via(source.what);
          }));
          return 'Scheduler-UI';
        },
        onInvalidated: () {},
      );

      terminal.activate();
      terminal.evaluate();
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Mutate source: Effect is scheduled on _Scheduler.instance
      source.set(2);

      // Deactivate immediately before microtask tick:
      terminal.deactivate();

      // Wait for scheduler microtask:
      await Future<void>.delayed(Duration.zero);

      // Runs must remain 1 because deactivation cancelled pending effect! Zero ghost execution!
      expect(runs, 1);
    });

    test('6. Pull firewall: Effect._isDirtySince returns false, preventing pull-based dirty leaks', () async {
      final effectSource = WhatController<int>(1);

      var parentInvalidated = 0;
      final terminal = RawViaTerminal(
        (via) {
          via.tether(Effect.via((via) {
            final _ = via(effectSource.what);
          }));
          return 'Result';
        },
        onInvalidated: () {
          parentInvalidated++;
        },
      );

      terminal.activate();
      terminal.evaluate();
      expect(parentInvalidated, 0);

      // Deactivate parent terminal
      terminal.deactivate();

      // Mutate effect source while parent is deactivated
      effectSource.set(99);

      // Reactivate parent terminal:
      // When terminal reactivates, it checks upstream sources via _isSourceDirty.
      // Because Effect._isDirtySince returns false, the terminal does NOT consider itself dirty!
      terminal.activate();
      expect(parentInvalidated, 0, reason: 'Parent terminal must NOT be dirtied via pull when waking up');

      terminal.deactivate();
    });

    test('7. Dormant on creation: Effect.via does not evaluate until tethered scope activates', () async {
      final source = WhatController<int>(10);
      var runCount = 0;
      var observed = -1;

      final effect = Effect.via((via) {
        runCount++;
        observed = via(source.what);
      });

      // 1. Dormant upon construction:
      expect(runCount, 0, reason: 'Must NOT evaluate on construction while inactive');

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});

      // 2. Evaluates when scope activates:
      terminal.activate();
      terminal.evaluate();
      expect(runCount, 0, reason: 'Must NOT evaluate on activation callstack (deferred to microtask)');

      await Future<void>.delayed(Duration.zero);
      expect(runCount, 1, reason: 'Evaluates on microtask upon activation');
      expect(observed, 10);

      // 3. Mutates while active:
      source.set(20);
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 2);
      expect(observed, 20);

      // 4. Deactivate and reactivate scope:
      terminal.deactivate();

      source.set(30);
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 2, reason: 'Does not run while deactivated');

      terminal.activate();
      terminal.evaluate();
      expect(runCount, 2, reason: 'Does not evaluate synchronously on reactivation callstack');

      await Future<void>.delayed(Duration.zero);
      expect(runCount, 3, reason: 'Re-evaluates on reactivation microtask to re-sync state');
      expect(observed, 30);

      terminal.deactivate();
    });
  });
}
