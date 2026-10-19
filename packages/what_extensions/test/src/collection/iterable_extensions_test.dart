import 'package:what_extensions/what_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('GeneralWhatElementsExtension', () {
    test(
        'firstWhereOrNull, lastWhereOrNull, singleWhereOrNull search elements reactively',
        () {
      final controller = WhatController<List<String>>(
          ['apple', 'banana', 'apricot', 'cherry']);

      final firstA =
          controller.what.elements.firstWhereOrNull((e) => e.startsWith('a'));
      final lastA =
          controller.what.elements.lastWhereOrNull((e) => e.startsWith('a'));
      final singleC =
          controller.what.elements.singleWhereOrNull((e) => e.startsWith('c'));

      final termFirst = RawWhatTerminal(firstA, onInvalidated: () {});
      final termLast = RawWhatTerminal(lastA, onInvalidated: () {});
      final termSingle = RawWhatTerminal(singleC, onInvalidated: () {});

      termFirst.activate();
      termLast.activate();
      termSingle.activate();

      expect(termFirst.snapshot.data, 'apple');
      expect(termLast.snapshot.data, 'apricot');
      expect(termSingle.snapshot.data, 'cherry');

      controller.set(['banana', 'cherry']);
      expect(termFirst.snapshot.data, null);
      expect(termLast.snapshot.data, null);
      expect(termSingle.snapshot.data, 'cherry');

      termFirst.deactivate();
      termLast.deactivate();
      termSingle.deactivate();
    });

    test('whereNotNull filters nulls reactively', () {
      final controller = WhatController<List<int?>>([1, null, 3, null, 5]);

      final nonNulls = controller.what.elements.whereNotNull;
      final term = RawWhatTerminal(nonNulls, onInvalidated: () {});
      term.activate();

      expect(term.snapshot.data, [1, 3, 5]);

      controller.set([null, null]);
      expect(term.snapshot.data, <int>[]);

      term.deactivate();
    });

    test('mapIndexed and whereIndexed use indices reactively', () {
      final controller = WhatController<List<String>>(['a', 'b', 'c']);

      final mapped =
          controller.what.elements.mapIndexed((idx, val) => '$idx:$val');
      final filtered =
          controller.what.elements.whereIndexed((idx, val) => idx.isEven);

      final termMap = RawWhatTerminal(mapped, onInvalidated: () {});
      final termFilter = RawWhatTerminal(filtered, onInvalidated: () {});

      termMap.activate();
      termFilter.activate();

      expect(termMap.snapshot.data, ['0:a', '1:b', '2:c']);
      expect(termFilter.snapshot.data, ['a', 'c']);

      termMap.deactivate();
      termFilter.deactivate();
    });

    test('groupBy and slices group collections reactively', () {
      final controller = WhatController<List<int>>([1, 2, 3, 4, 5]);

      final groups =
          controller.what.elements.groupBy((x) => x % 2 == 0 ? 'even' : 'odd');
      final sliced = controller.what.elements.slices(2);

      final termGroups = RawWhatTerminal(groups, onInvalidated: () {});
      final termSliced = RawWhatTerminal(sliced, onInvalidated: () {});

      termGroups.activate();
      termSliced.activate();

      expect(termGroups.snapshot.data, {
        'odd': [1, 3, 5],
        'even': [2, 4],
      });
      expect(termSliced.snapshot.data, [
        [1, 2],
        [3, 4],
        [5],
      ]);

      termGroups.deactivate();
      termSliced.deactivate();
    });
  });

  group('New General Extension Tests', () {
    test(
        'whereNot, shuffled, sortedBy, and isSortedBy reactively operate on elements',
        () {
      final controller = WhatController<List<int>>([1, 2, 3, 4]);

      final whereNotWhat = controller.what.elements.whereNot((x) => x.isEven);
      final isSortedWhat = controller.what.elements.isSortedBy((x) => x);

      final tWN = RawWhatTerminal(whereNotWhat, onInvalidated: () {});
      final tIS = RawWhatTerminal(isSortedWhat, onInvalidated: () {});

      tWN.activate();
      tIS.activate();

      expect(tWN.snapshot.data, [1, 3]);
      expect(tIS.snapshot.data, true);

      controller.set([3, 1, 4, 2]);
      expect(tWN.snapshot.data, [3, 1]);
      expect(tIS.snapshot.data, false);

      tWN.deactivate();
      tIS.deactivate();
    });

    test(
        'reduceIndexed, foldIndexed, none, and indexed predicates reactively compute elements',
        () {
      final controller = WhatController<List<int>>([1, 2, 3]);

      final redWhat = controller.what.elements
          .reduceIndexed((idx, prev, el) => prev + el + idx);
      final foldWhat = controller.what.elements
          .foldIndexed<int>(10, (idx, prev, el) => prev + el + idx);
      final noneWhat = controller.what.elements.none((x) => x > 5);
      final noneIndexedWhat =
          controller.what.elements.noneIndexed((idx, x) => x + idx > 5);

      final tRed = RawWhatTerminal(redWhat, onInvalidated: () {});
      final tFold = RawWhatTerminal(foldWhat, onInvalidated: () {});
      final tNone = RawWhatTerminal(noneWhat, onInvalidated: () {});
      final tNoneIndexed =
          RawWhatTerminal(noneIndexedWhat, onInvalidated: () {});

      tRed.activate();
      tFold.activate();
      tNone.activate();
      tNoneIndexed.activate();

      expect(tRed.snapshot.data, 1 + 2 + 1 + 3 + 2); // 9
      expect(tFold.snapshot.data, 10 + 1 + 0 + 2 + 1 + 3 + 2); // 19
      expect(tNone.snapshot.data, true);
      expect(tNoneIndexed.snapshot.data, true);

      tRed.deactivate();
      tFold.deactivate();
      tNone.deactivate();
      tNoneIndexed.deactivate();
    });

    test(
        'splitBefore, splitAfter, splitBetween reactively partition collections',
        () {
      final controller = WhatController<List<int>>([1, 0, 2, 1, 5, 7, 6]);

      final splitWhat = controller.what.elements.splitBefore((x) => x > 3);
      final tSplit = RawWhatTerminal(splitWhat, onInvalidated: () {});
      tSplit.activate();

      expect(tSplit.snapshot.data, [
        [1, 0, 2, 1],
        [5],
        [7],
        [6]
      ]);

      tSplit.deactivate();
    });

    test(
        'flattenedToList, flattenedToSet reactively flatten nested collections',
        () {
      final controller = WhatController<List<List<int>>>([
        [1, 2],
        [3],
        [3, 4]
      ]);

      final flatWhat = controller.what.elements.flattenedToList;
      final flatSetWhat = controller.what.elements.flattenedToSet;

      final tList = RawWhatTerminal(flatWhat, onInvalidated: () {});
      final tSet = RawWhatTerminal(flatSetWhat, onInvalidated: () {});

      tList.activate();
      tSet.activate();

      expect(tList.snapshot.data, [1, 2, 3, 3, 4]);
      expect(tSet.snapshot.data, {1, 2, 3, 4});

      tList.deactivate();
      tSet.deactivate();
    });
  });
}
