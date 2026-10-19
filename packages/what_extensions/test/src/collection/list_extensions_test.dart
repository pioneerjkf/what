import 'package:what_extensions/what_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('ListWhatElementsExtension', () {
    test('binarySearch and lowerBound locate elements reactively', () {
      final controller = WhatController<List<int>>([10, 20, 30, 40]);

      final indexWhat = controller.what.elements.binarySearch(30);
      final boundWhat = controller.what.elements.lowerBound(25);

      final termIdx = RawWhatTerminal(indexWhat, onInvalidated: () {});
      final termBound = RawWhatTerminal(boundWhat, onInvalidated: () {});

      termIdx.activate();
      termBound.activate();

      expect(termIdx.snapshot.data, 2);
      expect(termBound.snapshot.data,
          2); // 25 would be inserted at index 2 (between 20 and 30)

      termIdx.deactivate();
      termBound.deactivate();
    });

    test(
        'sortedRange, sortedBy, sortedByCompare, shuffledRange, reversedRange, swapped return new lists reactively',
        () {
      final controller = WhatController<List<int>>([5, 3, 9, 1, 7]);

      final sortedRangeWhat =
          controller.what.elements.sortedRange(1, 4, (a, b) => a.compareTo(b));
      final sortedByWhat = controller.what.elements.sortedBy((x) => x);
      final shuffledRangeWhat = controller.what.elements.shuffledRange(1, 4);
      final reversedRangeWhat = controller.what.elements.reversedRange(1, 4);
      final swappedWhat = controller.what.elements.swapped(0, 4);

      final t1 = RawWhatTerminal(sortedRangeWhat, onInvalidated: () {});
      final t2 = RawWhatTerminal(sortedByWhat, onInvalidated: () {});
      final t3 = RawWhatTerminal(shuffledRangeWhat, onInvalidated: () {});
      final t4 = RawWhatTerminal(reversedRangeWhat, onInvalidated: () {});
      final t5 = RawWhatTerminal(swappedWhat, onInvalidated: () {});

      t1.activate();
      t2.activate();
      t3.activate();
      t4.activate();
      t5.activate();

      expect(t1.snapshot.data, [5, 1, 3, 9, 7]);
      expect(t2.snapshot.data, [1, 3, 5, 7, 9]);
      expect(t4.snapshot.data, [5, 1, 9, 3, 7]);
      expect(t5.snapshot.data, [7, 3, 9, 1, 5]);

      t1.deactivate();
      t2.deactivate();
      t3.deactivate();
      t4.deactivate();
      t5.deactivate();
    });

    test(
        'equals, slice, elementAtOrNull, slices reactively compute list properties',
        () {
      final controller = WhatController<List<int>>([1, 2, 3]);

      final eqWhat = controller.what.elements.equals([1, 2, 3]);
      final sliceWhat = controller.what.elements.slice(1, 3);
      final elemWhat = controller.what.elements.elementAtOrNull(1);
      final slicesWhat = controller.what.elements.slices(2);

      final tEq = RawWhatTerminal(eqWhat, onInvalidated: () {});
      final tSlice = RawWhatTerminal(sliceWhat, onInvalidated: () {});
      final tElem = RawWhatTerminal(elemWhat, onInvalidated: () {});
      final tSlices = RawWhatTerminal(slicesWhat, onInvalidated: () {});

      tEq.activate();
      tSlice.activate();
      tElem.activate();
      tSlices.activate();

      expect(tEq.snapshot.data, true);
      expect(tSlice.snapshot.data, [2, 3]);
      expect(tElem.snapshot.data, 2);
      expect(tSlices.snapshot.data, [
        [1, 2],
        [3]
      ]);

      tEq.deactivate();
      tSlice.deactivate();
      tElem.deactivate();
      tSlices.deactivate();
    });
  });
}
