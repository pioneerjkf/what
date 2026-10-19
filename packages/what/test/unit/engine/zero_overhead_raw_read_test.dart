// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Phase W-2: Zero-Overhead Raw Read & Explicit Tracking Specification', () {
    test('1. Raw reads without via() do not establish dependency edges', () async {
      final a = WhatController(10);
      final b = WhatController(20);
      int computeCount = 0;

      // Only 'a' is explicitly tracked via `via(a)`.
      // 'b' is read directly via raw `.data`.
      final derived = computed((via) {
        computeCount++;
        return via(a.what) + b.data;
      });

      expect(computeCount, 0, reason: 'Lazy pull: not evaluated until accessed');
      expect(derived.peek, 30);
      expect(computeCount, 1);

      // Mutating 'b' (raw read, untracked) MUST NOT dirty 'derived'
      b.data = 99;
      expect(derived.peek, 30, reason: 'Untracked upstream mutation does not invalidate cache');
      expect(computeCount, 1, reason: 'Zero re-evaluation triggered by untracked raw read');

      // Mutating 'a' (tracked via via(a)) marks dirty and triggers recomputation on pull
      a.data = 15;
      expect(derived.peek, 114, reason: '15 + 99 = 114');
      expect(computeCount, 2);
    });

    test('2. All 10 state getters are zero-overhead and untracked without via()', () {
      final node = WhatController('Alpha');
      final emptyNode = WhatController<String>.late();
      final errorNode = What<String>.error('Fault');

      // Reading all 10 getters outside any scope
      expect(node.snapshot.data, 'Alpha');
      expect(node.data, 'Alpha');
      expect(node.dataOrNull, 'Alpha');
      expect(node.dataOrElse(() => 'Fallback'), 'Alpha');
      expect(node.hasData, isTrue);
      expect(node.isEmpty, isFalse);
      expect(emptyNode.emptyReason, isNull);
      expect(node.hasError, isFalse);
      expect(errorNode.peekState.error, 'Fault');
      expect(errorNode.peekState.stackTrace, isNotNull);

      // Inside computed with explicit tracking of another node
      final dummy = WhatController(1);
      final comp = computed((via) {
        via(dummy.what);
        // Direct read of all getters on 'node', 'emptyNode', 'errorNode' without via()
        node.snapshot;
        node.data;
        node.dataOrNull;
        node.dataOrElse(() => '');
        node.hasData;
        node.isEmpty;
        emptyNode.emptyReason;
        node.hasError;
        errorNode.peekState.error;
        errorNode.peekState.stackTrace;
        return 'Done';
      });

      expect(comp.peek, 'Done');

      // Mutating 'node' MUST NOT invalidate 'comp' because it was never passed to via()
      node.data = 'Beta';
      // comp is not dirty, re-read does not re-evaluate
      expect(comp.peek, 'Done');
    });

    test('3. Dynamic branching and 1-pass epoch sweeping with explicit via()', () async {
      final condition = WhatController(true);
      final branchA = WhatController('A');
      final branchB = WhatController('B');
      int computeRuns = 0;

      final dynamicNode = computed((via) {
        computeRuns++;
        return via(condition.what) ? via(branchA.what) : via(branchB.what);
      });

      expect(dynamicNode.peek, 'A');
      expect(computeRuns, 1);

      // Mutating branchB (unobserved in this epoch) does NOT dirty dynamicNode
      branchB.data = 'B_updated';
      expect(dynamicNode.peek, 'A');
      expect(computeRuns, 1);

      // Switch condition -> branchB becomes observed, branchA becomes unobserved
      condition.data = false;
      expect(dynamicNode.peek, 'B_updated');
      expect(computeRuns, 2);

      // Now mutating branchA MUST NOT dirty dynamicNode (pruned via epoch sweep)
      branchA.data = 'A_updated';
      expect(dynamicNode.peek, 'B_updated');
      expect(computeRuns, 2);
    });

    test('4. Effect with explicit via tracking triggers accurately on scheduled ticks', () async {
      final counter = WhatController(0);
      int effectRuns = 0;
      int observedValue = -1;

      final effect = Effect.via((via) {
        effectRuns++;
        observedValue = via(counter.what);
      });

      final terminal = RawViaTerminal((via) {
        via.tether(effect);
      }, onInvalidated: () {});

      terminal.activate();
      terminal.evaluate();

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observedValue, 0);

      counter.data = 42;
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 2);
      expect(observedValue, 42);

      terminal.deactivate();
      counter.data = 100;
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 2, reason: 'Deactivated effect does not run');
    });
  });
}
