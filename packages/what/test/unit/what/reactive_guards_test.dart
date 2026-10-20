// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.
import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('Reactive Guards Triad (resource, computed, switched) & Empty(emptyReason) Suite', () {
    // =========================================================================
    // 1. What.resource Guard & Lifecycle Invariants
    // =========================================================================
    group('1. What.resource with guard & reason', () {
      test('1.1 guard == false prevents create() and holds Empty(emptyReason)', () {
        final token = WhatController<String>.late();
        int createCount = 0;
        int disposeCount = 0;

        final clientRes = managed<String>(
          guard: (via) => via.state(token.what).hasData.guarded('AwaitingAuthToken'),
          create: (via) {
            createCount++;
            return 'Client(${via(token.what)})';
          },
          dispose: (_) => disposeCount++,
        );

        final terminal = RawWhatTerminal(clientRes, onInvalidated: () {});
        terminal.activate();

        // 1. Initial State: token is late (empty), so guard is false
        expect(terminal.isEmpty, isTrue);
        expect(terminal.hasData, isFalse);
        expect(terminal.snapshot.emptyReason, 'AwaitingAuthToken');
        expect(createCount, 0);
        expect(disposeCount, 0);

        // 2. Reading snapshot multiple times does not trigger create or recompute
        expect(terminal.snapshot.emptyReason, 'AwaitingAuthToken');
        expect(createCount, 0);

        // 3. Mutate token to valid data: guard becomes true
        token.set('jwt-secret-123');
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 'Client(jwt-secret-123)');
        expect(terminal.snapshot.emptyReason, isNull);
        expect(createCount, 1);
        expect(disposeCount, 0);

        // 4. Mutate token to another value
        token.set('jwt-secret-456');
        expect(terminal.data, 'Client(jwt-secret-456)');
        expect(createCount, 2);
        expect(disposeCount, 1);

        // 5. Deactivate
        terminal.deactivate();
        expect(disposeCount, 2);
      });

      test('1.2 Dynamic condition toggling: Valid -> Empty(emptyReason) triggers dispose()', () {
        final isOnline = WhatController(true);
        int createCount = 0;
        final disposedList = <String>[];

        final socketRes = managed<String>(
          guard: (via) => via(isOnline.what).guarded('NetworkOffline'),
          create: (via) {
            createCount++;
            return 'SocketConnection-$createCount';
          },
          dispose: (s) => disposedList.add(s),
        );

        final terminal = RawWhatTerminal(socketRes, onInvalidated: () {});
        terminal.activate();

        // Initial online
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 'SocketConnection-1');
        expect(createCount, 1);
        expect(disposedList, isEmpty);

        // Go offline: under 2-Phase LPDAG, dirty push is non-destructive;
        // reading terminal pulls new state: guard is false, so resource is cleanly disposed!
        isOnline.data = false;
        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'NetworkOffline');
        expect(disposedList, ['SocketConnection-1']);

        // Go online again: guard is true, resource is reallocated!
        isOnline.data = true;
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 'SocketConnection-2');
        expect(createCount, 2);

        terminal.deactivate();
        expect(disposedList, ['SocketConnection-1', 'SocketConnection-2']);
      });

      test('1.3 update callback with guard & reason', () {
        final server = WhatController('alpha');
        final enabled = WhatController(true);
        int createCount = 0;
        int updateCount = 0;
        final disposed = <String>[];

        final poolRes = managed<String>(
          guard: (via) => via(enabled.what).guarded('PoolDisabled'),
          create: (via) {
            createCount++;
            return 'Pool(${via(server.what)})';
          },
          update: (via, curr) {
            updateCount++;
            return 'Pool(${via(server.what)})';
          },
          dispose: (p) => disposed.add(p),
        );

        final terminal = RawWhatTerminal(poolRes, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 'Pool(alpha)');
        expect(createCount, 1);
        expect(updateCount, 0);

        // Mutate server with enabled == true: update is called.
        // Since 'Pool(beta)' != 'Pool(alpha)', old instance is disposed!
        server.data = 'beta';
        expect(terminal.data, 'Pool(beta)');
        expect(createCount, 1);
        expect(updateCount, 1);
        expect(disposed, ['Pool(alpha)']);

        // Disable: goes into emptyReason, dispose is called on current instance
        enabled.data = false;
        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'PoolDisabled');
        expect(disposed, ['Pool(alpha)', 'Pool(beta)']);

        terminal.deactivate();
      });

      test('1.4 dispose() callback is strictly Untracked (preventing zombie edges and loops)', () {
        final trigger = WhatController(1);
        final counter = WhatController(100);
        int disposeCount = 0;

        final res = managed<int>(
          create: (via) => via(trigger.what) * 10,
          dispose: (val) {
            disposeCount++;
            // Read or mutate another what inside dispose
            final _ = counter.data;
            counter.data = counter.data + 1;
          },
        );

        final terminal = RawWhatTerminal(res, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 10);
        expect(disposeCount, 0);
        expect(counter.data, 100);

        // Mutating trigger marks dirty; pull triggers recreation and calls dispose()
        trigger.data = 2;
        expect(terminal.data, 20);
        expect(disposeCount, 1);
        expect(counter.data, 101);

        // Mutating counter should NOT dirty or trigger res, because dispose was untracked!
        counter.data = 200;
        // terminal should not be marked dirty because of counter
        expect(terminal.data, 20);
        expect(disposeCount, 1); // No redundant disposal

        terminal.deactivate();
        expect(disposeCount, 2);
      });

      test('1.5 Unified Class Architecture: What.managed creates _LazyManagedWhat or _LazyGracefulManagedWhat', () {
        final pure = managed<int>(create: (_) => 42, dispose: (_) {});
        final guarded = managed<int>(create: (_) => 42, dispose: (_) {}, guard: (_) => WhatGuard.pass);
        final pureGraceful = managed<int>(create: (_) => 42, dispose: (_) {}, graceful: const Graceful());
        final guardedGraceful =
            managed<int>(create: (_) => 42, dispose: (_) {}, guard: (_) => WhatGuard.pass, graceful: const Graceful());

        // Standard managed nodes are unified under _LazyManagedWhat
        expect(pure.runtimeType.toString(), contains('_LazyManagedWhat'));
        expect(guarded.runtimeType.toString(), contains('_LazyManagedWhat'));

        // Graceful managed nodes are unified under _LazyGracefulManagedWhat
        expect(pureGraceful.runtimeType.toString(), contains('_LazyGracefulManagedWhat'));
        expect(guardedGraceful.runtimeType.toString(), contains('_LazyGracefulManagedWhat'));
      });

      test('1.6 Error handling during guard, create, and update', () {
        final shouldThrow = WhatController(false);
        final disposed = <String>[];

        final errorRes = managed<String>(
          guard: (via) {
            if (via(shouldThrow.what)) throw StateError('GuardEvaluationFailed');
            return WhatGuard.pass;
          },
          create: (_) => 'ActiveResource',
          dispose: (r) => disposed.add(r),
        );

        final terminal = RawWhatTerminal(errorRes, onInvalidated: () {});
        terminal.activate();

        expect(terminal.hasData, isTrue);
        expect(terminal.data, 'ActiveResource');
        expect(disposed, isEmpty);

        // Trigger error in guard: previously active resource is cleanly disposed!
        shouldThrow.data = true;
        expect(terminal.hasError, isTrue);
        expect(terminal.error, isA<StateError>());
        expect((terminal.error as StateError).message, 'GuardEvaluationFailed');
        expect(disposed, ['ActiveResource']);

        terminal.deactivate();
      });

      test('1.7 Graceful resource deactivation with guard', () async {
        final online = WhatController(true);
        int disposeCount = 0;

        final res = managed<String>(
          guard: (via) => via(online.what).guarded('Offline'),
          create: (_) => 'GracefulClient',
          dispose: (_) => disposeCount++,
          graceful: const Graceful(),
        );

        final terminal = RawWhatTerminal(res, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 'GracefulClient');
        expect(disposeCount, 0);

        // Deactivate terminal (graceful disposal scheduled on microtask)
        terminal.deactivate();
        expect(disposeCount, 0); // Not disposed synchronously

        // Reactivate before microtask fires: resource preserved!
        terminal.activate();
        expect(terminal.data, 'GracefulClient');
        expect(disposeCount, 0);

        // Deactivate and let microtask expire
        terminal.deactivate();
        await Future.delayed(Duration.zero);
        expect(disposeCount, 1);
      });
    });

    // =========================================================================
    // 2. What.computed Guard & Zero-Cost Specialization
    // =========================================================================
    group('2. What.computed with guard & reason', () {
      test('2.1 guard controls pure computation and suspends with emptyReason', () {
        final ready = WhatController(false);
        final count = WhatController(10);
        int computeCallCount = 0;

        final calc = computed(
          (via) {
            computeCallCount++;
            return via(count.what) * 2;
          },
          guard: (via) => via(ready.what).guarded('NotReadyYet'),
        );

        final terminal = RawWhatTerminal(calc, onInvalidated: () {});
        terminal.activate();

        // Initially blocked
        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'NotReadyYet');
        expect(computeCallCount, 0);

        // Mutating count while blocked does NOT trigger compute
        count.data = 20;
        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'NotReadyYet');
        expect(computeCallCount, 0);

        // Set ready = true -> triggers compute
        ready.data = true;
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 40);
        expect(computeCallCount, 1);

        // Mutating count now recomputes
        count.data = 25;
        expect(terminal.data, 50);
        expect(computeCallCount, 2);

        // Toggle ready back to false -> returns to Empty(emptyReason)
        ready.data = false;
        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'NotReadyYet');

        terminal.deactivate();
      });

      test('2.2 Unified Class Architecture: What.computed creates _ComputedWhat', () {
        final pure = computed((via) => 42);
        final guarded = computed((via) => 42, guard: (via) => WhatGuard.pass);

        // Both pure and guarded computed nodes are unified under _ComputedWhat
        expect(pure.runtimeType.toString(), contains('_ComputedWhat'));
        expect(guarded.runtimeType.toString(), contains('_ComputedWhat'));

        final num = WhatController(42);
        final pureComputed = computed((via) => via(num.what) + 1);
        expect(untracked(pureComputed), 43);
        num.data = 100;
        expect(untracked(pureComputed), 101);
      });

      test('2.3 top-level computed() forwarding', () {
        final ready = WhatController(false);
        final name = WhatController('What');

        final comp = computed(
          (via) => 'Hello, ${via(name.what)}',
          guard: (via) => via(ready.what).guarded('WaitingReady'),
        );

        expect(untracked.state(comp).isEmpty, isTrue);
        expect(untracked.state(comp).snapshot.emptyReason, 'WaitingReady');

        ready.data = true;
        expect(untracked.state(comp).hasData, isTrue);
        expect(untracked(comp), 'Hello, What');
      });

      test('2.4 Exception in guard transitions computed into error state', () {
        final shouldFail = WhatController(false);
        final comp = computed(
          (via) => 100,
          guard: (via) {
            if (via(shouldFail.what)) throw FormatException('GuardCheckFailed');
            return WhatGuard.pass;
          },
        );

        final terminal = RawWhatTerminal(comp, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 100);

        shouldFail.data = true;
        expect(terminal.hasError, isTrue);
        expect(terminal.error, isA<FormatException>());
        expect((terminal.error as FormatException).message, 'GuardCheckFailed');

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. What.switched with guard & reason
    // =========================================================================
    group('3. What.switched with guard & reason', () {
      test('3.1 guard controls dynamic switching with emptyReason', () {
        final loggedIn = WhatController(false);
        final mode = WhatController('light');
        final lightTheme = WhatController('Theme-Light');
        final darkTheme = WhatController('Theme-Dark');
        int switchCallCount = 0;

        final currentTheme = switched(
          (via) {
            switchCallCount++;
            return via(mode.what) == 'dark' ? darkTheme.what : lightTheme.what;
          },
          guard: (via) => via(loggedIn.what).guarded('UserLoggedOut'),
        );

        final terminal = RawWhatTerminal(currentTheme, onInvalidated: () {});
        terminal.activate();

        // 1. Logged out: blocked
        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'UserLoggedOut');
        expect(switchCallCount, 0);

        // 2. Log in: executes switched
        loggedIn.data = true;
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 'Theme-Light');
        expect(switchCallCount, 1);

        // 3. Switch mode: dynamic delegate updates
        mode.data = 'dark';
        expect(terminal.data, 'Theme-Dark');
        expect(switchCallCount, 2);

        // 4. Log out: returns to Empty(emptyReason)
        loggedIn.data = false;
        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'UserLoggedOut');

        terminal.deactivate();
      });

      test('3.2 Eager switched respects guard and reason', () {
        final ready = WhatController(false);
        final branchA = WhatController('BranchA');

        final eagerSwitched = switched(
          (_) => branchA.what,
          guard: (via) => via(ready.what).guarded('EagerNotReady'),
          eager: true,
        );

        final terminal = RawWhatTerminal(eagerSwitched, onInvalidated: () {});
        terminal.activate();

        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'EagerNotReady');

        ready.data = true;
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 'BranchA');

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 4. What.guard with reason
    // =========================================================================
    group('4. What.computed with guard and reason', () {
      test('4.1 guard with reason returns Empty(emptyReason) when blocked', () {
        final controller = WhatController<int>(10);
        final isAllowed = WhatController<bool>(true);

        final guarded = computed(
          (via) => via(controller.what),
          guard: (via) => via(isAllowed.what).guarded('InsufficientPermissions'),
        );

        final terminal = RawWhatTerminal(guarded, onInvalidated: () {});
        terminal.activate();

        expect(terminal.hasData, isTrue);
        expect(terminal.data, 10);

        isAllowed.set(false);
        controller.set(20);

        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'InsufficientPermissions');

        isAllowed.set(true);
        controller.set(30);

        expect(terminal.hasData, isTrue);
        expect(terminal.data, 30);

        terminal.deactivate();
      });

      test('4.2 distinct() suppresses consecutive identical emptyReason', () {
        final reason = WhatController('ReasonA');

        final comp = computed(
          (via) => 42,
          guard: (via) {
            final r = via(reason.what);
            return WhatGuard.block(r);
          },
        );
        final distinct = comp.distinct();

        int invalidationCount = 0;
        final terminal = RawWhatTerminal(distinct, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.isEmpty, isTrue);
        expect(terminal.snapshot.emptyReason, 'ReasonA');
        expect(invalidationCount, 0);

        // Mutate reason to different string: invalidation fired!
        reason.data = 'ReasonB';
        expect(invalidationCount, 1);
        expect(terminal.snapshot.emptyReason, 'ReasonB');

        // Mutate reason to identical string: distinct suppresses invalidation!
        reason.data = 'ReasonB';
        expect(invalidationCount, 1);

        terminal.deactivate();
      });

      test('4.3 computed forwards emptyReason and dataOrElse recovers empty state', () {
        final guarded = What<int>.empty('GuardedEmpty');

        // computed with guard forwards empty state and emptyReason without executing mapper
        int computeCount = 0;
        final mapped = computed(
          (via) {
            computeCount++;
            return via(guarded) * 10;
          },
          guard: (via) => via.state(guarded).hasData.guarded(untracked.state(guarded).emptyReason ?? 'PrerequisiteNotMet'),
        );
        expect(untracked.state(mapped).isEmpty, isTrue);
        expect(untracked.state(mapped).snapshot.emptyReason, 'GuardedEmpty');
        expect(computeCount, 0);

        // dataOrElse intercepts empty and recovers with valid value
        final recovered = computed((via) => via.state(guarded).dataOrElse(() => 999));
        expect(untracked.state(recovered).hasData, isTrue);
        expect(untracked(recovered), 999);
      });
    });

    // =========================================================================
    // 5. Dart 3 Pattern Matching & WhatSnapshot Symmetry
    // =========================================================================
    group('5. Dart 3 Pattern Matching on WhatSnapshot & WhatState', () {
      test('5.1 Pattern matching on emptyReason in Dart 3 switch expressions', () {
        String classify(WhatSnapshot<String> s) => switch (s) {
              WhatSnapshot(hasData: true, data: final d) => 'Data: $d',
              WhatSnapshot(isEmpty: true, emptyReason: 'WaitingAuth') => 'AuthRequired',
              WhatSnapshot(isEmpty: true, emptyReason: final r) => 'Empty: $r',
              WhatSnapshot(hasError: true, error: final e) => 'Error: $e',
              _ => 'Unknown',
            };

        expect(classify(const WhatSnapshot('Hello')), 'Data: Hello');
        expect(classify(const WhatSnapshot.empty('WaitingAuth')), 'AuthRequired');
        expect(classify(const WhatSnapshot.empty('CustomReason')), 'Empty: CustomReason');
        expect(classify(const WhatSnapshot.empty()), 'Empty: null');
        expect(classify(const WhatSnapshot.error('Boom')), 'Error: Boom');
      });

      test('5.2 Snapshot equality reflects emptyReason', () {
        const snap1 = WhatSnapshot<int>.empty('ReasonA');
        const snap2 = WhatSnapshot<int>.empty('ReasonA');
        const snap3 = WhatSnapshot<int>.empty('ReasonB');
        const snapEmpty = WhatSnapshot<int>.empty();

        expect(snap1, equals(snap2));
        expect(snap1 == snap3, isFalse);
        expect(snap1 == snapEmpty, isFalse);
      });

      test('5.3 What.empty([emptyReason]) static leaf node carries emptyReason', () {
        final leaf = What<String>.empty('StaticReason');
        expect(untracked.state(leaf).isEmpty, isTrue);
        expect(untracked.state(leaf).snapshot.emptyReason, 'StaticReason');
      });

      test('5.4 Direct .emptyReason getter access across What hierarchy', () {
        final leaf = What.empty('LeafReason');
        expect(untracked.state(leaf).emptyReason, 'LeafReason');

        final writeableLate = WhatController<int>.late();
        expect(writeableLate.emptyReason, isNull);

        final guarded = computed(
          (via) => via(writeableLate.what),
          guard: (via) => WhatGuard.block('GuardReason'),
        );
        expect(untracked.state(guarded).emptyReason, 'GuardReason');

        final whatView = writeableLate.what;
        expect(untracked.state(whatView).emptyReason, isNull);
        expect(() => (whatView as dynamic) as WhatController, throwsA(isA<TypeError>()));
      });

      test('5.5 WhatController and RawWhatController support optional reason on .late and .empty()', () {
        final ctrl = WhatController<String>.late(reason: 'AwaitingLogin');
        expect(ctrl.isEmpty, isTrue);
        expect(ctrl.emptyReason, 'AwaitingLogin');
        expect(untracked.state(ctrl.what).emptyReason, 'AwaitingLogin');

        ctrl.set('Alice');
        expect(ctrl.hasData, isTrue);
        expect(ctrl.emptyReason, isNull);

        ctrl.empty('UserLoggedOut');
        expect(ctrl.isEmpty, isTrue);
        expect(ctrl.emptyReason, 'UserLoggedOut');
        expect(untracked.state(ctrl.what).emptyReason, 'UserLoggedOut');

        // Test RawWhatController as well
        final rawCtrl = RawWhatController<int>.late(reason: 'RawPending');
        expect(rawCtrl.isEmpty, isTrue);
        expect(rawCtrl.emptyReason, 'RawPending');
        expect(untracked.state(rawCtrl.what).emptyReason, 'RawPending');

        rawCtrl.set(42);
        expect(rawCtrl.hasData, isTrue);
        expect(rawCtrl.emptyReason, isNull);

        rawCtrl.empty('RawReset');
        expect(rawCtrl.isEmpty, isTrue);
        expect(rawCtrl.emptyReason, 'RawReset');
        expect(untracked.state(rawCtrl.what).emptyReason, 'RawReset');
      });
    });
  });
}
