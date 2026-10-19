// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

void main() {
  group('WhatFlutterExtension (what.build) and _InlineSingleWhatWidget Tests',
      () {
    testWidgets(
        'renders initial data correctly via what.build((context, data) => ...)',
        (tester) async {
      final controller = WhatController<int>(10);
      final targetWhat = controller.what;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: targetWhat.build((context, count) {
            expect(context, isNotNull);
            return Text('Count: $count');
          }),
        ),
      );

      expect(find.text('Count: 10'), findsOneWidget);
    });

    testWidgets('rebuilds reactively when controller value changes',
        (tester) async {
      final controller = WhatController<String>('Hello');
      final targetWhat = controller.what;
      var buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: targetWhat.build((context, message) {
            buildCount++;
            return Text('Message: $message');
          }),
        ),
      );

      expect(find.text('Message: Hello'), findsOneWidget);
      expect(buildCount, 1);

      // Update state
      controller.set('World');
      await tester.pump();

      expect(find.text('Message: World'), findsOneWidget);
      expect(buildCount, 2);
    });

    testWidgets('does not rebuild when value is distinct (same value)',
        (tester) async {
      final controller = WhatController<int>(42, distinct: true);
      final targetWhat = controller.what;
      var buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: targetWhat.build((context, value) {
            buildCount++;
            return Text('Value: $value');
          }),
        ),
      );

      expect(buildCount, 1);

      // Setting same value with distinct: true
      controller.set(42);
      await tester.pump();

      expect(buildCount, 1);
    });

    testWidgets('handles nullable What<T?> values gracefully', (tester) async {
      final controller = WhatController<String?>('Initial');
      final targetWhat = controller.what;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: targetWhat.build((context, val) {
            return Text(val ?? 'No Data');
          }),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      controller.set(null);
      await tester.pump();
      expect(find.text('No Data'), findsOneWidget);

      controller.set('Recovered');
      await tester.pump();
      expect(find.text('Recovered'), findsOneWidget);
    });

    testWidgets(
        'updates correctly when widget configuration changes (same or new node)',
        (tester) async {
      final controller1 = WhatController<int>(1);
      final controller2 = WhatController<int>(2);

      Widget createHost(What<int> node) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: node.build(
            key: const ValueKey('what_widget'),
            (context, val) => Text('Val: $val'),
          ),
        );
      }

      // Initial pump with controller1
      await tester.pumpWidget(createHost(controller1.what));
      expect(find.text('Val: 1'), findsOneWidget);

      // Pump update with controller2
      await tester.pumpWidget(createHost(controller2.what));
      expect(find.text('Val: 2'), findsOneWidget);

      // Mutate controller2
      controller2.set(200);
      await tester.pump();
      expect(find.text('Val: 200'), findsOneWidget);

      // Controller1 should no longer drive the widget
      controller1.set(100);
      await tester.pump();
      expect(find.text('Val: 200'), findsOneWidget);
    });

    testWidgets('cleans up and deactivates RawWhatTerminal upon unmounting',
        (tester) async {
      final controller = WhatController<int>(100);
      final targetWhat = controller.what;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: targetWhat.build((context, val) => Text('Active: $val')),
        ),
      );

      expect(find.text('Active: 100'), findsOneWidget);

      // Unmount by replacing with empty Container
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      expect(find.text('Active: 100'), findsNothing);

      // Setting value after unmount must not throw or cause dirty leaks
      expect(() => controller.set(200), returnsNormally);
      await tester.pump();
    });

    testWidgets(
        'always provides local BuildContext allowing local InheritedWidget lookup',
        (tester) async {
      final controller = WhatController<String>('Alpha');
      final targetWhat = controller.what;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: targetWhat.build((context, data) {
            return Text('ContextData: $data (${context.runtimeType})');
          }),
        ),
      );

      expect(find.textContaining('ContextData: Alpha'), findsOneWidget);

      controller.set('Beta');
      await tester.pump();
      expect(find.textContaining('ContextData: Beta'), findsOneWidget);
    });

    testWidgets('targetWhat.build.child passes context, data, and cached child',
        (tester) async {
      final controller = WhatController<int>(10);
      final targetWhat = controller.what;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: targetWhat.build.child(
            (context, count, child) =>
                Row(children: [Text('Count: $count'), child]),
            child: const Text('StaticChild'),
          ),
        ),
      );

      expect(find.text('Count: 10'), findsOneWidget);
      expect(find.text('StaticChild'), findsOneWidget);

      controller.set(20);
      await tester.pump();
      expect(find.text('Count: 20'), findsOneWidget);
      expect(find.text('StaticChild'), findsOneWidget);
    });

    testWidgets(
        'targetWhat.build.children passes context, data, and cached children list',
        (tester) async {
      final controller = WhatController<String>('Title');
      final targetWhat = controller.what;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: targetWhat.build.children(
            (context, title, children) =>
                Column(children: [Text('Title: $title'), ...children]),
            children: const [Text('Item1'), Text('Item2')],
          ),
        ),
      );

      expect(find.text('Title: Title'), findsOneWidget);
      expect(find.text('Item1'), findsOneWidget);
      expect(find.text('Item2'), findsOneWidget);

      controller.set('UpdatedTitle');
      await tester.pump();
      expect(find.text('Title: UpdatedTitle'), findsOneWidget);
      expect(find.text('Item1'), findsOneWidget);
    });
  });
}
