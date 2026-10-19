// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

// =============================================================================
// Helper Widgets for Testing
// =============================================================================

base class DynamicListWhatWidget extends WhatWidget {
  DynamicListWhatWidget({
    super.key,
    required this.listWhat,
    this.onBuilt,
  });

  final What<List<What<int>>> listWhat;
  final void Function(int sum, int count)? onBuilt;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final list = via(listWhat);
    int sum = 0;
    for (final item in list) {
      sum += via(item);
    }
    onBuilt?.call(sum, list.length);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text('Sum: $sum, Count: ${list.length}'),
    );
  }
}

base class BranchSwitchingWhatWidget extends WhatWidget {
  BranchSwitchingWhatWidget({
    super.key,
    required this.useBranchA,
    required this.listA,
    required this.listB,
    this.onBuilt,
  });

  final What<bool> useBranchA;
  final What<List<What<int>>> listA;
  final What<List<What<int>>> listB;
  final void Function(int sum)? onBuilt;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final isA = via(useBranchA);
    final activeList = isA ? via(listA) : via(listB);

    int sum = 0;
    for (final item in activeList) {
      sum += via(item);
    }
    onBuilt?.call(sum);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text('BranchSum: $sum'),
    );
  }
}

void main() {
  group(
      'WhatWidget & composed Dynamic What<List<What<T>>> Topology, Edge Registration, Dirty & Sweep Tests',
      () {
    // =========================================================================
    // 1. WhatWidget: Dynamic List Watching, Edge Registration & Sweep
    // =========================================================================
    group('1. WhatWidget with dynamic What<List<What<T>>>', () {
      testWidgets(
          '1.1 Dynamic insertion, removal & sweep: detached items cause zero widget rebuilds',
          (tester) async {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);
        final w4 = WhatController<int>(40);

        final listController =
            WhatListController<What<int>>([w1.what, w2.what]);

        int buildCount = 0;
        int lastSum = -1;

        await tester.pumpWidget(
          DynamicListWhatWidget(
            listWhat: listController.what,
            onBuilt: (sum, count) {
              buildCount++;
              lastSum = sum;
            },
          ),
        );

        // 1. Initial State: w1(10) + w2(20) = 30
        expect(find.text('Sum: 30, Count: 2'), findsOneWidget);
        expect(buildCount, 1);
        expect(lastSum, 30);

        // 2. Mutate active w1: triggers rebuild
        w1.set(15);
        await tester.pump();
        expect(find.text('Sum: 35, Count: 2'), findsOneWidget);
        expect(buildCount, 2);
        expect(lastSum, 35); // 15 + 20

        // 3. Dynamic Insertion: append w3 (30)
        listController.set([w1.what, w2.what, w3.what]);
        await tester.pump();
        expect(find.text('Sum: 65, Count: 3'), findsOneWidget);
        expect(buildCount, 3);
        expect(lastSum, 65); // 15 + 20 + 30

        // 4. Edge Registration verification: mutating new w3 triggers rebuild
        w3.set(35);
        await tester.pump();
        expect(find.text('Sum: 70, Count: 3'), findsOneWidget);
        expect(buildCount, 4);
        expect(lastSum, 70); // 15 + 20 + 35

        // 5. Dynamic Removal & Sweep: [w1, w2, w3] -> [w2, w3, w4] (w1 removed, w4 added)
        listController.set([w2.what, w3.what, w4.what]);
        await tester.pump();
        expect(find.text('Sum: 95, Count: 3'), findsOneWidget);
        expect(buildCount, 5);
        expect(lastSum, 95); // 20 + 35 + 40

        // 6. SWEEP VERIFICATION: Detached w1 MUST NOT trigger any rebuilds!
        w1.set(999);
        await tester.pump();
        expect(buildCount, 5,
            reason:
                'Detached w1 must be completely swept; rebuildCount remains unchanged');
        expect(find.text('Sum: 95, Count: 3'), findsOneWidget);
        expect(lastSum, 95);

        // 7. Retained items (w2, w3) still trigger rebuilds
        w2.set(25);
        await tester.pump();
        expect(find.text('Sum: 100, Count: 3'), findsOneWidget);
        expect(buildCount, 6);
        expect(lastSum, 100); // 25 + 35 + 40

        // 8. Newly added item (w4) triggers rebuild
        w4.set(50);
        await tester.pump();
        expect(find.text('Sum: 110, Count: 3'), findsOneWidget);
        expect(buildCount, 7);
        expect(lastSum, 110); // 25 + 35 + 50
      });

      testWidgets(
          '1.2 Order permutation & list clearing in WhatWidget sweeps all inner edges',
          (tester) async {
        final w1 = WhatController<int>(1);
        final w2 = WhatController<int>(2);
        final w3 = WhatController<int>(3);

        final listController =
            WhatListController<What<int>>([w1.what, w2.what, w3.what]);

        int buildCount = 0;
        await tester.pumpWidget(
          DynamicListWhatWidget(
            listWhat: listController.what,
            onBuilt: (sum, count) => buildCount++,
          ),
        );

        expect(find.text('Sum: 6, Count: 3'), findsOneWidget);
        expect(buildCount, 1);

        // Reorder list: [w3, w1, w2] -> identical elements, new order
        listController.set([w3.what, w1.what, w2.what]);
        await tester.pump();
        expect(find.text('Sum: 6, Count: 3'), findsOneWidget);
        expect(buildCount, 2);

        // Mutate reordered element
        w3.set(30);
        await tester.pump();
        expect(find.text('Sum: 33, Count: 3'), findsOneWidget);
        expect(buildCount, 3);

        // Empty the list completely
        listController.set([]);
        await tester.pump();
        expect(find.text('Sum: 0, Count: 0'), findsOneWidget);
        expect(buildCount, 4);

        // Mutating previously registered items: all must be completely swept
        w1.set(100);
        w2.set(200);
        w3.set(300);
        await tester.pump();
        expect(buildCount, 4,
            reason:
                'All inner items were swept when list was emptied; zero rebuilds');
        expect(find.text('Sum: 0, Count: 0'), findsOneWidget);

        // Repopulate with new items
        final w4 = WhatController<int>(7);
        listController.set([w4.what]);
        await tester.pump();
        expect(find.text('Sum: 7, Count: 1'), findsOneWidget);
        expect(buildCount, 5);

        w4.set(14);
        await tester.pump();
        expect(find.text('Sum: 14, Count: 1'), findsOneWidget);
        expect(buildCount, 6);
      });

      testWidgets(
          '1.3 Branch switching in WhatWidget sweeps all unselected branch items',
          (tester) async {
        final useA = WhatController<bool>(true);

        final a1 = WhatController<int>(10);
        final a2 = WhatController<int>(20);
        final listA = WhatListController<What<int>>([a1.what, a2.what]);

        final b1 = WhatController<int>(100);
        final b2 = WhatController<int>(200);
        final listB = WhatListController<What<int>>([b1.what, b2.what]);

        int buildCount = 0;
        await tester.pumpWidget(
          BranchSwitchingWhatWidget(
            useBranchA: useA.what,
            listA: listA.what,
            listB: listB.what,
            onBuilt: (_) => buildCount++,
          ),
        );

        expect(find.text('BranchSum: 30'), findsOneWidget);
        expect(buildCount, 1);

        // Mutate a1
        a1.set(15);
        await tester.pump();
        expect(find.text('BranchSum: 35'), findsOneWidget);
        expect(buildCount, 2);

        // Mutating unselected branch B items causes zero rebuilds
        b1.set(999);
        await tester.pump();
        expect(buildCount, 2, reason: 'Branch B is unobserved');
        expect(find.text('BranchSum: 35'), findsOneWidget);

        // Switch to Branch B
        useA.set(false);
        await tester.pump();
        expect(find.text('BranchSum: 1199'), findsOneWidget); // 999 + 200
        expect(buildCount, 3);

        // SWEEP VERIFICATION: All items in branch A (a1, a2) and listA are swept!
        a1.set(500);
        a2.set(600);
        listA.set([a1.what, What.constant(700)]);
        await tester.pump();
        expect(buildCount, 3, reason: 'Branch A items were completely swept');
        expect(find.text('BranchSum: 1199'), findsOneWidget);

        // Mutating active branch B items triggers rebuild
        b2.set(250);
        await tester.pump();
        expect(find.text('BranchSum: 1249'), findsOneWidget); // 999 + 250
        expect(buildCount, 4);
      });
    });

    // =========================================================================
    // 2. composed: Top-Level Functor with Dynamic What<List<What<T>>>
    // =========================================================================
    group('2. composed functor with dynamic What<List<What<T>>>', () {
      testWidgets('2.1 Dynamic insertion, removal & sweep in composed functor',
          (tester) async {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);
        final listController =
            WhatListController<What<int>>([w1.what, w2.what]);

        int composedBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed((context, via) {
                composedBuildCount++;
                final list = via(listController.what);
                int sum = 0;
                for (final item in list) {
                  sum += via(item);
                }
                return Text('ComposedSum: $sum, Items: ${list.length}');
              }),
            ),
          ),
        );

        // 1. Initial State: w1(10) + w2(20) = 30
        expect(find.text('ComposedSum: 30, Items: 2'), findsOneWidget);
        expect(composedBuildCount, 1);

        // 2. Mutate active w1
        w1.set(15);
        await tester.pump();
        expect(find.text('ComposedSum: 35, Items: 2'), findsOneWidget);
        expect(composedBuildCount, 2);

        // 3. Dynamic Insertion: append w3 (30)
        listController.set([w1.what, w2.what, w3.what]);
        await tester.pump();
        expect(find.text('ComposedSum: 65, Items: 3'), findsOneWidget);
        expect(composedBuildCount, 3);

        // 4. Edge Registration verification: mutate new w3
        w3.set(40);
        await tester.pump();
        expect(find.text('ComposedSum: 75, Items: 3'), findsOneWidget);
        expect(composedBuildCount, 4);

        // 5. Dynamic Removal & Sweep: remove w1 -> [w2, w3]
        listController.set([w2.what, w3.what]);
        await tester.pump();
        expect(find.text('ComposedSum: 60, Items: 2'), findsOneWidget);
        expect(composedBuildCount, 5);

        // 6. SWEEP VERIFICATION: Detached w1 MUST NOT trigger any rebuild in composed!
        w1.set(999);
        await tester.pump();
        expect(composedBuildCount, 5,
            reason: 'Detached w1 must be swept from composed DAG');
        expect(find.text('ComposedSum: 60, Items: 2'), findsOneWidget);

        // 7. Retained w2 still triggers rebuild
        w2.set(25);
        await tester.pump();
        expect(find.text('ComposedSum: 65, Items: 2'), findsOneWidget);
        expect(composedBuildCount, 6);
      });

      testWidgets(
          '2.2 composed.child isolates static child while dynamic list sweeps inner items',
          (tester) async {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final listController =
            WhatListController<What<int>>([w1.what, w2.what]);

        int composedBuildCount = 0;
        int staticChildBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed.child(
                (context, via, child) {
                  composedBuildCount++;
                  final list = via(listController.what);
                  int sum = 0;
                  for (final item in list) {
                    sum += via(item);
                  }
                  return Column(
                    children: [
                      Text('DynamicSum: $sum'),
                      child,
                    ],
                  );
                },
                child: Builder(
                  builder: (context) {
                    staticChildBuildCount++;
                    return const Text('Static Heavy Child');
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('DynamicSum: 30'), findsOneWidget);
        expect(find.text('Static Heavy Child'), findsOneWidget);
        expect(composedBuildCount, 1);
        expect(staticChildBuildCount, 1);

        // Dynamic change in list
        final w3 = WhatController<int>(30);
        listController.set([w2.what, w3.what]); // w1 removed, w3 added
        await tester.pump();

        expect(find.text('DynamicSum: 50'), findsOneWidget);
        expect(composedBuildCount, 2);
        expect(staticChildBuildCount, 1,
            reason: 'Static child was not rebuilt');

        // Mutating swept w1
        w1.set(999);
        await tester.pump();
        expect(composedBuildCount, 2,
            reason: 'Swept w1 mutation does not rebuild composed');
        expect(staticChildBuildCount, 1);

        // Mutating active w3
        w3.set(50);
        await tester.pump();
        expect(find.text('DynamicSum: 70'), findsOneWidget);
        expect(composedBuildCount, 3);
        expect(staticChildBuildCount, 1);
      });

      testWidgets(
          '2.3 Multi-cycle churn with active vs evicted edge validation in composed',
          (tester) async {
        final pool = List.generate(
            6,
            (i) =>
                WhatController<int>((i + 1) * 10)); // [10, 20, 30, 40, 50, 60]
        final listController =
            WhatListController<What<int>>([pool[0].what, pool[1].what]);

        int buildCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed((context, via) {
                buildCount++;
                final list = via(listController.what);
                int sum = 0;
                for (final item in list) {
                  sum += via(item);
                }
                return Text('Total: $sum');
              }),
            ),
          ),
        );

        expect(find.text('Total: 30'), findsOneWidget); // 10 + 20
        expect(buildCount, 1);

        final testSteps = <List<int>>[
          [1, 2, 4], // [20, 30, 50] = 100
          [0, 5], // [10, 60] = 70
          [], // 0
          [3], // [40] = 40
        ];

        for (final indices in testSteps) {
          final activeSet = indices.toSet();
          listController.set(indices.map((i) => pool[i].what).toList());
          await tester.pump();

          final expectedSum =
              indices.fold<int>(0, (sum, i) => sum + pool[i].data);
          expect(find.text('Total: $expectedSum'), findsOneWidget);

          final checkBuild = buildCount;

          // 1. Mutate evicted item -> must NOT rebuild
          final evicted = List.generate(6, (i) => i).firstWhere(
            (i) => !activeSet.contains(i),
            orElse: () => -1,
          );
          if (evicted != -1) {
            pool[evicted].set(pool[evicted].data + 1);
            await tester.pump();
            expect(buildCount, checkBuild,
                reason: 'Evicted item $evicted must not rebuild widget');
          }

          // 2. Mutate active item -> MUST rebuild
          if (indices.isNotEmpty) {
            final activeTarget = indices.first;
            pool[activeTarget].set(pool[activeTarget].data + 5);
            await tester.pump();
            expect(buildCount, checkBuild + 1,
                reason: 'Active item $activeTarget must rebuild widget');
            expect(find.text('Total: ${expectedSum + 5}'), findsOneWidget);
          }
        }
      });
    });

    // =========================================================================
    // 3. Asynchronous, Batch & Combined Interactions
    // =========================================================================
    group('3. Asynchronous & Batch Operations in WhatWidget and composed', () {
      testWidgets('3.1 Atomic batch mutation coalesces rebuild to single frame',
          (tester) async {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final w3 = WhatController<int>(30);
        final listController =
            WhatListController<What<int>>([w1.what, w2.what]);

        int buildCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed((context, via) {
                buildCount++;
                final list = via(listController.what);
                int sum = 0;
                for (final item in list) {
                  sum += via(item);
                }
                return Text('BatchSum: $sum');
              }),
            ),
          ),
        );

        expect(find.text('BatchSum: 30'), findsOneWidget);
        expect(buildCount, 1);

        // Atomic batch: change topology + leaf nodes together
        batch(() {
          listController.set([w2.what, w3.what]); // w1 removed, w3 added
          w2.set(25);
          w3.set(35);
        });

        // Frame pump
        await tester.pump();
        expect(find.text('BatchSum: 60'), findsOneWidget); // 25 + 35
        expect(buildCount, 2,
            reason: 'Batch coalesced all changes into exactly 1 rebuild pass');

        // Swept w1 mutated inside or outside batch has zero effect
        batch(() {
          w1.set(999);
        });
        await tester.pump();
        expect(buildCount, 2);
        expect(find.text('BatchSum: 60'), findsOneWidget);
      });

      testWidgets('3.2 Delayed asynchronous mutations across pump ticks',
          (tester) async {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final listController =
            WhatListController<What<int>>([w1.what, w2.what]);

        int buildCount = 0;
        await tester.pumpWidget(
          DynamicListWhatWidget(
            listWhat: listController.what,
            onBuilt: (_, __) => buildCount++,
          ),
        );

        expect(find.text('Sum: 30, Count: 2'), findsOneWidget);
        expect(buildCount, 1);

        // Asynchronous delayed tick 1: Add new node w3
        final w3 = WhatController<int>(30);
        await tester.pump(const Duration(milliseconds: 5));
        listController.set([w1.what, w2.what, w3.what]);
        await tester.pump();
        expect(find.text('Sum: 60, Count: 3'), findsOneWidget);
        expect(buildCount, 2);

        // Asynchronous delayed tick 2: Remove w1
        await tester.pump(const Duration(milliseconds: 5));
        listController.set([w2.what, w3.what]);
        await tester.pump();
        expect(find.text('Sum: 50, Count: 2'), findsOneWidget);
        expect(buildCount, 3);

        // Asynchronous delayed tick 3: Mutate swept w1 across multiple delayed turns
        for (int i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 3));
          w1.set(100 * (i + 1));
          await tester.pump();
        }
        // Zero rebuilds across all delayed turns!
        expect(buildCount, 3,
            reason: 'Swept w1 caused zero rebuilds across all delayed turns');
        expect(find.text('Sum: 50, Count: 2'), findsOneWidget);

        // Asynchronous delayed tick 4: Mutate active w3
        await tester.pump(const Duration(milliseconds: 5));
        w3.set(45);
        await tester.pump();
        expect(find.text('Sum: 65, Count: 2'), findsOneWidget); // 20 + 45
        expect(buildCount, 4);
      });
    });

    // =========================================================================
    // 4. Tri-State FSM (Valid, Empty, Error) in WhatWidget and composed
    // =========================================================================
    group('4. Tri-State FSM (Valid, Empty, Error) in WhatWidget & composed',
        () {
      testWidgets(
          '4.1 WhatWidget with via.state pattern matching UI: Empty placeholder & Error banner',
          (tester) async {
        final w1 = WhatController<int>(10);
        final w2 = WhatController<int>(20);
        final listController =
            WhatListController<What<int>>([w1.what, w2.what]);

        int buildCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed((context, via) {
                buildCount++;
                final list = via(listController.what);
                final items = list.map((item) {
                  final s = via.state(item);
                  return s.match(
                    data: (v) => 'DATA:$v',
                    empty: () => 'EMPTY',
                    error: (e, _) => 'ERR:$e',
                  );
                }).join(' | ');
                return Text('ListUI: $items');
              }),
            ),
          ),
        );

        expect(find.text('ListUI: DATA:10 | DATA:20'), findsOneWidget);
        expect(buildCount, 1);

        // w1 becomes Empty
        w1.empty();
        await tester.pump();
        expect(find.text('ListUI: EMPTY | DATA:20'), findsOneWidget);
        expect(buildCount, 2);

        // w1 becomes Error
        w1.setError('Failed connection');
        await tester.pump();
        expect(find.text('ListUI: ERR:Failed connection | DATA:20'),
            findsOneWidget);
        expect(buildCount, 3);

        // w1 recovers to Valid (30)
        w1.set(30);
        await tester.pump();
        expect(find.text('ListUI: DATA:30 | DATA:20'), findsOneWidget);
        expect(buildCount, 4);

        // Evict w1 from list: [w2]
        listController.set([w2.what]);
        await tester.pump();
        expect(find.text('ListUI: DATA:20'), findsOneWidget);
        expect(buildCount, 5);

        // Swept w1 toggling states produces ZERO widget rebuilds!
        w1.setError('Detached Error');
        await tester.pump();
        expect(buildCount, 5,
            reason: 'Swept error item must not rebuild widget');

        w1.empty();
        await tester.pump();
        expect(buildCount, 5,
            reason: 'Swept empty item must not rebuild widget');

        w1.set(999);
        await tester.pump();
        expect(buildCount, 5);
      });

      testWidgets(
          '4.2 WhatWidget early return on first error item: renders error fallback; recovery restores list UI',
          (tester) async {
        final w1 = WhatController<String>('Item1');
        final w2 = WhatController<String>('Item2');
        final w3 = WhatController<String>('Item3');
        final listController =
            WhatListController<What<String>>([w1.what, w2.what, w3.what]);

        int buildCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed((context, via) {
                buildCount++;
                final list = via(listController.what);

                // Early return pattern in UI:
                for (int i = 0; i < list.length; i++) {
                  final s = via.state(list[i]);
                  if (s.hasError) {
                    return Text(
                        'ERROR_AT_$i:${s.error}'); // Early return widget!
                  }
                }

                // If all good:
                final titles = list.map((e) => via(e)).join(', ');
                return Text('SUCCESS: $titles');
              }),
            ),
          ),
        );

        expect(find.text('SUCCESS: Item1, Item2, Item3'), findsOneWidget);
        expect(buildCount, 1);

        // w2 enters Error -> early return widget rendered; w3 unvisited
        w2.setError('E2_FAIL');
        await tester.pump();
        expect(find.text('ERROR_AT_1:E2_FAIL'), findsOneWidget);
        expect(buildCount, 2);

        // Mutating w1 (before early return) updates and triggers rebuild
        w1.set('Item1_v2');
        await tester.pump();
        expect(find.text('ERROR_AT_1:E2_FAIL'), findsOneWidget);
        expect(buildCount, 3);

        // Recover w2 -> early return stops, full list UI restored
        w2.set('Item2_Fixed');
        await tester.pump();
        expect(
            find.text('SUCCESS: Item1_v2, Item2_Fixed, Item3'), findsOneWidget);
        expect(buildCount, 4);

        // Remove w3 and put w3 in error -> verify sweep
        listController.set([w1.what, w2.what]);
        await tester.pump();
        expect(find.text('SUCCESS: Item1_v2, Item2_Fixed'), findsOneWidget);
        expect(buildCount, 5);

        w3.setError('Detached w3 fail');
        await tester.pump();
        expect(buildCount, 5,
            reason:
                'Detached w3 in error must not trigger early return or rebuild');
      });
    });

    // =========================================================================
    // 5. Combinatorial Permutation Matrix & Dynamic Filters in WhatWidget & composed
    // =========================================================================
    group(
        '5. Combinatorial Permutation Matrix (Valid, Empty, Error) x Widget Tree',
        () {
      testWidgets(
          '5.1 Exhaustive 27-state matrix of 3 nodes under composed rendering & sweep',
          (tester) async {
        final cA = WhatController<int>(1);
        final cB = WhatController<int>(2);
        final cC = WhatController<int>(3);
        final controllers = [cA, cB, cC];

        final listController =
            WhatListController<What<int>>([cA.what, cB.what]);

        int buildCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed((context, via) {
                buildCount++;
                final list = via(listController.what);
                int validSum = 0;
                int validCount = 0;
                int errCount = 0;
                int empCount = 0;

                for (final item in list) {
                  final s = via.state(item);
                  if (s.hasData) {
                    validCount++;
                    validSum += s.data;
                  } else if (s.hasError) {
                    errCount++;
                  } else if (s.isEmpty) {
                    empCount++;
                  }
                }
                return Text(
                    'V:$validCount,E:$errCount,M:$empCount,Sum:$validSum');
              }),
            ),
          ),
        );

        expect(find.text('V:2,E:0,M:0,Sum:3'), findsOneWidget); // 1 + 2
        expect(buildCount, 1);

        // 27 state combinations (3^3)
        for (int sA = 0; sA < 3; sA++) {
          for (int sB = 0; sB < 3; sB++) {
            for (int sC = 0; sC < 3; sC++) {
              final stateIndices = [sA, sB, sC];

              // Configure node states
              for (int i = 0; i < 3; i++) {
                final ctrl = controllers[i];
                final st = stateIndices[i];
                if (st == 0) {
                  ctrl.set((i + 1) * 10);
                } else if (st == 1) {
                  ctrl.empty();
                } else {
                  ctrl.setError('E$i');
                }
              }

              // Dynamic active topology
              final isEven = (sA + sB + sC) % 2 == 0;
              final activeIndices = isEven ? [0, 1] : [1, 2];
              final evictedIndex = isEven ? 2 : 0;

              listController.set(
                  activeIndices.map((idx) => controllers[idx].what).toList());
              await tester.pump();

              // Compute expected stats
              int expectedValidCount = 0;
              int expectedErrCount = 0;
              int expectedEmpCount = 0;
              int expectedValidSum = 0;

              for (final idx in activeIndices) {
                final st = stateIndices[idx];
                if (st == 0) {
                  expectedValidCount++;
                  expectedValidSum += (idx + 1) * 10;
                } else if (st == 1) {
                  expectedEmpCount++;
                } else {
                  expectedErrCount++;
                }
              }

              final expectedText =
                  'V:$expectedValidCount,E:$expectedErrCount,M:$expectedEmpCount,Sum:$expectedValidSum';
              expect(find.text(expectedText), findsOneWidget);

              // SWEEP CHECK: Mutating evicted item must cause 0 rebuilds!
              final checkBuild = buildCount;
              controllers[evictedIndex].set(9999);
              await tester.pump();
              expect(buildCount, checkBuild,
                  reason:
                      'Evicted node mutation must not rebuild composed widget');
            }
          }
        }
      });
    });
  });
}
