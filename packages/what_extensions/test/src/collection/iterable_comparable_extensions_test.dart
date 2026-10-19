import 'package:what_extensions/what_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('ComparableWhatElementsExtension', () {
    test('maxOrNull and minOrNull compute comparable elements reactively', () {
      final controller = WhatController<List<int>>([5, 3, 9, 1, 7]);

      final maxWhat = controller.what.elements.maxOrNull;
      final minWhat = controller.what.elements.minOrNull;

      final termMax = RawWhatTerminal(maxWhat, onInvalidated: () {});
      final termMin = RawWhatTerminal(minWhat, onInvalidated: () {});
      termMax.activate();
      termMin.activate();

      expect(termMax.snapshot.data, 9);
      expect(termMin.snapshot.data, 1);

      controller.set([10, 20, 5]);
      expect(termMax.snapshot.data, 20);
      expect(termMin.snapshot.data, 5);

      controller.set([]);
      expect(termMax.snapshot.data, null);
      expect(termMin.snapshot.data, null);

      termMax.deactivate();
      termMin.deactivate();
    });

    test(
        'max and min compute comparable elements reactively and throw when empty',
        () {
      final controller = WhatController<List<int>>([5, 3, 9, 1, 7]);

      final maxWhat = controller.what.elements.max;
      final minWhat = controller.what.elements.min;

      final termMax = RawWhatTerminal(maxWhat, onInvalidated: () {});
      final termMin = RawWhatTerminal(minWhat, onInvalidated: () {});
      termMax.activate();
      termMin.activate();

      expect(termMax.snapshot.data, 9);
      expect(termMin.snapshot.data, 1);

      controller.set([10, 20, 5]);
      expect(termMax.snapshot.data, 20);
      expect(termMin.snapshot.data, 5);

      controller.set([]);
      expect(termMax.snapshot.hasError, isTrue);
      expect(termMax.snapshot.error, isA<StateError>());
      expect(termMin.snapshot.hasError, isTrue);
      expect(termMin.snapshot.error, isA<StateError>());

      termMax.deactivate();
      termMin.deactivate();
    });

    test('isSorted detects sorted state reactively', () {
      final controller = WhatController<List<int>>([1, 2, 3, 4, 5]);
      final isSortedWhat = controller.what.elements.isSorted();

      final term = RawWhatTerminal(isSortedWhat, onInvalidated: () {});
      term.activate();

      expect(term.snapshot.data, true);

      controller.set([1, 3, 2, 4]);
      expect(term.snapshot.data, false);

      controller.set([5]);
      expect(term.snapshot.data, true);

      controller.set([]);
      expect(term.snapshot.data, true);

      term.deactivate();
    });

    test('sorted and sortedDescending produce sorted lists reactively', () {
      final controller = WhatController<List<int>>([5, 3, 9, 1, 7]);
      final sortedWhat = controller.what.elements.sorted;
      final sortedDescWhat = controller.what.elements.sortedDescending;

      final termSorted = RawWhatTerminal(sortedWhat, onInvalidated: () {});
      final termSortedDesc =
          RawWhatTerminal(sortedDescWhat, onInvalidated: () {});
      termSorted.activate();
      termSortedDesc.activate();

      expect(termSorted.snapshot.data, [1, 3, 5, 7, 9]);
      expect(termSortedDesc.snapshot.data, [9, 7, 5, 3, 1]);

      controller.set([10, 20, 5]);
      expect(termSorted.snapshot.data, [5, 10, 20]);
      expect(termSortedDesc.snapshot.data, [20, 10, 5]);

      controller.set([]);
      expect(termSorted.snapshot.data, isEmpty);
      expect(termSortedDesc.snapshot.data, isEmpty);

      termSorted.deactivate();
      termSortedDesc.deactivate();
    });
  });
}
