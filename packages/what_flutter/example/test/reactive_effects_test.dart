// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';
import 'package:what_flutter_example/sections/reactive_effects_section.dart';
import 'package:what_flutter_example/sections/scoped_state_di_section.dart';
import 'package:what_flutter_example/store/showcase_store.dart';

void main() {
  group('ReactiveEffectsStore Unit Tests', () {
    test('Dynamic discovery, untracked boundaries, and tuple effects',
        () async {
      final store = ReactiveEffectsStore();
      final terminal = RawViaTerminal((via) {
        if (via(store.isEffectActive)) {
          via.tether(store.effects);
        }
      }, onInvalidated: () {});
      terminal.activate();
      terminal.evaluate();

      // Allow microtask scheduler to run initial effect evaluation
      await Future<void>.delayed(Duration.zero);

      // Upon activation:
      // watchEffect runs initially: 1
      // tupleEffect and singleEffect skip initial run: 0
      final initialRuns = store.effectRunCount.peek;
      expect(initialRuns, equals(1));

      // 1. Mutate primary counter
      store.incrementCounter();
      // Allow microtask scheduler to flush
      await Future<void>.delayed(Duration.zero);

      final runsAfterInc = store.effectRunCount.peek;
      expect(runsAfterInc, greaterThan(initialRuns));

      // 2. Untracked execution boundary
      // Mutating untrackedNode must NOT trigger watchEffect
      final beforeUntracked = store.effectRunCount.peek;
      store.mutateUntracked();
      await Future<void>.delayed(Duration.zero);
      // Only the manual log call in mutateUntracked happens, watchEffect does NOT fire
      // (effectRunCount is incremented by effects, not by mutateUntracked directly)
      expect(store.effectRunCount.peek, beforeUntracked);

      // 3. Dynamic dependency branch tracking
      // When isTrackingDetails is false, mutating detailPayload must NOT trigger effect
      final beforePayload = store.effectRunCount.peek;
      store.cycleDetailPayload();
      await Future<void>.delayed(Duration.zero);
      expect(store.effectRunCount.peek, beforePayload);

      // Toggle dynamic branch to true
      store.toggleDetailTracking(true);
      await Future<void>.delayed(Duration.zero);

      // Now mutating detailPayload MUST trigger watchEffect!
      final beforeActivePayload = store.effectRunCount.peek;
      store.cycleDetailPayload();
      await Future<void>.delayed(Duration.zero);
      expect(store.effectRunCount.peek, greaterThan(beforeActivePayload));

      // 4. Explicit Tuple Effect ((counter, alertThreshold).effect)
      // Set threshold to 10 and counter to 9 (no alert)
      store.setAlertThreshold(10);
      store.setCounter(9);
      await Future<void>.delayed(Duration.zero);
      expect(store.lastThresholdAlert.peek, 'None');

      // Now increment to 10 (meets threshold)
      store.incrementCounter();
      await Future<void>.delayed(Duration.zero);
      expect(store.lastThresholdAlert.peek, contains('Threshold Reached!'));

      // 5. Lifecycle deactivation & reactivation
      store.toggleLifecycle(false);
      terminal.evaluate();
      final runsWhileInactive = store.effectRunCount.peek;
      store.incrementCounter();
      await Future<void>.delayed(Duration.zero);
      expect(store.effectRunCount.peek, runsWhileInactive);

      // Reactivate
      store.toggleLifecycle(true);
      terminal.evaluate();
      store.incrementCounter();
      await Future<void>.delayed(Duration.zero);
      expect(store.effectRunCount.peek, greaterThan(runsWhileInactive));

      terminal.deactivate();
    });
  });

  group('ReactiveEffectsSectionDemo Widget Tests', () {
    testWidgets(
        'Renders controls, terminal, and triggers effects interactively',
        (WidgetTester tester) async {
      final showcaseStore = ShowcaseStore();

      await tester.pumpWidget(
        What.constant(showcaseStore).provide(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReactiveEffectsSectionDemo(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and badge check
      expect(find.text('Zero-Rebuild Invariant Guaranteed'), findsOneWidget);
      expect(find.text('EFFECT RUNS'), findsOneWidget);

      // Tap Increment (+1) button
      final incrementBtn =
          find.widgetWithText(ElevatedButton, 'Increment (+1)');
      expect(incrementBtn, findsOneWidget);
      await tester.tap(incrementBtn);
      await tester.pump(const Duration(milliseconds: 50));

      // Counter should display 1
      expect(find.text('Counter State: 1'), findsOneWidget);

      // Toggle dynamic branch filter chip
      final dynamicChip =
          find.widgetWithText(FilterChip, 'Dynamic Branch Tracking');
      expect(dynamicChip, findsOneWidget);
      await tester.tap(dynamicChip);
      await tester.pump(const Duration(milliseconds: 50));

      // Cycle payload button should now appear
      expect(find.text('Cycle Payload'), findsOneWidget);
    });

    testWidgets(
        'ScopedStateDiSectionDemo anchors effect to widget lifecycle and automatically activates/deactivates',
        (WidgetTester tester) async {
      final showcaseStore = ShowcaseStore();
      final scopedStore = showcaseStore.sections.scopedStateDi;

      // Initially false
      expect(scopedStore.isVipUnlocked.peek, false);

      // Mount widget
      await tester.pumpWidget(
        What.constant(showcaseStore).provide(
          child: MaterialApp(
            home: Scaffold(
              body: ScopedStateDiSectionDemo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially total is $290 (< $300), VIP is false
      expect(scopedStore.isVipUnlocked.peek, false);
      expect(find.textContaining('Cart < \$300'), findsOneWidget);

      // Increment item1 (120*2 + 170 = $410 >= $300)
      scopedStore.incrementItem1();
      await tester.pumpAndSettle();

      // Computed isVipUnlocked is true, and watch.effect triggered Milestone SnackBar!
      expect(scopedStore.isVipUnlocked.peek, true);
      expect(find.textContaining('VIP (\$300+)'), findsOneWidget);
      expect(find.textContaining('VIP Milestone Unlocked!'), findsOneWidget);

      // Unmount widget
      await tester.pumpWidget(
        What.constant(showcaseStore).provide(
          child: const MaterialApp(
            home: Scaffold(body: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // While unmounted: effect is deactivated!
      // Decrement item1 (total drops to $290 < $300)
      scopedStore.decrementItem1();
      await tester.pumpAndSettle();
      expect(scopedStore.isVipUnlocked.peek, false);

      // Remount widget
      await tester.pumpWidget(
        What.constant(showcaseStore).provide(
          child: MaterialApp(
            home: Scaffold(
              body: ScopedStateDiSectionDemo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger VIP again while mounted
      scopedStore.incrementItem1();
      await tester.pumpAndSettle();
      expect(scopedStore.isVipUnlocked.peek, true);
      expect(find.textContaining('VIP Milestone Unlocked!'), findsOneWidget);
    });
  });
}
