// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('Graceful Mooring & LPDAG Dynamic Lifecycle Suite', () {
    // =========================================================================
    // 1. Time-Based Mooring (Graceful.period) with What.managed
    // =========================================================================
    group('1. Time-Based Mooring with What.managed', () {
      test('1.1 Early return cancels grace period and retains active resource without reallocation', () async {
        int createCount = 0;
        int disposeCount = 0;

        final res = managed<String>(
          create: (_) {
            createCount++;
            return 'MooredResource-$createCount';
          },
          dispose: (_) {
            disposeCount++;
          },
          graceful: const Graceful.period(Duration(milliseconds: 100)),
        );

        final t1 = RawWhatTerminal(res, onInvalidated: () {});
        final t2 = RawWhatTerminal(res, onInvalidated: () {});

        t1.activate();
        expect(createCount, 0); // Pure lazy: Not created upon activation alone
        expect(t1.data, 'MooredResource-1');
        expect(createCount, 1);
        expect(disposeCount, 0);

        // Disconnect t1: Node enters mooring grace period (anchored by _MooringTerminal)
        t1.deactivate();
        expect(disposeCount, 0); // Preserved!

        // Wait 40ms (< 100ms duration)
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(disposeCount, 0);

        // Early return: t2 connects before expiration
        t2.activate();
        expect(createCount, 1); // Not re-created!
        expect(disposeCount, 0);
        expect(t2.data, 'MooredResource-1');

        // Wait beyond the original 100ms timer
        await Future<void>.delayed(const Duration(milliseconds: 90));
        expect(disposeCount, 0); // Timer was successfully cancelled!

        // Finally disconnect t2
        t2.deactivate();
        expect(disposeCount, 0);

        // Wait for 120ms to allow expiration
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(disposeCount, 1); // Natural deactivation triggered upon expiration!
      });

      test('1.2 Expiration triggers natural deactivation and releases resource cleanly', () async {
        int createCount = 0;
        int disposeCount = 0;

        final res = managed<String>(
          create: (_) {
            createCount++;
            return 'ExpireResource-$createCount';
          },
          dispose: (_) {
            disposeCount++;
          },
          graceful: const Graceful.period(Duration(milliseconds: 60)),
        );

        final terminal = RawWhatTerminal(res, onInvalidated: () {});
        terminal.activate();
        expect(createCount, 0);
        expect(terminal.data, 'ExpireResource-1');
        expect(createCount, 1);
        expect(disposeCount, 0);

        terminal.deactivate();
        expect(disposeCount, 0);

        // Wait until expired
        await Future<void>.delayed(const Duration(milliseconds: 90));
        expect(disposeCount, 1);

        // Reactivation after full expiration allocates fresh resource
        terminal.activate();
        expect(createCount, 1);
        expect(terminal.data, 'ExpireResource-2');
        expect(createCount, 2);
        expect(disposeCount, 1);

        terminal.deactivate();
        await Future<void>.delayed(const Duration(milliseconds: 90));
        expect(disposeCount, 2);
      });
    });

    // =========================================================================
    // 2. WhatController Lifecycle Hooks & Mooring
    // =========================================================================
    group('2. WhatController Lifecycle Hooks with Graceful.period', () {
      test('2.1 onDeactivated is deferred until period expiration', () async {
        int activatedCount = 0;
        int deactivatedCount = 0;

        final node = WhatController<int>(
          0,
          onActivated: () => activatedCount++,
          onDeactivated: () => deactivatedCount++,
          graceful: const Graceful.period(Duration(milliseconds: 80)),
        );

        final t1 = RawWhatTerminal(node.what, onInvalidated: () {});
        t1.activate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 0);

        t1.deactivate();
        expect(deactivatedCount, 0); // Moored!

        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(deactivatedCount, 0);

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(deactivatedCount, 1); // Expired!
      });

      test('2.2 Early reconnect prevents onDeactivated and skips redundant onActivated', () async {
        int activatedCount = 0;
        int deactivatedCount = 0;

        final node = WhatController<int>(
          10,
          onActivated: () => activatedCount++,
          onDeactivated: () => deactivatedCount++,
          graceful: const Graceful.period(Duration(milliseconds: 80)),
        );

        final t1 = RawWhatTerminal(node.what, onInvalidated: () {});
        final t2 = RawWhatTerminal(node.what, onInvalidated: () {});

        t1.activate();
        expect(activatedCount, 1);

        t1.deactivate();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Reconnect early
        t2.activate();
        expect(activatedCount, 1); // No redundant activation!
        expect(deactivatedCount, 0);

        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(deactivatedCount, 0); // Timer was cancelled!

        t2.deactivate();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(deactivatedCount, 1);
      });
    });

    // =========================================================================
    // 3. Stream & Async Resource Mooring
    // =========================================================================
    group('3. Stream Mooring with Graceful.period', () {
      test('3.1 Stream subscription stays open during mooring window', () async {
        final controller = StreamController<int>.broadcast();
        final streamWhat = controller.stream.toWhat(
          initialFactory: () => 0,
          graceful: const Graceful.period(Duration(milliseconds: 80)),
        );

        final t1 = RawWhatTerminal(streamWhat, onInvalidated: () {});
        t1.activate();
        expect(controller.hasListener, isTrue);

        t1.deactivate();
        // Still listening because _MooringTerminal is mooring the node!
        expect(controller.hasListener, isTrue);

        // New event arrives while moored:
        controller.add(42);
        await Future<void>.delayed(Duration.zero);

        // Reconnect early:
        final t2 = RawWhatTerminal(streamWhat, onInvalidated: () {});
        t2.activate();
        expect(t2.data, 42); // Value received while moored was preserved!

        t2.deactivate();
        await Future<void>.delayed(const Duration(milliseconds: 110));
        // Finally cancelled after expiration:
        expect(controller.hasListener, isFalse);

        await controller.close();
      });
    });

    // =========================================================================
    // 4. Policy Comparison (none vs microtask vs period)
    // =========================================================================
    group('4. Graceful Policy Variants', () {
      test('4.1 Graceful.none deactivates immediately synchronously', () {
        int disposeCount = 0;
        final res = managed<String>(
          create: (_) => 'Immediate',
          dispose: (_) => disposeCount++,
          graceful: Graceful.none,
        );

        final terminal = RawWhatTerminal(res, onInvalidated: () {});
        terminal.activate();
        expect(terminal.data, 'Immediate');
        expect(disposeCount, 0);

        terminal.deactivate();
        expect(disposeCount, 1); // Immediate synchronous teardown!
      });

      test('4.2 Graceful.microtask deactivates on next tick without Timer allocation', () async {
        int disposeCount = 0;
        final res = managed<String>(
          create: (_) => 'Microtask',
          dispose: (_) => disposeCount++,
          graceful: const Graceful(),
        );

        final terminal = RawWhatTerminal(res, onInvalidated: () {});
        terminal.activate();
        expect(terminal.data, 'Microtask');
        expect(disposeCount, 0);

        terminal.deactivate();
        expect(disposeCount, 0); // Not disposed synchronously

        await Future<void>.delayed(Duration.zero);
        expect(disposeCount, 1); // Disposed after microtask tick
      });

      test('4.3 Graceful.microtask early reconnect prevents deactivation and skips redundant reactivation', () async {
        int createCount = 0;
        int disposeCount = 0;
        int activatedCount = 0;
        int deactivatedCount = 0;

        final res = managed<String>(
          create: (_) {
            createCount++;
            return 'Microtask-$createCount';
          },
          dispose: (_) => disposeCount++,
          graceful: Graceful.microtask,
        );

        final writable = WhatController<int>(
          0,
          onActivated: () => activatedCount++,
          onDeactivated: () => deactivatedCount++,
          graceful: Graceful.microtask,
        );

        final t1 = RawWhatTerminal(res, onInvalidated: () {});
        final t2 = RawWhatTerminal(res, onInvalidated: () {});
        final w1 = RawWhatTerminal(writable.what, onInvalidated: () {});
        final w2 = RawWhatTerminal(writable.what, onInvalidated: () {});

        t1.activate();
        w1.activate();
        expect(t1.data, 'Microtask-1');
        expect(createCount, 1);
        expect(disposeCount, 0);
        expect(activatedCount, 1);
        expect(deactivatedCount, 0);

        // Disconnect t1 and w1: Enter microtask buffer
        t1.deactivate();
        w1.deactivate();
        expect(disposeCount, 0);
        expect(deactivatedCount, 0);

        // Early reconnect before microtask tick:
        t2.activate();
        w2.activate();
        expect(createCount, 1); // Preserved without reallocation
        expect(disposeCount, 0);
        expect(activatedCount, 1); // No redundant activation!
        expect(deactivatedCount, 0);

        // Wait for microtask tick
        await Future<void>.delayed(Duration.zero);
        expect(createCount, 1);
        expect(disposeCount, 0); // Still 0!
        expect(activatedCount, 1);
        expect(deactivatedCount, 0); // Still 0!

        // Finally disconnect t2 and w2
        t2.deactivate();
        w2.deactivate();
        expect(disposeCount, 0);
        expect(deactivatedCount, 0);

        await Future<void>.delayed(Duration.zero);
        expect(disposeCount, 1); // Natural deactivation triggered!
        expect(deactivatedCount, 1);
      });

      test('4.4 Graceful.microtask reactivation after full expiration cleanly creates fresh state', () async {
        int createCount = 0;
        int disposeCount = 0;

        final res = managed<String>(
          create: (_) {
            createCount++;
            return 'Cycle-$createCount';
          },
          dispose: (_) => disposeCount++,
          graceful: Graceful.microtask,
        );

        final terminal = RawWhatTerminal(res, onInvalidated: () {});
        terminal.activate();
        expect(terminal.data, 'Cycle-1');
        expect(createCount, 1);
        expect(disposeCount, 0);

        terminal.deactivate();
        await Future<void>.delayed(Duration.zero);
        expect(disposeCount, 1);

        // Reactivate fresh
        terminal.activate();
        expect(createCount, 1);
        expect(terminal.data, 'Cycle-2');
        expect(createCount, 2);
        expect(disposeCount, 1);

        terminal.deactivate();
        await Future<void>.delayed(Duration.zero);
        expect(disposeCount, 2);
      });

      test('4.5 Concurrently releasing 100 microtask nodes executes cleanly without edge allocation', () async {
        final disposed = <int>[];
        final terminals = <RawWhatTerminal<int>>[];

        for (var i = 0; i < 100; i++) {
          final res = managed<int>(
            create: (_) => i,
            dispose: (val) => disposed.add(val),
            graceful: Graceful.microtask,
          );
          final t = RawWhatTerminal(res, onInvalidated: () {});
          t.activate();
          expect(t.data, i);
          terminals.add(t);
        }

        expect(disposed, isEmpty);

        // Batch deactivate all 100 nodes in the same turn
        for (final t in terminals) {
          t.deactivate();
        }
        expect(disposed, isEmpty); // All buffered in scheduler without timer allocation

        await Future<void>.delayed(Duration.zero);
        expect(disposed.length, 100);
      });
    });

    // =========================================================================
    // 5. Multi-Node Mooring & Concurrent Grace Periods
    // =========================================================================
    group('5. Concurrent Mooring Nodes in _MooringTerminal', () {
      test('5.1 Multiple nodes can moor simultaneously with independent durations', () async {
        final disposed = <String>[];

        final resA = managed<String>(
          create: (_) => 'A',
          dispose: (_) => disposed.add('A'),
          graceful: const Graceful.period(Duration(milliseconds: 50)),
        );

        final resB = managed<String>(
          create: (_) => 'B',
          dispose: (_) => disposed.add('B'),
          graceful: const Graceful.period(Duration(milliseconds: 100)),
        );

        final tA = RawWhatTerminal(resA, onInvalidated: () {});
        final tB = RawWhatTerminal(resB, onInvalidated: () {});

        tA.activate();
        tB.activate();
        expect(tA.data, 'A');
        expect(tB.data, 'B');

        tA.deactivate();
        tB.deactivate();
        expect(disposed, isEmpty);

        // After 70ms: A should expire (50ms), B should still be moored (100ms)
        await Future<void>.delayed(const Duration(milliseconds: 75));
        expect(disposed, ['A']);

        // After another 50ms (total 125ms): B should expire
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(disposed, ['A', 'B']);
      });
    });

    // =========================================================================
    // 6. Top-Level graceful Functor & DSL Tests
    // =========================================================================
    // 6. Graceful Class Factories & Constants
    // =========================================================================
    group('6. Graceful Class Factories & Constants', () {
      test('6.1 Graceful.microtask works directly as default microtask policy', () async {
        int disposed = 0;
        final res = managed<int>(
          create: (_) => 42,
          dispose: (_) => disposed++,
          graceful: Graceful.microtask,
        );

        final t = RawWhatTerminal(res, onInvalidated: () {});
        t.activate();
        expect(t.data, 42);

        t.deactivate();
        expect(disposed, 0); // Not disposed synchronously

        await Future<void>.delayed(Duration.zero);
        expect(disposed, 1); // Disposed after microtask
      });

      test('6.2 Graceful() default constructor works as microtask policy', () async {
        int disposed = 0;
        final res = managed<int>(
          create: (_) => 100,
          dispose: (_) => disposed++,
          graceful: const Graceful(),
        );

        final t = RawWhatTerminal(res, onInvalidated: () {});
        t.activate();
        expect(t.data, 100);
        t.deactivate();
        expect(disposed, 0);

        await Future<void>.delayed(Duration.zero);
        expect(disposed, 1);
      });

      test('6.3 Graceful.period() creates active time-based mooring policy', () async {
        int disposed = 0;
        final res = managed<int>(
          create: (_) => 999,
          dispose: (_) => disposed++,
          graceful: const Graceful.period(Duration(milliseconds: 60)),
        );

        final t = RawWhatTerminal(res, onInvalidated: () {});
        t.activate();
        expect(t.data, 999);
        t.deactivate();
        expect(disposed, 0);

        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(disposed, 0); // Still moored

        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(disposed, 1); // Expired and disposed
      });

      test('6.4 Graceful.none represents null sentinel', () {
        expect(Graceful.none, isNull);
        expect(Graceful.microtask, isA<Graceful>());
        expect(const Graceful(), isA<Graceful>());
      });
    });
  });
}
