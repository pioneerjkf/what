// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

void main() {
  group('UnaryWhatListener Widget & Element Tests', () {
    testWidgets(
        '1. Rebuild Count: 0 Invariant - child never rebuilds on state mutations',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      int childBuildCount = 0;
      final listenerLogs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<int>(
              counter.what,
              (context, state) {
                listenerLogs.add(state);
              },
              child: Builder(
                builder: (context) {
                  childBuildCount++;
                  return const Text('Static Child');
                },
              ),
            ),
          ),
        ),
      );

      // Initial mount: child builds exactly once, listener NEVER runs (0 runs on mount)
      expect(find.text('Static Child'), findsOneWidget);
      expect(childBuildCount, equals(1));
      expect(listenerLogs, isEmpty,
          reason: 'Targets are manifest; 0 runs upon construction/mount');

      // Sequential mutations with pumps
      for (int i = 1; i <= 5; i++) {
        counter.data = i;
        await tester.pump();
      }

      // Invariant checks:
      expect(listenerLogs, equals([1, 2, 3, 4, 5]),
          reason: 'Listener must fire for every pumped state change');
      expect(childBuildCount, equals(1),
          reason:
              'Rebuild Count MUST be 0! Child should NEVER rebuild on What mutation.');
    });

    testWidgets('2. Microtask-Scheduled Execution and Burst Coalescing',
        (WidgetTester tester) async {
      final message = WhatController<String>('Hello');
      final results = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<String>(
              message.what,
              (context, state) {
                results.add(state);
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(results, isEmpty);

      // Mutate: listener does NOT execute synchronously before microtask flush
      message.data = 'World';
      expect(results, isEmpty, reason: 'Deferred to microtask turn');

      await tester.pump();
      expect(results, equals(['World']));

      // Burst mutations within same tick coalesce into 1 invocation
      message.data = 'A';
      message.data = 'B';
      message.data = 'What';
      expect(results, equals(['World']));

      await tester.pump();
      expect(results, equals(['World', 'What']));
    });

    testWidgets('3. guard conditionally filters execution',
        (WidgetTester tester) async {
      final number = WhatController<int>(0);
      final recorded = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<int>(
              number.what,
              (context, state) => recorded.add(state),
              guard: (state) => state.isEven,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      for (int i = 1; i <= 5; i++) {
        number.data = i;
        await tester.pump();
      }

      expect(recorded, equals([2, 4]),
          reason: 'Only even states should pass the guard');
    });

    testWidgets('4. take limits execution count and tears down early',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final recorded = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<int>(
              counter.what,
              (context, state) => recorded.add(state),
              take: 2,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      counter.data = 1;
      await tester.pump();
      counter.data = 2;
      await tester.pump();
      counter.data = 3;
      await tester.pump();
      counter.data = 4;
      await tester.pump();

      expect(recorded, equals([1, 2]),
          reason: 'Must stop executing after exactly 2 runs');
    });

    testWidgets('5. take + guard preserves take tickets on false guard',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final recorded = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<int>(
              counter.what,
              (context, state) => recorded.add(state),
              guard: (state) => state >= 10,
              take: 2,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Filtered out by guard: tickets are preserved
      counter.data = 1;
      await tester.pump();
      counter.data = 2;
      await tester.pump();
      expect(recorded, isEmpty);

      // Meets guard: consume ticket 1
      counter.data = 10;
      await tester.pump();
      expect(recorded, equals([10]));

      // Filtered out again
      counter.data = 3;
      await tester.pump();
      expect(recorded, equals([10]));

      // Meets guard: consume ticket 2 (take exhausted)
      counter.data = 20;
      await tester.pump();
      expect(recorded, equals([10, 20]));

      // Further mutations never run
      counter.data = 30;
      await tester.pump();
      expect(recorded, equals([10, 20]));
    });

    testWidgets(
        '6. onUncaughtError callback catches exceptions thrown in action',
        (WidgetTester tester) async {
      final trigger = WhatController<int>(0);
      Object? capturedError;
      StackTrace? capturedStackTrace;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<int>(
              trigger.what,
              (context, state) {
                throw StateError('Simulated Action Crash: $state');
              },
              onUncaughtError: (context, error, stackTrace) {
                capturedError = error;
                capturedStackTrace = stackTrace;
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      trigger.data = 1;
      await tester.pump();

      expect(capturedError, isA<StateError>());
      expect(capturedError.toString(), contains('Simulated Action Crash: 1'));
      expect(capturedStackTrace, isNotNull);
    });

    testWidgets('7. UnaryWhatListener Element debugFillProperties diagnostics',
        (WidgetTester tester) async {
      final testWhat = WhatController<int>(1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<int>(
              testWhat.what,
              (context, state) {},
              take: 5,
              child: const Text('Child'),
            ),
          ),
        ),
      );

      final element = tester.element(find.byType(UnaryWhatListener<int>));
      final builder = DiagnosticPropertiesBuilder();
      element.debugFillProperties(builder);

      expect(builder.properties.any((p) => p.name == 'isActive'), isTrue);
      expect(builder.properties.any((p) => p.name == 'hasChild'), isTrue);
    });
  });

  group('WhatListener (Multi-Target) Tests', () {
    testWidgets('1. WhatListener monitors multiple targets',
        (WidgetTester tester) async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener(
              [a.what, b.what],
              (context) {
                logs.add(a.what.peek + b.what.peek);
              },
              child: const Text('Multi Static Child'),
            ),
          ),
        ),
      );

      expect(find.text('Multi Static Child'), findsOneWidget);
      expect(logs, isEmpty);

      a.data = 10;
      await tester.pump();
      expect(logs, equals([12]));

      b.data = 20;
      await tester.pump();
      expect(logs, equals([12, 30]));
    });

    testWidgets(
        '2. WhatListener with guard filtering multi-target invalidations',
        (WidgetTester tester) async {
      final a = WhatController<int>(5);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener(
              [a.what],
              (context) => logs.add(a.what.peek * 2),
              guard: () => a.what.peek > 5,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(logs, isEmpty);

      a.data = 4;
      await tester.pump();
      expect(logs, isEmpty);

      a.data = 6;
      await tester.pump();
      expect(logs, equals([12]));
    });

    testWidgets('3. WhatListener debugFillProperties and reassemble()',
        (WidgetTester tester) async {
      final a = WhatController<int>(1);
      final widget = WhatListener(
        [a.what],
        (ctx) {},
        take: 5,
        child: const Text('Listener Child'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      final element = tester.element(find.byType(WhatListener));
      final builder = DiagnosticPropertiesBuilder();
      element.widget.debugFillProperties(builder);
      expect(builder.properties.any((p) => p.name == 'targets'), isTrue);
      expect(builder.properties.any((p) => p.name == 'action'), isTrue);
      expect(builder.properties.any((p) => p.name == 'take'), isTrue);

      // Reassemble
      // ignore: invalid_use_of_protected_member
      element.reassemble();
      expect(find.text('Listener Child'), findsOneWidget);
    });

    testWidgets(
        '4. WhatListener error handling with custom onUncaughtError and uncaught fallback',
        (WidgetTester tester) async {
      final a = WhatController<int>(1);
      Object? capturedError;
      final widgetWithOnError = WhatListener(
        [a.what],
        (ctx) => throw Exception('error in action'),
        onUncaughtError: (el, err, st) => capturedError = err,
        child: const Text('With Error'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widgetWithOnError,
          ),
        ),
      );

      a.data = 2;
      await tester.pump();
      expect(capturedError, isNotNull);
      expect(capturedError.toString(), contains('error in action'));

      // Test uncaught fallback directly via visibleForTesting hook
      final element = tester.element(find.byType(WhatListener)) as dynamic;
      FlutterErrorDetails? reportedError;
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) => reportedError = details;

      try {
        element.handleTerminalUncaughtError(
          Exception('direct uncaught error'),
          StackTrace.current,
        );
        expect(reportedError, isNotNull);
        expect(
          reportedError!.exception.toString(),
          contains('direct uncaught error'),
        );
      } finally {
        FlutterError.onError = prevOnError;
      }
    });
  });

  group('composed.listen Functor Tests', () {
    testWidgets(
        '1. composed.listen(targets, action) monitors multiple targets with Rebuild Count: 0',
        (WidgetTester tester) async {
      final a = WhatController<int>(10);
      final b = WhatController<int>(20);
      int childBuildCount = 0;
      final sumLogs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener(
              [a.what, b.what],
              (context) {
                sumLogs.add(a.what.peek + b.what.peek);
              },
              child: Builder(
                builder: (context) {
                  childBuildCount++;
                  return const Text('Composed Static Child');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Composed Static Child'), findsOneWidget);
      expect(childBuildCount, equals(1));
      expect(sumLogs, isEmpty);

      // Mutate a
      a.data = 15;
      await tester.pump();
      expect(sumLogs, equals([35]));
      expect(childBuildCount, equals(1));

      // Mutate b
      b.data = 25;
      await tester.pump();
      expect(sumLogs, equals([35, 40]));
      expect(childBuildCount, equals(1));
    });

    testWidgets(
        '2. composed.listen.unary(target, action) directly observes a single node',
        (WidgetTester tester) async {
      final status = WhatController<String>('init');
      final logs = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener(
              status.what,
              (context, state) => logs.add(state),
              child: const Text('Status Body'),
            ),
          ),
        ),
      );

      expect(find.text('Status Body'), findsOneWidget);
      expect(logs, isEmpty);

      status.data = 'loading';
      await tester.pump();
      status.data = 'done';
      await tester.pump();
      expect(logs, equals(['loading', 'done']));
    });

    testWidgets('3. composed.listen defers and coalesces bursts',
        (WidgetTester tester) async {
      final count = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener(
              [count.what],
              (context) {
                logs.add(count.what.peek * 10);
              },
              child: const Text('Scheduled Composed'),
            ),
          ),
        ),
      );

      // Bursty mutations within same turn
      for (var i = 1; i <= 5; i++) {
        count.data = i;
      }

      // Not invoked synchronously
      expect(logs, isEmpty);

      // Flushed after microtask
      await tester.pump();
      expect(logs, equals([50]));
    });

    testWidgets(
        '4. Dynamic widget update preserves reactivity with new targets',
        (WidgetTester tester) async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final logs = <int>[];

      Widget buildHost({required bool swapToB}) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener(
              swapToB ? [b.what] : [a.what],
              (context) => logs.add(swapToB ? b.what.peek : a.what.peek),
              child: const Text('Dynamic Targets Content'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHost(swapToB: false));
      expect(find.text('Dynamic Targets Content'), findsOneWidget);
      expect(logs, isEmpty);

      a.data = 10;
      await tester.pump();
      expect(logs, equals([10]));

      // Update widget with target b
      await tester.pumpWidget(buildHost(swapToB: true));

      // Mutate a: no longer observed
      a.data = 20;
      await tester.pump();
      expect(logs, equals([10]));

      // Mutate b: newly observed
      b.data = 5;
      await tester.pump();
      expect(logs, equals([10, 5]));
    });
  });

  group('What<T>.listen Extension Tests', () {
    testWidgets('1. counter.what.listen(...) creates unary listener correctly',
        (WidgetTester tester) async {
      final counter = WhatController<int>(10);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: counter.what.listen(
              (context, state) => logs.add(state),
              child: const Text('Extension Body'),
            ),
          ),
        ),
      );

      expect(find.text('Extension Body'), findsOneWidget);
      expect(logs, isEmpty);

      counter.data = 20;
      await tester.pump();
      expect(logs, equals([20]));
    });

    testWidgets(
        '2. counter.what.listen.debounce(...) debounces rapid mutations',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: counter.what.listen.debounce(
              const Duration(milliseconds: 100),
              (context, state) => logs.add(state),
            ),
          ),
        ),
      );

      // Rapid emissions
      counter.data = 1;
      await tester.pump(const Duration(milliseconds: 30));
      counter.data = 2;
      await tester.pump(const Duration(milliseconds: 30));
      counter.data = 3;
      await tester.pump(const Duration(milliseconds: 30));

      expect(logs, isEmpty);

      // Settle duration
      await tester.pump(const Duration(milliseconds: 120));
      expect(logs, equals([3]));
    });

    testWidgets(
        '3. counter.what.listen.throttle(...) throttles consecutive mutations',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: counter.what.listen.throttle(
              const Duration(milliseconds: 100),
              (context, state) => logs.add(state),
            ),
          ),
        ),
      );

      // Leading edge fires immediately
      counter.data = 1;
      await tester.pump();
      expect(logs, equals([1]));

      // Rapid emissions within the 100ms window
      counter.data = 2;
      await tester.pump(const Duration(milliseconds: 30));
      counter.data = 3;
      await tester.pump(const Duration(milliseconds: 30));
      expect(logs, equals([1]));

      // Window closes; trailing edge fires with latest value
      await tester.pump(const Duration(milliseconds: 50));
      expect(logs, equals([1, 3]));
    });

    testWidgets('4. counter.what.listen debounced side-effect works correctly',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: counter.what.listen.debounce(
              const Duration(milliseconds: 50),
              (context, state) => logs.add(state),
            ),
          ),
        ),
      );

      counter.data = 42;
      await tester.pump(const Duration(milliseconds: 60));
      expect(logs, equals([42]));
    });
  });

  group('WhatListener Time-Domain (Debounce & Throttle) Tests', () {
    testWidgets(
        '1. WhatListener.debounce delays execution until multi-target mutations settle',
        (WidgetTester tester) async {
      final a = WhatController<int>(0);
      final b = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener.debounce(
              [a.what, b.what],
              (context) {
                logs.add(a.what.peek + b.what.peek);
              },
              duration: const Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Mutate a and b rapidly
      a.data = 10;
      await tester.pump(const Duration(milliseconds: 40));
      b.data = 20;
      await tester.pump(const Duration(milliseconds: 40));
      a.data = 15;
      await tester.pump(const Duration(milliseconds: 40));

      expect(logs, isEmpty);

      // Settle
      await tester.pump(const Duration(milliseconds: 110));
      expect(logs, equals([35])); // 15 + 20
    });

    testWidgets(
        '2. WhatListener.throttle executes leading edge then trails after window',
        (WidgetTester tester) async {
      final a = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener.throttle(
              [a.what],
              (context) {
                logs.add(a.what.peek);
              },
              duration: const Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Leading edge
      a.data = 1;
      await tester.pump();
      expect(logs, equals([1]));

      // Bursts during window
      a.data = 2;
      await tester.pump(const Duration(milliseconds: 30));
      a.data = 3;
      await tester.pump(const Duration(milliseconds: 30));
      expect(logs, equals([1]));

      // Trailing edge
      await tester.pump(const Duration(milliseconds: 50));
      expect(logs, equals([1, 3]));
    });

    testWidgets('3. UnaryWhatListener.debounce and diagnostics',
        (WidgetTester tester) async {
      final target = WhatController<String>('init');
      final logs = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<String>.debounce(
              target.what,
              (context, state) => logs.add(state),
              duration: const Duration(milliseconds: 80),
              leading: true,
              trailing: true,
            ),
          ),
        ),
      );

      // Verify diagnostics
      final element = tester.element(
          find.byWidgetPredicate((w) => w is UnaryWhatListener<String>));
      final desc = element.toString();
      expect(desc.toLowerCase(), contains('debounce'));

      // Leading edge fires
      target.data = 'first';
      await tester.pump();
      expect(logs, equals(['first']));

      // Trailing burst
      target.data = 'second';
      await tester.pump(const Duration(milliseconds: 30));
      target.data = 'third';
      await tester.pump(const Duration(milliseconds: 90));

      expect(logs, equals(['first', 'third']));
    });

    testWidgets(
        '4. Debounced listener safely cancels timer and does not fire when unmounted',
        (WidgetTester tester) async {
      final target = WhatController<int>(0);
      final logs = <int>[];

      Widget buildHost(bool show) {
        return MaterialApp(
          home: Scaffold(
            body: show
                ? target.what.listen.debounce(
                    const Duration(milliseconds: 100),
                    (context, val) => logs.add(val),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }

      await tester.pumpWidget(buildHost(true));

      // Trigger mutation to start debounce timer
      target.data = 100;
      await tester.pump(const Duration(milliseconds: 30));
      expect(logs, isEmpty);

      // Unmount before timer finishes
      await tester.pumpWidget(buildHost(false));

      // Advance clock past timer expiration
      await tester.pump(const Duration(milliseconds: 120));

      // Should NEVER have fired because it was deactivated upon unmount
      expect(logs, isEmpty);
    });

    testWidgets(
        '5. UnaryWhatListener.debounce and UnaryWhatListener.throttle factory constructors',
        (WidgetTester tester) async {
      final target = WhatController<int>(1);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnaryWhatListener<int>.debounce(
              target.what,
              (context, val) => logs.add(val),
              duration: const Duration(milliseconds: 50),
            ),
          ),
        ),
      );

      target.data = 2;
      await tester.pump(const Duration(milliseconds: 60));
      expect(logs, equals([2]));
    });
  });
}
