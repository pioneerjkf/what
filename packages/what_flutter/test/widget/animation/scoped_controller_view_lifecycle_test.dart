// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';

void main() {
  group('ScopedAnimationController Scoped View Lifecycle Tests', () {
    testWidgets(
      'Listeners attached to mounted.view are automatically purged upon unmount (Zero-Leak)',
      (tester) async {
        final controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );

        final isMountedWhat = WhatController<bool>(true);
        int tickCount = 0;
        final statuses = <AnimationStatus>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed((context, via) {
              if (!via(isMountedWhat.what)) {
                return const SizedBox.shrink();
              }

              return composed.animate(controller, (context, via, mounted) {
                // Register listeners on the mounted scoped view
                mounted.view.addListener(() {
                  tickCount++;
                });
                mounted.view.addStatusListener(statuses.add);

                return FadeTransition(
                  opacity: mounted.view,
                  child: const Text('Animated Content'),
                );
              });
            }),
          ),
        );

        // Initial mount
        await tester.pump();
        expect(find.text('Animated Content'), findsOneWidget);

        // Drive animation while mounted
        controller.forward();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final ticksWhileMounted = tickCount;
        expect(ticksWhileMounted, greaterThan(0));
        expect(statuses, contains(AnimationStatus.forward));

        // Unmount the animated widget by updating the reactive flag
        isMountedWhat.set(false);
        await tester.pump();
        expect(find.text('Animated Content'), findsNothing);

        // Ticking the controller while unmounted must NOT notify old unmounted listeners
        final ticksAfterUnmount = tickCount;
        final statusesAfterUnmountCount = statuses.length;

        // Drive animation to complete while unmounted
        await tester.pump(const Duration(milliseconds: 200));

        // Invariant: Unmounted view listeners must remain completely silent (purged)
        expect(tickCount, equals(ticksAfterUnmount));
        expect(statuses.length, equals(statusesAfterUnmountCount));

        // Remounting should establish a fresh, working scope without listener duplication
        isMountedWhat.set(true);
        await tester.pump();
        expect(find.text('Animated Content'), findsOneWidget);

        controller.reverse();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tickCount, greaterThan(ticksAfterUnmount));
      },
    );

    testWidgets(
      'Unmounted proxy enters disposed terminal state and guards against view access',
      (tester) async {
        final controller = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final isMountedWhat = WhatController<bool>(true);
        late ScopedAnimationController capturedMounted;
        late Animation<double> capturedView;

        await tester.pumpWidget(
          MaterialApp(
            home: composed((context, via) {
              if (!via(isMountedWhat.what)) {
                return const SizedBox.shrink();
              }

              return composed.animate(controller, (context, via, mounted) {
                capturedMounted = mounted;
                capturedView = mounted.view;
                return const Text('Active Proxy');
              });
            }),
          ),
        );
        await tester.pump();
        expect(find.text('Active Proxy'), findsOneWidget);

        // Unmount
        isMountedWhat.set(false);
        await tester.pump();
        expect(find.text('Active Proxy'), findsNothing);

        // Performing operations on disposed proxy throws AssertionError
        expect(() => capturedMounted.view, throwsAssertionError);
        expect(() => capturedMounted.forward(), throwsAssertionError);
        expect(() => capturedMounted.reverse(), throwsAssertionError);
        expect(() => capturedMounted.stop(), throwsAssertionError);

        // Attaching listeners or creating derived animations on disposed view throws AssertionError
        expect(() => capturedView.addListener(() {}), throwsAssertionError);
        expect(
            () =>
                CurvedAnimation(parent: capturedView, curve: Curves.easeInOut),
            throwsAssertionError);
      },
    );
  });
}
