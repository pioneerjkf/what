// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:what/effect.dart';
import 'package:what/what.dart';

void main() {
  group('Unary-Faced Terminals with N-ary & Diamond Upstream Graph Suites', () {
    test('1. Unary node (distinct) facing Effect with N-ary (computed) upstream', () async {
      final a = WhatController<int>(10);
      final b = WhatController<int>(20);
      final sum = computed<int>((via) => via(a.what) + via(b.what));
      final distinctSum = sum.distinct();

      final captured = <int>[];
      final runner = distinctSum.effect(() {
        captured.add(untracked(distinctSum));
      }).run();

      expect(runner.isActive, isTrue);
      expect(captured, isEmpty, reason: 'Initial run must be skipped');

      // 1. Mutate a: 15 + 20 = 35
      a.data = 15;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [35]);

      // 2. Mutate b: 15 + 25 = 40
      b.data = 25;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [35, 40]);

      // 3. Mutate both to cancel out (distinct drop): 20 + 20 = 40
      a.data = 20;
      b.data = 20;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [35, 40], reason: 'Distinct sum did not change, must drop notification');

      // 4. Mutate to 45
      a.data = 25;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [35, 40, 45]);

      runner.deactivate();
      a.data = 30;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [35, 40, 45], reason: 'Deactivated runner must not capture');
    });

    test('2. Diamond upstream graph feeding Unary node (distinct) facing Effect', () async {
      final root = WhatController<int>(2);
      // Diamond branches
      final branchLeft = computed<int>((via) => via(root.what) * 10);
      final branchRight = computed<int>((via) => via(root.what) * 100);
      // Diamond join
      final join = computed<int>((via) => via(branchLeft) + via(branchRight));
      // Unary wrapper facing effect
      final distinctJoin = join.distinct();

      final captured = <int>[];
      final runner = distinctJoin.effect(() {
        captured.add(untracked(distinctJoin));
      }).run();

      expect(runner.isActive, isTrue);
      expect(captured, isEmpty, reason: 'Initial run skipped');

      // Mutate root: 3 * 10 + 3 * 100 = 330
      root.data = 3;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [330], reason: 'Diamond join must resolve cleanly and effect fire exactly once');

      // Mutate root: 4 * 10 + 4 * 100 = 440
      root.data = 4;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [330, 440]);

      runner.deactivate();
    });

    test('3. Unary nodes inside Diamond branches feeding N-ary join facing Effect', () async {
      final root = WhatController<int>(5);
      // Unary nodes inside branches
      final branchA = root.what.distinct();
      final branchB = root.what.distinct();
      final join = computed<int>((via) => via(branchA) + via(branchB));

      final captured = <int>[];
      final runner = join.effect(() {
        captured.add(untracked(join));
      }).run();

      expect(runner.isActive, isTrue);
      expect(captured, isEmpty);

      root.data = 10;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [20]);

      runner.deactivate();
    });

    test('4. Multi-hop Unary chain (distinct -> debounced) with N-ary upstream', () async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final sum = computed<int>((via) => via(a.what) + via(b.what));
      final distinctSum = sum.distinct();
      final debouncedSum = distinctSum.debounced(const Duration(milliseconds: 30));

      final captured = <int>[];
      final runner = debouncedSum.effect(() {
        captured.add(untracked(debouncedSum));
      }).run();

      expect(runner.isActive, isTrue);
      expect(captured, isEmpty);

      // Mutate
      a.data = 10;
      b.data = 20; // sum = 30
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(captured, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(captured, [30]);

      runner.deactivate();
    });

    test('5. Unary node with N-ary upstream: inactive mutation then activation', () async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final sum = computed<int>((via) => via(a.what) + via(b.what));
      final distinctSum = sum.distinct();

      // Mutate while no effect is connected
      a.data = 5;

      final captured = <int>[];
      final runner = distinctSum.effect(() {
        captured.add(untracked(distinctSum));
      }).run();

      expect(captured, isEmpty, reason: 'Initial run must be skipped even after pre-activation mutation');

      b.data = 10;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [15]);

      runner.deactivate();
    });

    test('6. Uneven Diamond with short direct path and long Unary/N-ary branch', () async {
      final root = WhatController<int>(1);
      // Long branch: root -> computed -> distinct
      final longBranch = computed<int>((via) => via(root.what) * 10).distinct();
      // Join: directly reads root and longBranch
      final join = computed<int>((via) => via(root.what) + via(longBranch));
      final distinctJoin = join.distinct();

      final captured = <int>[];
      final runner = distinctJoin.effect(() {
        captured.add(untracked(distinctJoin));
      }).run();

      expect(captured, isEmpty);

      // Mutate root: 2 + (2 * 10) = 22
      root.data = 2;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [22]);

      // Mutate root: 5 + (5 * 10) = 55
      root.data = 5;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [22, 55]);

      runner.deactivate();
    });

    test('7. Diamond with one distinct branch dropping mutation while other branch updates', () async {
      final root = WhatController<int>(1);
      // Left branch drops even/odd changes: parity
      final parity = computed((via) => via(root.what) % 2).distinct();
      // Right branch scales
      final scaled = computed((via) => via(root.what) * 10);
      // Join
      final join = computed((via) => 'p:${via(parity)}, s:${via(scaled)}');
      final unary = join.distinct();

      final captured = <String>[];
      final runner = unary.effect(() {
        captured.add(untracked(unary));
      }).run();

      expect(captured, isEmpty);

      // 1 -> 3: parity is still 1 (drops on left), scaled is 30 (dirty on right)
      root.data = 3;
      await Future<void>.delayed(Duration.zero);
      expect(captured, ['p:1, s:30']);

      // 3 -> 4: parity is 0 (dirty on left), scaled is 40 (dirty on right)
      root.data = 4;
      await Future<void>.delayed(Duration.zero);
      expect(captured, ['p:1, s:30', 'p:0, s:40']);

      runner.deactivate();
    });

    test('8. Diamond with switched & managed dynamic triad under unary distinct node', () async {
      final useManaged = WhatController<bool>(true);
      final capacity = WhatController<int>(3);
      int managedCreated = 0;
      int managedDisposed = 0;

      final pool = managed<String>(
        create: (via) {
          managedCreated++;
          return 'Pool(${via(capacity.what)})';
        },
        dispose: (_) => managedDisposed++,
      );

      final staticFallback = WhatController<String>('StaticFallback');

      final activeResource = switched<String>(
        (via) => via(useManaged.what) ? pool : staticFallback.what,
      );

      final distinctResource = activeResource.distinct();

      final captured = <String>[];
      final runner = distinctResource.effect(() {
        captured.add(untracked(distinctResource));
      }).run();

      expect(managedCreated, 1, reason: 'Activation must prime managed resource through unary chain');
      expect(captured, isEmpty);

      // Mutate managed capacity
      capacity.data = 5;
      await Future<void>.delayed(Duration.zero);
      expect(captured, ['Pool(5)']);

      // Switch to static fallback
      useManaged.data = false;
      await Future<void>.delayed(Duration.zero);
      expect(captured, ['Pool(5)', 'StaticFallback']);
      expect(managedDisposed, 2);

      runner.deactivate();
    });

    test('9. Handled Effect with Unary wrapping Diamond Upstream and cleanup lifecycle', () async {
      final root = WhatController<int>(1);
      final b1 = computed<int>((via) => via(root.what) * 2);
      final b2 = computed<int>((via) => via(root.what) * 3);
      final join = computed<int>((via) => via(b1) + via(b2));
      final distinctJoin = join.distinct();

      final captured = <int>[];
      final cleanups = <int>[];

      final runner = distinctJoin.effect.handled((handle) {
        final val = untracked(distinctJoin);
        captured.add(val);
        handle.onCleanup(() {
          cleanups.add(val);
        });
      }).run();

      expect(captured, isEmpty);
      expect(cleanups, isEmpty);

      // Turn 1: 2 * 2 + 2 * 3 = 10
      root.data = 2;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [10]);
      expect(cleanups, isEmpty);

      // Turn 2: 3 * 2 + 3 * 3 = 15
      root.data = 3;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [10, 15]);
      expect(cleanups, [10], reason: 'Previous turn cleanup must be called before next execution');

      // Deactivation disposes active cleanup
      runner.deactivate();
      expect(cleanups, [10, 15]);
    });

    test('10. Multi-Target (N-ary) Effect with Unary Diamond and Direct Controllers', () async {
      final root = WhatController<int>(1);
      final b1 = computed<int>((via) => via(root.what) + 10);
      final b2 = computed<int>((via) => via(root.what) + 20);
      final diamondUnary = computed<int>((via) => via(b1) + via(b2)).distinct();

      final independent = WhatController<String>('Hello');

      int runCount = 0;
      final runner = (diamondUnary, independent.what).effect(() {
        runCount++;
      }).run();

      expect(runCount, 0);

      // Mutate diamond root
      root.data = 2;
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 1);

      // Mutate independent controller
      independent.data = 'World';
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 2);

      runner.deactivate();
    });

    test('11. Direct WhatController leaf facing Effect', () async {
      final ctrl = WhatController<int>(100);

      final captured = <int>[];
      final runner = ctrl.what.effect(() {
        captured.add(ctrl.data);
      }).run();

      expect(captured, isEmpty);

      ctrl.data = 200;
      await Future<void>.delayed(Duration.zero);
      expect(captured, [200]);

      runner.deactivate();
    });

    test('12. Static What.constant leaf facing Effect', () async {
      final constantNode = What.constant(42);

      var runCount = 0;
      final runner = constantNode.effect(() {
        runCount++;
      }).run();

      expect(runner.isActive, isTrue);
      expect(runCount, 0);

      await Future<void>.delayed(Duration.zero);
      expect(runCount, 0, reason: 'Constant node never emits mutations');

      runner.deactivate();
    });
  });
}
