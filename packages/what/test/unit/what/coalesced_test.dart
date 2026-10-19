// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('What.coalesced() Comprehensive Unit Tests', () {
    test('1. Bursty mutations within same turn coalesce into single trailing notification', () async {
      final counter = WhatController(0, distinct: false);
      final coalesced = counter.what.coalesced();

      int invalidationCount = 0;
      final terminal = RawWhatTerminal(coalesced, onInvalidated: () => invalidationCount++);
      terminal.activate();

      expect(terminal.data, 0);
      expect(invalidationCount, 0);

      // Rapid burst of 100 mutations in the same event loop turn
      for (int i = 1; i <= 100; i++) {
        counter.data = i;
      }

      // Synchronously, no notification has leaked downstream yet (trailing default)
      expect(invalidationCount, 0);

      // Wait for microtask to flush
      await Future<void>.delayed(Duration.zero);

      // Exactly 1 coalesced invalidation dispatched for the entire burst
      expect(invalidationCount, 1);
      // Pulls fresh resolved state
      expect(terminal.data, 100);

      // Next mutation in a new turn fires next coalesced cycle
      counter.data = 101;
      expect(invalidationCount, 1); // Not flushed yet

      await Future<void>.delayed(Duration.zero);
      expect(invalidationCount, 2);
      expect(terminal.data, 101);

      terminal.deactivate();
    });

    test('2. Leading-only coalescing (leading: true, trailing: false) fires immediately and silences burst', () async {
      final counter = WhatController(0, distinct: false);
      final coalesced = counter.what.coalesced(leading: true, trailing: false);

      int invalidationCount = 0;
      final terminal = RawWhatTerminal(coalesced, onInvalidated: () => invalidationCount++);
      terminal.activate();

      expect(terminal.data, 0);
      expect(invalidationCount, 0);

      // First mutation fires leading notification immediately
      counter.data = 1;
      expect(invalidationCount, 1);

      // Subsequent burst within same turn is silenced
      for (int i = 2; i <= 10; i++) {
        counter.data = i;
      }
      expect(invalidationCount, 1);

      // After microtask finishes, cooldown is reset without trailing notification
      await Future<void>.delayed(Duration.zero);
      expect(invalidationCount, 1);
      expect(terminal.data, 10);

      // Next turn's first mutation fires leading again
      counter.data = 11;
      expect(invalidationCount, 2);

      terminal.deactivate();
    });

    test('3. Dual-edge coalescing (leading: true, trailing: true) fires leading then trailing after burst', () async {
      final counter = WhatController(0, distinct: false);
      final coalesced = counter.what.coalesced(leading: true, trailing: true);

      int invalidationCount = 0;
      final terminal = RawWhatTerminal(coalesced, onInvalidated: () => invalidationCount++);
      terminal.activate();

      expect(terminal.data, 0);
      expect(invalidationCount, 0);

      // First mutation fires leading immediately
      counter.data = 1;
      expect(invalidationCount, 1);

      // Bursty mutations trigger pending trailing
      counter.data = 2;
      counter.data = 3;
      expect(invalidationCount, 1); // Still 1 in same turn

      // Microtask expiration delivers trailing notification
      await Future<void>.delayed(Duration.zero);
      expect(invalidationCount, 2);
      expect(terminal.data, 3);

      terminal.deactivate();
    });

    test('4. Dual-edge coalescing with solitary mutation fires leading without redundant trailing', () async {
      final counter = WhatController(0, distinct: false);
      final coalesced = counter.what.coalesced(leading: true, trailing: true);

      int invalidationCount = 0;
      final terminal = RawWhatTerminal(coalesced, onInvalidated: () => invalidationCount++);
      terminal.activate();

      // Solitary mutation
      counter.data = 1;
      expect(invalidationCount, 1);

      // Microtask expires without additional mutations
      await Future<void>.delayed(Duration.zero);
      expect(invalidationCount, 1, reason: 'No redundant trailing pulse if no subsequent mutations arrived');
      expect(terminal.data, 1);

      terminal.deactivate();
    });

    test('5. Assertion error when both leading and trailing are false', () {
      final source = WhatController(1);
      expect(
        () => source.what.coalesced(leading: false, trailing: false),
        throwsA(isA<AssertionError>()),
      );
    });

    test('6. Deactivation cancels pending coalesced notification', () async {
      final counter = WhatController(0);
      final coalesced = counter.what.coalesced();

      int invalidationCount = 0;
      final terminal = RawWhatTerminal(coalesced, onInvalidated: () => invalidationCount++);
      terminal.activate();

      counter.data = 1;
      expect(invalidationCount, 0);

      // Deactivate before microtask runs
      terminal.deactivate();

      await Future<void>.delayed(Duration.zero);
      expect(invalidationCount, 0, reason: 'Deactivation cancels pending emission');
    });

    test('7. what.coalesced factory produces working coalesced relay', () async {
      final source = WhatController('initial');
      final coalesced = source.what.coalesced();

      final values = <String>[];
      final terminal = RawWhatTerminal(coalesced, onInvalidated: () => values.add(coalesced.peek));
      terminal.activate();

      expect(coalesced.peek, 'initial');

      source.data = 'step1';
      source.data = 'step2';
      source.data = 'step3';

      expect(values, isEmpty);

      await Future<void>.delayed(Duration.zero);
      expect(values, ['step3']);

      terminal.deactivate();
    });

    test('8. Full pipeline integration: source.coalesced() with computed works seamlessly', () async {
      final source = WhatController(10);
      final coalesced = source.what.coalesced();
      final pipeline = computed((via) {
        final doubled = via(coalesced) * 2;
        return doubled > 50 ? 'HIGH' : 'LOW';
      }).distinct();

      final captured = <String>[];
      final terminal = RawWhatTerminal(pipeline, onInvalidated: () => captured.add(pipeline.peek));
      terminal.activate();

      expect(terminal.data, 'LOW');

      // Burst of rapid changes
      for (int i = 11; i <= 30; i++) {
        source.data = i; // 30 * 2 = 60 -> 'HIGH'
      }

      expect(captured, isEmpty);

      await Future<void>.delayed(Duration.zero);
      expect(captured, ['HIGH']);

      terminal.deactivate();
    });

    test('9. Coalesced relay integrates with Effect on _Scheduler within single microtask pass', () async {
      final counter = WhatController(0);
      final coalesced = counter.what.coalesced();

      final effectValues = <int>[];
      final effect = coalesced.effect(() => effectValues.add(coalesced.peek));

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      expect(effectValues, isEmpty);

      for (int i = 1; i <= 10; i++) {
        counter.data = i;
      }

      expect(effectValues, isEmpty);

      await Future<void>.delayed(Duration.zero);

      expect(effectValues, [10]);

      terminal.deactivate();
    });
  });
}
