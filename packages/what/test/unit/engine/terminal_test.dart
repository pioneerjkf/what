// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('terminal.dart Constructors & Public API Comprehensive Tests', () {
    group('RawWhatTerminal Constructors & Inbound/Intent Properties', () {
      test('1.1 Source reference holds the underlying What node', () {
        final source = What.constant('test_value');
        final terminal = RawWhatTerminal(source, onInvalidated: () {});

        expect(terminal.source, same(source));
      });

      test('1.2 Generic type preservation', () {
        final source = What.constant(123);
        final terminal = RawWhatTerminal(source, onInvalidated: () {});

        terminal.activate();

        expect(terminal.snapshot, isA<WhatSnapshot<int>>());
        expect(terminal.hasData, isTrue);
        expect(terminal.isEmpty, isFalse);
        expect(terminal.hasError, isFalse);
        expect(terminal.data, 123);
        expect(terminal.dataOrNull, 123);
        expect(terminal.dataOrElse(() => 999), 123);

        terminal.deactivate();
      });
    });

    group('What<List> with RawWhatTerminal & Inbound/Intent Properties', () {
      test('What<List> RawWhatTerminal sets default and matches inbound', () {
        final listWhat = What.constant([What.constant('a'), What.constant('b')]);
        final terminal = RawWhatTerminal(listWhat, onInvalidated: () {});

        expect(terminal.source, same(listWhat));
      });

      test('What<List> terminal delegates snapshot properties directly', () {
        final listWhat = What.constant([What.constant(10), What.constant(20)]);
        final terminal = RawWhatTerminal(listWhat, onInvalidated: () {});

        terminal.activate();

        expect(terminal.snapshot, isA<WhatSnapshot<List<What<int>>>>());
        expect(terminal.hasData, isTrue);
        expect(terminal.isEmpty, isFalse);
        expect(terminal.hasError, isFalse);
        expect(terminal.data.map((c) => c.peek).toList(), [10, 20]);
        expect(terminal.dataOrNull?.map((c) => c.peek).toList(), [10, 20]);
        expect(terminal.dataOrElse(() => const []).map((c) => c.peek).toList(), [10, 20]);

        terminal.deactivate();
      });
    });

    group('Terminal Lifecycle Methods & Status Getters (activate, deactivate)', () {
      test('Complete lifecycle state machine and idempotency checks', () {
        final controller = WhatController<int>(1);
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {});

        // Initial state before activation
        expect(terminal.isActive, isFalse);
        expect(terminal.isActive, isFalse);

        // 1. Activate
        terminal.activate();
        expect(terminal.isActive, isTrue);
        expect(terminal.isActive, isTrue);

        // Idempotent activate()
        terminal.activate();
        expect(terminal.isActive, isTrue);

        // 2. Deactivate
        terminal.deactivate();
        expect(terminal.isActive, isFalse);
        expect(terminal.isActive, isFalse);

        // Idempotent deactivate()
        terminal.deactivate();
        expect(terminal.isActive, isFalse);
      });
    });

    group('Zero Spurious Invalidation & Clean Initial Lifecycle Tests', () {
      test('RawWhatTerminal: instantiation and initial activation never fire spurious invalidations', () {
        final controller = WhatController<int>(10);
        var invalidateCount = 0;
        final terminal = RawWhatTerminal<int>(controller.what, onInvalidated: () => invalidateCount++);

        // Inactive state on creation
        expect(invalidateCount, 0);
        expect(terminal.isActive, isFalse);

        // Activation should establish subscriptions without firing invalidations
        terminal.activate();
        expect(invalidateCount, 0);
        expect(terminal.isActive, isTrue);
        expect(terminal.data, 10);

        // Only genuine subsequent mutations should invalidate
        controller.set(20);
        expect(invalidateCount, 1);
        expect(terminal.data, 20);

        terminal.deactivate();
      });

      test('RawWhatTerminal: synchronizes pulledVersion AFTER lazy computed source resolves state', () {
        var computedCount = 0;
        final trigger = WhatController<int>(1);
        final lazySource = computed((via) {
          computedCount++;
          return via(trigger.what) * 10;
        });

        var invalidateCount = 0;
        final terminal = RawWhatTerminal(lazySource, onInvalidated: () => invalidateCount++);

        terminal.activate();
        expect(computedCount, 0);
        expect(invalidateCount, 0);

        // First read: lazySource computes for the first time, advancing its version to 1.
        // terminal._read() MUST synchronize _pulledVersion AFTER source resolves,
        // so that terminal's pulledVersion becomes 1.
        expect(terminal.data, 10);
        expect(computedCount, 1);
        expect(invalidateCount, 0);

        // Subsequence reads without upstream change must not trigger any side-effects
        expect(terminal.data, 10);
        expect(computedCount, 1);

        // Mutating trigger pushes dirty invalidation to terminal
        trigger.data = 2;
        expect(invalidateCount, 1);
        expect(terminal.data, 20);
        expect(computedCount, 2);

        terminal.deactivate();
      });

      test('RawWhatTerminal on WhatListController: instantiation and activation never fire spurious invalidations', () {
        final c1 = WhatController<int>(1);
        final c2 = WhatController<int>(2);
        final group = WhatListController([c1.what, c2.what]);

        var invalidateCount = 0;
        final terminal = RawWhatTerminal(group.what, onInvalidated: () => invalidateCount++);

        expect(invalidateCount, 0);
        terminal.activate();
        expect(invalidateCount, 0);
        expect(terminal.data.length, 2);

        group.set([c1.what]);
        expect(invalidateCount, 1);

        terminal.deactivate();
      });

      test('WhatListController & downstream pipeline: construction does not fire spurious invalidations', () {
        final c1 = WhatController<int>(10);
        final c2 = WhatController<int>(20);
        final groupCtrl = WhatListController([c1.what, c2.what]);

        // Downstream aggregation
        final sumWhat = computed((via) => via(groupCtrl.what).fold<int>(0, (int sum, item) => sum + via(item)));

        var invalidateCount = 0;
        final terminal = RawWhatTerminal(sumWhat, onInvalidated: () => invalidateCount++);

        // Activation must not trigger an immediate flush
        terminal.activate();
        expect(invalidateCount, 0);
        expect(terminal.data, 30);

        // Mutation triggers exactly 1 invalidation
        c1.set(15);
        expect(invalidateCount, 1);
        expect(terminal.data, 35);

        // WhatListController dynamic swap triggers exactly 1 invalidation
        final c3 = WhatController<int>(100);
        groupCtrl.set([c1.what, c2.what, c3.what]);
        expect(invalidateCount, 2);
        expect(terminal.data, 135);

        terminal.deactivate();
      });

      test('WhatController mutated while inactive: subsequent terminal attachment has zero spurious invalidations', () {
        final c = WhatController<int>(1);
        c.set(2); // mutated while inactive

        var invalidateCount = 0;
        final terminal = RawWhatTerminal(c.what, onInvalidated: () => invalidateCount++);

        terminal.activate();
        expect(invalidateCount, 0);
        expect(terminal.data, 2);

        c.set(3);
        expect(invalidateCount, 1);
        expect(terminal.data, 3);

        terminal.deactivate();
      });

      test('Cascading dynamic branching: activation does not fire spurious invalidations', () {
        final triggerCtrl = WhatController<String>('alpha');
        final c1 = WhatController<int>(100);
        final c2 = WhatController<int>(200);

        // 1. Dynamic branching computed node
        final branch = computed((via) {
          return via(triggerCtrl.what) == 'alpha' ? [c1] : [c2];
        });

        var invalidateCount = 0;
        final terminal = RawWhatTerminal(branch, onInvalidated: () => invalidateCount++);

        // Activation must NOT trigger invalidation
        terminal.activate();
        expect(invalidateCount, 0);
        expect(terminal.data.length, 1);
        expect(terminal.data.first.data, 100);

        // Trigger mutation triggers exactly 1 invalidation
        triggerCtrl.set('beta');
        expect(invalidateCount, 1);
        expect(terminal.data.first.data, 200);

        terminal.deactivate();
      });

      test('All terminals support clean reconnection with zero spurious invalidations', () {
        // 1. RawWhatTerminal with mutated source while inactive
        final ctrl = WhatController<int>(1);
        var invalidateCount = 0;
        final term = RawWhatTerminal<int>(ctrl.what, onInvalidated: () => invalidateCount++);
        term.activate();
        term.deactivate();

        // Mutate source while terminal is deactivated
        ctrl.set(2);
        expect(invalidateCount, 0);

        // Re-activating drops the reconnect invalidation (2-Phase Lazy-Pull)
        term.activate();
        expect(invalidateCount, 0);
        expect(term.data, 2);

        // Subsequent mutations fire normally
        ctrl.set(3);
        expect(invalidateCount, 1);
        expect(term.data, 3);
        term.deactivate();

        // 2. RawViaTerminal clean reconnection
        var viaTermInvalidateCount = 0;
        final viaTerm =
            RawViaTerminal<int>((via) => via(ctrl.what) + 10, onInvalidated: () => viaTermInvalidateCount++);
        viaTerm.evaluate(); // registers ctrl.what
        viaTerm.activate();
        viaTerm.deactivate();

        ctrl.set(6);
        viaTerm.activate();
        expect(viaTermInvalidateCount, 0);
        expect(viaTerm.evaluate(), 16);

        ctrl.set(7);
        expect(viaTermInvalidateCount, 1);
        viaTerm.deactivate();

        // 3. RawComputedTerminal clean reconnection
        var computedTermInvalidateCount = 0;
        final computedTerm = RawComputedTerminal<int>(
          (via) => via(ctrl.what) + 100,
          onInvalidated: () => computedTermInvalidateCount++,
        );
        expect(computedTerm.data, 107);
        computedTerm.activate();
        computedTerm.deactivate();

        ctrl.set(8);
        computedTerm.activate();
        expect(computedTermInvalidateCount, 0);
        expect(computedTerm.data, 108);

        ctrl.set(9);
        expect(computedTermInvalidateCount, 1);
        computedTerm.deactivate();
      });
    });

    group('RawTerminal.debugForceInvalidate Tests', () {
      test('debugForceInvalidate invalidates intermediate Relay caches and forces recomputation', () {
        final ctrl = WhatController<int>(5);
        var multiplier = 2;

        // intermediate computed what capturing `multiplier`
        final mapped = computed((via) => via(ctrl.what) * multiplier);
        final terminal = RawWhatTerminal(mapped, onInvalidated: () {});
        terminal.activate();

        // 1. Initial computation
        expect(terminal.data, 10);

        // 2. Simulate hot reload changing the closure behavior without changing controller data
        multiplier = 10;
        // Without debugForceInvalidate, cached _state in `mapped` still returns 10
        expect(terminal.data, 10);

        // 3. Call debugForceInvalidate()
        terminal.debugForceInvalidate();

        // 4. Next read must pull fresh recomputed value (5 * 10 = 50)
        expect(terminal.data, 50);

        terminal.deactivate();
      });

      test('debugForceInvalidate walks multi-level DAG with diamond dependencies correctly', () {
        final root = WhatController<int>(2);
        var addend = 1;

        final branchA = computed((via) => via(root.what) + addend);
        final branchB = computed((via) => via(root.what) * addend);
        final combined = computed((via) => via(branchA) + via(branchB));

        final terminal = RawWhatTerminal(combined, onInvalidated: () {});
        terminal.activate();

        // Initial: (2 + 1) + (2 * 1) = 3 + 2 = 5
        expect(terminal.data, 5);

        // Simulate code patch: addend changed
        addend = 5;
        expect(terminal.data, 5); // Still cached

        terminal.debugForceInvalidate();

        // After force invalidate: (2 + 5) + (2 * 5) = 7 + 10 = 17
        expect(terminal.data, 17);

        terminal.deactivate();
      });

      test('debugForceInvalidate works with RawViaTerminal and dynamic dependencies', () {
        final ctrlA = WhatController<int>(10);
        final ctrlB = WhatController<int>(20);
        var useCtrlB = false;

        final terminal = RawViaTerminal<int>(
          (via) => useCtrlB ? via(ctrlB.what) : via(ctrlA.what),
          onInvalidated: () {},
        );
        terminal.activate();

        expect(terminal.evaluate(), 10);

        // Simulate hot reload logic change
        useCtrlB = true;
        terminal.debugForceInvalidate();

        expect(terminal.evaluate(), 20);

        terminal.deactivate();
      });

      test('debugForceInvalidate propagates to scope-bound effect', () {
        final ctrl = WhatController<int>(10);
        var factor = 2;
        final mapped = computed((via) => via(ctrl.what) * factor);

        final effect = Effect([mapped], () {});

        final parentTerminal = RawViaTerminal<void>(
          (via) {
            via.tether(effect);
          },
          onInvalidated: () {},
        );
        parentTerminal.activate();
        parentTerminal.evaluate();

        expect(mapped.peek, 20);

        // Simulate hot reload logic change
        factor = 3;
        expect(mapped.peek, 20); // Still cached before debugForceInvalidate

        // Force invalidate from parent terminal
        parentTerminal.debugForceInvalidate();

        // Cached state in mapped is invalidated through effect lifecycle anchor!
        expect(mapped.peek, 30);

        parentTerminal.deactivate();
      });
    });

    group('Terminal onUncaughtError Custom Handler & Zone Fallback Tests', () {
      test('onUncaughtError catches exceptions thrown inside onInvalidated callback', () {
        final ctrl = WhatController<int>(1);
        Object? caughtError;
        StackTrace? caughtStackTrace;

        final terminal = RawWhatTerminal(ctrl.what, onInvalidated: () {
          throw StateError('Invalidation failed intentionally');
        }, onUncaughtError: (error, stackTrace) {
          caughtError = error;
          caughtStackTrace = stackTrace;
        });
        terminal.activate();

        // Mutate controller to trigger onInvalidated -> throws -> caught by onUncaughtError
        ctrl.set(2);

        expect(caughtError, isA<StateError>());
        expect((caughtError as StateError).message, 'Invalidation failed intentionally');
        expect(caughtStackTrace, isNotNull);

        terminal.deactivate();
      });

      test('onUncaughtError in RawWhatTerminal', () {
        final ctrl = WhatController<int>(1);
        final caughtList = <String>[];

        final whatTerminal = RawWhatTerminal(
          ctrl.what,
          onInvalidated: () => throw StateError('RawWhatTerminal invalidation error'),
          onUncaughtError: (e, s) => caughtList.add('what:${(e as StateError).message}'),
        )..activate();

        ctrl.set(2);

        expect(caughtList, contains('what:RawWhatTerminal invalidation error'));
        whatTerminal.deactivate();
      });

      test('onUncaughtError in RawViaTerminal', () {
        final ctrl = WhatController<int>(10);
        final caughtList = <String>[];

        final viaTerminal = RawViaTerminal(
          (via) => via(ctrl.what),
          onInvalidated: () => throw StateError('RawViaTerminal invalidation error'),
          onUncaughtError: (e, s) => caughtList.add('via:${(e as StateError).message}'),
        )..activate();
        viaTerminal.evaluate();

        // Trigger invalidations
        ctrl.set(20);

        expect(caughtList, contains('via:RawViaTerminal invalidation error'));

        viaTerminal.deactivate();
      });

      test('onUncaughtError in RawComputedTerminal', () {
        final ctrl = WhatController<int>(10);
        final caughtList = <String>[];

        final computedTerminal = RawComputedTerminal<int>(
          (via) => via(ctrl.what) * 2,
          onInvalidated: () => throw StateError('RawComputedTerminal invalidation error'),
          onUncaughtError: (e, s) => caughtList.add('computed:${(e as StateError).message}'),
        )..activate();
        expect(computedTerminal.data, 20);

        // Trigger invalidations
        ctrl.set(20);

        expect(caughtList, contains('computed:RawComputedTerminal invalidation error'));

        computedTerminal.deactivate();
      });

      test('When onUncaughtError throws, both original error and handler error fallback to Zone', () {
        final ctrl = WhatController<int>(1);
        final zoneErrors = <Object>[];

        runZonedGuarded(() {
          final terminal = RawWhatTerminal(
            ctrl.what,
            onInvalidated: () => throw StateError('Original Invalidation Error'),
            onUncaughtError: (error, stackTrace) {
              throw StateError('Secondary Handler Failure');
            },
          );
          terminal.activate();

          ctrl.set(2);
          terminal.deactivate();
        }, (error, stackTrace) {
          zoneErrors.add(error);
        });

        expect(zoneErrors.length, 2);
        expect(zoneErrors[0].toString(), contains('Original Invalidation Error'));
        expect(zoneErrors[1].toString(), contains('Secondary Handler Failure'));
      });
    });

    group('Zero-Copy Synchronous Gateway & Direct Source Access (P1)', () {
      test('Direct source read does NOT permanently mute subsequent invalidations', () {
        final source = WhatController(1);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(source.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.data, 1);
        expect(invalidationCount, 0);

        // First mutation
        source.data = 2;
        expect(invalidationCount, 1);

        // Direct read of source.hasData / source.data bypassing terminal.data
        expect(source.hasData, isTrue);
        expect(source.data, 2);

        // Second mutation: MUST NOT be muted despite terminal.data not being pulled directly
        source.data = 3;
        expect(invalidationCount, 2, reason: 'Terminal invalidation must not be muted by direct source access');
        expect(terminal.data, 3);

        terminal.deactivate();
      });

      test('Bursty mutations coalesce into single notification within what.batch', () {
        final source = WhatController(0, distinct: false);
        int invalidationCount = 0;
        final terminal = RawWhatTerminal(source.what, onInvalidated: () => invalidationCount++);
        terminal.activate();

        // Rapid burst within batch transaction
        batch(() {
          for (int i = 1; i <= 10; i++) {
            source.data = i;
          }
        });
        expect(invalidationCount, 1, reason: 'Bursty mutations within batch transaction coalesced to 1');

        // Next mutation outside batch fires again
        source.data = 99;
        expect(invalidationCount, 2, reason: 'Subsequent mutation outside batch notifies cleanly');
        expect(terminal.data, 99);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // RawWhatTerminal.swapSource() Dynamic Pipeline Sockets
    // =========================================================================
    group('RawWhatTerminal.swapSource() Dynamic Source Sockets', () {
      test('Active swap seamlessly transfers subscription and switches notification pipeline', () {
        final ctrlA = WhatController<String>('sourceA');
        final ctrlB = WhatController<String>('sourceB');

        int invalidations = 0;
        final terminal = RawWhatTerminal<String>(ctrlA.what, onInvalidated: () {
          invalidations++;
        });

        // 1. Initial active connection to ctrlA
        terminal.activate();
        expect(ctrlA.what.debug.targetCount, 1);
        expect(ctrlB.what.debug.targetCount, 0);
        expect(ctrlA.isActive, isTrue);
        expect(ctrlB.isActive, isFalse);
        expect(terminal.data, 'sourceA');

        // Mutating ctrlA triggers invalidation
        ctrlA.data = 'sourceA_v2';
        expect(invalidations, 1);
        expect(terminal.data, 'sourceA_v2');

        // 2. Dynamic swap while active to ctrlB
        terminal.swapSource(ctrlB.what);

        // ctrlA edge detached and dormant; ctrlB edge attached and active
        expect(ctrlA.what.debug.targetCount, 0);
        expect(ctrlB.what.debug.targetCount, 1);
        expect(ctrlA.isActive, isFalse);
        expect(ctrlB.isActive, isTrue);
        expect(terminal.data, 'sourceB');

        // Mutating old source ctrlA has ZERO effect on terminal
        ctrlA.data = 'sourceA_v3';
        expect(invalidations, 1); // Not incremented!

        // Mutating new source ctrlB dispatches invalidation
        ctrlB.data = 'sourceB_v2';
        expect(invalidations, 2);
        expect(terminal.data, 'sourceB_v2');

        terminal.deactivate();
        expect(ctrlB.what.debug.targetCount, 0);
        expect(ctrlB.isActive, isFalse);
      });

      test('Inactive swap updates source reference and correctly connects upon activation', () {
        final ctrlA = WhatController<int>(1);
        final ctrlB = WhatController<int>(2);

        int invalidations = 0;
        final terminal = RawWhatTerminal<int>(ctrlA.what, onInvalidated: () {
          invalidations++;
        });

        // Terminal is inactive: no edges attached
        expect(ctrlA.what.debug.targetCount, 0);
        expect(ctrlB.what.debug.targetCount, 0);

        // Swap while inactive
        terminal.swapSource(ctrlB.what);
        expect(terminal.source, same(ctrlB.what));
        expect(ctrlA.what.debug.targetCount, 0);
        expect(ctrlB.what.debug.targetCount, 0);

        // Activate: should attach exclusively to ctrlB
        terminal.activate();
        expect(ctrlA.what.debug.targetCount, 0);
        expect(ctrlB.what.debug.targetCount, 1);
        expect(terminal.data, 2);

        ctrlB.data = 20;
        expect(invalidations, 1);
        expect(terminal.data, 20);

        terminal.deactivate();
      });

      test('swapSource with identical instance is a clean no-op', () {
        final ctrl = WhatController<int>(10);
        final terminal = RawWhatTerminal<int>(ctrl.what, onInvalidated: () {})..activate();

        expect(ctrl.what.debug.targetCount, 1);
        terminal.swapSource(ctrl.what); // Same instance
        expect(ctrl.what.debug.targetCount, 1);
        expect(terminal.data, 10);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // RawComputedTerminal (1-Hop Leaf Computed Node with WhatStateMixin)
    // =========================================================================
    group('RawComputedTerminal Comprehensive Tests', () {
      test('data & snapshot reads lazily resolve value without evaluate() method', () {
        final ctrlA = WhatController<int>(10);
        final ctrlB = WhatController<int>(20);
        int computeCount = 0;
        int invalidations = 0;

        final terminal = RawComputedTerminal<int>(
          (via) {
            computeCount++;
            return via(ctrlA.what) + via(ctrlB.what);
          },
          onInvalidated: () => invalidations++,
        )..activate();

        // 1. Initial state before any read
        expect(computeCount, 0);

        // 2. First read resolves on-demand
        expect(terminal.data, 30);
        expect(computeCount, 1);
        expect(terminal.snapshot.data, 30);
        expect(terminal.hasData, isTrue);

        // 3. Uninvalidated reads return cached result (0-Compute)
        expect(terminal.data, 30);
        expect(terminal.data, 30);
        expect(terminal.snapshot.data, 30);
        expect(computeCount, 1, reason: 'Zero-compute caching when clean');

        // 4. Source update triggers 1-hop push-dirty directly to terminal
        ctrlA.data = 15;
        expect(invalidations, 1);
        expect(computeCount, 1, reason: 'Push-dirty phase does NOT compute');

        // 5. Subsequent read lazily pulls updated value
        expect(terminal.data, 35);
        expect(computeCount, 2);

        // 6. Again clean: returns cached
        expect(terminal.data, 35);
        expect(computeCount, 2);

        terminal.deactivate();
      });

      test('dynamic dependency switching & epoch sweep', () {
        final cond = WhatController<bool>(true);
        final a = WhatController<int>(1);
        final b = WhatController<int>(100);

        final terminal = RawComputedTerminal<int>(
          (via) => via(cond.what) ? via(a.what) : via(b.what),
          onInvalidated: () {},
        )..activate();

        expect(terminal.data, 1);
        expect(a.what.debug.targetCount, 1);
        expect(b.what.debug.targetCount, 0);

        // Switch branch
        cond.data = false;
        expect(terminal.data, 100);
        expect(a.what.debug.targetCount, 0, reason: 'Swept inactive edge');
        expect(b.what.debug.targetCount, 1);

        terminal.deactivate();
      });

      test('guard and reason support', () {
        final count = WhatController<int>(0);
        final terminal = RawComputedTerminal<int>(
          (via) => via(count.what) * 2,
          guard: (via) => (via(count.what) > 0).guarded('Count must be positive'),
          onInvalidated: () {},
        )..activate();

        expect(terminal.isEmpty, isTrue);
        expect(terminal.emptyReason, 'Count must be positive');
        expect(terminal.hasData, isFalse);

        count.data = 5;
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 10);

        terminal.deactivate();
      });

      test('error containment and exception propagation', () {
        final trigger = WhatController<bool>(false);
        final terminal = RawComputedTerminal<int>(
          (via) {
            if (via(trigger.what)) {
              throw FormatException('Malformed state');
            }
            return 42;
          },
          onInvalidated: () {},
        )..activate();

        expect(terminal.data, 42);
        expect(terminal.hasError, isFalse);

        trigger.data = true;
        expect(terminal.hasError, isTrue);
        expect(terminal.error, isA<FormatException>());
        expect(() => terminal.data, throwsA(isA<WhatSnapshotExtractionException>()));
        expect(terminal.snapshot.hasError, isTrue);

        terminal.deactivate();
      });

      test('markDirty forces re-resolution on next read', () {
        int computeCount = 0;
        final terminal = RawComputedTerminal<int>(
          (via) => ++computeCount,
          onInvalidated: () {},
        )..activate();

        expect(terminal.data, 1);
        expect(terminal.data, 1);

        terminal.markDirty();
        expect(terminal.data, 2);

        terminal.markDirty();
        expect(terminal.data, 3);

        terminal.deactivate();
      });
    });

    // =========================================================================

    group('RawViaTerminal Dynamic Invariants & 1-Pass Epoch Sweep', () {
      test('dynamic branching and 1-pass epoch sweep detach inactive branch edges', () {
        final condition = WhatController<bool>(true);
        final branchA = WhatController<String>('A');
        final branchB = WhatController<String>('B');
        int invalidationCount = 0;

        final terminal = RawViaTerminal<String>(
          (via) => via(condition.what) ? via(branchA.what) : via(branchB.what),
          onInvalidated: () {
            invalidationCount++;
          },
        )..activate();

        expect(terminal.evaluate(), 'A');
        expect(branchA.what.debug.targetCount, 1);
        expect(branchB.what.debug.targetCount, 0);

        // Switch to branchB
        condition.data = false;
        expect(invalidationCount, 1);
        expect(terminal.evaluate(), 'B');

        // branchA must be swept and detached; branchB attached
        expect(branchA.what.debug.targetCount, 0);
        expect(branchB.what.debug.targetCount, 1);

        // Mutating detached branchA produces 0 invalidations
        branchA.data = 'A_modified';
        expect(invalidationCount, 1); // unchanged!

        // Mutating active branchB triggers invalidation
        branchB.data = 'B_modified';
        expect(invalidationCount, 2);
        expect(terminal.evaluate(), 'B_modified');

        terminal.deactivate();
      });

      test('LpdagCycleError is thrown and cycle guard resets on cyclic evaluation', () {
        late final RawViaTerminal<int> terminal;
        terminal = RawViaTerminal<int>(
          (via) => terminal.evaluate(),
          onInvalidated: () {},
        );

        expect(() => terminal.evaluate(), throwsA(isA<LpdagCycleError>()));
      });
    });
  });
}
