// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Take Parameter on Effect Tests', () {
    test('1. Effect with take: 1 executes exactly once and tears down', () async {
      final counter = WhatController<int>(0);
      int runs = 0;

      final effect = Effect.unary(counter.what, () {
        runs++;
      }, take: 1);
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      expect(runs, 0, reason: 'Manifest effect skips initial execution');

      // Mutation 1: executes action
      counter.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Mutation 2: should NOT execute
      counter.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1, reason: 'Effect must not execute beyond take limit');

      terminal.deactivate();
    });

    test('2. Reactivation Guard: once exhausted, reviving parent scope cannot revive the effect', () async {
      final counter = WhatController<int>(0);
      int runs = 0;

      final effect = Effect.unary(counter.what, () {
        runs++;
      }, take: 1);
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      counter.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      // Attempt to revive by cycling parent terminal deactivation & reactivation
      terminal.deactivate();
      terminal.activate();
      terminal.evaluate();

      counter.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1, reason: 'Exhausted effect remains permanently dead even if scope reactivates');

      terminal.deactivate();
    });

    test('3. Effect with take: 3 executes exactly 3 times then deactivates', () async {
      final source = WhatController<int>(0);
      final observed = <int>[];

      final effect = Effect.unary(source.what, () {
        observed.add(source.data);
      }, take: 3);
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      source.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(observed, [1]);

      source.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(observed, [1, 2]);

      source.set(3);
      await Future<void>.delayed(Duration.zero);
      expect(observed, [1, 2, 3]);

      // 4th mutation: ignored
      source.set(4);
      await Future<void>.delayed(Duration.zero);
      expect(observed, [1, 2, 3]);

      terminal.deactivate();
    });

    test('4. Effect with take: 0 is permanently inactive and never executes', () async {
      final source = WhatController<int>(0);
      int runs = 0;

      final effect = Effect.unary(source.what, () {
        runs++;
      }, take: 0);
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      source.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 0);

      terminal.deactivate();
    });

    test('5. Negative take throws RangeError on construction', () {
      final source = WhatController<int>(0);
      expect(
        () => Effect.unary(source.what, () {}, take: -1),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => source.what.effect(() {}, take: -1),
        throwsA(isA<RangeError>()),
      );
    });

    test('6. Multi-target list effect respects take parameter', () async {
      final a = WhatController<int>(0);
      final b = WhatController<int>(0);
      int runs = 0;

      final effect = Effect([a.what, b.what], () {
        runs++;
      }, take: 2);
      final terminal = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {})
        ..activate()
        ..evaluate();

      a.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      b.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      a.set(2);
      b.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      terminal.deactivate();
    });

    test('7. Scope-bound Effect with take: 2 executes at most 2 times and self-deactivates', () async {
      final counter = WhatController<int>(0);
      int runs = 0;

      final effect = counter.what.effect(() {
        runs++;
      }, take: 2);

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      expect(runs, 0);

      counter.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);

      counter.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      // Third mutation should not trigger
      counter.set(3);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);

      terminal.deactivate();
    });
  });
}
