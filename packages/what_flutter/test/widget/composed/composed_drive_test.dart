// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/src/animation/durable/testing.dart';

void main() {
  group('composed.drive Functor Widget Tests', () {
    testWidgets(
        '1. composed.drive() evaluates onTick and continuously updates inline widget on frame ticks',
        (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.drive<int>(
            (elapsed) => elapsed.inMilliseconds,
            (context, via, ms) {
              buildCount++;
              return Text('Elapsed: $ms ms');
            },
            initialValue: 0,
          ),
        ),
      );

      expect(find.text('Elapsed: 0 ms'), findsOneWidget);
      expect(buildCount, equals(1));

      // Advance time by 50ms
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Elapsed: 50 ms'), findsOneWidget);
      expect(buildCount, equals(2));

      // Advance time by another 100ms
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Elapsed: 150 ms'), findsOneWidget);
      expect(buildCount, equals(3));
    });

    testWidgets('2. composed.drive() accesses BuildContext', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.drive<int>(
            (elapsed) => elapsed.inMilliseconds,
            (context, via, ms) =>
                Text('ContextDir: ${Directionality.of(context).name} $ms'),
            initialValue: 0,
          ),
        ),
      );

      expect(find.text('ContextDir: ltr 0'), findsOneWidget);
    });

    testWidgets(
        '3. composed.drive.child() isolates heavy static child during 120fps ticks',
        (tester) async {
      int childBuildCount = 0;
      int vsyncBuildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.drive.child<int>(
            (elapsed) => elapsed.inMilliseconds,
            (context, via, ms, child) {
              vsyncBuildCount++;
              return Row(
                children: [
                  Text('Tick: $ms'),
                  child,
                ],
              );
            },
            child: Builder(
              builder: (context) {
                childBuildCount++;
                return const Text('HeavyChild');
              },
            ),
            initialValue: 0,
          ),
        ),
      );

      expect(find.text('Tick: 0'), findsOneWidget);
      expect(find.text('HeavyChild'), findsOneWidget);
      expect(vsyncBuildCount, equals(1));
      expect(childBuildCount, equals(1));

      // Advance multiple frames
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Tick: 100'), findsOneWidget);
      expect(vsyncBuildCount, equals(3));
      // HeavyChild MUST NOT rebuild on ticker ticks
      expect(childBuildCount, equals(1));
    });

    testWidgets('4. composed.drive with hoisted children and context work',
        (tester) async {
      const child1 = Text('Child1');
      const child2 = Text('Child2');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              composed.drive<int>(
                (elapsed) => elapsed.inMilliseconds,
                (context, via, ms) => Row(children: [
                  child1,
                  Text('Val1: $ms ${Directionality.of(context).name}'),
                ]),
                initialValue: 0,
              ),
              composed.drive<int>(
                (elapsed) => elapsed.inMilliseconds,
                (context, via, ms) => Row(children: [
                  Text('Val2: ${Directionality.of(context).name} $ms'),
                  child2,
                ]),
                initialValue: 0,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Child1'), findsOneWidget);
      expect(find.text('Val1: 0 ltr'), findsOneWidget);
      expect(find.text('Child2'), findsOneWidget);
      expect(find.text('Val2: ltr 0'), findsOneWidget);
    });

    testWidgets(
        '5. composed.drive.children provides context, tick value, and children',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.drive.children<int>(
            (elapsed) => elapsed.inMilliseconds,
            (context, via, ms, children) => Column(children: [
              Text('A: $ms ${Directionality.of(context).name}'),
              ...children,
            ]),
            children: const [Text('Item 1'), Text('Item 2')],
            initialValue: 0,
          ),
        ),
      );

      expect(find.text('A: 0 ltr'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets(
        '6. composed.drive with distinct: true suppresses duplicate rebuilds on equal ticks',
        (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.drive<bool>(
            // Emits true when elapsed > 100ms
            (elapsed) => elapsed.inMilliseconds >= 100,
            (context, via, flag) {
              buildCount++;
              return Text('Flag: $flag');
            },
            distinct: true,
            initialValue: false,
          ),
        ),
      );

      expect(find.text('Flag: false'), findsOneWidget);
      expect(buildCount, equals(1));

      // Advance by 30ms -> elapsed = 30ms -> still false -> suppressed by distinct!
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('Flag: false'), findsOneWidget);
      expect(buildCount, equals(1)); // SUPPRESSED!

      // Advance by 40ms -> elapsed = 70ms -> still false -> suppressed!
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Flag: false'), findsOneWidget);
      expect(buildCount, equals(1)); // SUPPRESSED!

      // Advance by 50ms -> elapsed = 120ms -> becomes true -> rebuilds!
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Flag: true'), findsOneWidget);
      expect(buildCount, equals(2)); // FIRED!

      // Advance by another 50ms -> elapsed = 170ms -> still true -> suppressed!
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Flag: true'), findsOneWidget);
      expect(buildCount, equals(2)); // SUPPRESSED!
    });

    testWidgets(
        '7. composed.drive with custom equals comparator suppresses rebuilds properly',
        (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.drive<double>(
            (elapsed) => elapsed.inMilliseconds / 100.0,
            (context, via, val) {
              buildCount++;
              return Text('Floor: ${val.floor()}');
            },
            distinct: true,
            equals: (prev, next) => prev.floor() == next.floor(),
            initialValue: 0.0,
          ),
        ),
      );

      expect(find.text('Floor: 0'), findsOneWidget);
      expect(buildCount, equals(1));

      // 40ms -> 0.4 -> floor is 0 -> equals returns true -> suppressed
      await tester.pump(const Duration(milliseconds: 40));
      expect(buildCount, equals(1));

      // 80ms -> 0.8 -> floor is 0 -> suppressed
      await tester.pump(const Duration(milliseconds: 40));
      expect(buildCount, equals(1));

      // 120ms -> 1.2 -> floor is 1 -> equals returns false -> rebuilds!
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Floor: 1'), findsOneWidget);
      expect(buildCount, equals(2));
    });

    testWidgets(
        '8. composed.drive cancels internal ticker upon unmount preventing leaks',
        (tester) async {
      final showWhat = WhatController<bool>(true);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed(
            (context, via) => via(showWhat.what)
                ? composed.drive<int>(
                    (elapsed) => elapsed.inMilliseconds,
                    (context, via, ms) => Text('Ticking: $ms'),
                    initialValue: 0,
                  )
                : const Text('Dead'),
          ),
        ),
      );

      expect(find.text('Ticking: 0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Ticking: 50'), findsOneWidget);

      // Unmount the driven widget
      showWhat.data = false;
      await tester.pump();

      expect(find.text('Dead'), findsOneWidget);

      // Advance frames - must not crash or invoke onTick
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Dead'), findsOneWidget);
    });

    testWidgets(
        '9. Multiple composed.drive widgets run independently without interference',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              composed.drive<int>(
                (elapsed) => elapsed.inMilliseconds * 2, // 2x speed
                (context, via, ms) => Text('DriveA: $ms'),
                initialValue: 0,
              ),
              composed.drive<int>(
                (elapsed) => elapsed.inMilliseconds * 10, // 10x speed
                (context, via, ms) => Text('DriveB: $ms'),
                initialValue: 0,
              ),
            ],
          ),
        ),
      );

      expect(find.text('DriveA: 0'), findsOneWidget);
      expect(find.text('DriveB: 0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('DriveA: 100'), findsOneWidget);
      expect(find.text('DriveB: 500'), findsOneWidget);
    });
  });

  group('composed.drive Reactive Tracking Tests', () {
    testWidgets(
        '10. composed.drive automatically tracks external What mutations via RawViaTerminal',
        (tester) async {
      final prefixWhat = WhatController<String>('Speed:');
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.drive<int>(
            (elapsed) => elapsed.inMilliseconds,
            (context, via, ms) {
              buildCount++;
              final prefix = via(prefixWhat.what);
              return Text('$prefix $ms');
            },
            initialValue: 0,
          ),
        ),
      );

      expect(find.text('Speed: 0'), findsOneWidget);
      expect(buildCount, equals(1));

      // Advance time
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Speed: 50'), findsOneWidget);
      expect(buildCount, equals(2));

      // Mutate external What without tick advancement!
      prefixWhat.data = 'Velocity:';
      await tester.pump(); // No frame duration advance

      // Must have rebuilt reactively!
      expect(find.text('Velocity: 50'), findsOneWidget);
      expect(buildCount, equals(3));
    });

    testWidgets('11. composed.drive tracks external Whats with hoisted widgets',
        (tester) async {
      final tagWhat = WhatController<String>('Tag');
      const staticChild = Text('ChildStatic');
      const staticChildren = [Text('Item 1')];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              composed.drive<int>(
                (elapsed) => elapsed.inMilliseconds,
                (context, via, ms) => Text(
                    'CtxWatch: ${Directionality.of(context).name} ${via(tagWhat.what)} $ms'),
                initialValue: 0,
              ),
              composed.drive<int>(
                (elapsed) => elapsed.inMilliseconds,
                (context, via, ms) => Row(children: [
                  Text('WatchChild: ${via(tagWhat.what)} $ms'),
                  staticChild,
                ]),
                initialValue: 0,
              ),
              composed.drive<int>(
                (elapsed) => elapsed.inMilliseconds,
                (context, via, ms) => Column(children: [
                  Text('WatchChildren: ${via(tagWhat.what)} $ms'),
                  ...staticChildren,
                ]),
                initialValue: 0,
              ),
            ],
          ),
        ),
      );

      expect(find.text('CtxWatch: ltr Tag 0'), findsOneWidget);
      expect(find.text('WatchChild: Tag 0'), findsOneWidget);
      expect(find.text('ChildStatic'), findsOneWidget);
      expect(find.text('WatchChildren: Tag 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);

      tagWhat.data = 'Updated';
      await tester.pump();

      expect(find.text('CtxWatch: ltr Updated 0'), findsOneWidget);
      expect(find.text('WatchChild: Updated 0'), findsOneWidget);
      expect(find.text('WatchChildren: Updated 0'), findsOneWidget);
    });
  });

  group('composed.animate Functor Widget Tests', () {
    testWidgets(
        '12. composed.animate drives DurableAnimationController with automatic resync',
        (tester) async {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate(
            controller,
            (context, via, ctrl) =>
                Text('Progress: ${(ctrl.value * 100).toInt()}%'),
            onActivate: (ctrl) => ctrl.forward(),
          ),
        ),
      );

      expect(find.text('Progress: 0%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 50%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 100%'), findsOneWidget);

      controller.hibernate();
    });

    testWidgets(
        '13. composed.animate in composed tracks external What alongside controller',
        (tester) async {
      final modeWhat = WhatController<String>('Linear');
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed(
            (context, via) {
              final mode = via(modeWhat.what);
              return composed.animate(
                controller,
                (context, via, ctrl) {
                  return Text('$mode: ${(ctrl.value * 100).toInt()}%');
                },
              );
            },
          ),
        ),
      );

      expect(find.text('Linear: 0%'), findsOneWidget);

      controller.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Linear: 50%'), findsOneWidget);

      modeWhat.data = 'EaseInOut';
      await tester.pump();
      expect(find.text('EaseInOut: 50%'), findsOneWidget);

      controller.hibernate();
    });

    testWidgets(
        '14. composed.animate with context and hoisted children work as expected',
        (tester) async {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 100),
      );
      const resStaticChild = Text('ResStaticChild');
      const resStaticChildCtx = Text('ResStaticChildCtx');
      const resStaticCtxChild = Text('ResStaticCtxChild');
      const resItem1 = [Text('ResItem 1')];
      const resItem2 = [Text('ResItem 2')];
      const resItem3 = [Text('ResItem 3')];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              composed.animate(
                controller,
                (context, via, ctrl) =>
                    Text('ResCtx: ${Directionality.of(context).name}'),
              ),
              composed.animate(
                controller,
                (context, via, ctrl) => Row(children: [
                  Text('ResChild: ${ctrl.value}'),
                  resStaticChild
                ]),
              ),
              composed.animate(
                controller,
                (context, via, ctrl) => Row(children: [
                  Text(
                      'ResChildCtx: ${Directionality.of(context).name} ${ctrl.value}'),
                  resStaticChildCtx,
                ]),
              ),
              composed.animate(
                controller,
                (context, via, ctrl) => Row(children: [
                  Text(
                      'ResCtxChild: ${Directionality.of(context).name} ${ctrl.value}'),
                  resStaticCtxChild,
                ]),
              ),
              composed.animate(
                controller,
                (context, via, ctrl) => Column(children: [
                  Text('ResChildren: ${ctrl.value}'),
                  ...resItem1,
                ]),
              ),
              composed.animate(
                controller,
                (context, via, ctrl) => Row(children: [
                  Text(
                      'ResChildrenCtx: ${Directionality.of(context).name} ${ctrl.value}'),
                  ...resItem2,
                ]),
              ),
              composed.animate(
                controller,
                (context, via, ctrl) => Row(children: [
                  Text(
                      'ResCtxChildren: ${Directionality.of(context).name} ${ctrl.value}'),
                  ...resItem3,
                ]),
              ),
            ],
          ),
        ),
      );

      expect(find.text('ResCtx: ltr'), findsOneWidget);
      expect(find.text('ResChild: 0.0'), findsOneWidget);
      expect(find.text('ResStaticChild'), findsOneWidget);
      expect(find.text('ResChildCtx: ltr 0.0'), findsOneWidget);
      expect(find.text('ResStaticChildCtx'), findsOneWidget);
      expect(find.text('ResCtxChild: ltr 0.0'), findsOneWidget);
      expect(find.text('ResStaticCtxChild'), findsOneWidget);
      expect(find.text('ResChildren: 0.0'), findsOneWidget);
      expect(find.text('ResItem 1'), findsOneWidget);
      expect(find.text('ResChildrenCtx: ltr 0.0'), findsOneWidget);
      expect(find.text('ResItem 2'), findsOneWidget);
      expect(find.text('ResCtxChildren: ltr 0.0'), findsOneWidget);
      expect(find.text('ResItem 3'), findsOneWidget);

      controller.hibernate();
    });

    testWidgets(
        '15. composed.animate triggers onActivate on mount and onDeactivate on unmount',
        (tester) async {
      int activateCount = 0;
      int deactivateCount = 0;
      final showWhat = WhatController<bool>(true);
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed(
            (context, via) => via(showWhat.what)
                ? composed.animate(
                    controller,
                    (context, via, ctrl) =>
                        Text('Value: ${(ctrl.value * 100).toInt()}%'),
                    onActivate: (ctrl) {
                      activateCount++;
                      if (!ctrl.isAnimating) ctrl.forward();
                    },
                    onDeactivate: (ctrl) {
                      deactivateCount++;
                    },
                  )
                : const Text('Hidden'),
          ),
        ),
      );

      expect(activateCount, equals(1));
      expect(deactivateCount, equals(0));
      expect(find.text('Value: 0%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Value: 50%'), findsOneWidget);

      // Unmount the wake widget
      showWhat.data = false;
      await tester.pumpAndSettle();

      expect(activateCount, equals(1));
      expect(deactivateCount, equals(1));
      expect(find.text('Hidden'), findsOneWidget);

      // Remount the wake widget
      showWhat.data = true;
      await tester.pumpAndSettle();

      expect(activateCount, equals(2));
      expect(deactivateCount, equals(1));

      controller.hibernate();
    });

    testWidgets(
        '16. composed.animate inside composed triggers onActivate and onDeactivate properly',
        (tester) async {
      int activateCount = 0;
      int deactivateCount = 0;
      final showWhat = WhatController<bool>(true);
      final titleWhat = WhatController<String>('TitleA');
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed(
            (context, via) {
              final show = via(showWhat.what);
              final title = via(titleWhat.what);
              return show
                  ? composed.animate(
                      controller,
                      (context, via, ctrl) =>
                          Text('$title: ${(ctrl.value * 100).toInt()}%'),
                      onActivate: (ctrl) {
                        activateCount++;
                        ctrl.forward();
                      },
                      onDeactivate: (ctrl) {
                        deactivateCount++;
                      },
                    )
                  : const Text('Off');
            },
          ),
        ),
      );

      expect(activateCount, equals(1));
      expect(deactivateCount, equals(0));
      expect(find.text('TitleA: 0%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('TitleA: 50%'), findsOneWidget);

      titleWhat.data = 'TitleB';
      await tester.pump();
      expect(find.text('TitleB: 50%'), findsOneWidget);
      // Mutating what should not re-trigger activate/deactivate
      expect(activateCount, equals(1));
      expect(deactivateCount, equals(0));

      // Unmount
      showWhat.data = false;
      await tester.pumpAndSettle();
      expect(deactivateCount, equals(1));

      controller.hibernate();
    });
  });

  group('composed.animate Unified Tests', () {
    testWidgets(
        '17. composed.animate automatically updates on frame ticks without AnimatedBuilder',
        (tester) async {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate(
            controller,
            (context, via, ctrl) =>
                Text('Progress: ${(ctrl.value * 100).toInt()}%'),
            onActivate: (ctrl) => ctrl.forward(),
          ),
        ),
      );

      // Frame 0ms (0%)
      expect(find.text('Progress: 0%'), findsOneWidget);

      // Frame 150ms (50%)
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 50%'), findsOneWidget);

      // Frame 300ms (100%)
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 100%'), findsOneWidget);

      controller.hibernate();
    });

    testWidgets(
        '18. composed.animate.child isolates heavy static child during 60/120fps ticks',
        (tester) async {
      int staticChildBuildCount = 0;
      int dynamicBuilderCount = 0;
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 200),
      );

      final staticChild = Builder(
        builder: (context) {
          staticChildBuildCount++;
          return const Text('Static Heavy Graphic');
        },
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate.child(
            controller,
            (context, via, ctrl, child) {
              dynamicBuilderCount++;
              return Column(
                children: [
                  child,
                  Text('Progress: ${(ctrl.value * 100).toInt()}%'),
                ],
              );
            },
            child: staticChild,
            onActivate: (ctrl) => ctrl.forward(),
          ),
        ),
      );

      expect(staticChildBuildCount, equals(1));
      expect(dynamicBuilderCount, equals(1));
      expect(find.text('Static Heavy Graphic'), findsOneWidget);
      expect(find.text('Progress: 0%'), findsOneWidget);

      // Advance frames
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Progress: 50%'), findsOneWidget);
      expect(staticChildBuildCount, equals(1),
          reason: 'Static child must not rebuild on ticks');
      expect(dynamicBuilderCount, greaterThan(1));

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Progress: 100%'), findsOneWidget);
      expect(staticChildBuildCount, equals(1));

      controller.hibernate();
    });

    testWidgets(
        '19. composed.animate tracks both frame ticks and external What mutations',
        (tester) async {
      final labelWhat = WhatController<String>('Alpha');
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate(
            controller,
            (context, via, ctrl) =>
                Text('${via(labelWhat.what)}: ${(ctrl.value * 100).toInt()}%'),
            onActivate: (ctrl) => ctrl.forward(),
          ),
        ),
      );

      expect(find.text('Alpha: 0%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Alpha: 50%'), findsOneWidget);

      labelWhat.data = 'Beta';
      await tester.pump();
      expect(find.text('Beta: 50%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Beta: 100%'), findsOneWidget);

      controller.hibernate();
    });

    testWidgets('20. composed.animate.child provides context, ctrl, and child',
        (tester) async {
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate.child(
            controller,
            (context, via, ctrl, child) => Column(
              children: [
                child,
                Text('Val: ${(ctrl.value * 100).toInt()}'),
              ],
            ),
            child: const Text('Cached Header'),
            onActivate: (ctrl) => ctrl.forward(),
          ),
        ),
      );

      expect(find.text('Cached Header'), findsOneWidget);
      expect(find.text('Val: 0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Val: 50'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Val: 100'), findsOneWidget);

      controller.hibernate();
    });

    testWidgets(
        '21. composed.animate unmount/remount dormant and lifecycle safety',
        (tester) async {
      int activateCount = 0;
      int deactivateCount = 0;
      final showWhat = WhatController<bool>(true);
      final controller = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed(
            (context, via) => via(showWhat.what)
                ? composed.animate(
                    controller,
                    (context, via, ctrl) =>
                        Text('Coord: ${ctrl.value.toStringAsFixed(1)}'),
                    onActivate: (ctrl) {
                      activateCount++;
                    },
                    onDeactivate: (ctrl) {
                      deactivateCount++;
                    },
                  )
                : const Text('Dormant'),
          ),
        ),
      );

      expect(activateCount, equals(1));
      expect(deactivateCount, equals(0));
      expect(find.text('Coord: 0.0'), findsOneWidget);

      // Start animation to 0.5 (half duration = 150ms)
      controller.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Coord: 0.5'), findsOneWidget);

      // Unmount mid-flight -> deactivates and detaches listener
      showWhat.data = false;
      await tester.pump();
      await tester.pump();

      expect(activateCount, equals(1));
      expect(deactivateCount, equals(1));
      expect(find.text('Dormant'), findsOneWidget);
      expect(controller.value, equals(0.5)); // Frozen freezes

      // Remount -> reactivates and reattaches listener
      showWhat.data = true;
      await tester.pump();
      await tester.pump();

      expect(activateCount, equals(2));
      expect(deactivateCount, equals(1));
      expect(find.text('Coord: 0.5'), findsOneWidget);

      controller.hibernate();
    });
  });
}
