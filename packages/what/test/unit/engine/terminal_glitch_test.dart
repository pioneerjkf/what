// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('2-Phase _PushScope & Synchronous Terminal Flush Suite', () {
    // =========================================================================
    // Test Case 1: Diamond Graph Glitch Prevention
    // =========================================================================
    test('1. Diamond dependency graph never observes glitch intermediate values in onInvalidated', () {
      // Topology:
      //         root
      //        /    \
      //      left   right
      //        \    /
      //         sum
      //          │
      //       terminal
      final root = WhatController<int>(10);
      final left = computed<int>((via) => via(root.what) + 1); // 11 -> 21
      final right = computed<int>((via) => via(root.what) + 2); // 12 -> 22
      final sum = computed<int>((via) => via(left) + via(right)); // 23 -> 43

      final valuesWitnessed = <int>[];
      int invalidationCount = 0;

      late final RawWhatTerminal<int> terminal;
      terminal = RawWhatTerminal(sum, onInvalidated: () {
        invalidationCount++;
        valuesWitnessed.add(terminal.data);
      });

      terminal.activate();
      expect(terminal.data, 23);
      expect(invalidationCount, 0);

      // Mutate root: 10 -> 20
      // In a glitched system, left might update first yielding 21 + 12 = 33,
      // followed by right updating yielding 21 + 22 = 43.
      // Under _PushScope: Left and Right are both dirtied in Phase 1,
      // and Terminal is flushed exactly once in Phase 2 with final value 43.
      root.data = 20;

      expect(invalidationCount, 1, reason: 'Terminal must be flushed exactly once');
      expect(valuesWitnessed, [43], reason: 'Glitch intermediate value (33) must never be witnessed');
      expect(terminal.data, 43);

      terminal.deactivate();
    });

    // =========================================================================
    // Test Case 2: RawViaTerminal Diamond Graph Glitch Prevention
    // =========================================================================
    test('2. RawViaTerminal diamond graph dynamically evaluates without glitch', () {
      final root = WhatController<int>(1);
      final left = computed((via) => via(root.what) * 2); // 2 -> 20
      final right = computed((via) => via(root.what) * 3); // 3 -> 30

      final valuesWitnessed = <int>[];
      int invalidations = 0;

      late final RawViaTerminal<int> viaTerminal;
      viaTerminal = RawViaTerminal<int>(
        (via) => via(left) + via(right),
        onInvalidated: () {
          invalidations++;
          valuesWitnessed.add(viaTerminal.evaluate());
        },
      );

      viaTerminal.activate();
      expect(viaTerminal.evaluate(), 5); // 2 + 3

      // Mutate root: 1 -> 10
      root.data = 10;

      expect(invalidations, 1);
      expect(valuesWitnessed, [50]); // 20 + 30, never intermediate 23 or 32
      expect(viaTerminal.evaluate(), 50);

      viaTerminal.deactivate();
    });

    // =========================================================================
    // Test Case 3: Multiple Independent Entries & Pipelines
    // =========================================================================
    test('3. Independent entry mutations coalesce and resolve cleanly', () {
      final a = WhatController<int>(1);
      final b = WhatController<int>(10);
      final combined = computed<int>((via) => via(a.what) + via(b.what));

      final log = <int>[];
      late final RawWhatTerminal<int> terminal;
      terminal = RawWhatTerminal(combined, onInvalidated: () {
        log.add(terminal.data);
      });
      terminal.activate();

      expect(terminal.data, 11);

      // Mutate a then b
      a.data = 2;
      expect(log, [12]);

      b.data = 20;
      expect(log, [12, 22]);

      terminal.deactivate();
    });

    // =========================================================================
    // Test Case 4: Trampoline Loop Flattens Reentrant Mutations
    // =========================================================================
    test('4. Reentrant mutation inside onInvalidated drains sequentially via trampoline without stack explosion', () {
      final source = WhatController<int>(1);
      final history = <int>[];
      late final RawWhatTerminal<int> terminal;

      terminal = RawWhatTerminal(source.what, onInvalidated: () {
        final current = terminal.data;
        history.add(current);
        if (current < 5) {
          source.set(current + 1);
        }
      });

      terminal.activate();
      expect(terminal.data, 1);
      expect(history, isEmpty);

      // Trigger mutation to 2, which will chain: 2 -> 3 -> 4 -> 5
      source.set(2);

      expect(history, [2, 3, 4, 5], reason: 'Trampoline sequentially drains reentrant mutations');
      expect(source.data, 5);
      expect(terminal.data, 5);

      terminal.deactivate();
    });

    // =========================================================================
    // Test Case 5: Inter-Terminal Cascade via Reentrant Mutation
    // =========================================================================
    test('5. Reentrant cascade across two terminals drains in causal order', () {
      final sourceA = WhatController<int>(1);
      final sourceB = WhatController<int>(10);

      final executionOrder = <String>[];

      late final RawWhatTerminal<int> terminalA;
      late final RawWhatTerminal<int> terminalB;

      terminalA = RawWhatTerminal(sourceA.what, onInvalidated: () {
        executionOrder.add('A:${terminalA.data}');
        if (terminalA.data == 2) {
          sourceB.set(20);
        }
      });

      terminalB = RawWhatTerminal(sourceB.what, onInvalidated: () {
        executionOrder.add('B:${terminalB.data}');
      });

      terminalA.activate();
      terminalB.activate();

      expect(terminalA.data, 1);
      expect(terminalB.data, 10);

      // Mutate A to 2, which causes A to run, mutating B to 20, causing B to run
      sourceA.set(2);

      expect(executionOrder, ['A:2', 'B:20']);
      expect(terminalA.data, 2);
      expect(terminalB.data, 20);

      terminalA.deactivate();
      terminalB.deactivate();
    });

    // =========================================================================
    // Test Case 6: Deactivation While Queued in Pushing Scope
    // =========================================================================
    test('6. Terminal deactivated while in pushing queue drops flush callback', () {
      final source = WhatController<int>(1);

      late final RawWhatTerminal<int> terminalA;
      late final RawWhatTerminal<int> terminalB;

      int aRunCount = 0;
      int bRunCount = 0;

      terminalA = RawWhatTerminal(source.what, onInvalidated: () {
        aRunCount++;
        terminalB.deactivate();
      });

      terminalB = RawWhatTerminal(source.what, onInvalidated: () {
        bRunCount++;
      });

      terminalB.activate();
      terminalA.activate();

      // Trigger mutation: both A and B are dirtied and queued into pushing scope.
      // A is drained first, and deactivates B.
      // When B's turn comes, _lifecycle.isActive is false, so it must be dropped.
      source.set(2);

      expect(aRunCount, 1);
      expect(bRunCount, 0, reason: 'Deactivated terminal in queue must drop onInvalidated');
      expect(terminalB.isActive, isFalse);

      terminalA.deactivate();
    });

    // =========================================================================
    // Test Case 7: WhatCoupler as _PushOriginMixin Origin Point
    // =========================================================================
    test('7. WhatCoupler couple triggers _PushScope flush without glitch', () {
      final s1 = WhatController<int>(10);
      final s2 = WhatController<int>(20);

      final coupler = WhatCoupler<int>(s1.what);
      final derived = computed((via) => via(coupler.what) * 2);

      final values = <int>[];
      final terminal = RawWhatTerminal(derived, onInvalidated: () {
        values.add(derived.peek);
      });
      terminal.activate();

      expect(terminal.data, 20);

      // Couple source to s2
      coupler.couple(s2.what);

      expect(values, [40]);
      expect(terminal.data, 40);

      terminal.deactivate();
    });
  });
}
