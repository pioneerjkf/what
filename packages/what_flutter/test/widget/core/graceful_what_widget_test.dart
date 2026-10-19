// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

void main() {
  group('GracefulWhat & Flutter Widget Integration Tests', () {
    testWidgets(
      '1.1 Widget unmount anchors upstream resource in grace period without disposing',
      (tester) async {
        int createCount = 0;
        int disposeCount = 0;

        final resource = managed<String>(
          create: (_) {
            createCount++;
            return 'Resource-$createCount';
          },
          dispose: (_) {
            disposeCount++;
          },
        );

        final gracefulResource =
            resource.graceful(graceful(const Duration(milliseconds: 100)));
        bool showWidget = true;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                if (showWidget) {
                  return gracefulResource.build((_, data) => Text(data));
                }
                return const Text('Alternative');
              },
            ),
          ),
        );

        expect(find.text('Resource-1'), findsOneWidget);
        expect(createCount, 1);
        expect(disposeCount, 0);

        // Depart screen: Widget unmounts, subscriber drops to 0
        tester.element(find.byType(StatefulBuilder)).markNeedsBuild();
        showWidget = false;
        await tester.pump();

        expect(find.text('Alternative'), findsOneWidget);
        expect(disposeCount, 0); // Graceful anchor keeps it warm!

        // Wait 40ms (< 100ms)
        await tester.pump(const Duration(milliseconds: 40));
        expect(disposeCount, 0);

        // Return before expiration: Widget remounts
        tester.element(find.byType(StatefulBuilder)).markNeedsBuild();
        showWidget = true;
        await tester.pump();

        expect(find.text('Resource-1'), findsOneWidget);
        expect(createCount, 1); // Zero recreation! Instant restore!
        expect(disposeCount, 0);

        // Depart again
        tester.element(find.byType(StatefulBuilder)).markNeedsBuild();
        showWidget = false;
        await tester.pump();

        // Wait past 100ms grace period
        await tester.pump(const Duration(milliseconds: 150));
        expect(disposeCount, 1); // Cleanly released!
      },
    );

    testWidgets(
      '1.2 Multiple widgets sharing single GracefulWhat manage reference counting smoothly',
      (tester) async {
        int createCount = 0;
        int disposeCount = 0;

        final resource = managed<int>(
          create: (_) {
            createCount++;
            return createCount * 10;
          },
          dispose: (_) {
            disposeCount++;
          },
        );

        final gracefulResource =
            resource.graceful(graceful(const Duration(milliseconds: 80)));
        bool showFirst = true;
        bool showSecond = true;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    if (showFirst)
                      gracefulResource.build((_, data) => Text('First: $data')),
                    if (showSecond)
                      gracefulResource
                          .build((_, data) => Text('Second: $data')),
                  ],
                );
              },
            ),
          ),
        );

        expect(find.text('First: 10'), findsOneWidget);
        expect(find.text('Second: 10'), findsOneWidget);
        expect(createCount, 1);

        // Drop first widget: second still active, no grace period needed
        tester.element(find.byType(StatefulBuilder)).markNeedsBuild();
        showFirst = false;
        await tester.pump();

        expect(find.text('Second: 10'), findsOneWidget);
        expect(disposeCount, 0);

        // Drop second widget: now total subscribers = 0, grace period starts
        tester.element(find.byType(StatefulBuilder)).markNeedsBuild();
        showSecond = false;
        await tester.pump();

        expect(disposeCount, 0);

        // Wait past expiration
        await tester.pump(const Duration(milliseconds: 120));
        expect(disposeCount, 1);
      },
    );

    testWidgets(
      '1.3 composed with via explicit tracking works seamlessly with GracefulWhat',
      (tester) async {
        final count = WhatController<int>(1);
        final gracefulCount =
            count.what.graceful(graceful(const Duration(milliseconds: 60)));

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: composed(
                (context, via) => Text('Count: ${via(gracefulCount)}')),
          ),
        );

        expect(find.text('Count: 1'), findsOneWidget);

        count.set(2);
        await tester.pump();
        expect(find.text('Count: 2'), findsOneWidget);

        // Tear down widget tree and allow grace period timer to expire
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
