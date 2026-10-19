// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('What Node List Core, Controller, Snapshot & Operators Unit Tests', () {
    // =========================================================================
    // 1. What Node List WhatSnapshot Tests
    // =========================================================================
    group('1. What Node List WhatSnapshot Core & Invariants', () {
      test('1.1 Valid What node list WhatSnapshot properties and fail-safe getters', () {
        final c1 = What.constant(1);
        final c2 = What.constant(2);
        final snapshot = WhatSnapshot([c1, c2]);

        expect(snapshot.hasData, isTrue);
        expect(snapshot.isEmpty, isFalse);
        expect(snapshot.hasError, isFalse);
        expect(snapshot.data, [c1, c2]);
        expect(snapshot.dataOrNull, [c1, c2]);
        expect(snapshot.dataOrElse(() => const []), [c1, c2]);
      });

      test('1.2 Empty What node list WhatSnapshot throws extraction exception on data', () {
        const snapshot = WhatSnapshot<List<What<int>>>.empty();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.hasData, isFalse);
        expect(snapshot.hasError, isFalse);
        expect(snapshot.dataOrNull, isNull);
        expect(snapshot.dataOrElse(() => const []), isEmpty);
        expect(() => snapshot.data, throwsA(isA<WhatSnapshotExtractionException>()));
      });

      test('1.3 Error What node list WhatSnapshot exposes error and throws extraction exception', () {
        final err = const FormatException('What list Error');
        final stack = StackTrace.current;
        final snapshot = WhatSnapshot<List<What<int>>>.error(err, stack);

        expect(snapshot.hasData, isFalse);
        expect(snapshot.isEmpty, isFalse);
        expect(snapshot.hasError, isTrue);
        expect(snapshot.error, same(err));
        expect(snapshot.stackTrace, same(stack));
        expect(snapshot.dataOrNull, isNull);
        expect(snapshot.dataOrElse(() => const []), isEmpty);
        expect(() => snapshot.data, throwsA(isA<WhatSnapshotExtractionException>()));
      });
    });

    // =========================================================================
    // 2. What Node List Factory Constructors
    // =========================================================================
    group('2. What Node List Factory Constructors', () {
      test('2.1 What.constant creates valid sealed list', () {
        final c1 = What.constant('x');
        final c2 = What.constant('y');
        final group = What.constant([c1, c2]);

        final terminal = RawWhatTerminal(group, onInvalidated: () {});
        terminal.activate();

        expect(group.peekState.hasData, isTrue);
        expect(group.peekState.isEmpty, isFalse);
        expect(group.peekState.hasError, isFalse);
        expect(group.peek, [c1, c2]);

        terminal.deactivate();
      });

      test('2.2 What.constant supports composite nested lists', () {
        final c1 = What.constant('a');
        final c2 = What.constant('b');

        final s1 = What.constant([c1]);
        final s2 = What.constant([c2]);

        final compositeGroup = What.constant([s1, s2]);

        expect(compositeGroup.peekState.hasData, isTrue);
        expect(compositeGroup.peek, [s1, s2]);
        expect(What.constant([c1, c2]).peekState.hasData, isTrue);
      });

      test('2.3 What.empty and What.error factories for lists', () {
        final groupEmpty = What<List<What<int>>>.empty();
        expect(groupEmpty.peekState.isEmpty, isTrue);
        expect(groupEmpty.peekState.hasData, isFalse);
        expect(groupEmpty.peekState.dataOrElse(() => const []), isEmpty);

        final groupError = What<List<What<int>>>.error('Error in group');
        expect(groupError.peekState.hasError, isTrue);
        expect(groupError.peekState.hasData, isFalse);
        expect(groupError.peekState.error, 'Error in group');
      });
    });

    // =========================================================================
    // 3. WhatListController Tests
    // =========================================================================
    group('3. WhatListController Lifecycle & Mutation', () {
      test('3.1 Standard WhatListController initialization and set mutation', () {
        final what1 = WhatController<int>(10);
        final what2 = WhatController<int>(20);
        final controller = WhatListController<What<int>>([what1.what, what2.what]);

        expect(controller.hasData, isTrue);
        expect(controller.data.length, equals(2));
        expect(controller.data[0].peekState.snapshot.data, equals(10));
        expect(controller.data[1].peekState.snapshot.data, equals(20));

        final what3 = WhatController<int>(30);
        controller.set([what3.what]);

        expect(controller.data.length, equals(1));
        expect(controller.data[0].peekState.snapshot.data, equals(30));
      });

      test('3.2 WhatListController.late initialization and delayed set', () {
        final controller = WhatListController<What<int>>.late();

        expect(controller.isEmpty, isTrue);
        expect(controller.hasData, isFalse);
        expect(() => controller.data, throwsA(isA<WhatSnapshotExtractionException>()));

        final what1 = WhatController<int>(100);
        controller.set([what1.what]);

        expect(controller.hasData, isTrue);
        expect(controller.data.length, equals(1));
        expect(controller.data[0].peekState.snapshot.data, equals(100));
      });

      test('3.3 WhatListController setGuarded, setError, and empty', () {
        final controller = WhatListController<What<int>>.late();

        controller.setGuarded(() => throw Exception('Calculation error'));
        expect(controller.hasError, isTrue);
        expect(controller.hasData, isFalse);
        expect(controller.error, isA<Exception>());

        final what1 = WhatController<int>(50);
        controller.setGuarded(() => [what1.what]);
        expect(controller.hasData, isTrue);
        expect(controller.data.length, equals(1));

        controller.setError('Manual Error');
        expect(controller.hasError, isTrue);
        expect(controller.hasData, isFalse);
        expect(controller.error, equals('Manual Error'));

        controller.empty();
        expect(controller.isEmpty, isTrue);
        expect(controller.hasData, isFalse);
      });

      test('3.4 WhatListController does not emit dirty when identical node elements are re-assigned (_nodeListEquals)',
          () {
        final a = What.constant(1);
        final b = What.constant(2);
        final group = WhatListController([a, b]);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(group.what, onInvalidated: () => dirtyCount++);
        terminal.activate();
        expect(dirtyCount, 0);

        // Re-assign identical list instance
        group.set([a, b]);
        expect(dirtyCount, 0); // [Suppressed]

        // In-place assignment via data setter
        group.data = [a, b];
        expect(dirtyCount, 0); // [Suppressed]

        // Actual modification
        final c = What.constant(3);
        group.set([a, c]);
        expect(dirtyCount, 1);

        terminal.deactivate();
      });

      test('3.5 What node list data guarantees unmodifiable list', () {
        final a = What.constant(1);
        final group = WhatListController([a]);

        expect(() => (group.data as dynamic).add(What.constant(2)), throwsUnsupportedError);
      });

      test('3.6 WhatListController handles standard data assignment and setGuarded', () {
        final a = What.constant(1);
        final b = What.constant(2);
        final c = What.constant(3);
        final group = WhatListController([a]);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(group.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // data = assignment
        group.data = [...group.data, b];
        expect(dirtyCount, 1);
        expect(terminal.data, [a, b]);

        // remove via list filtering
        group.data = group.data.where((e) => !identical(e, a)).toList();
        expect(dirtyCount, 2);
        expect(terminal.data, [b]);

        // re-assigning identical elements emits zero dirty pulses
        group.data = [b];
        expect(dirtyCount, 2);
        expect(terminal.data, [b]);

        // setGuarded executes safely and emits single dirty pulse
        group.setGuarded(() {
          return [...group.data, c, a];
        });
        expect(dirtyCount, 3);
        expect(terminal.data, [b, c, a]);

        // setGuarded catches exception and transitions to error state
        group.setGuarded(() => throw Exception('Calculation Error'));
        expect(group.hasError, isTrue);

        terminal.deactivate();
      });

      test('3.7 WhatListController.late handles set and setGuarded safely', () {
        final group = WhatListController<What<int>>.late();
        expect(group.isEmpty, isTrue);

        final a = What.constant(10);
        group.set([a]);
        expect(group.hasData, isTrue);
        expect(group.data, [a]);

        group.empty();
        expect(group.isEmpty, isTrue);

        group.setGuarded(() => [a]);
        expect(group.hasData, isTrue);
        expect(group.data, [a]);
      });

      test('3.8 WhatListController<int> manages primitive value lists with distinct shallow equality', () {
        final group = WhatListController<int>([1, 2, 3]);
        expect(group.hasData, isTrue);
        expect(group.data, [1, 2, 3]);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(group.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        // Assigning new list with same values suppresses dirty pulse (distinct)
        group.set([1, 2, 3]);
        expect(dirtyCount, 0);

        // Assigning new list with changed values triggers dirty pulse
        group.set([1, 2, 4]);
        expect(dirtyCount, 1);
        expect(terminal.data, [1, 2, 4]);

        // Aggregate operator works seamlessly on primitive list
        final sum = group.what.aggregate((nums) => nums.reduce((a, b) => a + b));
        expect(sum.peek, 7);

        terminal.deactivate();
      });

      test('3.9 aggregate works polymorphically on What<Set<T>> and What<Iterable<T>>', () {
        final setWhat = WhatController<Set<int>>({10, 20, 30});
        final total = setWhat.what.aggregate((elements) => elements.fold<int>(0, (a, b) => a + b));
        expect(total.peek, 60);

        setWhat.set({10, 20, 40});
        expect(total.peek, 70);
      });
    });

    // =========================================================================
    // 4. What Node List Operators (combine, fold, reduce, sum, every, any)
    // =========================================================================
    group('4. What Node List Operators & Combinators', () {
      test('4.1 computed aggregation reduces group elements into a single scalar what', () {
        final c1 = What.constant(10);
        final c2 = What.constant(20);
        final c3 = What.constant(30);
        final group = What.constant([c1, c2, c3]);

        final aggregated = computed((via) => via(group).fold<int>(0, (sum, item) => sum + via(item)));
        final terminal = RawWhatTerminal(aggregated, onInvalidated: () {});
        terminal.activate();

        expect(aggregated.peek, 60);

        terminal.deactivate();
      });

      test('4.2 combine bundles all element data into What<List<T>>', () {
        final c1 = What.constant('apple');
        final c2 = What.constant('banana');
        final group = What.constant([c1, c2]);

        final combined = group.combine();
        final terminal = RawWhatTerminal(combined, onInvalidated: () {});
        terminal.activate();

        expect(combined.peek, ['apple', 'banana']);

        terminal.deactivate();
      });

      test('4.3 computed conditionally returns a value based on group elements', () {
        final c1 = WhatController<int>(10);
        final c2 = WhatController<int>(20);
        final group = WhatListController([c1.what, c2.what]);

        final converged = computed((via) {
          final sum = via(group.what).fold<int>(0, (acc, g) => acc + via(g));
          return sum > 25 ? 'HIGH' : 'LOW';
        });

        final terminal = RawWhatTerminal(converged, onInvalidated: () {});
        terminal.activate();

        expect(converged.peek, 'HIGH');

        c1.set(0);
        c2.set(10);
        expect(converged.peek, 'LOW');

        terminal.deactivate();
      });

      test('4.4 fold operator reduces values iteratively with an initial seed', () {
        final g1 = What.constant(1);
        final g2 = What.constant(2);
        final g3 = What.constant(3);
        final group = What.constant([g1, g2, g3]);

        final folded = group.fold<int>(100, (acc, val) => acc + val);
        final terminal = RawWhatTerminal(folded, onInvalidated: () {});
        terminal.activate();

        expect(folded.peek, 106);
        terminal.deactivate();
      });

      test('4.5 reduce operator iteratively combines all values without an initial seed', () {
        final g1 = What.constant('a');
        final g2 = What.constant('b');
        final g3 = What.constant('c');
        final group = What.constant([g1, g2, g3]);

        final reduced = group.reduce((acc, val) => '$acc-$val');
        final terminal = RawWhatTerminal(reduced, onInvalidated: () {});
        terminal.activate();

        expect(reduced.peek, 'a-b-c');
        terminal.deactivate();
      });

      test('4.6 sum operator calculates arithmetic sum for numeric groups (num, int, double)', () {
        final n1 = What.constant(10);
        final n2 = What.constant(25);
        final groupInt = What.constant([n1, n2]);
        final sumInt = groupInt.sum();

        final d1 = What.constant(1.5);
        final d2 = What.constant(2.5);
        final groupDouble = What.constant([d1, d2]);
        final sumDouble = groupDouble.sum();

        final tInt = RawWhatTerminal(sumInt, onInvalidated: () {});
        final tDouble = RawWhatTerminal(sumDouble, onInvalidated: () {});
        tInt.activate();
        tDouble.activate();

        expect(sumInt.peek, 35);
        expect(sumDouble.peek, 4.0);

        tInt.deactivate();
        tDouble.deactivate();
      });

      test('4.7 every and any boolean logical reduction operators', () {
        final g1 = WhatController<int>(10);
        final g2 = WhatController<int>(20);
        final group = What.constant([g1.what, g2.what]);

        final allEven = group.every((x) => x % 2 == 0);
        final anyGreaterThan15 = group.any((x) => x > 15);

        final tEvery = RawWhatTerminal(allEven, onInvalidated: () {});
        final tAny = RawWhatTerminal(anyGreaterThan15, onInvalidated: () {});
        tEvery.activate();
        tAny.activate();

        expect(allEven.peek, isTrue);
        expect(anyGreaterThan15.peek, isTrue);

        g1.set(11);
        expect(allEven.peek, isFalse);

        g2.set(10);
        expect(anyGreaterThan15.peek, isFalse);

        tEvery.deactivate();
        tAny.deactivate();
      });
    });

    // =========================================================================
    // 5. Complex What Node List Lifecycle & Dynamic Topology Integration
    // =========================================================================
    group('5. Complex What Node List Topology & Dynamic Lifecycle', () {
      test('5.1 Dynamic What node list elements mutating trigger single dirty notification via combined pipeline', () {
        final c1 = WhatController<int>(1);
        final c2 = WhatController<int>(2);
        final group = What.constant([c1.what, c2.what]);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(group.combine(), onInvalidated: () {
          dirtyCount++;
        });

        terminal.activate();
        expect(dirtyCount, 0);
        expect(terminal.data, [1, 2]);

        c1.set(10);
        expect(dirtyCount, 1);

        // Pull to clear dirty
        expect(terminal.data, [10, 2]);

        c2.set(20);
        expect(dirtyCount, 2);
        expect(terminal.data, [10, 20]);

        terminal.deactivate();
      });

      test('5.2 What node list combine reacts lazily to inner controllers while active', () {
        final c1 = WhatController<String>('A');
        final c2 = WhatController<String>('B');
        final group = What.constant([c1.what, c2.what]);
        final combined = group.combine();

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(combined, onInvalidated: () {
          dirtyCount++;
        });

        expect(dirtyCount, 0);
        terminal.activate();

        expect(combined.peek, ['A', 'B']);

        c1.set('Alpha');
        expect(dirtyCount, 1);

        // Compute only on pull
        expect(combined.peek, ['Alpha', 'B']);

        terminal.deactivate();
      });

      test('5.3 Dynamic Re-parenting in WhatListController (Swap In, Swap Out & Mooring GC)', () {
        final g1 = WhatController<String>('Item 1');
        final g2 = WhatController<String>('Item 2');
        final g3 = WhatController<String>('Item 3');

        final groupController = WhatListController<What<String>>([g1.what, g2.what]);
        int dirtyCount = 0;
        final complexTerminal = RawWhatTerminal(groupController.what.combine(), onInvalidated: () => dirtyCount++);

        complexTerminal.activate();
        expect(complexTerminal.data.length, 2);

        // Swap topology: [g1, g2] -> [g2, g3] (g1 removed, g3 added)
        groupController.set([g2.what, g3.what]);
        expect(dirtyCount, 1);
        expect(complexTerminal.data.length, 2);

        // Reset dirty counter
        dirtyCount = 0;

        // Mutate detached g1 -> MUST NOT trigger notification
        g1.set('Item 1 Mutated Detached');
        expect(dirtyCount, 0);

        // Mutate retained g2 -> MUST trigger notification
        g2.set('Item 2 Updated');
        expect(dirtyCount, 1);
        expect(complexTerminal.data.length, 2);

        // Mutate newly added g3 -> MUST trigger notification
        g3.set('Item 3 Updated');
        expect(dirtyCount, 2);

        complexTerminal.deactivate();
      });

      test('5.4 Nested What Node List Hierarchy: List of Lists with Deep Leaf Mutations', () {
        final leafA1 = WhatController<String>('A1');
        final leafA2 = WhatController<String>('A2');
        final leafB1 = WhatController<String>('B1');

        final groupA = What.constant([leafA1.what, leafA2.what]);
        final groupB = What.constant([leafB1.what]);

        final rootGroup = What.constant([groupA, groupB]);
        final rootCombined = computed(
          (via) => via(rootGroup).expand((s) => via(s.combine())).toList(),
        );

        int rootDirtyCount = 0;
        final rootTerminal = RawWhatTerminal(rootCombined, onInvalidated: () => rootDirtyCount++);
        rootTerminal.activate();

        expect(rootTerminal.data.length, 3);

        leafA1.set('A1-v2');
        expect(rootDirtyCount, 1);
        expect(rootTerminal.data.first, 'A1-v2');

        leafA1.set('A1-v3');
        expect(rootDirtyCount, 2);
        expect(rootTerminal.data.first, 'A1-v3');

        leafB1.set('B1-v2');
        expect(rootDirtyCount, 3);
        expect(rootTerminal.data.last, 'B1-v2');

        rootTerminal.deactivate();
      });

      test('5.5 Single element transitioning to Error and recovering to Valid in What node list', () {
        final g1 = WhatController<int>(10);
        final g2 = WhatController<int>(20);

        final group = What.constant([g1.what, g2.what]);
        final combined = group.combine();

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(combined, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.snapshot.hasData, isTrue);

        g1.setError('Database connection lost');
        expect(dirtyCount, 1);
        expect(terminal.snapshot.hasError, isTrue);

        g1.set(15);
        expect(dirtyCount, 2);
        expect(terminal.snapshot.hasData, isTrue);

        g1.set(25);
        expect(dirtyCount, 3);

        terminal.deactivate();
      });

      test('5.6 WhatListController downstream pipeline integration via computed', () {
        final c1 = WhatController<int>(10);
        final c2 = WhatController<int>(20);
        final groupController = WhatListController<What<int>>([c1.what, c2.what]);

        final sumWhat = computed(
          (via) => via(groupController.what).fold<int>(0, (int sum, item) => sum + via(item)),
        );

        var dirtyCount = 0;
        final terminal = RawWhatTerminal(sumWhat, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, equals(30));

        c1.set(15);
        expect(dirtyCount, equals(1));
        expect(terminal.data, equals(35));

        final c3 = WhatController<int>(100);
        groupController.set([c1.what, c2.what, c3.what]);
        expect(dirtyCount, equals(2));
        expect(terminal.data, equals(135));

        terminal.deactivate();
      });

      test('5.7 WhatListController multiple heterogeneous elements creates active reactive What node list', () {
        final c1 = WhatController<int>(10);
        final c2 = WhatController<String>('hello');
        final c3 = WhatController<bool>(true);
        final c4 = WhatController<double>(3.14);
        final c5 = WhatController<int>(50);

        final group = WhatListController<What<dynamic>>([c1.what, c2.what, c3.what, c4.what, c5.what]);
        expect(group.hasData, isTrue);
        expect(group.data.length, 5);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(group.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        group.set([c1.what, c2.what]);
        expect(dirtyCount, 1);
        expect(terminal.data.length, 2);

        group.set([c1.what, c2.what, c3.what, c4.what, c5.what]);
        expect(dirtyCount, 2);
        expect(terminal.data.length, 5);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 6. Unified Collection Convenience Extensions (what.dart export)
    // =========================================================================
    group('6. Unified Collection Convenience Extensions (Single Entrypoint)', () {
      test('6.1 Iterable<WhatState<T>> via peekState.data and dataOrNull extract values correctly', () {
        final w1 = What.constant(10);
        final w2 = What.constant(20);
        final w3 = What<int>.empty();
        final list = [w1.peekState, w2.peekState];

        expect(list.data.toList(), equals([10, 20]));
        expect(list.dataOrNull.toList(), equals([10, 20]));

        final mixed = [w1.peekState, w3.peekState];
        expect(mixed.dataOrNull.toList(), equals([10, null]));
        expect(() => mixed.data.toList(), throwsA(isA<WhatSnapshotExtractionException>()));
      });

      test('6.2 Iterable<WhatController<T>>.data and dataOrNull extract values correctly', () {
        final c1 = WhatController<String>('alpha');
        final c2 = WhatController<String>('beta');
        final c3 = WhatController<String>('gamma')..empty();
        final list = [c1, c2];

        expect(list.data.toList(), equals(['alpha', 'beta']));
        expect(list.dataOrNull.toList(), equals(['alpha', 'beta']));

        final mixed = [c1, c3];
        expect(mixed.dataOrNull.toList(), equals(['alpha', null]));
        expect(() => mixed.data.toList(), throwsA(isA<WhatSnapshotExtractionException>()));
      });

      test('6.3 Iterable<WhatSnapshot<T>>.data and dataOrNull extract values correctly', () {
        final s1 = WhatSnapshot<int>(1);
        final s2 = WhatSnapshot<int>(2);
        final sEmpty = const WhatSnapshot<int>.empty();
        final list = [s1, s2];

        expect(list.data.toList(), equals([1, 2]));
        expect(list.dataOrNull.toList(), equals([1, 2]));

        final mixed = [s1, sEmpty];
        expect(mixed.dataOrNull.toList(), equals([1, null]));
        expect(() => mixed.data.toList(), throwsA(isA<WhatSnapshotExtractionException>()));
      });

      test('6.4 Iterable<WhatState<T>>.data and dataOrNull extract values correctly', () {
        final state1 = WhatSnapshot<String>('hello');
        final state2 = What<String>.constant('world');
        final stateEmpty = const WhatSnapshot<String>.empty();
        final List<WhatState<String>> list = [state1, state2.peekState];

        expect(list.data.toList(), equals(['hello', 'world']));
        expect(list.dataOrNull.toList(), equals(['hello', 'world']));

        final List<WhatState<String>> mixed = [state1, stateEmpty];
        expect(mixed.dataOrNull.toList(), equals(['hello', null]));
        expect(() => mixed.data.toList(), throwsA(isA<WhatSnapshotExtractionException>()));
      });
    });
  });
}
