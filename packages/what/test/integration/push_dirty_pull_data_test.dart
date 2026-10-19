// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('Push-Dirty & Lazy Pull-Data Integration Suite', () {
    // =========================================================================
    // 1. Push-Dirty Invalidation & Delayed Pull-Data Computation
    // =========================================================================
    group('1. Push-Dirty (O(1)) & Lazy Pull-Data Core Model', () {
      test('1.1 Dirty Notification triggers UI updates without computing data', () {
        int computationCount = 0;
        int dirtyCount = 0;

        final source = WhatController<int>(0);
        final cascaded = computed((via) {
          computationCount++;
          return via(source.what);
        });

        final terminal = RawWhatTerminal(cascaded, onInvalidated: () {
          dirtyCount++;
        });
        terminal.activate();

        expect(terminal.snapshot.dataOrNull, 0);
        expect(computationCount, 1);
        expect(dirtyCount, 0);

        // Update source multiple times
        source.set(1);
        source.set(2);
        source.set(3);

        expect(computationCount, 1, reason: 'Data computation must be delayed until .snapshot is called');
        expect(dirtyCount, 1, reason: 'Bursty mutations coalesce into a single dirty pulse before pull (Q1: A)');

        // Now pull data
        expect(terminal.snapshot.dataOrNull, 3);
        expect(computationCount, 2, reason: 'Only the final pull triggers computation');

        // Subsequent mutation after pull triggers a new dirty notification
        source.set(4);
        expect(dirtyCount, 2, reason: 'New mutation after pull triggers another dirty pulse');
        expect(terminal.snapshot.dataOrNull, 4);
        expect(computationCount, 3);

        terminal.deactivate();
      });

      test('1.2 Memoization (Caching): Repeated pulls without source changes return cached data', () {
        int computationCount = 0;

        final source = WhatController<int>(0);
        final cascaded = computed((via) {
          computationCount++;
          return via(source.what) * 2;
        });

        final terminal = RawWhatTerminal(cascaded, onInvalidated: () {});
        terminal.activate();

        expect(terminal.snapshot.dataOrNull, 0);
        expect(computationCount, 1);

        expect(terminal.snapshot.dataOrNull, 0);
        expect(terminal.snapshot.dataOrNull, 0);
        expect(computationCount, 1, reason: 'Repeated pulls without dirty signal must use cached snapshot');

        terminal.deactivate();
      });

      test('1.3 Bursty Mutation Coalescing maintains O(1) lazy computation', () {
        int computationCount = 0;
        int dirtyCount = 0;

        final source = WhatController<int>(0);
        final cascaded = computed((via) {
          computationCount++;
          return via(source.what) * 10;
        });

        final terminal = RawWhatTerminal(cascaded, onInvalidated: () {
          dirtyCount++;
        });
        terminal.activate();

        expect(terminal.snapshot.dataOrNull, 0);
        expect(computationCount, 1);
        expect(dirtyCount, 0);

        // Execute 1,000 rapid synchronous updates
        for (int i = 1; i <= 1000; i++) {
          source.set(i);
        }

        expect(dirtyCount, 1, reason: '1,000 rapid mutations coalesce into a single dirty pulse before pull (Q1: A)');
        expect(computationCount, 1);

        // Pull final value
        expect(terminal.snapshot.dataOrNull, 10000);
        expect(computationCount, 2, reason: 'Computation must occur exactly once on pull (O(1))');

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 2. Multi-Path Wave Collapsing & Short-Circuiting
    // =========================================================================
    group('2. Multi-Path Wave Collapsing & Short-Circuiting', () {
      test('2.1 Dirty Notification Wave Collapsing across multi-path upstream topology', () {
        final source = WhatController<int>(10);
        int dirtyCount = 0;

        final diverged = computed((via) {
          final val = via(source.what);
          return [
            What.constant(val * 2),
            What.constant(val + 5),
          ];
        });

        final converged = computed((via) {
          final list = via(diverged);
          return via(list[0]) + via(list[1]);
        });

        final terminal = RawWhatTerminal(converged, onInvalidated: () {
          dirtyCount++;
        });
        terminal.activate();

        expect(terminal.data, 35); // 20 + 15 = 35
        expect(dirtyCount, 0);

        source.set(20);

        expect(dirtyCount, 1, reason: 'Dirty notifications from multiple upstream paths should collapse');

        terminal.deactivate();
      });

      test('2.2 Dynamic short-circuit computation prevents computation of unread branches', () {
        final conditionController = WhatController<bool>(true);
        final branchAController = WhatController<int>(10);
        final branchBController = WhatController<int>(20);

        int branchAComputeCalls = 0;
        int branchBComputeCalls = 0;

        final branchA = computed((via) {
          branchAComputeCalls++;
          return via(branchAController.what) * 2;
        });

        final branchB = computed((via) {
          branchBComputeCalls++;
          return via(branchBController.what) * 3;
        });

        final conditionalPipeline = switched((via) {
          return via(conditionController.what) ? branchA : branchB;
        }, eager: false);

        final terminal = RawWhatTerminal(conditionalPipeline, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 20); // 10 * 2
        expect(branchAComputeCalls, 1);
        expect(branchBComputeCalls, 0);

        branchBController.set(999);

        expect(terminal.data, 20);
        expect(branchBComputeCalls, 0, reason: 'Unread branchB should short-circuit and not compute');

        conditionController.set(false);

        expect(terminal.data, 2997); // 999 * 3
        expect(branchBComputeCalls, 1);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. Exact Version Invariants (debugVersion)
    // =========================================================================
    group('3. Exact Version Invariants (debugVersion)', () {
      test('3.1 Inactive mutation increments version and preserves it upon activation without duplicate flush', () {
        final controller = WhatController<int>(10);
        expect(controller.what.debugVersion, 0);

        controller.set(20);
        expect(controller.what.debugVersion, 1);

        final terminal = RawWhatTerminal<int>(controller.what, onInvalidated: () {});
        terminal.activate();

        expect(controller.what.debugVersion, 1);

        terminal.deactivate();
      });

      test('3.2 Multiple inactive mutations increment version accurately and preserve upon activation', () {
        final controller = WhatController<int>(10);
        expect(controller.what.debugVersion, 0);

        controller.set(20);
        controller.set(30);
        controller.set(40);
        expect(controller.what.debugVersion, 3);

        final terminal = RawWhatTerminal<int>(controller.what, onInvalidated: () {});
        terminal.activate();

        expect(controller.what.debugVersion, 3);

        terminal.deactivate();
      });

      test('3.3 Deactivate -> Inactive Mutate -> Reactivate cycle preserves exact version', () {
        final controller = WhatController<String>('A');
        final terminal = RawWhatTerminal<String>(controller.what, onInvalidated: () {});

        terminal.activate();
        expect(controller.what.debugVersion, 0);

        terminal.deactivate();
        expect(controller.isActive, isFalse);

        controller.set('B');
        expect(controller.what.debugVersion, 1);

        terminal.activate();
        expect(controller.what.debugVersion, 1);

        terminal.deactivate();
      });
    });
  });
}
