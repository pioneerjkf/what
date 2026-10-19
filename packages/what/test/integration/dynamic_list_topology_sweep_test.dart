// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:what/what.dart';

import '../test_utils.dart';

class _TestWorkerResource {
  _TestWorkerResource(this.id, this.itemsSum, {this.label = ''});

  final int id;
  int itemsSum;
  String label;
  bool isDisposed = false;

  void dispose() {
    isDisposed = true;
  }
}

void main() {
  group('What<List<What<T>>> Dynamic Topology, Edge Registration, Dirty & Sweep Tests', () {
    // =========================================================================
    // 1. computed: Dynamic Collection Watching, Edge Registration & Sweep
    // =========================================================================
    group('1. computed with dynamic What<List<What<T>>>', () {
      test('1.1 Dynamic insertion, removal & sweep: detached items do not pulse dirty', () {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);
        final w4 = WhatController<int>(40);

        final listController = WhatListController<What<int>>([w1.what, w2.what]);

        // downstream computed watching both the list and each inner what
        final sumComputed = computed((via) {
          final list = via(listController.what);
          int sum = 0;
          for (final item in list) {
            sum += via(item);
          }
          return sum;
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(sumComputed, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // 1. Initial State: w1(10) + w2(20) = 30
        expect(terminal.data, 30);
        expect(dirtyCount, 0);

        // 2. Mutate active w1: dirty received & value updated
        w1.set(15);
        expect(dirtyCount, 1);
        expect(terminal.data, 35); // 15 + 20

        // 3. Dynamic Insertion: append w3 (30)
        listController.set([w1.what, w2.what, w3.what]);
        expect(dirtyCount, 2);
        expect(terminal.data, 65); // 15 + 20 + 30

        // 4. Verify Edge Registration for new item w3
        w3.set(35);
        expect(dirtyCount, 3);
        expect(terminal.data, 70); // 15 + 20 + 35

        // 5. Dynamic Removal & Sweep: [w1, w2, w3] -> [w2, w3, w4] (w1 removed, w4 added)
        listController.set([w2.what, w3.what, w4.what]);
        expect(dirtyCount, 4);
        expect(terminal.data, 95); // 20 + 35 + 40

        // Reset dirty counter for clear isolation
        dirtyCount = 0;

        // 6. SWEEP VERIFICATION: Detached w1 MUST NOT trigger dirty pulses anymore!
        w1.set(999);
        expect(dirtyCount, 0, reason: 'Detached w1 must be swept from dependency DAG');
        expect(terminal.data, 95, reason: 'Terminal data remains untouched by swept node');

        // 7. Retained items (w2, w3) still trigger dirty pulses
        w2.set(25);
        expect(dirtyCount, 1);
        expect(terminal.data, 100); // 25 + 35 + 40

        // 8. Newly added item (w4) triggers dirty pulse
        w4.set(50);
        expect(dirtyCount, 2);
        expect(terminal.data, 110); // 25 + 35 + 50

        terminal.deactivate();
      });

      test('1.2 Order permutation & duplicate avoidance maintains cursor-aligned edges', () {
        final w1 = WhatController<int>(1);
        final w2 = WhatController<int>(2);
        final w3 = WhatController<int>(3);

        final listController = WhatListController<What<int>>([w1.what, w2.what, w3.what]);

        final formulaComputed = computed((via) {
          final list = via(listController.what);
          // String formula: e.g. "1-2-3"
          return list.map((node) => via(node).toString()).join('-');
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(formulaComputed, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, '1-2-3');
        expect(dirtyCount, 0);

        // Reorder list: [w3, w1, w2]
        listController.set([w3.what, w1.what, w2.what]);
        expect(dirtyCount, 1);
        expect(terminal.data, '3-1-2');

        // Mutate reordered nodes
        w3.set(30);
        expect(dirtyCount, 2);
        expect(terminal.data, '30-1-2');

        w1.set(10);
        expect(dirtyCount, 3);
        expect(terminal.data, '30-10-2');

        terminal.deactivate();
      });

      test('1.3 Emptying list sweeps all inner edges; repopulating re-binds cleanly', () {
        final w1 = WhatController<int>(100);
        final w2 = WhatController<int>(200);

        final listController = WhatListController<What<int>>([w1.what, w2.what]);

        final sumComputed = computed((via) {
          final list = via(listController.what);
          return list.fold<int>(0, (acc, item) => acc + via(item));
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(sumComputed, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 300);

        // Empty the list completely
        listController.set([]);
        expect(dirtyCount, 1);
        expect(terminal.data, 0);

        // Mutating previously registered items: both must be completely swept
        w1.set(999);
        w2.set(888);
        expect(dirtyCount, 1, reason: 'All previous inner edges were swept when list was emptied');
        expect(terminal.data, 0);

        // Repopulate with brand new items
        final w3 = WhatController<int>(5);
        final w4 = WhatController<int>(15);
        listController.set([w3.what, w4.what]);
        expect(dirtyCount, 2);
        expect(terminal.data, 20);

        // Verify w3 and w4 are actively listened
        w3.set(10);
        expect(dirtyCount, 3);
        expect(terminal.data, 25);

        terminal.deactivate();
      });

      test('1.4 Multi-cycle pseudo-random churn with active vs evicted edge validation', () {
        final pool = List.generate(8, (i) => WhatController<int>((i + 1) * 10));

        final listController = WhatListController<What<int>>([pool[0].what, pool[1].what, pool[2].what]);

        final sumComputed = computed((via) {
          final list = via(listController.what);
          return list.fold<int>(0, (acc, item) => acc + via(item));
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(sumComputed, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // Run sequential topology transformations
        final steps = <List<int>>[
          [1, 3, 5, 7], // Swap out [0, 2], swap in [3, 5, 7]
          [0, 1, 2], // Swap back
          [4], // Shrink to single item
          [0, 1, 2, 3, 4, 5, 6, 7], // Expand to all items
          [], // Empty
          [6, 2], // Sub-array
        ];

        for (final activeIndices in steps) {
          final activeSet = activeIndices.toSet();
          final nextList = activeIndices.map((i) => pool[i].what).toList();
          listController.set(nextList);

          // Expected sum
          final expectedSum = activeIndices.fold<int>(0, (acc, i) => acc + pool[i].data);
          expect(terminal.data, expectedSum);

          final checkpointDirty = dirtyCount;

          // 1. Mutate an evicted node (if any exists) -> must not increment dirtyCount
          final evictedIndex = List.generate(8, (i) => i).firstWhere(
            (i) => !activeSet.contains(i),
            orElse: () => -1,
          );
          if (evictedIndex != -1) {
            pool[evictedIndex].set(pool[evictedIndex].data + 1);
            expect(dirtyCount, checkpointDirty, reason: 'Evicted node $evictedIndex must not pulse dirty');
          }

          // 2. Mutate an active node (if any exists) -> must increment dirtyCount
          if (activeIndices.isNotEmpty) {
            final targetActive = activeIndices.first;
            pool[targetActive].set(pool[targetActive].data + 5);
            expect(dirtyCount, checkpointDirty + 1, reason: 'Active node $targetActive must pulse dirty');
            // Pull updated data
            expect(terminal.data, expectedSum + 5);
          }
        }

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 2. switched: Dynamic Collection Branching, Edge Registration & Sweep
    // =========================================================================
    group('2. switched with dynamic What<List<What<T>>>', () {
      test('2.1 Switching between two dynamic What node lists sweeps all previous branch inner nodes', () {
        final mode = WhatController<bool>(true);

        final listA1 = WhatController<int>(10);
        final listA2 = WhatController<int>(20);
        final listControllerA = WhatListController<What<int>>([listA1.what, listA2.what]);

        final listB1 = WhatController<int>(100);
        final listB2 = WhatController<int>(200);
        final listB3 = WhatController<int>(300);
        final listControllerB = WhatListController<What<int>>([listB1.what, listB2.what, listB3.what]);

        final switchedPipeline = switched<int>((via) {
          final isA = via(mode.what);
          final targetList = isA ? via(listControllerA.what) : via(listControllerB.what);

          int sum = 0;
          for (final item in targetList) {
            sum += via(item);
          }
          return What.constant(sum);
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(switchedPipeline, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // 1. Initial Mode A: 10 + 20 = 30
        expect(terminal.data, 30);
        expect(dirtyCount, 0);

        // Mutating listA1 pulses dirty
        listA1.set(15);
        expect(dirtyCount, 1);
        expect(terminal.data, 35);

        // Mutating unselected branch B items has zero effect
        listB1.set(999);
        listControllerB.set([listB1.what]);
        expect(dirtyCount, 1, reason: 'Branch B is not watched');
        expect(terminal.data, 35);

        // 2. Switch to Mode B: 999
        mode.set(false);
        expect(dirtyCount, 2);
        expect(terminal.data, 999);

        // Reset dirty counter
        dirtyCount = 0;

        // 3. SWEEP VERIFICATION: All items in List A (listA1, listA2) and listControllerA are swept!
        listA1.set(500);
        listA2.set(600);
        listControllerA.set([listA1.what, listA2.what, What.constant(700)]);
        expect(dirtyCount, 0, reason: 'List A and all its elements were completely swept upon switch');
        expect(terminal.data, 999);

        // 4. Modifying branch B dynamically registers and updates
        listControllerB.set([listB1.what, listB2.what]);
        expect(dirtyCount, 1);
        expect(terminal.data, 1199); // 999 + 200

        listB2.set(250);
        expect(dirtyCount, 2);
        expect(terminal.data, 1249); // 999 + 250

        terminal.deactivate();
      });

      test('2.2 switched indexing into dynamic What<List<What<T>>> with out-of-bounds containment', () {
        final indexController = WhatController<int>(0);
        final w0 = WhatController<String>('Zero');
        final w1 = WhatController<String>('One');
        final w2 = WhatController<String>('Two');

        final listController = WhatListController<What<String>>([w0.what, w1.what, w2.what]);
        final fallback = WhatController<String>('FALLBACK');

        final dynamicItemSwitched = switched<String>((via) {
          final list = via(listController.what);
          final idx = via(indexController.what);

          if (idx < 0 || idx >= list.length) {
            return fallback.what;
          }
          return list[idx];
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(dynamicItemSwitched, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // 1. Initial index 0 -> w0
        expect(terminal.data, 'Zero');

        // Mutating active w0 triggers dirty
        w0.set('Zero-v2');
        expect(dirtyCount, 1);
        expect(terminal.data, 'Zero-v2');

        // Mutating inactive w1 triggers zero dirty
        w1.set('One-v2');
        expect(dirtyCount, 1);

        // 2. Change index: 0 -> 1 -> selects w1
        indexController.set(1);
        expect(dirtyCount, 2);
        expect(terminal.data, 'One-v2');

        // w0 is now swept!
        w0.set('Zero-v3');
        expect(dirtyCount, 2, reason: 'w0 is no longer active in switched branch');

        // 3. Shrink list such that index 1 becomes out-of-bounds -> fallback
        listController.set([w0.what]);
        expect(dirtyCount, 3);
        expect(terminal.data, 'FALLBACK');

        // Mutating fallback works
        fallback.set('FALLBACK-UPDATED');
        expect(dirtyCount, 4);
        expect(terminal.data, 'FALLBACK-UPDATED');

        // Mutating w1 (which was the previously selected index) triggers zero dirty
        w1.set('One-v3');
        expect(dirtyCount, 4, reason: 'w1 is completely detached');

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. managed: Dynamic Collection Resource Lifecycle, Update & Sweep
    // =========================================================================
    group('3. managed with dynamic What<List<What<T>>>', () {
      test('3.1 Resource update vs dispose/create when What list items change dynamically', () {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);

        final listController = WhatListController<What<int>>([w1.what, w2.what]);

        int createCount = 0;
        int updateCount = 0;
        int disposeCount = 0;
        final disposedResources = <_TestWorkerResource>[];

        final managedWorker = managed<_TestWorkerResource>(
          create: (via) {
            createCount++;
            final list = via(listController.what);
            int sum = 0;
            for (final item in list) {
              sum += via(item);
            }
            return _TestWorkerResource(createCount, sum, label: 'initial');
          },
          update: (via, current) {
            updateCount++;
            final list = via(listController.what);
            int sum = 0;
            for (final item in list) {
              sum += via(item);
            }
            current.itemsSum = sum;
            current.label = 'updated_$updateCount';
            return current; // Reuse identical instance
          },
          dispose: (worker) {
            disposeCount++;
            worker.dispose();
            disposedResources.add(worker);
          },
        );

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(managedWorker, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // 1. Initial lazy allocation on pull
        final res1 = terminal.data;
        expect(createCount, 1);
        expect(updateCount, 0);
        expect(disposeCount, 0);
        expect(res1.itemsSum, 30); // 10 + 20
        expect(dirtyCount, 0);

        // 2. Mutate active w1: update callback is invoked, resource is reused
        w1.set(15);
        expect(dirtyCount, 1);

        final res1AfterUpdate = terminal.data;
        expect(identical(res1, res1AfterUpdate), isTrue, reason: 'Resource reused via update');
        expect(updateCount, 1);
        expect(createCount, 1);
        expect(disposeCount, 0);
        expect(res1AfterUpdate.itemsSum, 35); // 15 + 20

        // 3. Dynamic Expansion: add w3 (30)
        listController.set([w1.what, w2.what, w3.what]);
        expect(dirtyCount, 2);

        final res1AfterExpansion = terminal.data;
        expect(identical(res1, res1AfterExpansion), isTrue);
        expect(updateCount, 2);
        expect(res1AfterExpansion.itemsSum, 65); // 15 + 20 + 30

        // Mutating newly added w3 triggers update
        w3.set(40);
        expect(dirtyCount, 3);
        expect(terminal.data.itemsSum, 75); // 15 + 20 + 40
        expect(updateCount, 3);

        // 4. Dynamic Removal & Sweep: remove w1 -> [w2, w3]
        listController.set([w2.what, w3.what]);
        expect(dirtyCount, 4);
        expect(terminal.data.itemsSum, 60); // 20 + 40
        expect(updateCount, 4);

        // SWEEP VERIFICATION: Detached w1 MUST NOT trigger dirty pulse or update resource!
        w1.set(999);
        expect(dirtyCount, 4, reason: 'w1 was swept from managed dependency DAG');
        expect(updateCount, 4, reason: 'update must not be called when swept w1 is mutated');
        expect(terminal.data.itemsSum, 60);

        // 5. Deactivation cleans up resource cleanly
        terminal.deactivate();
        expect(disposeCount, 1);
        expect(disposedResources.length, 1);
        expect(identical(disposedResources.first, res1), isTrue);
        expect(res1.isDisposed, isTrue);
      });

      test('3.2 Re-creation semantics under dynamic collection list clearing', () {
        final w1 = WhatController<int>(5);
        final w2 = WhatController<int>(10);
        final listController = WhatListController<What<int>>([w1.what, w2.what]);

        int createCount = 0;
        int disposeCount = 0;

        // managed without update callback -> always disposes old and creates new on change
        final managedWorker = managed<_TestWorkerResource>(
          create: (via) {
            createCount++;
            final list = via(listController.what);
            int sum = 0;
            for (final item in list) {
              sum += via(item);
            }
            return _TestWorkerResource(createCount, sum);
          },
          dispose: (res) {
            disposeCount++;
            res.dispose();
          },
        );

        final terminal = RawWhatTerminal(managedWorker, onInvalidated: () {});
        terminal.activate();

        final r1 = terminal.data;
        expect(createCount, 1);
        expect(disposeCount, 0);
        expect(r1.itemsSum, 15);

        // Empty list -> recreates resource with sum 0
        listController.set([]);
        final r2 = terminal.data;
        expect(createCount, 2);
        expect(disposeCount, 1);
        expect(r1.isDisposed, isTrue);
        expect(r2.itemsSum, 0);

        // Mutating old items (w1, w2): must not cause any recreation
        w1.set(100);
        w2.set(200);
        expect(createCount, 2, reason: 'No recreation because w1 and w2 were swept');
        expect(disposeCount, 1);

        terminal.deactivate();
        expect(disposeCount, 2);
        expect(r2.isDisposed, isTrue);
      });
    });

    // =========================================================================
    // 4. Heterogeneous Multi-Primitive Pipeline (computed + switched + managed)
    // =========================================================================
    group('4. Unified Heterogeneous Pipeline & Batch Churn', () {
      test('4.1 Unified Pipeline: listController -> computed -> switched -> managed', () {
        final c1 = WhatController<int>(10);
        final c2 = WhatController<int>(20);
        final c3 = WhatController<int>(30);
        final listController = WhatListController<What<int>>([c1.what, c2.what]);

        // 1. computed aggregates dynamic list
        final listSum = computed((via) {
          final list = via(listController.what);
          return list.fold<int>(0, (sum, node) => sum + via(node));
        });

        // 2. switched switches between listSum and a scalar threshold
        final useSum = WhatController<bool>(true);
        final threshold = WhatController<int>(1000);

        final switchedVal = switched<int>((via) {
          return via(useSum.what) ? listSum : threshold.what;
        });

        // 3. managed wraps the value in a worker
        int managedDisposeCount = 0;
        final managedWorker = managed<_TestWorkerResource>(
          create: (via) => _TestWorkerResource(1, via(switchedVal)),
          update: (via, current) {
            current.itemsSum = via(switchedVal);
            return current;
          },
          dispose: (res) {
            managedDisposeCount++;
            res.dispose();
          },
        );

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(managedWorker, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data.itemsSum, 30); // 10 + 20
        expect(dirtyCount, 0);

        // Rapid atomic batch: list change + leaf node change simultaneously
        batch(() {
          listController.set([c2.what, c3.what]); // c1 removed, c3 added
          c2.set(25);
          c3.set(35);
        });

        // Exactly 1 coalesced dirty notification during batch!
        expect(dirtyCount, 1);
        expect(terminal.data.itemsSum, 60); // 25 + 35

        // Swept c1 must not affect pipeline
        c1.set(999);
        expect(dirtyCount, 1);
        expect(terminal.data.itemsSum, 60);

        // Switch to threshold
        useSum.set(false);
        expect(dirtyCount, 2);
        expect(terminal.data.itemsSum, 1000);

        // While in threshold mode, list changes and c2, c3 changes must be completely ignored
        listController.set([c1.what]);
        c2.set(100);
        c3.set(200);
        expect(dirtyCount, 2, reason: 'Entire computed sub-DAG is swept while switched is in threshold mode');
        expect(terminal.data.itemsSum, 1000);

        // Switch back to list
        useSum.set(true);
        expect(dirtyCount, 3);
        expect(terminal.data.itemsSum, 999); // listController currently contains [c1], whose value is 999!

        terminal.deactivate();
        expect(managedDisposeCount, 1);
      });
    });

    // =========================================================================
    // 5. Asynchronous & Temporal Dynamics (Effect, Microtask Coalescing, Future, Delayed Turns)
    // =========================================================================
    group('5. Asynchronous & Temporal Dynamics with dynamic What<List<What<T>>>', () {
      test('5.1 computed + effect across asynchronous microtask turns: dirty coalescing and sweep', () async {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);
        final listController = WhatListController<What<int>>([w1.what, w2.what]);

        final sumComputed = computed((via) {
          final list = via(listController.what);
          return list.fold<int>(0, (acc, item) => acc + via(item));
        });

        final effectLogs = <int>[];
        final disposeEffect = effect((via) {
          effectLogs.add(via(sumComputed));
        });

        // Initial effect execution on microtask loop
        await Future<void>.delayed(Duration.zero);
        expect(effectLogs, [30]); // 10 + 20

        // 1. Multiple mutations within the same turn are coalesced into a single effect execution
        w1.set(15);
        listController.set([w1.what, w2.what, w3.what]); // w3 added (30)
        w3.set(40);

        await Future<void>.delayed(Duration.zero);
        expect(effectLogs, [30, 75]); // 15 + 20 + 40 = 75

        // 2. Next turn: remove w1 from list
        listController.set([w2.what, w3.what]);
        await Future<void>.delayed(Duration.zero);
        expect(effectLogs, [30, 75, 60]); // 20 + 40 = 60

        // 3. Across delayed turns: mutate swept w1
        w1.set(999);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(effectLogs, [30, 75, 60], reason: 'Effect must not re-run when swept w1 is mutated');

        // 4. Mutate active w2
        w2.set(25);
        await Future<void>.delayed(Duration.zero);
        expect(effectLogs, [30, 75, 60, 65]); // 25 + 40 = 65

        disposeEffect();
      });

      test('5.2 switched + delayed async turns: obsolete branch elements are permanently swept across turns', () async {
        final branch = WhatController<bool>(true);

        final a1 = WhatController<int>(1);
        final a2 = WhatController<int>(2);
        final listA = WhatListController<What<int>>([a1.what, a2.what]);

        final b1 = WhatController<int>(100);
        final b2 = WhatController<int>(200);
        final listB = WhatListController<What<int>>([b1.what, b2.what]);

        final activeBranchSum = switched<int>((via) {
          final isA = via(branch.what);
          final activeList = isA ? via(listA.what) : via(listB.what);
          return What.constant(activeList.fold<int>(0, (sum, item) => sum + via(item)));
        });

        final logs = <int>[];
        final dispose = effect((via) {
          logs.add(via(activeBranchSum));
        });

        await Future<void>.delayed(Duration.zero);
        expect(logs, [3]); // 1 + 2

        // Switch to Branch B
        branch.set(false);
        await Future<void>.delayed(Duration.zero);
        expect(logs, [3, 300]); // 100 + 200

        // Multiple async turns with delayed intervals modifying Branch A
        for (int i = 0; i < 3; i++) {
          a1.set(a1.data + 10);
          a2.set(a2.data + 10);
          listA.set([a1.what, a2.what, What.constant(i)]);
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }

        // Branch A mutations must be completely swept and silent
        expect(logs, [3, 300]);

        // Branch B mutation triggers update
        b1.set(150);
        await Future<void>.delayed(Duration.zero);
        expect(logs, [3, 300, 350]); // 150 + 200

        dispose();
      });

      test('5.3 managed + delayed async mutations: resource updates on delayed ticks without reacting to swept items',
          () async {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);
        final listController = WhatListController<What<int>>([w1.what, w2.what]);

        int updateCalls = 0;
        final managedWorker = managed<_TestWorkerResource>(
          create: (via) {
            final list = via(listController.what);
            return _TestWorkerResource(1, list.fold(0, (sum, i) => sum + via(i)));
          },
          update: (via, current) {
            updateCalls++;
            final list = via(listController.what);
            current.itemsSum = list.fold(0, (sum, i) => sum + via(i));
            return current;
          },
          dispose: (res) => res.dispose(),
        );

        final terminal = RawWhatTerminal(managedWorker, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data.itemsSum, 30);
        expect(updateCalls, 0);

        // Turn 1: Add w3
        await Future<void>.delayed(const Duration(milliseconds: 2));
        listController.set([w1.what, w2.what, w3.what]);
        expect(terminal.data.itemsSum, 60);
        expect(updateCalls, 1);

        // Turn 2: Remove w1
        await Future<void>.delayed(const Duration(milliseconds: 2));
        listController.set([w2.what, w3.what]);
        expect(terminal.data.itemsSum, 50);
        expect(updateCalls, 2);

        // Turn 3: Asynchronously mutate swept w1 over multiple delayed turns
        for (int i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          w1.set(100 + i);
        }
        // Reading terminal data must NOT invoke updateCalls nor change itemsSum
        expect(terminal.data.itemsSum, 50);
        expect(updateCalls, 2, reason: 'Swept w1 mutation must never trigger managed update');

        // Turn 4: Asynchronously mutate active w2
        await Future<void>.delayed(const Duration(milliseconds: 2));
        w2.set(25);
        expect(terminal.data.itemsSum, 55);
        expect(updateCalls, 3);

        terminal.deactivate();
      });

      test('5.4 computed.future dynamic resolution: downstream binds inner Whats asynchronously and sweeps', () async {
        final wA = WhatController<int>(10);
        final wB = WhatController<int>(20);
        final wC = WhatController<int>(30);

        final query = WhatController<String>('pair1');

        // Async computed that fetches / constructs a List<What<int>> based on query
        final asyncListWhat = computed.future<List<What<int>>>((via) async {
          final q = via(query.what);
          await Future<void>.delayed(const Duration(milliseconds: 5));
          if (q == 'pair1') {
            return [wA.what, wB.what];
          } else {
            return [wB.what, wC.what];
          }
        });

        // Downstream computed watching the resolved asyncList and summing inner items
        final derivedSum = computed((via) {
          final state = via.state(asyncListWhat);
          if (!state.hasData) return -1;
          final list = state.data;
          return list.fold<int>(0, (sum, item) => sum + via(item));
        });

        final observedSums = <int>[];
        final dispose = effect((via) {
          observedSums.add(via(derivedSum));
        });

        // Initial empty state (-1)
        await Future<void>.delayed(Duration.zero);
        expect(observedSums, [-1]);

        // Wait for asyncListWhat to resolve 'pair1' ([wA, wB])
        await Future<void>.delayed(const Duration(milliseconds: 25));
        expect(observedSums.last, 30); // 10 + 20

        // Mutate wA -> updates derivedSum
        wA.set(15);
        await Future<void>.delayed(Duration.zero);
        expect(observedSums.last, 35); // 15 + 20

        // Change query to 'pair2' ([wB, wC])
        query.set('pair2');
        await Future<void>.delayed(const Duration(milliseconds: 25));
        expect(observedSums.last, 50); // 20 + 30

        // wA is now swept from the active dependency graph!
        wA.set(999);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(observedSums.last, 50, reason: 'wA was swept when async list changed to pair2');

        // Mutate active wC
        wC.set(35);
        await Future<void>.delayed(Duration.zero);
        expect(observedSums.last, 55); // 20 + 35

        dispose();
      });

      test('5.5 Concurrent async mutations under Future.wait: DAG converges to strictly active nodes', () async {
        final pool = List.generate(5, (i) => WhatController<int>(i * 10)); // [0, 10, 20, 30, 40]
        final listController = WhatListController<What<int>>([pool[0].what, pool[1].what]);

        final sumComputed = computed((via) {
          final list = via(listController.what);
          return list.fold<int>(0, (acc, item) => acc + via(item));
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(sumComputed, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 10); // 0 + 10

        // Run concurrent asynchronous tasks
        await Future.wait([
          Future(() async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            // Change list membership to [pool[2], pool[3], pool[4]]
            listController.set([pool[2].what, pool[3].what, pool[4].what]);
          }),
          Future(() async {
            await Future<void>.delayed(const Duration(milliseconds: 2));
            // Mutate evicted pool[0]
            pool[0].set(999);
          }),
          Future(() async {
            await Future<void>.delayed(const Duration(milliseconds: 8));
            // Mutate active pool[3]
            pool[3].set(35);
          }),
        ]);

        // Pull final resolved state: pool[2](20) + pool[3](35) + pool[4](40) = 95
        expect(terminal.data, 95);

        final dirtyAfterConcurrent = dirtyCount;

        // Evicted pool[0] and pool[1] mutations must be completely silent
        pool[0].set(1000);
        pool[1].set(2000);
        expect(dirtyCount, dirtyAfterConcurrent, reason: 'Evicted nodes must be swept');
        expect(terminal.data, 95);

        // Active node mutation must trigger dirty
        pool[4].set(45);
        expect(dirtyCount, dirtyAfterConcurrent + 1);
        expect(terminal.data, 100); // 20 + 35 + 45

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 6. Tri-State FSM (Valid, Empty, Error) in Dynamic Collections
    // =========================================================================
    group('6. Tri-State FSM (Valid, Empty, Error) & Error Containment', () {
      test('6.1 Inner What cycling Valid -> Empty -> Error -> Valid with graceful via.state fallback', () {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);
        final listController = WhatListController<What<int>>([w1.what, w2.what, w3.what]);

        // Resilient computed aggregator handling valid, empty, and error gracefully
        final resilientSum = computed<int>((via) {
          final list = via(listController.what);
          int total = 0;
          for (final item in list) {
            final s = via.state(item);
            if (s.hasData) {
              total += s.data;
            } else if (s.isEmpty) {
              total += 0; // Empty treated as 0
            } else if (s.hasError) {
              total -= 100; // Error treated as -100 penalty
            }
          }
          return total;
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(resilientSum, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // 1. Initial All Valid: 10 + 20 + 30 = 60
        expect(terminal.data, 60);
        expect(dirtyCount, 0);

        // 2. Transition w1 to Empty
        w1.empty();
        expect(dirtyCount, 1);
        expect(terminal.data, 50); // 0 + 20 + 30

        // 3. Transition w1 to Error
        w1.setError('Disk I/O Error');
        expect(dirtyCount, 2);
        expect(terminal.data, -50); // -100 + 20 + 30

        // 4. Recover w1 to Valid (15)
        w1.set(15);
        expect(dirtyCount, 3);
        expect(terminal.data, 65); // 15 + 20 + 30

        // 5. Remove w1 from list: [w2, w3]
        listController.set([w2.what, w3.what]);
        expect(dirtyCount, 4);
        expect(terminal.data, 50); // 20 + 30

        // 6. SWEEP VERIFICATION: Mutating detached w1 between Error and Empty must produce zero dirty pulses!
        w1.setError('Ignored Detached Error');
        expect(dirtyCount, 4, reason: 'Detached w1 in error state must not pulse dirty');
        expect(terminal.data, 50);

        w1.empty();
        expect(dirtyCount, 4, reason: 'Detached w1 in empty state must not pulse dirty');
        expect(terminal.data, 50);

        w1.set(999);
        expect(dirtyCount, 4, reason: 'Detached w1 in valid state must not pulse dirty');
        expect(terminal.data, 50);

        terminal.deactivate();
      });

      test(
          '6.2 Direct via(item) on Error inner node: upstream computed transitions to Error and auto-recovers on eviction',
          () {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);
        final listController = WhatListController<What<int>>([w1.what, w2.what, w3.what]);

        final unhandledSum = computed<int>((via) {
          final list = via(listController.what);
          int sum = 0;
          for (final item in list) {
            sum += via(item); // Throws if item hasError or isEmpty
          }
          return sum;
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(unhandledSum, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.snapshot.hasData, isTrue);
        expect(terminal.data, 60);

        // Put w2 into error -> downstream unhandledSum transitions to Error state
        w2.setError('Critical Network Timeout');
        expect(dirtyCount, 1);
        expect(terminal.snapshot.hasError, isTrue);
        expect(terminal.snapshot.error, 'Critical Network Timeout');

        // Evict failing w2 from list: [w1, w3]
        listController.set([w1.what, w3.what]);
        expect(dirtyCount, 2);

        // Auto-recovers to valid state immediately upon eviction!
        expect(terminal.snapshot.hasData, isTrue);
        expect(terminal.data, 40); // 10 + 30

        // Swept failing w2 continues to error without leaking to downstream
        w2.setError('Secondary Crash');
        expect(dirtyCount, 2, reason: 'Swept error node must never pulse dirty downstream');
        expect(terminal.snapshot.hasData, isTrue);

        terminal.deactivate();
      });

      test('6.3 Outer WhatListController itself transitioning Valid -> Empty -> Error -> Valid', () {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final listController = WhatListController<What<int>>([w1.what, w2.what]);

        final downstream = computed<String>((via) {
          final state = via.state(listController.what);
          return state.match(
            data: (list) => 'DATA:${list.map((e) => via(e)).join(',')}',
            empty: () => 'LIST_EMPTY',
            error: (err, _) => 'LIST_ERROR:$err',
          );
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(downstream, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 'DATA:10,20');

        // 1. Outer list becomes empty
        listController.empty();
        expect(dirtyCount, 1);
        expect(terminal.data, 'LIST_EMPTY');

        // While list is empty, inner items are swept
        w1.set(100);
        expect(dirtyCount, 1, reason: 'Inner items swept while outer list is empty');

        // 2. Outer list enters error
        listController.setError('Repository offline');
        expect(dirtyCount, 2);
        expect(terminal.data, 'LIST_ERROR:Repository offline');

        // 3. Outer list recovers with new items
        listController.set([w2.what]);
        expect(dirtyCount, 3);
        expect(terminal.data, 'DATA:20');

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 7. Early Return / Short-Circuiting, Dynamic Branching & Unvisited Sweep
    // =========================================================================
    group('7. Early Return / Short-Circuiting, Dynamic Branching & Unvisited Sweep', () {
      test(
          '7.1 Early return on first Error: loop short-circuits; subsequent nodes unvisited; recovery re-awakens full list',
          () {
        final w0 = WhatController<int>(10);
        final w1 = WhatController<int>(20);
        final w2 = WhatController<int>(30);
        final w3 = WhatController<int>(40);

        final listController = WhatListController<What<int>>([w0.what, w1.what, w2.what, w3.what]);

        final earlyReturnPipeline = computed<String>((via) {
          final list = via(listController.what);
          int sum = 0;
          for (int i = 0; i < list.length; i++) {
            final s = via.state(list[i]);
            if (s.hasError) {
              return 'ERROR_AT_$i:${s.error}'; // Early return!
            }
            if (s.isEmpty) {
              return 'EMPTY_AT_$i'; // Early return!
            }
            sum += s.data;
          }
          return 'FULL_SUM:$sum';
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(earlyReturnPipeline, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // 1. Initial clean evaluation: 10 + 20 + 30 + 40 = 100
        expect(terminal.data, 'FULL_SUM:100');
        expect(dirtyCount, 0);

        // 2. w1 (index 1) enters Error: loop breaks at index 1; w2 and w3 are NOT visited in this epoch
        w1.setError('FAIL_1');
        expect(dirtyCount, 1);
        expect(terminal.data, 'ERROR_AT_1:FAIL_1');

        // 3. Mutating w0 (index 0, before early return) triggers re-evaluation
        w0.set(15);
        expect(dirtyCount, 2);
        expect(terminal.data, 'ERROR_AT_1:FAIL_1');

        // 4. Recover w1 to Valid: early return stops, w2 and w3 are visited again!
        w1.set(25);
        expect(dirtyCount, 3);
        expect(terminal.data, 'FULL_SUM:110'); // 15 + 25 + 30 + 40

        // 5. w2 (index 2) enters Empty: loop breaks at index 2; w3 is unvisited
        w2.empty();
        expect(dirtyCount, 4);
        expect(terminal.data, 'EMPTY_AT_2');

        // 6. Evict w2 from list: [w0, w1, w3] -> early return removed, full sum computed
        listController.set([w0.what, w1.what, w3.what]);
        expect(dirtyCount, 5);
        expect(terminal.data, 'FULL_SUM:80'); // 15 + 25 + 40

        // Swept w2 mutating in error produces zero dirty pulses
        w2.setError('Detached error');
        expect(dirtyCount, 5, reason: 'Detached w2 is swept');

        terminal.deactivate();
      });

      test('7.2 Dynamic multi-mode branching (strict vs lenient vs first_valid) with heterogeneous node states', () {
        final mode = WhatController<String>('strict');
        final n0 = WhatController<int>(10);
        final n1 = WhatController<int>(20);
        final n2 = WhatController<int>(30);
        final listController = WhatListController<What<int>>([n0.what, n1.what, n2.what]);

        final multiBranchPipeline = computed<String>((via) {
          final list = via(listController.what);
          final currentMode = via(mode.what);

          switch (currentMode) {
            case 'strict':
              int total = 0;
              for (final item in list) {
                final s = via.state(item);
                if (s.hasError) return 'STRICT:ERROR';
                if (s.isEmpty) return 'STRICT:EMPTY';
                total += s.data;
              }
              return 'STRICT:OK:$total';

            case 'lenient':
              int total = 0;
              int validCount = 0;
              for (final item in list) {
                final s = via.state(item);
                if (s.hasData) {
                  total += s.data;
                  validCount++;
                }
              }
              return 'LENIENT:COUNT:$validCount:SUM:$total';

            case 'first_valid':
              for (final item in list) {
                final s = via.state(item);
                if (s.hasData) return 'FIRST:${s.data}';
              }
              return 'FIRST:NONE';

            default:
              return 'UNKNOWN';
          }
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(multiBranchPipeline, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // 1. Strict mode with all valid: OK:60
        expect(terminal.data, 'STRICT:OK:60');

        // n1 becomes Empty -> strict mode returns STRICT:EMPTY
        n1.empty();
        expect(dirtyCount, 1);
        expect(terminal.data, 'STRICT:EMPTY');

        // Switch to lenient mode -> skips empty n1, sums n0(10) + n2(30) = 40
        mode.set('lenient');
        expect(dirtyCount, 2);
        expect(terminal.data, 'LENIENT:COUNT:2:SUM:40');

        // n2 becomes Error -> lenient mode skips error, keeps n0(10)
        n2.setError('n2 corrupted');
        expect(dirtyCount, 3);
        expect(terminal.data, 'LENIENT:COUNT:1:SUM:10');

        // Switch to first_valid mode -> returns n0(10)
        mode.set('first_valid');
        expect(dirtyCount, 4);
        expect(terminal.data, 'FIRST:10');

        // n0 becomes Empty -> first_valid skips n0, finds n1(empty), n2(error) -> FIRST:NONE
        n0.empty();
        expect(dirtyCount, 5);
        expect(terminal.data, 'FIRST:NONE');

        // Recover n2 to 99 -> FIRST:99
        n2.set(99);
        expect(dirtyCount, 6);
        expect(terminal.data, 'FIRST:99');

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 8. Combinatorial Permutation Matrix ($3^3 = 27$ States Churn)
    // =========================================================================
    group('8. Combinatorial Permutation Matrix (Valid, Empty, Error) x Topology Churn', () {
      test('8.1 Exhaustive 27-state matrix of 3 nodes under dynamic membership & sweep', () {
        final cA = WhatController<int>(1);
        final cB = WhatController<int>(2);
        final cC = WhatController<int>(3);
        final controllers = [cA, cB, cC];

        final listController = WhatListController<What<int>>([cA.what, cB.what]);

        // Downstream computed leniently sums active valid nodes and formats counts
        final matrixComputed = computed<(int sum, int validCount, int errorCount, int emptyCount)>((via) {
          final list = via(listController.what);
          int sum = 0;
          int valids = 0;
          int errors = 0;
          int empties = 0;

          for (final item in list) {
            final s = via.state(item);
            if (s.hasData) {
              valids++;
              sum += s.data;
            } else if (s.hasError) {
              errors++;
            } else if (s.isEmpty) {
              empties++;
            }
          }
          return (sum, valids, errors, empties);
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(matrixComputed, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // 3 states for each controller: 0 = Valid, 1 = Empty, 2 = Error
        // 27 combinations = 3^3
        for (int stateA = 0; stateA < 3; stateA++) {
          for (int stateB = 0; stateB < 3; stateB++) {
            for (int stateC = 0; stateC < 3; stateC++) {
              final states = [stateA, stateB, stateC];

              // Apply states to controllers
              for (int i = 0; i < 3; i++) {
                final ctrl = controllers[i];
                final st = states[i];
                if (st == 0) {
                  ctrl.set((i + 1) * 10);
                } else if (st == 1) {
                  ctrl.empty();
                } else {
                  ctrl.setError('Err_$i');
                }
              }

              // Topology shift based on iteration:
              // Even sum -> active = [cA, cB]
              // Odd sum  -> active = [cB, cC]
              final sumStates = stateA + stateB + stateC;
              final isEven = sumStates % 2 == 0;
              final activeIndices = isEven ? [0, 1] : [1, 2];
              final evictedIndex = isEven ? 2 : 0;

              listController.set(activeIndices.map((idx) => controllers[idx].what).toList());

              // Verify computed output matches expected active nodes
              final result = terminal.data;

              int expectedSum = 0;
              int expectedValids = 0;
              int expectedErrors = 0;
              int expectedEmpties = 0;

              for (final idx in activeIndices) {
                final st = states[idx];
                if (st == 0) {
                  expectedValids++;
                  expectedSum += (idx + 1) * 10;
                } else if (st == 1) {
                  expectedEmpties++;
                } else {
                  expectedErrors++;
                }
              }

              expect(result.$1, expectedSum);
              expect(result.$2, expectedValids);
              expect(result.$3, expectedErrors);
              expect(result.$4, expectedEmpties);

              // SWEEP INVARIANT at every single combination:
              // Mutate the evicted controller between states -> MUST produce 0 dirty pulses!
              final checkDirty = dirtyCount;
              controllers[evictedIndex].set(9999);
              expect(dirtyCount, checkDirty, reason: 'Evicted controller $evictedIndex must produce 0 dirty pulses');
            }
          }
        }

        terminal.deactivate();
      });
    });
  });
}
