// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('Zero-Allocation _BatchScope & Batch System Suite', () {
    test('1. Single batch coalesces multiple mutations into a single terminal flush', () {
      final a = WhatController(1);
      final b = WhatController(2);
      final c = WhatController(3);

      final sum = computed<int>((via) => (via(a.what) + via(b.what) + via(c.what)).toInt());

      var notificationCount = 0;
      int? lastNotifiedValue;

      final terminal = RawWhatTerminal(sum, onInvalidated: () {
        notificationCount++;
        lastNotifiedValue = untracked(sum);
      });
      terminal.activate();

      expect(untracked(sum), equals(6));
      expect(notificationCount, equals(0));

      // Batch 3 mutations together
      batch(() {
        a.data = 10;
        b.data = 20;
        c.data = 30;

        // Inside batch, terminal should not have fired yet
        expect(notificationCount, equals(0));
      });

      // After batch exits, exactly one notification must be delivered
      expect(notificationCount, equals(1));
      expect(lastNotifiedValue, equals(60));
      expect(untracked(sum), equals(60));

      terminal.deactivate();
    });

    test('2. Nested batch coalesces to the outermost batch boundary', () {
      final first = WhatController('A');
      final last = WhatController('B');
      final age = WhatController(20);

      final profile = computed((via) => '${via(first.what)} ${via(last.what)} (${via(age.what)})');

      var notificationCount = 0;
      String? lastNotifiedProfile;

      final terminal = RawWhatTerminal(profile, onInvalidated: () {
        notificationCount++;
        lastNotifiedProfile = untracked(profile);
      });
      terminal.activate();

      expect(untracked(profile), equals('A B (20)'));
      expect(notificationCount, equals(0));

      batch(() {
        first.data = 'John';

        // Inner nested batch 1
        batch(() {
          last.data = 'Doe';

          // Deeply nested batch 2
          batch(() {
            age.data = 30;
          });

          // Inner batches should not flush
          expect(notificationCount, equals(0));
        });

        // Exiting inner batches still keeps notification deferred
        expect(notificationCount, equals(0));

        age.data = 31;
      });

      // Outermost batch finishes -> Single flush with all nested changes
      expect(notificationCount, equals(1));
      expect(lastNotifiedProfile, equals('John Doe (31)'));
      expect(untracked(profile), equals('John Doe (31)'));

      terminal.deactivate();
    });

    test('3. RYOW (Read-Your-Own-Writes) and multiple writes to the same entry in batch', () {
      final a = WhatController(1);
      final derived = computed((via) => via(a.what) * 10);

      var notificationCount = 0;
      int? lastNotified;

      final terminal = RawWhatTerminal(derived, onInvalidated: () {
        notificationCount++;
        lastNotified = untracked(derived);
      });
      terminal.activate();

      expect(untracked(derived), equals(10));
      expect(notificationCount, equals(0));

      batch(() {
        a.data = 2;

        // RYOW: Reading derived immediately reflects the eager dirty propagation!
        expect(untracked(derived), equals(20));

        // Terminal notification remains deferred
        expect(notificationCount, equals(0));

        // Write again to the same entry after derived became clean
        a.data = 5;

        // RYOW: Reading again re-evaluates cleanly
        expect(untracked(derived), equals(50));
        expect(notificationCount, equals(0));

        a.data = 10;
      });

      // Outermost batch exit flushes exactly once with the latest value (100)
      expect(notificationCount, equals(1));
      expect(lastNotified, equals(100));
      expect(untracked(derived), equals(100));

      terminal.deactivate();
    });

    test('4. Glitch-Free Diamond Dependency Graph in batch', () {
      // Diamond:
      //       a
      //      / \
      //   left  right
      //      \ /
      //      sum
      final a = WhatController(1);
      final left = computed<int>((via) => via(a.what) * 2);
      final right = computed<int>((via) => via(a.what) + 10);
      final sum = computed<int>((via) => via(left) + via(right));

      final observations = <int>[];
      final terminal = RawWhatTerminal(sum, onInvalidated: () {
        observations.add(untracked(sum));
      });
      terminal.activate();

      // Initial state: left=2, right=11, sum=13.
      expect(untracked(sum), equals(13));
      expect(observations, isEmpty);

      batch(() {
        a.data = 10; // left should be 20, right should be 20, sum should be 40
      });

      // Exactly 1 notification, absolutely no intermediate glitches
      expect(observations, equals([40]));
      expect(untracked(sum), equals(40));

      terminal.deactivate();
    });

    test('5. Exception in batch safely releases lock and maintains consistency', () async {
      final count = WhatController(0);
      var notificationCount = 0;

      final terminal = RawWhatTerminal(count.what, onInvalidated: () {
        notificationCount++;
      });
      terminal.activate();

      expect(count.data, equals(0));
      expect(notificationCount, equals(0));

      expect(
        () => batch(() {
          count.data = 42;
          throw StateError('Intentional Batch Error');
        }),
        throwsStateError,
      );

      // Batch lock must be released even after uncaught exception
      expect(batch.isBatching, isFalse);

      // Terminal should be flushed to reflect the mutated state (42)
      expect(count.data, equals(42));
      expect(notificationCount, equals(1));

      // Wait for RawWhatTerminal's microtask coalescing guard to reset
      await pumpEventQueue();

      // Subsequent batches must continue to work normally
      batch(() {
        count.data = 100;
      });

      expect(count.data, equals(100));
      expect(notificationCount, equals(2));

      terminal.deactivate();
    });

    test('6. Reentrant mutation inside terminal notification callback during batch flush', () {
      final a = WhatController(1);
      final b = WhatController(10);

      var aFlushCount = 0;
      var bFlushCount = 0;

      final bTerminal = RawWhatTerminal(b.what, onInvalidated: () {
        bFlushCount++;
      });
      bTerminal.activate();

      final aTerminal = RawWhatTerminal(a.what, onInvalidated: () {
        aFlushCount++;
        if (a.data == 2) {
          b.data = 20;
        }
      });
      aTerminal.activate();

      expect(a.data, equals(1));
      expect(b.data, equals(10));
      expect(aFlushCount, equals(0));
      expect(bFlushCount, equals(0));

      batch(() {
        a.data = 2;
      });

      // Trampoline loop must absorb reentrant mutation cleanly
      expect(aFlushCount, equals(1));
      expect(bFlushCount, equals(1));
      expect(b.data, equals(20));

      aTerminal.deactivate();
      bTerminal.deactivate();
    });

    test('7. Empty batch without mutations executes cleanly with zero side-effects', () {
      expect(batch.isBatching, isFalse);

      final result = batch(() {
        expect(batch.isBatching, isTrue);
        return 42;
      });

      expect(result, equals(42));
      expect(batch.isBatching, isFalse);
    });
  });
}
