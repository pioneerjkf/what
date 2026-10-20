// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:what/effect.dart';
import 'package:what/what.dart';

void main() {
  group('EffectRunner Architectural Suite (Standalone Effect Execution)', () {
    test('1. Architectural Contract: EffectRunner is a RawTerminal governing an Effect', () {
      final controller = WhatController<int>(0);
      final effect = controller.what.effect(() {});
      final runner = effect.run();

      expect(runner, isA<EffectRunner>());
      expect(runner, isA<RawTerminal>());
      expect(runner.isActive, isTrue);

      runner.deactivate();
      expect(runner.isActive, isFalse);
    });

    test('1.1 Standalone execution with run() responds to mutations', () async {
      final counter = WhatController<int>(0);
      var runs = 0;

      final runner = counter.what.effect(() {
        runs++;
      }).run();

      expect(runner.isActive, isTrue);

      counter.data = 1;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Deactivation detaches upstream subscription
      runner.deactivate();
      expect(runner.isActive, isFalse);

      counter.data = 2;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1); // No new execution

      // Reactivation reconnects upstream subscription
      runner.activate();
      expect(runner.isActive, isTrue);

      counter.data = 3;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      runner.deactivate();
    });

    test('1.2 autoStart: false stays inactive until explicit activate()', () async {
      final counter = WhatController<int>(0);
      var runs = 0;

      final runner = counter.what.effect(() {
        runs++;
      }).run(autoStart: false);

      expect(runner.isActive, isFalse);

      counter.data = 1;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 0);

      runner.activate();
      expect(runner.isActive, isTrue);

      counter.data = 2;
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      runner.deactivate();
    });

    // =========================================================================
    // 2. Shared Ownership & Subscriber-Driven Dormancy (Tether + Runner)
    // =========================================================================
    group('2. Shared Ownership (Tether + Runner)', () {
      test(
        '2.1 Deactivating runner keeps effect active while tether scope is active',
        () async {
          final counter = WhatController<int>(0);
          var runs = 0;

          // Single shared Effect instance
          final sharedEffect = counter.what.effect(() {
            runs++;
          });

          // 1. Tethered inside a reactive scope (e.g. computed node)
          final toggle = WhatController<bool>(true);
          final computedScope = computed((via) {
            if (via(toggle.what)) {
              via.tether(sharedEffect);
              return 'active_scope';
            }
            return 'inactive_scope';
          });

          // Mount computed scope to make it active and prime tether
          final scopeTerminal = RawWhatTerminal(computedScope, onInvalidated: () {})..activate();
          expect(scopeTerminal.data, 'active_scope');

          // 2. Also run via EffectRunner
          final runner = sharedEffect.run();
          expect(runner.isActive, isTrue);

          // 3. Mutate: executes exactly once (deduplicated by single Effect node)
          counter.data = 1;
          await Future<void>.delayed(Duration.zero);
          expect(runs, 1);

          // 4. Deactivate runner: runner is deactivated, BUT computedScope is still tethering!
          runner.deactivate();
          expect(runner.isActive, isFalse);

          // 5. Mutate: Effect MUST STILL EXECUTE because tether scope is active!
          counter.data = 2;
          await Future<void>.delayed(Duration.zero);
          expect(runs, 2);

          // 6. Now sweep the tether branch out of computedScope
          toggle.data = false;
          expect(scopeTerminal.data, 'inactive_scope');
          await Future<void>.delayed(Duration.zero);

          // 7. Mutate: Now BOTH runner and tether are inactive -> Effect is Dormant!
          counter.data = 3;
          await Future<void>.delayed(Duration.zero);
          expect(runs, 2); // No run!

          // 8. Reactivating runner revives the Effect independently!
          runner.activate();
          expect(runner.isActive, isTrue);

          counter.data = 4;
          await Future<void>.delayed(Duration.zero);
          expect(runs, 3);

          runner.deactivate();
          scopeTerminal.deactivate();
        },
      );

      test(
        '2.2 Unmounting tether scope keeps effect active while runner is active',
        () async {
          final counter = WhatController<int>(0);
          var runs = 0;

          final sharedEffect = counter.what.effect(() {
            runs++;
          });

          final toggle = WhatController<bool>(true);
          final computedScope = computed((via) {
            if (via(toggle.what)) {
              via.tether(sharedEffect);
              return 'active';
            }
            return 'inactive';
          });

          final scopeTerminal = RawWhatTerminal(computedScope, onInvalidated: () {})..activate();
          expect(scopeTerminal.data, 'active');
          final runner = sharedEffect.run();

          counter.data = 1;
          await Future<void>.delayed(Duration.zero);
          expect(runs, 1);

          // Tether scope detaches (sweep out)
          toggle.data = false;
          expect(scopeTerminal.data, 'inactive');
          await Future<void>.delayed(Duration.zero);

          // Mutate: Runner is still active, so Effect must execute!
          counter.data = 2;
          await Future<void>.delayed(Duration.zero);
          expect(runs, 2);

          // Now deactivate runner
          runner.deactivate();

          // Mutate: Both are detached -> Dormant!
          counter.data = 3;
          await Future<void>.delayed(Duration.zero);
          expect(runs, 2);

          scopeTerminal.deactivate();
        },
      );
    });

    // =========================================================================
    // 3. Composite EffectGroup Execution
    // =========================================================================
    group('3. Composite EffectGroup Execution', () {
      test('3.1 EffectGroup.run() coordinates multiple effects atomically', () async {
        final a = WhatController<int>(0);
        final b = WhatController<int>(0);
        var runsA = 0;
        var runsB = 0;

        final e1 = a.what.effect(() => runsA++);
        final e2 = b.what.effect(() => runsB++);

        final groupRunner = EffectGroup([e1, e2]).run();
        expect(groupRunner.isActive, isTrue);

        a.data = 1;
        b.data = 1;
        await Future<void>.delayed(Duration.zero);
        expect(runsA, 1);
        expect(runsB, 1);

        // Deactivate group
        groupRunner.deactivate();
        expect(groupRunner.isActive, isFalse);

        a.data = 2;
        b.data = 2;
        await Future<void>.delayed(Duration.zero);
        expect(runsA, 1);
        expect(runsB, 1);

        // Reactivate group
        groupRunner.activate();
        expect(groupRunner.isActive, isTrue);

        a.data = 3;
        b.data = 3;
        await Future<void>.delayed(Duration.zero);
        expect(runsA, 2);
        expect(runsB, 2);

        groupRunner.deactivate();
      });

      test('3.2 Tuple extension (e1, e2).group.run() works seamlessly', () async {
        final a = WhatController<int>(0);
        final b = WhatController<int>(0);
        var runsA = 0;
        var runsB = 0;

        final e1 = a.what.effect(() => runsA++);
        final e2 = b.what.effect(() => runsB++);

        final runner = (e1, e2).group.run();
        expect(runner.isActive, isTrue);

        a.data = 10;
        await Future<void>.delayed(Duration.zero);
        expect(runsA, 1);
        expect(runsB, 0);

        b.data = 20;
        await Future<void>.delayed(Duration.zero);
        expect(runsA, 1);
        expect(runsB, 1);

        runner.deactivate();
      });
    });

    // =========================================================================
    // 4. Temporal Pipelines with EffectRunner
    // =========================================================================
    group('4. Temporal Pipelines (Debounce & Throttle)', () {
      test('4.1 Debounced effect runs standalone and respects silence duration', () async {
        final query = WhatController<String>('');
        final results = <String>[];

        final runner = query.what.effect.debounce(const Duration(milliseconds: 30), () {
          results.add(untracked(query.what));
        }).run();

        // Rapid mutations
        query.data = 'd';
        query.data = 'da';
        query.data = 'dar';
        query.data = 'dart';

        // Before debounce window
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(results, isEmpty);

        // After debounce window
        await Future<void>.delayed(const Duration(milliseconds: 35));
        expect(results, ['dart']);

        runner.deactivate();
      });

      test('4.2 Deactivating runner during active debounce cancels pending timer cleanly', () async {
        final query = WhatController<String>('');
        final results = <String>[];

        final runner = query.what.effect.debounce(const Duration(milliseconds: 50), () {
          results.add(untracked(query.what));
        }).run();

        query.data = 'hello';
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Deactivate before timer fires
        runner.deactivate();

        // Wait past timer duration
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(results, isEmpty); // Cleanly cancelled!
      });
    });

    // =========================================================================
    // 5. Lazy Computed Derivation Priming & Graph Continuity
    // =========================================================================
    group('5. Lazy Computed Derivation Priming & Graph Continuity', () {
      test('5.1 Unary effect on lazy computed node primes DAG and responds to upstream mutations', () async {
        final counter = WhatController<int>(10);
        final doubled = computed((via) => via(counter.what) * 2);

        final captured = <int>[];
        // EffectRunner attached directly to unevaluated lazy computed node
        final runner = doubled.effect(() {
          captured.add(untracked(doubled));
        }).run();

        expect(runner.isActive, isTrue);
        expect(captured, isEmpty); // Skips initial execution

        counter.data = 20;
        await Future<void>.delayed(Duration.zero);
        expect(captured, [40]);

        counter.data = 30;
        await Future<void>.delayed(Duration.zero);
        expect(captured, [40, 60]);

        runner.deactivate();
      });

      test('5.2 N-ary effect on multiple lazy computed nodes primes DAG cleanly', () async {
        final a = WhatController<int>(1);
        final b = WhatController<int>(2);
        final sum = computed((via) => via(a.what) + via(b.what));
        final product = computed((via) => via(a.what) * via(b.what));

        var executions = 0;
        final runner = Effect([sum, product], () {
          executions++;
        }).run();

        expect(executions, 0);

        a.data = 10;
        await Future<void>.delayed(Duration.zero);
        expect(executions, 1);
        expect(untracked(sum), 12);
        expect(untracked(product), 20);

        runner.deactivate();
      });
    });
  });
}
