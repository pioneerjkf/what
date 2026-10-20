// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('RawWhat & markDirty() Comprehensive Unit Tests', () {
    // =========================================================================
    // 1. Sibling Architecture & Type Isolation Tests
    // =========================================================================
    group('1. Sibling Architecture & Strict Type Isolation', () {
      test('1.1 RawWhatController is a WhatController with Has-a What, but NOT a What itself', () {
        final raw = RawWhatController<int>(10);

        expect(raw, isA<RawWhatController<int>>());
        expect(raw, isA<WhatController<int>>());
        expect(raw, isNot(isA<What>()), reason: 'WhatController must NOT be a What (Has-a architecture)');
        expect(raw.what, isA<What<int>>());
      });

      test('1.2 Standard WhatController is NOT a RawWhatController', () {
        final writable = WhatController<int>(10);

        expect(writable, isA<WhatController<int>>());
        expect(writable, isNot(isA<What>()), reason: 'WhatController must NOT be a What (Has-a architecture)');
        expect(writable.what, isA<What<int>>());
        expect(writable, isNot(isA<RawWhatController>()),
            reason: 'Standard WhatController must NOT be an instance of RawWhatController');
      });

      test('1.3 WhatController(distinct: false) is NOT a RawWhat', () {
        final writableNonDistinct = WhatController<int>(10, distinct: false);

        expect(writableNonDistinct, isA<WhatController<int>>());
        expect(writableNonDistinct, isNot(isA<RawWhatController>()),
            reason: 'Even with distinct: false, WhatController retains its distinct family identity');
      });

      test('1.4 Both WhatController and RawWhatController implement WhatController polymorphically', () {
        final writable = WhatController<int>(10);
        final raw = RawWhatController<int>(20);

        expect(writable, isA<WhatController<int>>());
        expect(raw, isA<WhatController<int>>());

        void mutateEntry(WhatController<int> entry, int val) {
          entry.data = val;
        }

        mutateEntry(writable, 99);
        expect(writable.data, 99);

        mutateEntry(raw, 100);
        expect(raw.data, 100);
      });
    });

    // =========================================================================
    // 2. markDirty() Zero-Allocation Dirty Pulse Tests
    // =========================================================================
    group('2. markDirty() Zero-Allocation Dirty Pulse Invalidation', () {
      test('2.1 markDirty() broadcasts invalidation pulse without changing data', () {
        final raw = RawWhatController<int>(42);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.data, 42);
        expect(invalidationCount, 0);

        // Call markDirty without mutating data
        raw.markDirty();
        expect(invalidationCount, 1);
        expect(terminal.data, 42);

        // Consecutive markDirty calls
        raw.markDirty();
        expect(invalidationCount, 2);
        expect(terminal.data, 42);

        terminal.deactivate();
      });

      test('2.2 In-place collection mutation followed by markDirty()', () {
        final buffer = <String>['apple'];
        final raw = RawWhatController<List<String>>(buffer);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.data, equals(['apple']));
        expect(invalidationCount, 0);

        // Mutate buffer directly in-place
        raw.data.add('banana');
        expect(invalidationCount, 0, reason: 'In-place mutation alone does not notify');

        // Broadcast dirty pulse via markDirty
        raw.markDirty();
        expect(invalidationCount, 1);
        expect(terminal.data, equals(['apple', 'banana']));

        // Another in-place mutation
        raw.data.add('cherry');
        raw.markDirty();
        expect(invalidationCount, 2);
        expect(terminal.data, equals(['apple', 'banana', 'cherry']));

        terminal.deactivate();
      });

      test('2.3 markDirty() while inactive records dirty version and invalidates on reconnect', () {
        final raw = RawWhatController<int>(100);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => invalidationCount++);

        // Inactive: calling markDirty bumps dirty version internally
        raw.markDirty();
        expect(invalidationCount, 0);

        // Activation connects to upstream: Q2: B drops onInvalidated and resolves lazily on pull
        terminal.activate();
        expect(terminal.data, 100);
        expect(invalidationCount, 0, reason: 'Q2: B - Reconnection does NOT trigger onInvalidated');

        // Active mutation
        raw.markDirty();
        expect(invalidationCount, 1, reason: 'Active markDirty invalidates immediately');

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. Raw State Mutation & Unconditional Dirty Propagation
    // =========================================================================
    group('3. Raw State Mutation (No Distinct Filtering)', () {
      test('3.1 Setting identical value unconditionally broadcasts dirty pulse', () {
        final raw = RawWhatController<int>(5);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.data, 5);
        expect(invalidationCount, 0);

        // Duplicate value via property setter
        raw.data = 5;
        expect(invalidationCount, 1);
        expect(terminal.data, 5); // Pull resets pending state under Q1: A

        // Duplicate value via set()
        raw.set(5);
        expect(invalidationCount, 2);
        expect(terminal.data, 5);

        // Different value
        raw.set(10);
        expect(invalidationCount, 3);
        expect(terminal.data, 10);

        terminal.deactivate();
      });

      test('3.2 setGuarded works on RawWhat', () {
        final raw = RawWhatController<int>(1);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        raw.setGuarded(() => 20);
        expect(terminal.data, 20);
        expect(invalidationCount, 1);

        // Thrown exception transitions to error state
        raw.setGuarded(() => throw Exception('GuardedFailure'));
        expect(terminal.hasError, isTrue);
        expect(invalidationCount, 2);

        terminal.deactivate();
      });

      test('3.3 empty() transitions to empty state and broadcasts dirty', () {
        final raw = RawWhatController<int>(50);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.hasData, isTrue);

        raw.empty();
        expect(terminal.isEmpty, isTrue);
        expect(invalidationCount, 1);

        terminal.deactivate();
      });

      test('3.4 setError() transitions to error state and broadcasts dirty', () {
        final raw = RawWhatController<int>(50);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        raw.setError('CustomError');
        expect(terminal.hasError, isTrue);
        expect(terminal.error, 'CustomError');
        expect(invalidationCount, 1);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 4. RawWhat.late & RawWhat.error Constructors
    // =========================================================================
    group('4. RawWhat.late & RawWhat.error', () {
      test('4.1 RawWhat.late starts in empty state and transitions on set', () {
        final rawLate = RawWhatController<String>.late();
        expect(rawLate.isEmpty, isTrue);

        int invalidationCount = 0;
        final terminal = RawWhatTerminal(rawLate.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.isEmpty, isTrue);
        expect(invalidationCount, 0);

        rawLate.data = 'initialized';
        expect(terminal.data, 'initialized');
        expect(invalidationCount, 1);

        // Duplicate value on RawWhat still emits dirty pulse
        rawLate.data = 'initialized';
        expect(invalidationCount, 2);

        terminal.deactivate();
      });

      test('4.2 RawWhat.error starts in error state and propagates duplicate errors', () {
        final rawErr = RawWhatController<int>.error('InitialError');
        expect(rawErr.hasError, isTrue);

        int invalidationCount = 0;
        final terminal = RawWhatTerminal(rawErr.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.hasError, isTrue);

        // Re-injecting error propagates in RawWhat
        rawErr.setError('InitialError');
        expect(invalidationCount, 1);
        expect(terminal.hasError, isTrue); // Pull resets pending state under Q1: A

        // Recover with set
        rawErr.set(999);
        expect(terminal.data, 999);
        expect(invalidationCount, 2);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 5. Factory Functor: what.dataOrNull
    // =========================================================================
    group('5. what.dataOrNull Functor', () {
      test('5.1 what.dataOrNull creates RawWhat', () {
        final r1 = RawWhatController(123);
        expect(r1, isA<RawWhatController<int>>());
        expect(r1, isA<WhatController<int>>());
        expect(r1.data, 123);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(r1.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        r1.markDirty();
        expect(dirtyCount, 1);

        terminal.deactivate();
      });

      test('5.2 what.dataOrNull.late and what.dataOrNull.error functors work', () {
        final lateRaw = RawWhatController<double>.late();
        expect(lateRaw, isA<RawWhatController<double>>());
        expect(lateRaw.isEmpty, isTrue);

        final errRaw = RawWhatController<double>.error('Err1');
        expect(errRaw, isA<RawWhatController<double>>());
        expect(errRaw.hasError, isTrue);
      });
    });

    // =========================================================================
    // 6. Lifecycle Hooks on RawWhat
    // =========================================================================
    group('6. Lifecycle Hooks on RawWhat', () {
      test('6.1 onActivated and onDeactivated are called correctly', () {
        int activatedCount = 0;
        int deactivatedCount = 0;

        final raw = RawWhatController<int>(
          0,
          onActivated: () => activatedCount++,
          onDeactivated: () => deactivatedCount++,
        );

        expect(activatedCount, 0);
        expect(deactivatedCount, 0);

        final terminal = RawWhatTerminal(raw.what, onInvalidated: () {});
        terminal.activate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 0);

        terminal.deactivate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 1);
      });

      test('6.2 Graceful deactivation works on RawWhat', () async {
        int deactivatedCount = 0;

        final raw = RawWhatController<int>(
          0,
          onActivated: () {},
          onDeactivated: () => deactivatedCount++,
          graceful: Graceful.microtask,
        );

        final terminal = RawWhatTerminal(raw.what, onInvalidated: () {});
        terminal.activate();
        terminal.deactivate();

        // Deferred via microtask
        expect(deactivatedCount, 0);

        await Future<void>.delayed(Duration.zero);
        expect(deactivatedCount, 1);
      });
    });
  });
}
