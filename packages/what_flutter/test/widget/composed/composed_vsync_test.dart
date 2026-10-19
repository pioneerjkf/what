// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';

void main() {
  group('composed.vsync Functor Hierarchy Tests', () {
    testWidgets(
        '1. Direct composed.vsync provides TickerProvider and tracks reactivity',
        (tester) async {
      final counter = WhatController<int>(0);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.vsync((context, via, vsync) {
            return Text(
                'Count: ${via(counter.what)}, HasVsync: ${(vsync as dynamic) is TickerProvider}');
          }),
        ),
      );

      expect(find.text('Count: 0, HasVsync: true'), findsOneWidget);

      counter.set(1);
      await tester.pump();
      expect(find.text('Count: 1, HasVsync: true'), findsOneWidget);
    });

    testWidgets('2. composed.vsync provides context and vsync', (tester) async {
      final counter = WhatController<int>(10);

      final w1 = composed.vsync((context, via, vsync) {
        expect(context, isA<BuildContext>());
        expect(vsync, isA<TickerProvider>());
        return Text('W1: ${via(counter.what)}');
      });

      final w2 = composed.vsync((context, via, vsync) {
        expect(context, isA<BuildContext>());
        expect(vsync, isA<TickerProvider>());
        return Text('W2: ${via(counter.what)}');
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [w1, w2]),
        ),
      );

      expect(find.text('W1: 10'), findsOneWidget);
      expect(find.text('W2: 10'), findsOneWidget);

      counter.set(20);
      await tester.pump();
      expect(find.text('W1: 20'), findsOneWidget);
      expect(find.text('W2: 20'), findsOneWidget);
    });

    testWidgets('3. composed.vsync.child memoizes static child',
        (tester) async {
      final counter = WhatController<int>(0);
      int childBuildCount = 0;

      final childWidget = Builder(
        builder: (context) {
          childBuildCount++;
          return const Text('StaticChild');
        },
      );

      final w1 = composed.vsync.child(
        (context, via, vsync, child) => Column(
          children: [
            Text('VsyncChild: ${via(counter.what)}'),
            child,
          ],
        ),
        child: childWidget,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: w1,
        ),
      );

      expect(find.text('VsyncChild: 0'), findsOneWidget);
      expect(find.text('StaticChild'), findsOneWidget);
      expect(childBuildCount, 1);

      counter.set(1);
      await tester.pump();

      expect(find.text('VsyncChild: 1'), findsOneWidget);
      expect(find.text('StaticChild'), findsOneWidget);
      expect(childBuildCount, 1); // Child was NOT rebuilt
    });

    testWidgets('4. composed.vsync.child provides context, vsync, and child',
        (tester) async {
      final counter = WhatController<int>(5);

      final w1 = composed.vsync.child(
        (context, via, vsync, child) => Column(
          children: [
            Text('W1: ${via(counter.what)}'),
            child,
          ],
        ),
        child: const Text('Child1'),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: w1,
        ),
      );

      expect(find.text('W1: 5'), findsOneWidget);
      expect(find.text('Child1'), findsOneWidget);

      counter.set(15);
      await tester.pump();

      expect(find.text('W1: 15'), findsOneWidget);
      expect(find.text('Child1'), findsOneWidget);
    });

    testWidgets(
        '5. composed.vsync.children provides context, vsync, and children',
        (tester) async {
      final counter = WhatController<int>(100);

      final w1 = composed.vsync.children(
        (context, via, vsync, children) => Column(
          children: [
            Text('Count1: ${via(counter.what)}'),
            ...children,
          ],
        ),
        children: const [Text('C1'), Text('C2')],
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: w1,
        ),
      );

      expect(find.text('Count1: 100'), findsOneWidget);
      expect(find.text('C1'), findsOneWidget);
      expect(find.text('C2'), findsOneWidget);

      counter.set(200);
      await tester.pump();

      expect(find.text('Count1: 200'), findsOneWidget);
      expect(find.text('C1'), findsOneWidget);
      expect(find.text('C2'), findsOneWidget);
    });

    testWidgets(
        '7. couples external controller via composed.animate and disposes on unmount',
        (tester) async {
      final ctrl = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed.animate(
            ctrl,
            (context, via, c) =>
                Text('AnimValue: ${c.value.toStringAsFixed(1)}'),
          ),
        ),
      );

      expect(find.text('AnimValue: 0.0'), findsOneWidget);

      ctrl.value = 0.8;
      await tester.pump();
      expect(find.text('AnimValue: 0.8'), findsOneWidget);

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.text('AnimValue: 0.8'), findsNothing);
    });
  });
}
