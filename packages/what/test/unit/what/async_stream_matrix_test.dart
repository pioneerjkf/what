// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:test/test.dart';
import 'package:what/what.dart';
import '../../test_utils.dart';

void main() {
  group('What Async, Future & Stream Integration Matrix Tests', () {
    test('1.1 future.toWhat transitions from empty to populated and error', () async {
      final completer = Completer<String>();
      final futureWhat = completer.future.toWhat();

      final states = <String>[];
      final dispose = effect((via) {
        final fa = via.state(futureWhat);
        if (fa.hasData) {
          states.add('Data:${fa.data}');
        } else if (fa.hasError) {
          states.add('Error:${fa.snapshot.hasError}');
        } else {
          states.add('Empty');
        }
      });

      await Future<void>.delayed(Duration.zero);
      expect(states, ['Empty']);

      completer.complete('Success');
      await Future<void>.delayed(Duration.zero);

      expect(states, ['Empty', 'Data:Success']);
      dispose();
    });

    test('1.2 stream.toWhat auto-subscribes, auto-cancels and deduplicates events', () async {
      final streamController = StreamController<int>();
      final streamWhat = streamController.stream.toWhat(distinct: true);

      final loggedValues = <int>[];
      final dispose = effect((via) {
        final sa = via.state(streamWhat);
        if (sa.hasData) {
          loggedValues.add(sa.data);
        }
      });

      await Future<void>.delayed(Duration.zero);
      expect(loggedValues, isEmpty);
      expect(streamController.hasListener, isTrue);

      streamController.add(10);
      await Future<void>.delayed(Duration.zero);
      expect(loggedValues, [10]);

      // Duplicate event -> ignored by distinct
      streamController.add(10);
      await Future<void>.delayed(Duration.zero);
      expect(loggedValues, [10]);

      // New event
      streamController.add(20);
      await Future<void>.delayed(Duration.zero);
      expect(loggedValues, [10, 20]);

      // Disposing effect cancels stream subscription
      dispose();
      expect(streamController.hasListener, isFalse);

      await streamController.close();
    });

    test('1.3 Stream error transitions stream.toWhat into error state', () async {
      final streamController = StreamController<String>();
      final streamWhat = streamController.stream.toWhat();

      Object? capturedError;
      final dispose = effect((via) {
        final sa = via.state(streamWhat);
        if (sa.hasError) {
          capturedError = sa.snapshot.hasError;
        }
      });

      expect(capturedError, isNull);

      streamController.addError(TimeoutException('Socket timed out'));
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, isTrue);
      expect(streamWhat.peekState.hasError, isTrue);

      dispose();
      await streamController.close();
    });

    test('1.4 Future collection toWhat combine aggregates multiple futures', () async {
      final c1 = Completer<int>();
      final c2 = Completer<int>();

      final combinedGroup = [c1.future, c2.future].toWhat().combine();

      final results = <List<int>>[];
      final dispose = effect((via) {
        final cg = via.state(combinedGroup);
        if (cg.hasData) {
          results.add(cg.data);
        }
      });

      expect(results, isEmpty);

      c1.complete(100);
      await Future<void>.delayed(Duration.zero);
      expect(results, isEmpty); // waiting for c2

      c2.complete(200);
      await Future<void>.delayed(Duration.zero);
      expect(results, [
        [100, 200]
      ]);

      dispose();
    });

    test('1.5 what.future and what.stream factory methods integrate seamlessly', () async {
      final completer = Completer<String>();
      final futureWhat = What.future(completer.future, initialFactory: () => 'InitialPending');

      final streamController = StreamController<int>();
      final streamWhat = What.stream(streamController.stream, initialFactory: () => 0, distinct: true);

      final combined = computed((via) => '${via(futureWhat)}:${via(streamWhat)}');

      final values = <String>[];
      final dispose = effect((via) {
        values.add(via(combined));
      });

      await Future<void>.delayed(Duration.zero);
      expect(values, ['InitialPending:0']);

      completer.complete('Ready');
      await Future<void>.delayed(Duration.zero);
      expect(values, ['InitialPending:0', 'Ready:0']);

      streamController.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(values, ['InitialPending:0', 'Ready:0', 'Ready:1']);

      // Duplicate stream value ignored by distinct
      streamController.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(values.length, 3);

      dispose();
      await streamController.close();
    });
  });
}
