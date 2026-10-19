// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:test/test.dart';
import 'package:what/effect.dart';
import 'package:what/what.dart';

void main() {
  group('Shared Effect Multi-Scope Lifecycle & Ref-Counting Tests', () {
    test(
        '1. Shared Effect stays active while at least one scope is active, goes dormant when all scopes unmount, and revives on remount',
        () async {
      final source = WhatController<int>(0);
      var effectRuns = 0;
      var observed = -1;

      final sharedEffect = source.what.effect(() {
        effectRuns++;
        observed = source.data;
      });

      // Scope A
      final scopeA = RawViaTerminal((via) {
        via.tether(sharedEffect);
        return 'ScopeA';
      }, onInvalidated: () {});

      // Scope B
      final scopeB = RawViaTerminal((via) {
        via.tether(sharedEffect);
        return 'ScopeB';
      }, onInvalidated: () {});

      // Initially, neither scope is active -> effect is inactive
      expect(effectRuns, 0);
      expect(sharedEffect.isActive, isFalse);

      // 1. Mount Scope A -> effect activates
      scopeA.activate();
      scopeA.evaluate();
      expect(sharedEffect.isActive, isTrue);

      source.set(1);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observed, 1);

      // 2. Mount Scope B -> effect now shared by both scopes (refCount == 2)
      scopeB.activate();
      scopeB.evaluate();
      expect(sharedEffect.isActive, isTrue);

      source.set(2);
      await Future<void>.delayed(Duration.zero);
      // Must execute exactly once for the single shared effect!
      expect(effectRuns, 2);
      expect(observed, 2);

      // 3. Unmount Scope A -> effect remains active because Scope B is still active!
      scopeA.deactivate();
      expect(sharedEffect.isActive, isTrue);

      source.set(3);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 3);
      expect(observed, 3);

      // 4. Unmount Scope B -> all scopes unmounted -> effect enters dormancy (deactivated)!
      scopeB.deactivate();
      expect(sharedEffect.isActive, isFalse);

      source.set(4);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 3, reason: 'Dormant effect must not run when all host scopes unmounted');

      // 5. Remount Scope A -> effect revives!
      scopeA.activate();
      scopeA.evaluate();
      expect(sharedEffect.isActive, isTrue);

      source.set(5);
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 4, reason: 'Revived effect must resume running on mutations');
      expect(observed, 5);

      scopeA.deactivate();
    });

    test('2. Zero rebuild invariant: parent scopes are never invalidated by shared effect execution', () async {
      final counter = WhatController<int>(0);
      var scopeAInvalidations = 0;
      var scopeBInvalidations = 0;
      var effectRuns = 0;

      final sharedEffect = counter.what.effect(() => effectRuns++);

      final scopeA = RawViaTerminal(
        (via) {
          via.tether(sharedEffect);
          return 'A';
        },
        onInvalidated: () => scopeAInvalidations++,
      );

      final scopeB = RawViaTerminal(
        (via) {
          via.tether(sharedEffect);
          return 'B';
        },
        onInvalidated: () => scopeBInvalidations++,
      );

      scopeA.activate();
      scopeA.evaluate();
      scopeB.activate();
      scopeB.evaluate();

      counter.set(100);
      await Future<void>.delayed(Duration.zero);

      expect(effectRuns, 1);
      expect(scopeAInvalidations, 0, reason: 'Scope A must never receive dirty invalidation from effect');
      expect(scopeBInvalidations, 0, reason: 'Scope B must never receive dirty invalidation from effect');

      scopeA.deactivate();
      scopeB.deactivate();
    });
  });
}
