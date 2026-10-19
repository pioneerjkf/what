// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('DAG Glitch-Freedom, Complex Diamond & Mesh Invariants Integration Tests', () {
    // =========================================================================
    // 1. Asymmetrical Diamond Graphs (Glitch-Freedom)
    // =========================================================================
    group('1. Asymmetrical Multi-Path Diamond Graphs', () {
      test('1.1 Asymmetrical 4-Path What List Diamond (Lengths 1, 2, 4, 8) computes once upon pull without glitches',
          () {
        final root = WhatController<int>(1);

        final path1 = computed((via) => via(root.what) * 10);
        final path2Step1 = computed((via) => via(root.what) + 1);
        final path2 = computed((via) => via(path2Step1) * 10);

        What<int> path3 = root.what;
        for (int i = 0; i < 4; i++) {
          final prev = path3;
          path3 = computed((via) => via(prev) + 1);
        }

        What<int> path4 = root.what;
        for (int i = 0; i < 8; i++) {
          final prev = path4;
          path4 = computed((via) => via(prev) + 2);
        }

        final group = What.constant([path1, path2, path3, path4]);
        int aggregateComputeCount = 0;
        final sink = computed((via) {
          aggregateComputeCount++;
          return via(group).fold<int>(0, (sum, g) => sum + via(g));
        });

        int terminalDirtyCount = 0;
        final terminal = RawWhatTerminal(sink, onInvalidated: () {
          terminalDirtyCount++;
        });

        terminal.activate();

        // Initial evaluation: 10 + 20 + 5 + 17 = 52
        expect(terminal.data, 52);
        expect(aggregateComputeCount, 1);
        expect(terminalDirtyCount, 0);

        // Mutate Root -> 10: 100 + 110 + 14 + 26 = 250
        root.set(10);
        expect(terminalDirtyCount, 1);
        expect(terminal.data, 250);
        expect(aggregateComputeCount, 2);

        // Mutate Root -> 100: 1000 + 1010 + 104 + 116 = 2230
        root.set(100);
        expect(terminalDirtyCount, 2);
        expect(terminal.data, 2230);
        expect(aggregateComputeCount, 3);

        terminal.deactivate();
      });

      test('1.2 Asymmetrical Diamond via What.computed with glitch-free evaluation', () {
        final root = WhatController<int>(5);

        final left = computed((via) => via(root.what) * 2);
        final rightStep1 = computed((via) => via(root.what) + 10);
        final right = computed((via) => via(rightStep1) * 3);

        int computedCount = 0;
        final diamondSink = computed((via) {
          computedCount++;
          return via(left) + via(right);
        });

        final terminal = RawWhatTerminal(diamondSink, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 55); // 10 + 45
        expect(computedCount, 1);

        root.set(10);
        expect(terminal.data, 80); // 20 + 60
        expect(computedCount, 2);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 2. Complete Bipartite Mesh DAG (K_4,4 -> K_3)
    // =========================================================================
    group('2. Multi-Source, Multi-Sink Mesh & Lattice Topologies', () {
      test('2.1 N x M Complete Bipartite Mesh DAG with Single Pull Cache Invariant', () {
        final sources = List.generate(4, (i) => WhatController<int>(i + 1)); // 1, 2, 3, 4
        final intermediateEvalCounts = List<int>.filled(4, 0);

        final intermediates = List.generate(4, (j) {
          final jMultiplier = j + 1;
          return computed((via) {
            intermediateEvalCounts[j]++;
            int sum = 0;
            for (int i = 0; i < 4; i++) {
              final val = via(sources[i].what);
              sum += val * (i + 1) * jMultiplier;
            }
            return sum;
          });
        });

        int sink1Computes = 0;
        final sink1 = computed((via) {
          sink1Computes++;
          return intermediates.fold<int>(0, (acc, t) => acc + via(t));
        });

        final term1 = RawWhatTerminal(sink1, onInvalidated: () {});
        term1.activate();

        // Verify initial computation
        expect(term1.snapshot.hasData, isTrue);
        expect(sink1Computes, 1);
        for (int j = 0; j < 4; j++) {
          expect(intermediateEvalCounts[j], 1);
        }

        // Mutate single root source
        sources[0].set(10);
        expect(term1.snapshot.hasData, isTrue);
        expect(sink1Computes, 2);
        for (int j = 0; j < 4; j++) {
          expect(intermediateEvalCounts[j], 2);
        }

        term1.deactivate();
      });
    });

    // =========================================================================
    // 3. Graph Morphology & Degree (Deep Linear Pipelines & Wide Fan-Out)
    // =========================================================================
    group('3. Graph Morphology & Degree Invariants', () {
      test('3.1 Deep Linear Pipeline: lazy evaluation across 12 sequential nodes', () {
        final source = WhatController<int>(1);
        int deepMapCalls = 0;

        What<int> current = source.what;
        for (int i = 0; i < 12; i++) {
          final prev = current;
          current = computed((via) {
            deepMapCalls++;
            return via(prev) + 1;
          });
        }

        final terminal = RawWhatTerminal(current, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 13); // 1 + 12
        expect(deepMapCalls, 12);

        // Cache hit
        expect(terminal.data, 13);
        expect(deepMapCalls, 12);

        source.set(10);
        expect(terminal.data, 22); // 10 + 12
        expect(deepMapCalls, 24);

        terminal.deactivate();
      });

      test('3.2 Wide Fan-out (1:25): single source broadcasting to 25 independent active subscribers', () {
        final source = WhatController<int>(100);
        final dirtyCounts = List<int>.filled(25, 0);
        final terminals = <RawWhatTerminal<int>>[];

        for (int i = 0; i < 25; i++) {
          final idx = i;
          final term = RawWhatTerminal(source.what, onInvalidated: () {
            dirtyCounts[idx]++;
          });
          term.activate();
          terminals.add(term);
        }

        for (int i = 0; i < 25; i++) {
          expect(dirtyCounts[i], 0);
          expect(terminals[i].data, 100);
        }

        source.set(200);

        for (int i = 0; i < 25; i++) {
          expect(dirtyCounts[i], 1);
          expect(terminals[i].data, 200);
        }

        for (final t in terminals) {
          t.deactivate();
        }
      });
    });
  });
}
