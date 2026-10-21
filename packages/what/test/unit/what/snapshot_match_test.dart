// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.
import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  // ─────────────────────────────────────────────
  // WhatSnapshot switch (phase) Pattern Matching
  // ─────────────────────────────────────────────
  group('WhatSnapshot switch (phase)', () {
    test('valid  → data branch evaluated', () {
      const snap = WhatSnapshot<int>(42);
      final result = switch (snap.phase) {
        WhatPhase.valid => 'data:${snap.data}',
        WhatPhase.empty => 'empty',
        WhatPhase.error => 'error',
      };
      expect(result, 'data:42');
    });

    test('empty  → empty branch evaluated', () {
      const snap = WhatSnapshot<int>.empty();
      final result = switch (snap.phase) {
        WhatPhase.valid => 'data:${snap.data}',
        WhatPhase.empty => 'empty',
        WhatPhase.error => 'error',
      };
      expect(result, 'empty');
    });

    test('error  → error branch evaluated', () {
      final snap = WhatSnapshot<int>.error(Exception('boom'));
      final result = switch (snap.phase) {
        WhatPhase.valid => 'data:${snap.data}',
        WhatPhase.empty => 'empty',
        WhatPhase.error => 'error:${snap.error}',
      };
      expect(result, 'error:Exception: boom');
    });
  });

  group('WhatSnapshot switch fallback with default clause', () {
    test('valid  → evaluated with transformation', () {
      const snap = WhatSnapshot<int>(10);
      final res = switch (snap.phase) {
        WhatPhase.valid => snap.data * 2,
        _ => -1,
      };
      expect(res, 20);
    });

    test('empty  → fallback returned', () {
      const snap = WhatSnapshot<int>.empty();
      final res = switch (snap.phase) {
        WhatPhase.valid => snap.data,
        _ => -1,
      };
      expect(res, -1);
    });

    test('error  → error branch returned', () {
      final snap = WhatSnapshot<int>.error(Exception('x'));
      final res = switch (snap.phase) {
        WhatPhase.error => 99,
        _ => 0,
      };
      expect(res, 99);
    });
  });

  group('WhatSnapshot conditional null-coalescing with hasData / hasError / dataOrNull', () {
    test('valid  → returns value', () {
      const snap = WhatSnapshot<int>(5);
      final res = snap.hasData ? snap.data + 1 : null;
      expect(res, 6);
      expect(snap.dataOrNull != null ? snap.dataOrNull! + 1 : null, 6);
    });

    test('empty  → returns null', () {
      const snap = WhatSnapshot<int>.empty();
      final res = snap.hasData ? snap.data : null;
      expect(res, isNull);
      expect(snap.dataOrNull, isNull);
    });

    test('error  → returns error string', () {
      final snap = WhatSnapshot<int>.error(Exception('fail'));
      final res = snap.hasError ? snap.error.toString() : null;
      expect(res, 'Exception: fail');
      expect(snap.dataOrNull, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // What (WhatState) — live node switch (phase)
  // ─────────────────────────────────────────────
  group('What switch (phase) on live node', () {
    test('valid what → data branch', () {
      final node = WhatController(7);
      final res = switch (node.phase) {
        WhatPhase.valid => node.data,
        WhatPhase.empty => 0,
        WhatPhase.error => -1,
      };
      expect(res, 7);
    });

    test('late what → empty branch', () {
      final node = WhatController<int>.late();
      final res = switch (node.phase) {
        WhatPhase.valid => node.data,
        WhatPhase.empty => 0,
        WhatPhase.error => -1,
      };
      expect(res, 0);
    });

    test('error what → error branch', () {
      final node = WhatController<int>.error(Exception('what fail'));
      final res = switch (node.phase) {
        WhatPhase.valid => node.data,
        WhatPhase.empty => 0,
        WhatPhase.error => -1,
      };
      expect(res, -1);
    });
  });

  // ─────────────────────────────────────────────
  // WhatSnapshot<List<What>> switch (phase)
  // ─────────────────────────────────────────────
  group('WhatSnapshot<List<What>> switch (phase)', () {
    final g1 = WhatController(1);
    final g2 = WhatController(2);

    test('hasData → data branch', () {
      final snap = WhatSnapshot([g1, g2]);
      final result = switch (snap.phase) {
        WhatPhase.valid => snap.data.length,
        WhatPhase.empty => 0,
        WhatPhase.error => -1,
      };
      expect(result, 2);
    });

    test('empty group snapshot → empty branch', () {
      const snap = WhatSnapshot<List<What<int>>>.empty();
      final result = switch (snap.phase) {
        WhatPhase.valid => snap.data.length,
        WhatPhase.empty => -99,
        WhatPhase.error => -1,
      };
      expect(result, -99);
    });

    test('error group snapshot → error branch', () {
      final snap = WhatSnapshot<List<What<int>>>.error(Exception('group fail'));
      final result = switch (snap.phase) {
        WhatPhase.valid => snap.data.length,
        WhatPhase.empty => 0,
        WhatPhase.error => -1,
      };
      expect(result, -1);
    });
  });

  // ─────────────────────────────────────────────
  // WhatListController live node — switch (phase)
  // ─────────────────────────────────────────────
  group('WhatListController switch (phase) on live node', () {
    test('valid group → data branch', () {
      final c = WhatListController([WhatController(1).what, WhatController(2).what]);
      final res = switch (c.phase) {
        WhatPhase.valid => c.data.length,
        WhatPhase.empty => 0,
        WhatPhase.error => -1,
      };
      expect(res, 2);
    });

    test('empty group → empty branch', () {
      final c = WhatListController<What<int>>.late();
      final res = switch (c.phase) {
        WhatPhase.valid => c.data.length,
        WhatPhase.empty => -99,
        WhatPhase.error => -1,
      };
      expect(res, -99);
    });

    test('error group → error branch', () {
      final c = WhatListController<What<int>>.late();
      c.setError(Exception('x'));
      final res = switch (c.phase) {
        WhatPhase.valid => c.data.length,
        WhatPhase.empty => 0,
        WhatPhase.error => -1,
      };
      expect(res, -1);
    });
  });

  // ─────────────────────────────────────────────
  // Reactive dependency tracking — switch (phase) via WhatVia
  // ─────────────────────────────────────────────
  group('Reactive pattern matching tracking', () {
    test('switch (via.state(controller.what).phase) inside RawViaTerminal registers dependency', () {
      final controller = WhatController(0);
      var invalidateCount = 0;

      final terminal = RawViaTerminal(
        (WhatVia via) {
          final state = via.state(controller.what);
          return switch (state.phase) {
            WhatPhase.valid => 'data:${state.data}',
            WhatPhase.empty => 'empty',
            WhatPhase.error => 'error',
          };
        },
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
      final listWithError = [a, b, untracked.state(error)];
      expect(listWithError.allHaveData(), isFalse);
      expect(listWithError.hasAnyEmpty(), isFalse);
      expect(listWithError.hasAnyError(), isTrue);
    });

    test('whereHasData, whereEmpty, whereError filtering', () {
      final v1 = WhatController('v1');
      final v2 = WhatController('v2');
      final e1 = WhatController<String>.late();
      final err1 = What<String>.error('error1');

      final mixed = [v1, e1, v2, untracked.state(err1)];

      expect(mixed.whereHasData().toList(), [v1, v2]);
      expect(mixed.whereEmpty().toList(), [e1]);
      expect(mixed.whereError().toList(), [untracked.state(err1)]);
    });

    test('Works seamlessly with computed(guard)', () {
      final a = WhatController<int>.late();
      final b = WhatController<int>.late();
      final c = WhatController<int>.late();

      final comp = computed<int>(
        (via) => (via(a.what) + via(b.what) + via(c.what)).toInt(),
        guard: (via) => (via.state(a.what), via.state(b.what), via.state(c.what)).guarded('Waiting'),
      );

      expect(untracked.state(comp).isEmpty, isTrue);
      expect(untracked.state(comp).snapshot.emptyReason, 'Waiting');

      a.set(10);
      expect(untracked.state(comp).isEmpty, isTrue);

      b.set(20);
      expect(untracked.state(comp).isEmpty, isTrue);

      c.set(30);
      expect(untracked.state(comp).hasData, isTrue);
      expect(untracked(comp), 60);
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

      expect(untracked.state(comp).isEmpty, isTrue);

      a.set(10);
      expect(untracked.state(comp).isEmpty, isTrue);

      b.set(20);
      expect(untracked.state(comp).isEmpty, isTrue);

      c.set(30);
      expect(untracked.state(comp).hasData, isTrue);
      expect(untracked(comp), 60);
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
