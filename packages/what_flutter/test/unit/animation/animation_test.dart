// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what_flutter/src/animation/durable/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DurableAnimationController Exhaustive Member & Case Tests', () {
    // =========================================================================
    // 1. Constructors & Property Defaults
    // =========================================================================
    group('1. Constructors & Constraints', () {
      testWidgets('default bounded constructor initializes correctly',
          (WidgetTester tester) async {
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                debugLabel: 'test_label',
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.lowerBound, equals(0.0));
        expect(controller.upperBound, equals(1.0));
        expect(controller.value, equals(0.0));
        expect(controller.duration, isNull);
        expect(controller.reverseDuration, isNull);
        expect(controller.debugLabel, equals('test_label'));
        expect(controller.animationBehavior, equals(AnimationBehavior.normal));

        controller.hibernate();
      });

      testWidgets('asserts if upperBound < lowerBound',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              expect(
                () => DurableAnimationController(
                  lowerBound: 1.0,
                  upperBound: 0.0,
                ),
                throwsAssertionError,
              );
              return const SizedBox.shrink();
            }),
          ),
        );
      });

      testWidgets('unbounded constructor initializes infinite bounds',
          (WidgetTester tester) async {
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController.unbounded(
                value: 42.0,
                duration: const Duration(milliseconds: 200),
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.lowerBound, equals(double.negativeInfinity));
        expect(controller.upperBound, equals(double.infinity));
        expect(controller.value, equals(42.0));
        expect(controller.duration, equals(const Duration(milliseconds: 200)));
        expect(
            controller.animationBehavior, equals(AnimationBehavior.preserve));

        controller.hibernate();
      });
    });

    // =========================================================================
    // 2. Dormant State All Members (Pre-activation Staging Verification)
    // =========================================================================
    group('2. Dormant State All Members', () {
      test('all driving methods stage motion gracefully in dormant state', () {
        final controller = DurableAnimationController(
          duration: const Duration(seconds: 1),
        );

        // Value mutation and query work without throwing
        controller.value = 0.5;
        expect(controller.value, equals(0.5));
        expect(controller.velocity, equals(0.0));
        expect(controller.lastElapsedDuration, isNull);
        expect(controller.view, isA<Animation<double>>());

        // Driving methods stage motion without throwing StateError
        expect(() => controller.forward(), returnsNormally);
        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.forward));

        expect(() => controller.reverse(), returnsNormally);
        expect(controller.status, equals(AnimationStatus.reverse));

        expect(() => controller.toggle(), returnsNormally);
        expect(() => controller.animateTo(0.8), returnsNormally);
        expect(() => controller.animateBack(0.2), returnsNormally);
        expect(() => controller.repeat(), returnsNormally);
        expect(() => controller.fling(), returnsNormally);

        // reset and stop cancel staged motion
        controller.reset();
        expect(controller.isAnimating, isFalse);
        expect(controller.value, equals(0.0));
      });

      test('reads and writes dormant properties safely without notifications',
          () {
        final controller = DurableAnimationController(
          value: 0.2,
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 150),
        );
        int notifyCount = 0;

        controller.view.addListener(() => notifyCount++);

        // Check initial dormant getters
        expect(controller.observe().isActive, isFalse);
        expect(controller.isActive, isFalse);
        expect(controller.view, isA<Animation<double>>());
        expect(controller.value, equals(0.2));
        expect(controller.duration, equals(const Duration(milliseconds: 300)));
        expect(controller.reverseDuration,
            equals(const Duration(milliseconds: 150)));
        expect(controller.velocity, equals(0.0));
        expect(controller.lastElapsedDuration, isNull);
        expect(controller.isAnimating, isFalse);
        expect(controller.status, equals(AnimationStatus.dismissed));
        expect(controller.isDismissed, isTrue);
        expect(controller.isCompleted, isFalse);
        expect(controller.isForwardOrCompleted, isFalse);

        // Value setter in dormant state (zero-notification invariant)
        controller.value = 0.7;
        expect(controller.value, equals(0.7));
        expect(notifyCount, equals(0));

        // Duration setter in dormant state (zero-notification invariant)
        controller.duration = const Duration(milliseconds: 600);
        expect(controller.duration, equals(const Duration(milliseconds: 600)));
        expect(notifyCount, equals(0));

        // ReverseDuration setter in dormant state (zero-notification invariant)
        controller.reverseDuration = const Duration(milliseconds: 400);
        expect(controller.reverseDuration,
            equals(const Duration(milliseconds: 400)));
        expect(notifyCount, equals(0));

        // Reset in dormant state (zero-notification invariant)
        controller.reset();
        expect(controller.value, equals(0.0));
        expect(notifyCount, equals(0));

        // Stop in dormant state (safe no-op)
        controller.stop();
        expect(controller.isAnimating, isFalse);

        // toStringDetails in dormant state
        expect(controller.toStringDetails(), contains('dormant'));

        controller.hibernate();
      });

      test('status computation in dormant state for bounds', () {
        final controller = DurableAnimationController(
          lowerBound: 0.0,
          upperBound: 1.0,
        );

        // Value == lowerBound -> dismissed
        controller.value = 0.0;
        expect(controller.status, equals(AnimationStatus.dismissed));
        expect(controller.isDismissed, isTrue);

        // Value == upperBound -> completed
        controller.value = 1.0;
        expect(controller.status, equals(AnimationStatus.completed));
        expect(controller.isCompleted, isTrue);

        // In between -> dismissed by default in dormant
        controller.value = 0.5;
        expect(controller.status, equals(AnimationStatus.dismissed));

        controller.hibernate();
      });

      testWidgets(
          'all driving methods stage motion gracefully in dormant state',
          (WidgetTester tester) async {
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 300),
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(() => controller.forward(), returnsNormally);
        expect(() => controller.reverse(), returnsNormally);
        expect(() => controller.toggle(), returnsNormally);
        expect(() => controller.animateTo(0.8), returnsNormally);
        expect(() => controller.animateBack(0.2), returnsNormally);
        expect(() => controller.repeat(), returnsNormally);
        expect(() => controller.fling(), returnsNormally);
        expect(
          () => controller.animateWith(GravitySimulation(9.8, 0.0, 1.0, 0.0)),
          returnsNormally,
        );
        expect(
          () =>
              controller.animateBackWith(GravitySimulation(9.8, 1.0, 0.0, 0.0)),
          returnsNormally,
        );

        controller.hibernate();
      });
    });

    // =========================================================================
    // 3. Active State Member Behavior (All Driving Methods & Engine Operations)
    // =========================================================================
    group('3. Active State Driving Methods & Ticker Simulation', () {
      testWidgets('forward & reverse drive animation properly when active',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 200),
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.isActive, isTrue);
        expect(controller.view, isNotNull);

        // Test forward()
        final forwardFuture = controller.forward();
        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.forward));

        await tester.pumpAndSettle();
        await forwardFuture;

        expect(controller.value, equals(1.0));
        expect(controller.status, equals(AnimationStatus.completed));
        expect(controller.isCompleted, isTrue);

        // Test reverse()
        final reverseFuture = controller.reverse();
        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.reverse));

        await tester.pumpAndSettle();
        await reverseFuture;

        expect(controller.value, equals(0.0));
        expect(controller.status, equals(AnimationStatus.dismissed));

        // Test forward(from: 0.5)
        controller.forward(from: 0.5);
        expect(controller.value, equals(0.5));
        await tester.pumpAndSettle();
        expect(controller.value, equals(1.0));

        terminal.deactivate();
        controller.hibernate();
      });

      testWidgets('toggle switches direction correctly',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 100),
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        // Initial state is dismissed -> toggle moves forward
        controller.toggle();
        expect(controller.status, equals(AnimationStatus.forward));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.completed));

        // State is completed -> toggle moves in reverse
        controller.toggle();
        expect(controller.status, equals(AnimationStatus.reverse));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.dismissed));

        terminal.deactivate();
        controller.hibernate();
      });

      testWidgets('animateTo and animateBack drive towards target values',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 200),
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        controller.animateTo(0.6, curve: Curves.easeIn);
        await tester.pumpAndSettle();
        expect(controller.value, closeTo(0.6, 0.01));

        controller.animateBack(0.2, curve: Curves.easeOut);
        await tester.pumpAndSettle();
        expect(controller.value, closeTo(0.2, 0.01));

        terminal.deactivate();
        controller.hibernate();
      });

      testWidgets('repeat drives cyclic animation',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 100),
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        controller.repeat(count: 2, reverse: true);
        expect(controller.isAnimating, isTrue);

        await tester.pump(const Duration(milliseconds: 100)); // Forward pass
        await tester.pump(const Duration(milliseconds: 100)); // Reverse pass
        await tester.pumpAndSettle();

        expect(controller.isAnimating, isFalse);

        terminal.deactivate();
        controller.hibernate();
      });

      testWidgets('fling drives physics simulation',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 200),
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        controller.fling(velocity: 2.0);
        expect(controller.isAnimating, isTrue);

        await tester.pumpAndSettle();
        expect(controller.value, equals(1.0));

        terminal.deactivate();
        controller.hibernate();
      });

      testWidgets('animateWith and animateBackWith drive custom simulation',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 200),
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        final sim = FrictionSimulation(0.1, 0.0, 1.0);
        controller.animateWith(sim);
        expect(controller.isAnimating, isTrue);
        await tester.pumpAndSettle();

        final backSim = FrictionSimulation(0.1, 1.0, -1.0);
        controller.animateBackWith(backSim);
        expect(controller.isAnimating, isTrue);
        await tester.pumpAndSettle();

        terminal.deactivate();
        controller.hibernate();
      });

      testWidgets(
          'DurableAnimationController pauses and resumes SpringSimulation from frozen progress without restarting from 0.0',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late TickerProvider savedVsync;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                duration: const Duration(seconds: 2),
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        final spring = SpringSimulation(
          const SpringDescription(mass: 1.0, stiffness: 20.0, damping: 10.0),
          0.0,
          1.0,
          4.0,
        );

        controller.animateWith(spring);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final progressBeforeDetach = controller.value;
        expect(progressBeforeDetach, greaterThan(0.2));

        // Detach / Go dormant
        controller.hibernate();
        await tester.pump();
        expect(controller.value, equals(progressBeforeDetach));

        // Remount / Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // Must NOT restart from 0.0! Value must stay at progressBeforeDetach
        expect(controller.value, closeTo(progressBeforeDetach, 0.05));
        expect(controller.value, isNot(closeTo(0.0, 0.05)));

        // Advance 100ms
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, isNot(closeTo(0.0, 0.05)));

        await tester.pumpAndSettle();
        expect(controller.value, closeTo(1.0, 0.02));

        controller.hibernate();
      });

      testWidgets(
          'DurableAnimationController compensates wall-clock time for SpringSimulation during dormancy',
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
                duration: const Duration(seconds: 2),
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        final spring = SpringSimulation(
          const SpringDescription(mass: 1.0, stiffness: 20.0, damping: 10.0),
          0.0,
          1.0,
          4.0,
        );

        controller.animateWith(spring);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final progressBeforeDetach = controller.value;
        expect(progressBeforeDetach, greaterThan(0.2));

        // Detach / Go dormant
        controller.hibernate();
        await tester.pump();

        // Advance wall-clock by 300ms while dormant
        currentTime = currentTime.add(const Duration(milliseconds: 300));

        // Remount / Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // At 200ms + 300ms = 500ms total elapsed, value should match spring.x(0.5)
        final expectedValueAt500ms = spring.x(0.5);
        expect(controller.value, closeTo(expectedValueAt500ms, 0.05));

        await tester.pumpAndSettle();
        expect(controller.value, closeTo(1.0, 0.02));

        controller.hibernate();
      });

      testWidgets(
          'DurableAnimationController.unbounded compensates wall-clock time and remaining duration for animateTo across dormancy',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        late DurableAnimationController controller;
        late TickerProvider savedVsync;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController.unbounded(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                clock: () => currentTime,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // Start animateTo 5000.0 with 5 seconds duration
        controller.animateTo(
          5000.0,
          duration: const Duration(seconds: 5),
          curve: Curves.linear,
        );
        await tester.pump();
        await tester
            .pump(const Duration(seconds: 1)); // 1s elapsed -> value ~1000.0

        expect(controller.value, closeTo(1000.0, 50.0));

        // Detach / Dormant
        controller.hibernate();
        await tester.pump();

        // Advance wall-clock by 2 seconds while dormant (total 3s elapsed)
        currentTime = currentTime.add(const Duration(seconds: 2));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // At 1s + 2s = 3s total elapsed on a 5s linear animation to 5000.0,
        // value should be ~3000.0 (3/5 of 5000)
        expect(controller.value, closeTo(3000.0, 50.0));

        // Pump 1 second more (total 4s) -> value should be ~4000.0
        await tester.pump(const Duration(seconds: 1));
        expect(controller.value, closeTo(4000.0, 50.0));

        // Pump remaining and settle -> reaches 5000.0
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(controller.value, closeTo(5000.0, 1.0));

        controller.hibernate();
      });
    });

    // =========================================================================
    // 4. State Continuity across Dormant ??Active Transitions
    // =========================================================================
    group('4. State Continuity & Lifecycle Transitions', () {
      testWidgets(
          'preserves parameters staged in dormant state upon activation',
          (WidgetTester tester) async {
        final controller = DurableAnimationController();

        // Stage parameters while dormant
        controller.value = 0.4;
        controller.duration = const Duration(milliseconds: 400);
        controller.reverseDuration = const Duration(milliseconds: 250);

        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        // Activate by providing vsync
        controller.wake(vsync);

        // Verify active engine inherited staged parameters
        expect(controller.isActive, isTrue);
        expect(controller.value, equals(0.4));
        expect(controller.duration, equals(const Duration(milliseconds: 400)));
        expect(controller.reverseDuration,
            equals(const Duration(milliseconds: 250)));

        controller.hibernate();
      });
    });

    // =========================================================================
    // 5. Broadcaster vs Single Provider Strategy
    // =========================================================================
    group('5. Broadcast Strategy', () {
      testWidgets('broadcast=true allows multiple subscribers without error',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal1;
        late RawWhatTerminal<double> terminal2;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 100),
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        terminal1 = RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal2 = RawWhatTerminal(controller.observe(), onInvalidated: () {});

        terminal1.activate();
        terminal2.activate();
        await tester.pump();

        expect(terminal1.isActive, isTrue);
        expect(terminal2.isActive, isTrue);

        terminal1.deactivate();
        terminal2.deactivate();

        controller.hibernate();
      });
    });

    // =========================================================================
    // 6. Utility & Mixin Methods (drive, toStringDetails)
    // =========================================================================
    group('6. Transformations & Debugging', () {
      testWidgets('drive method creates transformed Animation',
          (WidgetTester tester) async {
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                value: 0.5,
              )..wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        final tween = Tween<double>(begin: 0.0, end: 200.0);
        final Animation<double> drivenAnimation = controller.drive(tween);

        expect(drivenAnimation.value, equals(100.0));

        controller.hibernate();
      });

      testWidgets('toStringDetails provides diagnostic info in active state',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                debugLabel: 'my_anim',
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        final details = controller.toStringDetails();
        expect(details, isNotEmpty);

        terminal.deactivate();
        controller.hibernate();
      });
    });

    // =========================================================================
    // 7. VsyncDerivedFrozenAnimationController & Lifecycle Tests
    // =========================================================================
    group('7. Durable Lifecycle & Frozen Mode Tests', () {
      testWidgets('constructors initialize bounded and unbounded correctly',
          (WidgetTester tester) async {
        final bounded = DurableAnimationController(
          debugLabel: 'derived_frozen_bounded',
        );

        expect(bounded.lowerBound, equals(0.0));
        expect(bounded.upperBound, equals(1.0));
        expect(bounded.value, equals(0.0));
        expect(bounded.debugLabel, equals('derived_frozen_bounded'));

        final unbounded = DurableAnimationController.unbounded(
          value: 15.0,
        );

        expect(unbounded.lowerBound, equals(double.negativeInfinity));
        expect(unbounded.upperBound, equals(double.infinity));
        expect(unbounded.value, equals(15.0));

        expect(bounded, isA<DurableAnimationController>());
        expect(bounded.policy, equals(DurabilityPolicy.resume));
        expect(unbounded, isA<DurableAnimationController>());
        expect(unbounded.policy, equals(DurabilityPolicy.resume));

        bounded.hibernate();
        unbounded.hibernate();
      });

      testWidgets('asserts if upperBound < lowerBound on frozen controller',
          (WidgetTester tester) async {
        expect(
          () => DurableAnimationController(
            lowerBound: 10.0,
            upperBound: 5.0,
          ),
          throwsAssertionError,
        );
      });

      testWidgets('remains dormant until vsync emits TickerProvider',
          (WidgetTester tester) async {
        final controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );

        int notifyCount = 0;
        controller.view.addListener(() => notifyCount++);

        // Reads/writes in dormant state
        expect(controller.isAnimating, isFalse);
        expect(controller.status, equals(AnimationStatus.dismissed));
        expect(controller.view, isA<Animation<double>>());

        // In dormant state, forward stages motion gracefully
        expect(() => controller.forward(), returnsNormally);
        expect(controller.isAnimating, isTrue);

        controller.hibernate();
      });

      testWidgets(
          'activates seamlessly when vsync emits TickerProvider in reactive topology',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 300),
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();

              // Emit vsync
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();

        expect(controller.isActive, isTrue);
        expect(controller.view, isNotNull);

        // Drive animation
        final forwardFuture = controller.forward();
        await tester.pumpAndSettle();
        await forwardFuture;
        expect(controller.value, equals(1.0));
        expect(controller.isCompleted, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'reverts to dormant preserving value when vsync is cleared and reactivates',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 300),
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.forward();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final progress = controller.value;
        expect(progress, greaterThan(0.0));

        // Simulate widget unmount / vsync empty
        controller.hibernate();
        await tester.pump();

        // Should be dormant with preserved progress value
        expect(controller.value, equals(progress));
        expect(() => controller.forward(), returnsNormally);

        // Re-mount / re-emit vsync
        controller.wake(savedVsync);
        await tester.pump();

        // Active again from preserved progress
        expect(controller.value, equals(progress));
        final forwardFuture = controller.forward();
        await tester.pumpAndSettle();
        await forwardFuture;
        expect(controller.value, equals(1.0));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'resync and couple methods dynamically update DurableAnimationController',
          (WidgetTester tester) async {
        late TickerProvider vsync1;
        late TickerProvider vsync2;
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                composed.vsync((context, via, v) {
                  vsync1 = v;
                  return const SizedBox.shrink();
                }),
                composed.vsync((context, via, v) {
                  vsync2 = v;
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        );

        controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        )..wake(vsync1);
        await tester.pump();

        expect(controller.isActive, isTrue);

        // Test dynamic attach/detach handover
        controller.attachVsync(vsync2);
        controller.detachVsync(vsync1);
        await tester.pump();
        expect(controller.isActive, isTrue);

        // Test hibernate
        controller.hibernate();
        await tester.pump();
        expect(controller.isActive, isFalse);

        // Re-attach vsync2
        controller.wake(vsync2);
        await tester.pump();
        expect(controller.isActive, isTrue);

        final forwardFuture = controller.forward();
        await tester.pumpAndSettle();
        await forwardFuture;
        expect(controller.value, equals(1.0));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'dispose() while active immediately halts underlying engine and stops listener dispatches',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        int listenerCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 500),
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        controller.view.addListener(() {
          listenerCalls++;
        });

        // Start forward
        controller.forward();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.isAnimating, isTrue);
        final countBeforeDispose = listenerCalls;
        expect(countBeforeDispose, greaterThan(0));

        // Dispose controller directly while active and ticking
        controller.hibernate();

        // Pump further frames
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        // After dispose(), no further listener callbacks should fire
        expect(listenerCalls, equals(countBeforeDispose));

        terminal.deactivate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'frozen: false resets progress to initial value upon deactivation',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.reset,
                value: 0.1,
                duration: const Duration(milliseconds: 300),
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.forward();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(controller.value, greaterThan(0.1));

        // Simulate widget unmount / vsync empty
        controller.hibernate();
        await tester.pump();

        // In non-frozen mode, value resets back to initial value (0.1)
        expect(controller.value, equals(0.1));

        // Re-mount vsync
        controller.wake(savedVsync);
        await tester.pump();

        // Starts fresh from initial value (0.1)
        expect(controller.value, equals(0.1));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // 8. DurableAnimationController Lifecycle & Members Tests
    // =========================================================================
    group('8. DurableAnimationController Dynamic Coupling & Lifecycle', () {
      testWidgets('constructors initialize bounded and unbounded correctly',
          (WidgetTester tester) async {
        final bounded = DurableAnimationController(
          debugLabel: 'derived_bounded',
          value: 0.2,
          duration: const Duration(milliseconds: 200),
          reverseDuration: const Duration(milliseconds: 150),
        );

        expect(bounded.lowerBound, equals(0.0));
        expect(bounded.upperBound, equals(1.0));
        expect(bounded.value, equals(0.2));
        expect(bounded.debugLabel, equals('derived_bounded'));
        expect(bounded.duration, equals(const Duration(milliseconds: 200)));
        expect(
            bounded.reverseDuration, equals(const Duration(milliseconds: 150)));

        final unbounded = DurableAnimationController.unbounded(
          value: 10.0,
        );

        expect(unbounded.lowerBound, equals(double.negativeInfinity));
        expect(unbounded.upperBound, equals(double.infinity));
        expect(unbounded.value, equals(10.0));

        bounded.hibernate();
        unbounded.hibernate();
      });

      testWidgets('stages motion when driving forward before activated',
          (WidgetTester tester) async {
        final controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );

        expect(controller.isActive, isFalse);
        expect(() => controller.forward(), returnsNormally);
        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.forward));

        controller.hibernate();
      });

      testWidgets('activates and drives animations seamlessly when subscribed',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 300),
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();

        expect(controller.isActive, isTrue);
        expect(controller.view, isNotNull);

        final forwardFuture = controller.forward();
        await tester.pumpAndSettle();
        await forwardFuture;

        expect(controller.value, equals(1.0));
        expect(controller.isCompleted, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'resync(TickerProvider) connects a new What into coupler and updates active engine',
          (WidgetTester tester) async {
        late TickerProvider vsync1;
        late TickerProvider vsync2;
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                composed.vsync((context, via, v) {
                  vsync1 = v;
                  return const SizedBox.shrink();
                }),
                composed.vsync((context, via, v) {
                  vsync2 = v;
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        );

        controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        )..wake(vsync1);

        terminal = RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();
        await tester.pump();

        expect(controller.isActive, isTrue);

        // Re-attach with vsync2
        controller.attachVsync(vsync2);
        controller.detachVsync(vsync1);
        await tester.pump();

        expect(controller.isActive, isTrue);

        // Forward works cleanly with resynced provider
        final forwardFuture = controller.forward();
        await tester.pumpAndSettle();
        await forwardFuture;
        expect(controller.value, equals(1.0));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('attachVsync() updates TickerProvider directly',
          (WidgetTester tester) async {
        late TickerProvider vsync1;
        late TickerProvider vsync2;
        late DurableAnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                composed.vsync((context, via, v) {
                  vsync1 = v;
                  return const SizedBox.shrink();
                }),
                composed.vsync((context, via, v) {
                  vsync2 = v;
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        );

        controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        )..wake(vsync1);
        await tester.pump();

        expect(controller.isActive, isTrue);

        // Re-attach to vsync2 directly
        controller.attachVsync(vsync2);
        controller.detachVsync(vsync1);
        await tester.pump();

        expect(controller.isActive, isTrue);

        final forwardFuture = controller.forward();
        await tester.pumpAndSettle();
        await forwardFuture;
        expect(controller.value, equals(1.0));

        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'dispose() while active immediately disposes underlying engine and stops ticking',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller = DurableAnimationController(
                duration: const Duration(milliseconds: 500),
              )..wake(vsync);
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              return const SizedBox.shrink();
            }),
          ),
        );

        // Start animation forward
        controller.forward();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.isAnimating, isTrue);

        // Dispose controller directly while active and ticking
        controller.hibernate();

        // If engine wasn't disposed, it would continue ticking and notify listeners on disposed controller or leak ticker
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        terminal.deactivate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // 9. WhatTickerProviderDriveExtension (vsync.drive) Tests
    // =========================================================================
    group('9. WhatTickerProviderDriveExtension (vsync.drive)', () {
      testWidgets('drives reactive What values on every animation frame tick',
          (WidgetTester tester) async {
        final List<double> recordedValues = [];
        late What<double> drivenWhat;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              drivenWhat = vsync.drive<double>(
                (elapsed) => elapsed.inMilliseconds.toDouble(),
                initialValue: -1.0,
              );
              return composed((context, via) {
                final val = via.state(drivenWhat).dataOrNull;
                if (val != null) recordedValues.add(val);
                return Text('$val');
              });
            }),
          ),
        );

        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(recordedValues.isNotEmpty, isTrue);
        expect(recordedValues.last, greaterThan(0.0));

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'repeat(reverse: true) ping-pong in reverse phase preserves reverse direction across dormancy',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                value: 0.0,
                duration: const Duration(milliseconds: 200),
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.repeat(reverse: true);

        // Advance: forward (0.0 -> 1.0, 200ms) + reverse (1.0 -> 0.5, 100ms)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.status, equals(AnimationStatus.reverse));
        final valueBeforeDormant = controller.value;
        expect(valueBeforeDormant, closeTo(0.50, 0.1));

        // Detach (Dormant)
        controller.hibernate();
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.reverse));
        expect(controller.value, equals(valueBeforeDormant));

        // Re-attach vsync
        controller.wake(savedVsync);
        await tester.pump();

        // Advance 50ms: must continue in reverse direction towards 0.0, NOT flip to forward
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.status, equals(AnimationStatus.reverse));
        expect(controller.value, lessThan(valueBeforeDormant));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // 10. DurableAnimationController Lifecycle & Time Compensation Tests
    // =========================================================================
    group('10. DurableAnimationController Lifecycle & Time Compensation', () {
      testWidgets('constructors initialize bounded and unbounded correctly',
          (WidgetTester tester) async {
        final bounded = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          debugLabel: 'catch_up_bounded',
          value: 0.25,
          duration: const Duration(milliseconds: 400),
        );

        expect(bounded.lowerBound, equals(0.0));
        expect(bounded.upperBound, equals(1.0));
        expect(bounded.value, equals(0.25));
        expect(bounded.debugLabel, equals('catch_up_bounded'));
        expect(bounded.policy, equals(DurabilityPolicy.catchUp));

        final unbounded = DurableAnimationController.unbounded(
          policy: DurabilityPolicy.catchUp,
          value: 50.0,
        );

        expect(unbounded.lowerBound, equals(double.negativeInfinity));
        expect(unbounded.upperBound, equals(double.infinity));
        expect(unbounded.value, equals(50.0));

        bounded.hibernate();
        unbounded.hibernate();
      });

      testWidgets('idle controller does not advance value during dormant gap',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.4,
                duration: const Duration(milliseconds: 300),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        expect(controller.value, equals(0.4));
        expect(controller.isAnimating, isFalse);

        // Deactivate vsync
        controller.hibernate();
        await tester.pump();

        // Advance simulated clock by 5 seconds
        currentTime = currentTime.add(const Duration(seconds: 5));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // Stays at 0.4 because it was idle
        expect(controller.value, equals(0.4));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('repeat() advances loop phase accurately across dormant gap',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(milliseconds: 200),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.repeat();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.isAnimating, isTrue);

        // Deactivate vsync while repeating
        controller.hibernate();
        await tester.pump();

        // Advance clock by 350ms (1 full loop + 150ms = 0.75 progress)
        currentTime = currentTime.add(const Duration(milliseconds: 350));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // Automatically resumed repeat motion and value advanced to ~0.75
        expect(controller.value, closeTo(0.75, 0.02));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'forward() advances progress and auto-resumes across dormant gap',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 2),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.forward();
        await tester.pump(const Duration(milliseconds: 50));

        // Deactivate vsync while moving forward
        controller.hibernate();
        await tester.pump();

        // Advance clock by 1 second (50% progress on a 2-second animation)
        currentTime = currentTime.add(const Duration(seconds: 1));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // Value advanced by 1s (approx 0.5 + initial pump) and is still animating
        expect(controller.value, closeTo(0.525, 0.05));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'forward() overshoot settles at upperBound and enters idle state without resuming',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(milliseconds: 500),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.forward();
        await tester.pump(const Duration(milliseconds: 100));

        // Deactivate
        controller.hibernate();
        await tester.pump();

        // Advance clock by 5 seconds (greatly exceeds remaining 400ms duration)
        currentTime = currentTime.add(const Duration(seconds: 5));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // Must clamp at upperBound (1.0) and remain stopped (isAnimating == false)
        expect(controller.value, equals(1.0));
        expect(controller.isAnimating, isFalse);
        expect(controller.status, equals(AnimationStatus.completed));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'reverse() overshoot settles at lowerBound and enters idle state',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.8,
                duration: const Duration(milliseconds: 400),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.reverse();
        await tester.pump(const Duration(milliseconds: 50));

        // Deactivate
        controller.hibernate();
        await tester.pump();

        // Advance clock by 2 seconds
        currentTime = currentTime.add(const Duration(seconds: 2));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // Must clamp at lowerBound (0.0) and remain stopped
        expect(controller.value, equals(0.0));
        expect(controller.isAnimating, isFalse);
        expect(controller.status, equals(AnimationStatus.dismissed));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Manual state modification (value/reset) during dormant gap disables catch-up',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 1),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.forward();
        await tester.pump(const Duration(milliseconds: 100));

        // Deactivate
        controller.hibernate();
        await tester.pump();

        // Developer manually intervenes while dormant
        controller.value = 0.25;

        // Advance clock by 10 seconds
        currentTime = currentTime.add(const Duration(seconds: 10));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // Value must stay at manual value (0.25) and NOT catch-up or resume
        expect(controller.value, equals(0.25));
        expect(controller.isAnimating, isFalse);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('animateTo() catches up and respects target bound',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 2),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.animateTo(0.6, duration: const Duration(seconds: 1));
        await tester.pump();

        // Deactivate
        controller.hibernate();
        await tester.pump();

        // Advance clock by 500ms (50% of the 1-second target duration = 0.3)
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        expect(controller.value, closeTo(0.3, 0.05));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'repeat(reverse: true) ping-pong calculates phase correctly into descending phase',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(milliseconds: 200),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.repeat(reverse: true);
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.isAnimating, isTrue);

        // Deactivate vsync (controller reaches 150ms = 0.75 forward progress)
        controller.hibernate();
        await tester.pump();

        // Advance clock by 300ms (200ms forward to 1.0 + 100ms reverse descending to 0.50)
        currentTime = currentTime.add(const Duration(milliseconds: 300));

        // Reactivate
        controller.wake(savedVsync);

        // 300ms into the 400ms cycle puts the controller at 0.50 in the descending phase
        expect(controller.value, closeTo(0.50, 0.05));

        await tester.pump();
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'repeat(count: N) terminates when loop count is exceeded during dormant gap',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(milliseconds: 200),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        // Repeat exactly 2 times (total duration = 400ms)
        controller.repeat(count: 2, period: const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 50));

        // Deactivate vsync
        controller.hibernate();
        await tester.pump();

        // Advance clock by 800ms (4 loops > count of 2)
        currentTime = currentTime.add(const Duration(milliseconds: 800));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        // Must settle at max (1.0) and be stopped (isAnimating == false)
        expect(controller.value, equals(1.0));
        expect(controller.isAnimating, isFalse);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'animateTo() with non-linear Curve accurately calculates transformed value',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 1),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        // Use quadratic easeIn (t=0.5 -> curve value = 0.25)
        controller.animateTo(1.0,
            duration: const Duration(seconds: 1), curve: Curves.easeIn);
        await tester.pump();

        // Deactivate
        controller.hibernate();
        await tester.pump();

        // Advance clock by 500ms (t = 0.5)
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Reactivate
        controller.wake(savedVsync);

        // Value must match Curves.easeIn.transform(0.5) = 0.25, NOT linear 0.50
        final expectedValue = Curves.easeIn.transform(0.5);
        expect(controller.value, closeTo(expectedValue, 0.02));

        await tester.pump();
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'AnimationStatus listeners fire reliably during dormant catch-up completion',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        final statusLog = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(milliseconds: 500),
                clock: () => currentTime,
              );
              controller.view.addStatusListener((s) => statusLog.add(s));

              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.forward();
        await tester.pump(const Duration(milliseconds: 100));

        // Deactivate
        controller.hibernate();
        await tester.pump();

        // Advance clock past completion (2 seconds)
        currentTime = currentTime.add(const Duration(seconds: 2));

        // Reactivate
        controller.wake(savedVsync);
        await tester.pump();

        expect(controller.value, equals(1.0));
        expect(controller.isCompleted, isTrue);
        expect(statusLog, contains(AnimationStatus.completed));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial Test 1: Massive 100,000 loop cycles maintain precision without drift',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(milliseconds: 200),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.repeat();
        await tester.pump();

        // Deactivate vsync (at 0.0)
        controller.hibernate();
        await tester.pump();

        // Advance clock by 100,000 loops + 70ms (0.35 fraction of 200ms period)
        // Total gap = 100,000 * 200ms + 70ms = 20,000,070ms
        currentTime = currentTime.add(const Duration(milliseconds: 20000070));

        // Reactivate
        controller.wake(savedVsync);

        // Expected: (0.0 + 0.35) % 1.0 = 0.35
        expect(controller.value, closeTo(0.35, 0.02));
        expect(controller.value, greaterThanOrEqualTo(0.0));
        expect(controller.value, lessThanOrEqualTo(1.0));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial Test 2: NTP / Clock rewind (negative elapsed duration) is safely ignored',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.4,
                duration: const Duration(seconds: 1),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.forward();
        await tester.pump();

        // Deactivate vsync
        controller.hibernate();
        await tester.pump();

        // System clock jumped BACKWARDS by 1 hour (NTP sync / time-zone glitch)
        currentTime = currentTime.subtract(const Duration(hours: 1));

        // Reactivate
        controller.wake(savedVsync);

        // Value must NOT rewind or produce NaN/negative values; remains at preserved value
        expect(controller.value, greaterThanOrEqualTo(0.4));
        expect(controller.value, lessThanOrEqualTo(1.0));
        expect(controller.value.isNaN, isFalse);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial Test 3: Rapid reentrant deactivation/reactivation accumulates correctly',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.0,
                duration: const Duration(seconds: 1),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.forward();
        await tester.pump();

        // Cycle 1: Deactivate at T0 (0.0)
        controller.hibernate();
        await tester.pump();

        // Gap 1: 200ms
        currentTime = currentTime.add(const Duration(milliseconds: 200));

        // Reactivate at T1, immediately deactivate without ticking
        controller.wake(savedVsync);
        controller.hibernate();

        // Gap 2: 300ms
        currentTime = currentTime.add(const Duration(milliseconds: 300));

        // Final Reactivate at T2
        controller.wake(savedVsync);

        // Total advance = Gap 1 (0.2) + Gap 2 (0.3) = 0.50
        expect(controller.value, closeTo(0.50, 0.05));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial Test 4: Custom repeat range (min: 0.3, max: 0.7) strictly clamps within bounds',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.3,
                duration: const Duration(milliseconds: 200),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        // Repeat inside sub-range [0.3, 0.7] with period 200ms (range = 0.4)
        controller.repeat(
            min: 0.3, max: 0.7, period: const Duration(milliseconds: 200));
        await tester.pump();

        // Deactivate vsync
        controller.hibernate();
        await tester.pump();

        // Advance clock by 300ms (1.5 periods = 0.5 * 0.4 = 0.2 offset)
        currentTime = currentTime.add(const Duration(milliseconds: 300));

        // Reactivate
        controller.wake(savedVsync);

        // Value must stay strictly within [0.3, 0.7]
        expect(controller.value, greaterThanOrEqualTo(0.3));
        expect(controller.value, lessThanOrEqualTo(0.7));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial Test 5: fling(velocity: -1.0) reverse physics catches up towards lowerBound',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late RawWhatTerminal<double> terminal;
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller = DurableAnimationController(
                policy: DurabilityPolicy.catchUp,
                value: 0.8,
                duration: const Duration(seconds: 1),
                clock: () => currentTime,
              );
              terminal =
                  RawWhatTerminal(controller.observe(), onInvalidated: () {});
              terminal.activate();
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump();
        controller.fling(velocity: -1.0);
        await tester.pump();

        // Deactivate vsync
        controller.hibernate();
        await tester.pump();

        // Advance clock by 500ms
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Reactivate
        controller.wake(savedVsync);

        // Negative velocity fling must catch up towards lowerBound (decreasing value)
        expect(controller.value, lessThan(0.8));
        expect(controller.value, greaterThanOrEqualTo(0.0));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Dormant Motion Staging 1: forward() ordered before vsync catches up on late mount',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        // 1. Create controller while dormant (no vsync provided yet)
        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // 2. Order forward() while completely dormant!
        controller.forward();
        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.forward));

        // 3. 300ms passes in the real world before widget mounts
        currentTime = currentTime.add(const Duration(milliseconds: 300));

        // 4. Widget mounts and supplies vsync
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // 5. Must immediately catch up to 0.30 and be actively ticking
        expect(controller.isActive, isTrue);
        expect(controller.value, closeTo(0.30, 0.02));
        expect(controller.isAnimating, isTrue);

        await tester.pump(const Duration(milliseconds: 200));
        expect(controller.value, closeTo(0.50, 0.05));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Dormant Motion Staging 2: repeat() ordered before vsync catches up loop phase on late mount',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        // 1. Create while dormant
        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(milliseconds: 200),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // 2. Order repeat() while dormant
        controller.repeat();
        expect(controller.isAnimating, isTrue);

        // 3. 350ms passes (1 full 200ms loop + 150ms = 0.75 progress)
        currentTime = currentTime.add(const Duration(milliseconds: 350));

        // 4. Widget mounts
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // 5. Must catch up directly to 0.75
        expect(controller.isActive, isTrue);
        expect(controller.value, closeTo(0.75, 0.05));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Dormant Motion Staging 3: animateTo() with Curve catches up accurately on late mount',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        // 1. Create while dormant
        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // 2. Order animateTo(0.8, curve: Curves.easeIn)
        controller.animateTo(0.8,
            duration: const Duration(seconds: 1), curve: Curves.easeIn);
        expect(controller.isAnimating, isTrue);

        // 3. 500ms passes (t = 0.5 -> easeIn(0.5) = 0.25 -> 0.25 * 0.8 = 0.20)
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // 4. Mount
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // 5. Matches curve calculation
        final expected = 0.8 * Curves.easeIn.transform(0.5);
        expect(controller.isActive, isTrue);
        expect(controller.value, closeTo(expected, 0.02));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Dormant Motion Staging 4: stop() or reset() while dormant cancels staged motion',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // Order forward, then cancel via stop()
        controller.forward();
        expect(controller.isAnimating, isTrue);
        controller.stop();
        expect(controller.isAnimating, isFalse);

        // 10 seconds pass
        currentTime = currentTime.add(const Duration(seconds: 10));

        // Mount
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // Must remain stopped at 0.0 without any catch-up jump or animation
        expect(controller.value, equals(0.0));
        expect(controller.isAnimating, isFalse);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Google Stress Test 1: Vsync Hot-Swapping (couple) mid-flight maintains catch-up trajectory',
          (WidgetTester tester) async {
        late TickerProvider vsyncA;
        late TickerProvider vsyncB;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        controller.forward();
        currentTime = currentTime.add(const Duration(milliseconds: 200));

        // Mount with Vsync A
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              vsyncA = vsync;
              controller.wake(vsyncA);
              return const SizedBox.shrink();
            }),
          ),
        );
        expect(controller.value, closeTo(0.20, 0.02));

        // Mount new widget with distinct key providing Vsync B
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync(
              key: const ValueKey('widget_b'),
              (context, via, vsync) {
                vsyncB = vsync;
                controller.attachVsync(vsyncB);
                controller.detachVsync(vsyncA);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.value, closeTo(0.50, 0.05));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Google Stress Test 2: Dormant rapid toggle() direction thrashing flips reliably',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.2,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // 5 consecutive toggles while dormant (odd flips -> reverse direction)
        controller.toggle();
        controller.toggle();
        controller.toggle();
        controller.toggle();
        controller.toggle();

        expect(controller.status, equals(AnimationStatus.forward));

        currentTime = currentTime.add(const Duration(milliseconds: 300));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // Advanced forward from 0.2 + 0.3 = 0.50
        expect(controller.value, closeTo(0.50, 0.05));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Google Stress Test 3: animateBack() Non-linear Curve interpolation across dormant gap',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.8,
          duration: const Duration(seconds: 2),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // Animate backward from 0.8 to 0.2 using easeInOut
        controller.animateBack(
          0.2,
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );

        // 1 second passes (t = 0.5 -> easeInOut(0.5) = 0.50)
        currentTime = currentTime.add(const Duration(seconds: 1));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // Expected: 0.8 - 0.5 * (0.8 - 0.2) = 0.50
        expect(controller.value, closeTo(0.50, 0.05));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Google Stress Test 4: repeat(reverse: true, count: 5/6) lands on exact odd/even boundary',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(milliseconds: 100),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // Odd count: 5 loops (ends at upperBound 1.0)
        controller.repeat(
            reverse: true, count: 5, period: const Duration(milliseconds: 100));

        // Advance 10 seconds (well past the 500ms total run time)
        currentTime = currentTime.add(const Duration(seconds: 10));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, equals(1.0));
        expect(controller.isAnimating, isFalse);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Google Stress Test 5: Dynamic mutation of duration during dormancy is respected',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        controller.forward();

        // While dormant, developer doubles the duration to 2 seconds
        controller.duration = const Duration(seconds: 2);

        // 500ms passes (500ms on 2s duration = 0.25 progress)
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // Progress is 0.25 (reflecting the mutated 2s duration), NOT 0.50
        expect(controller.value, closeTo(0.25, 0.02));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Google Stress Test 6: Multi-subscriber listener churn across dormancy transitions',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        var valueNotificationCount = 0;
        var statusNotificationCount = 0;

        for (var i = 0; i < 20; i++) {
          controller.view.addListener(() => valueNotificationCount++);
          controller.view.addStatusListener((_) => statusNotificationCount++);
        }

        controller.forward();
        currentTime = currentTime.add(const Duration(milliseconds: 200));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // Advance 1 frame so active engine ticks and notifies listeners
        await tester.pump(const Duration(milliseconds: 50));

        expect(valueNotificationCount, greaterThan(0));
        expect(statusNotificationCount, greaterThan(0));
        expect(controller.value, closeTo(0.25, 0.05));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Google Stress Test 7: drive(Tween) pipeline updates reactively across catch-up',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        final drivenAnimation =
            controller.drive(IntTween(begin: 100, end: 500));

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

        // At 0.50 progress, IntTween(100, 500) gives 300
        expect(controller.value, closeTo(0.50, 0.05));
        expect(drivenAnimation.value, closeTo(300, 20));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Google Stress Test 8: Zero-Duration animation settles safely without division by zero',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: Duration.zero,
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        controller.forward();
        currentTime = currentTime.add(const Duration(seconds: 5));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value.isNaN, isFalse);
        expect(controller.value.isInfinite, isFalse);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'DurableAnimationController: forward() staged before mount starts from 0.0 without time jump',
          (WidgetTester tester) async {
        late TickerProvider savedVsync;

        // 1. Create controller while dormant
        final controller = DurableAnimationController(
          value: 0.0,
          duration: const Duration(milliseconds: 500),
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // 2. Order forward() before widget mounts
        controller.forward();
        expect(controller.isAnimating, isTrue);
        expect(controller.status, equals(AnimationStatus.forward));

        // 3. Mount widget providing vsync
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // 4. Starts from 0.0 (preserved position, NO catch-up jump!)
        expect(controller.value, equals(0.0));
        expect(controller.isAnimating, isTrue);

        // 5. Ticks smoothly forward
        await tester.pump(const Duration(milliseconds: 250));
        expect(controller.value, closeTo(0.50, 0.05));

        // 6. Unmount mid-flight -> freezes at 0.50
        controller.hibernate();
        await tester.pump();
        expect(controller.value, closeTo(0.50, 0.05));

        // 7. Remount -> resumes from 0.50 smoothly
        controller.wake(savedVsync);
        await tester.pump();

        expect(controller.value, closeTo(0.50, 0.05));
        expect(controller.isAnimating, isTrue);

        await tester.pumpAndSettle();
        expect(controller.value, equals(1.0));
        expect(controller.isCompleted, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // 11. Google & Flutter Engine Team Adversarial Verification Suite
    // =========================================================================
    group('11. Google & Flutter Engine Team Adversarial Verification Suite',
        () {
      testWidgets(
          'Adversarial 1: valueWhat.map and What.combine2 reactive pipeline across dormancy',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 2),
          clock: () => currentTime,
        );

        final multiplier = What.constant(100.0);
        final controllerWhat = controller.observe();
        final curvedWhat =
            computed((via) => Curves.easeInOut.transform(via(controllerWhat)));
        final combinedWhat = computed(
          (via) => via(curvedWhat) * via(multiplier),
        );

        final log = <double>[];
        final controllerTerminal =
            RawWhatTerminal(controllerWhat, onInvalidated: () {});
        controllerTerminal.activate();
        final terminal = RawWhatTerminal(combinedWhat, onInvalidated: () {
          log.add(combinedWhat.peek);
        });
        terminal.activate();

        controller.forward();
        // 1 second elapsed (50% progress -> easeInOut(0.5) is exactly 0.5)
        currentTime = currentTime.add(const Duration(seconds: 1));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump();

        expect(controller.value, closeTo(0.50, 0.01));
        expect(terminal.snapshot.data, closeTo(50.0, 1.0));

        terminal.deactivate();
        controllerTerminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 2: Deep 4-level composite hierarchy (CurvedAnimation -> ReverseAnimation -> Tween.animate)',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 2),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        final curved =
            CurvedAnimation(parent: controller.view, curve: Curves.linear);
        final reversed = ReverseAnimation(curved);
        final tweenAnimation =
            IntTween(begin: 1000, end: 2000).animate(reversed);

        controller.forward();
        // 50% elapsed
        currentTime = currentTime.add(const Duration(seconds: 1));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, closeTo(0.50, 0.01));
        expect(curved.value, closeTo(0.50, 0.01));
        expect(reversed.value, closeTo(0.50, 0.01));
        expect(tweenAnimation.value, equals(1500));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 3: Microsecond-interval flapping deactivations loop (20 rapid cycles)',
          (WidgetTester tester) async {
        late TickerProvider savedVsync;
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 10),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        controller.forward();

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // Run 20 rapid unmount-timeAdvance-remount cycles
        for (var i = 0; i < 20; i++) {
          controller.hibernate();
          await tester.pump();
          currentTime = currentTime.add(const Duration(milliseconds: 100));
          controller.wake(savedVsync);
          await tester.pump(const Duration(milliseconds: 16));
        }

        // 20 * 100ms = 2.0s + frame ticks -> ~2.3s -> progress ~0.23
        expect(controller.value, greaterThan(0.20));
        expect(controller.value, lessThan(0.40));
        expect(controller.isAnimating, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 4: DurableAnimationController with frozen: false resets on deactivation',
          (WidgetTester tester) async {
        late TickerProvider savedVsync;

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.reset,
          value: 0.2,
          duration: const Duration(milliseconds: 500),
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        controller.forward();

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              savedVsync = vsync;
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump(const Duration(milliseconds: 250));
        expect(controller.value, greaterThan(0.5));

        // Unmount -> with frozen: false, it resets back to initial value (0.2)
        controller.hibernate();
        await tester.pump();
        expect(controller.value, equals(0.2));
        expect(controller.isAnimating, isFalse);

        // Remount -> starts fresh and idle at 0.2 without ghost animations
        controller.wake(savedVsync);
        await tester.pump();
        expect(controller.value, equals(0.2));
        expect(controller.isAnimating, isFalse);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 5: DurableAnimationController.unbounded extreme coordinate space',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController.unbounded(
          policy: DurabilityPolicy.catchUp,
          value: -1000.0,
          duration: const Duration(seconds: 10),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // Animate from -1000.0 to 5000.0 (span: 6000.0)
        controller.animateTo(5000.0);

        // Advance 5 seconds (50% progress)
        currentTime = currentTime.add(const Duration(seconds: 5));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // -1000 + 0.5 * 6000 = 2000.0
        expect(controller.value, closeTo(2000.0, 50.0));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 5b: DurableAnimationController.unbounded multi-cycle mount/unmount flapping with easeInOutCubic',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController.unbounded(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 6),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.observe(), onInvalidated: () {});
        terminal.activate();

        // Animate from 0.0 to 5000.0 over 6s with easeInOutCubic
        controller.animateTo(
          5000.0,
          duration: const Duration(seconds: 6),
          curve: Curves.easeInOutCubic,
        );

        // Mount cycle 1:
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Unmount 1: advance clock by 500ms (total wall time = 1.0s)
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Mount cycle 2:
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Unmount 2: advance clock by 500ms (total wall time = 2.0s)
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Mount cycle 3:
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // Unmount 3: advance clock by 500ms (total wall time = 3.0s)
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
        currentTime = currentTime.add(const Duration(milliseconds: 500));

        // At total time ~3.05s (approx 50% of 6.0s across frame quantization ticks):
        // 0.0 + 5000.0 * 0.5 = 2500.0 (with slight frame tick delta ~84.0).
        // It must NOT be prematurely completed at 5000.0!
        expect(controller.value, closeTo(2500.0, 100.0));
        expect(controller.isAnimating, isTrue);

        // Mount cycle 4: remount and let it run to completion
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );
        currentTime = currentTime.add(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 3));

        expect(controller.value, closeTo(5000.0, 0.1));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 6: Dynamic resync and couple hot-swapping during active physics simulation',
          (WidgetTester tester) async {
        late TickerProvider vsync1;
        late TickerProvider vsync2;

        final controller = DurableAnimationController(
          duration: const Duration(seconds: 2),
        );
        final terminal =
            RawWhatTerminal(controller.view.toWhat(), onInvalidated: () {});
        terminal.activate();

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                composed.vsync(
                  key: const ValueKey('widget_1'),
                  (context, via, vsync) {
                    vsync1 = vsync;
                    controller.wake(vsync1);
                    return const SizedBox.shrink();
                  },
                ),
                composed.vsync(
                  key: const ValueKey('widget_2'),
                  (context, via, vsync) {
                    vsync2 = vsync;
                    controller.attachVsync(vsync2);
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        );

        // Start spring simulation
        final spring = SpringSimulation(
          const SpringDescription(mass: 1.0, stiffness: 100.0, damping: 10.0),
          0.0,
          1.0,
          0.0,
        );
        controller.animateWith(spring);
        await tester.pump(const Duration(milliseconds: 50));

        // Hot swap vsync mid-simulation

        controller.detachVsync(vsync1);
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.isAnimating, isTrue);

        await tester.pumpAndSettle();
        expect(controller.value, closeTo(1.0, 0.05));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 7: Re-entrant self-mutating listener during catch-up completion notification',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.view.toWhat(), onInvalidated: () {});
        terminal.activate();

        var listenerBFired = false;
        void listenerB(AnimationStatus s) {
          listenerBFired = true;
        }

        late void Function(AnimationStatus) listenerA;
        listenerA = (AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            controller.view.removeStatusListener(listenerA);
            controller.view.addStatusListener(listenerB);
          }
        };

        controller.view.addStatusListener(listenerA);
        controller.forward();

        // Advance past completion
        currentTime = currentTime.add(const Duration(seconds: 5));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, equals(1.0));
        expect(controller.isCompleted, isTrue);

        // Verify listenerB was safely registered dynamically and fires on next status change
        expect(listenerBFired, isFalse);
        controller.reverse();
        await tester.pump();
        expect(listenerBFired, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 8: Staged fling(velocity: -3.0) drives to lowerBound across dormant gap',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 1.0,
          duration: const Duration(seconds: 2),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.view.toWhat(), onInvalidated: () {});
        terminal.activate();

        // Staged negative fling while dormant
        controller.fling(velocity: -3.0);
        expect(controller.status, equals(AnimationStatus.reverse));

        currentTime = currentTime.add(const Duration(seconds: 3));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controller.value, equals(0.0));
        expect(controller.isDismissed, isTrue);

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 9: Multi-controller dual clock harmonic synchronization',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        // Controller 1: 10s period
        final controllerFast = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 10),
          clock: () => currentTime,
        );
        // Controller 2: 20s period
        final controllerSlow = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 20),
          clock: () => currentTime,
        );

        final terminalFast =
            RawWhatTerminal(controllerFast.view.toWhat(), onInvalidated: () {});
        final terminalSlow =
            RawWhatTerminal(controllerSlow.view.toWhat(), onInvalidated: () {});
        terminalFast.activate();
        terminalSlow.activate();

        controllerFast.repeat();
        controllerSlow.repeat();

        // 15 seconds elapsed while dormant:
        // Fast (10s period): 1.5 cycles -> progress = 0.50
        // Slow (20s period): 0.75 cycles -> progress = 0.75
        currentTime = currentTime.add(const Duration(seconds: 15));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controllerFast.wake(vsync);
              controllerSlow.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(controllerFast.value, closeTo(0.50, 0.01));
        expect(controllerSlow.value, closeTo(0.75, 0.01));

        terminalFast.deactivate();
        terminalSlow.deactivate();
        controllerFast.hibernate();
        controllerSlow.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'Adversarial 10: Late animateBackWith simulation evaluates smoothly',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.9,
          duration: const Duration(seconds: 1),
          clock: () => currentTime,
        );
        final terminal =
            RawWhatTerminal(controller.view.toWhat(), onInvalidated: () {});
        terminal.activate();

        final sim = FrictionSimulation(0.1, 0.9, -0.5);
        controller.animateBackWith(sim);
        expect(controller.status, equals(AnimationStatus.reverse));

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              controller.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        await tester.pump(const Duration(milliseconds: 200));
        expect(controller.value, lessThan(0.9));

        terminal.deactivate();
        controller.hibernate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    group('DurableAnimationController detachVsync & Lifecycle Tests', () {
      testWidgets('isActive reflects active state and false when dormant',
          (WidgetTester tester) async {
        late DurableAnimationController frozenCtrl;
        late DurableAnimationController catchUpCtrl;

        frozenCtrl = DurableAnimationController();
        catchUpCtrl = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
        );

        // Initially dormant -> isActive is false
        expect(frozenCtrl.isActive, isFalse);
        expect(catchUpCtrl.isActive, isFalse);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, vsync) {
              frozenCtrl.wake(vsync);
              catchUpCtrl.wake(vsync);
              return const SizedBox.shrink();
            }),
          ),
        );

        // Active -> isActive is true
        expect(frozenCtrl.isActive, isTrue);
        expect(catchUpCtrl.isActive, isTrue);

        // Hibernated -> isActive is false
        frozenCtrl.hibernate();
        catchUpCtrl.hibernate();
        expect(frozenCtrl.isActive, isFalse);
        expect(catchUpCtrl.isActive, isFalse);

        // Durable controllers do not have dispose()
      });

      testWidgets(
          'detachVsync only detaches and hibernates if provided vsync matches current vsync',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late TickerProvider vsyncA;
        late TickerProvider vsyncB;

        controller = DurableAnimationController();

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                composed.vsync((context, via, vsync) {
                  vsyncA = vsync;
                  return const SizedBox.shrink();
                }),
                composed.vsync((context, via, vsync) {
                  vsyncB = vsync;
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        );

        controller.wake(vsyncA);
        expect(controller.isActive, isTrue);

        // detachVsync with mismatched vsyncB -> returns false, stays active
        final detachedWrong = controller.detachVsync(vsyncB);
        expect(detachedWrong, isFalse);
        expect(controller.isActive, isTrue);

        // detachVsync with matching vsyncA -> returns true, becomes dormant
        final detachedCorrect = controller.detachVsync(vsyncA);
        expect(detachedCorrect, isTrue);
        expect(controller.isActive, isFalse);

        // Repeated detachVsync when already dormant -> returns false
        expect(controller.detachVsync(vsyncA), isFalse);

        controller.hibernate();
      });

      testWidgets('WhatDurableAnimationControllerProxy forwards detachVsync',
          (WidgetTester tester) async {
        late DurableAnimationController controller;
        late TickerProvider vsyncA;
        late TickerProvider vsyncB;

        controller = DurableAnimationController();
        final ctrlWhat = What.constant(controller);

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                composed.vsync((context, via, vsync) {
                  vsyncA = vsync;
                  return const SizedBox.shrink();
                }),
                composed.vsync((context, via, vsync) {
                  vsyncB = vsync;
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        );

        expect(ctrlWhat.peek.isActive, isFalse);

        ctrlWhat.peek.wake(vsyncA);
        expect(ctrlWhat.peek.isActive, isTrue);

        expect(ctrlWhat.peek.detachVsync(vsyncB), isFalse);
        expect(ctrlWhat.peek.detachVsync(vsyncA), isTrue);
        expect(ctrlWhat.peek.isActive, isFalse);
      });
    });

    group(
        '12. Dormant Zero-Notification Invariant & Build Reentrancy Regression Tests',
        () {
      test(
          'Dormant Zero-Notification Guarantee: duration, reverseDuration, value, and reset emit 0 notifications while dormant',
          () {
        final frozen = DurableAnimationController(
          value: 0.2,
          duration: const Duration(seconds: 1),
        );
        final catchUp = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.2,
          duration: const Duration(seconds: 1),
        );

        var frozenNotifications = 0;
        var catchUpNotifications = 0;

        frozen.view.addListener(() => frozenNotifications++);
        catchUp.view.addListener(() => catchUpNotifications++);

        // 1. Mutate durations
        frozen.duration = const Duration(seconds: 5);
        frozen.reverseDuration = const Duration(seconds: 4);
        catchUp.duration = const Duration(seconds: 5);
        catchUp.reverseDuration = const Duration(seconds: 4);

        // 2. Mutate values
        frozen.value = 0.8;
        catchUp.value = 0.8;

        // 3. Reset
        frozen.reset();
        catchUp.reset();

        // Must remain exactly 0 notifications while dormant
        expect(frozenNotifications, equals(0));
        expect(catchUpNotifications, equals(0));

        expect(frozen.value, equals(0.0));
        expect(catchUp.value, equals(0.0));
        expect(frozen.duration, equals(const Duration(seconds: 5)));
        expect(catchUp.duration, equals(const Duration(seconds: 5)));
      });

      testWidgets(
          'Build-Phase Reentrancy Isolation: vsync.wake with CatchUp in AnimatedBuilder throws ZERO setState errors',
          (WidgetTester tester) async {
        var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

        // 1. Create dormant controller in store and stage repeat motion
        final controller = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 10),
          clock: () => currentTime,
        );
        controller.repeat();

        // 2. Advance time by 3.5 seconds while dormant (progress = 0.35)
        currentTime = currentTime.add(const Duration(milliseconds: 3500));

        // 3. Mount widget with vsync.wake and AnimatedBuilder
        await tester.pumpWidget(
          MaterialApp(
            home: _TestVsyncHostWidget(controller: controller),
          ),
        );

        // 4. Verification: No FlutterError or setState during build was thrown
        expect(tester.takeException(), isNull);
        expect(controller.value, closeTo(0.35, 0.02));
        expect(find.text('Val: 0.35'), findsOneWidget);

        // 5. Subsequent tick advances smoothly
        await tester.pump(const Duration(milliseconds: 500));
        expect(controller.value, closeTo(0.40, 0.02));
      });

      testWidgets(
          'Multi-Cycle Flapping: DurableAnimationController preserves accumulated elapsed time across 5 consecutive mount/unmount cycles during active physics simulation',
          (WidgetTester tester) async {
        final controller = DurableAnimationController(
          value: 0.0,
          duration: const Duration(seconds: 4),
        );

        final spring = SpringSimulation(
          const SpringDescription(mass: 1.0, stiffness: 60.0, damping: 12.0),
          0.0,
          1.0,
          2.0,
          snapToEnd: true,
        );

        controller.animateWith(spring);

        // 1. Run 100ms in active mode
        await tester.pumpWidget(
          MaterialApp(
            home: _TestFrozenVsyncHostWidget(controller: controller),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final val1 = controller.value;
        expect(val1, greaterThan(0.0));

        // 2. Perform 5 rapid unmount & remount flapping cycles with 50ms active runs
        double prevVal = val1;
        for (int cycle = 1; cycle <= 5; cycle++) {
          // Unmount
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 20));

          // Remount
          await tester.pumpWidget(
            MaterialApp(
              home: _TestFrozenVsyncHostWidget(controller: controller),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          // Must monotonically advance along the spring trajectory, NOT reset to 0
          final currentVal = controller.value;
          expect(currentVal, greaterThanOrEqualTo(prevVal),
              reason:
                  'Cycle $cycle: Value $currentVal should advance past $prevVal');
          prevVal = currentVal;
        }

        expect(controller.value, greaterThan(0.5));
      });

      test(
          'DurableAnimationController provides Animation<double> view polymorphically',
          () {
        void acceptStandardAnimation(Animation<double> anim) {
          expect(anim, isA<Animation<double>>());
          expect(anim.value, equals(0.0));
        }

        final frozen = DurableAnimationController();
        final catchUp = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
        );

        expect(frozen, isA<DurableAnimationController>());
        expect(catchUp, isA<DurableAnimationController>());
        expect(frozen.view, isA<Animation<double>>());
        expect(catchUp.view, isA<Animation<double>>());

        acceptStandardAnimation(frozen.view);
        acceptStandardAnimation(catchUp.view);

        frozen.hibernate();
        catchUp.hibernate();
      });
    });
  });
}

base class _TestVsyncHostWidget extends WhatWidget {
  const _TestVsyncHostWidget({required this.controller});
  final DurableAnimationController controller;

  @override
  Widget build(BuildContext context, WhatVia via) {
    return composed.animate(controller, (context, via, ctrl) {
      return Text('Val: ${ctrl.value.toStringAsFixed(2)}');
    });
  }
}

base class _TestFrozenVsyncHostWidget extends WhatWidget {
  const _TestFrozenVsyncHostWidget({required this.controller});
  final DurableAnimationController controller;

  @override
  Widget build(BuildContext context, WhatVia via) {
    return composed.animate(controller, (context, via, ctrl) {
      return Text('Val: ${ctrl.value.toStringAsFixed(2)}');
    });
  }
}
