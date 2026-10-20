// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('WhatVia & RawViaTerminal Explicit Dependency Tracking Suite', () {
    test('1. WhatVia interface contracts and direct value extraction', () {
      final a = WhatController(10);
      final b = WhatController(20);

      var viaCalls = 0;

      final testVia = _DirectTestVia(
        onCall: (node) {
          viaCalls++;
          return node;
        },
      );

      // 1.1 Direct value extraction with via(a)
      final valA = testVia(a.what);
      expect(valA, 10);
      expect(viaCalls, 1);

      // 1.2 State inspection with via.state(b)
      final stateB = testVia.state(b.what);
      expect(stateB.data, 20);
      expect(viaCalls, 2);
    });

    test('2. RawViaTerminal multi-dependency tracking and push-dirty invalidation', () {
      final a = WhatController(10);
      final b = WhatController(20);
      var invalidationCount = 0;

      final terminal = RawViaTerminal(
        (via) => via(a.what) + via(b.what),
        onInvalidated: () => invalidationCount++,
      );

      // Activate terminal
      terminal.activate();

      // Initial evaluation
      final initialResult = terminal.evaluate();
      expect(initialResult, 30);
      expect(invalidationCount, 0);

      // Mutating 'a' pushes dirty invalidation to terminal
      a.data = 15;
      expect(invalidationCount, 1);

      // Re-evaluating pulls fresh data
      final updatedResult = terminal.evaluate();
      expect(updatedResult, 35);

      // Mutating 'b' pushes dirty invalidation
      b.data = 25;
      expect(invalidationCount, 2);
      expect(terminal.evaluate(), 40);

      terminal.deactivate();
    });

    test('3. RawViaTerminal dynamic branching and 1-pass epoch sweeping', () {
      final condition = WhatController(true);
      final a = WhatController('Branch A');
      final b = WhatController('Branch B');
      var invalidationCount = 0;

      final terminal = RawViaTerminal(
        (via) => via(condition.what) ? via(a.what) : via(b.what),
        onInvalidated: () => invalidationCount++,
      );

      terminal.activate();

      // 3.1 Initial evaluation: condition is true -> only condition and 'a' should be observed
      expect(terminal.evaluate(), 'Branch A');
      expect(invalidationCount, 0);

      // Mutating 'b' should NOT trigger invalidation because 'b' was never observed!
      b.data = 'Branch B Modified';
      expect(invalidationCount, 0);

      // Mutating 'a' DOES trigger invalidation
      a.data = 'Branch A 2';
      expect(invalidationCount, 1);
      expect(terminal.evaluate(), 'Branch A 2');

      // 3.2 Flip condition to false: next evaluation should drop 'a' and bind 'b'
      condition.data = false;
      expect(invalidationCount, 2);

      expect(terminal.evaluate(), 'Branch B Modified');

      // 3.3 Epoch sweep verification: 'a' was swept and detached!
      // Mutating 'a' should NO LONGER trigger invalidation!
      a.data = 'Branch A 3';
      expect(invalidationCount, 2); // Count must remain 2!

      // Mutating 'b' DOES trigger invalidation!
      b.data = 'Branch B Fresh';
      expect(invalidationCount, 3);
      expect(terminal.evaluate(), 'Branch B Fresh');

      terminal.deactivate();
    });

    test('4. Pure dependency registration via track(node)', () {
      final trigger = WhatController(0);
      var invalidationCount = 0;

      final terminal = RawViaTerminal(
        (via) {
          via(trigger.what);
          return 'Static Result';
        },
        onInvalidated: () => invalidationCount++,
      );

      terminal.activate();
      expect(terminal.evaluate(), 'Static Result');
      expect(invalidationCount, 0);

      // Trigger mutation invalidates terminal even though payload wasn't read
      trigger.data = 1;
      expect(invalidationCount, 1);

      terminal.deactivate();
    });

    test('5. Zero-Overhead: Direct read without via(...) is not tracked', () {
      final a = WhatController(100);
      final b = WhatController(200);
      var invalidationCount = 0;

      final terminal = RawViaTerminal(
        (via) {
          // Explicitly track 'a', but read 'b' directly without via()
          final trackedA = via(a.what);
          final untrackedB = b.data; // Unwrapped read!
          return trackedA + untrackedB;
        },
        onInvalidated: () => invalidationCount++,
      );

      terminal.activate();
      expect(terminal.evaluate(), 300);
      expect(invalidationCount, 0);

      // Mutating unwrapped 'b' does NOT invalidate terminal
      b.data = 999;
      expect(invalidationCount, 0);

      // Mutating tracked 'a' DOES invalidate terminal
      a.data = 150;
      expect(invalidationCount, 1);

      // Re-evaluation pulls fresh b directly
      expect(terminal.evaluate(), 1149);

      terminal.deactivate();
    });

    test('6. Cycle Guard: Self-referential loop throws LpdagCycleError', () {
      late final RawViaTerminal<int> terminal;
      terminal = RawViaTerminal<int>(
        (via) {
          return terminal.evaluate(); // Self cycle!
        },
        onInvalidated: () {},
      );

      terminal.activate();
      expect(() => terminal.evaluate(), throwsA(isA<LpdagCycleError>()));
      terminal.deactivate();
    });

    test('7. Exception Transactional Resilience: Edges are preserved on error and awake upon upstream change', () {
      final a = WhatController(1);
      final b = WhatController(10);
      var invalidationCount = 0;

      final terminal = RawViaTerminal(
        (via) {
          final valA = via(a.what);
          if (valA < 0) {
            throw StateError('Negative value in a!');
          }
          final valB = via(b.what);
          return valA + valB;
        },
        onInvalidated: () => invalidationCount++,
      );

      terminal.activate();

      // 7.1 Initial evaluation is clean
      expect(terminal.evaluate(), 11);
      expect(invalidationCount, 0);

      // 7.2 Cause an exception during evaluation
      a.data = -5;
      expect(invalidationCount, 1);
      expect(() => terminal.evaluate(), throwsStateError);

      // 7.3 CRITICAL: Even though evaluation failed before reading 'b' in this epoch,
      // 'b' MUST NOT be swept/detached!
      // Mutating 'b' MUST trigger invalidation and wake up the terminal!
      b.data = 20;
      expect(invalidationCount, 2);

      // 7.4 Recover from error by setting 'a' to positive
      a.data = 5;
      expect(invalidationCount, 3);
      expect(terminal.evaluate(), 25); // 5 + 20

      terminal.deactivate();
    });

    test('8. Cursor-Accelerated Sequential Tracking with Many Sources & Dynamic Order Retention', () {
      final controllers = List.generate(50, (i) => WhatController(i));
      var invalidationCount = 0;

      final terminal = RawViaTerminal(
        (via) {
          var sum = 0;
          for (final c in controllers) {
            sum += via(c.what);
          }
          return sum;
        },
        onInvalidated: () => invalidationCount++,
      );

      terminal.activate();

      // 8.1 First evaluation: adds all 50 edges in sequential order
      final initialSum = terminal.evaluate();
      expect(initialSum, 1225); // sum(0..49) = 49*50/2 = 1225
      expect(invalidationCount, 0);

      // 8.2 Second evaluation: hit cursor fast-path for all 50 nodes without re-allocation
      controllers[25].data = 100; // change middle element (+75)
      expect(invalidationCount, 1);
      expect(terminal.evaluate(), 1300);

      // 8.3 Multiple successive cursor-aligned evaluations
      controllers[0].data = 10;
      controllers[49].data = 50;
      expect(terminal.evaluate(), 1311);

      terminal.deactivate();
    });

    test('9. _pullVersion Invariant: Lazy computed dependencies synchronize pulledVersion in _endEpoch', () {
      final source = WhatController(10);
      var computedRunCount = 0;

      // Lazy computed node whose version starts at 0 and increments upon pull
      final lazyComputed = computed((via) {
        computedRunCount++;
        return via(source.what) * 2;
      });

      var terminalInvalidations = 0;
      final terminal = RawViaTerminal(
        (via) => via(lazyComputed) + 5,
        onInvalidated: () => terminalInvalidations++,
      );

      terminal.activate();

      // Prior to evaluation, lazyComputed has not been pulled yet
      expect(computedRunCount, 0);

      // Evaluate terminal:
      // During evaluation, via(lazyComputed) is registered before lazyComputed.data resolves.
      // _endEpoch MUST pull latest versions so terminal's edge tracks lazyComputed's resolved version.
      final result = terminal.evaluate();
      expect(result, 25); // (10 * 2) + 5
      expect(computedRunCount, 1);
      expect(terminalInvalidations, 0);

      // Now mutate source
      source.data = 20;
      expect(terminalInvalidations, 1);

      // Re-evaluation pulls updated lazyComputed
      expect(terminal.evaluate(), 45); // (20 * 2) + 5
      expect(computedRunCount, 2);

      terminal.deactivate();
    });

    test('10. _pullVersion Invariant: Distinct Short-Circuit execution drop under RawComputedTerminal', () {
      final user = WhatController((name: 'Alice', age: 20));
      var distinctComputeCount = 0;

      // Derived distinct name: only increments version if 'name' actually changes
      final distinctName = computed((via) {
        distinctComputeCount++;
        return via(user.what).name;
      }).distinct();

      var terminalComputeCount = 0;
      var terminalInvalidations = 0;

      final terminal = RawComputedTerminal(
        (via) {
          terminalComputeCount++;
          return 'User: ${via(distinctName)}';
        },
        onInvalidated: () => terminalInvalidations++,
      );

      terminal.activate();

      // Initial read: computes both distinctName and terminal
      expect(terminal.data, 'User: Alice');
      expect(distinctComputeCount, 1);
      expect(terminalComputeCount, 1);
      expect(terminalInvalidations, 0);

      // Mutate 'user' with the SAME name, but different age.
      // 1. Push phase: marks downstream check/invalidated.
      user.data = (name: 'Alice', age: 21);
      expect(terminalInvalidations, 1);

      // 2. Lazy-Pull phase:
      // terminal._resolveDirty() checks upstream. distinctName re-evaluates, finds name unchanged,
      // and does NOT bump its version.
      // CRITICAL: If terminal's edge _pulledVersion was NOT properly updated via _pullVersion(),
      // terminal._isSourceDirty would erroneously return true and force an unnecessary recompute!
      expect(terminal.data, 'User: Alice');
      expect(distinctComputeCount, 2);
      expect(terminalComputeCount, 1, reason: 'Terminal computation MUST be dropped via distinct short-circuit!');

      // Now mutate 'user' with a DIFFERENT name
      user.data = (name: 'Bob', age: 22);
      expect(terminalInvalidations, 2);

      expect(terminal.data, 'User: Bob');
      expect(distinctComputeCount, 3);
      expect(terminalComputeCount, 2, reason: 'Terminal computation MUST run when distinct value changed.');

      terminal.deactivate();
    });

    test('11. _pullVersion Invariant: Dynamic branch swap synchronizes pulledVersion on newly mounted edges', () {
      final branch = WhatController(true);
      final a = WhatController('A0');
      final b = WhatController('B0');

      var aComputeCount = 0;
      final compA = computed((via) {
        aComputeCount++;
        return via(a.what);
      }).distinct();

      var bComputeCount = 0;
      final compB = computed((via) {
        bComputeCount++;
        return via(b.what);
      }).distinct();

      var terminalComputeCount = 0;
      final terminal = RawComputedTerminal(
        (via) {
          terminalComputeCount++;
          return via(branch.what) ? via(compA) : via(compB);
        },
        onInvalidated: () {},
      );

      terminal.activate();

      // Branch A initial
      expect(terminal.data, 'A0');
      expect(terminalComputeCount, 1);
      expect(aComputeCount, 1);
      expect(bComputeCount, 0);

      // Swap to Branch B
      branch.data = false;
      expect(terminal.data, 'B0');
      expect(terminalComputeCount, 2);
      expect(bComputeCount, 1);

      // Mutate unobserved branch A -> terminal must NOT recompute
      a.data = 'A1';
      expect(terminal.data, 'B0');
      expect(terminalComputeCount, 2);

      // Mutate observed branch B with same value via distinct -> terminal must drop recompute
      // If _pullVersion was missed for newly mounted edge B, this would fail!
      b.data = 'B0'; // No distinct change
      expect(terminal.data, 'B0');
      expect(terminalComputeCount, 2, reason: 'Short-circuit must drop recompute on newly mounted branch edge');

      terminal.deactivate();
    });

    test('12. _pullVersion Exception Guard: Failed evaluation does NOT advance pulledVersion on unvisited edges', () {
      final trigger = WhatController(1);
      final errorTrigger = WhatController(false);
      var invalidationCount = 0;

      final terminal = RawViaTerminal(
        (via) {
          if (via(errorTrigger.what)) {
            throw FormatException('Simulated evaluation failure');
          }
          return via(trigger.what) * 10;
        },
        onInvalidated: () => invalidationCount++,
      );

      terminal.activate();
      expect(terminal.evaluate(), 10);
      expect(invalidationCount, 0);

      // Cause failure
      errorTrigger.data = true;
      expect(invalidationCount, 1);
      expect(() => terminal.evaluate(), throwsFormatException);

      // While in error, mutating trigger must STILL invalidate and wake terminal
      // because edges were preserved without advancing to invalid state
      trigger.data = 2;
      expect(invalidationCount, 2);

      // Recover
      errorTrigger.data = false;
      expect(invalidationCount, 3);
      expect(terminal.evaluate(), 20);

      terminal.deactivate();
    });

    test('13. _pullVersion Invariant: Effect distinct short-circuit drops scheduled execution', () async {
      final user = WhatController((name: 'Alice', age: 20));
      var distinctComputeCount = 0;

      final distinctName = computed((via) {
        distinctComputeCount++;
        return via(user.what).name;
      }).distinct();

      var effectRuns = 0;
      final effect = Effect.via((via) {
        effectRuns++;
        via(distinctName);
      });

      final host = RawViaTerminal(
        (via) => via.tether(effect),
        onInvalidated: () {},
      )
        ..activate()
        ..evaluate();

      await Future<void>.delayed(Duration.zero);

      // Initial execution
      expect(effectRuns, 1);
      expect(distinctComputeCount, 1);

      // Mutate 'user' with the same name, but different age
      user.data = (name: 'Alice', age: 25);
      await Future.microtask(() {});

      // Effect must NOT re-run because distinctName did not bump version,
      // and terminal's pulledVersion was synchronized via _endEpoch._pullVersion()!
      expect(distinctComputeCount, 2);
      expect(
        effectRuns,
        1,
        reason: 'Effect execution MUST be dropped when upstream distinct version did not advance',
      );

      // Mutate with different name -> Effect MUST re-run
      user.data = (name: 'Bob', age: 25);
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(distinctComputeCount, 3);

      host.deactivate();
    });

    test('14. Duplicate reads of the same source in one evaluation remain correct across re-evaluations', () {
      final a = WhatController('Hello');
      final b = WhatController('World');
      final c = WhatController('!');

      final terminal = RawViaTerminal(
        (via) {
          // 'a' is read multiple times in a single evaluation
          final first = via(a.what);
          final second = via(b.what);
          final duplicate = via(a.what); // Read 'a' again
          final third = via(c.what);
          return '$first $second $duplicate $third';
        },
        onInvalidated: () {},
      );

      terminal.activate();
      expect(terminal.evaluate(), 'Hello World Hello !');

      // Subsequent evaluation with mutation
      b.data = 'Antigravity';
      expect(terminal.evaluate(), 'Hello Antigravity Hello !');

      c.data = '?';
      expect(terminal.evaluate(), 'Hello Antigravity Hello ?');

      terminal.deactivate();
    });

    test('15. _pullVersion Invariant: Effect.handledVia distinct short-circuit drops scheduled execution', () async {
      final user = WhatController((name: 'Alice', age: 20));
      final distinctName = computed((via) => via(user.what).name).distinct();

      var effectRuns = 0;
      final effect = Effect.handledVia((via, handle) {
        effectRuns++;
        via(distinctName);
      });

      final host = RawViaTerminal(
        (via) => via.tether(effect),
        onInvalidated: () {},
      )
        ..activate()
        ..evaluate();

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);

      // Same name: distinct version unchanged -> handled effect MUST NOT re-run.
      user.data = (name: 'Alice', age: 25);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1, reason: 'Handled effect must commit versions after a successful run');

      // Different name -> MUST re-run.
      user.data = (name: 'Bob', age: 25);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 2);

      host.deactivate();
    });

    test('16. _trackDependency self-healing order realignment and dynamic insertion before cursor', () {
      final a = WhatController('A');
      final b = WhatController('B');
      final c = WhatController('C');
      final order = WhatController(['A', 'B', 'C']);

      var invalidations = 0;
      final terminal = RawViaTerminal(
        (via) {
          final keys = via(order.what);
          final buffer = StringBuffer();
          for (final key in keys) {
            if (key == 'A') buffer.write(via(a.what));
            if (key == 'B') buffer.write(via(b.what));
            if (key == 'C') buffer.write(via(c.what));
          }
          return buffer.toString();
        },
        onInvalidated: () => invalidations++,
      );

      terminal.activate();

      // Epoch 1: Initial order [A, B, C]
      expect(terminal.evaluate(), 'ABC');
      expect(invalidations, 0);

      // Epoch 2: Inverted order [C, B, A] -> triggers _moveSourceEdgeBefore to realign list
      order.data = ['C', 'B', 'A'];
      expect(invalidations, 1);
      expect(terminal.evaluate(), 'CBA');

      // Epoch 3: Stable inverted order [C, B, A] -> should hit O(1) sequential fast-path smoothly
      c.data = 'C2';
      expect(invalidations, 2);
      expect(terminal.evaluate(), 'C2BA');

      // Epoch 4: Shuffled order [B, A, C]
      order.data = ['B', 'A', 'C'];
      expect(invalidations, 3);
      expect(terminal.evaluate(), 'BAC2');

      // Epoch 5: Dynamic insertion in the middle [B, new D, A, C]
      final d = WhatController('D');
      order.data = ['B', 'D', 'A', 'C'];
      expect(invalidations, 4);

      var dInvalidations = 0;
      final terminal2 = RawViaTerminal(
        (via) {
          final keys = via(order.what);
          final buffer = StringBuffer();
          for (final key in keys) {
            if (key == 'A') buffer.write(via(a.what));
            if (key == 'B') buffer.write(via(b.what));
            if (key == 'C') buffer.write(via(c.what));
            if (key == 'D') buffer.write(via(d.what));
          }
          return buffer.toString();
        },
        onInvalidated: () => dInvalidations++,
      )..activate();

      expect(terminal2.evaluate(), 'BDAC2');

      // Mutating newly inserted node D triggers invalidation
      d.data = 'D2';
      expect(dInvalidations, 1);
      expect(terminal2.evaluate(), 'BD2AC2');

      terminal.deactivate();
      terminal2.deactivate();
    });

    test('17. _trackDependency re-read with interleaved order retains integrity', () {
      final a = WhatController(1);
      final b = WhatController(2);
      final c = WhatController(3);

      final terminal = RawViaTerminal(
        (via) {
          // Re-reads interleaved with out-of-order dependencies
          final r1 = via(c.what);
          final r2 = via(a.what);
          final r3 = via(c.what); // Re-read c
          final r4 = via(b.what);
          final r5 = via(a.what); // Re-read a
          return '$r1,$r2,$r3,$r4,$r5';
        },
        onInvalidated: () {},
      );

      terminal.activate();
      expect(terminal.evaluate(), '3,1,3,2,1');

      // Mutate each dependency and verify proper propagation
      a.data = 10;
      expect(terminal.evaluate(), '3,10,3,2,10');

      b.data = 20;
      expect(terminal.evaluate(), '3,10,3,20,10');

      c.data = 30;
      expect(terminal.evaluate(), '30,10,30,20,10');

      terminal.deactivate();
    });
  });
}

final class _DirectTestVia implements WhatVia {
  _DirectTestVia({required this.onCall});

  final What<dynamic> Function(What<dynamic> what) onCall;

  @override
  T call<T>(What<T> what) {
    onCall(what);
    return untracked(what);
  }

  @override
  WhatState<T> state<T>(What<T> what) {
    onCall(what);
    return untracked.state(what);
  }

  @override
  T tether<T extends Tether>(T tether) => tether;
}
