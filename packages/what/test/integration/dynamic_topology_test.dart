// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('Dynamic Topology, Hot-Swapping & Graph Restructuring Integration Tests', () {
    // =========================================================================
    // 1. Dynamic Edge Rerouting & Sub-DAG Hot-Swapping
    // =========================================================================
    group('1. Dynamic Edge Rerouting & Sub-DAG Swapping', () {
      test('1.1 Dynamic pipeline switching via cascading', () {
        final sourceA = WhatController<int>(10);
        final sourceB = WhatController<int>(20);
        final switcher = WhatController<bool>(true);

        final cascade = switched((via) {
          return via(switcher.what) ? sourceA.what : sourceB.what;
        });

        final terminal = RawWhatTerminal(cascade, onInvalidated: () {});
        terminal.activate();

        expect(terminal.snapshot.dataOrNull, 10);

        // Perform hot-swap to sourceB
        switcher.set(false);
        expect(terminal.snapshot.dataOrNull, 20);

        terminal.deactivate();
      });

      test('1.2 Subtree disposal during dynamic cascading switch', () {
        final switcher = WhatController<bool>(true);
        int disposeA = 0;
        int disposeB = 0;

        final cascade = switched((via) {
          if (via(switcher.what)) {
            return managed(
              create: (_) => 1,
              dispose: (_) => disposeA++,
            );
          } else {
            return managed(
              create: (_) => 2,
              dispose: (_) => disposeB++,
            );
          }
        });

        final terminal = RawWhatTerminal(cascade, onInvalidated: () {});
        terminal.activate();

        expect(terminal.snapshot.dataOrNull, 1);
        expect(disposeA, 0);

        // Switch to branch B
        switcher.set(false);

        expect(terminal.snapshot.dataOrNull, 2);
        expect(disposeA, 1);
        expect(disposeB, 0);

        terminal.deactivate();
        expect(disposeB, 1);
      });
    });

    // =========================================================================
    // 2. Dynamic Shape Morphing (Diamond <-> Linear <-> Inverted Star)
    // =========================================================================
    group('2. Dynamic Shape Morphing', () {
      test('2.1 Morphing between Diamond, Linear, and Star shapes', () {
        final shapeMode = WhatController<String>('diamond');
        final root = WhatController<int>(10);

        final morphingWhat = switched((via) {
          switch (via(shapeMode.what)) {
            case 'diamond':
              final left = computed((via) => via(root.what) * 2);
              final right = computed((via) => via(root.what) + 5);
              return computed((via) => via(left) + via(right));
            case 'linear':
              final step1 = computed((via) => via(root.what) + 1);
              return computed((via) => via(step1) * 2);
            case 'star':
              final branches = List.generate(5, (i) => computed((via) => via(root.what) * (i + 1)));
              return What.constant(branches).sum();
            default:
              return root.what;
          }
        });

        final terminal = RawWhatTerminal(morphingWhat, onInvalidated: () {});
        terminal.activate();

        // 1. Diamond: (10 * 2) + (10 + 5) = 35
        expect(terminal.data, 35);

        // 2. Linear: (10 + 1) * 2 = 22
        shapeMode.set('linear');
        expect(terminal.data, 22);

        // 3. Star: 10*(1+2+3+4+5) = 150
        shapeMode.set('star');
        expect(terminal.data, 150);

        // 4. Back to Diamond
        shapeMode.set('diamond');
        root.set(20);
        expect(terminal.data, 65); // (20 * 2) + (20 + 5)

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. Chained Coupler Dynamic Transposition
    // =========================================================================
    group('3. Chained Coupler Permutations', () {
      test('3.1 Chained Coupler dynamic permutations without leaking connections', () {
        final cA = WhatController<int>(1);
        final cB = WhatController<int>(2);
        final cC = WhatController<int>(3);

        final coupler1 = WhatCoupler<int>(cA.what);
        final coupler2 = WhatCoupler<int>(cB.what);

        final converged = What.constant([coupler1.what, coupler2.what]).sum();

        final terminal = RawWhatTerminal(converged, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 3); // 1 + 2

        // Transpose coupler1 to cC
        coupler1.couple(cC.what);
        expect(terminal.data, 5); // 3 + 2

        // Transpose coupler2 to cA
        coupler2.couple(cA.what);
        expect(terminal.data, 4); // 3 + 1

        terminal.deactivate();
      });
    });
  });
}
