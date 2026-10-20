// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('WhatListController & Reactive Collection Evolution Tests', () {
    // =========================================================================
    // 1. Instantiation & Factory Constructors
    // =========================================================================
    group('1. Instantiation & Factory Constructors', () {
      test('1.1 WhatListController default factory creates unmodifiable list', () {
        final controller = WhatListController<int>([1, 2, 3]);

        expect(controller.hasData, isTrue);
        expect(controller.data, equals([1, 2, 3]));
        expect(untracked(controller.what), equals([1, 2, 3]));

        // Immutability check: data must be unmodifiable
        expect(() => controller.data.add(4), throwsUnsupportedError);
      });

      test('1.2 WhatListController empty explicit initialization', () {
        final controller = WhatListController<String>([]);

        expect(controller.hasData, isTrue);
        expect(controller.data, isEmpty);
      });

      test('1.3 WhatListController.late initialization', () {
        final controller = WhatListController<int>.late();

        expect(controller.isEmpty, isTrue);
        expect(controller.hasData, isFalse);
        expect(() => controller.data, throwsA(isA<WhatSnapshotExtractionException>()));

        controller.set([10, 20]);
        expect(controller.hasData, isTrue);
        expect(controller.data, equals([10, 20]));
      });

      test('1.4 WhatListController.error initialization', () {
        final controller = WhatListController<int>.error('Failed to load list');

        expect(controller.hasError, isTrue);
        expect(controller.hasData, isFalse);
        expect(controller.error, equals('Failed to load list'));
      });
    });

    // =========================================================================
    // 2. Method 1: Immutable Whole Replacement (.set, .data =)
    // =========================================================================
    group('2. Method 1: Immutable Whole Replacement (.set, .data =)', () {
      test('2.1 Whole replacement updates payload and notifies downstream', () {
        final controller = WhatListController<int>([1, 2]);
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        expect(notifyCount, equals(0));

        controller.set([3, 4, 5]);
        expect(notifyCount, equals(1));
        expect(controller.data, equals([3, 4, 5]));

        controller.data = [6];
        expect(notifyCount, equals(2));
        expect(controller.data, equals([6]));

        terminal.deactivate();
      });

      test('2.2 _listEquals suppresses redundant Push-Dirty pulses on identical elements', () {
        final controller = WhatListController<int>([1, 2, 3]);
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        // Assigning a new list instance with identical elements
        controller.set([1, 2, 3]);
        expect(notifyCount, equals(0), reason: 'Identical elements must suppress dirty pulse');

        controller.data = [1, 2, 3];
        expect(notifyCount, equals(0), reason: 'Identical elements must suppress dirty pulse');

        // Modifying one element must trigger notification
        controller.set([1, 2, 4]);
        expect(notifyCount, equals(1));

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. Method 3: Transactional Draft Edit (.edit((draft) => ...))
    // =========================================================================
    group('3. Method 3: Transactional Draft Edit (.edit)', () {
      test('3.1 Single draft modification applies atomically and freezes result', () {
        final controller = WhatListController<String>(['alpha']);
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        controller.edit((draft) {
          draft.add('beta');
        });

        expect(notifyCount, equals(1));
        expect(controller.data, equals(['alpha', 'beta']));
        expect(() => controller.data.add('gamma'), throwsUnsupportedError);

        terminal.deactivate();
      });

      test('3.2 Multiple operations inside edit emit AT MOST 1 dirty pulse (Atomic Commit)', () {
        final controller = WhatListController<int>([5, 3, 1]);
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        controller.edit((draft) {
          draft.add(4);
          draft.add(2);
          draft.remove(5);
          draft.sort();
        });

        expect(notifyCount, equals(1), reason: 'Regardless of recipe operations, only 1 pulse commits');
        expect(controller.data, equals([1, 2, 3, 4]));

        terminal.deactivate();
      });

      test('3.3 No-op edit suppresses Push-Dirty pulse completely', () {
        final controller = WhatListController<int>([10, 20]);
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        controller.edit((draft) {
          // Do nothing or redundant modification that returns to original state
          draft.add(30);
          draft.remove(30);
        });

        expect(notifyCount, equals(0), reason: 'No effective change in elements must not emit pulse');
        expect(controller.data, equals([10, 20]));

        terminal.deactivate();
      });

      test('3.4 edit on late() controller starts with empty list', () {
        final controller = WhatListController<int>.late();
        expect(controller.isEmpty, isTrue);

        controller.edit((draft) {
          draft.add(999);
        });

        expect(controller.hasData, isTrue);
        expect(controller.data, equals([999]));
      });

      test('3.5 edit on error controller transitions to valid data', () {
        final controller = WhatListController<int>.error('Initial error');
        expect(controller.hasError, isTrue);

        controller.edit((draft) {
          draft.add(100);
        });

        expect(controller.hasData, isTrue);
        expect(controller.hasError, isFalse);
        expect(controller.data, equals([100]));
      });

      test('3.6 edit failure preserves original state and rethrows (Atomicity / Rollback)', () {
        final controller = WhatListController<int>([1, 2, 3]);
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        expect(
          () => controller.edit((draft) {
            draft.add(4);
            throw StateError('Recipe transaction boom!');
          }),
          throwsA(isA<StateError>()),
        );

        // Original list preserved intact
        expect(controller.data, equals([1, 2, 3]));
        expect(notifyCount, equals(0), reason: 'Failed transaction must not emit dirty pulse');

        terminal.deactivate();
      });

      test('3.7 editGuarded successfully updates payload and notifies', () {
        final controller = WhatListController<String>(['a']);
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        controller.editGuarded((draft) {
          draft.add('b');
        });

        expect(notifyCount, equals(1));
        expect(controller.data, equals(['a', 'b']));

        terminal.deactivate();
      });

      test('3.8 editGuarded catches exception and safely transitions to error state', () {
        final controller = WhatListController<int>([10, 20]);
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        // Must not throw in caller stack
        controller.editGuarded((draft) {
          draft.add(30);
          throw RangeError('Index out of range');
        });

        expect(notifyCount, equals(1), reason: 'Error state transition emits Push-Dirty pulse');
        expect(controller.hasError, isTrue);
        expect(controller.hasData, isFalse);
        expect(controller.error, isA<RangeError>());

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 4. Downstream Pipeline & ComputedWhat Integration
    // =========================================================================
    group('4. Downstream Pipeline & ComputedWhat Integration', () {
      test('4.1 ComputedWhat seamlessly tracks WhatListController edits', () {
        final todos = WhatListController<String>(['task1']);
        final count = computed((via) => via(todos.what).length);
        final joined = computed((via) => via(todos.what).join(', '));

        final terminalCount = RawWhatTerminal(count, onInvalidated: () {});
        final terminalJoined = RawWhatTerminal(joined, onInvalidated: () {});
        terminalCount.activate();
        terminalJoined.activate();

        expect(untracked(count), equals(1));
        expect(untracked(joined), equals('task1'));

        todos.edit((draft) {
          draft.add('task2');
          draft.add('task3');
        });

        expect(untracked(count), equals(3));
        expect(untracked(joined), equals('task1, task2, task3'));

        todos.set(['only_one']);
        expect(untracked(count), equals(1));
        expect(untracked(joined), equals('only_one'));

        terminalCount.deactivate();
        terminalJoined.deactivate();
      });
    });

    // =========================================================================
    // 5. Custom Equality for Nested/High-Dimensional Collections
    // =========================================================================
    group('5. Custom Equality for Nested/High-Dimensional Collections', () {
      bool deepListEquals(List<List<int>> a, List<List<int>> b) {
        if (identical(a, b)) return true;
        if (a.length != b.length) return false;
        for (var i = 0; i < a.length; i++) {
          final rowA = a[i];
          final rowB = b[i];
          if (rowA.length != rowB.length) return false;
          for (var j = 0; j < rowA.length; j++) {
            if (rowA[j] != rowB[j]) return false;
          }
        }
        return true;
      }

      test('5.1 Custom equals suppresses dirty pulses when nested contents are equal', () {
        final matrix = WhatListController<List<int>>(
          [
            [1, 2],
            [3, 4],
          ],
          equals: deepListEquals,
        );

        var notifyCount = 0;
        final terminal = RawWhatTerminal(matrix.what, onInvalidated: () => notifyCount++);
        terminal.activate();

        // New nested instance with identical contents -> should be short-circuited!
        matrix.set([
          [1, 2],
          [3, 4],
        ]);
        expect(notifyCount, equals(0));

        // New nested instance with different contents -> should notify exactly once!
        matrix.set([
          [1, 2],
          [3, 5],
        ]);
        expect(notifyCount, equals(1));
        expect(matrix.data[1][1], equals(5));

        terminal.deactivate();
      });

      test('5.2 WhatListController.late propagates custom equals comparator', () {
        final matrix = WhatListController<List<int>>.late(
          equals: deepListEquals,
        );

        var notifyCount = 0;
        final terminal = RawWhatTerminal(matrix.what, onInvalidated: () => notifyCount++);
        terminal.activate();

        matrix.set([
          [10, 20],
        ]);
        expect(notifyCount, equals(1));

        // Setting identical nested contents must not notify
        matrix.set([
          [10, 20],
        ]);
        expect(notifyCount, equals(1));

        // Setting different nested contents must notify
        matrix.set([
          [10, 99],
        ]);
        expect(notifyCount, equals(2));

        terminal.deactivate();
      });
    });
  });
}
