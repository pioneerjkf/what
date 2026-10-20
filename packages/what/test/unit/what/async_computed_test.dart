// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:what/what.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  group('ComputedFunctor (computed.future, computed.stream, computed.async)', () {
    test('1.1 computed.future completes and transitions state', () async {
      final completer = Completer<String>();
      final greeting = computed.future((_) => completer.future);

      expect(untracked.state(greeting).isEmpty, isTrue);
      expect(untracked.state(greeting).hasData, isFalse);

      String? observed;
      final dispose = effect((via) {
        if (via.state(greeting).hasData) {
          observed = via(greeting);
        }
      });

      expect(observed, isNull);

      completer.complete('Hello, World!');
      await Future<void>.delayed(Duration.zero);

      expect(untracked.state(greeting).hasData, isTrue);
      expect(untracked(greeting), 'Hello, World!');
      expect(observed, 'Hello, World!');

      dispose();
    });

    test('1.2 computed.async alias behaves identically to computed.future', () async {
      final completer = Completer<int>();
      final count = computed.async((_) => completer.future);

      expect(untracked.state(count).isEmpty, isTrue);

      int? observed;
      final dispose = effect((via) {
        if (via.state(count).hasData) {
          observed = via(count);
        }
      });

      completer.complete(999);
      await Future<void>.delayed(Duration.zero);

      expect(untracked.state(count).hasData, isTrue);
      expect(untracked(count), 999);
      expect(observed, 999);

      dispose();
    });

    test('1.3 computed.future supports initialFactory', () async {
      final completer = Completer<String>();
      final withInitialFactory = computed.future(
        (_) => completer.future,
        initialFactory: () => 'FactoryValue',
      );

      expect(untracked.state(withInitialFactory).hasData, isTrue);
      expect(untracked(withInitialFactory), 'FactoryValue');

      String? observedFactory;
      final dispose = effect((via) {
        observedFactory = via(withInitialFactory);
      });

      await Future<void>.delayed(Duration.zero);
      expect(observedFactory, 'FactoryValue');

      completer.complete('UpdatedValue');
      await Future<void>.delayed(Duration.zero);

      expect(untracked(withInitialFactory), 'UpdatedValue');
      expect(observedFactory, 'UpdatedValue');

      dispose();
    });

    test('2.1 computed.future automatically tracks upstream synchronous dependencies', () async {
      final userId = WhatController(1);
      var fetchCount = 0;

      final userProfile = computed.future((via) async {
        fetchCount++;
        final id = via(userId.what);
        return 'User-$id';
      });

      String? currentProfile;
      final dispose = effect((via) {
        if (via.state(userProfile).hasData) {
          currentProfile = via(userProfile);
        }
      });

      await Future<void>.delayed(Duration.zero);
      expect(fetchCount, 1);
      expect(currentProfile, 'User-1');

      // Update upstream dependency
      userId.data = 2;
      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, 2);
      expect(currentProfile, 'User-2');

      dispose();
    });

    test('3.1 Out-of-order race condition immunity (slow old request ignored after fast new request)', () async {
      final query = WhatController('initial');
      final slowCompleter = Completer<String>();
      final fastCompleter = Completer<String>();

      final searchResult = computed.future((via) {
        final q = via(query.what);
        if (q == 'slow') {
          return slowCompleter.future;
        } else if (q == 'fast') {
          return fastCompleter.future;
        }
        return Future.value('Default');
      });

      String? observedResult;
      final dispose = effect((via) {
        if (via.state(searchResult).hasData) {
          observedResult = via(searchResult);
        }
      });

      await Future<void>.delayed(Duration.zero);
      expect(observedResult, 'Default');

      // Trigger slow request
      query.data = 'slow';
      await Future<void>.delayed(Duration.zero);

      // Trigger fast request while slow request is still pending
      query.data = 'fast';
      await Future<void>.delayed(Duration.zero);

      // Fast request resolves first
      fastCompleter.complete('FastResult');
      await Future<void>.delayed(Duration.zero);

      expect(observedResult, 'FastResult');
      expect(untracked(searchResult), 'FastResult');

      // Slow request resolves later - MUST be ignored due to LPDAG topology swap
      slowCompleter.complete('StaleSlowResult');
      await Future<void>.delayed(Duration.zero);

      expect(observedResult, 'FastResult');
      expect(untracked(searchResult), 'FastResult');

      dispose();
    });

    test('4.1 computed.future propagates errors to ErrorWhatState and supports onError fallback', () async {
      final shouldFail = WhatController(false);

      final result = computed.future((via) async {
        if (via(shouldFail.what)) {
          throw FormatException('Malformed payload');
        }
        return 'Success';
      });

      Object? lastError;
      String? lastData;
      final dispose = effect((via) {
        if (via.state(result).hasError) {
          lastError = via.state(result).snapshot.error;
        } else if (via.state(result).hasData) {
          lastData = via(result);
        }
      });

      await Future<void>.delayed(Duration.zero);
      expect(lastData, 'Success');
      expect(untracked.state(result).hasError, isFalse);

      // Trigger failure
      shouldFail.data = true;
      await Future<void>.delayed(Duration.zero);

      expect(untracked.state(result).hasError, isTrue);
      expect(lastError, isA<FormatException>());

      dispose();

      // Test with onError fallback
      final fallbackResult = computed.future<String>(
        (_) async => throw StateError('Boom'),
        onError: (error, [st]) => 'Recovered',
      );

      String? fallbackObserved;
      final disposeFallback = effect((via) {
        if (via.state(fallbackResult).hasData) {
          fallbackObserved = via(fallbackResult);
        }
      });

      await Future<void>.delayed(Duration.zero);
      expect(untracked.state(fallbackResult).hasData, isTrue);
      expect(untracked(fallbackResult), 'Recovered');
      expect(fallbackObserved, 'Recovered');

      disposeFallback();
    });

    test('5.1 computed.future respects reactive guards (guard and reason)', () async {
      final isReady = WhatController(false);
      var computeCalled = false;

      final guarded = computed.future(
        (_) async {
          computeCalled = true;
          return 42;
        },
        guard: (via) => via(isReady.what).guarded('AwaitingReadyState'),
      );

      int? observed;
      final dispose = effect((via) {
        if (via.state(guarded).hasData) {
          observed = via(guarded);
        }
      });

      expect(untracked.state(guarded).isEmpty, isTrue);
      expect(untracked.state(guarded).snapshot.emptyReason, 'AwaitingReadyState');
      expect(computeCalled, isFalse);
      expect(observed, isNull);

      // Enable guard
      isReady.data = true;
      await Future<void>.delayed(Duration.zero);

      expect(computeCalled, isTrue);
      expect(untracked.state(guarded).hasData, isTrue);
      expect(untracked(guarded), 42);
      expect(observed, 42);

      dispose();
    });

    test('6.1 computed.stream receives sequential events and auto-cancels old stream on dependency change', () async {
      final channel = WhatController('A');
      final scA = StreamController<String>.broadcast();
      final scB = StreamController<String>.broadcast();

      final activeStream = computed.stream((via) {
        if (via(channel.what) == 'A') {
          return scA.stream;
        } else {
          return scB.stream;
        }
      });

      final received = <String>[];
      final dispose = effect((via) {
        if (via.state(activeStream).hasData) {
          received.add(via(activeStream));
        }
      });

      await Future<void>.delayed(Duration.zero);

      // Stream A events
      scA.add('A1');
      await Future<void>.delayed(Duration.zero);
      expect(received, ['A1']);

      scA.add('A2');
      await Future<void>.delayed(Duration.zero);
      expect(received, ['A1', 'A2']);

      // Switch to Channel B
      channel.data = 'B';
      await Future<void>.delayed(Duration.zero);

      // Emitting on old stream A must be completely ignored
      scA.add('A3-Orphan');
      await Future<void>.delayed(Duration.zero);
      expect(received, ['A1', 'A2']);

      // Emitting on new stream B
      scB.add('B1');
      await Future<void>.delayed(Duration.zero);
      expect(received, ['A1', 'A2', 'B1']);

      dispose();
      await scA.close();
      await scB.close();
    });

    test('6.2 computed.stream auto-cancels subscription when deactivated', () async {
      final controller = StreamController<int>();
      final streamNode = computed.stream((_) => controller.stream);

      expect(controller.hasListener, isFalse);

      final dispose = effect((via) {
        if (via.state(streamNode).hasData) {
          // observe
        }
      });

      await Future<void>.delayed(Duration.zero);
      // While active, stream is subscribed
      expect(controller.hasListener, isTrue);

      // When deactivated (dispose effect), subscription is automatically cancelled
      dispose();
      expect(controller.hasListener, isFalse);

      await controller.close();
    });

    test('7.1 Synchronous computed(...) preserves 100% backward compatibility and inlined speed', () {
      final a = WhatController(10);
      final b = WhatController(20);

      // Standard top-level computed
      final sum = computed((via) => via(a.what) + via(b.what));
      expect(untracked(sum), 30);

      a.data = 15;
      expect(untracked(sum), 35);

      // what.computed factory accessor
      final product = computed((via) => via(a.what) * via(b.what));
      expect(untracked(product), 300);

      b.data = 2;
      expect(untracked(product), 30);
    });

    // =========================================================================
    // 8. _DeLorean (Future Bridge) Error Recovery & Sync Failure Edge Cases
    // =========================================================================
    group('8. Future Bridge (_DeLorean) Error Recovery & Sync Failures', () {
      test('8.1 initialFactory exception initializes node into ErrorWhatState', () {
        final node = computed.future(
          (_) => Completer<String>().future,
          initialFactory: () => throw StateError('InitFactoryFailed'),
        );

        final terminal = RawWhatTerminal(node, onInvalidated: () {})..activate();
        expect(terminal.hasError, isTrue);
        expect(terminal.snapshot.error, isA<StateError>());
        terminal.deactivate();
      });

      test('8.2 Async onError callback throws exception falling back to setError', () async {
        final node = computed.future<String>(
          (_) => Future.error(StateError('OriginalAsyncError')),
          onError: (e, [s]) => throw FormatException('OnErrorFailed'),
        );

        final terminal = RawWhatTerminal(node, onInvalidated: () {})..activate();
        await Future<void>.delayed(Duration.zero);

        expect(terminal.hasError, isTrue);
        expect(terminal.snapshot.error, isA<FormatException>());
        terminal.deactivate();
      });

      test('8.3 Synchronous future.then failure recovers via onError or sets error', () {
        // Case A: onError recovers
        final recoveredNode = computed.future<String>(
          (_) => _SyncThrowingFuture<String>(),
          onError: (e, [s]) => 'SyncRecovered',
        );
        final tRec = RawWhatTerminal(recoveredNode, onInvalidated: () {})..activate();
        expect(tRec.data, 'SyncRecovered');
        tRec.deactivate();

        // Case B: onError throws secondary error
        final secondaryFailNode = computed.future<String>(
          (_) => _SyncThrowingFuture<String>(),
          onError: (e, [s]) => throw FormatException('SyncSecondaryFail'),
        );
        final tSec = RawWhatTerminal(secondaryFailNode, onInvalidated: () {})..activate();
        expect(tSec.hasError, isTrue);
        expect(tSec.snapshot.error, isA<FormatException>());
        tSec.deactivate();

        // Case C: No onError provided
        final directFailNode = computed.future<String>(
          (_) => _SyncThrowingFuture<String>(),
        );
        final tDir = RawWhatTerminal(directFailNode, onInvalidated: () {})..activate();
        expect(tDir.hasError, isTrue);
        expect(tDir.snapshot.error, isA<StateError>());
        tDir.deactivate();
      });
    });

    // =========================================================================
    // 9. _PragueVltava (Stream Bridge) Lifecycle, InitialFactory & Error Handling
    // =========================================================================
    group('9. Stream Bridge (_PragueVltava) Edge Cases', () {
      test('9.1 initialFactory provides synchronous initial value before stream events', () async {
        final sc = StreamController<String>();
        final streamNode = computed.stream(
          (_) => sc.stream,
          initialFactory: () => 'InitialStreamValue',
        );

        final terminal = RawWhatTerminal(streamNode, onInvalidated: () {})..activate();
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 'InitialStreamValue');

        sc.add('FirstStreamEvent');
        await Future<void>.delayed(Duration.zero);
        expect(terminal.data, 'FirstStreamEvent');

        terminal.deactivate();
        await sc.close();
      });

      test('9.2 initialFactory exception initializes stream node into ErrorWhatState', () {
        final sc = StreamController<String>();
        final streamNode = computed.stream(
          (_) => sc.stream,
          initialFactory: () => throw StateError('StreamInitFailed'),
        );

        final terminal = RawWhatTerminal(streamNode, onInvalidated: () {})..activate();
        expect(terminal.hasError, isTrue);
        expect(terminal.snapshot.error, isA<StateError>());

        terminal.deactivate();
        sc.close();
      });

      test('9.3 Stream event error handling with recovery, secondary throw, or direct error', () async {
        // Case A: onError recovers error event to value
        final scA = StreamController<String>();
        final nodeA = computed.stream<String>(
          (_) => scA.stream,
          onError: (e, [s]) => 'RecoveredStreamError',
        );
        final tA = RawWhatTerminal(nodeA, onInvalidated: () {})..activate();
        scA.addError(StateError('OriginalStreamError'));
        await Future<void>.delayed(Duration.zero);
        expect(tA.hasData, isTrue);
        expect(tA.data, 'RecoveredStreamError');
        tA.deactivate();
        await scA.close();

        // Case B: onError throws secondary error
        final scB = StreamController<String>();
        final nodeB = computed.stream<String>(
          (_) => scB.stream,
          onError: (e, [s]) => throw FormatException('StreamOnErrorFailed'),
        );
        final tB = RawWhatTerminal(nodeB, onInvalidated: () {})..activate();
        scB.addError(StateError('Original'));
        await Future<void>.delayed(Duration.zero);
        expect(tB.hasError, isTrue);
        expect(tB.snapshot.error, isA<FormatException>());
        tB.deactivate();
        await scB.close();

        // Case C: No onError provided
        final scC = StreamController<String>();
        final nodeC = computed.stream<String>(
          (_) => scC.stream,
        );
        final tC = RawWhatTerminal(nodeC, onInvalidated: () {})..activate();
        scC.addError(StateError('StreamFatal'));
        await Future<void>.delayed(Duration.zero);
        expect(tC.hasError, isTrue);
        expect(tC.snapshot.error, isA<StateError>());
        tC.deactivate();
        await scC.close();
      });

      test('9.4 cancelOnError: true unsubscribes stream upon error', () async {
        final sc = StreamController<String>();
        final streamNode = computed.stream<String>(
          (_) => sc.stream,
          cancelOnError: true,
        );

        final terminal = RawWhatTerminal(streamNode, onInvalidated: () {})..activate();
        expect(sc.hasListener, isTrue);

        sc.addError(StateError('AbortError'));
        await Future<void>.delayed(Duration.zero);

        expect(terminal.hasError, isTrue);
        // Subscription is canceled
        expect(sc.hasListener, isFalse);

        terminal.deactivate();
        await sc.close();
      });

      test('9.5 Stream onDone closes subscription and marks done', () async {
        final sc = StreamController<String>();
        final streamNode = computed.stream<String>(
          (_) => sc.stream,
        );

        final terminal = RawWhatTerminal(streamNode, onInvalidated: () {})..activate();
        expect(sc.hasListener, isTrue);

        sc.add('PreClose');
        await Future<void>.delayed(Duration.zero);
        expect(terminal.data, 'PreClose');

        // Close stream -> triggers onDone
        await sc.close();
        await Future<void>.delayed(Duration.zero);
        expect(sc.hasListener, isFalse);

        // Deactivate and re-activate does not re-subscribe because _isDone is true
        terminal.deactivate();
        terminal.activate();
        expect(sc.hasListener, isFalse);
        terminal.deactivate();
      });

      test('9.6 Synchronous stream.listen failure recovers via onError or sets error', () {
        // Case A: onError recovers
        final recNode = computed.stream<String>(
          (_) => _SyncThrowingStream<String>(),
          onError: (e, [s]) => 'StreamSyncRecovered',
        );
        final tRec = RawWhatTerminal(recNode, onInvalidated: () {})..activate();
        expect(tRec.data, 'StreamSyncRecovered');
        tRec.deactivate();

        // Case B: onError secondary throw
        final secNode = computed.stream<String>(
          (_) => _SyncThrowingStream<String>(),
          onError: (e, [s]) => throw FormatException('StreamSyncSecFail'),
        );
        final tSec = RawWhatTerminal(secNode, onInvalidated: () {})..activate();
        expect(tSec.hasError, isTrue);
        expect(tSec.snapshot.error, isA<FormatException>());
        tSec.deactivate();

        // Case C: No onError
        final failNode = computed.stream<String>(
          (_) => _SyncThrowingStream<String>(),
        );
        final tFail = RawWhatTerminal(failNode, onInvalidated: () {})..activate();
        expect(tFail.hasError, isTrue);
        expect(tFail.snapshot.error, isA<StateError>());
        tFail.deactivate();
      });
    });
  });
}

class _SyncThrowingFuture<T> implements Future<T> {
  @override
  Stream<T> asStream() => throw UnimplementedError();

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) => throw UnimplementedError();

  @override
  Future<S> then<S>(FutureOr<S> Function(T value) onValue, {Function? onError}) {
    throw StateError('SyncFutureThenFailed');
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) => throw UnimplementedError();

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) => throw UnimplementedError();
}

class _SyncThrowingStream<T> extends Stream<T> {
  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    throw StateError('SyncStreamListenFailed');
  }
}
