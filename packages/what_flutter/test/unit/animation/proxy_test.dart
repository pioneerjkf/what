// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/src/animation/durable/testing.dart';

void main() {
  group('DurableAnimationController & Inline Proxy Tests', () {
    testWidgets(
        '1. controller.animate passes DurableAnimationController to builder',
        (tester) async {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );
      DurableAnimationController? observedCtrl;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate(
            controller,
            (context, via, ctrl) {
              observedCtrl = ctrl;
              return Text('Val: ${ctrl.value}');
            },
          ),
        ),
      );

      expect(observedCtrl, isNotNull);
      expect(observedCtrl!.duration, equals(const Duration(milliseconds: 300)));
      expect(find.text('Val: 0.0'), findsOneWidget);

      controller.hibernate();
    });

    testWidgets(
        '2. inline controller forwards state, values, and control commands to target',
        (tester) async {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );
      late DurableAnimationController observedCtrl;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate(
            controller,
            (context, via, ctrl) {
              observedCtrl = ctrl;
              return Text('Val: ${ctrl.value}');
            },
          ),
        ),
      );

      observedCtrl.value = 0.42;
      expect(controller.value, equals(0.42));

      observedCtrl.duration = const Duration(milliseconds: 600);
      expect(controller.duration, equals(const Duration(milliseconds: 600)));

      controller.hibernate();
    });

    testWidgets(
        '3. inline controller manages independent listeners and receives forward updates when active',
        (tester) async {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );
      late DurableAnimationController observedCtrl;
      int customTicks = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate(
            controller,
            (context, via, ctrl) {
              observedCtrl = ctrl;
              return Text('Val: ${ctrl.value}');
            },
          ),
        ),
      );

      observedCtrl.view.addListener(() => customTicks++);

      // Active controller updates notify listener
      controller.value = 0.5;
      expect(customTicks, equals(1));

      controller.hibernate();
    });

    testWidgets(
        '4. unmounting inline widget clears scoped listeners without affecting target controller',
        (tester) async {
      final showWhat = WhatController<bool>(true);
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );
      int scopedTicks = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed(
            (context, via) {
              if (via(showWhat.what)) {
                return composed.animate(
                  controller,
                  (context, via, ctrl) {
                    ctrl.view.addListener(() => scopedTicks++);
                    return Text('Val: ${ctrl.value}');
                  },
                );
              }
              return const Text('Hidden');
            },
          ),
        ),
      );

      expect(controller.isActive, isTrue);

      // Unmount inline widget -> scoped listeners detached and controller hibernated
      showWhat.data = false;
      await tester.pumpAndSettle();

      expect(find.text('Hidden'), findsOneWidget);
      expect(controller.isDormant, isTrue);

      controller.hibernate();
    });

    testWidgets(
        '5. unmounting one inline widget does not affect other widgets or the target',
        (tester) async {
      final showA = WhatController<bool>(true);
      final showB = WhatController<bool>(true);
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              composed(
                (context, via) => via(showA.what)
                    ? composed.animate(
                        controller,
                        (context, via, ctrl) =>
                            Text('A: ${(ctrl.value * 100).toInt()}%'),
                      )
                    : const Text('A: hidden'),
              ),
              composed(
                (context, via) => via(showB.what)
                    ? composed.animate(
                        controller,
                        (context, via, ctrl) =>
                            Text('B: ${(ctrl.value * 100).toInt()}%'),
                      )
                    : const Text('B: hidden'),
              ),
            ],
          ),
        ),
      );

      expect(controller.isActive, isTrue);
      expect(find.text('A: 0%'), findsOneWidget);
      expect(find.text('B: 0%'), findsOneWidget);

      // Mutate value
      controller.value = 0.5;
      await tester.pump();
      expect(find.text('A: 50%'), findsOneWidget);
      expect(find.text('B: 50%'), findsOneWidget);

      // Unmount A
      showA.data = false;
      await tester.pumpAndSettle();

      expect(find.text('A: hidden'), findsOneWidget);
      expect(find.text('B: 50%'), findsOneWidget);
      expect(controller.isActive, isTrue);

      // Mutate value again -> B updates cleanly
      controller.value = 0.8;
      await tester.pump();
      expect(find.text('B: 80%'), findsOneWidget);

      controller.hibernate();
    });

    testWidgets(
        '6. inline widget detaches on unmount and preserves frozen value on remount',
        (tester) async {
      final showWhat = WhatController<bool>(true);
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed(
            (context, via) {
              if (via(showWhat.what)) {
                return composed.animate(
                  controller,
                  (context, via, ctrl) =>
                      Text('Val: ${(ctrl.value * 100).toInt()}%'),
                );
              }
              return const Text('Hidden');
            },
          ),
        ),
      );

      expect(find.text('Val: 0%'), findsOneWidget);

      // Advance value
      controller.value = 0.5;
      await tester.pump();
      expect(find.text('Val: 50%'), findsOneWidget);

      // Unmount inline widget -> hibernates
      showWhat.data = false;
      await tester.pumpAndSettle();

      expect(find.text('Hidden'), findsOneWidget);
      expect(controller.isDormant, isTrue);
      expect(controller.value, equals(0.5)); // Frozen value preserved

      // Remount inline widget -> wakes up from frozen value
      showWhat.data = true;
      await tester.pumpAndSettle();

      expect(find.text('Val: 50%'), findsOneWidget);
      expect(controller.isActive, isTrue);

      controller.hibernate();
    });

    test(
        '7. controller delegates all animation getters, setters, and properties',
        () {
      final vsync = const TestDurableVSync();
      final controller = DurableAnimationController(
        policy: DurabilityPolicy.catchUp,
        duration: const Duration(milliseconds: 400),
        reverseDuration: const Duration(milliseconds: 200),
        lowerBound: 0.1,
        upperBound: 0.9,
        debugLabel: 'test_controller',
        animationBehavior: AnimationBehavior.preserve,
      )..wake(vsync);

      expect(controller.view, isA<Animation<double>>());
      expect(controller.lowerBound, equals(0.1));
      expect(controller.upperBound, equals(0.9));
      expect(controller.debugLabel, equals('test_controller'));
      expect(controller.animationBehavior, equals(AnimationBehavior.preserve));
      expect(controller.duration, equals(const Duration(milliseconds: 400)));
      expect(controller.reverseDuration,
          equals(const Duration(milliseconds: 200)));

      controller.reverseDuration = const Duration(milliseconds: 250);
      expect(controller.reverseDuration,
          equals(const Duration(milliseconds: 250)));

      expect(controller.velocity, equals(0.0));
      expect(controller.lastElapsedDuration, isNull);
      expect(controller.status, equals(AnimationStatus.dismissed));
      expect(controller.isAnimating, isFalse);
      expect(controller.isCompleted, isFalse);
      expect(controller.isDismissed, isTrue);
      expect(controller.isForwardOrCompleted, isFalse);
      expect(controller.isActive, isTrue);
      expect(controller.isDormant, isFalse);

      expect(controller.toStringDetails(), isNotEmpty);

      // Drive Animatable
      final driven = controller.drive(Tween<double>(begin: 0, end: 100));
      expect(driven.value, equals(10.0)); // value is 0.1 (lowerBound) -> 10.0

      // Reset
      controller.value = 0.5;
      expect(controller.value, equals(0.5));
      controller.reset();
      expect(controller.value, equals(0.1));

      // Attach Vsync
      controller.attachVsync(const TestDurableVSync());

      // Hibernate and detachVsync
      controller.hibernate();
      expect(controller.detachVsync(const TestDurableVSync()), isFalse);

      expect(controller.isDormant, isTrue);
    });

    testWidgets(
        '8. controller delegates motion commands (forward, reverse, toggle, animateTo, animateBack, repeat, fling, stop)',
        (tester) async {
      final vsync = const TestDurableVSync();
      final controller = DurableAnimationController(
        policy: DurabilityPolicy.catchUp,
        duration: const Duration(milliseconds: 300),
      )..wake(vsync);

      // forward
      controller.forward();
      expect(controller.isAnimating, isTrue);
      controller.stop();
      expect(controller.isAnimating, isFalse);

      // Set value to 1.0 to test reverse
      controller.value = 1.0;
      controller.reverse();
      expect(controller.isAnimating, isTrue);
      controller.stop();

      // toggle
      controller.value = 0.5;
      controller.toggle();
      expect(controller.isAnimating, isTrue);
      controller.stop();

      // animateTo
      controller.animateTo(0.8, curve: Curves.easeInOut);
      expect(controller.isAnimating, isTrue);
      controller.stop();

      // animateBack (from current value towards 0.2)
      controller.value = 0.9;
      controller.animateBack(0.2, curve: Curves.easeInOut);
      expect(controller.isAnimating, isTrue);
      controller.stop();

      // repeat
      controller.repeat(min: 0.2, max: 0.8, reverse: true);
      expect(controller.isAnimating, isTrue);
      controller.stop();

      // fling
      controller.fling(velocity: 2.0);
      expect(controller.isAnimating, isTrue);
      controller.stop();

      // animateWith & animateBackWith
      final sim = GravitySimulation(100.0, 0.0, 1.0, 0.0);
      controller.animateWith(sim);
      expect(controller.isAnimating, isTrue);
      controller.stop();

      final reverseSim = GravitySimulation(-100.0, 1.0, 0.0, 0.0);
      controller.animateBackWith(reverseSim);
      expect(controller.isAnimating, isTrue);
      controller.stop();

      controller.hibernate();
    });

    test(
        '9. multi-holder vsync attach/detach seamlessly hands over active ticker',
        () {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );
      final vsyncA = TestDurableVSync();
      final vsyncB = TestDurableVSync();

      expect(controller.isActive, isFalse);

      // Attach vsyncA -> activates
      controller.attachVsync(vsyncA);
      expect(controller.isActive, isTrue);

      controller.forward();
      expect(controller.isAnimating, isTrue);

      // Attach vsyncB -> still active with vsyncA
      controller.attachVsync(vsyncB);
      expect(controller.isActive, isTrue);
      expect(controller.isAnimating, isTrue);

      // Detach vsyncA -> hands over to vsyncB, remains animating!
      final detachedA = controller.detachVsync(vsyncA);
      expect(detachedA, isTrue);
      expect(controller.isActive, isTrue);
      expect(controller.isAnimating, isTrue);

      // Detach vsyncB -> no holders left, enters dormant state (hibernated)
      final detachedB = controller.detachVsync(vsyncB);
      expect(detachedB, isTrue);
      expect(controller.isActive, isFalse);
      expect(controller.isDormant, isTrue);
    });

    test('10. multi-holder vsync when non-primary holder detaches first', () {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );
      final vsyncA = TestDurableVSync();
      final vsyncB = TestDurableVSync();

      controller.attachVsync(vsyncA);
      controller.attachVsync(vsyncB);
      controller.forward();
      expect(controller.isAnimating, isTrue);

      // Detach secondary vsyncB first -> vsyncA continues driving
      final detachedB = controller.detachVsync(vsyncB);
      expect(detachedB, isTrue);
      expect(controller.isActive, isTrue);
      expect(controller.isAnimating, isTrue);

      // Detach primary vsyncA -> now all detached, enters dormant state
      final detachedA = controller.detachVsync(vsyncA);
      expect(detachedA, isTrue);
      expect(controller.isActive, isFalse);
      expect(controller.isDormant, isTrue);
    });

    testWidgets(
        '11. multiple inline widgets sharing controller seamlessly hand over when first unmounts',
        (tester) async {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 200),
      );
      final showA = WhatController<bool>(true);
      final showB = WhatController<bool>(true);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              composed(
                (context, via) => via(showA.what)
                    ? composed.animate(
                        controller,
                        (context, via, ctrl) =>
                            Text('A: ${(ctrl.value * 100).toInt()}%'),
                      )
                    : const Text('A: hidden'),
              ),
              composed(
                (context, via) => via(showB.what)
                    ? composed.animate(
                        controller,
                        (context, via, ctrl) =>
                            Text('B: ${(ctrl.value * 100).toInt()}%'),
                      )
                    : const Text('B: hidden'),
              ),
            ],
          ),
        ),
      );

      expect(controller.isActive, isTrue);
      expect(find.text('A: 0%'), findsOneWidget);
      expect(find.text('B: 0%'), findsOneWidget);

      // Start animation
      controller.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.isAnimating, isTrue);
      expect(controller.value, greaterThan(0.0));
      expect(find.text('A: hidden'), findsNothing);
      expect(find.text('B: hidden'), findsNothing);

      // Unmount Widget A while animating
      showA.data = false;
      await tester.pump(const Duration(milliseconds: 50));

      // Widget A is unmounted, but Widget B is still active!
      // Controller must NOT freeze or hibernate; handover to Widget B's ticker!
      expect(find.text('A: hidden'), findsOneWidget);
      expect(controller.isActive, isTrue);
      expect(controller.isAnimating, isTrue);
      expect(controller.value, greaterThan(0.2));

      // Wait until animation completes on Widget B
      await tester.pumpAndSettle();
      expect(controller.isCompleted, isTrue);
      expect(controller.value, equals(1.0));
      expect(find.text('B: 100%'), findsOneWidget);

      // Now unmount Widget B -> last holder unmounts, controller hibernates
      showB.data = false;
      await tester.pumpAndSettle();

      expect(find.text('B: hidden'), findsOneWidget);
      expect(controller.isActive, isFalse);
      expect(controller.isDormant, isTrue);
    });

    testWidgets(
        '12. controller.animate dynamically resyncs proxy and triggers onDeactivate/onActivate when controller changes',
        (tester) async {
      final ctrl1 = DurableAnimationController(
          duration: const Duration(milliseconds: 300))
        ..value = 0.25;
      final ctrl2 = DurableAnimationController(
          duration: const Duration(milliseconds: 300))
        ..value = 0.75;

      int activateCount = 0;
      int deactivateCount = 0;
      final activeCtrlWhat = WhatController<DurableAnimationController>(ctrl1);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed(
            (context, via) => composed.animate(
              via(activeCtrlWhat.what),
              (context, via, ctrl) => Text('Val: ${ctrl.value}'),
              onActivate: (ctrl) => activateCount++,
              onDeactivate: (ctrl) => deactivateCount++,
            ),
          ),
        ),
      );

      expect(activateCount, equals(1));
      expect(deactivateCount, equals(0));
      expect(ctrl1.isActive, isTrue);
      expect(ctrl2.isDormant, isTrue);
      expect(find.text('Val: 0.25'), findsOneWidget);

      // Dynamically switch controller from ctrl1 to ctrl2
      activeCtrlWhat.data = ctrl2;
      await tester.pump();

      expect(activateCount, equals(2));
      expect(deactivateCount, equals(1));
      expect(ctrl1.isDormant, isTrue);
      expect(ctrl2.isActive, isTrue);
      expect(find.text('Val: 0.75'), findsOneWidget);

      ctrl1.hibernate();
      ctrl2.hibernate();
    });
  });
}
