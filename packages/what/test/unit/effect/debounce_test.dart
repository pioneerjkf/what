// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Debounce Effect Comprehensive Unit Tests', () {
    test('1. Default debounce (leading: false) resets timer on consecutive mutations and fires once after silence',
        () async {
      final input = WhatController<String>('');
      final observed = <String>[];

      final effect = DebounceEffect.unary(
        input.what,
        const Duration(milliseconds: 50),
        () => observed.add(input.data),
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      // Rapid typing simulation:
      input.set('u');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      input.set('us');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      input.set('use');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      input.set('user');

      // Zero runs so far because timer kept getting reset:
      expect(observed, []);

      // Wait for 70ms of silence:
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Fires exactly once with the final settled value:
      expect(observed, ['user']);

      terminal.deactivate();
    });

    test(
        '2. Leading-only debounce (leading: true, trailing: false) fires immediately on first burst then silences until window expires',
        () async {
      final query = WhatController<String>('');
      final observed = <String>[];

      final effect = DebounceEffect.unary(
        query.what,
        const Duration(milliseconds: 50),
        () => observed.add(query.data),
        leading: true,
        trailing: false,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      // First keystroke: fires immediately in microtask
      query.set('f');
      await Future<void>.delayed(Duration.zero);
      expect(observed, ['f']);

      // Subsequent keystrokes during debounce duration:
      query.set('fl');
      query.set('flu');
      query.set('flut');
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // With leading: true and trailing: false, only the first hit fires:
      expect(observed, ['f']);

      // Next mutation after silence window has elapsed:
      query.set('flutter');
      await Future<void>.delayed(Duration.zero);
      expect(observed, ['f', 'flutter']);

      terminal.deactivate();
    });

    test('3. Debounce with take limit self-deactivates after limit is reached', () async {
      final search = WhatController<String>('');
      int runs = 0;

      final effect = DebounceEffect.unary(
        search.what,
        const Duration(milliseconds: 40),
        () => runs++,
        take: 1,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      search.set('query 1');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(runs, 1);

      // Subsequent search:
      search.set('query 2');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(runs, 1, reason: 'Exhausted debounce effect must not execute');

      terminal.deactivate();
    });

    test('4. Multi-target debounce on list of targets', () async {
      final minPrice = WhatController<int>(0);
      final maxPrice = WhatController<int>(100);
      int runs = 0;

      final effect = DebounceEffect(
        [minPrice.what, maxPrice.what],
        const Duration(milliseconds: 50),
        () => runs++,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      minPrice.set(10);
      maxPrice.set(90);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      maxPrice.set(80);

      expect(runs, 0);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 1);

      terminal.deactivate();
    });

    test('5. Deactivation cancels pending debounce timer and prevents execution', () async {
      final source = WhatController<int>(0);
      int runs = 0;

      final effect = DebounceEffect.unary(
        source.what,
        const Duration(milliseconds: 50),
        () => runs++,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      source.set(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Deactivate while timer is counting down:
      terminal.deactivate();

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 0, reason: 'Cancelled debounce timer must not fire');
    });

    test('6. Scope-bound DebounceEffect works with fluent extension', () async {
      final input = WhatController<String>('');
      final observed = <String>[];

      final effect = input.what.effect.debounce(
        const Duration(milliseconds: 40),
        () => observed.add(input.data),
      );

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      input.set('a');
      await Future<void>.delayed(const Duration(milliseconds: 15));
      input.set('ab');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(observed, ['ab']);

      terminal.deactivate();
    });

    test(
        '7. Dual-edge debounce (leading: true, trailing: true) fires leading edge immediately and trailing edge after silence',
        () async {
      final search = WhatController<String>('');
      final observed = <String>[];

      final effect = DebounceEffect.unary(
        search.what,
        const Duration(milliseconds: 50),
        () => observed.add(search.data),
        leading: true,
        trailing: true,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      // First keystroke: Leading edge fires immediately
      search.set('a');
      await Future<void>.delayed(Duration.zero);
      expect(observed, ['a'], reason: 'Leading edge must fire immediately in microtask');

      // Burst of keystrokes while timer keeps extending
      await Future<void>.delayed(const Duration(milliseconds: 20));
      search.set('ap');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      search.set('app');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      search.set('apple');

      // Still only 'a' has fired because burst is ongoing
      expect(observed, ['a']);

      // Silence period (70ms > 50ms)
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Trailing edge fires with final settled value
      expect(observed, ['a', 'apple'], reason: 'Trailing edge must fire after silence window elapses');

      terminal.deactivate();
    });

    test('8. Debounce with leading: false and trailing: false throws AssertionError', () {
      final source = WhatController<int>(0);
      expect(
        () => DebounceEffect.unary(
          source.what,
          const Duration(milliseconds: 50),
          () {},
          leading: false,
          trailing: false,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => DebounceEffect(
          [source.what],
          const Duration(milliseconds: 50),
          () {},
          leading: false,
          trailing: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('9. DebounceEffect forwards uncaught errors to onUncaughtError', () async {
      final source = WhatController<int>(0);
      Object? caughtError;

      final effect = source.what.effect.debounce(
        const Duration(milliseconds: 30),
        () => throw StateError('Debounce action failed'),
        onUncaughtError: (error, stack) {
          caughtError = error;
        },
      );

      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      source.set(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(caughtError, isA<StateError>());
      expect((caughtError as StateError).message, 'Debounce action failed');

      terminal.deactivate();
    });
  });
}
