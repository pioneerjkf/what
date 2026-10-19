// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.
import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  // ─────────────────────────────────────────────
  // WhatSnapshot.match / matchOrElse / matchOrNull
  // ─────────────────────────────────────────────
  group('WhatSnapshot.match', () {
    test('valid  → data handler called', () {
      const snap = WhatSnapshot<int>(42);
      final result = snap.match(
        data: (v) => 'data:$v',
        empty: () => 'empty',
        error: (e, s) => 'error',
      );
      expect(result, 'data:42');
    });

    test('empty  → empty handler called', () {
      const snap = WhatSnapshot<int>.empty();
      final result = snap.match(
        data: (v) => 'data:$v',
        empty: () => 'empty',
        error: (e, s) => 'error',
      );
      expect(result, 'empty');
    });

    test('error  → error handler called', () {
      final snap = WhatSnapshot<int>.error(Exception('boom'));
      final result = snap.match(
        data: (v) => 'data:$v',
        empty: () => 'empty',
        error: (e, s) => 'error:$e',
      );
      expect(result, 'error:Exception: boom');
    });
  });

  group('WhatSnapshot.matchOrElse', () {
    test('valid  → data handler present → data handler called', () {
      const snap = WhatSnapshot<int>(10);
      expect(
        snap.matchOrElse(data: (v) => v * 2, orElse: () => -1),
        20,
      );
    });

    test('empty  → empty handler absent → orElse called', () {
      const snap = WhatSnapshot<int>.empty();
      expect(
        snap.matchOrElse(data: (v) => v, orElse: () => -1),
        -1,
      );
    });

    test('error  → error handler present → error handler called', () {
      final snap = WhatSnapshot<int>.error(Exception('x'));
      expect(
        snap.matchOrElse(error: (e, s) => 99, orElse: () => 0),
        99,
      );
    });
  });

  group('WhatSnapshot.matchOrNull', () {
    test('valid  → data handler present → returns value', () {
      const snap = WhatSnapshot<int>(5);
      expect(snap.matchOrNull(data: (v) => v + 1), 6);
    });

    test('empty  → empty handler absent → returns null', () {
      const snap = WhatSnapshot<int>.empty();
      expect(snap.matchOrNull(data: (v) => v), isNull);
    });

    test('error  → error handler present → returns value', () {
      final snap = WhatSnapshot<int>.error(Exception('fail'));
      expect(
        snap.matchOrNull(error: (e, s) => e.toString()),
        'Exception: fail',
      );
    });
  });

  // ─────────────────────────────────────────────
  // What (WhatState) — live node
  // ─────────────────────────────────────────────
  group('What.match on live node', () {
    test('valid what → data handler', () {
      final node = WhatController(7);
      expect(
        node.match(data: (v) => v, empty: () => 0, error: (e, s) => -1),
        7,
      );
    });

    test('late what → empty handler', () {
      final node = WhatController<int>.late();
      expect(
        node.match(data: (v) => v, empty: () => 0, error: (e, s) => -1),
        0,
      );
    });

    test('error what → error handler', () {
      final node = WhatController<int>.error(Exception('what fail'));
      expect(
        node.match(data: (v) => v, empty: () => 0, error: (e, s) => -1),
        -1,
      );
    });
  });

  // ─────────────────────────────────────────────
  // WhatSnapshot<List<N>>.match / matchOrElse / matchOrNull
  // ─────────────────────────────────────────────
  group('WhatSnapshot<List<What>>.match', () {
    final g1 = WhatController(1);
    final g2 = WhatController(2);

    test('hasData → data handler', () {
      final snap = WhatSnapshot([g1, g2]);
      final result = snap.match(
        data: (list) => list.length,
        empty: () => 0,
        error: (e, s) => -1,
      );
      expect(result, 2);
    });

    test('empty group snapshot → empty handler', () {
      const snap = WhatSnapshot<List<What<int>>>.empty();
      final result = snap.match(
        data: (list) => list.length,
        empty: () => -99,
        error: (e, s) => -1,
      );
      expect(result, -99);
    });

    test('error group snapshot → error handler', () {
      final snap = WhatSnapshot<List<What<int>>>.error(Exception('group fail'));
      final result = snap.match(
        data: (list) => list.length,
        empty: () => 0,
        error: (e, s) => -1,
      );
      expect(result, -1);
    });
  });

  group('WhatSnapshot<List<What>>.matchOrElse', () {
    final g1 = WhatController(1);
    final g2 = WhatController(2);

    test('hasData → data handler present → calls it', () {
      final snap = WhatSnapshot([g1, g2]);
      expect(
        snap.matchOrElse(data: (list) => list.length, orElse: () => 0),
        2,
      );
    });

    test('empty → data handler absent → orElse', () {
      const snap = WhatSnapshot<List<What<int>>>.empty();
      expect(
        snap.matchOrElse(data: (list) => list.length, orElse: () => 0),
        0,
      );
    });
  });

  group('WhatSnapshot<List<What>>.matchOrNull', () {
    final g1 = WhatController(1);
    final g2 = WhatController(2);

    test('hasData → returns mapped value', () {
      final snap = WhatSnapshot([g1, g2]);
      expect(snap.matchOrNull(data: (list) => list.length), 2);
    });

    test('empty → returns null', () {
      const snap = WhatSnapshot<List<What<int>>>.empty();
      expect(snap.matchOrNull(data: (list) => list.length), isNull);
    });

    test('error → returns null when no error handler', () {
      final snap = WhatSnapshot<List<What<int>>>.error(Exception('group fail'));
      expect(snap.matchOrNull(data: (list) => list.length), isNull);
    });
  });

  // ─────────────────────────────────────────────
  // WhatListController live node — match / matchOrNull / matchOrElse
  // ─────────────────────────────────────────────
  group('WhatListController.match on live node', () {
    test('valid group → data handler', () {
      final c = WhatListController([WhatController(1).what, WhatController(2).what]);
      expect(
        c.match(data: (list) => list.length, empty: () => 0, error: (e, s) => -1),
        2,
      );
    });

    test('empty group → empty handler', () {
      final c = WhatListController<What<int>>.late();
      expect(
        c.match(data: (list) => list.length, empty: () => -99, error: (e, s) => -1),
        -99,
      );
    });

    test('error group → error handler', () {
      final c = WhatListController<What<int>>.late();
      c.setError(Exception('x'));
      expect(
        c.match(data: (list) => list.length, empty: () => 0, error: (e, s) => -1),
        -1,
      );
    });
  });

  // ─────────────────────────────────────────────
  // Reactive dependency tracking — match registers dependency via WhatVia
  // ─────────────────────────────────────────────
  group('Reactive match tracking', () {
    test('match() inside RawViaTerminal registers dependency', () {
      final controller = WhatController(0);
      var invalidateCount = 0;

      final terminal = RawViaTerminal(
        (WhatVia via) => via.state(controller.what).match(
              data: (v) => 'data:$v',
              empty: () => 'empty',
              error: (e, s) => 'error',
            ),
        onInvalidated: () => invalidateCount++,
      );

      expect(terminal.evaluate(), 'data:0');
      terminal.activate();

      controller.set(1);
      expect(invalidateCount, 1);

      terminal.deactivate();
    });
  });

  // ─────────────────────────────────────────────
  // WhatStateCollectionExtension
  // ─────────────────────────────────────────────
  group('WhatStateCollectionExtension', () {
    test('allHaveData, hasAnyEmpty, hasAnyError', () {
      final a = WhatController(1);
      final b = WhatController(2);
      final c = WhatController(3);

      final listAllData = [a, b, c];
      expect(listAllData.allHaveData(), isTrue);
      expect(listAllData.hasAnyEmpty(), isFalse);
      expect(listAllData.hasAnyError(), isFalse);

      final empty = WhatController<int>.late();
      final listWithEmpty = [a, empty, c];
      expect(listWithEmpty.allHaveData(), isFalse);
      expect(listWithEmpty.hasAnyEmpty(), isTrue);
      expect(listWithEmpty.hasAnyError(), isFalse);

      final error = What<int>.error('err');
      final listWithError = [a, b, error.peekState];
      expect(listWithError.allHaveData(), isFalse);
      expect(listWithError.hasAnyEmpty(), isFalse);
      expect(listWithError.hasAnyError(), isTrue);
    });

    test('whereHasData, whereEmpty, whereError filtering', () {
      final v1 = WhatController('v1');
      final v2 = WhatController('v2');
      final e1 = WhatController<String>.late();
      final err1 = What<String>.error('error1');

      final mixed = [v1, e1, v2, err1.peekState];

      expect(mixed.whereHasData().toList(), [v1, v2]);
      expect(mixed.whereEmpty().toList(), [e1]);
      expect(mixed.whereError().toList(), [err1.peekState]);
    });

    test('Works seamlessly with computed(guard)', () {
      final a = WhatController<int>.late();
      final b = WhatController<int>.late();
      final c = WhatController<int>.late();

      final comp = computed<int>(
        (via) => (via(a.what) + via(b.what) + via(c.what)).toInt(),
        guard: (via) => (via.state(a.what), via.state(b.what), via.state(c.what)).guarded('Waiting'),
      );

      expect(comp.peekState.isEmpty, isTrue);
      expect(comp.peekState.snapshot.emptyReason, 'Waiting');

      a.set(10);
      expect(comp.peekState.isEmpty, isTrue);

      b.set(20);
      expect(comp.peekState.isEmpty, isTrue);

      c.set(30);
      expect(comp.peekState.hasData, isTrue);
      expect(comp.peek, 60);
    });
  });

  // ─────────────────────────────────────────────
  // WhatState Record Tuple Extensions (Zero Allocation)
  // ─────────────────────────────────────────────
  group('WhatState Record Tuple Extensions', () {
    test('(a, b) status checks: allHaveData, hasAnyEmpty, hasAnyError', () {
      final a = WhatController<int>.late();
      final b = WhatController('hello');

      expect((a, b).allHaveData(), isFalse);
      expect((a, b).hasAnyEmpty(), isTrue);
      expect((a, b).hasAnyError(), isFalse);

      a.set(42);
      expect((a, b).allHaveData(), isTrue);
      expect((a, b).hasAnyEmpty(), isFalse);
      expect((a, b).hasAnyError(), isFalse);
    });

    test('(a, b, c).allHaveData in guard with zero heap allocation', () {
      final a = WhatController<int>.late();
      final b = WhatController<int>.late();
      final c = WhatController<int>.late();

      final comp = computed<int>(
        (via) => (via(a.what) + via(b.what) + via(c.what)).toInt(),
        guard: (via) => (via.state(a.what), via.state(b.what), via.state(c.what)).guarded('Waiting'),
      );

      expect(comp.peekState.isEmpty, isTrue);

      a.set(10);
      expect(comp.peekState.isEmpty, isTrue);

      b.set(20);
      expect(comp.peekState.isEmpty, isTrue);

      c.set(30);
      expect(comp.peekState.hasData, isTrue);
      expect(comp.peek, 60);
      expect((a, b, c).allHaveData(), isTrue);
    });

    test('Record tuple status extensions (2 to 9 elements, heterogeneous)', () {
      final intWhat = WhatController(10);
      final strWhat = WhatController('hello');
      final boolWhat = WhatController<bool>.late();
      final doubleWhat = WhatController(3.14);
      final listWhat = WhatController([1, 2]);
      final mapWhat = WhatController({'key': 'val'});
      final setWhat = WhatController({1, 2, 3});
      final symWhat = WhatController(#symbol);
      final objWhat = WhatController(Object());

      final t2 = (intWhat, strWhat);
      expect(t2.allHaveData(), isTrue);
      expect(t2.hasAnyEmpty(), isFalse);

      final t3 = (intWhat, strWhat, boolWhat);
      expect(t3.allHaveData(), isFalse);
      expect(t3.hasAnyEmpty(), isTrue);

      boolWhat.set(true);
      expect(t3.allHaveData(), isTrue);
      expect(t3.hasAnyEmpty(), isFalse);

      final t4 = (intWhat, strWhat, boolWhat, doubleWhat);
      expect(t4.allHaveData(), isTrue);

      final t5 = (intWhat, strWhat, boolWhat, doubleWhat, listWhat);
      expect(t5.allHaveData(), isTrue);

      final t6 = (intWhat, strWhat, boolWhat, doubleWhat, listWhat, mapWhat);
      expect(t6.allHaveData(), isTrue);
      expect(t6.hasAnyError(), isFalse);

      final t7 = (intWhat, strWhat, boolWhat, doubleWhat, listWhat, mapWhat, setWhat);
      expect(t7.allHaveData(), isTrue);
      expect(t7.hasAnyEmpty(), isFalse);

      final t8 = (intWhat, strWhat, boolWhat, doubleWhat, listWhat, mapWhat, setWhat, symWhat);
      expect(t8.allHaveData(), isTrue);

      final t9 = (intWhat, strWhat, boolWhat, doubleWhat, listWhat, mapWhat, setWhat, symWhat, objWhat);
      expect(t9.allHaveData(), isTrue);
      expect(t9.hasAnyEmpty(), isFalse);
      expect(t9.hasAnyError(), isFalse);

      // Dedicated error and empty branch coverage across tuples 3 to 9
      final errWhat = WhatController<int>.error(StateError('error'));
      final emptyWhat = WhatController<int>.late();
      final validWhat = WhatController(1);

      // t3 error
      expect((validWhat, validWhat, errWhat).hasAnyError(), isTrue);
      expect((validWhat, validWhat, validWhat).hasAnyError(), isFalse);

      // t4 empty & error
      expect((validWhat, validWhat, validWhat, emptyWhat).hasAnyEmpty(), isTrue);
      expect((validWhat, validWhat, validWhat, validWhat).hasAnyEmpty(), isFalse);
      expect((validWhat, validWhat, validWhat, errWhat).hasAnyError(), isTrue);
      expect((validWhat, validWhat, validWhat, validWhat).hasAnyError(), isFalse);

      // t5 empty & error
      expect((validWhat, validWhat, validWhat, validWhat, emptyWhat).hasAnyEmpty(), isTrue);
      expect((validWhat, validWhat, validWhat, validWhat, validWhat).hasAnyEmpty(), isFalse);
      expect((validWhat, validWhat, validWhat, validWhat, errWhat).hasAnyError(), isTrue);
      expect((validWhat, validWhat, validWhat, validWhat, validWhat).hasAnyError(), isFalse);

      // t6 empty & error
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, emptyWhat).hasAnyEmpty(), isTrue);
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, validWhat).hasAnyEmpty(), isFalse);
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, errWhat).hasAnyError(), isTrue);

      // t7 empty & error
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, emptyWhat).hasAnyEmpty(), isTrue);
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, errWhat).hasAnyError(), isTrue);
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat).hasAnyError(), isFalse);

      // t8 empty & error
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, emptyWhat).hasAnyEmpty(),
          isTrue);
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat).hasAnyEmpty(),
          isFalse);
      expect(
          (validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, errWhat).hasAnyError(), isTrue);
      expect((validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat).hasAnyError(),
          isFalse);

      // t9 empty & error
      expect(
          (validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, emptyWhat)
              .hasAnyEmpty(),
          isTrue);
      expect(
          (validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, validWhat, errWhat)
              .hasAnyError(),
          isTrue);
    });
  });
}
