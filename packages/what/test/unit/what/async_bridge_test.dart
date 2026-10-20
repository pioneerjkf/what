// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('Async Reactivity & Stream/Future Bridge Unit Tests', () {
    // =========================================================================
    // 1. Future.toWhat() Tests
    // =========================================================================
    group('1. Future.toWhat()', () {
      test('1.1 resolves with a value when Future completes successfully', () async {
        final completer = Completer<int>();
        final asyncWhat = completer.future.toWhat();

        expect(untracked.state(asyncWhat).snapshot.isEmpty, isTrue);

        final terminal = RawWhatTerminal(asyncWhat, onInvalidated: () {});
        terminal.activate();

        completer.complete(42);
        await Future<void>.delayed(Duration.zero);

        expect(terminal.snapshot.hasData, isTrue);
        expect(terminal.data, 42);

        terminal.deactivate();
      });

      test('1.2 resolves with an error when Future completes with an error', () async {
        final completer = Completer<int>();
        final asyncWhat = completer.future.toWhat();

        final terminal = RawWhatTerminal(asyncWhat, onInvalidated: () {});
        terminal.activate();

        final exception = Exception('Something went wrong');
        completer.completeError(exception);
        await Future<void>.delayed(Duration.zero);

        expect(terminal.snapshot.hasError, isTrue);
        expect(terminal.error, exception);

        terminal.deactivate();
      });

      test('1.3 prevents multiple subscriptions to the same Future', () async {
        final completer = Completer<int>();
        final asyncWhat = completer.future.toWhat();

        int onDirtyCount = 0;
        final terminal = RawWhatTerminal(asyncWhat, onInvalidated: () {
          onDirtyCount++;
        });

        terminal.activate();
        terminal.deactivate();
        terminal.activate();

        completer.complete(100);
        await Future<void>.delayed(Duration.zero);

        expect(terminal.data, 100);
        expect(onDirtyCount, 1);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 2. Iterable<Future>.toWhat() Tests
    // =========================================================================
    group('2. Iterable<Future>.toWhat()', () {
      test('2.1 transforms a list of Futures into a list of What nodes', () async {
        final completer1 = Completer<String>();
        final completer2 = Completer<String>();
        final futures = [completer1.future, completer2.future];

        final group = futures.toWhat();
        expect(untracked(group).length, 2);

        final t1 = RawWhatTerminal(untracked(group)[0], onInvalidated: () {});
        final t2 = RawWhatTerminal(untracked(group)[1], onInvalidated: () {});
        t1.activate();
        t2.activate();

        completer1.complete('Hello');
        completer2.complete('World');
        await Future<void>.delayed(Duration.zero);

        expect(t1.data, 'Hello');
        expect(t2.data, 'World');

        t1.deactivate();
        t2.deactivate();
      });
    });

    // =========================================================================
    // 3. Stream.toWhat() Tests
    // =========================================================================
    group('3. Stream.toWhat()', () {
      test('3.1 updates what data as stream events occur', () async {
        final controller = StreamController<int>();
        final asyncWhat = controller.stream.toWhat();

        int onDirtyCount = 0;
        final terminal = RawWhatTerminal(asyncWhat, onInvalidated: () {
          onDirtyCount++;
        });
        terminal.activate();

        expect(terminal.snapshot.isEmpty, isTrue);

        controller.add(1);
        await Future<void>.delayed(Duration.zero);
        expect(terminal.data, 1);
        expect(onDirtyCount, 1);

        controller.add(2);
        await Future<void>.delayed(Duration.zero);
        expect(terminal.data, 2);
        expect(onDirtyCount, 2);

        await controller.close();
        terminal.deactivate();
      });

      test('3.2 handles distinct correctly', () async {
        final controller = StreamController<int>();
        final asyncWhat = controller.stream.toWhat(distinct: true);

        int onDirtyCount = 0;
        late final RawWhatTerminal<int> terminal;
        terminal = RawWhatTerminal(asyncWhat, onInvalidated: () {
          onDirtyCount++;
          terminal.snapshot;
        });
        terminal.activate();

        controller.add(1);
        await Future<void>.delayed(Duration.zero);

        controller.add(1); // Ignored
        await Future<void>.delayed(Duration.zero);

        controller.add(2);
        await Future<void>.delayed(Duration.zero);

        expect(terminal.data, 2);
        expect(onDirtyCount, 2);

        await controller.close();
        terminal.deactivate();
      });

      test('3.3 handles errors and cancelOnError correctly', () async {
        final controller = StreamController<int>();
        final asyncWhat = controller.stream.toWhat(cancelOnError: true);

        final terminal = RawWhatTerminal(asyncWhat, onInvalidated: () {});
        terminal.activate();

        final exception = Exception('Stream error');
        controller.addError(exception);
        await Future<void>.delayed(Duration.zero);

        expect(terminal.snapshot.hasError, isTrue);
        expect(terminal.error, exception);
        expect(controller.hasListener, isFalse);

        await controller.close();
        terminal.deactivate();
      });

      test('3.4 unsubscribes when terminal is deactivated', () async {
        final controller = StreamController<int>();
        final asyncWhat = controller.stream.toWhat();

        final terminal = RawWhatTerminal(asyncWhat, onInvalidated: () {});
        terminal.activate();

        expect(controller.hasListener, isTrue);

        terminal.deactivate();
        expect(controller.hasListener, isFalse);

        await controller.close();
      });
    });

    // =========================================================================
    // 4. Iterable<Stream>.toWhat() Tests
    // =========================================================================
    group('4. Iterable<Stream>.toWhat()', () {
      test('4.1 transforms a list of Streams into a list of What nodes', () async {
        final controller1 = StreamController<String>();
        final controller2 = StreamController<String>();
        final streams = [controller1.stream, controller2.stream];

        final group = streams.toWhat();
        expect(untracked(group).length, 2);

        final t1 = RawWhatTerminal(untracked(group)[0], onInvalidated: () {});
        final t2 = RawWhatTerminal(untracked(group)[1], onInvalidated: () {});
        t1.activate();
        t2.activate();

        controller1.add('Hello');
        controller2.add('World');
        await Future<void>.delayed(Duration.zero);

        expect(t1.data, 'Hello');
        expect(t2.data, 'World');

        t1.deactivate();
        t2.deactivate();
        await controller1.close();
        await controller2.close();
      });
    });

    // =========================================================================
    // 5. What.future() & What.stream() Factory Constructor Tests
    // =========================================================================
    group('5. What.future() & What.stream() Factory Constructors', () {
      test('5.1 What.future bridges Future and resolves upon activation', () async {
        final completer = Completer<String>();
        final asyncWhat = What.future(completer.future, initialFactory: () => 'Loading');

        expect(untracked.state(asyncWhat).snapshot.hasData, isTrue);
        expect(untracked(asyncWhat), 'Loading');

        final terminal = RawWhatTerminal(asyncWhat, onInvalidated: () {});
        terminal.activate();

        completer.complete('ResolvedValue');
        await Future<void>.delayed(Duration.zero);

        expect(terminal.data, 'ResolvedValue');
        terminal.deactivate();
      });

      test('5.2 What.stream bridges Stream with lifecycle and distinct comparator', () async {
        final streamController = StreamController<int>();
        final asyncWhat = What.stream(
          streamController.stream,
          initialFactory: () => 0,
          distinct: true,
        );

        expect(untracked(asyncWhat), 0);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(asyncWhat, onInvalidated: () => dirtyCount++);
        terminal.activate();

        streamController.add(10);
        await Future<void>.delayed(Duration.zero);
        expect(terminal.data, 10);
        expect(dirtyCount, 1);

        // Duplicate value with distinct: true should not trigger dirty notification
        streamController.add(10);
        await Future<void>.delayed(Duration.zero);
        expect(dirtyCount, 1);

        streamController.add(20);
        await Future<void>.delayed(Duration.zero);
        expect(terminal.data, 20);
        expect(dirtyCount, 2);

        terminal.deactivate();
        await streamController.close();
      });
    });
  });
}
