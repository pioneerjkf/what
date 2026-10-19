// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/effect.dart';
import 'package:what/what.dart';

void main() {
  group('What Read Surface: peek and peekState (A5, D3, D8, D9)', () {
    test('x.peek returns value, throws WhatSnapshotExtractionException on Empty/Error', () {
      final ctrl = WhatController<int>(42);
      expect(ctrl.what.peek, equals(42));

      ctrl.set(100);
      expect(ctrl.what.peek, equals(100));

      ctrl.empty('reset');
      expect(() => ctrl.what.peek, throwsA(isA<WhatSnapshotExtractionException>()));

      ctrl.setError('fail');
      expect(() => ctrl.what.peek, throwsA(isA<WhatSnapshotExtractionException>()));
    });

    test('x.what.data and x.what.isEmpty are compile-time errors (untracked reads require peek/peekState)', () {
      // Invariant: What<T> does not implement WhatState<T> on its public static surface.
      // Therefore, inside or outside closures:
      //   ctrl.what.data    --> Compile-time Error: undefined_getter
      //   ctrl.what.isEmpty --> Compile-time Error: undefined_getter
      // Untracked reads must explicitly route through .peek (value) or .peekState (state view).
      final ctrl = WhatController<int>(10);
      expect(ctrl.what.peek, equals(10));
      expect(ctrl.what.peekState.hasData, isTrue);
      expect(ctrl.what.peekState.isEmpty, isFalse);
    });

    test('identical(via.state(x), x.peekState) - both return the node itself', () {
      final ctrl = WhatController<int>(10);
      WhatState<int>? viaState;

      final comp = computed((via) {
        viaState = via.state(ctrl.what);
        return via(ctrl.what) * 2;
      });

      // Trigger computation
      final r = comp.effect(() {}).run();

      expect(viaState, isNotNull);
      expect(identical(viaState, ctrl.what), isTrue);
      expect(identical(ctrl.what.peekState, ctrl.what), isTrue);
      expect(identical(viaState, ctrl.what.peekState), isTrue);

      r.deactivate();
    });

    test('via.state(x) captured view observes current live state across Valid->Valid and Valid->Empty->Valid',
        () async {
      final src = WhatController<int>(1);
      final captured = <WhatState<int>>[];

      final derived = computed((via) {
        final s = via.state(src.what);
        captured.add(s);
        return via(src.what) * 10;
      });

      final r = derived.effect(() {}).run();
      await Future<void>.delayed(Duration.zero);

      expect(captured.length, equals(1));
      expect(captured[0].hasData, isTrue);
      expect(captured[0].data, equals(1));

      // Valid -> Valid
      src.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(captured.length, equals(2));
      // Both captured instances are the node itself
      expect(identical(captured[0], src.what), isTrue);
      expect(identical(captured[1], src.what), isTrue);
      expect(captured[0].data, equals(2));
      expect(captured[1].data, equals(2));

      src.set(3);
      await Future<void>.delayed(Duration.zero);
      expect(captured.length, equals(3));
      expect(captured[0].data, equals(3));
      expect(captured[2].data, equals(3));

      // Valid -> Empty
      src.empty('reset');
      await Future<void>.delayed(Duration.zero);
      expect(captured.length, equals(4));
      expect(captured[0].isEmpty, isTrue);
      expect(captured[0].emptyReason, equals('reset'));

      // Empty -> Valid
      src.set(4);
      await Future<void>.delayed(Duration.zero);
      expect(captured.length, equals(5));
      expect(captured[0].hasData, isTrue);
      expect(captured[0].data, equals(4));
      expect(identical(captured[0], captured.last), isTrue);

      r.deactivate();
    });

    test('x.peekState.snapshot captures an immutable snapshot unaffected by subsequent mutations', () {
      final ctrl = WhatController<String>('initial');
      final snapshot1 = ctrl.what.peekState.snapshot;

      expect(snapshot1.hasData, isTrue);
      expect(snapshot1.data, equals('initial'));

      ctrl.set('updated');
      final snapshot2 = ctrl.what.peekState.snapshot;

      expect(snapshot1.data, equals('initial'));
      expect(snapshot2.data, equals('updated'));
      expect(ctrl.what.peek, equals('updated'));

      ctrl.empty('cleared');
      final snapshot3 = ctrl.what.peekState.snapshot;

      expect(snapshot1.data, equals('initial'));
      expect(snapshot2.data, equals('updated'));
      expect(snapshot3.isEmpty, isTrue);
    });

    test('WhatController, RawWhatTerminal, and WhatSnapshot retain WhatState implementation', () {
      final ctrl = WhatController<int>(7);
      // WhatController implements WhatState
      WhatState<int> stateRef = ctrl;
      expect(stateRef.data, equals(7));
      expect(stateRef.hasData, isTrue);

      // RawWhatTerminal implements WhatState
      final terminal = RawWhatTerminal<int>(ctrl.what, onInvalidated: () {});
      stateRef = terminal;
      expect(stateRef.data, equals(7));

      // WhatSnapshot implements WhatState
      final snap = WhatSnapshot<int>(7);
      stateRef = snap;
      expect(stateRef.data, equals(7));
    });
  });
}
