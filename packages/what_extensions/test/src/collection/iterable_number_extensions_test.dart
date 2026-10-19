import 'package:what_extensions/what_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('NumericWhatElementsExtension', () {
    test('sum and average compute numeric elements reactively', () {
      final controller = WhatController<List<double>>([1.5, 2.5, 4.0]);

      final sumWhat = controller.what.elements.sum;
      final avgWhat = controller.what.elements.average;

      final termSum = RawWhatTerminal(sumWhat, onInvalidated: () {});
      final termAvg = RawWhatTerminal(avgWhat, onInvalidated: () {});
      termSum.activate();
      termAvg.activate();

      expect(termSum.snapshot.data, 8.0);
      expect(termAvg.snapshot.data, 8.0 / 3);

      controller.set([10.0, 20.0]);
      expect(termSum.snapshot.data, 30.0);
      expect(termAvg.snapshot.data, 15.0);

      controller.set([]);
      expect(termSum.snapshot.data, 0.0);
      expect(termAvg.snapshot.hasError, isTrue);
      expect(termAvg.snapshot.error, isA<StateError>());

      termSum.deactivate();
      termAvg.deactivate();
    });
  });
}
