// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:what/what.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  group('retained (Stale-While-Revalidate Functor & Coupler Integration) Suite', () {
    test('1.1 Basic SWR transition retains previous data and toggles pending via coupler', () async {
      final query = WhatController('apple');
      Completer<String>? activeCompleter;

      final rawFuture = computed.future((via) {
        via(query.what);
        final completer = Completer<String>();
        activeCompleter = completer;
        return completer.future;
      });

      final pendingCoupler = WhatCoupler<bool>.late();
      final smooth = rawFuture.retained(pending: pendingCoupler);
      final pending = pendingCoupler.what;

      // Initially empty before first resolution
      expect(smooth.peekState.isEmpty, isTrue);
      expect(smooth.peekState.hasData, isFalse);
      expect(pending.peek, isFalse);

      final observedData = <String>[];
      final observedPending = <bool>[];

      final disposeData = effect((via) {
        if (via.state(smooth).hasData) observedData.add(via(smooth));
      });
      final disposePending = effect((via) {
        observedPending.add(via(pending));
      });

      await Future<void>.delayed(Duration.zero);

      // 1. Resolve first request ('apple')
      activeCompleter!.complete('AppleResults');
      await Future<void>.delayed(Duration.zero);

      expect(smooth.peekState.hasData, isTrue);
      expect(smooth.peek, equals('AppleResults'));
      expect(pending.peek, isFalse);
      expect(observedData, contains('AppleResults'));

      // 2. Change query to 'banana' -> starts background transition
      query.data = 'banana';
      await Future<void>.delayed(Duration.zero);

      // FLICKER-FREE: Previous data is retained!
      expect(smooth.peekState.hasData, isTrue);
      expect(smooth.peek, equals('AppleResults'));
      expect(pending.peek, isTrue);
      expect(observedPending.last, isTrue);

      // 3. Resolve 'banana' request
      activeCompleter!.complete('BananaResults');
      await Future<void>.delayed(Duration.zero);

      expect(smooth.peekState.hasData, isTrue);
      expect(smooth.peek, equals('BananaResults'));
      expect(pending.peek, isFalse);
      expect(observedData.last, equals('BananaResults'));

      disposeData();
      disposePending();
    });

    test('1.2 Chained .retained() creates working pure What<T> with zero-alloc pending', () async {
      final query = WhatController('cat');
      Completer<String>? activeCompleter;

      final smooth = computed.future((via) {
        via(query.what);
        final c = Completer<String>();
        activeCompleter = c;
        return c.future;
      }).retained();

      final terminal = RawWhatTerminal(smooth, onInvalidated: () {});
      terminal.activate();

      activeCompleter!.complete('CatData');
      await Future<void>.delayed(Duration.zero);
      expect(smooth.peek, equals('CatData'));

      // Mutate upstream
      query.data = 'dog';
      await Future<void>.delayed(Duration.zero);

      // Retains CatData while dog is in-flight without allocating secondary facet
      expect(smooth.peek, equals('CatData'));

      activeCompleter!.complete('DogData');
      await Future<void>.delayed(Duration.zero);

      expect(smooth.peek, equals('DogData'));

      terminal.deactivate();
    });

    test('2.1 Coupler surgical reactivity: pending facet pulses independently from data', () async {
      final id = WhatController(1);
      Completer<String>? activeCompleter;

      final pendingCoupler = WhatCoupler<bool>.late();
      final user = computed.future((via) {
        via(id.what);
        final c = Completer<String>();
        activeCompleter = c;
        return c.future;
      }).retained(pending: pendingCoupler);
      final pending = pendingCoupler.what;

      var dataPulseCount = 0;
      var pendingPulseCount = 0;
      var dataDownstreamRuns = 0;

      final downstream = computed((via) {
        dataDownstreamRuns++;
        return 'User: ${via(user)}';
      });

      final termDownstream = RawWhatTerminal(downstream, onInvalidated: () {});
      final termData = RawWhatTerminal(user, onInvalidated: () => dataPulseCount++);
      final termPending = RawWhatTerminal(pending, onInvalidated: () => pendingPulseCount++);
      termDownstream.activate();
      termData.activate();
      termPending.activate();

      // Initial load completes
      activeCompleter!.complete('User#1');
      await Future<void>.delayed(Duration.zero);
      expect(user.peek, 'User#1');
      expect(pending.peek, isFalse);
      expect(termDownstream.data, equals('User: User#1'));
      expect(dataDownstreamRuns, 1);

      final basePendingPulses = pendingPulseCount;
      final baseUserVersion = user.debug.snapshot().version;

      // Switch to ID 2 (in-flight)
      id.data = 2;
      await Future<void>.delayed(Duration.zero);

      // Pending facet MUST pulse dirty (false -> true)
      expect(pendingPulseCount, greaterThan(basePendingPulses));
      // In 2-Phase LPDAG, dirty propagates downstream during Push-Dirty phase to
      // preserve lazy-pull, but retained data preserves its version to drop redundant recomputation!
      expect(user.debug.snapshot().version, equals(baseUserVersion));
      expect(termDownstream.data, equals('User: User#1'));
      expect(
        dataDownstreamRuns,
        1,
        reason: 'Downstream computed must NOT re-evaluate while retaining stale data',
      );
      expect(pending.peek, isTrue);

      // Data is still User#1
      expect(user.peek, 'User#1');

      // Complete ID 2
      activeCompleter!.complete('User#2');
      await Future<void>.delayed(Duration.zero);

      expect(user.peek, 'User#2');
      expect(pending.peek, isFalse);
      expect(termDownstream.data, equals('User: User#2'));
      expect(dataDownstreamRuns, 2);

      termDownstream.deactivate();
      termData.deactivate();
      termPending.deactivate();
    });

    test('3.1 Zero-Zombie out-of-order race condition immunity', () async {
      final query = WhatController('initial');
      final slowCompleter = Completer<String>();
      final fastCompleter = Completer<String>();

      final pendingCoupler = WhatCoupler<bool>.late();
      final search = computed.future((via) {
        final q = via(query.what);
        if (q == 'slow') return slowCompleter.future;
        if (q == 'fast') return fastCompleter.future;
        return Future.value('InitialData');
      }).retained(pending: pendingCoupler);

      final terminal = RawWhatTerminal(search, onInvalidated: () {});
      terminal.activate();
      await Future<void>.delayed(Duration.zero);

      expect(search.peek, equals('InitialData'));
      expect(pendingCoupler.what.peek, isFalse);

      // Trigger slow
      query.data = 'slow';
      await Future<void>.delayed(Duration.zero);
      expect(search.peek, equals('InitialData'));
      expect(pendingCoupler.what.peek, isTrue);

      // Trigger fast while slow is still in-flight
      query.data = 'fast';
      await Future<void>.delayed(Duration.zero);
      expect(search.peek, equals('InitialData'));
      expect(pendingCoupler.what.peek, isTrue);

      // Fast completes first
      fastCompleter.complete('FastResult');
      await Future<void>.delayed(Duration.zero);

      expect(search.peek, equals('FastResult'));
      expect(pendingCoupler.what.peek, isFalse);

      // Slow completes later -> MUST be ignored due to LPDAG topology switch
      slowCompleter.complete('StaleSlowResult');
      await Future<void>.delayed(Duration.zero);

      expect(search.peek, equals('FastResult'));
      expect(pendingCoupler.what.peek, isFalse);

      terminal.deactivate();
    });

    test('4.1 Returning empty data (Future.value) smoothly transitions and settles pending', () async {
      final query = WhatController('search');
      final pendingCoupler = WhatCoupler<bool>.late();

      final search = computed.future((via) {
        final q = via(query.what);
        if (q.isEmpty) return Future.value(<String>[]);
        return Future.value(<String>['Result for $q']);
      }).retained(pending: pendingCoupler);

      final term = RawWhatTerminal(search, onInvalidated: () {});
      term.activate();
      await Future<void>.delayed(Duration.zero);

      expect(search.peekState.hasData, isTrue);
      expect(search.peek, equals(['Result for search']));
      expect(pendingCoupler.what.peek, isFalse);

      // Clear query
      query.data = '';
      await Future<void>.delayed(Duration.zero);

      // Smoothly transitions to empty list and pending is false
      expect(search.peekState.hasData, isTrue);
      expect(search.peek, isEmpty);
      expect(pendingCoupler.what.peek, isFalse);

      term.deactivate();
    });

    test('5.1 Errors immediately clear retained data, surface error state, and clear pending', () async {
      final trigger = WhatController(1);
      Completer<String>? completer;
      final pendingCoupler = WhatCoupler<bool>.late();

      final node = computed.future((via) {
        final t = via(trigger.what);
        if (t == 2) return Future.error(StateError('FetchFailed'));
        final c = Completer<String>();
        completer = c;
        return c.future;
      }).retained(pending: pendingCoupler);

      final term = RawWhatTerminal(node, onInvalidated: () {});
      term.activate();

      completer!.complete('Success1');
      await Future<void>.delayed(Duration.zero);
      expect(node.peek, equals('Success1'));

      // Trigger error
      trigger.data = 2;
      await Future<void>.delayed(Duration.zero);

      // Clears retained data and honestly propagates error
      expect(node.peekState.hasData, isFalse);
      expect(node.peekState.hasError, isTrue);
      expect(node.peekState.error, isA<StateError>());
      expect(pendingCoupler.what.peek, isFalse);

      term.deactivate();
    });

    test('6.1 Stream transition retains last stream value while new stream prepares', () async {
      final channel = WhatController('A');
      StreamController<String>? controller;
      final pendingCoupler = WhatCoupler<bool>.late();

      final streamNode = computed.stream((via) {
        via(channel.what);
        final c = StreamController<String>();
        controller = c;
        return c.stream;
      }).retained(pending: pendingCoupler);

      final term = RawWhatTerminal(streamNode, onInvalidated: () {});
      term.activate();

      // Emit first value on Channel A
      controller!.add('MsgA1');
      await Future<void>.delayed(Duration.zero);
      expect(streamNode.peek, equals('MsgA1'));
      expect(pendingCoupler.what.peek, isFalse);

      // Switch to Channel B (new stream hasn't emitted yet)
      channel.data = 'B';
      await Future<void>.delayed(Duration.zero);

      // Stale-While-Revalidate: MsgA1 retained!
      expect(streamNode.peek, equals('MsgA1'));
      expect(pendingCoupler.what.peek, isTrue);

      // Emit first value on Channel B
      controller!.add('MsgB1');
      await Future<void>.delayed(Duration.zero);

      expect(streamNode.peek, equals('MsgB1'));
      expect(pendingCoupler.what.peek, isFalse);

      term.deactivate();
    });

    test('7.1 Observing pending coupler alone activates upstream pipeline', () async {
      var isComputedActivated = false;
      final query = WhatController('start');

      final pendingCoupler = WhatCoupler<bool>.late();
      computed.future((via) async {
        isComputedActivated = true;
        return 'Computed:${via(query.what)}';
      }).retained(pending: pendingCoupler);

      expect(isComputedActivated, isFalse);

      // Attach only to pending coupler!
      final pendingTerminal = RawWhatTerminal(pendingCoupler.what, onInvalidated: () {});
      pendingTerminal.activate();

      await Future<void>.delayed(Duration.zero);

      // Upstream MUST have been activated!
      expect(isComputedActivated, isTrue);

      pendingTerminal.deactivate();
    });

    test('8.1 Chained .retained() and managed(...).retained() compatibility', () async {
      final count = WhatController(10);
      final raw = computed((via) => 'Count: ${via(count.what)}');
      final smooth = raw.retained();

      expect(smooth.peek, equals('Count: 10'));

      // Managed retained
      var disposed = false;
      final managedNode = managed(
        create: (_) => 'ManagedResource',
        dispose: (res) => disposed = true,
      ).retained();

      final term = RawWhatTerminal(managedNode, onInvalidated: () {});
      term.activate();

      expect(managedNode.peek, equals('ManagedResource'));

      term.deactivate();
      expect(disposed, isTrue);
    });

    test('9.1 Debug observability reflects retained properties', () async {
      final source = WhatController('val');
      final pendingCoupler = WhatCoupler<bool>.late();
      final smooth = source.what.retained(pending: pendingCoupler)..debugTrace('SmoothNode');

      final snapshot = smooth.debug.snapshot();
      expect(snapshot.name, equals('SmoothNode'));
      expect(snapshot.customProperties['isPending'], isFalse);
      expect(snapshot.customProperties['hasRetainedData'], isTrue);
    });

    // =========================================================================
    // 10. Distinct Invariant & Diamond Consistency on Pending Facet
    // =========================================================================
    test('10.1 Pending facet does NOT increment version when pending state remains unchanged', () async {
      final source = WhatController('Data1');
      final pendingCoupler = WhatCoupler<bool>.late();
      source.what.retained(pending: pendingCoupler);
      final pending = pendingCoupler.what;

      int pendingDownstreamRuns = 0;
      final pendingDownstream = computed((via) {
        pendingDownstreamRuns++;
        return 'Pending: ${via(pending)}';
      });

      final term = RawWhatTerminal(pendingDownstream, onInvalidated: () {});
      term.activate();

      expect(term.data, equals('Pending: false'));
      expect(pendingDownstreamRuns, 1);

      // Mutate source: Data1 -> Data2.
      // Normal synchronous mutation: smooth updates data, pending stays false (false -> false).
      source.data = 'Data2';

      // Pull term:
      expect(term.data, equals('Pending: false'));
      expect(
        pendingDownstreamRuns,
        1,
        reason: 'Pending facet must NOT trigger downstream re-computation if pending remained false',
      );

      term.deactivate();
    });

    test('10.2 Diamond graph observing both retained and pending facet resolves consistently', () async {
      final query = WhatController('A');
      Completer<String>? completer;

      final rawFuture = computed.future((via) {
        via(query.what);
        final c = Completer<String>();
        completer = c;
        return c.future;
      });

      final pendingCoupler = WhatCoupler<bool>.late();
      final smooth = rawFuture.retained(pending: pendingCoupler);
      final pending = pendingCoupler.what;

      int diamondRuns = 0;
      final diamond = computed((via) {
        diamondRuns++;
        final hasData = via.state(smooth).hasData;
        final d = hasData ? via(smooth) : 'NONE';
        final p = via(pending);
        return '$d|$p';
      });

      final term = RawWhatTerminal(diamond, onInvalidated: () {});
      term.activate();

      // Initial state: NONE|false
      expect(term.data, equals('NONE|false'));
      expect(diamondRuns, 1);

      // Complete initial load
      completer!.complete('ValueA');
      await Future<void>.delayed(Duration.zero);

      expect(term.data, equals('ValueA|false'));
      expect(diamondRuns, 2);

      // Trigger background mutation
      query.data = 'B';
      await Future<void>.delayed(Duration.zero);

      // SWR: ValueA retained, pending=true
      expect(term.data, equals('ValueA|true'));
      expect(diamondRuns, 3);

      // Complete background load
      completer!.complete('ValueB');
      await Future<void>.delayed(Duration.zero);

      // Completed: ValueB, pending=false
      expect(term.data, equals('ValueB|false'));
      expect(diamondRuns, 4);

      term.deactivate();
    });

    test('10.3 Pending facet pull suppresses version bump when current pending matches previous state', () {
      final source = WhatController('A');
      final pendingCoupler = WhatCoupler<bool>.late();
      source.what.retained(pending: pendingCoupler);
      final pending = pendingCoupler.what;

      // Initial read
      expect(pending.peek, isFalse);
      final initialVersion = pending.debug.snapshot().version;

      // Force a pull cycle on pending facet directly
      pending.peek;
      expect(
        pending.debug.snapshot().version,
        equals(initialVersion),
        reason: 'Repeated reads must not bump version',
      );
    });
  });
}
