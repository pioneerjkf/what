// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Throttle Effect Comprehensive Unit Tests', () {
    test('1. Default throttle (leading: true, trailing: true) fires on leading edge and trailing edge', () async {
      final query = WhatController<String>('initial');
      final observed = <String>[];

      final effect = ThrottleEffect.unary(
        query.what,
        const Duration(milliseconds: 50),
        () => observed.add(query.data),
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      // Mutation 1: Leading edge executes immediately in microtask
      query.set('alpha');
      await Future<void>.delayed(Duration.zero);
      expect(observed, ['alpha'], reason: 'Leading edge must fire in microtask');

      // Rapid mutations during throttle window:
      query.set('beta');
      query.set('gamma');
      await Future<void>.delayed(Duration.zero);
      expect(observed, ['alpha'], reason: 'Intermediate mutations must be suppressed');

      // Wait for throttle window (50ms) to elapse:
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(observed, ['alpha', 'gamma'], reason: 'Trailing edge must fire with latest value');

      terminal.deactivate();
    });

    test('2. Leading-only throttle (leading: true, trailing: false) ignores mutations during window', () async {
      final click = WhatController<int>(0);
      int runs = 0;

      final effect = ThrottleEffect.unary(
        click.what,
        const Duration(milliseconds: 50),
        () => runs++,
        trailing: false,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      // First click: fires
      click.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Subsequent clicks during 50ms window:
      click.set(2);
      click.set(3);
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Trailing should NOT fire:
      expect(runs, 1);

      // New click after window elapsed:
      click.set(4);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      terminal.deactivate();
    });

    test('3. Trailing-only throttle (leading: false, trailing: true) delays first execution to window expiration',
        () async {
      final text = WhatController<String>('');
      final observed = <String>[];

      final effect = ThrottleEffect.unary(
        text.what,
        const Duration(milliseconds: 50),
        () => observed.add(text.data),
        leading: false,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      text.set('a');
      await Future<void>.delayed(Duration.zero);
      expect(observed, [], reason: 'Leading edge is disabled');

      text.set('ab');
      text.set('abc');
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(observed, ['abc'], reason: 'Trailing edge must fire when window elapses');

      terminal.deactivate();
    });

    test('4. Throttle with take limit deactivates and cleans up timer after limit reached', () async {
      final count = WhatController<int>(0);
      int runs = 0;

      final effect = ThrottleEffect.unary(
        count.what,
        const Duration(milliseconds: 40),
        () => runs++,
        take: 2,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      // 1st run (leading):
      count.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Cause trailing run:
      count.set(2);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(runs, 2);

      // Subsequent mutation:
      count.set(3);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(runs, 2, reason: 'Exhausted throttle effect must not execute');

      terminal.deactivate();
    });

    test('5. Multi-target throttle on list of targets', () async {
      final a = WhatController<int>(0);
      final b = WhatController<int>(0);
      int runs = 0;

      final effect = ThrottleEffect(
        [a.what, b.what],
        const Duration(milliseconds: 50),
        () => runs++,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      a.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      b.set(1);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 2);

      terminal.deactivate();
    });

    test('6. Deactivation cancels pending throttle timer and prevents ghost executions', () async {
      final source = WhatController<int>(0);
      int runs = 0;

      final effect = ThrottleEffect.unary(
        source.what,
        const Duration(milliseconds: 50),
        () => runs++,
      );
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      source.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Invalidate for trailing execution:
      source.set(2);

      // Deactivate immediately before window expires:
      terminal.deactivate();

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 1, reason: 'Cancelled throttle timer must not fire ghost execution');
    });

    test('7. Scope-bound ThrottleEffect works with fluent extension', () async {
      final query = WhatController<String>('initial');
      final observed = <String>[];

      final effect = query.what.effect.throttle(
        const Duration(milliseconds: 40),
        () => observed.add(query.data),
      );

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      query.set('step1');
      await Future<void>.delayed(Duration.zero);
      expect(observed, ['step1']);

      query.set('step2');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(observed, ['step1', 'step2']);

      terminal.deactivate();
    });

    test('8. Throttle with leading: false and trailing: false throws AssertionError', () {
      final click = WhatController<int>(0);
      expect(
        () => ThrottleEffect.unary(
          click.what,
          const Duration(milliseconds: 50),
          () {},
          leading: false,
          trailing: false,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ThrottleEffect(
          [click.what],
          const Duration(milliseconds: 50),
          () {},
          leading: false,
          trailing: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('9. ThrottleEffect forwards uncaught errors to onUncaughtError', () async {
      final click = WhatController<int>(0);
      Object? caughtError;

      final effect = click.what.effect.throttle(
        const Duration(milliseconds: 30),
        () => throw StateError('Throttle action failed'),
        onUncaughtError: (error, stack) {
          caughtError = error;
        },
      );

      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      click.set(1);
      await Future<void>.delayed(Duration.zero);

      expect(caughtError, isA<StateError>());
      expect((caughtError as StateError).message, 'Throttle action failed');

      terminal.deactivate();
    });
  });
}
