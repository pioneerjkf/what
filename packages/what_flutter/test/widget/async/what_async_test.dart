// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

void main() {
  group('WhatAsyncBuilder & WhatPendingIndicator Widget Tests', () {
    testWidgets(
        '1.1 WhatAsyncBuilder renders loading when node has no data yet',
        (tester) async {
      final controller = WhatController<String>.late();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<String>(
            what: controller.what,
            data: (context, user) => Text('Data: $user'),
            loading: (context) => const Text('Loading...'),
            error: (context, error, stack) => Text('Error: $error'),
            empty: (context) => const Text('Empty!'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.text('Data: Alice'), findsNothing);
    });

    testWidgets('1.2 WhatAsyncBuilder transitions from loading to data',
        (tester) async {
      final controller = WhatController<String>.late();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<String>(
            what: controller.what,
            data: (context, user) => Text('Data: $user'),
            loading: (context) => const Text('Loading...'),
            error: (context, error, stack) => Text('Error: $error'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      // Transition to data
      controller.set('Alice');
      await tester.pump();

      expect(find.text('Data: Alice'), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);
    });

    testWidgets('1.3 WhatAsyncBuilder renders error when node fails',
        (tester) async {
      final controller = WhatController<String>.late();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<String>(
            what: controller.what,
            data: (context, user) => Text('Data: $user'),
            loading: (context) => const Text('Loading...'),
            error: (context, error, stack) => Text('Error: $error'),
          ),
        ),
      );

      controller.setError('Server unavailable');
      await tester.pump();

      expect(find.text('Error: Server unavailable'), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);
    });

    testWidgets(
        '1.4 WhatAsyncBuilder renders empty when payload is empty list/map',
        (tester) async {
      final listController = WhatController<List<String>>(['first', 'second']);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<List<String>>(
            what: listController.what,
            data: (context, items) => Text('Items: ${items.length}'),
            loading: (context) => const Text('Loading...'),
            empty: (context) => const Text('No items found'),
          ),
        ),
      );

      expect(find.text('Items: 2'), findsOneWidget);

      // Mutate to empty list
      listController.set([]);
      await tester.pump();

      expect(find.text('No items found'), findsOneWidget);
      expect(find.text('Items: 0'), findsNothing);

      // Mutate to empty map
      final mapController = WhatController<Map<String, int>>({'a': 1});
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<Map<String, int>>(
            what: mapController.what,
            data: (context, map) => Text('Map: ${map.length}'),
            loading: (context) => const Text('Loading...'),
            empty: (context) => const Text('Empty Map'),
          ),
        ),
      );
      expect(find.text('Map: 1'), findsOneWidget);

      mapController.set({});
      await tester.pump();
      expect(find.text('Empty Map'), findsOneWidget);
    });

    testWidgets(
        '1.4b WhatAsyncBuilder renders default ErrorWidget when error callback is null',
        (tester) async {
      final controller = WhatController<String>.late();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<String>(
            what: controller.what,
            data: (context, user) => Text('Data: $user'),
            loading: (context) => const Text('Loading...'),
          ),
        ),
      );

      controller.setError('Default Error Message');
      await tester.pump();

      expect(find.byType(ErrorWidget), findsOneWidget);
    });

    testWidgets('1.5 WhatAsyncBuilder renders empty when node has emptyReason',
        (tester) async {
      final node = What<String>.empty('AwaitingSearchQuery');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<String>(
            what: node,
            data: (context, val) => Text('Data: $val'),
            loading: (context) => const Text('Loading...'),
            empty: (context) => const Text('Please enter search query'),
          ),
        ),
      );

      expect(find.text('Please enter search query'), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);
    });

    testWidgets(
        '1.6 SWR preservation: retains prior data during pending re-evaluation by default',
        (tester) async {
      final query = WhatController<String>('apple');
      Completer<String>? activeCompleter;

      final rawFuture = computed.future((via) {
        via(query.what);
        final c = Completer<String>();
        activeCompleter = c;
        return c.future;
      });

      final retainedNode = rawFuture.retained();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<String>(
            what: retainedNode,
            preserveDataOnPending: true,
            data: (context, val) => Text('Fruit: $val'),
            loading: (context) => const Text('Loading...'),
          ),
        ),
      );

      // Initially loading
      expect(find.text('Loading...'), findsOneWidget);

      // First query finishes
      activeCompleter!.complete('AppleResults');
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.text('Fruit: AppleResults'), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);

      // Query changes -> Starts pending transition
      query.set('banana');
      await tester.pump();
      await tester.pump(Duration.zero);

      // FLICKER-FREE SWR: Previous data is retained on screen!
      expect(find.text('Fruit: AppleResults'), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);

      // Second query completes
      activeCompleter!.complete('BananaResults');
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.text('Fruit: BananaResults'), findsOneWidget);
    });

    testWidgets(
        '1.7 SWR disabled (preserveDataOnPending: false): shows loading during pending',
        (tester) async {
      final query = WhatController<String>('apple');
      Completer<String>? activeCompleter;

      final rawFuture = computed.future((via) {
        via(query.what);
        final c = Completer<String>();
        activeCompleter = c;
        return c.future;
      });

      final pendingCoupler = WhatCoupler<bool>.late();
      final retainedNode = rawFuture.retained(pending: pendingCoupler);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatAsyncBuilder<String>(
            what: retainedNode,
            pending: pendingCoupler.what,
            preserveDataOnPending: false, // SWR disabled!
            data: (context, val) => Text('Fruit: $val'),
            loading: (context) => const Text('Loading...'),
          ),
        ),
      );

      // Initial load
      expect(find.text('Loading...'), findsOneWidget);
      activeCompleter!.complete('AppleResults');
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.text('Fruit: AppleResults'), findsOneWidget);

      // Query changes -> pending
      query.set('banana');
      await tester.pump();
      await tester.pump(Duration.zero);

      // Shows loading because preserveDataOnPending is false!
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.text('Fruit: AppleResults'), findsNothing);

      activeCompleter!.complete('BananaResults');
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.text('Fruit: BananaResults'), findsOneWidget);
    });

    testWidgets('2.1 WhatPendingIndicator renders idle vs pending correctly',
        (tester) async {
      final pendingWhat = WhatController<bool>(false);

      final bar = WhatPendingIndicator(
        target: pendingWhat.what,
        height: 4.0,
      );

      expect(bar.preferredSize.height, 4.0);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              bar,
              const Text('Content Body'),
            ],
          ),
        ),
      );

      expect(find.text('Content Body'), findsOneWidget);
      expect(find.byType(CustomPaint), findsNothing);

      // Toggle pending to true
      pendingWhat.set(true);
      await tester.pump();

      expect(find.byType(CustomPaint), findsOneWidget);

      // Toggle pending back to false
      pendingWhat.set(false);
      await tester.pump();

      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('2.2 WhatPendingIndicator supports custom builder',
        (tester) async {
      final pendingWhat = WhatController<bool>(false);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatPendingIndicator(
            target: pendingWhat.what,
            builder: (context, isPending) => Text('PendingStatus: $isPending'),
          ),
        ),
      );

      expect(find.text('PendingStatus: false'), findsOneWidget);

      pendingWhat.set(true);
      await tester.pump();

      expect(find.text('PendingStatus: true'), findsOneWidget);
    });

    testWidgets(
        '2.3 WhatPendingIndicator directly binds to retained pending coupler',
        (tester) async {
      final query = WhatController<int>(1);
      Completer<String>? completer;

      final pendingCoupler = WhatCoupler<bool>.late();
      computed.future((via) {
        via(query.what);
        final c = Completer<String>();
        completer = c;
        return c.future;
      }).retained(pending: pendingCoupler);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatPendingIndicator(
            target: pendingCoupler.what,
            builder: (context, isPending) =>
                Text('RetainedPending: $isPending'),
          ),
        ),
      );

      // Initially before first resolution: idle (pending is false, raw is empty)
      expect(find.text('RetainedPending: false'), findsOneWidget);

      completer!.complete('Result 1');
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.text('RetainedPending: false'), findsOneWidget);

      // Trigger re-query -> pending turns true
      query.set(2);
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.text('RetainedPending: true'), findsOneWidget);

      completer!.complete('Result 2');
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.text('RetainedPending: false'), findsOneWidget);
    });

    testWidgets(
        '2.4 WhatPendingIndicator with opaque backgroundColor paints background',
        (tester) async {
      final pendingWhat = WhatController<bool>(true);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatPendingIndicator(
            target: pendingWhat.what,
            color: const Color(0xFF0000FF),
            backgroundColor: const Color(0xFF000000),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final painter = customPaint.painter as dynamic;

      // test shouldRepaint branches
      expect(painter.shouldRepaint(painter), isFalse);
    });

    testWidgets(
        '3.1 what.build.async functor constructs WhatAsyncBuilder inline',
        (tester) async {
      final controller = WhatController<int>(42);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: controller.what.build.async(
            data: (context, val) => Text('Count: $val'),
            loading: (context) => const Text('Loading...'),
            error: (context, err, _) => Text('Error: $err'),
            empty: (context) => const Text('Empty'),
          ),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);

      controller.set(99);
      await tester.pump();

      expect(find.text('Count: 99'), findsOneWidget);

      // Verify loading and error callbacks
      final lateCtrl = WhatController<int>.late();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: lateCtrl.what.build.async(
            data: (context, val) => Text('Count: $val'),
            loading: (context) => const Text('Loading Inline'),
            error: (context, err, _) => Text('Error: $err'),
            empty: (context) => const Text('Empty Inline'),
          ),
        ),
      );
      expect(find.text('Loading Inline'), findsOneWidget);

      lateCtrl.setError('Failed');
      await tester.pump();
      expect(find.text('Error: Failed'), findsOneWidget);

      // Verify empty callback
      final emptyWhat = What<int>.empty('NoData');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: emptyWhat.build.async(
            data: (context, val) => Text('Count: $val'),
            loading: (context) => const Text('Loading Inline'),
            error: (context, err, _) => Text('Error: $err'),
            empty: (context) => const Text('Empty Inline'),
          ),
        ),
      );
      expect(find.text('Empty Inline'), findsOneWidget);
    });

    testWidgets(
        '3.2 what.build.async functor provides context to all callbacks',
        (tester) async {
      final controller = WhatController<String>('Greeting');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: controller.what.build.async(
            data: (context, val) =>
                Text('$val in ${Directionality.of(context)}'),
            loading: (context) => const Text('Loading...'),
          ),
        ),
      );

      expect(
        find.text('Greeting in TextDirection.ltr'),
        findsOneWidget,
      );
    });
  });
}
