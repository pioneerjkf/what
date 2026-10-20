// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

final class _TestBinaryComputation extends Computation<int> {
  _TestBinaryComputation(this.a, this.b);

  final What<int> a;
  final What<int> b;

  int computeCallCount = 0;

  @override
  int compute(WhatVia via) {
    computeCallCount++;
    return via(a) + via(b);
  }
}

void main() {
  group('What Core, Controller, Snapshot & Operators Unit Tests', () {
    // =========================================================================
    // 1. WhatSnapshot 3-State Exclusivity, Equality & Sound Null-Safety
    // =========================================================================
    group('1. WhatSnapshot Core & Invariants', () {
      test('1.1 Snapshot 3-State exclusivity and extraction contracts', () {
        final sValid1 = const WhatSnapshot<int>(100);
        final sValid2 = const WhatSnapshot<int>(100);
        final sValid3 = const WhatSnapshot<int>(200);
        final sEmpty = const WhatSnapshot<int>.empty();
        final sError = WhatSnapshot<int>.error('Error');

        expect(sValid1.hasData, isTrue);
        expect(sValid1.data, 100);
        expect(sValid1.dataOrNull, 100);
        expect(sValid1.dataOrElse(() => 999), 100);

        expect(sEmpty.isEmpty, isTrue);
        expect(sEmpty.dataOrNull, isNull);
        expect(sEmpty.dataOrElse(() => 999), 999);
        expect(() => sEmpty.data, throwsA(isA<WhatSnapshotExtractionException>()));

        expect(sError.hasError, isTrue);
        expect(sError.error, 'Error');
        expect(sError.dataOrNull, isNull);
        expect(sError.dataOrElse(() => 999), 999);
        expect(() => sError.data, throwsA(isA<WhatSnapshotExtractionException>()));

        expect(sValid1.equals(sValid2), isTrue);
        expect(sValid1.equals(sValid3), isFalse);
        expect(sValid1.equals(sValid3, (a, b) => a % 100 == b % 100), isTrue);
      });

      test('1.2 Valid Snapshot containing explicit null (Sound Null Safety)', () {
        const snapshot = WhatSnapshot<String?>(null);

        expect(snapshot.hasData, isTrue);
        expect(snapshot.isEmpty, isFalse);
        expect(snapshot.hasError, isFalse);

        expect(snapshot.data, isNull);
        expect(snapshot.dataOrNull, isNull);
        expect(snapshot.dataOrElse(() => 'fallback'), isNull);

        expect(
          () => snapshot.error,
          throwsA(isA<WhatSnapshotStateException>().having((e) => e.state, 'state', 'Valid')),
        );
        expect(
          () => snapshot.stackTrace,
          throwsA(isA<WhatSnapshotStateException>().having((e) => e.state, 'state', 'Valid')),
        );
      });

      test('1.3 Empty Snapshot invariants and fail-fast extraction behavior', () {
        const snapshot = WhatSnapshot<int>.empty();

        expect(snapshot.hasData, isFalse);
        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.hasError, isFalse);

        expect(
          () => snapshot.data,
          throwsA(isA<WhatSnapshotExtractionException>().having((e) => e.state, 'state', 'Empty')),
        );

        expect(snapshot.dataOrNull, isNull);
        expect(snapshot.dataOrElse(() => 42), 42);

        expect(
          () => snapshot.error,
          throwsA(isA<WhatSnapshotStateException>().having((e) => e.state, 'state', 'Empty')),
        );
      });

      test('1.4 Error Snapshot invariants, error payload, and fail-fast extraction', () {
        final customError = StateError('Corrupted Pipeline');
        final customTrace = StackTrace.current;
        final snapshot = WhatSnapshot<double>.error(customError, customTrace);

        expect(snapshot.hasData, isFalse);
        expect(snapshot.isEmpty, isFalse);
        expect(snapshot.hasError, isTrue);

        expect(
          () => snapshot.data,
          throwsA(
            isA<WhatSnapshotExtractionException>()
                .having((e) => e.state, 'state', 'Error')
                .having((e) => e.error, 'error', customError)
                .having((e) => e.stackTrace, 'stackTrace', customTrace),
          ),
        );

        expect(snapshot.dataOrNull, isNull);
        expect(snapshot.dataOrElse(() => 3.14), 3.14);
        expect(snapshot.error, same(customError));
        expect(snapshot.stackTrace, same(customTrace));
      });

      test('1.5 Snapshot Equality matrix across nulls, records, and comparators', () {
        const nullSnap1 = WhatSnapshot<String?>(null);
        const nullSnap2 = WhatSnapshot<String?>(null);
        const nonNullSnap = WhatSnapshot<String?>('test');
        const emptySnap = WhatSnapshot<String?>.empty();
        final errorSnap = WhatSnapshot<String?>.error('Err');

        expect(nullSnap1.equals(nullSnap2), isTrue);
        expect(nullSnap1.equals(nonNullSnap), isFalse);
        expect(nullSnap1.equals(emptySnap), isFalse);
        expect(nullSnap1.equals(errorSnap), isFalse);

        final snapCaseA = const WhatSnapshot<String>('HELLO');
        final snapCaseB = const WhatSnapshot<String>('hello');
        expect(snapCaseA.equals(snapCaseB), isFalse);
        expect(
          snapCaseA.equals(snapCaseB, (a, b) => a.toLowerCase() == b.toLowerCase()),
          isTrue,
        );

        const recordSnap1 = WhatSnapshot<(int, String)>((1, 'A'));
        const recordSnap2 = WhatSnapshot<(int, String)>((1, 'A'));
        const recordSnap3 = WhatSnapshot<(int, String)>((2, 'A'));
        expect(recordSnap1.equals(recordSnap2), isTrue);
        expect(recordSnap1.equals(recordSnap3), isFalse);

        const empty1 = WhatSnapshot<int>.empty();
        const empty2 = WhatSnapshot<int>.empty();
        expect(empty1.equals(empty2), isTrue);

        final trace = StackTrace.current;
        final err1 = WhatSnapshot<int>.error('ErrA', trace);
        final err2 = WhatSnapshot<int>.error('ErrA', trace);
        final err3 = WhatSnapshot<int>.error('ErrB', trace);
        expect(err1.equals(err2), isTrue);
        expect(err1.equals(err3), isFalse);
        expect(err1.equals(empty1), isFalse);
      });
    });

    // =========================================================================
    // 2. Nullable Pipeline & Combinator Soundness
    // =========================================================================
    group('2. Nullable Pipeline & Combinator Soundness', () {
      test('2.1 WhatController with nullable type and computed derivations', () {
        final controller = WhatController<String?>(null);
        final lengthWhat = computed((via) => via(controller.what)?.length);
        final upperWhat = computed((via) => via(controller.what)?.toUpperCase());

        final lenTerminal = RawWhatTerminal(lengthWhat, onInvalidated: () {});
        final upTerminal = RawWhatTerminal(upperWhat, onInvalidated: () {});
        lenTerminal.activate();
        upTerminal.activate();

        expect(lenTerminal.hasData, isTrue);
        expect(lenTerminal.data, isNull);
        expect(upTerminal.hasData, isTrue);
        expect(upTerminal.data, isNull);

        controller.set('flutter');
        expect(lenTerminal.data, 7);
        expect(upTerminal.data, 'FLUTTER');

        controller.set(null);
        expect(lenTerminal.hasData, isTrue);
        expect(lenTerminal.data, isNull);
        expect(upTerminal.hasData, isTrue);
        expect(upTerminal.data, isNull);

        lenTerminal.deactivate();
        upTerminal.deactivate();
      });

      test('2.2 Distinct combinator coalesces consecutive null and non-null transitions', () {
        final controller = WhatController<String?>(null);
        int distinctDirtyCount = 0;

        final distinctWhat = controller.what.distinct();
        final terminal = RawWhatTerminal(distinctWhat, onInvalidated: () {
          distinctDirtyCount++;
        });
        terminal.activate();

        expect(terminal.data, isNull);
        expect(distinctDirtyCount, 0);

        controller.set(null);
        expect(distinctDirtyCount, 0);
        expect(terminal.data, isNull);

        controller.set('alpha');
        expect(distinctDirtyCount, 1);
        expect(terminal.data, 'alpha');

        controller.set('alpha');
        expect(distinctDirtyCount, 1);

        controller.set(null);
        expect(distinctDirtyCount, 2);
        expect(terminal.data, isNull);

        terminal.deactivate();
      });

      test('2.3 Fallback and null recovery with Nullable Flows via computed', () {
        final emptyController = WhatController<String?>.late();
        final fallbackToDefault = computed((via) {
          final s = via.state(emptyController.what).snapshot;
          if (s.isEmpty) return 'DEFAULT_VALUE';
          if (s.hasError) return 'ERROR_RECOVERED';
          return s.data;
        });
        final fallbackToNull = computed<String?>((via) {
          final s = via.state(emptyController.what).snapshot;
          if (s.isEmpty) return null;
          if (s.hasError) throw s.error;
          return s.data;
        });

        final defTerminal = RawWhatTerminal(fallbackToDefault, onInvalidated: () {});
        final nullTerminal = RawWhatTerminal(fallbackToNull, onInvalidated: () {});
        defTerminal.activate();
        nullTerminal.activate();

        expect(defTerminal.data, 'DEFAULT_VALUE');
        expect(nullTerminal.hasData, isTrue);
        expect(nullTerminal.data, isNull);

        emptyController.set(null);
        expect(defTerminal.hasData, isTrue);
        expect(defTerminal.data, isNull);
        expect(nullTerminal.hasData, isTrue);
        expect(nullTerminal.data, isNull);

        emptyController.setError(Exception('Boom'));
        expect(defTerminal.data, 'ERROR_RECOVERED');
        expect(nullTerminal.hasError, isTrue);

        emptyController.empty();
        expect(defTerminal.data, 'DEFAULT_VALUE');
        expect(nullTerminal.hasData, isTrue);
        expect(nullTerminal.data, isNull);

        defTerminal.deactivate();
        nullTerminal.deactivate();
      });
    });

    // =========================================================================
    // 3. WhatController Lifecycle & Callbacks
    // =========================================================================
    group('3. WhatController Lifecycle & Callbacks', () {
      test('3.1 WhatController with onActivated and onDeactivated callbacks', () {
        int activatedCount = 0;
        int deactivatedCount = 0;

        final controller = WhatController<int>(
          10,
          onActivated: () => activatedCount++,
          onDeactivated: () => deactivatedCount++,
        );

        expect(activatedCount, 0);
        expect(deactivatedCount, 0);

        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {});
        expect(activatedCount, 0);

        terminal.activate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 0);

        terminal.deactivate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 1);
      });

      test('3.2 WhatController.late with onActivated and onDeactivated callbacks', () {
        int activatedCount = 0;
        int deactivatedCount = 0;

        final controller = WhatController<int>.late(
          onActivated: () => activatedCount++,
          onDeactivated: () => deactivatedCount++,
        );

        expect(activatedCount, 0);
        expect(deactivatedCount, 0);

        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {});
        expect(activatedCount, 0);

        terminal.activate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 0);

        controller.set(42);
        expect(terminal.data, 42);

        terminal.deactivate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 1);
      });
    });

    // =========================================================================
    // 4. What Operators & Extensions (distinct, select, fallback, map)
    // =========================================================================
    group('4. What Operators & Extensions', () {
      test('4.1 RawWhatTerminal attaches directly to source', () {
        int dirtyCount = 0;
        final controller = WhatController<int>(10);
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          dirtyCount++;
        });

        terminal.activate();
        expect(terminal.snapshot.data, 10);

        controller.set(20);
        expect(dirtyCount, 1);
        expect(terminal.snapshot.data, 20);

        terminal.deactivate();
      });

      test('4.2 distinct suppresses duplicate snapshots', () {
        final controller = WhatController<int>(10);
        int dirtyCount = 0;

        final distinctWhat = controller.what.distinct();
        final terminal = RawWhatTerminal(distinctWhat, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(untracked(distinctWhat), 10);

        controller.set(10);
        expect(dirtyCount, 0);

        controller.set(20);
        expect(dirtyCount, 1);
        expect(untracked(distinctWhat), 20);

        terminal.deactivate();
      });

      test('4.3 computed with distinct projects slice and suppresses duplicate snapshots', () {
        final controller = WhatController<({String name, int age})>((name: 'Alice', age: 20));
        int dirtyCount = 0;

        final nameWhat = computed((via) => via(controller.what).name).distinct();
        final terminal = RawWhatTerminal(nameWhat, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(untracked(nameWhat), 'Alice');

        controller.set((name: 'Alice', age: 21));
        // Under 2-Phase Lazy-Pull: Dirty pulse notifies terminal without eager computation
        expect(dirtyCount, 1);
        final baseVersion = nameWhat.debugVersion;
        expect(terminal.data, 'Alice');
        // When pulled, since the selected slice 'Alice' didn't change, version is NOT incremented!
        expect(nameWhat.debugVersion, equals(baseVersion));

        controller.set((name: 'Bob', age: 21));
        expect(dirtyCount, 2);
        expect(terminal.data, 'Bob');
        expect(nameWhat.debugVersion, greaterThan(baseVersion));

        final ageCategoryWhat = computed((via) => via(controller.what).age).distinct(
          (prev, next) => (prev ~/ 10) == (next ~/ 10),
        );
        int ageCategoryDirty = 0;
        final t2 = RawWhatTerminal(ageCategoryWhat, onInvalidated: () => ageCategoryDirty++);
        t2.activate();

        expect(t2.data, 21);

        controller.set((name: 'Bob', age: 25));
        expect(ageCategoryDirty, 1);
        final baseAgeVersion = ageCategoryWhat.debugVersion;
        expect(t2.data, 21);
        expect(ageCategoryWhat.debugVersion, equals(baseAgeVersion));

        controller.set((name: 'Bob', age: 30));
        expect(ageCategoryDirty, 2);
        expect(t2.data, 30);
        expect(ageCategoryWhat.debugVersion, greaterThan(baseAgeVersion));

        terminal.deactivate();
        t2.deactivate();
      });

      test('4.3.1 equals callback exception in _DistinctEntry safely converges to error state without rethrow', () {
        final controller = WhatController<int>(
          1,
          equals: (prev, next) {
            if (next == 42) throw const FormatException('Forbidden number 42');
            return prev == next;
          },
        );

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 1);
        expect(dirtyCount, 0);

        // Mutating with 42 causes equals to throw.
        // Should NOT rethrow from set(), but should transition controller to error state and notify terminal.
        expect(() => controller.set(42), returnsNormally);
        expect(dirtyCount, 1);
        expect(controller.hasError, isTrue);
        expect(controller.error, isA<FormatException>());
        expect(terminal.hasError, isTrue);
        expect(terminal.error, isA<FormatException>());

        terminal.deactivate();
      });

      test('4.3.2 equals callback exception in _DistinctWhat._pull safely transitions node to error state', () {
        final source = WhatController<int>(1);
        final distinctWhat = source.what.distinct((prev, next) {
          if (next == 99) throw StateError('99 is invalid');
          return prev == next;
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(distinctWhat, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 1);
        expect(dirtyCount, 0);

        source.set(99);
        expect(dirtyCount, 1);

        // Pulling terminal should safely yield error state rather than throwing unhandled exception
        expect(() => terminal.hasError, returnsNormally);
        expect(terminal.hasError, isTrue);
        expect(terminal.error, isA<StateError>());
        expect(untracked.state(distinctWhat).hasError, isTrue);
        expect(untracked.state(distinctWhat).error, isA<StateError>());

        terminal.deactivate();
      });

      test('4.4 computed recovers empty and error states via dataOrElse or snapshot', () {
        final cEmpty = What<String>.empty();
        final cError = What<String>.error('Failure');

        final recoveredEmpty = computed((via) => via.state(cEmpty).dataOrElse(() => 'RecoveredEmpty'));
        final recoveredError = computed((via) {
          final s = via.state(cError).snapshot;
          if (s.hasError) return 'RecoveredError: ${s.error}';
          return s.data;
        });

        final t1 = RawWhatTerminal(recoveredEmpty, onInvalidated: () {});
        final t2 = RawWhatTerminal(recoveredError, onInvalidated: () {});
        t1.activate();
        t2.activate();

        expect(untracked(recoveredEmpty), 'RecoveredEmpty');
        expect(untracked(recoveredError), 'RecoveredError: Failure');

        t1.deactivate();
        t2.deactivate();
      });

      test('4.5 dataOrElse converts empty state to valid null', () {
        final cEmpty = What<String>.empty();
        final nullWhat = computed<String?>((via) => via.state(cEmpty).hasData ? via(cEmpty) : null);

        final t = RawWhatTerminal(nullWhat, onInvalidated: () {});
        t.activate();

        expect(untracked.state(nullWhat).hasData, isTrue);
        expect(untracked(nullWhat), isNull);

        t.deactivate();
      });

      test('4.6 Iterable<WhatState<T>> and Iterable<WhatSnapshot<T>> data accessors', () {
        final list = <What<int>>[What.constant(10), What.constant(20), What.constant(30)];
        final terminals = list.map((c) => RawWhatTerminal(c, onInvalidated: () {})).toList();
        for (final t in terminals) {
          t.activate();
        }

        expect(list.map((w) => untracked.state(w)).data.toList(), [10, 20, 30]);
        for (final t in terminals) {
          t.deactivate();
        }

        final snapshots = <WhatSnapshot<String>>[
          const WhatSnapshot<String>('first'),
          const WhatSnapshot<String>('second'),
        ];
        expect(snapshots.data.toList(), ['first', 'second']);

        final emptySnapshots = <WhatSnapshot<String>>[
          const WhatSnapshot<String>('valid'),
          const WhatSnapshot<String>.empty(),
        ];
        expect(() => emptySnapshots.data.toList(), throwsA(isA<WhatSnapshotExtractionException>()));
        expect(emptySnapshots.dataOrNull.toList(), ['valid', null]);

        final mixedWhats = <What<int>>[
          What.constant(100),
          What<int>.empty(),
        ];
        expect(mixedWhats.map((w) => untracked.state(w)).dataOrNull.toList(), [100, null]);
      });

      test('4.7 What.constant creates a What node list from Iterable<What<T>>', () {
        final list = <What<String>>[What.constant('a'), What.constant('b')];
        final group = What.constant(list);
        expect(group, isA<What<List<What<String>>>>());

        final terminal = RawWhatTerminal(group, onInvalidated: () {});
        terminal.activate();

        expect(untracked(group).map((c) => untracked(c)).toList(), ['a', 'b']);
        terminal.deactivate();
      });
    });

    // =========================================================================
    // 5. Reactive Guards via What.computed
    // =========================================================================
    group('5. Reactive Guards via What.computed Comprehensive Matrix', () {
      test('5.1 Repeated controller mutations while isReady == false with terminal reading snapshot', () {
        final controller = WhatController<int>(0);
        final isReady = WhatController<bool>(false);

        final guarded = computed(
          (via) => via(controller.what),
          guard: (via) => (via(controller.what) >= 0 && via(isReady.what)).guarded(),
        );

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(guarded, onInvalidated: () {
          dirtyCount++;
        });
        terminal.activate();

        expect(terminal.snapshot.isEmpty, isTrue);
        expect(dirtyCount, 0);

        controller.set(10);
        expect(dirtyCount, 1);
        expect(terminal.snapshot.isEmpty, isTrue);

        controller.set(20);
        expect(dirtyCount, 2);
        expect(terminal.snapshot.isEmpty, isTrue);

        controller.set(30);
        expect(dirtyCount, 3);
        expect(terminal.snapshot.isEmpty, isTrue);

        isReady.set(true);
        controller.set(35);
        expect(dirtyCount, 4);
        expect(terminal.data, 35);

        controller.set(40);
        expect(dirtyCount, 5);
        expect(terminal.data, 40);

        terminal.deactivate();
      });

      test('5.2 Dynamic Flapping of isReady Guard Conditions (Blocked <-> Unblocked Cycles)', () {
        final controller = WhatController<int>(0);
        final isReady = WhatController<bool>(true);

        final guarded = computed(
          (via) => via(controller.what),
          guard: (via) => via(isReady.what).guarded(),
        );

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(guarded, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 0);
        expect(dirtyCount, 0);

        // Cycle 1: Blocked
        isReady.set(false);
        expect(dirtyCount, 1);
        expect(terminal.snapshot.isEmpty, isTrue);

        // Cycle 2: Unblocked
        isReady.set(true);
        controller.set(200);
        expect(dirtyCount, 2);
        expect(terminal.data, 200);

        // Cycle 3: Re-Blocked
        isReady.set(false);
        expect(dirtyCount, 3);
        expect(terminal.snapshot.isEmpty, isTrue);

        // Cycle 4: Re-Unblocked
        isReady.set(true);
        controller.set(400);
        expect(dirtyCount, 4);
        expect(terminal.data, 400);

        terminal.deactivate();
      });

      test('5.3 Guard with dynamic reason function reflects latest error reason when blocked', () {
        final controller = WhatController<int>(10);
        final blockReason = WhatController<String?>('Error 401: Unauthorized');

        final guarded = computed(
          (via) => via(controller.what),
          guard: (via) {
            final reason = via(blockReason.what);
            if (reason != null) return WhatGuard.block(reason);
            return WhatGuard.pass;
          },
        );

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(guarded, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.snapshot.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'Error 401: Unauthorized');
        expect(dirtyCount, 0);

        // Block with Reason B
        blockReason.set('Error 403: Forbidden');
        expect(dirtyCount, 1);
        expect(terminal.snapshot.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'Error 403: Forbidden');

        // Unblock
        blockReason.set(null);
        expect(dirtyCount, 2);
        expect(terminal.data, 10);

        controller.set(40);
        expect(dirtyCount, 3);
        expect(terminal.data, 40);

        terminal.deactivate();
      });

      test('5.4 Guarded pipeline feeding downstream computed transformer', () {
        final controller = WhatController<int>(5);
        final isReady = WhatController<bool>(false);
        int mapExecCount = 0;

        final guarded = computed(
          (via) => via(controller.what),
          guard: (via) => via(isReady.what).guarded(),
        );
        final doubled = computed(
          (via) {
            mapExecCount++;
            return via(guarded) * 2;
          },
          guard: (via) => via(isReady.what).guarded(),
        );

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(doubled, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.snapshot.isEmpty, isTrue);
        expect(mapExecCount, 0);

        controller.set(10);
        expect(terminal.snapshot.isEmpty, isTrue);
        expect(mapExecCount, 0);

        isReady.set(true);
        controller.set(16);
        expect(terminal.data, 32);
        expect(mapExecCount, 1);

        terminal.deactivate();
      });

      test('5.5 Asymmetric Fan-Out: Single Controller with 3 Independent Guarded Branches', () {
        final controller = WhatController<int>(100);

        final permAdmin = WhatController<bool>(false);
        final permUser = WhatController<bool>(true);

        final rawBranch = controller;
        int rawDirty = 0;
        final rawTerminal = RawWhatTerminal(rawBranch.what, onInvalidated: () => rawDirty++);

        final adminBranch = computed(
          (via) => via(controller.what),
          guard: (via) => via(permAdmin.what).guarded(),
        );
        int adminDirty = 0;
        final adminTerminal = RawWhatTerminal(adminBranch, onInvalidated: () => adminDirty++);

        final userBranch = computed(
          (via) => via(controller.what),
          guard: (via) => via(permUser.what).guarded(),
        );
        int userDirty = 0;
        final userTerminal = RawWhatTerminal(userBranch, onInvalidated: () => userDirty++);

        rawTerminal.activate();
        adminTerminal.activate();
        userTerminal.activate();

        expect(rawTerminal.data, 100);
        expect(adminTerminal.snapshot.isEmpty, isTrue);
        expect(userTerminal.data, 100);

        controller.set(200);
        expect(rawDirty, 1);
        expect(userDirty, 1);

        expect(rawTerminal.data, 200);
        expect(adminTerminal.snapshot.isEmpty, isTrue);
        expect(userTerminal.data, 200);

        permAdmin.set(true);
        controller.set(300);
        expect(rawDirty, 2);
        expect(adminDirty, 1);
        expect(userDirty, 2);

        expect(rawTerminal.data, 300);
        expect(adminTerminal.data, 300);
        expect(userTerminal.data, 300);

        rawTerminal.deactivate();
        adminTerminal.deactivate();
        userTerminal.deactivate();
      });

      test('5.6 guard throwing an exception is cleanly caught and isolated into Error state', () {
        final controllerA = WhatController<int>(10);
        final controllerB = WhatController<int>(20);

        final computation = _TestBinaryComputation(
          controllerA.what,
          controllerB.what,
        );

        final throwInGuard = WhatController<bool>(true);
        final guardedWhat = computed(
          (via) => via(computation.what),
          guard: (via) {
            if (via(throwInGuard.what)) {
              throw const FormatException('Unexpected guard internal error');
            }
            return WhatGuard.pass;
          },
        );

        final terminal = RawWhatTerminal(guardedWhat, onInvalidated: () {});
        terminal.activate();

        expect(terminal.snapshot.hasError, isTrue);
        expect(terminal.snapshot.error, isA<FormatException>());

        throwInGuard.set(false);
        controllerA.set(15);

        expect(terminal.snapshot.hasData, isTrue);
        expect(terminal.data, 35); // 15 + 20

        terminal.deactivate();
      });
    });
  });
}
