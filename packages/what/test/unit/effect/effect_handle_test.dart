// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:what/effect.dart';
import 'package:what/what.dart';

void main() {
  group('EffectHandle Lifecycle & Cancellation Suite', () {
    test('1. Effect.handled executes with active handle via runner', () async {
      final counter = WhatController(0);
      EffectHandle? capturedHandle;
      var runCount = 0;

      final runner = counter.what.effect.handled((handle) {
        runCount++;
        capturedHandle = handle;
      }).run();

      expect(runCount, 0); // Effects skip initial evaluation

      counter.set(1);
      await Future<void>.delayed(Duration.zero);

      expect(runCount, 1);
      expect(capturedHandle, isNotNull);
      expect(capturedHandle!.isActive, isTrue);
      expect(capturedHandle!.isCancelled, isFalse);

      runner.deactivate();
      expect(capturedHandle!.isActive, isFalse);
      expect(capturedHandle!.isCancelled, isTrue);
    });

    test('2. Invariant 1: onCleanup is called before subsequent turn begins', () async {
      final query = WhatController('a');
      final log = <String>[];
      final handles = <EffectHandle>[];

      final runner = query.what.effect.handled((handle) {
        handles.add(handle);
        final current = query.what.peek;
        log.add('run: $current');

        handle.onCleanup(() {
          log.add('cleanup: $current');
          expect(handle.isActive, isFalse);
          expect(handle.isCancelled, isTrue);
        });
      }).run();

      // First trigger
      query.set('b');
      await Future<void>.delayed(Duration.zero);

      expect(log, ['run: b']);
      expect(handles.first.isActive, isTrue);

      // Second trigger: should clean up previous before running new
      query.set('c');
      await Future<void>.delayed(Duration.zero);

      expect(log, ['run: b', 'cleanup: b', 'run: c']);
      expect(handles[0].isActive, isFalse);
      expect(handles[0].isCancelled, isTrue);
      expect(handles[1].isActive, isTrue);

      runner.deactivate();
    });

    test('3. Invariant 2: onCleanup is called on deactivation / unmount', () async {
      final target = WhatController(10);
      var cleanedUp = false;
      EffectHandle? currentHandle;

      final runner = target.what.effect.handled((handle) {
        currentHandle = handle;
        handle.onCleanup(() {
          cleanedUp = true;
        });
      }).run();

      target.set(20);
      await Future<void>.delayed(Duration.zero);

      expect(cleanedUp, isFalse);
      expect(currentHandle!.isActive, isTrue);

      // Deactivate effect
      runner.deactivate();

      expect(cleanedUp, isTrue);
      expect(currentHandle!.isActive, isFalse);
      expect(currentHandle!.isCancelled, isTrue);
    });

    test('4. Multi-target Effect.handled with tuple', () async {
      final a = WhatController(1);
      final b = WhatController(2);
      final cleanupOrder = <int>[];

      final runner = (a.what, b.what).effect.handled((handle) {
        final sum = a.what.peek + b.what.peek;
        handle.onCleanup(() {
          cleanupOrder.add(sum);
        });
      }).run();

      a.set(10);
      await Future<void>.delayed(Duration.zero);
      expect(cleanupOrder, isEmpty);

      b.set(20);
      await Future<void>.delayed(Duration.zero);
      expect(cleanupOrder, [12]); // Previous sum was 10 + 2 = 12

      runner.deactivate();
      expect(cleanupOrder, [12, 30]); // Current sum was 10 + 20 = 30
    });

    test('5. Dynamic Effect.handledVia with 1-Pass Epoch Sweeping', () async {
      final condition = WhatController(true);
      final left = WhatController('L1');
      final right = WhatController('R1');
      final log = <String>[];

      final runner = Effect.handledVia((via, handle) {
        final cond = via(condition.what);
        final value = cond ? via(left.what) : via(right.what);
        log.add('via run: $value');

        handle.onCleanup(() {
          log.add('via cleanup: $value');
        });
      }).run();

      // Initial run happens via scheduler microtask
      await Future<void>.delayed(Duration.zero);
      expect(log, ['via run: L1']);

      // Mutate active branch
      left.set('L2');
      await Future<void>.delayed(Duration.zero);
      expect(log, ['via run: L1', 'via cleanup: L1', 'via run: L2']);

      // Switch branch to right
      condition.set(false);
      await Future<void>.delayed(Duration.zero);
      expect(log, [
        'via run: L1',
        'via cleanup: L1',
        'via run: L2',
        'via cleanup: L2',
        'via run: R1',
      ]);

      // Mutating swept branch (left) should NOT trigger anything
      left.set('L3');
      await Future<void>.delayed(Duration.zero);
      expect(log.length, 5); // Unchanged

      runner.deactivate();
      expect(log.last, 'via cleanup: R1');
    });

    test('6. Multiple onCleanup callbacks execute in LIFO / all guaranteed via finally', () async {
      final counter = WhatController(0);
      final executed = <String>[];

      final runner = counter.what.effect.handled((handle) {
        handle.onCleanup(() {
          executed.add('cleanup 1');
          throw Exception('Intentional failure in cleanup 1');
        });
        handle.onCleanup(() {
          executed.add('cleanup 2');
        });
      }, onUncaughtError: (error, st) {
        executed.add('handled error: $error');
      }).run();

      counter.set(1);
      await Future<void>.delayed(Duration.zero);

      runner.deactivate();

      // Even if cleanup 1 throws, cleanup 2 must execute
      expect(executed, contains('cleanup 1'));
      expect(executed, contains('cleanup 2'));
      expect(executed, anyElement(contains('Intentional failure in cleanup 1')));
    });

    test('7. Registering onCleanup on an already cancelled handle executes immediately', () {
      final counter = WhatController(0);
      EffectHandle? storedHandle;

      final runner = counter.what.effect.handled((handle) {
        storedHandle = handle;
      }).run();

      counter.set(1);
      // Wait for execution
      Future<void>.delayed(Duration.zero).then((_) {
        runner.deactivate();
        expect(storedHandle!.isCancelled, isTrue);

        var called = false;
        storedHandle!.onCleanup(() {
          called = true;
        });
        expect(called, isTrue);
      });
    });

    test('8. Guard returning false preserves previous handle and skips execution', () async {
      final counter = WhatController(0);
      var runCount = 0;
      var cleanups = 0;

      final runner = counter.what.effect.handled(
        (handle) {
          runCount++;
          handle.onCleanup(() => cleanups++);
        },
        guard: () => counter.what.peek.isEven,
      ).run();

      counter.set(2); // Even -> runs
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 1);
      expect(cleanups, 0);

      counter.set(3); // Odd -> guard fails -> should skip run and NOT cleanup previous
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 1);
      expect(cleanups, 0);

      counter.set(4); // Even -> runs -> cleans up previous (from 2)
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 2);
      expect(cleanups, 1);

      runner.deactivate();
      expect(cleanups, 2);
    });

    test('9. take: N automatically triggers early teardown and cleans up last handle', () async {
      final counter = WhatController(0);
      var runCount = 0;
      var cleanups = 0;

      final runner = counter.what.effect.handled(
        (handle) {
          runCount++;
          handle.onCleanup(() => cleanups++);
        },
        take: 2,
      ).run();

      counter.set(1); // Turn 1
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 1);
      expect(cleanups, 0);

      counter.set(2); // Turn 2 (takes exhausted -> deactivates)
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 2);
      expect(cleanups, 2); // Previous cleanup + early teardown deactivation cleanup!
      expect(runner.isActive, isFalse);

      counter.set(3); // Dead
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 2);
    });

    test('10. In-flight race condition immunity simulation', () async {
      final query = WhatController('first');
      final receivedResults = <String>[];

      final runner = query.what.effect.handled((handle) async {
        final currentQuery = query.what.peek;
        final delayMs = currentQuery == 'first' ? 50 : 10;

        // Simulate async I/O
        await Future<void>.delayed(Duration(milliseconds: delayMs));

        if (handle.isActive) {
          receivedResults.add(currentQuery);
        }
      }).run();

      // Trigger 1: 'first' (takes 50ms)
      query.set('first');
      await Future<void>.delayed(Duration.zero);

      // Trigger 2: 'second' (takes 10ms), fired 5ms later
      await Future<void>.delayed(const Duration(milliseconds: 5));
      query.set('second');
      await Future<void>.delayed(Duration.zero);

      // Wait for all async tasks to settle
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 'first' must have been aborted by handle.isActive check; only 'second' survived!
      expect(receivedResults, ['second']);
      runner.deactivate();
    });

    test('11. Cleanup errors after cancellation or disposal are routed to onUncaughtError', () async {
      final counter = WhatController(0);
      EffectHandle? capturedHandle;
      final errors = <Object>[];

      final runner = counter.what.effect.handled(
        (handle) {
          capturedHandle = handle;
          handle.onCleanup(() {
            throw StateError('Teardown failure');
          });
        },
        onUncaughtError: (error, stack) {
          errors.add(error);
        },
      ).run();

      counter.set(1);
      await Future<void>.delayed(Duration.zero);

      // Deactivating disposes the current handle, triggering onCleanup exception
      runner.deactivate();

      expect(errors.length, 1);
      expect(errors.first, isA<StateError>());

      // Calling onCleanup after cancellation also catches and forwards to onUncaughtError
      capturedHandle!.onCleanup(() {
        throw StateError('Late cleanup error');
      });

      expect(errors.length, 2);
      expect(errors.last, isA<StateError>());
    });
  });
}
