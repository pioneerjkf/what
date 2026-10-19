// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('Monte-Carlo Chaos Fuzzing & Multi-Root Concurrency Suite', () {
    // =========================================================================
    // 1. Monte-Carlo Chaos Graph Synthesis (500 Randomized Operations)
    // =========================================================================
    group('1. Monte-Carlo Chaos Graph Synthesis & Continuous Audit', () {
      test('1.1 Randomized Graph Generator & Continuous Invariant Auditor (500 Operations)', () {
        final random = Random(1337);

        // 1. Construct 6 root controllers
        final roots = List.generate(6, (i) => WhatController<int>(i + 1));

        // 2. Construct 4 dynamic couplers
        final couplers = List.generate(4, (i) => WhatCoupler<int>(roots[i].what));

        // 3. Construct 4 computed combinator whats
        final computedList = List.generate(4, (i) {
          final srcA = couplers[i % 4].what;
          final srcB = roots[(i + 2) % 6].what;
          return computed((via) {
            final valA = via.state(srcA).dataOrElse(() => 0);
            final valB = via.state(srcB).dataOrElse(() => 0);
            return (valA + valB) * (i + 1);
          });
        });

        // 4. Construct 4 sink terminals
        final terminals = List.generate(4, (i) => RawWhatTerminal(computedList[i], onInvalidated: () {}));
        for (final t in terminals) {
          t.activate();
        }

        // 5. Run 500 randomized operations
        for (var step = 0; step < 500; step++) {
          final op = random.nextInt(7);

          switch (op) {
            case 0:
              // Mutate random root
              final rootIdx = random.nextInt(6);
              roots[rootIdx].set(random.nextInt(100));
              break;
            case 1:
              // Couple random coupler to another root
              final couplerIdx = random.nextInt(4);
              final targetRoot = roots[random.nextInt(6)];
              couplers[couplerIdx].couple(targetRoot.what);
              break;
            case 2:
              // Decouple and re-couple coupler
              final couplerIdx = random.nextInt(4);
              couplers[couplerIdx].decouple();
              couplers[couplerIdx].couple(roots[couplerIdx].what);
              break;
            case 3:
              // Toggle terminal activation
              final terminalIdx = random.nextInt(4);
              if (terminals[terminalIdx].isActive) {
                terminals[terminalIdx].deactivate();
                terminals[terminalIdx].activate();
              }
              break;
            case 4:
              // Inject error into root
              final rootIdx = random.nextInt(6);
              roots[rootIdx].setError(FormatException('Chaos fault step $step'));
              break;
            case 5:
              // Clear error from root
              final rootIdx = random.nextInt(6);
              roots[rootIdx].set(random.nextInt(50) + 1);
              break;
            case 6:
              // Audit all 4 sink terminals
              for (var i = 0; i < 4; i++) {
                final snapshot = terminals[i].snapshot;
                expect(snapshot.hasData || snapshot.isEmpty || snapshot.hasError, isTrue);
                if (snapshot.hasData) {
                  expect(snapshot.data, isA<int>());
                }
              }
              break;
          }
        }

        // Final healing
        for (var i = 0; i < 6; i++) {
          roots[i].set(10);
        }
        for (var i = 0; i < 4; i++) {
          couplers[i].couple(roots[i].what);
        }
        for (var i = 0; i < 4; i++) {
          expect(terminals[i].data, greaterThan(0));
        }

        for (final t in terminals) {
          t.deactivate();
        }
      });
    });

    // =========================================================================
    // 2. Multi-Root Concurrent Transitions on Converging Mesh DAG
    // =========================================================================
    group('2. Multi-Root Concurrent Transitions', () {
      test('2.1 Multi-Root Concurrent Transitions on Converging Mesh DAG', () {
        final r1 = WhatController<int>(1);
        final r2 = WhatController<int>(2);
        final r3 = WhatController<int>(3);

        final midA = computed((via) => via(r1.what) * 10 + via(r2.what));
        final midB = computed((via) => via(r2.what) * 10 + via(r3.what));

        final sink = computed((via) => via(midA) + via(midB));

        final terminal = RawWhatTerminal(sink, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 35);

        // Mutate all 3 roots synchronously
        r1.set(10);
        r2.set(20);
        r3.set(30);

        expect(terminal.data, 350);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. Temporal Anomaly & Asynchronous Race Sabotage
    // =========================================================================
    group('3. Temporal Anomaly & Async Race Resilience', () {
      test('3.1 Rapid Async Future Emission Race Condition across Terminals', () async {
        final completerA = Completer<int>();
        final completerB = Completer<int>();

        final whatA = completerA.future.toWhat();
        final whatB = completerB.future.toWhat();

        final combined = What.constant(<What<int>>[whatA, whatB]).combine();

        final terminal = RawWhatTerminal(combined, onInvalidated: () {});
        terminal.activate();

        expect(terminal.snapshot.hasData, isFalse);

        // Complete A first
        completerA.complete(100);
        await Future<void>.delayed(Duration.zero);

        expect(terminal.snapshot.hasData, isFalse);

        // Complete B
        completerB.complete(200);
        await Future<void>.delayed(Duration.zero);

        expect(terminal.snapshot.hasData, isTrue);
        expect(terminal.data, [100, 200]);

        terminal.deactivate();
      });
    });
  });
}
