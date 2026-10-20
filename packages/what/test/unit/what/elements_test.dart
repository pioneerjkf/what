// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

class _UserItem {
  _UserItem(this.id, this.name);
  final String id;
  final String name;
}

class _UserViewModel {
  _UserViewModel(this.item);
  final _UserItem item;
}

void main() {
  group('What Elements, Reactive Collections & Keyed Operations Unit Tests', () {
    // =========================================================================
    // 1. WhatIterableElements, WhatListElements, WhatSetElements & Type Conversions
    // =========================================================================
    group('1. Collection Elements & Type Factories', () {
      test('1.1 elements.toList converts What<Iterable<T>> into What<List<T>>', () {
        final setController = WhatController<Set<int>>({1, 2, 3});

        final listWhatProxy = setController.what.elements.toList();
        final proxyTerminal = RawWhatTerminal(listWhatProxy, onInvalidated: () {});
        proxyTerminal.activate();

        expect(proxyTerminal.snapshot.data, equals([1, 2, 3]));
        expect(() => proxyTerminal.snapshot.data.add(4), throwsUnsupportedError);

        setController.set({10, 20});
        expect(proxyTerminal.snapshot.data, equals([10, 20]));

        proxyTerminal.deactivate();
      });

      test('1.2 elements.cast downcasts dynamic iterable into What<List<T>>', () {
        final dynamicListController = WhatController<List<dynamic>>(['a', 'b', 'c']);

        final stringListWhatProxy = dynamicListController.what.elements.cast<String>();
        final proxyTerminal = RawWhatTerminal(stringListWhatProxy, onInvalidated: () {});
        proxyTerminal.activate();

        expect(proxyTerminal.snapshot.data, equals(['a', 'b', 'c']));

        proxyTerminal.deactivate();
      });

      test('1.3 elements.cast adapts List<S> to List<T>', () {
        final numListController = WhatController<List<num>>([1, 2, 3]);

        final castProxyWhat = numListController.what.elements.cast<int>();
        final proxyTerminal = RawWhatTerminal(castProxyWhat, onInvalidated: () {});
        proxyTerminal.activate();

        expect(proxyTerminal.snapshot.data, equals([1, 2, 3]));

        numListController.set([10, 20]);
        expect(proxyTerminal.snapshot.data, equals([10, 20]));

        proxyTerminal.deactivate();
      });
    });

    // =========================================================================
    // 2. List Elements Operators (index, length, first, last, where, map)
    // =========================================================================
    group('2. List Elements Operators', () {
      test('2.1 List elements indexing, length, where, map, first and last', () {
        final controller = WhatController<List<int>>([10, 20, 30, 40]);

        final lengthWhat = controller.what.elements.length;
        final firstWhat = controller.what.elements.first;
        final lastWhat = controller.what.elements.last;
        final atIndex1 = controller.what.elements[1];
        final doubled = controller.what.elements.map((x) => x * 2);
        final filtered = controller.what.elements.where((x) => x > 25);

        final tLen = RawWhatTerminal(lengthWhat, onInvalidated: () {});
        final tFirst = RawWhatTerminal(firstWhat, onInvalidated: () {});
        final tLast = RawWhatTerminal(lastWhat, onInvalidated: () {});
        final tAt1 = RawWhatTerminal(atIndex1, onInvalidated: () {});
        final tDouble = RawWhatTerminal(doubled, onInvalidated: () {});
        final tFiltered = RawWhatTerminal(filtered, onInvalidated: () {});

        tLen.activate();
        tFirst.activate();
        tLast.activate();
        tAt1.activate();
        tDouble.activate();
        tFiltered.activate();

        expect(tLen.data, 4);
        expect(tFirst.data, 10);
        expect(tLast.data, 40);
        expect(tAt1.data, 20);
        expect(tDouble.data, [20, 40, 60, 80]);
        expect(tFiltered.data, [30, 40]);

        // Mutate list
        controller.set([100, 200]);
        expect(tLen.data, 2);
        expect(tFirst.data, 100);
        expect(tLast.data, 200);
        expect(tAt1.data, 200);
        expect(tDouble.data, [200, 400]);
        expect(tFiltered.data, [100, 200]);

        tLen.deactivate();
        tFirst.deactivate();
        tLast.deactivate();
        tAt1.deactivate();
        tDouble.deactivate();
        tFiltered.deactivate();
      });
    });

    // =========================================================================
    // 3. Map Elements Operators (index, keys, values, containsKey, containsValue)
    // =========================================================================
    group('3. Map Elements Operators', () {
      test('3.1 Map elements indexing, keys, values, containsKey, and containsValue', () {
        final controller = WhatController<Map<String, int>>({'a': 1, 'b': 2});

        final valA = controller.what.elements['a'];
        final valNonExistent = controller.what.elements['z'];
        final hasKeyA = controller.what.elements.containsKey('a');
        final hasKeyZ = controller.what.elements.containsKey('z');
        final hasVal2 = controller.what.elements.containsValue(2);
        final keysList = controller.what.elements.keys;
        final valuesList = controller.what.elements.values;

        final tValA = RawWhatTerminal(valA, onInvalidated: () {});
        final tValZ = RawWhatTerminal(valNonExistent, onInvalidated: () {});
        final tHasA = RawWhatTerminal(hasKeyA, onInvalidated: () {});
        final tHasZ = RawWhatTerminal(hasKeyZ, onInvalidated: () {});
        final tHasV2 = RawWhatTerminal(hasVal2, onInvalidated: () {});
        final tKeys = RawWhatTerminal(keysList, onInvalidated: () {});
        final tValues = RawWhatTerminal(valuesList, onInvalidated: () {});

        tValA.activate();
        tValZ.activate();
        tHasA.activate();
        tHasZ.activate();
        tHasV2.activate();
        tKeys.activate();
        tValues.activate();

        expect(tValA.data, 1);
        expect(tValZ.data, isNull);
        expect(tHasA.data, isTrue);
        expect(tHasZ.data, isFalse);
        expect(tHasV2.data, isTrue);
        expect(tKeys.data, ['a', 'b']);
        expect(tValues.data, [1, 2]);

        // Mutate map
        controller.set({'z': 99});
        expect(tValA.data, isNull);
        expect(tValZ.data, 99);
        expect(tHasA.data, isFalse);
        expect(tHasZ.data, isTrue);
        expect(tHasV2.data, isFalse);
        expect(tKeys.data, ['z']);
        expect(tValues.data, [99]);

        tValA.deactivate();
        tValZ.deactivate();
        tHasA.deactivate();
        tHasZ.deactivate();
        tHasV2.deactivate();
        tKeys.deactivate();
        tValues.deactivate();
      });
    });

    // =========================================================================
    // 4. Keyed Elements (keyed.map) Caching & Identity Retention
    // =========================================================================
    group('4. Keyed Elements Caching & Identity Retention', () {
      test('4.1 Keyed map reuses cached objects when list is reordered or partially updated', () {
        final u1 = _UserItem('1', 'Alice');
        final u2 = _UserItem('2', 'Bob');
        final u3 = _UserItem('3', 'Charlie');

        final controller = WhatController<List<_UserItem>>([u1, u2, u3]);
        int convertCount = 0;

        final keyedWhat = controller.what.keyed.map(
          key: (u) => u.id,
          convert: (u) {
            convertCount++;
            return _UserViewModel(u);
          },
        );

        final terminal = RawWhatTerminal(keyedWhat, onInvalidated: () {});
        terminal.activate();

        // Lazy computation: convert is not called on activate
        expect(convertCount, 0);

        // First pull evaluates convert
        final initialList = terminal.data;
        expect(convertCount, 3);
        final vm1 = initialList[0];
        final vm2 = initialList[1];
        final vm3 = initialList[2];

        // Reorder list: [u3, u1, u2]
        controller.set([u3, u1, u2]);

        // Convert should NOT be called again because all 3 keys are cached
        final reorderedList = terminal.data;
        expect(convertCount, 3);
        expect(reorderedList.length, 3);
        expect(identical(reorderedList[0], vm3), isTrue);
        expect(identical(reorderedList[1], vm1), isTrue);
        expect(identical(reorderedList[2], vm2), isTrue);

        // Add 1 new user: [u1, u4]
        final u4 = _UserItem('4', 'David');
        controller.set([u1, u4]);

        // Only u4 should be converted
        final updatedList = terminal.data;
        expect(convertCount, 4);
        expect(updatedList.length, 2);
        expect(identical(updatedList[0], vm1), isTrue);
        expect(updatedList[1].item.name, 'David');

        terminal.deactivate();
      });

      test('4.2 Empty and Error state transitions reset or preserve cache correctly in keyed.map', () {
        final u1 = _UserItem('1', 'Alice');
        final controller = WhatController<List<_UserItem>>([u1]);
        int convertCount = 0;

        final keyedWhat = controller.what.keyed.map(
          key: (u) => u.id,
          convert: (u) {
            convertCount++;
            return _UserViewModel(u);
          },
        );

        final terminal = RawWhatTerminal(keyedWhat, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data.length, 1);
        expect(convertCount, 1);

        // Empty source resets cache
        controller.empty();
        expect(terminal.isEmpty, isTrue);

        // Re-adding u1 should re-convert because empty cleared cache
        controller.set([u1]);
        expect(terminal.data.length, 1);
        expect(convertCount, 2);

        // Error on source preserves pipeline error
        controller.setError('Upstream Error');
        expect(terminal.hasError, isTrue);

        // Recovery
        controller.set([u1]);
        expect(terminal.hasData, isTrue);

        terminal.deactivate();
      });

      test('4.3 Keyed map retains What instances across list mutations and deletions', () {
        final controller = WhatController<List<String>>(['A', 'B', 'C']);
        int builderCount = 0;

        final mappedGroup = controller.what.keyed.map(
          key: (item) => item,
          convert: (item) {
            builderCount++;
            return WhatController<String>('Node-$item');
          },
        );

        final countWhat = computed((via) => via(mappedGroup).length);
        final terminal = RawWhatTerminal(countWhat, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 3);
        expect(builderCount, 3);

        final groupSnapshot1 = untracked.state(mappedGroup).snapshot;
        final nodeA = groupSnapshot1.data[0];
        final nodeB = groupSnapshot1.data[1];
        final nodeC = groupSnapshot1.data[2];

        // Mutate list: reverse order ['C', 'B', 'A']
        controller.set(['C', 'B', 'A']);

        // Builder should NOT be called again
        expect(builderCount, 3);
        final groupSnapshot2 = untracked.state(mappedGroup).snapshot;
        expect(groupSnapshot2.data.length, 3);
        expect(identical(groupSnapshot2.data[0], nodeC), isTrue);
        expect(identical(groupSnapshot2.data[1], nodeB), isTrue);
        expect(identical(groupSnapshot2.data[2], nodeA), isTrue);

        // Remove B: ['A', 'C']
        controller.set(['A', 'C']);
        expect(builderCount, 3);
        final groupSnapshot3 = untracked.state(mappedGroup).snapshot;
        expect(groupSnapshot3.data.length, 2);
        expect(identical(groupSnapshot3.data[0], nodeA), isTrue);
        expect(identical(groupSnapshot3.data[1], nodeC), isTrue);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 5. WhatIterableElements Exhaustive Operators
    // =========================================================================
    group('5. WhatIterableElements Exhaustive Operators', () {
      test('5.1 whereType, indexed, expand, contains, reduce, fold, every, any, join', () {
        final controller = WhatController<Iterable<Object>>([1, 'two', 3, 'four', 5]);

        final numbersOnly = controller.what.elements.whereType<int>();
        final indexedList = controller.what.elements.indexed;
        final expanded = controller.what.elements.expand((e) => [e, e]);
        final hasThree = controller.what.elements.contains(3);
        final hasNine = controller.what.elements.contains(9);
        final reduced = controller.what.elements.whereType<int>().elements.reduce((a, b) => a + b);
        final folded = controller.what.elements.fold('Prefix:', (prev, e) => '$prev $e');
        final allStrings = controller.what.elements.every((e) => e is String);
        final anyStrings = controller.what.elements.any((e) => e is String);
        final joined = controller.what.elements.join('-');

        final tNum = RawWhatTerminal(numbersOnly, onInvalidated: () {})..activate();
        final tIdx = RawWhatTerminal(indexedList, onInvalidated: () {})..activate();
        final tExp = RawWhatTerminal(expanded, onInvalidated: () {})..activate();
        final tHas3 = RawWhatTerminal(hasThree, onInvalidated: () {})..activate();
        final tHas9 = RawWhatTerminal(hasNine, onInvalidated: () {})..activate();
        final tRed = RawWhatTerminal(reduced, onInvalidated: () {})..activate();
        final tFold = RawWhatTerminal(folded, onInvalidated: () {})..activate();
        final tAllStr = RawWhatTerminal(allStrings, onInvalidated: () {})..activate();
        final tAnyStr = RawWhatTerminal(anyStrings, onInvalidated: () {})..activate();
        final tJoin = RawWhatTerminal(joined, onInvalidated: () {})..activate();

        expect(tNum.data, [1, 3, 5]);
        expect(tIdx.data, [(0, 1), (1, 'two'), (2, 3), (3, 'four'), (4, 5)]);
        expect(tExp.data, [1, 1, 'two', 'two', 3, 3, 'four', 'four', 5, 5]);
        expect(tHas3.data, isTrue);
        expect(tHas9.data, isFalse);
        expect(tRed.data, 9);
        expect(tFold.data, 'Prefix: 1 two 3 four 5');
        expect(tAllStr.data, isFalse);
        expect(tAnyStr.data, isTrue);
        expect(tJoin.data, '1-two-3-four-5');

        // Test proxy .what getter
        expect(identical(controller.what.elements.what, controller.what), isTrue);

        tNum.deactivate();
        tIdx.deactivate();
        tExp.deactivate();
        tHas3.deactivate();
        tHas9.deactivate();
        tRed.deactivate();
        tFold.deactivate();
        tAllStr.deactivate();
        tAnyStr.deactivate();
        tJoin.deactivate();
      });

      test('5.2 toSet (unmodifiable and mutable), isEmpty, isNotEmpty, take, skip, elementAt', () {
        final controller = WhatController<Iterable<int>>([1, 2, 2, 3]);

        final unmodSet = controller.what.elements.toSet(unmodifiable: true);
        final modSet = controller.what.elements.toSet(unmodifiable: false);
        final emptyWhat = controller.what.elements.isEmpty;
        final notEmptyWhat = controller.what.elements.isNotEmpty;
        final taken = controller.what.elements.take(2);
        final skipped = controller.what.elements.skip(2);
        final elemAt1 = controller.what.elements.elementAt(1);

        final tUnmod = RawWhatTerminal(unmodSet, onInvalidated: () {})..activate();
        final tMod = RawWhatTerminal(modSet, onInvalidated: () {})..activate();
        final tEmpty = RawWhatTerminal(emptyWhat, onInvalidated: () {})..activate();
        final tNotEmpty = RawWhatTerminal(notEmptyWhat, onInvalidated: () {})..activate();
        final tTaken = RawWhatTerminal(taken, onInvalidated: () {})..activate();
        final tSkipped = RawWhatTerminal(skipped, onInvalidated: () {})..activate();
        final tElemAt = RawWhatTerminal(elemAt1, onInvalidated: () {})..activate();

        expect(tUnmod.data, {1, 2, 3});
        expect(() => tUnmod.data.add(99), throwsUnsupportedError);
        expect(tMod.data, {1, 2, 3});
        tMod.data.add(99); // Mutable copy allowed
        expect(tEmpty.data, isFalse);
        expect(tNotEmpty.data, isTrue);
        expect(tTaken.data, [1, 2]);
        expect(tSkipped.data, [2, 3]);
        expect(tElemAt.data, 2);

        // Update to empty
        controller.set([]);
        expect(tEmpty.data, isTrue);
        expect(tNotEmpty.data, isFalse);

        tUnmod.deactivate();
        tMod.deactivate();
        tEmpty.deactivate();
        tNotEmpty.deactivate();
        tTaken.deactivate();
        tSkipped.deactivate();
        tElemAt.deactivate();
      });

      test('5.3 firstOrNull, lastOrNull, single, singleOrNull, firstWhere, lastWhere, singleWhere', () {
        final controller = WhatController<List<int>>([10, 20, 30, 20]);

        final firstNullWhat = controller.what.elements.firstOrNull;
        final lastNullWhat = controller.what.elements.lastOrNull;
        final singleNullWhat = controller.what.elements.singleOrNull;
        final firstWhereWhat = controller.what.elements.firstWhere((x) => x > 15);
        final firstWhereOrElse = controller.what.elements.firstWhere((x) => x > 100, orElse: () => -1);
        final lastWhereWhat = controller.what.elements.lastWhere((x) => x == 20);
        final lastWhereOrElse = controller.what.elements.lastWhere((x) => x > 100, orElse: () => -2);
        final singleWhereWhat = controller.what.elements.singleWhere((x) => x == 30);
        final singleWhereOrElse = controller.what.elements.singleWhere((x) => x > 100, orElse: () => -3);

        final tFirstN = RawWhatTerminal(firstNullWhat, onInvalidated: () {})..activate();
        final tLastN = RawWhatTerminal(lastNullWhat, onInvalidated: () {})..activate();
        final tSingleN = RawWhatTerminal(singleNullWhat, onInvalidated: () {})..activate();
        final tFW = RawWhatTerminal(firstWhereWhat, onInvalidated: () {})..activate();
        final tFWO = RawWhatTerminal(firstWhereOrElse, onInvalidated: () {})..activate();
        final tLW = RawWhatTerminal(lastWhereWhat, onInvalidated: () {})..activate();
        final tLWO = RawWhatTerminal(lastWhereOrElse, onInvalidated: () {})..activate();
        final tSW = RawWhatTerminal(singleWhereWhat, onInvalidated: () {})..activate();
        final tSWO = RawWhatTerminal(singleWhereOrElse, onInvalidated: () {})..activate();

        expect(tFirstN.data, 10);
        expect(tLastN.data, 20);
        expect(tSingleN.data, isNull); // Multiple elements
        expect(tFW.data, 20);
        expect(tFWO.data, -1);
        expect(tLW.data, 20);
        expect(tLWO.data, -2);
        expect(tSW.data, 30);
        expect(tSWO.data, -3);

        // Single element test
        controller.set([42]);
        final singleWhat = controller.what.elements.single;
        final tSingle = RawWhatTerminal(singleWhat, onInvalidated: () {})..activate();
        expect(tSingle.data, 42);
        expect(tSingleN.data, 42);

        // Empty list test
        controller.set([]);
        expect(tFirstN.data, isNull);
        expect(tLastN.data, isNull);
        expect(tSingleN.data, isNull);

        tFirstN.deactivate();
        tLastN.deactivate();
        tSingleN.deactivate();
        tFW.deactivate();
        tFWO.deactivate();
        tLW.deactivate();
        tLWO.deactivate();
        tSW.deactivate();
        tSWO.deactivate();
        tSingle.deactivate();
      });
    });

    // =========================================================================
    // 6. WhatListElements Additional Operators
    // =========================================================================
    group('6. WhatListElements Additional Operators', () {
      test('6.1 reversed, indexOf, indexWhere, lastIndexWhere, lastIndexOf, sublist, asMap, toUnmodifiable', () {
        final controller = WhatController<List<String>>(['a', 'b', 'c', 'b']);

        final reversedWhat = controller.what.elements.reversed;
        final idxOfB = controller.what.elements.indexOf('b', 0);
        final idxWhereC = controller.what.elements.indexWhere((s) => s == 'c');
        final lastIdxWhereB = controller.what.elements.lastIndexWhere((s) => s == 'b');
        final lastIdxB = controller.what.elements.lastIndexOf('b');
        final sublistWhat = controller.what.elements.sublist(1, 3);
        final asMapWhat = controller.what.elements.asMap();
        final unmodifiableWhat = controller.what.elements.toUnmodifiable();

        final tRev = RawWhatTerminal(reversedWhat, onInvalidated: () {})..activate();
        final tIdxB = RawWhatTerminal(idxOfB, onInvalidated: () {})..activate();
        final tIdxC = RawWhatTerminal(idxWhereC, onInvalidated: () {})..activate();
        final tLIdxWhereB = RawWhatTerminal(lastIdxWhereB, onInvalidated: () {})..activate();
        final tLIdxB = RawWhatTerminal(lastIdxB, onInvalidated: () {})..activate();
        final tSub = RawWhatTerminal(sublistWhat, onInvalidated: () {})..activate();
        final tMap = RawWhatTerminal(asMapWhat, onInvalidated: () {})..activate();
        final tUnmod = RawWhatTerminal(unmodifiableWhat, onInvalidated: () {})..activate();

        expect(tRev.data, ['b', 'c', 'b', 'a']);
        expect(tIdxB.data, 1);
        expect(tIdxC.data, 2);
        expect(tLIdxWhereB.data, 3);
        expect(tLIdxB.data, 3);
        expect(tSub.data, ['b', 'c']);
        expect(tMap.data, {0: 'a', 1: 'b', 2: 'c', 3: 'b'});
        expect(tUnmod.data, ['a', 'b', 'c', 'b']);
        expect(() => tUnmod.data.add('d'), throwsUnsupportedError);

        tRev.deactivate();
        tIdxB.deactivate();
        tIdxC.deactivate();
        tLIdxWhereB.deactivate();
        tLIdxB.deactivate();
        tSub.deactivate();
        tMap.deactivate();
        tUnmod.deactivate();
      });
    });

    // =========================================================================
    // 7. WhatSetElements Operators
    // =========================================================================
    group('7. WhatSetElements Operators', () {
      test('7.1 lookup, intersection, union, difference, cast, toUnmodifiable, what getter', () {
        final setController = WhatController<Set<int>>({1, 2, 3});

        final lookup2 = setController.what.elements.lookup(2);
        final lookup99 = setController.what.elements.lookup(99);
        final intersectionWhat = setController.what.elements.intersection({2, 3, 4});
        final unionWhat = setController.what.elements.union({4, 5});
        final diffWhat = setController.what.elements.difference({1, 2});
        final castWhat = setController.what.elements.cast<num>();
        final unmodWhat = setController.what.elements.toUnmodifiable();

        final tLook2 = RawWhatTerminal(lookup2, onInvalidated: () {})..activate();
        final tLook99 = RawWhatTerminal(lookup99, onInvalidated: () {})..activate();
        final tInter = RawWhatTerminal(intersectionWhat, onInvalidated: () {})..activate();
        final tUnion = RawWhatTerminal(unionWhat, onInvalidated: () {})..activate();
        final tDiff = RawWhatTerminal(diffWhat, onInvalidated: () {})..activate();
        final tCast = RawWhatTerminal(castWhat, onInvalidated: () {})..activate();
        final tUnmod = RawWhatTerminal(unmodWhat, onInvalidated: () {})..activate();

        expect(tLook2.data, 2);
        expect(tLook99.data, isNull);
        expect(tInter.data, {2, 3});
        expect(tUnion.data, {1, 2, 3, 4, 5});
        expect(tDiff.data, {3});
        expect(tCast.data, {1, 2, 3});
        expect(tUnmod.data, {1, 2, 3});
        expect(() => tUnmod.data.add(99), throwsUnsupportedError);

        // proxy what getter
        expect(identical(setController.what.elements.what, setController.what), isTrue);

        tLook2.deactivate();
        tLook99.deactivate();
        tInter.deactivate();
        tUnion.deactivate();
        tDiff.deactivate();
        tCast.deactivate();
        tUnmod.deactivate();
      });
    });

    // =========================================================================
    // 8. WhatMapElements Additional Operators
    // =========================================================================
    group('8. WhatMapElements Additional Operators', () {
      test('8.1 map, where, length, isEmpty, isNotEmpty, cast, toUnmodifiable, what getter', () {
        final mapController = WhatController<Map<String, int>>({'apple': 100, 'banana': 200});

        final mappedEntries = mapController.what.elements.map((k, v) => MapEntry(k.toUpperCase(), v * 2));
        final filteredEntries = mapController.what.elements.where((k, v) => v > 150);
        final lenWhat = mapController.what.elements.length;
        final emptyWhat = mapController.what.elements.isEmpty;
        final notEmptyWhat = mapController.what.elements.isNotEmpty;
        final castWhat = mapController.what.elements.cast<Object, Object>();
        final unmodWhat = mapController.what.elements.toUnmodifiable();

        final tMap = RawWhatTerminal(mappedEntries, onInvalidated: () {})..activate();
        final tWhere = RawWhatTerminal(filteredEntries, onInvalidated: () {})..activate();
        final tLen = RawWhatTerminal(lenWhat, onInvalidated: () {})..activate();
        final tEmpty = RawWhatTerminal(emptyWhat, onInvalidated: () {})..activate();
        final tNotEmpty = RawWhatTerminal(notEmptyWhat, onInvalidated: () {})..activate();
        final tCast = RawWhatTerminal(castWhat, onInvalidated: () {})..activate();
        final tUnmod = RawWhatTerminal(unmodWhat, onInvalidated: () {})..activate();

        expect(tMap.data, {'APPLE': 200, 'BANANA': 400});
        expect(tWhere.data, {'banana': 200});
        expect(tLen.data, 2);
        expect(tEmpty.data, isFalse);
        expect(tNotEmpty.data, isTrue);
        expect(tCast.data, {'apple': 100, 'banana': 200});
        expect(tUnmod.data, {'apple': 100, 'banana': 200});
        expect(() => tUnmod.data['kiwi'] = 300, throwsUnsupportedError);

        // proxy what getter
        expect(identical(mapController.what.elements.what, mapController.what), isTrue);

        // empty map
        mapController.set({});
        expect(tEmpty.data, isTrue);
        expect(tNotEmpty.data, isFalse);
        expect(tLen.data, 0);

        tMap.deactivate();
        tWhere.deactivate();
        tLen.deactivate();
        tEmpty.deactivate();
        tNotEmpty.deactivate();
        tCast.deactivate();
        tUnmod.deactivate();
      });
    });

    // =========================================================================
    // 9. What.elements.what and WhatKeyedIterableElements.what consistency
    // =========================================================================
    group('9. What.elements.what and WhatKeyedIterableElements.what consistency', () {
      test('9.1 What Iterable/List/Set/Map .elements & .keyed proxies', () {
        final WhatController<Iterable<int>> iterCtrl = WhatController<Iterable<int>>([1, 2]);
        final WhatController<List<int>> listCtrl = WhatController<List<int>>([3, 4]);
        final WhatController<Set<int>> setCtrl = WhatController<Set<int>>({5, 6});
        final WhatController<Map<String, int>> mapCtrl = WhatController<Map<String, int>>({'k': 1});

        expect(iterCtrl.what.elements.what, equals(iterCtrl.what));
        expect(iterCtrl.what.keyed.what, equals(iterCtrl.what));
        expect(listCtrl.what.elements.what, equals(listCtrl.what));
        expect(listCtrl.what.keyed.what, equals(listCtrl.what));
        expect(setCtrl.what.elements.what, equals(setCtrl.what));
        expect(mapCtrl.what.elements.what, equals(mapCtrl.what));

        final What<Iterable<int>> rawIterWhat = iterCtrl.what;
        expect(rawIterWhat.elements.what, equals(rawIterWhat));
        expect(rawIterWhat.keyed.what, equals(rawIterWhat));
      });
    });
  });
}
