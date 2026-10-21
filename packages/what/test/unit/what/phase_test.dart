// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('WhatPhase Enum', () {
    test('values contains exactly valid, empty, and error in order', () {
      expect(WhatPhase.values, equals([WhatPhase.valid, WhatPhase.empty, WhatPhase.error]));
    });

    test('phases are mutually exclusive and distinct', () {
      expect(WhatPhase.valid, isNot(equals(WhatPhase.empty)));
      expect(WhatPhase.valid, isNot(equals(WhatPhase.error)));
      expect(WhatPhase.empty, isNot(equals(WhatPhase.error)));
    });
  });

  group('WhatSnapshot.phase', () {
    test('valid snapshot yields WhatPhase.valid', () {
      const snapshot = WhatSnapshot<int>(42);
      expect(snapshot.phase, equals(WhatPhase.valid));
    });

    test('empty snapshot yields WhatPhase.empty', () {
      const snapshot = WhatSnapshot<int>.empty('AwaitingValue');
      expect(snapshot.phase, equals(WhatPhase.empty));
    });

    test('error snapshot yields WhatPhase.error', () {
      final snapshot = WhatSnapshot<int>.error(FormatException('invalid'));
      expect(snapshot.phase, equals(WhatPhase.error));
    });
  });

  group('WhatController.phase & State Transitions', () {
    test('initial phases align with constructor variants', () {
      final validController = WhatController<int>(10);
      final emptyController = WhatController<int>.late();
      final errorController = WhatController<int>.error(Exception('initial error'));

      expect(validController.phase, equals(WhatPhase.valid));
      expect(emptyController.phase, equals(WhatPhase.empty));
      expect(errorController.phase, equals(WhatPhase.error));
    });

    test('transitions update phase reactively', () {
      final controller = WhatController<int>.late();
      expect(controller.phase, equals(WhatPhase.empty));

      // Transition: empty -> valid
      controller.data = 100;
      expect(controller.phase, equals(WhatPhase.valid));

      // Transition: valid -> error
      controller.setError(StateError('failure'));
      expect(controller.phase, equals(WhatPhase.error));

      // Transition: error -> empty
      controller.empty('cleared');
      expect(controller.phase, equals(WhatPhase.empty));

      // Transition: empty -> valid
      controller.set(200);
      expect(controller.phase, equals(WhatPhase.valid));
    });
  });

  group('untracked.state(what).phase & Computed DAG Propagation', () {
    test('untracked.state reflects the underlying node phase', () {
      final controller = WhatController<String>('hello');
      expect(untracked.state(controller.what).phase, equals(WhatPhase.valid));

      controller.empty();
      expect(untracked.state(controller.what).phase, equals(WhatPhase.empty));

      controller.setError('bad');
      expect(untracked.state(controller.what).phase, equals(WhatPhase.error));
    });

    test('computed derivation propagates upstream phase deterministically', () {
      final a = WhatController<int>(5);
      final b = WhatController<int>(10);
      final sum = computed((via) => via(a.what) + via(b.what));

      expect(untracked.state(sum).phase, equals(WhatPhase.valid));
      expect(untracked(sum), equals(15));

      // Upstream empty short-circuit -> computed becomes empty
      a.empty('prereq missing');
      expect(untracked.state(sum).phase, equals(WhatPhase.empty));

      // Upstream error short-circuit -> computed becomes error
      b.setError(RangeError('out of bounds'));
      expect(untracked.state(sum).phase, equals(WhatPhase.empty)); // a is still empty and short-circuits first

      a.data = 5;
      expect(untracked.state(sum).phase, equals(WhatPhase.error)); // now b's error surfaces
    });
  });

  group('Dart 3 Exhaustive Pattern Matching on phase', () {
    String describeState(WhatState<int> state) {
      return switch (state.phase) {
        WhatPhase.valid => 'Data: ${state.data}',
        WhatPhase.empty => 'Empty: ${state.emptyReason}',
        WhatPhase.error => 'Error: ${state.error}',
      };
    }

    test('exhaustive switch executes correct branches without wildcard', () {
      final valid = WhatSnapshot<int>(99);
      final empty = WhatSnapshot<int>.empty('no input');
      final error = WhatSnapshot<int>.error('crash');

      expect(describeState(valid), equals('Data: 99'));
      expect(describeState(empty), equals('Empty: no input'));
      expect(describeState(error), equals('Error: crash'));
    });

    test('Dart 3 Object Pattern matching on WhatState with phase', () {
      String matchObject(WhatState<int> state) {
        return switch (state) {
          WhatState(phase: WhatPhase.valid, :final data) => 'Resolved: $data',
          WhatState(phase: WhatPhase.empty, :final emptyReason) => 'Pending: $emptyReason',
          WhatState(phase: WhatPhase.error, :final error) => 'Failed: $error',
        };
      }

      expect(matchObject(WhatSnapshot(1)), equals('Resolved: 1'));
      expect(matchObject(WhatSnapshot.empty('wait')), equals('Pending: wait'));
      expect(matchObject(WhatSnapshot.error('fail')), equals('Failed: fail'));
    });
  });

  group('WhatStateCollectionExtension.wherePhase', () {
    test('filters collection by operational phase', () {
      final list = <WhatState<int>>[
        WhatSnapshot(1),
        WhatSnapshot.empty(),
        WhatSnapshot(2),
        WhatSnapshot.error('e1'),
        WhatSnapshot.empty('reason'),
      ];

      final validItems = list.wherePhase(WhatPhase.valid).toList();
      final emptyItems = list.wherePhase(WhatPhase.empty).toList();
      final errorItems = list.wherePhase(WhatPhase.error).toList();

      expect(validItems, hasLength(2));
      expect(validItems.map((e) => e.data), equals([1, 2]));

      expect(emptyItems, hasLength(2));
      expect(errorItems, hasLength(1));
    });
  });
}
