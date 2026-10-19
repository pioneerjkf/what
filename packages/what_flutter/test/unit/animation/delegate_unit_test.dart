// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/src/animation/durable/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exhaustive Dormant Animation Delegate Combinatorial Test Suite', () {
    // =========================================================================
    // Category A: Chained & Thrashing Operations in Dormant State
    // =========================================================================
    group('Category A: Chained & Thrashing Operations in Dormant', () {
      test(
          'TC-A1: forward() followed immediately by reverse() overrides correctly',
          () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        controller.forward();
        expect(controller.status, equals(AnimationStatus.forward));

        controller.reverse();
        expect(controller.status, equals(AnimationStatus.reverse));
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
      });

      test('TC-A2: repeat(reverse: true) followed by stop() cancels completely',
          () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        controller.repeat(reverse: true);
        expect(controller.isAnimating, isTrue);

        controller.stop();
        expect(controller.isAnimating, isFalse);
        expect(controller.status, equals(AnimationStatus.dismissed));

        controller.hibernate();
      });

      test('TC-A3: animateTo() chained calls preserve last target and curve',
          () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        controller.animateTo(0.8, curve: Curves.easeIn);
        controller.animateTo(0.2,
            curve: Curves.bounceOut,
            duration: const Duration(milliseconds: 500));

        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.forward));

        controller.hibernate();
      });

      test('TC-A4: forward() followed by value= cancels staged motion to idle',
          () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        controller.forward();
        expect(controller.isAnimating, isTrue);

        controller.value = 0.5;
        expect(controller.isAnimating, isFalse);
        expect(controller.value, equals(0.5));
        expect(controller.status, equals(AnimationStatus.dismissed));

        controller.hibernate();
      });

      test(
          'TC-A5: repeat() followed by reset() resets value to lowerBound and cancels motion',
          () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        controller.value = 0.7;
        controller.repeat();
        expect(controller.isAnimating, isTrue);

        controller.reset();
        expect(controller.value, equals(0.0));
        expect(controller.isAnimating, isFalse);
        expect(controller.status, equals(AnimationStatus.dismissed));

        controller.hibernate();
      });

      test('TC-A6: toggle() thrashing flips direction correctly', () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        // Initially at 0.0 (dismissed) -> toggle aims forward
        controller.toggle();
        expect(controller.status, equals(AnimationStatus.forward));

        // Toggle again -> aims reverse
        controller.toggle();
        expect(controller.status, equals(AnimationStatus.reverse));

        // Toggle again -> aims forward
        controller.toggle();
        expect(controller.status, equals(AnimationStatus.forward));

        // Toggle again -> aims reverse
        controller.toggle();
        expect(controller.status, equals(AnimationStatus.reverse));

        controller.hibernate();
      });

      test(
          'TC-A7: fling(velocity: -2.0) then animateWith(simulation) overrides cleanly',
          () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        controller.fling(velocity: -2.0);
        expect(controller.status, equals(AnimationStatus.reverse));

        controller.animateWith(GravitySimulation(9.8, 0.0, 1.0, 0.0));
        expect(controller.status, equals(AnimationStatus.forward));
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
      });
    });

    // =========================================================================
    // Category B: Dormant State Virtualization Accuracy
    // =========================================================================
    group('Category B: Dormant State Virtualization Accuracy', () {
      test('TC-B1: forward() virtual state properties', () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        controller.forward();
        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.forward));
        expect(controller.isForwardOrCompleted, isTrue);
        expect(controller.isDismissed, isFalse);
        expect(controller.isCompleted, isFalse);

        controller.hibernate();
      });

      test('TC-B2: reverse() virtual state properties', () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        controller.reverse();
        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.reverse));
        expect(controller.isForwardOrCompleted, isFalse);
        expect(controller.isDismissed, isFalse);
        expect(controller.isCompleted, isFalse);

        controller.hibernate();
      });

      test('TC-B3: value == upperBound and reverse() sets isCompleted to false',
          () {
        final controller = DurableAnimationController(
          value: 1.0,
          duration: const Duration(seconds: 1),
        );

        expect(controller.status, equals(AnimationStatus.completed));
        expect(controller.isCompleted, isTrue);

        controller.reverse();
        expect(controller.status, equals(AnimationStatus.reverse));
        expect(controller.isCompleted, isFalse);
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
      });

      test('TC-B4: value == lowerBound and forward() sets isDismissed to false',
          () {
        final controller = DurableAnimationController(
          value: 0.0,
          duration: const Duration(seconds: 1),
        );

        expect(controller.status, equals(AnimationStatus.dismissed));
        expect(controller.isDismissed, isTrue);

        controller.forward();
        expect(controller.status, equals(AnimationStatus.forward));
        expect(controller.isDismissed, isFalse);
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
      });

      test('TC-B5: animateTo() vs animateBack() status evaluation', () {
        final controller = DurableAnimationController(
          value: 0.5,
          duration: const Duration(seconds: 1),
        );

        controller.animateTo(0.9);
        expect(controller.status, equals(AnimationStatus.forward));

        controller.animateBack(0.1);
        expect(controller.status, equals(AnimationStatus.reverse));

        controller.hibernate();
      });

      test('TC-B6: stop() at intermediate position restores dismissed status',
          () {
        final controller = DurableAnimationController(
          value: 0.5,
          duration: const Duration(seconds: 1),
        );

        controller.forward();
        expect(controller.status, equals(AnimationStatus.forward));

        controller.stop();
        expect(controller.isAnimating, isFalse);
        expect(controller.status, equals(AnimationStatus.dismissed));

        controller.hibernate();
      });
    });

    // =========================================================================
    // Category C: Dormant -> Active Transition & Motion Resumption
    // =========================================================================
    group('Category C: Dormant -> Active Transition & Motion Resumption', () {
      testWidgets(
          'TC-C1: Staged forward() when already at upperBound does not restart from 0',
          (WidgetTester tester) async {
        late DurableAnimationController controller;

        controller = DurableAnimationController(
          value: 1.0,
          duration: const Duration(milliseconds: 300),
        );

        controller.forward();

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, equals(1.0));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'TC-C2: Staged reverse() when already at lowerBound does not restart from 1',
          (WidgetTester tester) async {
        late DurableAnimationController controller;

        controller = DurableAnimationController(
          value: 0.0,
          duration: const Duration(milliseconds: 300),
        );

        controller.reverse();

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, equals(0.0));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'TC-C3: Staged animateTo(target) with custom curve and duration',
          (WidgetTester tester) async {
        late DurableAnimationController controller;

        controller = DurableAnimationController(
          value: 0.0,
          duration: const Duration(seconds: 1),
        );

        controller.animateTo(0.6,
            duration: const Duration(milliseconds: 500), curve: Curves.linear);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump(const Duration(milliseconds: 250));
        expect(controller.value, closeTo(0.3, 0.05));

        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.value, closeTo(0.6, 0.02));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('TC-C7: Staged idle mounts without auto-starting animation',
          (WidgetTester tester) async {
        late DurableAnimationController controller;

        controller = DurableAnimationController(
          value: 0.42,
          duration: const Duration(seconds: 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.isAnimating, isFalse);
        expect(controller.value, equals(0.42));

        await tester.pump(const Duration(milliseconds: 200));
        expect(controller.value, equals(0.42));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // Category D: CatchUp Time Compensation Math & Boundary Cases
    // =========================================================================
    group('Category D: CatchUp Time Compensation Math & Boundary Cases', () {
      testWidgets(
          'TC-D1: Zero-elapsed time compensation does not alter value or throw',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );

        controller.forward();

        // 0ms elapsed
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, equals(0.0));
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('TC-D2: Micro-elapsed time (10us) does not destabilize value',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );

        controller.forward();

        // 10 microseconds elapsed
        currentTime = currentTime.add(const Duration(microseconds: 10));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, closeTo(0.0, 0.001));
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'TC-D3: Exact duration match settles cleanly at destination bound',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );

        controller.forward();

        // Exactly 1000ms elapsed
        currentTime = currentTime.add(const Duration(seconds: 1));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, equals(1.0));
        expect(controller.status, equals(AnimationStatus.completed));
        expect(controller.isCompleted, isTrue);

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'TC-D4: Over-duration (200% elapsed) settles at bound without overshoot',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );

        controller.forward();

        // 2000ms elapsed (2x duration)
        currentTime = currentTime.add(const Duration(seconds: 2));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, equals(1.0));
        expect(controller.status, equals(AnimationStatus.completed));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('TC-D9: Negative coordinate bounds ([-100.0, -10.0])',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          lowerBound: -100.0,
          upperBound: -10.0,
          value: -100.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );

        controller.forward();

        // 500ms elapsed -> progress is 50% of range (-100 to -10 = 90 range -> 45 delta -> -55.0)
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, closeTo(-55.0, 0.5));
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('TC-D10: Unbounded coordinate space with animateTo()',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController.unbounded(
          policy: DurabilityPolicy.catchUp,
          value: 100.0,
          duration: const Duration(seconds: 2),
          clock: () => currentTime,
        );

        controller.animateTo(500.0);

        // 1 second elapsed -> 50% progress between 100.0 and 500.0 = 300.0
        currentTime = currentTime.add(const Duration(seconds: 1));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, closeTo(300.0, 1.0));
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'TC-D11: Zero-duration animation settles safely without division by zero',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: Duration.zero,
          clock: () => currentTime,
        );

        controller.forward();

        currentTime = currentTime.add(const Duration(milliseconds: 500));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, isNot(isNaN));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // Category E: Round-Trip & Flapping Stress Tests
    // =========================================================================
    group('Category E: Round-Trip & Flapping Stress Tests', () {
      testWidgets('TC-E1: 30 rapid dormant/active cycles preserve integrity',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        TickerProvider? vsyncRef;

        controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
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
        controller.forward();

        for (int i = 0; i < 30; i++) {
          controller.hibernate();
          expect(controller.isActive, isFalse);
          controller.wake(vsyncRef!);
          expect(controller.isActive, isTrue);
        }

        expect(controller.isAnimating, isTrue);

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('TC-E3: DurabilityPolicy.reset resets value on deactivation',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        TickerProvider? vsyncRef;

        controller = DurableAnimationController(
          policy: DurabilityPolicy.reset,
          value: 0.0,
          duration: const Duration(seconds: 1),
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
        controller.value = 0.8;
        expect(controller.value, equals(0.8));

        controller.hibernate();
        expect(controller.value, equals(0.0));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // Category F: Notification & Reentrancy Guarantees
    // =========================================================================
    group('Category F: Notification & Reentrancy Guarantees', () {
      test(
          'TC-F1: Dormant Zero-Notification Guarantee for value, duration, reset',
          () {
        final controller = DurableAnimationController(
          value: 0.2,
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 150),
        );

        int notifyCount = 0;
        controller.view.addListener(() => notifyCount++);

        controller.value = 0.7;
        controller.duration = const Duration(milliseconds: 600);
        controller.reverseDuration = const Duration(milliseconds: 400);
        controller.reset();

        expect(notifyCount, equals(0));

        controller.hibernate();
      });

      test('TC-F2: Dormant Status Notification Guarantee', () {
        final controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );

        final statuses = <AnimationStatus>[];
        controller.view.addStatusListener((s) => statuses.add(s));

        controller.forward();
        expect(statuses, equals([AnimationStatus.forward]));

        controller.reverse();
        expect(statuses,
            equals([AnimationStatus.forward, AnimationStatus.reverse]));

        controller.hibernate();
      });

      test('TC-F3: Re-entrant status listener calling stop() while dormant',
          () {
        final controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );

        controller.view.addStatusListener((s) {
          if (s == AnimationStatus.forward) {
            controller.stop();
          }
        });

        expect(() => controller.forward(), returnsNormally);
        expect(controller.isAnimating, isFalse);

        controller.hibernate();
      });
    });
  });
}
