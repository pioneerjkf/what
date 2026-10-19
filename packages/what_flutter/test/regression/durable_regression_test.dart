// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/src/animation/durable/testing.dart';

void main() {
  group('DurableAnimationController Defect Verification Tests', () {
    testWidgets(
      'Issue 2: CatchUpAnimationController reverse fling simulation must notify dismissed (not completed) when done in dormancy',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.8,
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        controller.view.addStatusListener(statuses.add);

        // Run reverse fling
        controller.fling(velocity: -2.0);
        await tester.pump();
        expect(statuses, contains(AnimationStatus.reverse));

        // Hibernate into dormant state
        controller.hibernate();
        await tester.pump();
        expect(controller.isDormant, isTrue);

        // Advance wall-clock by 5 seconds so the motion completes
        currentTime = currentTime.add(const Duration(seconds: 5));

        // Reading value and status while dormant purely projects progress without firing listeners
        final finalVal = controller.value;
        expect(finalVal, closeTo(0.0, 0.001));
        expect(controller.status, equals(AnimationStatus.dismissed));

        // Pure getter read must NOT have fired listener yet
        expect(statuses.last, equals(AnimationStatus.reverse));

        // Reactivating via wake flushes the completion status atomically
        controller.wake(savedVsync);
        await tester.pump();
        expect(
          statuses.last,
          equals(AnimationStatus.dismissed),
          reason:
              'Reverse motion completing in dormancy must notify dismissed upon wake-up',
        );

        controller.hibernate();
      },
    );

    testWidgets(
      'Issue 1: resumeMotion animateTo / animateBack completion must safely set target without NPE',
      (WidgetTester tester) async {
        late DurableAnimationController controller;
        late TickerProvider savedVsync;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                value: 0.0,
                lowerBound: 0.0,
                upperBound: 1.0,
                duration: const Duration(milliseconds: 200),
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        controller.view.addStatusListener(statuses.add);

        // Start animating to 1.0
        controller.animateTo(1.0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, greaterThan(0.2));

        // Hibernate controller
        controller.hibernate();
        await tester.pump();
        expect(controller.isDormant, isTrue);

        // Reactivate: resumeMotion must safely re-couple or complete without throwing NPE
        expect(
          () => controller.wake(savedVsync),
          returnsNormally,
          reason: 'wake must execute cleanly without NPE',
        );

        controller.hibernate();
      },
    );

    testWidgets(
      'Issue 3: CatchUpAnimationController.value getter in dormancy calculates catch-up value cleanly',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                lowerBound: 0.0,
                upperBound: 1.0,
                duration: const Duration(milliseconds: 1000),
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        controller.animateTo(1.0);
        await tester.pump();

        // Hibernate into dormancy
        controller.hibernate();
        await tester.pump();
        expect(controller.isDormant, isTrue);

        // Advance 500ms (50% progress)
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Read value
        final midVal = controller.value;
        expect(midVal, closeTo(0.5, 0.05));

        // Advance another 600ms (1100ms total > 1000ms -> completion)
        currentTime = currentTime.add(const Duration(milliseconds: 600));

        final completedVal = controller.value;
        expect(completedVal, equals(1.0));
        expect(controller.status, equals(AnimationStatus.completed));

        controller.hibernate();
      },
    );

    testWidgets(
      'Option 1: CatchUpAnimationController fling preserves SpringSimulation physics across dormancy and waking',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        controller.view.addStatusListener(statuses.add);

        // 1. Fling forward with velocity 2.0 (pure physics, no duration set on controller)
        controller.fling(velocity: 2.0);
        await tester.pump();
        expect(statuses, contains(AnimationStatus.forward));

        // Advance 20ms while active
        await tester.pump(const Duration(milliseconds: 20));
        expect(controller.value, greaterThan(0.01));
        final activeVal = controller.value;

        // 2. Hibernate into dormancy
        controller.hibernate();
        await tester.pump();
        expect(controller.isDormant, isTrue);

        // Advance wall-clock by 50ms while dormant
        currentTime = currentTime.add(const Duration(milliseconds: 50));

        // Value in dormancy must advance via SpringSimulation
        final dormantVal = controller.value;
        expect(dormantVal, greaterThan(activeVal));

        // 3. Reactivate with vsync: must seamlessly resume with _TimeOffsetSimulation
        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.isDormant, isFalse);
        expect(controller.isAnimating, isTrue);

        // Advance until completion
        await tester.pump(const Duration(milliseconds: 500));
        expect(controller.value, closeTo(1.0, 0.001));
        expect(statuses.last, equals(AnimationStatus.completed));

        controller.hibernate();
      },
    );

    testWidgets(
      'Task 4-8.1 Defect: CatchUpAnimationController.value getter in dormancy must NOT trigger status listeners or destroy staged motion',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 1),
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        controller.view.addStatusListener(statuses.add);

        // 1. Start forward motion
        controller.forward();
        await tester.pump();
        expect(statuses, contains(AnimationStatus.forward));
        statuses.clear();

        // 2. Hibernate into dormancy
        controller.hibernate();
        await tester.pump();
        expect(controller.isDormant, isTrue);

        // 3. Advance clock past the duration (1.5s > 1.0s)
        currentTime = currentTime.add(const Duration(milliseconds: 1500));

        // 4. Purely read controller.value while dormant
        // In an ideal architecture, reading a property MUST NOT fire side-effect listeners
        final readVal = controller.value;
        expect(readVal, equals(1.0));

        // [Defect Check]: Currently, applyElapsedCompensation inside getter synchronously
        // triggers onNotifyStatusListeners(AnimationStatus.completed) and wipes staged motion!
        // The architectural requirement: Reading a getter must NOT trigger listeners while dormant.
        expect(
          statuses,
          isEmpty,
          reason:
              'Getter read while dormant must be pure and must NOT trigger status listeners!',
        );

        // 5. Wake up / wake: Atomic wake-up flush should fire the completed status
        controller.wake(savedVsync);
        await tester.pump();
        expect(
          statuses,
          contains(AnimationStatus.completed),
          reason:
              'Status listener must fire upon waking (resync / resumeMotion), not on getter read!',
        );

        controller.hibernate();
      },
    );

    testWidgets(
      'Task 4-8.2: CatchUpAnimationController repeat(reverse: true) ping-pong phase integrity across dormancy',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 1),
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        // 1. Start ping-pong repeat (period = 1s, full cycle = 2s)
        controller.repeat(reverse: true, period: const Duration(seconds: 1));
        await tester.pump();

        // 2. Hibernate at start
        controller.hibernate();
        await tester.pump();
        expect(controller.isDormant, isTrue);

        // 3. Advance 2.5s (2 full periods = 1 full round trip, plus 0.5s into forward phase)
        currentTime = currentTime.add(const Duration(milliseconds: 2500));

        // Projected value at 2.5s should be 0.5 in forward phase
        expect(controller.value, closeTo(0.5, 0.01));

        // 4. Wake up / wake
        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.isDormant, isFalse);
        expect(controller.value, closeTo(0.5, 0.01));
        expect(controller.status, equals(AnimationStatus.forward));

        controller.hibernate();
      },
    );

    testWidgets(
      'Exhaustive 1: animateBack pure projection and wake-up dismissal',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.8,
                duration: const Duration(seconds: 1),
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();
        controller.view.addStatusListener(statuses.add);

        // Start animateBack towards 0.2
        controller.animateBack(0.2, duration: const Duration(seconds: 1));
        await tester.pump();
        expect(statuses, contains(AnimationStatus.reverse));

        // Hibernate into dormancy
        controller.hibernate();
        await tester.pump();
        expect(controller.isDormant, isTrue);

        // 1. Advance 500ms (50% progress between 0.8 and 0.2 -> approx 0.5)
        currentTime = currentTime.add(const Duration(milliseconds: 500));
        expect(controller.value, closeTo(0.5, 0.05));
        expect(controller.status, equals(AnimationStatus.reverse));
        expect(statuses.length, equals(1),
            reason: 'Pure reads must NOT trigger new listeners');

        // 2. Advance another 600ms (1100ms total > 1000ms -> target reached)
        currentTime = currentTime.add(const Duration(milliseconds: 600));
        expect(controller.value, closeTo(0.2, 0.001));
        expect(controller.status, equals(AnimationStatus.dismissed));
        expect(statuses.length, equals(1),
            reason: 'Completion in dormancy must NOT trigger listeners yet');

        // 3. Wake up / wake: flushes dismissed status
        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.isDormant, isFalse);
        expect(controller.value, closeTo(0.2, 0.001));
        expect(statuses.last, equals(AnimationStatus.dismissed));

        controller.hibernate();
      },
    );

    testWidgets(
      'Exhaustive 2: animateWith (Custom Simulation) forward projection and completion',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();
        controller.view.addStatusListener(statuses.add);

        // Start forward simulation: linear step simulation taking 1.0s
        final sim = FrictionSimulation(0.05, 0.0, 1.5);
        controller.animateWith(sim);
        await tester.pump();
        expect(statuses, contains(AnimationStatus.forward));

        controller.hibernate();
        await tester.pump();

        // 1. Advance 200ms
        currentTime = currentTime.add(const Duration(milliseconds: 200));
        expect(controller.value, closeTo(sim.x(0.2).clamp(0.0, 1.0), 0.01));
        expect(controller.status, equals(AnimationStatus.forward));
        expect(statuses.length, equals(1));

        // 2. Advance 10s (past simulation completion)
        currentTime = currentTime.add(const Duration(seconds: 10));
        expect(controller.value, closeTo(sim.x(10.2).clamp(0.0, 1.0), 0.01));
        expect(controller.status, equals(AnimationStatus.completed));
        expect(statuses.length, equals(1));

        // 3. Wake up / wake
        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.isDormant, isFalse);
        expect(statuses.last, equals(AnimationStatus.completed));

        controller.hibernate();
      },
    );

    testWidgets(
      'Exhaustive 3: animateBackWith (Custom Simulation) reverse projection and dismissal',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 1.0,
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();
        controller.view.addStatusListener(statuses.add);

        // Start reverse simulation: velocity = -1.5
        final sim = FrictionSimulation(0.05, 1.0, -1.5);
        controller.animateBackWith(sim);
        await tester.pump();
        expect(statuses, contains(AnimationStatus.reverse));

        controller.hibernate();
        await tester.pump();

        // 1. Advance 200ms
        currentTime = currentTime.add(const Duration(milliseconds: 200));
        expect(controller.value, closeTo(sim.x(0.2).clamp(0.0, 1.0), 0.01));
        expect(controller.status, equals(AnimationStatus.reverse));
        expect(statuses.length, equals(1));

        // 2. Advance 10s (past simulation completion)
        currentTime = currentTime.add(const Duration(seconds: 10));
        expect(controller.value, closeTo(sim.x(10.2).clamp(0.0, 1.0), 0.01));
        expect(controller.status, equals(AnimationStatus.dismissed));
        expect(statuses.length, equals(1));

        // 3. Wake up / wake
        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.isDormant, isFalse);
        expect(statuses.last, equals(AnimationStatus.dismissed));

        controller.hibernate();
      },
    );

    testWidgets(
      'Exhaustive 4: repeat(count: N, reverse: true) odd and even count termination boundaries',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 1),
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        // --- Test 4-A: Odd count (count: 1) terminates at upperBound (1.0) with completed status ---
        controller.repeat(
            reverse: true, count: 1, period: const Duration(seconds: 1));
        await tester.pump();
        controller.hibernate();
        await tester.pump();

        currentTime = currentTime.add(const Duration(milliseconds: 1500));
        expect(controller.value, equals(1.0));
        expect(controller.status, equals(AnimationStatus.completed));

        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.value, equals(1.0));
        expect(controller.status, equals(AnimationStatus.completed));

        // --- Test 4-B: Even count (count: 2) terminates at lowerBound (0.0) with dismissed status ---
        controller.value = 0.0;
        controller.repeat(
            reverse: true, count: 2, period: const Duration(seconds: 1));
        await tester.pump();
        controller.hibernate();
        await tester.pump();

        currentTime = currentTime.add(const Duration(milliseconds: 2500));
        expect(controller.value, equals(0.0));
        expect(controller.status, equals(AnimationStatus.dismissed));

        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.value, equals(0.0));
        expect(controller.status, equals(AnimationStatus.dismissed));

        controller.hibernate();
      },
    );

    testWidgets(
      'Exhaustive 5: Incremental multiple pure reads in dormancy maintain monotonic projection and 0 listeners',
      (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 1),
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();
        controller.view.addStatusListener(statuses.add);

        controller.forward();
        await tester.pump();
        expect(statuses, contains(AnimationStatus.forward));

        controller.hibernate();
        await tester.pump();

        // Perform multiple successive reads as time advances
        currentTime = currentTime.add(const Duration(milliseconds: 200));
        expect(controller.value, closeTo(0.2, 0.01));
        expect(controller.status, equals(AnimationStatus.forward));

        currentTime = currentTime.add(const Duration(milliseconds: 300));
        expect(controller.value, closeTo(0.5, 0.01));
        expect(controller.status, equals(AnimationStatus.forward));

        currentTime = currentTime.add(const Duration(milliseconds: 300));
        expect(controller.value, closeTo(0.8, 0.01));
        expect(controller.status, equals(AnimationStatus.forward));

        currentTime = currentTime.add(const Duration(milliseconds: 400));
        expect(controller.value, equals(1.0));
        expect(controller.status, equals(AnimationStatus.completed));

        // ZERO status listeners must have fired across all 4 successive reads
        expect(statuses.length, equals(1),
            reason: 'Zero side-effects during intermediate reads');

        // Wake up / wake: only now is the completion flushed
        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.isDormant, isFalse);
        expect(statuses.last, equals(AnimationStatus.completed));

        controller.hibernate();
      },
    );

    testWidgets(
      'Successive motion switches in dormancy flush previous progress and re-anchor timestamp',
      (tester) async {
        late TickerProvider savedVsync;
        late DurableAnimationController controller;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 1),
                reverseDuration: const Duration(seconds: 1),
                lowerBound: 0.0,
                upperBound: 1.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        // 1. Start forward, then hibernate
        controller.forward();
        await tester.pump();
        controller.hibernate();
        await tester.pump();

        // 2. Advance 500ms in dormancy (value should project to 0.5)
        currentTime = currentTime.add(const Duration(milliseconds: 500));
        expect(controller.value, closeTo(0.5, 0.01));

        // 3. Switch to reverse while still dormant!
        // Should flush progress to 0.5 and re-anchor baseline to currentTime
        controller.reverse();

        // 4. Advance 200ms in reverse motion
        currentTime = currentTime.add(const Duration(milliseconds: 200));
        // Expect 0.5 - 0.2 = 0.3
        expect(controller.value, closeTo(0.3, 0.01));
        expect(controller.status, equals(AnimationStatus.reverse));

        // 5. Advance another 300ms to complete reverse motion
        currentTime = currentTime.add(const Duration(milliseconds: 300));
        expect(controller.value, equals(0.0));
        expect(controller.status, equals(AnimationStatus.dismissed));

        // 6. Wake up and verify active controller preserves dismissed state
        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.isDormant, isFalse);
        expect(controller.value, equals(0.0));
        expect(controller.status, equals(AnimationStatus.dismissed));

        controller.hibernate();
      },
    );

    testWidgets(
      'P0 Fix: resumeMotion repeat reverse-phase animateBack does NOT trigger stale repeat if stopped/interrupted',
      (WidgetTester tester) async {
        late TickerProvider savedVsync;
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                value: 0.5,
                duration: const Duration(milliseconds: 400),
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        // 1. Start repeat with reverse
        controller.repeat(reverse: true);
        await tester.pump(const Duration(milliseconds: 300));
        // controller is in reverse phase
        controller.hibernate();
        await tester.pump();

        // 2. Wake up (triggers resumeMotion with animateBack)
        controller.wake(savedVsync);
        await tester.pump();

        // 3. Immediately stop while animateBack is in-flight
        controller.stop();
        expect(controller.isAnimating, isFalse);

        // 4. Advance time past the animateBack completion window
        await tester.pump(const Duration(milliseconds: 500));

        // 5. Must REMAIN stopped and not resurrected into repeat
        expect(controller.isAnimating, isFalse);

        controller.hibernate();
      },
    );

    testWidgets(
      'resumeMotion repeat reverse-phase animateBack smoothly transitions into engine.repeat when uninterrupted',
      (WidgetTester tester) async {
        late TickerProvider savedVsync;
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                value: 0.5,
                duration: const Duration(milliseconds: 400),
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        // 1. Start repeat with reverse
        controller.repeat(reverse: true);
        await tester.pump(const Duration(milliseconds: 300));
        // controller is in reverse phase
        controller.hibernate();
        await tester.pump();

        // 2. Wake up (triggers resumeMotion with animateBack)
        controller.wake(savedVsync);
        await tester.pump();

        // 3. Advance time past the animateBack completion window (uninterrupted)
        await tester.pump(const Duration(milliseconds: 500));

        // 4. Must continue repeating
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
      },
    );

    testWidgets(
      'P1 Fix: Disposed proxy isolates listeners and target remains dormant without throwing',
      (WidgetTester tester) async {
        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
        );
        final showWhat = WhatController<bool>(true);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: composed(
              (context, via) {
                if (via(showWhat.what)) {
                  return composed.animate(
                    controller,
                    (context, via, ctrl) => Text('Val: ${ctrl.value}'),
                  );
                }
                return const Text('Hidden');
              },
            ),
          ),
        );
        expect(controller.isActive, isTrue);
        expect(find.text('Val: 0.0'), findsOneWidget);

        // Unmounting inline widget detaches internal proxy listeners and hibernates controller
        showWhat.data = false;
        await tester.pumpAndSettle();

        expect(find.text('Hidden'), findsOneWidget);
        expect(controller.isDormant, isTrue);

        // Target controller hibernates gracefully and remains safe for reactivation
        showWhat.data = true;
        await tester.pumpAndSettle();

        expect(find.text('Val: 0.0'), findsOneWidget);
        expect(controller.isActive, isTrue);

        controller.hibernate();
      },
    );

    testWidgets(
      'Blast-proof activation: throwing vsync during wake leaves FrozenAnimationController dormant and reports error',
      (WidgetTester tester) async {
        final controller = DurableAnimationController(
          value: 0.5,
          duration: const Duration(seconds: 1),
        );
        expect(controller.isDormant, isTrue);

        final errors = <FlutterErrorDetails>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = errors.add;

        try {
          final brokenVsync = TestDurableVSync(
            tickerFactory: (_) =>
                throw StateError('Simulated Ticker creation failure'),
          );
          controller.wake(brokenVsync);

          // Activation failed: controller must remain dormant and clean
          expect(controller.isDormant, isTrue);
          expect(controller.value, equals(0.5));
          expect(errors, hasLength(1));
          expect(errors.first.exception, isA<StateError>());

          // Detaching un-attached broken vsync returns false
          expect(controller.detachVsync(brokenVsync), isFalse);
        } finally {
          FlutterError.onError = oldHandler;
        }
      },
    );

    testWidgets(
      'Blast-proof activation: throwing vsync during wake leaves CatchUpAnimationController dormant and reports error',
      (WidgetTester tester) async {
        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.5,
          duration: const Duration(seconds: 1),
        );
        expect(controller.isDormant, isTrue);

        final errors = <FlutterErrorDetails>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = errors.add;

        try {
          final brokenVsync = TestDurableVSync(
            tickerFactory: (_) =>
                throw StateError('Simulated Ticker creation failure'),
          );
          controller.wake(brokenVsync);

          // Activation failed: controller must remain dormant and clean
          expect(controller.isDormant, isTrue);
          expect(controller.value, equals(0.5));
          expect(errors, hasLength(1));
          expect(errors.first.exception, isA<StateError>());

          // Detaching un-attached broken vsync returns false
          expect(controller.detachVsync(brokenVsync), isFalse);
        } finally {
          FlutterError.onError = oldHandler;
        }
      },
    );

    // =========================================================================
    // DurabilityPolicy.reset Invariant & Defect Regression Suite
    // =========================================================================
    group('DurabilityPolicy.reset Invariants & Dormancy Defect Verification',
        () {
      testWidgets(
        'Reset Defect 1: Repeat ping-pong motion deactivation cancels staged motion, resets to initial value, and stays idle upon remount',
        (WidgetTester tester) async {
          late DurableAnimationController controller;
          TickerProvider? vsyncRef;

          controller = DurableAnimationController(
            policy: DurabilityPolicy.reset,
            duration: const Duration(milliseconds: 1000),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: composed.vsync((context, via, vsync) {
                vsyncRef = vsync;
                return const SizedBox.shrink();
              }),
            ),
          );

          expect(vsyncRef, isNotNull);
          controller.wake(vsyncRef!);
          expect(controller.isActive, isTrue);

          // 1. Start oscillating ping-pong animation
          controller.repeat(reverse: true);
          await tester.pump();
          expect(controller.isAnimating, isTrue);

          // Advance 400ms into forward phase (t ~ 0.4)
          await tester.pump(const Duration(milliseconds: 400));
          expect(controller.value, closeTo(0.4, 0.05));
          expect(controller.status, equals(AnimationStatus.forward));

          // 2. Deactivate into dormancy (unmount)
          controller.hibernate();
          await tester.pump();

          // Must be dormant, value reset to 0.0, and NOT animating
          expect(controller.isDormant, isTrue);
          expect(controller.value, equals(0.0));
          expect(controller.isAnimating, isFalse);
          expect(controller.status, equals(AnimationStatus.dismissed));

          // 3. Remount (wake)
          controller.wake(vsyncRef!);
          await tester.pump();

          // Must wake up at 0.0 and remain IDLE (no background ghost animation)
          expect(controller.isActive, isTrue);
          expect(controller.value, equals(0.0));
          expect(controller.isAnimating, isFalse,
              reason:
                  'DurabilityPolicy.reset must NOT resume ghost motion on wake');
          expect(controller.status, equals(AnimationStatus.dismissed));

          // 4. Starting repeat explicitly starts from 0.0 towards 1.0 smoothly
          controller.repeat(reverse: true);
          await tester.pump();
          expect(controller.isAnimating, isTrue);
          await tester.pump(const Duration(milliseconds: 200));
          expect(controller.value, closeTo(0.2, 0.05));
          expect(controller.status, equals(AnimationStatus.forward));

          controller.hibernate();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        'Reset Defect 2: Deactivation during Reverse Phase resets cleanly to 0.0 without stale reverse momentum',
        (WidgetTester tester) async {
          late DurableAnimationController controller;
          TickerProvider? vsyncRef;

          controller = DurableAnimationController(
            policy: DurabilityPolicy.reset,
            duration: const Duration(milliseconds: 1000),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: composed.vsync((context, via, vsync) {
                vsyncRef = vsync;
                return const SizedBox.shrink();
              }),
            ),
          );

          expect(vsyncRef, isNotNull);
          controller.wake(vsyncRef!);
          controller.repeat(reverse: true);
          await tester.pump();

          // Move into reverse phase: 1000ms forward + 500ms reverse (t ~ 0.5 reverse)
          await tester.pump(const Duration(milliseconds: 1500));
          expect(controller.value, closeTo(0.5, 0.05));
          expect(controller.status, equals(AnimationStatus.reverse));

          // Deactivate while moving in reverse
          controller.hibernate();
          await tester.pump();

          // Must reset to 0.0 and be dismissed
          expect(controller.isDormant, isTrue);
          expect(controller.value, equals(0.0));
          expect(controller.isAnimating, isFalse);
          expect(controller.status, equals(AnimationStatus.dismissed));

          // Remount while idle
          controller.wake(vsyncRef!);
          await tester.pump();
          expect(controller.value, equals(0.0));
          expect(controller.isAnimating, isFalse);

          // Subsequent forward playback must move forward from 0.0 towards 1.0
          controller.forward();
          await tester.pump();
          expect(controller.isAnimating, isTrue);
          expect(controller.status, equals(AnimationStatus.forward));
          await tester.pump(const Duration(milliseconds: 200));
          expect(controller.value, closeTo(0.2, 0.05));

          controller.hibernate();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        'Reset Defect 3: Initial Value parameter preservation (default lowerBound vs custom initialValue vs unbounded)',
        (WidgetTester tester) async {
          TickerProvider? vsyncRef;

          await tester.pumpWidget(
            MaterialApp(
              home: composed.vsync((context, via, vsync) {
                vsyncRef = vsync;
                return const SizedBox.shrink();
              }),
            ),
          );
          expect(vsyncRef, isNotNull);

          // Case A: Custom initialValue = 0.35
          final customInitCtrl = DurableAnimationController(
            policy: DurabilityPolicy.reset,
            value: 0.35,
            duration: const Duration(milliseconds: 500),
          );
          expect(customInitCtrl.value, equals(0.35));
          customInitCtrl.wake(vsyncRef!);
          customInitCtrl.forward();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(customInitCtrl.value, greaterThan(0.5));

          customInitCtrl.hibernate();
          expect(customInitCtrl.value, equals(0.35),
              reason: 'Must reset back to the specified initialValue (0.35)');

          customInitCtrl.wake(vsyncRef!);
          expect(customInitCtrl.value, equals(0.35));
          expect(customInitCtrl.isAnimating, isFalse);
          customInitCtrl.hibernate();

          // Case B: Custom lowerBound = -2.0 without explicit value
          final customBoundsCtrl = DurableAnimationController(
            policy: DurabilityPolicy.reset,
            lowerBound: -2.0,
            upperBound: 2.0,
            duration: const Duration(milliseconds: 500),
          );
          expect(customBoundsCtrl.value, equals(-2.0));
          customBoundsCtrl.wake(vsyncRef!);
          customBoundsCtrl.animateTo(1.0);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(customBoundsCtrl.value, greaterThan(-1.0));

          customBoundsCtrl.hibernate();
          expect(customBoundsCtrl.value, equals(-2.0),
              reason:
                  'Must reset back to lowerBound (-2.0) when value is omitted');
          customBoundsCtrl.hibernate();

          // Case C: Unbounded controller
          final unboundedCtrl = DurableAnimationController.unbounded(
            policy: DurabilityPolicy.reset,
            value: 10.0,
            duration: const Duration(milliseconds: 500),
          );
          expect(unboundedCtrl.value, equals(10.0));
          unboundedCtrl.wake(vsyncRef!);
          unboundedCtrl.animateTo(50.0);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(unboundedCtrl.value, greaterThan(20.0));

          unboundedCtrl.hibernate();
          expect(unboundedCtrl.value, equals(10.0),
              reason:
                  'Unbounded controller with reset policy must reset to initial value');
          unboundedCtrl.hibernate();

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        'Reset Defect 4: Duration mutations during active state revert to initialDuration upon dormancy',
        (WidgetTester tester) async {
          late DurableAnimationController controller;
          TickerProvider? vsyncRef;

          controller = DurableAnimationController(
            policy: DurabilityPolicy.reset,
            duration: const Duration(milliseconds: 500),
            reverseDuration: const Duration(milliseconds: 700),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: composed.vsync((context, via, vsync) {
                vsyncRef = vsync;
                return const SizedBox.shrink();
              }),
            ),
          );

          expect(vsyncRef, isNotNull);
          controller.wake(vsyncRef!);

          // Mutate durations in active state
          controller.duration = const Duration(seconds: 10);
          controller.reverseDuration = const Duration(seconds: 15);
          expect(controller.duration, equals(const Duration(seconds: 10)));
          expect(
              controller.reverseDuration, equals(const Duration(seconds: 15)));

          // Under DurabilityPolicy.reset (frozen: false), deactivation reverts to initial durations
          controller.hibernate();
          expect(
              controller.duration, equals(const Duration(milliseconds: 500)));
          expect(controller.reverseDuration,
              equals(const Duration(milliseconds: 700)));

          // Waking up also provisions engine with initial durations
          controller.wake(vsyncRef!);
          expect(
              controller.duration, equals(const Duration(milliseconds: 500)));
          expect(controller.reverseDuration,
              equals(const Duration(milliseconds: 700)));

          controller.hibernate();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        'Reset Defect 5: Reactive widget lifecycle integration via controller.animate mount/unmount/remount',
        (WidgetTester tester) async {
          final showWhat = WhatController<bool>(true);
          final controller = DurableAnimationController(
            policy: DurabilityPolicy.reset,
            duration: const Duration(milliseconds: 1000),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: composed((context, via) {
                  if (via(showWhat.what)) {
                    return composed.animate(
                      controller,
                      (context, via, ctrl) =>
                          Text('Tick: ${ctrl.value.toStringAsFixed(2)}'),
                    );
                  }
                  return const Text('Unmounted');
                }),
              ),
            ),
          );

          // 1. Initial mounted state
          expect(controller.isActive, isTrue);
          expect(controller.isAnimating, isFalse);
          expect(find.text('Tick: 0.00'), findsOneWidget);

          // 2. Start repeat animation
          controller.repeat(reverse: true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(controller.isAnimating, isTrue);
          expect(find.text('Tick: 0.30'), findsOneWidget);

          // 3. Unmount widget subtree
          showWhat.data = false;
          await tester.pumpAndSettle();

          expect(find.text('Unmounted'), findsOneWidget);
          expect(controller.isDormant, isTrue);
          expect(controller.isAnimating, isFalse);
          expect(controller.value, equals(0.0),
              reason: 'Unmounting must reset controller value to 0.0');

          // 4. Remount widget subtree
          showWhat.data = true;
          await tester.pumpAndSettle();

          // Must be mounted, idle at 0.00, NOT animating
          expect(find.text('Tick: 0.00'), findsOneWidget);
          expect(controller.isActive, isTrue);
          expect(controller.isAnimating, isFalse,
              reason: 'Remount must NOT ghost animate');

          // 5. User plays again -> runs cleanly from 0.00
          controller.repeat(reverse: true);
          await tester.pump();
          expect(controller.isAnimating, isTrue);
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('Tick: 0.20'), findsOneWidget);

          controller.hibernate();
        },
      );
    });
  });
}
