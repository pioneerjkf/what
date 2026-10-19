// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:what/effect.dart';
import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('WhatSignal & WhatSignalController Suite', () {
    test('1.1 Basic pulse emission advances version and notifies downstream terminal', () {
      final sig = WhatSignalController();
      expect(sig.what.peek, 0);
      expect(sig.isActive, isFalse);

      var pulses = 0;
      final term = RawWhatTerminal(sig.what, onInvalidated: () => pulses++);
      term.activate();

      expect(sig.isActive, isTrue);
      expect(pulses, 0);

      // Emit 1
      sig.emit();
      expect(pulses, 1);
      expect(sig.what.peek, 1);

      // Emit 2
      sig.emit();
      expect(pulses, 2);
      expect(sig.what.peek, 2);

      term.deactivate();
      expect(sig.isActive, isFalse);
    });

    test('1.2 Signal dynamically drives computed evaluation via WhatVia', () {
      final sig = WhatSignalController();
      var computeRuns = 0;

      final counter = computed((via) {
        computeRuns++;
        final tick = via(sig.what);
        return 'Tick: $tick';
      });

      final term = RawWhatTerminal(counter, onInvalidated: () {});
      term.activate();

      expect(term.data, 'Tick: 0');
      expect(computeRuns, 1);

      // Emit signal pulse
      sig.emit();
      expect(term.data, 'Tick: 1');
      expect(computeRuns, 2);

      // Emit again
      sig.emit();
      expect(term.data, 'Tick: 2');
      expect(computeRuns, 3);

      term.deactivate();
    });

    test('1.3 Signal is IMMUNE to distinct() drop bug because version advances monotonically', () {
      final sig = WhatSignalController();

      // Explicitly attach distinct() to the signal pipeline
      final distinctSignal = sig.what.distinct();

      var pulseCount = 0;
      final term = RawWhatTerminal(distinctSignal, onInvalidated: () => pulseCount++);
      term.activate();

      expect(pulseCount, 0);
      expect(distinctSignal.peek, 0);

      // 1st pulse
      sig.emit();
      expect(pulseCount, 1);
      expect(distinctSignal.peek, 1);

      // 2nd pulse (Must NOT be dropped by distinct()!)
      sig.emit();
      expect(pulseCount, 2, reason: 'Consecutive signal pulses must never be dropped by distinct()');
      expect(distinctSignal.peek, 2);

      // 3rd pulse
      sig.emit();
      expect(pulseCount, 3);
      expect(distinctSignal.peek, 3);

      term.deactivate();
    });

    test('1.4 Lifecycle hooks onActivated and onDeactivated are invoked accurately', () {
      var activatedCount = 0;
      var deactivatedCount = 0;

      final sig = WhatSignalController(
        onActivated: () => activatedCount++,
        onDeactivated: () => deactivatedCount++,
      );

      expect(activatedCount, 0);
      expect(deactivatedCount, 0);

      final term1 = RawWhatTerminal(sig.what, onInvalidated: () {});
      final term2 = RawWhatTerminal(sig.what, onInvalidated: () {});

      // Connect 1st listener
      term1.activate();
      expect(activatedCount, 1);
      expect(deactivatedCount, 0);

      // Connect 2nd listener (already active, no duplicate hook)
      term2.activate();
      expect(activatedCount, 1);
      expect(deactivatedCount, 0);

      // Disconnect 1st listener (1 listener remains, not deactivated)
      term1.deactivate();
      expect(activatedCount, 1);
      expect(deactivatedCount, 0);

      // Disconnect 2nd listener -> drops to 0 active
      term2.deactivate();
      expect(activatedCount, 1);
      expect(deactivatedCount, 1);
    });

    test('1.5 Signal integrates seamlessly with Effect.via runner', () async {
      final sig = WhatSignalController();
      final receivedTicks = <int>[];

      final runner = Effect.via((via) {
        receivedTicks.add(via(sig.what));
      }).run();

      await Future<void>.delayed(Duration.zero);
      expect(receivedTicks, [0]);

      sig.emit();
      await Future<void>.delayed(Duration.zero);
      expect(receivedTicks, [0, 1]);

      sig.emit();
      await Future<void>.delayed(Duration.zero);
      expect(receivedTicks, [0, 1, 2]);

      runner.deactivate();
    });
  });

  group('2. Discrete Signal Invalidation Integration via WhatVia (computed & managed)', () {
    test('2.1 computed with via(sig.what) re-evaluates when signal emits', () {
      final sig = WhatSignalController();
      var computeRuns = 0;

      final countNode = WhatController(10);
      final derived = computed((via) {
        via(sig.what);
        computeRuns++;
        return via(countNode.what) * 2;
      });

      final term = RawWhatTerminal(derived, onInvalidated: () {});
      term.activate();

      expect(term.data, 20);
      expect(computeRuns, 1);

      // Mutating signal triggers re-evaluation even if other dependencies did not change
      sig.emit();
      expect(term.data, 20);
      expect(computeRuns, 2);

      // Emit again
      sig.emit();
      expect(term.data, 20);
      expect(computeRuns, 3);

      term.deactivate();
    });

    test('2.2 computed.future with via(sig.what) refetches when signal emits', () async {
      final sig = WhatSignalController();
      var fetchCount = 0;

      final feed = computed.future((via) async {
        via(sig.what);
        fetchCount++;
        return 'Data #$fetchCount';
      });

      final term = RawWhatTerminal(feed, onInvalidated: () {});
      term.activate();

      await Future<void>.delayed(Duration.zero);
      expect(term.data, 'Data #1');
      expect(fetchCount, 1);

      // Emit refresh signal
      sig.emit();
      await Future<void>.delayed(Duration.zero);
      expect(term.data, 'Data #2');
      expect(fetchCount, 2);

      sig.emit();
      await Future<void>.delayed(Duration.zero);
      expect(term.data, 'Data #3');
      expect(fetchCount, 3);

      term.deactivate();
    });

    test('2.3 computed.stream with via(sig.what) re-creates stream when signal emits', () async {
      final sig = WhatSignalController();
      var streamCount = 0;

      final feed = computed.stream((via) {
        via(sig.what);
        streamCount++;
        return Stream.value('Stream #$streamCount');
      });

      final term = RawWhatTerminal(feed, onInvalidated: () {});
      term.activate();

      await Future<void>.delayed(Duration.zero);
      expect(term.data, 'Stream #1');
      expect(streamCount, 1);

      // Emit signal
      sig.emit();
      await Future<void>.delayed(Duration.zero);
      expect(term.data, 'Stream #2');
      expect(streamCount, 2);

      term.deactivate();
    });

    test('2.4 managed(create: (via) => ...) with via(sig.what) re-creates/disposes resource when signal emits', () {
      final sig = WhatSignalController();
      final createdInstances = <int>[];
      final disposedInstances = <int>[];
      var nextId = 1;

      final resourceWhat = managed<int>(
        create: (via) {
          via(sig.what);
          final id = nextId++;
          createdInstances.add(id);
          return id;
        },
        dispose: (id) {
          disposedInstances.add(id);
        },
      );

      final term = RawWhatTerminal(resourceWhat, onInvalidated: () {});
      term.activate();

      expect(term.data, 1);
      expect(createdInstances, [1]);
      expect(disposedInstances, isEmpty);

      // Emit signal -> triggers re-creation
      sig.emit();
      expect(term.data, 2);
      expect(createdInstances, [1, 2]);
      expect(disposedInstances, [1]);

      // Emit signal again -> triggers re-creation
      sig.emit();
      expect(term.data, 3);
      expect(createdInstances, [1, 2, 3]);
      expect(disposedInstances, [1, 2]);

      term.deactivate();
      expect(disposedInstances, [1, 2, 3]);
    });

    test('2.5 WhatSignalController attaches debugLabel to controller and what independently', () {
      final sig = WhatSignalController().withDebugLabel('RefreshController');
      sig.what.withDebugLabel('RefreshTrigger');

      expect(sig.debugLabel, equals('RefreshController'));
      expect(sig.what.debugLabel, equals('RefreshTrigger'));
      expect(sig.what.debug.debugLabel, equals('RefreshTrigger'));
      expect(sig.what.debugVersion, equals(0));

      sig.debugTrace();
      expect(sig.debugCreationLocation, isNotNull);

      final snapshot = sig.what.debug.snapshot();
      expect(snapshot.debugLabel, equals('RefreshTrigger'));
      expect(snapshot.name, equals('RefreshTrigger'));
      expect(snapshot.data, equals(0));
      expect(snapshot.hasData, isTrue);

      sig.emit();
      expect(sig.what.debugVersion, equals(1));
    });
  });
}
