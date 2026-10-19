// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:test/test.dart';
import '../../test_utils.dart';

void main() {
  group('What Async Extensions', () {
    test('Future.toWhat converts Future to reactive What node', () async {
      final completer = Completer<int>();
      final futureWhat = completer.future.toWhat();

      expect(futureWhat.peekState.isEmpty, isTrue);
      expect(futureWhat.peekState.hasData, isFalse);

      var effectRuns = 0;
      int? lastValue;

      final dispose = effect((via) {
        effectRuns++;
        final fa = via.state(futureWhat);
        if (fa.hasData) {
          lastValue = fa.data;
        }
      });

      await Future.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(lastValue, isNull);

      completer.complete(42);
      await Future.delayed(Duration.zero);

      expect(effectRuns, 2);
      expect(lastValue, 42);
      expect(futureWhat.peekState.hasData, isTrue);

      dispose();
    });

    test('Iterable<Future>.toWhat groups concurrent futures into a What list', () async {
      final c1 = Completer<int>();
      final c2 = Completer<int>();

      final group = [c1.future, c2.future].toWhat();
      final total = group.sum();

      var effectRuns = 0;
      int? currentTotal;

      final dispose = effect((via) {
        effectRuns++;
        final t = via.state(total);
        if (t.hasData) {
          currentTotal = t.data;
        }
      });

      await Future.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(currentTotal, isNull);

      c1.complete(10);
      c2.complete(20);
      await Future.delayed(Duration.zero);

      expect(effectRuns, 3);
      expect(currentTotal, 30);

      dispose();
    });

    test('Stream.toWhat streams events reactively', () async {
      final controller = StreamController<String>();
      final streamWhat = controller.stream.toWhat();

      var effectRuns = 0;
      String? latestMsg;

      final dispose = effect((via) {
        effectRuns++;
        final sa = via.state(streamWhat);
        if (sa.hasData) {
          latestMsg = sa.data;
        }
      });

      await Future.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(latestMsg, isNull);

      controller.add('event-1');
      await Future.delayed(Duration.zero);

      expect(effectRuns, 2);
      expect(latestMsg, 'event-1');

      controller.add('event-2');
      await Future.delayed(Duration.zero);

      expect(effectRuns, 3);
      expect(latestMsg, 'event-2');

      dispose();
      await controller.close();
    });

    test('Iterable<Stream>.toWhat groups streams into a What list', () async {
      final s1 = StreamController<int>();
      final s2 = StreamController<int>();

      final group = [s1.stream, s2.stream].toWhat();
      final combined = group.combine();

      var runs = 0;
      List<int>? values;

      final dispose = effect((via) {
        runs++;
        final c = via.state(combined);
        if (c.hasData) {
          values = c.data;
        }
      });

      s1.add(100);
      s2.add(200);
      await Future.delayed(Duration.zero);

      expect(runs, 3);
      expect(values, [100, 200]);

      dispose();
      await s1.close();
      await s2.close();
    });

    test('Future.toWhat transitions to hasError on error completion and triggers effect', () async {
      final completer = Completer<String>();
      final futureWhat = completer.future.toWhat();

      var effectRuns = 0;
      Object? observedError;

      final dispose = effect((via) {
        effectRuns++;
        final fa = via.state(futureWhat);
        if (fa.hasError) {
          observedError = fa.snapshot.error;
        }
      });

      await Future.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observedError, isNull);

      completer.completeError(FormatException('Network error'));
      await Future.delayed(Duration.zero);

      expect(effectRuns, 2);
      expect(futureWhat.peekState.hasError, isTrue);
      expect(observedError, isA<FormatException>());

      dispose();
    });

    test('Stream.toWhat handles errors and recovers on subsequent data emissions', () async {
      final controller = StreamController<int>.broadcast();
      final streamWhat = controller.stream.toWhat();

      var runs = 0;
      int? lastData;
      bool hasErrorState = false;

      final dispose = effect((via) {
        runs++;
        final sa = via.state(streamWhat);
        hasErrorState = sa.hasError;
        if (sa.hasData) {
          lastData = sa.data;
        }
      });

      await Future.delayed(Duration.zero);
      expect(runs, 1);
      expect(hasErrorState, isFalse);

      // 1. Data event
      controller.add(10);
      await Future.delayed(Duration.zero);
      expect(runs, 2);
      expect(lastData, 10);
      expect(hasErrorState, isFalse);

      // 2. Error event
      controller.addError(TimeoutException('Timeout'));
      await Future.delayed(Duration.zero);
      expect(runs, 3);
      expect(hasErrorState, isTrue);

      // 3. Recovery data event
      controller.add(20);
      await Future.delayed(Duration.zero);
      expect(runs, 4);
      expect(lastData, 20);
      expect(hasErrorState, isFalse);

      dispose();
      await controller.close();
    });

    test('Stream.toWhat respects distinct deduplication', () async {
      final controller = StreamController<String>();
      final streamWhat = controller.stream.toWhat(distinct: true);

      var runs = 0;
      final dispose = effect((via) {
        runs++;
        via.state(streamWhat).dataOrNull;
      });

      await Future.delayed(Duration.zero);
      expect(runs, 1);

      controller.add('hello');
      await Future.delayed(Duration.zero);
      expect(runs, 2);

      // Emit identical value -> distinct ignores it
      controller.add('hello');
      await Future.delayed(Duration.zero);
      expect(runs, 2); // No extra effect run!

      controller.add('world');
      await Future.delayed(Duration.zero);
      expect(runs, 3);

      dispose();
      await controller.close();
    });
  });
}
