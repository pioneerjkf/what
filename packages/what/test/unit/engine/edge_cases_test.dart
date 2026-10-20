import 'dart:async';
import 'package:test/test.dart';
import 'package:what/effect.dart';
import 'package:what/what.dart';

void main() {
  group('Engine Edge Cases Coverage', () {
    test('Uncaught Error propagates to Zone when target detaches during evaluation', () {
      Object? caughtError;
      runZonedGuarded(() {
        final ctrl = WhatController(0);
        final terminal = RawWhatTerminal<int>(ctrl.what, onInvalidated: () {
          throw StateError('Intentional error in onInvalidate');
        });
        terminal.activate();
        ctrl.set(1); // Will trigger onInvalidate which throws
      }, (e, s) {
        caughtError = e;
      });

      expect(caughtError, isA<StateError>());
    });

    test('Scheduler _onTask clears processing set in finally block even when task throws', () async {
      final ctrl1 = WhatController(0);
      final ctrl2 = WhatController(0);

      Object? caughtError;
      var e2ExecutionCount = 0;
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      final handle1 = ctrl1.what.effect(
        () {
          throw StateError('Effect task error');
        },
        onUncaughtError: (e, s) {
          caughtError = e;
          if (!completer1.isCompleted) completer1.complete();
        },
      ).run();

      final handle2 = ctrl2.what.effect(() {
        e2ExecutionCount++;
        if (!completer2.isCompleted) {
          completer2.complete();
        }
      }).run();

      // Mutate ctrl1 to trigger error in _onTask
      ctrl1.set(1);
      await completer1.future;
      expect(caughtError, isA<StateError>());

      // Next tick: mutate ctrl2. If processing set wasn't cleared in finally,
      // subsequent scheduling in _terminalSet would be dropped or corrupted.
      ctrl2.set(1);
      await completer2.future;
      expect(e2ExecutionCount, 1); // Only 1 execution post-init!

      handle1.deactivate();
      handle2.deactivate();
    });

    test('LpdagReentrancyError is thrown when cyclic relay dependency pushes dirty reentrantly', () {
      final a = WhatCoupler<int>.late();
      final b = WhatCoupler<int>.late();

      // a couples to b first
      a.couple(b.what);

      Object? capturedError;
      final terminal = RawWhatTerminal<int>(
        a.what,
        onInvalidated: () {},
        onUncaughtError: (e, s) {
          capturedError = e;
        },
      );
      terminal.activate();

      // Coupling b back to a while active creates a dynamic cyclic relay loop
      // and triggers a dirty push reentrancy error
      b.couple(a.what);

      expect(capturedError, isA<LpdagReentrancyError>());
    });

    test('Uncaught error in onActivated is handled via _activateOptimistically (line 50)', () {
      Object? capturedError;
      final ctrl = WhatController<int>(
        0,
        onActivated: () {
          throw StateError('onActivated failure');
        },
      );

      final terminal = RawWhatTerminal<int>(
        ctrl.what,
        onInvalidated: () {},
        onUncaughtError: (e, s) {
          capturedError = e;
        },
      );

      // Activating terminal invokes _activateOptimistically -> _activate -> onActivated
      terminal.activate();

      expect(capturedError, isA<StateError>().having((e) => e.message, 'message', 'onActivated failure'));
      terminal.deactivate();
    });

    test('Uncaught error in onDeactivated is handled via _deactivateOptimistically (line 60)', () {
      Object? capturedError;
      final ctrl = WhatController<int>(
        0,
        onDeactivated: () {
          throw StateError('onDeactivated failure');
        },
      );

      final terminal = RawWhatTerminal<int>(
        ctrl.what,
        onInvalidated: () {},
      );

      terminal.activate();

      // Deactivating terminal invokes _deactivateOptimistically on node when terminals become empty,
      // dispatching the uncaught error to Zone / LpdagUncaughtErrorHandler
      runZonedGuarded(() {
        terminal.deactivate();
      }, (e, s) {
        capturedError = e;
      });

      expect(capturedError, isA<StateError>().having((e) => e.message, 'message', 'onDeactivated failure'));
    });

    test('LpdagReentrancyError and LpdagCycleError toString formats diagnostic information', () {
      final reentrancyErr = LpdagReentrancyError('custom reentrancy');
      expect(reentrancyErr.toString(), contains('[Lpdag] Reentrancy Violation: custom reentrancy'));

      final defaultReentrancy = LpdagReentrancyError();
      expect(defaultReentrancy.toString(),
          contains('[Lpdag] Reentrancy Violation: Reentrant call to _pushDirty detected.'));

      final cycleErr = LpdagCycleError('custom cycle');
      expect(cycleErr.toString(), contains('[Lpdag] Cyclic Dependency Violation: custom cycle'));

      final defaultCycle = LpdagCycleError();
      expect(
          defaultCycle.toString(), contains('[Lpdag] Cyclic Dependency Violation: Cyclic evaluation loop detected.'));
    });

    test('RawComputedTerminal.debugForceInvalidate resets state and dirty flags', () {
      final source = WhatController(10);
      final terminal = RawComputedTerminal<int>((via) {
        return via(source.what);
      }, onInvalidated: () {});

      terminal.activate();
      expect(terminal.data, 10);

      // debugForceInvalidate invalidates state and clears cache
      terminal.debugForceInvalidate();
      expect(terminal.data, 10);

      terminal.deactivate();
    });

    test('What.managed creates eager and graceful variant properly', () async {
      var createCount = 0;
      var disposeCount = 0;

      final comp = What.managed<int>(
        create: (via) {
          createCount++;
          return 999;
        },
        dispose: (val) {
          disposeCount++;
        },
        eager: true,
        graceful: Graceful.microtask,
      );

      final terminal = RawWhatTerminal<int>(comp, onInvalidated: () {});
      terminal.activate();

      // Microtask loop allows eager evaluation to take place
      await Future<void>.delayed(Duration.zero);
      expect(createCount, 1);
      expect(untracked(comp), 999);

      terminal.deactivate();
      // Graceful microtask defers disposal
      expect(disposeCount, 0);
      await Future<void>.delayed(Duration.zero);
      expect(disposeCount, 1);
    });

    test('WhatSnapshotStateException formats diagnostic state string', () {
      final ex = WhatSnapshotStateException('Empty', 'Attempted to access error');
      expect(ex.toString(), contains('[What/API] Invalid State Access: Querying state metadata'));
      expect(ex.toString(), contains('Context: Attempted to access error'));
      expect(ex.toString(), contains('incompatible state (Empty)'));
    });

    test('WhatState.equals compares states between reactive nodes', () {
      final a = WhatController(10);
      final b = WhatController(10);
      final c = WhatController(20);

      expect(untracked.state(a.what).equals(untracked.state(b.what)), isTrue);
      expect(untracked.state(a.what).equals(untracked.state(c.what)), isFalse);
      expect(untracked.state(a.what).equals(untracked.state(c.what), (prev, next) => true), isTrue);
    });

    test('What.elements handles error in convert callback and resets cache', () {
      var shouldThrow = false;
      final source = WhatController([1, 2, 3]);

      final converted = source.what.keyed.map<int, String>(
        key: (item) => item,
        convert: (item) {
          if (shouldThrow && item == 4) {
            throw StateError('Conversion error');
          }
          return 'item_$item';
        },
      );

      final terminal = RawWhatTerminal(converted, onInvalidated: () {});
      terminal.activate();

      // Normal conversion
      expect(untracked(converted), ['item_1', 'item_2', 'item_3']);

      // Error during conversion of new item triggers catch block (lines 73-74)
      shouldThrow = true;
      source.set([1, 2, 4]); // 4 will throw because it is not in cache!
      expect(() => untracked(converted), throwsA(isA<WhatSnapshotExtractionException>()));
      expect(untracked.state(converted).hasError, isTrue);
      expect(untracked.state(converted).error, isA<StateError>());

      // Recovery
      shouldThrow = false;
      source.set([1, 5]);
      expect(untracked(converted), ['item_1', 'item_5']);

      terminal.deactivate();
    });

    test('What.elements handles error in removeWhere equality via outer catch', () {
      final k1 = _ThrowingEqualityKey(1);
      final k2 = _ThrowingEqualityKey(2);
      final source = WhatController<List<_ThrowingEqualityKey>>([k1, k2]);

      final mapped = source.what.keyed.map<_ThrowingEqualityKey, String>(
        key: (k) => k,
        convert: (k) => 'val_${k.id}',
      );

      final terminal = RawWhatTerminal(mapped, onInvalidated: () {});
      terminal.activate();

      expect(untracked(mapped), ['val_1', 'val_2']);

      // Setting k1.shouldThrow = true causes k1 == k2 inside activeKeys.contains(k2) to throw
      k1.shouldThrow = true;
      source.set([k1]);
      expect(() => untracked(mapped), throwsA(isA<WhatSnapshotExtractionException>()));
      expect(untracked.state(mapped).hasError, isTrue);
      expect(untracked.state(mapped).error, isA<StateError>());

      terminal.deactivate();
    });

    test('EffectGroup.run().debugForceInvalidate invalidates composite effects', () async {
      final source = WhatController(1);
      var runCount = 0;
      final e1 = Effect.via((via) {
        via(source.what);
        runCount++;
      });
      final group = EffectGroup([e1]).run();
      await Future<void>.delayed(Duration.zero);
      expect(runCount, 1);

      group.debugForceInvalidate();
      expect(group.isActive, isTrue);
      group.deactivate();
    });

    test('Effect.handled catches uncaught error in action via runner', () async {
      Object? caughtError;
      final source = WhatController(1);
      final runner = source.what.effect.handled(
        (handle) {
          throw StateError('Handled unary action failed');
        },
        onUncaughtError: (err, st) {
          caughtError = err;
        },
      ).run();
      source.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(caughtError, isA<StateError>());
      runner.deactivate();
    });

    test('Effect.handledVia honors guard false and catches action error via runner', () async {
      var actionCount = 0;
      Object? caughtError;
      final source = WhatController(1);
      final runner = Effect.handledVia(
        (via, handle) {
          actionCount++;
          if (via(source.what) == 2) {
            throw StateError('Handled via action failed');
          }
        },
        guard: (via) => via(source.what) > 0 && via(source.what) != 999,
        onUncaughtError: (err, st) {
          caughtError = err;
        },
      ).run();
      await Future<void>.delayed(Duration.zero);
      expect(actionCount, 1);

      // Guard false drops action (line 363)
      source.set(999);
      await Future<void>.delayed(Duration.zero);
      expect(actionCount, 1);

      // Error triggers line 371
      source.set(2);
      await Future<void>.delayed(Duration.zero);
      expect(caughtError, isA<StateError>());
      runner.deactivate();
    });

    test('WhatDebugSnapshot handles constant, unary relay and sourceCount', () {
      final constantWhat = What.constant(100);
      final cSnap = WhatDebug(constantWhat).snapshot();
      expect(WhatDebug(constantWhat).sourceCount, 0);
      expect(cSnap.hasData, isTrue);

      final comp = What.computed((via) => 10);
      final distinctRelay = comp.distinct();
      final mSnap = WhatDebug(distinctRelay).snapshot();
      expect(WhatDebug(distinctRelay).sourceCount, 1);
      expect(mSnap.hasData, isFalse);
    });

    test('Node uncaught error containment handles fatal error in terminal handler', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        final comp = _ThrowingLifecycleComputation().what;
        final terminal = RawWhatTerminal(
          comp,
          onInvalidated: () {},
          onUncaughtError: (err, st) {
            throw StateError('Fatal terminal error');
          },
        );
        terminal.activate();
        terminal.deactivate();
      }, (err, st) {
        errors.add(err);
      });

      // 2 errors for activate (original error + fatal handler error)
      // and 1 error for deactivate (since terminal is already detached, directly dispatched)
      expect(errors.length, 3);
    });

    test('debugForceInvalidate propagates through unary and switched delta nodes', () {
      final source = WhatController(1);
      final distinctRelay = source.what.distinct();
      final switched = What.switched((via) => What.constant(via(source.what)));

      final t1 = RawWhatTerminal(distinctRelay, onInvalidated: () {});
      final t2 = RawWhatTerminal(switched, onInvalidated: () {});
      t1.activate();
      t2.activate();

      expect(untracked(distinctRelay), 1);
      expect(untracked(switched), 1);

      t1.debugForceInvalidate();
      t2.debugForceInvalidate();

      t1.deactivate();
      t2.deactivate();
    });

    test('WhatLifecycleAware handles errors thrown in didActivate and didDeactivate', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        final comp = _ThrowingLifecycleComputation().what;
        final terminal = RawWhatTerminal(comp, onInvalidated: () {});
        terminal.activate();
        terminal.deactivate();
      }, (err, st) {
        errors.add(err);
      });

      expect(errors.length, 2);
    });

    test('What.computed.stream respects guard and dormant resolution in delta', () {
      final streamWhat = What.computed.stream<int>(
        (via) => Stream.value(100),
        guard: (via) => WhatGuard.block('Stream is guarded'),
      );

      // Read while dormant (inactive) triggers _isGuarded and delta lines 82-84
      expect(untracked.state(streamWhat).isEmpty, isTrue);
      expect(untracked.state(streamWhat).emptyReason, 'Stream is guarded');

      final terminal = RawWhatTerminal(streamWhat, onInvalidated: () {});
      terminal.activate();

      expect(untracked.state(streamWhat).isEmpty, isTrue);
      terminal.deactivate();
    });

    test('Top-level switched functor creates eager and lazy variants', () {
      final sEager = switched((via) => What.constant(1), eager: true);
      final sLazy = switched((via) => What.constant(2), eager: false);
      final sGuarded = switched((via) => What.constant(3), guard: (via) => WhatGuard.block('switched_guarded'));

      expect(untracked(sEager), 1);
      expect(untracked(sLazy), 2);
      expect(untracked.state(sGuarded).isEmpty, isTrue);
      expect(untracked.state(sGuarded).emptyReason, 'switched_guarded');
    });

    test('Top-level managed functor creates all eager/lazy and graceful variants', () {
      final m1 = managed<int>(create: (_) => 1, dispose: (_) {}, eager: true);
      final m2 = managed<int>(create: (_) => 2, dispose: (_) {}, eager: true, graceful: Graceful.microtask);
      final m3 = managed<int>(create: (_) => 3, dispose: (_) {}, eager: false);
      final m4 = managed<int>(create: (_) => 4, dispose: (_) {}, eager: false, graceful: Graceful.microtask);

      final t1 = RawWhatTerminal(m1, onInvalidated: () {});
      final t2 = RawWhatTerminal(m2, onInvalidated: () {});
      final t3 = RawWhatTerminal(m3, onInvalidated: () {});
      final t4 = RawWhatTerminal(m4, onInvalidated: () {});

      t1.activate();
      t2.activate();
      t3.activate();
      t4.activate();

      expect(untracked(m1), 1);
      expect(untracked(m2), 2);
      expect(untracked(m3), 3);
      expect(untracked(m4), 4);

      t1.deactivate();
      t2.deactivate();
      t3.deactivate();
      t4.deactivate();
    });

    test('Scheduler try/finally chain ensures Graceful and downstream flush even on unhandled error', () async {
      final errors = <Object>[];
      var gracefulExecuted = false;
      var shouldThrow = false;

      await runZonedGuarded(() async {
        final ctrl = WhatController(0);
        // Create an effect that rethrows in onUncaughtError during microtask flush
        final effectHandle = ctrl.what.effect(
          () {
            if (shouldThrow) {
              throw StateError('Intentional crash in effect');
            }
          },
          onUncaughtError: (e, s) {
            throw StateError('Rethrown from handler');
          },
        ).run();

        // Create a managed node with microtask graceful policy
        final managedCtrl = What.managed<int>(
          create: (via) => 100,
          graceful: Graceful.microtask,
          dispose: (val) {
            gracefulExecuted = true;
          },
        );
        final term = RawWhatTerminal(managedCtrl, onInvalidated: () {});
        term.activate();
        final _ = term.data; // Initialize managed resource
        // Deactivating queues a microtask grace handle
        term.deactivate();

        shouldThrow = true;
        // Mutate ctrl to trigger effect execution in the same microtask pass
        ctrl.set(1);

        // Yield to allow microtask to run
        await Future<void>.delayed(Duration.zero);

        effectHandle.deactivate();
      }, (error, stack) {
        errors.add(error);
      });

      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.toString().contains('Rethrown from handler')), isTrue);
      // Graceful stage must have executed via try/finally unwinding!
      expect(gracefulExecuted, isTrue);
    });
  });
}

class _ThrowingEqualityKey {
  final int id;
  bool shouldThrow = false;
  _ThrowingEqualityKey(this.id);

  @override
  bool operator ==(Object other) {
    if (shouldThrow) throw StateError('Equality error in removeWhere');
    return other is _ThrowingEqualityKey && other.id == id;
  }

  @override
  int get hashCode => 1;
}

final class _ThrowingLifecycleComputation extends Computation<int> with WhatLifecycleAware {
  @override
  int compute(WhatVia via) => 42;

  @override
  void didActivate() {
    super.didActivate();
    throw StateError('didActivate failure');
  }

  @override
  void didDeactivate() {
    super.didDeactivate();
    throw StateError('didDeactivate failure');
  }
}
