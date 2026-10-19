// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('What State Pipeline Temporal Control Suite', () {
    group('1. DebouncedWhat (Trailing Edge - Default)', () {
      test('1.1 Rapid successive mutations are collapsed to the last value after silence', () async {
        final query = WhatController('a');
        final debouncedQuery = query.what.debounced(const Duration(milliseconds: 50));

        final observed = <String>[debouncedQuery.peek];
        final terminal = RawWhatTerminal(debouncedQuery, onInvalidated: () {
          observed.add(debouncedQuery.peek);
        });
        terminal.activate();

        expect(observed, ['a']);
        expect(debouncedQuery.peek, 'a');

        // Type rapidly
        query.data = 'ap';
        await Future<void>.delayed(const Duration(milliseconds: 20));
        query.data = 'app';
        await Future<void>.delayed(const Duration(milliseconds: 20));
        query.data = 'appl';
        await Future<void>.delayed(const Duration(milliseconds: 20));
        query.data = 'apple';

        // Before 50ms of silence, observed remains ['a']
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(observed, ['a']);

        // Wait past 50ms of silence
        await Future<void>.delayed(const Duration(milliseconds: 35));
        expect(observed, ['a', 'apple']);
        expect(debouncedQuery.peek, 'apple');

        terminal.deactivate();
      });

      test('1.2 Top-level factory what.debounced works identically', () async {
        final text = WhatController('start');
        final debouncedText = text.what.debounced(const Duration(milliseconds: 40));

        final notifications = <String>[debouncedText.peek];
        final terminal = RawWhatTerminal(debouncedText, onInvalidated: () {
          notifications.add(debouncedText.peek);
        });
        terminal.activate();

        text.data = 'change1';
        text.data = 'change2';
        text.data = 'final';

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(notifications, ['start', 'final']);

        terminal.deactivate();
      });
    });

    group('2. DebouncedWhat (Leading and Dual Edges)', () {
      test('2.1 Leading-only debounce propagates first mutation immediately and ignores subsequent in window',
          () async {
        final state = WhatController(1);
        final debounced = state.what.debounced(
          const Duration(milliseconds: 50),
          leading: true,
          trailing: false,
        );

        final observed = <int>[debounced.peek];
        final terminal = RawWhatTerminal(debounced, onInvalidated: () {
          observed.add(debounced.peek);
        });
        terminal.activate();

        expect(observed, [1]);

        // First mutation: fires immediately!
        state.data = 2;
        expect(observed, [1, 2]);

        // Subsequent mutations within 50ms are ignored
        await Future<void>.delayed(const Duration(milliseconds: 20));
        state.data = 3;
        state.data = 4;
        expect(observed, [1, 2]);

        // Wait past window (timer was reset at 20ms, so wait 60ms)
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(observed, [1, 2]);

        // Next mutation after cooldown fires immediately
        state.data = 5;
        expect(observed, [1, 2, 5]);

        terminal.deactivate();
      });

      test('2.2 Dual-edge debounce (leading: true, trailing: true) fires leading then trailing after silence',
          () async {
        final state = WhatController('A');
        final debounced = state.what.debounced(
          const Duration(milliseconds: 50),
          leading: true,
          trailing: true,
        );

        final observed = <String>[debounced.peek];
        final terminal = RawWhatTerminal(debounced, onInvalidated: () {
          observed.add(debounced.peek);
        });
        terminal.activate();

        expect(observed, ['A']);

        // First change: leading edge fires immediately
        state.data = 'B';
        expect(observed, ['A', 'B']);

        // Intermediate changes
        await Future<void>.delayed(const Duration(milliseconds: 20));
        state.data = 'C';
        await Future<void>.delayed(const Duration(milliseconds: 20));
        state.data = 'D';

        // Wait for silence
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(observed, ['A', 'B', 'D']);

        terminal.deactivate();
      });
    });

    group('3. ThrottledWhat (Rate-Limiting)', () {
      test('3.1 ThrottledWhat limits downstream notifications to window interval', () async {
        final scroll = WhatController(0.0);
        final throttledScroll = scroll.what.throttled(
          const Duration(milliseconds: 50),
          leading: true,
          trailing: true,
        );

        final observed = <double>[throttledScroll.peek];
        final terminal = RawWhatTerminal(throttledScroll, onInvalidated: () {
          observed.add(throttledScroll.peek);
        });
        terminal.activate();

        expect(observed, [0.0]);

        // Leading edge fires immediately
        scroll.data = 10.0;
        expect(observed, [0.0, 10.0]);

        // Rapid scrolling inside window
        await Future<void>.delayed(const Duration(milliseconds: 15));
        scroll.data = 25.0;
        await Future<void>.delayed(const Duration(milliseconds: 15));
        scroll.data = 50.0;

        // Inside window: not yet fired
        expect(observed, [0.0, 10.0]);

        // Past 50ms window: trailing edge fires with latest value (50.0)
        await Future<void>.delayed(const Duration(milliseconds: 35));
        expect(observed, [0.0, 10.0, 50.0]);

        terminal.deactivate();
      });

      test('3.2 what.throttled factory creates functioning rate limiter', () async {
        final counter = WhatController(0);
        final throttled = counter.what.throttled(
          const Duration(milliseconds: 40),
          leading: false,
          trailing: true,
        );

        final observed = <int>[throttled.peek];
        final terminal = RawWhatTerminal(throttled, onInvalidated: () {
          observed.add(throttled.peek);
        });
        terminal.activate();

        expect(observed, [0]);

        counter.data = 1;
        counter.data = 2;
        counter.data = 3;

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(observed, [0, 3]);

        terminal.deactivate();
      });
    });

    group('4. Zero-Leak Deactivation & Resilience', () {
      test('4.1 Deactivating node cancels running timers without leaking or throwing', () async {
        final source = WhatController('live');
        final debounced = source.what.debounced(const Duration(milliseconds: 50));

        final terminal = RawWhatTerminal(debounced, onInvalidated: () {});
        terminal.activate();

        source.data = 'updated';
        // Now timer is running. Deactivate terminal before timer expires:
        terminal.deactivate();

        // Wait past timer duration
        await Future<void>.delayed(const Duration(milliseconds: 70));

        // Node should safely reactivate and pull latest state on demand
        terminal.activate();
        expect(debounced.peek, 'updated');

        terminal.deactivate();
      });

      test('4.2 Invalid configuration assert(leading || trailing) fails early', () {
        final source = WhatController(42);
        expect(
          () => source.what.debounced(
            const Duration(milliseconds: 50),
            leading: false,
            trailing: false,
          ),
          throwsA(isA<AssertionError>()),
        );

        expect(
          () => source.what.throttled(
            const Duration(milliseconds: 50),
            leading: false,
            trailing: false,
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('5. Full Reactive Pipeline Integration (SWR / computed.future)', () {
      test('5.1 Debounced state seamlessly feeds computed.future with retained() SWR', () async {
        final query = WhatController('init');
        final debounced = query.what.debounced(const Duration(milliseconds: 40));

        var apiCallCount = 0;
        final searchResults = computed.future((via) {
          final currentQuery = via(debounced);
          apiCallCount++;
          return Future<String>.delayed(
            const Duration(milliseconds: 20),
            () => 'Result for: $currentQuery',
          );
        }).retained();

        final terminal = RawWhatTerminal(searchResults, onInvalidated: () {});
        terminal.activate();

        // Initial fetch starts
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(searchResults.peek, 'Result for: init');
        expect(apiCallCount, 1);

        // Rapid query changes
        query.data = 'fl';
        await Future<void>.delayed(const Duration(milliseconds: 15));
        query.data = 'flu';
        await Future<void>.delayed(const Duration(milliseconds: 15));
        query.data = 'flutter';

        // Wait for debounce silence (40ms) + future computation (20ms)
        await Future<void>.delayed(const Duration(milliseconds: 75));

        expect(searchResults.peek, 'Result for: flutter');
        // Only 1 initial call + 1 debounced call = 2 total API calls!
        expect(apiCallCount, 2);

        terminal.deactivate();
      });
    });
  });
}
