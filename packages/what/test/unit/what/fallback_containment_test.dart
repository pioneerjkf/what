// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('What Native Fallback & Callback Error Containment Suite', () {
    // =========================================================================
    // 1. What.computed Fallback & Exception Containment
    // =========================================================================
    group('1. What.computed Fallback & Error Containment', () {
      test('1.1 computed transforms valid data normally when fallbacks are provided', () {
        final controller = WhatController<int>(5);
        final mapped = computed((via) {
          final s = via.state(controller.what).snapshot;
          if (s.isEmpty) return 'Count: 0';
          if (s.hasError) return 'Count: Error';
          return 'Count: ${s.data}';
        });

        expect(untracked.state(mapped).hasData, isTrue);
        expect(untracked(mapped), equals('Count: 5'));

        controller.set(10);
        expect(untracked(mapped), equals('Count: 10'));
      });

      test('1.2 computed uses onEmpty fallback when upstream is empty', () {
        final controller = WhatController<int>.late();
        final mapped = computed((via) {
          final s = via.state(controller.what).snapshot;
          if (s.isEmpty) return 'Count: Default';
          if (s.hasError) return 'Count: Error';
          return 'Count: ${s.data}';
        });

        expect(untracked.state(mapped).hasData, isTrue);
        expect(untracked(mapped), equals('Count: Default'));

        controller.set(42);
        expect(untracked(mapped), equals('Count: 42'));

        controller.empty();
        expect(untracked(mapped), equals('Count: Default'));
      });

      test('1.3 computed uses onError fallback when upstream has error', () {
        final controller = WhatController<int>.late();
        final mapped = computed((via) {
          final s = via.state(controller.what).snapshot;
          if (s.isEmpty) return 'Count: Default';
          if (s.hasError) return 'Recovered: ${s.error}';
          return 'Count: ${s.data}';
        });

        controller.setError('NetworkFailed');
        expect(untracked.state(mapped).hasData, isTrue);
        expect(untracked(mapped), equals('Recovered: NetworkFailed'));
      });

      test('1.4 computed catches exception thrown inside computation callback and isolates to Error', () {
        final controller = WhatController<int>(0);
        final mapped = computed<int>((via) {
          final c = via(controller.what);
          if (c == 0) throw FormatException('Zero division forbidden');
          return 100 ~/ c;
        });

        // compute threw FormatException -> transitions to error state
        expect(untracked.state(mapped).hasError, isTrue);
        expect(untracked.state(mapped).error, isA<FormatException>());

        // Mutating to valid input clears error
        controller.set(2);
        expect(untracked.state(mapped).hasData, isTrue);
        expect(untracked(mapped), equals(50));
      });

      test('1.5 computed catches exception thrown inside onEmpty and onError branches gracefully', () {
        final controller = WhatController<int>.late();
        final mapped = computed((via) {
          final s = via.state(controller.what).snapshot;
          if (s.isEmpty) throw StateError('Empty fallback failed');
          if (s.hasError) throw StateError('Error fallback failed');
          return 'Count: ${s.data}';
        });

        // onEmpty threw StateError
        expect(untracked.state(mapped).hasError, isTrue);
        expect(untracked.state(mapped).error, isA<StateError>());

        // Trigger error
        controller.setError('OriginalError');
        expect(untracked.state(mapped).hasError, isTrue);
        expect(untracked.state(mapped).error, isA<StateError>());
      });
    });

    // =========================================================================
    // 2. What.computed with distinct Fallback & Error Containment
    // =========================================================================
    group('2. What.computed with distinct Fallback & Deduplication', () {
      test('2.1 computed with distinct projects with deduplication and fallbacks', () {
        final controller = WhatController<({String name, int age})>.late();
        final selected = computed((via) {
          final s = via.state(controller.what).snapshot;
          if (s.isEmpty) return 'Guest';
          if (s.hasError) return 'Recovered: ${s.error}';
          return s.data.name;
        }).distinct();

        expect(untracked.state(selected).hasData, isTrue);
        expect(untracked(selected), equals('Guest'));

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(selected, onInvalidated: () => dirtyCount++);
        terminal.activate();

        controller.set((name: 'Alice', age: 20));
        expect(terminal.data, equals('Alice'));
        expect(dirtyCount, 1);

        // Under 2-Phase LPDAG: dirty push reaches terminal; semantic deduplication is verified upon pull
        controller.set((name: 'Alice', age: 21));
        expect(dirtyCount, 2);
        expect(terminal.data, equals('Alice'));

        // Error -> recovered by onError
        controller.setError('NetworkLost');
        expect(terminal.data, equals('Recovered: NetworkLost'));
        expect(dirtyCount, 3);

        terminal.deactivate();
      });

      test('2.2 computed catches exception in selector and isolates to Error', () {
        final controller = WhatController<int>(0);
        final selected = computed<int>((via) {
          final c = via(controller.what);
          if (c == 0) throw ArgumentError('Zero is forbidden');
          return 10 ~/ c;
        });

        expect(untracked.state(selected).hasError, isTrue);
        expect(untracked.state(selected).error, isA<ArgumentError>());

        controller.set(2);
        expect(untracked.state(selected).hasData, isTrue);
        expect(untracked(selected), equals(5));
      });
    });

    // =========================================================================
    // 3. What.switched Native Fallback & Error Containment
    // =========================================================================
    group('3. What.switched Native Fallback & Error Containment', () {
      test('2.1 switched switches branch with empty and error handling', () {
        final trigger = WhatController<String?>.late();
        final fallbackBranch = What.constant('DefaultBranch');

        final switchedWhat = switched<String>((via) {
          final t = via.state(trigger.what);
          if (t.isEmpty) return fallbackBranch;
          if (t.hasError) return What.constant('ErrorBranch: ${t.error}');
          return What.constant('Active: ${t.data}');
        });

        expect(untracked.state(switchedWhat).hasData, isTrue);
        expect(untracked(switchedWhat), equals('DefaultBranch'));

        trigger.set('User1');
        expect(untracked(switchedWhat), equals('Active: User1'));

        trigger.setError('TriggerFailed');
        expect(untracked(switchedWhat), equals('ErrorBranch: TriggerFailed'));
      });

      test('2.2 switched catches exception in switched builder callback', () {
        final trigger = WhatController<int>(0);

        final switchedWhat = switched<String>((via) {
          final data = via(trigger.what);
          if (data == 0) throw ArgumentError('Invalid branch ID');
          return What.constant('Branch $data');
        });

        expect(untracked.state(switchedWhat).hasError, isTrue);
        expect(untracked.state(switchedWhat).error, isA<ArgumentError>());

        trigger.set(1);
        expect(untracked.state(switchedWhat).hasData, isTrue);
        expect(untracked(switchedWhat), equals('Branch 1'));
      });
    });

    // =========================================================================
    // 3. Future.toWhat & Stream.toWhat Native Fallback & Initial State
    // =========================================================================
    group('3. Future.toWhat & Stream.toWhat Native Fallbacks', () {
      test('3.1 Future.toWhat with initialFactory starts in valid data state', () async {
        final completer = Completer<String>();
        final futureWhat = completer.future.toWhat(initialFactory: () => 'Initial');

        expect(untracked.state(futureWhat).hasData, isTrue);
        expect(untracked(futureWhat), equals('Initial'));

        final terminal = RawWhatTerminal(futureWhat, onInvalidated: () {});
        terminal.activate();

        completer.complete('Resolved');
        await Future<void>.delayed(Duration.zero);

        expect(untracked(futureWhat), equals('Resolved'));
        terminal.deactivate();
      });

      test('3.2 Future.toWhat with onError recovers from future failure', () async {
        final completer = Completer<int>();
        final futureWhat = completer.future.toWhat(
          initialFactory: () => 0,
          onError: (err, [stack]) => -999,
        );

        expect(untracked(futureWhat), equals(0));

        final terminal = RawWhatTerminal(futureWhat, onInvalidated: () {});
        terminal.activate();

        completer.completeError(Exception('API error'));
        await Future<void>.delayed(Duration.zero);

        expect(untracked.state(futureWhat).hasData, isTrue);
        expect(untracked(futureWhat), equals(-999));
        terminal.deactivate();
      });

      test('3.3 Stream.toWhat with initialFactory and onError', () async {
        final streamController = StreamController<int>();
        final streamWhat = streamController.stream.toWhat(
          initialFactory: () => 100,
          onError: (err, [stack]) => -1,
        );

        // Terminal activation to start stream subscription
        final terminal = RawWhatTerminal(streamWhat, onInvalidated: () {});
        terminal.activate();

        expect(untracked(streamWhat), equals(100));

        streamController.add(200);
        await Future<void>.delayed(Duration.zero);
        expect(untracked(streamWhat), equals(200));

        streamController.addError('StreamCrash');
        await Future<void>.delayed(Duration.zero);
        expect(untracked.state(streamWhat).hasData, isTrue);
        expect(untracked(streamWhat), equals(-1));

        terminal.deactivate();
        await streamController.close();
      });
    });

    // =========================================================================
    // 5. WhatController & WhatListController .error Native Constructors
    // =========================================================================
    group('5. WhatController & WhatListController .error', () {
      test('5.1 WhatController.error starts in error state and recovers on set', () {
        final error = FormatException('Initial format error');
        final controller = WhatController<int>.error(error);

        expect(controller.hasError, isTrue);
        expect(controller.hasData, isFalse);
        expect(controller.isEmpty, isFalse);
        expect(controller.error, equals(error));
        expect(() => controller.data, throwsA(isA<WhatSnapshotExtractionException>()));

        // Downstream terminal receives invalidation on recovery
        int dirtyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () => dirtyCount++)..activate();

        controller.set(100);
        expect(controller.hasData, isTrue);
        expect(controller.data, equals(100));
        expect(dirtyCount, 1);

        terminal.deactivate();
      });

      test('5.2 WhatController.error with distinct and lifecycle hooks', () {
        bool activated = false;
        bool deactivated = false;

        final controller = WhatController<String>.error(
          'InitError',
          onActivated: () => activated = true,
          onDeactivated: () => deactivated = true,
        );

        expect(controller.isActive, isFalse);
        expect(controller.hasError, isTrue);

        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {});
        terminal.activate();
        expect(activated, isTrue);
        expect(controller.isActive, isTrue);

        // Deduplication on set
        controller.set('Hello');
        expect(controller.data, equals('Hello'));

        terminal.deactivate();
        expect(deactivated, isTrue);
      });

      test('5.3 WhatListController.error starts in error state and recovers on set', () {
        final controller = WhatListController<What<int>>.error('GroupError');

        expect(controller.snapshot.hasError, isTrue);
        expect(controller.snapshot.hasData, isFalse);
        expect(controller.snapshot.error, equals('GroupError'));
        expect(() => controller.data, throwsA(isA<WhatSnapshotExtractionException>()));

        final what1 = What.constant(1);
        final what2 = What.constant(2);
        controller.set([what1, what2]);

        expect(controller.snapshot.hasData, isTrue);
        expect(controller.data, equals([what1, what2]));
      });
    });

    // =========================================================================
    // =========================================================================
    // 6. WhatCoupler .error Sockets
    // =========================================================================
    group('6. WhatCoupler .error', () {
      test('6.1 WhatCoupler.error starts in error state and recovers on couple', () {
        final coupler = WhatCoupler<String>.error('SocketUnavailable');

        expect(coupler.hasError, isTrue);
        expect(coupler.error, equals('SocketUnavailable'));

        final liveSource = What.constant('LivePayload');
        coupler.couple(liveSource);

        expect(coupler.hasData, isTrue);
        expect(coupler.data, equals('LivePayload'));
      });

      test('6.2 WhatCoupler<List> .error starts in error state and recovers on couple', () {
        final coupler = WhatCoupler<List<What<int>>>.error('BundleError');

        expect(coupler.snapshot.hasError, isTrue);
        expect(coupler.snapshot.error, equals('BundleError'));

        final liveBundle = What.constant([What.constant(10), What.constant(20)]);
        coupler.couple(liveBundle);

        expect(coupler.snapshot.hasData, isTrue);
        expect(untracked(coupler.what).map((g) => untracked(g)).toList(), equals([10, 20]));
      });
    });

    // =========================================================================
    // 7. WhatListController Fallback & Exception Containment
    // =========================================================================
    group('7. WhatListController Fallback & Exception Containment', () {
      test('7.1 WhatListController.late starts empty and recovers with data assignment', () {
        final controller = WhatListController<What<int>>.late();

        expect(controller.snapshot.isEmpty, isTrue);
        expect(controller.snapshot.hasData, isFalse);

        // Recovering with data
        controller.data = [What.constant(1), What.constant(2)];
        expect(controller.snapshot.hasData, isTrue);
        expect(controller.data.map((g) => untracked(g)).toList(), equals([1, 2]));
      });

      test('7.2 WhatListController.setGuarded catches exception and isolates failure to error state', () {
        final controller = WhatListController<What<int>>([What.constant(10)]);

        controller.setGuarded(() {
          throw FormatException('Invalid nodes generation');
        });

        expect(controller.snapshot.hasError, isTrue);
        expect(controller.snapshot.error, isA<FormatException>());
      });

      test('7.3 WhatListController.error initializes in error state and fails fast on data access', () {
        final controller = WhatListController<What<int>>.error(StateError('Group failed'));

        expect(controller.snapshot.hasError, isTrue);
        expect(controller.snapshot.error, isA<StateError>());
        expect(() => controller.data, throwsA(isA<WhatSnapshotExtractionException>()));
      });

      test('7.4 WhatListController.error recovers to valid state on subsequent data assignment', () {
        final controller = WhatListController<What<int>>.error('OriginalError');

        expect(controller.snapshot.hasError, isTrue);

        // Recovery
        controller.data = [What.constant(100)];
        expect(controller.snapshot.hasData, isTrue);
        expect(untracked(controller.data.first), equals(100));
      });
    });

    // =========================================================================
    // 9. WhatListController Dynamic Aggregation & Exception Containment
    // =========================================================================
    group('9. WhatListController Dynamic Aggregation & Exception Containment', () {
      test('9.1 dynamic aggregation collapses data into what normally with fallbacks provided', () {
        final controller = WhatListController<What<int>>([What.constant(10), What.constant(20)]);
        final converged = computed((via) {
          if (via.state(controller.what).hasError) return -1;
          if (via.state(controller.what).isEmpty) return 0;
          return via(controller.what).map((g) => via(g)).reduce((a, b) => a + b);
        });

        expect(untracked.state(converged).hasData, isTrue);
        expect(untracked(converged), equals(30));

        controller.set([What.constant(1), What.constant(2), What.constant(3)]);
        expect(untracked(converged), equals(6));
      });

      test('9.2 dynamic aggregation handles empty upstream what list', () {
        final controller = WhatListController<What<int>>.late();
        final converged = computed((via) {
          if (via.state(controller.what).hasError) return -1;
          if (via.state(controller.what).isEmpty) return 100;
          return via(controller.what).map((g) => via(g)).reduce((a, b) => a + b);
        });

        expect(untracked.state(converged).hasData, isTrue);
        expect(untracked(converged), equals(100));

        controller.set([What.constant(5), What.constant(5)]);
        expect(untracked(converged), equals(10));

        controller.empty();
        expect(untracked(converged), equals(100));
      });

      test('9.3 dynamic aggregation handles error or throwing callback', () {
        final controller = WhatListController<What<int>>.error('GroupExploded');
        final converged = computed((via) {
          if (via.state(controller.what).hasError) return 555;
          return via(controller.what).map((g) => via(g)).reduce((a, b) => a + b);
        });

        expect(untracked.state(converged).hasData, isTrue);
        expect(untracked(converged), equals(555));

        // When callback throws
        final liveController = WhatListController<What<int>>([What.constant(1)]);
        final throwingConverged = computed((via) {
          if (via(liveController.what).isNotEmpty) throw FormatException('Converge parse error');
          return 888;
        });

        expect(untracked.state(throwingConverged).hasError, isTrue);
        expect(untracked.state(throwingConverged).error, isA<FormatException>());
      });

      test('9.4 dynamic aggregation with throwing isolates to error state without crashing', () {
        final controller = WhatListController<What<int>>.late();
        final converged = computed((via) {
          if (via.state(controller.what).isEmpty) throw 'onEmptyThrows';
          return 1;
        });

        expect(untracked.state(converged).hasError, isTrue);
        expect(untracked.state(converged).error, equals('onEmptyThrows'));
      });
    });
  });
}
