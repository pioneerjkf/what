// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('2-Phase Lazy-Pull Architecture (LPDAG) Invariant Verification', () {
    // =========================================================================
    // Invariant 1: Zero Eager Computation During Push Phase
    // =========================================================================
    test('1. Zero eager computation during push phase', () {
      int computeCount = 0;
      final root = WhatController(10);
      final mapped = computed((via) {
        computeCount++;
        return via(root.what) * 2;
      });

      int invalidationCount = 0;
      final terminal = RawWhatTerminal(mapped, onInvalidated: () {
        invalidationCount++;
      });
      terminal.activate();

      // Initial read pulls once
      expect(terminal.data, 20);
      expect(computeCount, 1);
      expect(invalidationCount, 0);

      // Mutate root: push phase must propagate dirty pulse without computing
      root.data = 20;
      expect(invalidationCount, 1);
      expect(computeCount, 1, reason: 'Zero computation during push phase!');

      // Further mutation while pending: coalesced under Q1: A
      root.data = 30;
      expect(invalidationCount, 1, reason: 'Coalesced dirty pulse under Q1: A');
      expect(computeCount, 1, reason: 'Still zero computation during push phase!');

      // Pull phase: resolves fresh state on demand
      expect(terminal.data, 60);
      expect(computeCount, 2, reason: 'Computed exactly once on pull!');

      terminal.deactivate();
    });

    // =========================================================================
    // Invariant 2: Bursty Mutation Coalescing (Q1: A)
    // =========================================================================
    test('2. Bursty mutation coalescing (Q1: A) delivers 1 notification during batch transaction', () {
      final counter = WhatController(0, distinct: false);
      int invalidations = 0;
      final terminal = RawWhatTerminal(counter.what, onInvalidated: () => invalidations++);
      terminal.activate();

      expect(terminal.data, 0);
      expect(invalidations, 0);

      // Rapid burst of 100 mutations within an atomic batch
      batch(() {
        for (int i = 1; i <= 100; i++) {
          counter.data = i;
        }
      });

      expect(invalidations, 1, reason: 'Q1: A strictly drops redundant dirty pulses during batch transaction');

      // Pulling clears pending flag
      expect(terminal.data, 100);

      // Next mutation after pull triggers new notification
      counter.data = 101;
      expect(invalidations, 2);
      expect(terminal.data, 101);

      terminal.deactivate();
    });

    // =========================================================================
    // Invariant 3: Re-activation without Spurious onInvalidated (Q2: B)
    // =========================================================================
    test('3. Re-activation while mutated does NOT trigger onInvalidated (Q2: B)', () {
      final source = WhatController('Initial');
      int invalidations = 0;
      final terminal = RawWhatTerminal(source.what, onInvalidated: () => invalidations++);
      terminal.activate();

      expect(terminal.data, 'Initial');
      expect(invalidations, 0);

      // Deactivate
      terminal.deactivate();
      expect(terminal.isActive, isFalse);

      // Mutate while disconnected
      source.data = 'MutatedWhileDormant';
      expect(invalidations, 0);

      // Re-activate: under Q2: B, onInvalidated is NOT called
      terminal.activate();
      expect(invalidations, 0, reason: 'Q2: B drops onInvalidated on reconnection');

      // State is lazily resolved to latest value on pull
      expect(terminal.data, 'MutatedWhileDormant');

      terminal.deactivate();
    });

    // =========================================================================
    // Invariant 4: RawWhatTerminal Pure Lazy Initialization (Q3: A)
    // =========================================================================
    test('4. RawWhatTerminal is purely lazy on construction (Q3: A)', () {
      int computeCount = 0;
      final source = computed((via) {
        computeCount++;
        return 'ComputedValue';
      });

      // Construction of terminal must NOT pull upstream
      final terminal = RawWhatTerminal(source, onInvalidated: () {});
      expect(computeCount, 0, reason: 'Q3: A guarantees pure lazy terminal at birth');

      // Activation must NOT pull upstream
      terminal.activate();
      expect(computeCount, 0, reason: 'Activation attaches lifecycle without eager pull');

      // First read triggers initial pull
      expect(terminal.data, 'ComputedValue');
      expect(computeCount, 1);

      terminal.deactivate();
    });

    // =========================================================================
    // Invariant 5: Diamond Graph Single Evaluation & Version Gating
    // =========================================================================
    test('5. Diamond DAG evaluates exactly once on pull and short-circuits unchanged branches', () {
      final root = WhatController(1);

      int leftComputes = 0;
      final left = computed((via) {
        leftComputes++;
        return via(root.what) * 10;
      });

      int rightComputes = 0;
      final right = computed((via) {
        rightComputes++;
        return via(root.what) + 5;
      });

      int diamondComputes = 0;
      final diamond = computed((via) {
        diamondComputes++;
        return via(left) + via(right);
      });

      final terminal = RawWhatTerminal(diamond, onInvalidated: () {});
      terminal.activate();

      // Initial read: 10 + 6 = 16
      expect(terminal.data, 16);
      expect(leftComputes, 1);
      expect(rightComputes, 1);
      expect(diamondComputes, 1);

      // Mutate root
      root.data = 2;
      expect(leftComputes, 1, reason: 'Push does not compute left');
      expect(rightComputes, 1, reason: 'Push does not compute right');
      expect(diamondComputes, 1, reason: 'Push does not compute diamond');

      // Pull on diamond terminal: (20 + 7) = 27
      expect(terminal.data, 27);
      expect(leftComputes, 2);
      expect(rightComputes, 2);
      expect(diamondComputes, 2, reason: 'Single glitch-free evaluation on diamond join');

      terminal.deactivate();
    });

    // =========================================================================
    // Invariant 6: Deferred Resource Disposal in ManagedWhat
    // =========================================================================
    test('6. ManagedWhat defers disposal until pull or deactivation (non-destructive push)', () {
      final url = WhatController('https://server1.com');
      final disposals = <String>[];
      final creations = <String>[];

      final client = managed<String>(
        create: (via) {
          final res = 'Client(${via(url.what)})';
          creations.add(res);
          return res;
        },
        dispose: (c) {
          disposals.add(c);
        },
      );

      final terminal = RawWhatTerminal(client, onInvalidated: () {});
      terminal.activate();

      // Lazy: not pulled yet, creations must be empty!
      expect(creations, isEmpty);
      expect(disposals, isEmpty);

      // Pull phase: now creates initial client on-demand
      expect(terminal.data, 'Client(https://server1.com)');
      expect(creations, ['Client(https://server1.com)']);
      expect(disposals, isEmpty);

      // Mutate url: push phase must NOT dispose existing client
      url.data = 'https://server2.com';
      expect(disposals, isEmpty, reason: 'Push phase is non-destructive!');
      expect(creations.length, 1);

      // Rapid consecutive mutations without read: still no thrashing or premature disposal
      url.data = 'https://server3.com';
      expect(disposals, isEmpty);
      expect(creations.length, 1);

      // Pull phase: now disposes stale client1 and allocates client3
      expect(terminal.data, 'Client(https://server3.com)');
      expect(disposals, ['Client(https://server1.com)']);
      expect(creations, ['Client(https://server1.com)', 'Client(https://server3.com)']);

      // Deactivation cleans up active resource
      terminal.deactivate();
      expect(disposals, ['Client(https://server1.com)', 'Client(https://server3.com)']);
    });

    // =========================================================================
    // Invariant 7: Effect Scheduled Drop on Unchanged Upstream
    // =========================================================================
    test('7. Effect drops scheduled execution if upstream evaluated to unchanged', () async {
      final user = WhatController((name: 'Alice', age: 25));
      final name = computed((via) => via(user.what).name).distinct();

      int effectRuns = 0;
      String? observedName;

      final effect = Effect.via((via) {
        effectRuns++;
        observedName = via(name);
      });
      final terminal = RawViaTerminal(
        (via) => via.tether(effect),
        onInvalidated: () {},
      )
        ..activate()
        ..evaluate();

      await Future<void>.delayed(Duration.zero);

      expect(effectRuns, 1);
      expect(observedName, 'Alice');

      // Age changes, but selected name remains identical:
      // Dirty is pushed, but effect aborts in pull phase because name did not mutate!
      user.data = (name: 'Alice', age: 26);
      await Future.microtask(() {});

      expect(effectRuns, 1, reason: 'Effect scheduled execution dropped because name was unchanged!');
      expect(observedName, 'Alice');

      // Name changes: effect runs!
      user.data = (name: 'Bob', age: 26);
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(observedName, 'Bob');

      terminal.deactivate();
    });

    // =========================================================================
    // Invariant 8: Downstream Computed Skips Calculation on Distinct Upstream
    // =========================================================================
    test('8. Downstream computed drops re-calculation when intermediate distinct node produces identical state', () {
      final source = WhatController(0, distinct: false);
      final isEven = computed((via) => via(source.what) % 2 == 0).distinct();

      int downstreamComputeCount = 0;
      final downstream = computed((via) {
        downstreamComputeCount++;
        return via(isEven) ? 'EVEN' : 'ODD';
      });

      final terminal = RawWhatTerminal(downstream, onInvalidated: () {});
      terminal.activate();

      expect(terminal.data, 'EVEN');
      expect(downstreamComputeCount, 1);

      // Mutate source: 0 -> 2 (both even).
      // Dirty is pushed through DAG, marking downstream check.
      source.data = 2;

      // Upon lazy pull, isEven evaluates to true (identical).
      // isEven does NOT increment _version.
      // downstream resolves dirty, detects isEven is NOT newer, and skips re-evaluating compute function!
      expect(terminal.data, 'EVEN');
      expect(downstreamComputeCount, 1,
          reason: 'Downstream compute function was dropped because isEven did not increment _version');

      // Mutate source: 2 -> 3 (even -> odd).
      source.data = 3;
      expect(terminal.data, 'ODD');
      expect(downstreamComputeCount, 2);

      terminal.deactivate();
    });
  });
}
