// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Comprehensive LPDAG Version Synchronization Invariant Suite', () {
    // =========================================================================
    // Group 1: 1:1 Terminals (RawWhatTerminal)
    // =========================================================================
    group('1. 1:1 Terminals (RawWhatTerminal)', () {
      test('1.1 RawWhatTerminal: Post-_read() edge version matches lazy computed version', () {
        var computedCount = 0;
        final upstream = WhatController(10);
        final lazySource = computed((via) {
          computedCount++;
          return via(upstream.what) * 2;
        });

        var invalidationCount = 0;
        final terminal = RawWhatTerminal(lazySource, onInvalidated: () => invalidationCount++);

        terminal.activate();
        expect(computedCount, 0, reason: 'Lazy computed must be uncalculated before read');
        expect(invalidationCount, 0);

        // First read triggers _read():
        // lazySource._pull() runs -> lazySource._version advances to 1.
        // terminal._read() must pull version AFTER source resolves.
        expect(terminal.data, 20);
        expect(computedCount, 1);
        expect(invalidationCount, 0);

        // Subsequent read on unchanged graph must return clean value without re-computation
        expect(terminal.data, 20);
        expect(computedCount, 1);
        expect(invalidationCount, 0);

        // Genuine upstream mutation must trigger invalidation exactly once
        upstream.data = 15;
        expect(invalidationCount, 1);
        expect(terminal.data, 30);
        expect(computedCount, 2);

        terminal.deactivate();
      });

      test('1.3 RawWhatTerminal: Dormant deactivation, upstream mutation, and re-activation version sync', () {
        final root = WhatController(100);
        var compCount = 0;
        final lazy = computed((via) {
          compCount++;
          return via(root.what) + 1;
        });

        var invalidationCount = 0;
        final terminal = RawWhatTerminal(lazy, onInvalidated: () => invalidationCount++);
        terminal.activate();

        expect(terminal.data, 101);
        expect(compCount, 1);

        // Deactivate: enters zero-leak dormancy
        terminal.deactivate();

        // Mutate upstream while dormant
        root.data = 200;
        expect(invalidationCount, 0, reason: 'Dormant terminal must not receive invalidation');
        expect(compCount, 1, reason: 'No lazy computation while dormant');

        // Re-activate: terminal synchronizes version lazily
        terminal.activate();
        expect(compCount, 1, reason: 'Lazy pull occurs on demand, not upon activate');

        // Reading terminal resolves fresh state and synchronizes version
        expect(terminal.data, 201);
        expect(compCount, 2);

        // Subsequent reads remain cached
        expect(terminal.data, 201);
        expect(compCount, 2);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // Group 2: Dynamic N-ary Terminals & Effects (RawViaTerminal, Effect.*)
    // =========================================================================
    group('2. Dynamic N-ary Terminals & Effects', () {
      test('2.1 RawViaTerminal: Sequential lazy dependencies all advance to current version in _endEpoch', () {
        final ctrl1 = WhatController(1);
        final ctrl2 = WhatController(2);

        final lazy1 = computed((via) => via(ctrl1.what) + 10);
        final lazy2 = computed((via) => via(ctrl2.what) + 20);

        var invalidationCount = 0;
        final terminal = RawViaTerminal(
          (via) => via(lazy1) + via(lazy2),
          onInvalidated: () => invalidationCount++,
        );

        terminal.activate();
        final result = terminal.evaluate();
        expect(result, 33); // 11 + 22
        expect(invalidationCount, 0);

        // Inactive graph checks
        ctrl1.data = 5;
        expect(invalidationCount, 1);
        expect(terminal.evaluate(), 37); // 15 + 22

        ctrl2.data = 8;
        expect(invalidationCount, 2);
        expect(terminal.evaluate(), 43); // 15 + 28

        terminal.deactivate();
      });

      test('2.2 RawViaTerminal: Dynamic branch sweep updates pulledVersion for newly tracked branch only', () {
        final selector = WhatController(true);
        final rootA = WhatController('A');
        final rootB = WhatController('B');

        var aRuns = 0;
        final lazyA = computed((via) {
          aRuns++;
          return 'Val-${via(rootA.what)}';
        });

        var bRuns = 0;
        final lazyB = computed((via) {
          bRuns++;
          return 'Val-${via(rootB.what)}';
        });

        var invalidations = 0;
        final terminal = RawViaTerminal(
          (via) => via(selector.what) ? via(lazyA) : via(lazyB),
          onInvalidated: () => invalidations++,
        );

        terminal.activate();
        expect(terminal.evaluate(), 'Val-A');
        expect(aRuns, 1);
        expect(bRuns, 0);

        // Switch branch to lazyB: lazyA is swept out in 1-pass epoch sweep
        selector.data = false;
        expect(invalidations, 1);

        expect(terminal.evaluate(), 'Val-B');
        expect(aRuns, 1);
        expect(bRuns, 1);

        // Mutating swept-out branch rootA must NOT invalidate terminal
        rootA.data = 'A2';
        expect(invalidations, 1, reason: 'Swept branch rootA must not trigger invalidation');

        // Mutating active branch rootB MUST invalidate terminal
        rootB.data = 'B2';
        expect(invalidations, 2);
        expect(terminal.evaluate(), 'Val-B2');
        expect(bRuns, 2);

        terminal.deactivate();
      });

      test('2.3 RawViaTerminal: Exception in evaluator skips _pullVersion and preserves edges across retry', () {
        final trigger = WhatController(1);
        var shouldThrow = true;

        var invalidationCount = 0;
        final terminal = RawViaTerminal(
          (via) {
            final val = via(trigger.what);
            if (shouldThrow) {
              throw StateError('Transient evaluation failure');
            }
            return val * 10;
          },
          onInvalidated: () => invalidationCount++,
        );

        terminal.activate();

        // Initial evaluation throws: succeeded = false, edges preserved, no version sync
        expect(() => terminal.evaluate(), throwsStateError);
        expect(invalidationCount, 0);

        // Recover condition and mutate trigger
        shouldThrow = false;
        trigger.data = 2;
        expect(invalidationCount, 1, reason: 'Preserved edge must deliver invalidation pulse');

        // Next evaluation succeeds
        expect(terminal.evaluate(), 20);

        terminal.deactivate();
      });

      test('2.4 Effect.via: Distinct short-circuit strictly suppresses execution when upstream version unchanged',
          () async {
        final user = WhatController((name: 'Alice', age: 20));
        var distinctRuns = 0;
        final distinctName = computed((via) {
          distinctRuns++;
          return via(user.what).name;
        }).distinct();

        var effectRuns = 0;
        final effect = Effect.via((via) {
          effectRuns++;
          via(distinctName);
        });

        final host = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {});
        host.activate();
        host.evaluate();
        await Future<void>.delayed(Duration.zero);

        expect(effectRuns, 1);
        expect(distinctRuns, 1);

        // Age changes, name remains identical
        user.data = (name: 'Alice', age: 25);
        await Future.microtask(() {});

        // Distinct re-evaluates but drops version increment -> Effect MUST NOT run
        expect(distinctRuns, 2);
        expect(effectRuns, 1, reason: 'Effect must drop execution because distinct version did not increment');

        // Name changes -> Effect MUST run
        user.data = (name: 'Bob', age: 25);
        await Future.microtask(() {});

        expect(distinctRuns, 3);
        expect(effectRuns, 2);

        host.deactivate();
      });

      test('2.5 Effect.unary: Manifest effect skips initial execution and executes on mutation', () async {
        final root = WhatController(10);
        var compRuns = 0;
        final lazySource = computed((via) {
          compRuns++;
          return via(root.what) * 2;
        });

        // Prime lazySource to establish active edge from root to lazySource
        expect(untracked(lazySource), 20);
        expect(compRuns, 1);

        var effectRuns = 0;
        var capturedValue = 0;
        final effect = Effect.unary(lazySource, () {
          effectRuns++;
          capturedValue = untracked(lazySource);
        });

        final host = RawViaTerminal((via) => via.tether(effect), onInvalidated: () {});
        host.activate();
        host.evaluate();
        await Future<void>.delayed(Duration.zero);

        // Manifest effect skips initial execution
        expect(effectRuns, 0);
        expect(compRuns, 1);

        // Mutate root: Effect scheduled, resolves dirty upstream, advances pulledVersion
        root.data = 20;
        await Future.microtask(() {});

        expect(effectRuns, 1);
        expect(capturedValue, 40);
        expect(compRuns, 2);

        host.deactivate();
      });
    });

    // =========================================================================
    // Group 3: Dynamic Coupling Relays (WhatCoupler & What.switched)
    // =========================================================================
    group('3. Dynamic Coupling Relays (WhatCoupler & What.switched)', () {
      test('3.1 WhatCoupler: Synchronizes version when coupled to lazy computed and bumps its own version', () {
        final coupler = WhatCoupler<int>.late();
        final root = WhatController(5);
        var computeCount = 0;
        final lazyTarget = computed((via) {
          computeCount++;
          return via(root.what) * 10;
        });

        // Downstream observer of coupler
        var downstreamRuns = 0;
        final downstream = computed((via) {
          downstreamRuns++;
          return via(coupler.what) + 1;
        });

        // Couple to uncomputed lazy node
        coupler.couple(lazyTarget);
        expect(computeCount, 0);

        // First downstream read forces coupler._resolve() -> lazyTarget._resolve() -> version bump
        expect(untracked(downstream), 51);
        expect(computeCount, 1);
        expect(downstreamRuns, 1);

        // Subsequent read on unchanged data is cached
        expect(untracked(downstream), 51);
        expect(computeCount, 1);
        expect(downstreamRuns, 1);

        // Upstream mutation propagates through coupler to downstream
        root.data = 7;
        expect(untracked(downstream), 71);
        expect(computeCount, 2);
        expect(downstreamRuns, 2);
      });

      test('3.2 WhatCoupler: Decouple and error transitions correctly advance versions', () {
        final initial = WhatController(42);
        final coupler = WhatCoupler<int>(initial.what);

        expect(untracked(coupler.what), 42);

        // Decouple transitions to Empty state and increments version
        coupler.decouple();
        expect(untracked.state(coupler.what).isEmpty, isTrue);

        // Set error transitions to Error state and increments version
        coupler.setError(Exception('Failed to load'));
        expect(untracked.state(coupler.what).hasError, isTrue);

        // Re-couple to valid node
        final fresh = WhatController(100);
        coupler.couple(fresh.what);
        expect(untracked(coupler.what), 100);
      });

      test('3.3 What.switched: Synchronizes version when switching branches to uncomputed lazy computed', () {
        final selector = WhatController('branchA');
        final rootA = WhatController(10);
        final rootB = WhatController(20);

        var aRuns = 0;
        final lazyA = computed((via) {
          aRuns++;
          return via(rootA.what) * 2;
        });

        var bRuns = 0;
        final lazyB = computed((via) {
          bRuns++;
          return via(rootB.what) * 3;
        });

        final switchedWhat = switched((via) {
          return via(selector.what) == 'branchA' ? lazyA : lazyB;
        });

        var downstreamRuns = 0;
        final downstream = computed((via) {
          downstreamRuns++;
          return 'Result: ${via(switchedWhat)}';
        });

        // Initial read: branchA
        expect(untracked(downstream), 'Result: 20');
        expect(aRuns, 1);
        expect(bRuns, 0);
        expect(downstreamRuns, 1);

        // Switch to branchB (lazyB has never been pulled before)
        selector.data = 'branchB';

        // Downstream read must trigger switchedWhat._resolve() which pulls lazyB,
        // synchronizes _pulledVersion, advances switchedWhat._version, and serves fresh state.
        expect(untracked(downstream), 'Result: 60');
        expect(bRuns, 1);
        expect(downstreamRuns, 2);

        // Mutating rootB must correctly notify downstream because pulledVersion matches
        rootB.data = 25;
        expect(untracked(downstream), 'Result: 75');
        expect(bRuns, 2);
        expect(downstreamRuns, 3);
      });

      test('3.4 What.switched with Distinct: Drops downstream re-computation if branch output is unchanged', () {
        final selector = WhatController(1);
        final root = WhatController((flag: true, text: 'Hello'));

        final distinctText = computed((via) => via(root.what).text).distinct();
        final staticBranch = What.constant('Static');

        final switchedWhat = switched((via) {
          return via(selector.what) == 1 ? distinctText : staticBranch;
        });

        var downstreamRuns = 0;
        final downstream = RawComputedTerminal(
          (via) {
            downstreamRuns++;
            return 'Output: ${via(switchedWhat)}';
          },
          onInvalidated: () {},
        );
        downstream.activate();

        expect(downstream.data, 'Output: Hello');
        expect(downstreamRuns, 1);

        // Mutate root flag: text remains 'Hello' -> distinct does not increment version
        root.data = (flag: false, text: 'Hello');

        // Downstream read should drop recomputation because switchedWhat._version is clean
        expect(downstream.data, 'Output: Hello');
        expect(downstreamRuns, 1, reason: 'Downstream computation must be dropped via short-circuit');

        // Mutate root text: now it changes
        root.data = (flag: false, text: 'World');
        expect(downstream.data, 'Output: World');
        expect(downstreamRuns, 2);

        downstream.deactivate();
      });

      test('3.5 What.switched: Switching to throwing selector catches into Error state and increments version', () {
        final flag = WhatController(true);
        final switchedWhat = switched<int>((via) {
          if (via(flag.what)) {
            return What.constant(100);
          }
          throw UnsupportedError('Unsupported dynamic route');
        });

        expect(untracked(switchedWhat), 100);

        // Trigger switch error
        flag.data = false;
        expect(untracked.state(switchedWhat).hasError, isTrue);
        expect(untracked.state(switchedWhat).error, isA<UnsupportedError>());

        // Restore to valid branch
        flag.data = true;
        expect(untracked.state(switchedWhat).hasData, isTrue);
        expect(untracked(switchedWhat), 100);
      });
    });

    // =========================================================================
    // Group 4: Transform, Filter & Temporal Relays
    // =========================================================================
    group('4. Transform, Filter & Temporal Relays', () {
      test('4.1 DistinctWhat: PullResolver advances pulledVersion after source._read() even when value unchanged', () {
        final root = WhatController(100);
        var sourceComputeRuns = 0;
        final lazySource = computed((via) {
          sourceComputeRuns++;
          return via(root.what) ~/ 10;
        });

        var distinctRuns = 0;
        final distinctNode = computed((via) {
          distinctRuns++;
          return via(lazySource);
        }).distinct();

        // First read
        expect(untracked(distinctNode), 10);
        expect(sourceComputeRuns, 1);
        expect(distinctRuns, 1);

        // Read again on unchanged: 0 computations
        expect(untracked(distinctNode), 10);
        expect(sourceComputeRuns, 1);
        expect(distinctRuns, 1);

        // Mutate root to produce same quotient: 105 ~/ 10 == 10
        root.data = 105;
        expect(untracked(distinctNode), 10);
        expect(sourceComputeRuns, 2);
        // distinctNode re-evaluated lazySource, found it was identical 10, did NOT bump version
        expect(distinctRuns, 2);

        // Subsequent read on unchanged data: must NOT re-evaluate!
        expect(untracked(distinctNode), 10);
        expect(sourceComputeRuns, 2);
        expect(distinctRuns, 2);
      });

      test('4.2 RetainedWhat: Pending state transitions correctly manage and sync versions with pending coupler', () {
        final root = WhatController<String>('Initial');
        final pendingCoupler = WhatCoupler<bool>.late();
        final retained = root.what.retained(pending: pendingCoupler);

        expect(untracked(retained), 'Initial');
        expect(untracked(pendingCoupler.what), isFalse);

        // Invalidate root to empty
        root.empty('Loading...');
        expect(untracked(retained), 'Initial', reason: 'Retained node must retain previous valid state');
        expect(untracked(pendingCoupler.what), isTrue);

        // Restore root to valid
        root.data = 'Updated';
        expect(untracked(retained), 'Updated');
        expect(untracked(pendingCoupler.what), isFalse);
      });

      test('4.3 KeyedMapWhat: Dynamic list generation from lazy source synchronizes version cleanly', () {
        final count = WhatController(3);
        var listComputeRuns = 0;
        final lazyList = computed((via) {
          listComputeRuns++;
          final c = via(count.what);
          return List.generate(c, (i) => 'Item $i');
        });

        final elements = lazyList.keyed.map(
          key: (item) => item,
          convert: (item) => item.toUpperCase(),
        );

        expect(untracked(elements), ['ITEM 0', 'ITEM 1', 'ITEM 2']);
        expect(listComputeRuns, 1);

        // Subsequent read is clean
        expect(untracked(elements), ['ITEM 0', 'ITEM 1', 'ITEM 2']);
        expect(listComputeRuns, 1);

        count.data = 4;
        expect(untracked(elements), ['ITEM 0', 'ITEM 1', 'ITEM 2', 'ITEM 3']);
        expect(listComputeRuns, 2);
      });

      test('4.4 DebouncedWhat: Deferred pull synchronizes version upon timer expiration', () async {
        final root = WhatController(1);
        final debounced = root.what.debounced(const Duration(milliseconds: 20));
        final observed = <int>[untracked(debounced)];
        final terminal = RawWhatTerminal(debounced, onInvalidated: () {
          observed.add(untracked(debounced));
        });
        terminal.activate();

        expect(observed, [1]);

        // Mutate root rapidly
        root.data = 2;
        root.data = 3;
        root.data = 4;

        // Before timer elapses, onInvalidated has not fired
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(observed, [1]);

        // Wait for debounce window
        await Future<void>.delayed(const Duration(milliseconds: 25));

        // Now debounced emits trailing and synchronizes version
        expect(observed, [1, 4]);
        expect(untracked(debounced), 4);

        terminal.deactivate();
      });

      test('4.5 ThrottledWhat: Leading and trailing window accurately synchronizes version', () async {
        final root = WhatController('A');
        final throttled = root.what.throttled(
          const Duration(milliseconds: 25),
          leading: true,
          trailing: true,
        );

        final observed = <String>[untracked(throttled)];
        final terminal = RawWhatTerminal(throttled, onInvalidated: () {
          observed.add(untracked(throttled));
        });
        terminal.activate();

        expect(observed, ['A']);

        // First mutation passes immediately (leading)
        root.data = 'B';
        expect(observed, ['A', 'B']);

        // Subsequent mutation within cooldown is suppressed
        root.data = 'C';
        expect(observed, ['A', 'B'], reason: 'Must not emit during cooldown');

        // Wait for cooldown to expire
        await Future<void>.delayed(const Duration(milliseconds: 35));

        // Trailing value emitted and version synchronized
        expect(observed, ['A', 'B', 'C']);
        expect(untracked(throttled), 'C');

        terminal.deactivate();
      });

      test('4.6 GracefulWhat: Graceful node preserves state and synchronizes version during grace window', () {
        final root = WhatController(50);
        var lazyRuns = 0;
        final lazySource = computed((via) {
          lazyRuns++;
          return via(root.what) * 2;
        });

        final gracefulNode = lazySource.graceful(const Graceful.period(Duration(milliseconds: 50)));
        final terminal = RawWhatTerminal(gracefulNode, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 100);
        expect(lazyRuns, 1);

        // Deactivate: enters graceful delay window
        terminal.deactivate();

        // Mutate root while in graceful deactivation
        root.data = 60;

        // Re-activate: gracefulNode pulls fresh state and synchronizes version
        terminal.activate();
        expect(terminal.data, 120);
        expect(lazyRuns, 2);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // Group 5: Managed Resources Lifecycle (What.managed)
    // =========================================================================
    group('5. Managed Resources Lifecycle (What.managed)', () {
      test('5.1 What.managed: Resolves uncomputed lazy dependencies and manages resource versions', () {
        final config = WhatController({'port': 8080});
        var lazyRuns = 0;
        final lazyPort = computed((via) {
          lazyRuns++;
          return via(config.what)['port']!;
        });

        var createdCount = 0;
        var updatedCount = 0;
        var disposedCount = 0;

        final server = managed<String>(
          create: (via) {
            createdCount++;
            final port = via(lazyPort);
            return 'Server-$port';
          },
          update: (via, current) {
            updatedCount++;
            final port = via(lazyPort);
            return 'Server-$port';
          },
          dispose: (resource) {
            disposedCount++;
          },
        );

        final terminal = RawWhatTerminal(server, onInvalidated: () {});
        terminal.activate();

        // First read: forces lazyPort._read() -> manages edge versions
        expect(terminal.data, 'Server-8080');
        expect(createdCount, 1);
        expect(lazyRuns, 1);
        expect(updatedCount, 0);

        // Read again on unchanged: cached
        expect(terminal.data, 'Server-8080');
        expect(createdCount, 1);
        expect(lazyRuns, 1);

        // Mutate config: triggers update
        config.data = {'port': 9000};
        expect(terminal.data, 'Server-9000');
        expect(updatedCount, 1);
        expect(lazyRuns, 2);
        expect(disposedCount, 1);

        terminal.deactivate();
        expect(disposedCount, 2);
      });

      test('5.2 What.managed: Guard transitions between Valid and Empty correctly increment and sync versions', () {
        final isEnabled = WhatController(false);
        final payload = WhatController('Data');

        var createCount = 0;
        var disposeCount = 0;

        final res = managed<String>(
          guard: (via) => via(isEnabled.what).guarded(),
          create: (via) {
            createCount++;
            return 'Resource-${via(payload.what)}';
          },
          dispose: (r) {
            disposeCount++;
          },
        );

        final terminal = RawWhatTerminal(res, onInvalidated: () {});
        terminal.activate();

        // Guard is false -> Empty state
        expect(terminal.isEmpty, isTrue);
        expect(createCount, 0);

        // Enable guard -> transitions to Valid state, version increments
        isEnabled.data = true;
        expect(terminal.hasData, isTrue);
        expect(terminal.data, 'Resource-Data');
        expect(createCount, 1);

        // Disable guard -> transitions back to Empty, disposes current resource, version increments
        isEnabled.data = false;
        expect(terminal.isEmpty, isTrue);
        expect(disposeCount, 1);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // Group 6: Deep Cascading Multi-tier Lazy Graph (Diamond DAG Invariant)
    // =========================================================================
    group('6. Deep Cascading Multi-tier Lazy Graph', () {
      test('6.1 Multi-tier uncomputed chain resolves atomically from terminal read with 0 redundant computations', () {
        // Topology:
        // root -> lazyCompA -> switched -> distinct -> lazyCompB -> terminal
        final root = WhatController(10);
        final mode = WhatController(true);

        var compARuns = 0;
        final lazyCompA = computed((via) {
          compARuns++;
          return via(root.what) * 2; // 20
        });

        final alternate = What.constant(999);

        final switchedNode = switched((via) {
          return via(mode.what) ? lazyCompA : alternate;
        });

        final distinctNode = computed((via) => via(switchedNode)).distinct();

        var compBRuns = 0;
        final lazyCompB = computed((via) {
          compBRuns++;
          return via(distinctNode) + 5; // 25
        });

        final terminal = RawWhatTerminal(lazyCompB, onInvalidated: () {});
        terminal.activate();

        // Before any read, entire chain is uncomputed
        expect(compARuns, 0);
        expect(compBRuns, 0);

        // 1. Single terminal read forces entire cascading lazy-pull resolution
        expect(terminal.data, 25);
        expect(compARuns, 1);
        expect(compBRuns, 1);

        // 2. Second read: every single node in the chain is clean and synchronised -> 0 re-computations!
        expect(terminal.data, 25);
        expect(compARuns, 1);
        expect(compBRuns, 1);

        // 3. Mutate root: propagates through entire chain accurately
        root.data = 15;
        expect(terminal.data, 35); // (15 * 2) + 5
        expect(compARuns, 2);
        expect(compBRuns, 2);

        terminal.deactivate();
      });

      test('6.2 Diamond Multi-tier DAG: Dual converging lazy paths synchronize atomically without glitch', () {
        // Topology:
        //           root
        //          /    \
        //     lazyLeft  lazyRight
        //          \    /
        //          join
        //            |
        //         terminal
        final root = WhatController(10);
        var leftComputes = 0;
        var rightComputes = 0;
        var joinComputes = 0;

        final lazyLeft = computed((via) {
          leftComputes++;
          return via(root.what) + 1; // 11
        });

        final lazyRight = computed((via) {
          rightComputes++;
          return via(root.what) * 2; // 20
        });

        final join = computed((via) {
          joinComputes++;
          return via(lazyLeft) + via(lazyRight); // 31
        });

        final terminal = RawWhatTerminal(join, onInvalidated: () {});
        terminal.activate();

        // Initial atomic resolution
        expect(terminal.data, 31);
        expect(leftComputes, 1);
        expect(rightComputes, 1);
        expect(joinComputes, 1);

        // Re-read: clean cache
        expect(terminal.data, 31);
        expect(leftComputes, 1);
        expect(rightComputes, 1);
        expect(joinComputes, 1);

        // Mutate root: both branches mark dirty, join resolves both atomically
        root.data = 20;
        // left: 21, right: 40 -> join: 61
        expect(terminal.data, 61);
        expect(leftComputes, 2);
        expect(rightComputes, 2);
        expect(joinComputes, 2);

        terminal.deactivate();
      });
    });
  });
}
