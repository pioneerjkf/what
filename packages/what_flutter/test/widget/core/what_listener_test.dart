// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

void main() {
  group('WhatListener Widget & Element Tests', () {
    testWidgets(
        '1. Rebuild Count: 0 Invariant - child never rebuilds on state mutations',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      int childBuildCount = 0;
      final listenerLogs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
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
            body: WhatListener<String>(
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
            body: WhatListener<int>(
              number.what,
              (context, state) => recorded.add(state),
              guard: (state) => state % 2 == 0,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Filtered out by guard:
      for (int i = 1; i <= 5; i++) {
        number.data = i;
        await tester.pump();
      }

      expect(recorded, equals([2, 4]),
          reason: 'Only even states should pass the guard');
    });

    testWidgets(
        '4. onUncaughtError callback catches exceptions thrown in action',
        (WidgetTester tester) async {
      final trigger = WhatController<int>(0);
      Object? capturedError;
      StackTrace? capturedStackTrace;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
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

    testWidgets('5. WhatListener Element debugFillProperties diagnostics',
        (WidgetTester tester) async {
      final testWhat = WhatController<int>(1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
              testWhat.what,
              (context, state) {},
              child: const Text('Child'),
            ),
          ),
        ),
      );

      final element = tester.element(find.byType(WhatListener<int>));
      final builder = DiagnosticPropertiesBuilder();
      element.debugFillProperties(builder);

      expect(builder.properties.any((p) => p.name == 'isActive'), isTrue);
      expect(builder.properties.any((p) => p.name == 'hasChild'), isTrue);
    });

    testWidgets(
        '6. WhatListener debugFillProperties on widget and reassemble()',
        (WidgetTester tester) async {
      final a = WhatController<int>(1);
      final widget = WhatListener<int>(
        a.what,
        (ctx, state) {},
        child: const Text('Listener Child'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      final element = tester.element(find.byType(WhatListener<int>));
      final builder = DiagnosticPropertiesBuilder();
      element.widget.debugFillProperties(builder);
      expect(builder.properties.any((p) => p.name == 'target'), isTrue);
      expect(builder.properties.any((p) => p.name == 'action'), isTrue);

      // Reassemble
      // ignore: invalid_use_of_protected_member
      element.reassemble();
      expect(find.text('Listener Child'), findsOneWidget);
    });

    testWidgets(
        '7. WhatListener error handling with custom onUncaughtError and uncaught fallback',
        (WidgetTester tester) async {
      final a = WhatController<int>(1);
      Object? capturedError;
      final widgetWithOnError = WhatListener<int>(
        a.what,
        (ctx, state) => throw Exception('error in action'),
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

      // Test uncaught fallback directly via terminal hook
      final element = tester.element(find.byType(WhatListener<int>)) as dynamic;
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

    testWidgets('8. Composed multi-target listening via computed derived state',
        (WidgetTester tester) async {
      final a = WhatController<int>(10);
      final b = WhatController<int>(20);
      final sum = computed<int>((via) => via(a.what) + via(b.what));
      int childBuildCount = 0;
      final sumLogs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
              sum,
              (context, total) {
                sumLogs.add(total);
              },
              child: Builder(
                builder: (context) {
                  childBuildCount++;
                  return const Text('Composed Derived Child');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Composed Derived Child'), findsOneWidget);
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

    testWidgets('9. Dynamic widget update preserves reactivity with new target',
        (WidgetTester tester) async {
      final a = WhatController<int>(1);
      final b = WhatController<int>(2);
      final logs = <int>[];

      Widget buildHost({required bool swapToB}) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
              swapToB ? b.what : a.what,
              (context, state) => logs.add(state),
              child: const Text('Dynamic Target Content'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHost(swapToB: false));
      expect(find.text('Dynamic Target Content'), findsOneWidget);
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
    testWidgets('1. counter.what.listen(...) creates listener correctly',
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

    testWidgets('5. counter.what.listen respects take limit and deactivates',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: counter.what.listen(
              (context, state) => logs.add(state),
              take: 1,
            ),
          ),
        ),
      );

      counter.data = 1;
      await tester.pump();
      expect(logs, equals([1]));

      counter.data = 2;
      await tester.pump();
      expect(logs, equals([1]),
          reason: 'take: 1 must prevent second execution');
    });
  });

  group('WhatListener Time-Domain (Debounce & Throttle) Tests', () {
    testWidgets('1. WhatListener.debounce delays execution until settled',
        (WidgetTester tester) async {
      final a = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>.debounce(
              a.what,
              (context, state) => logs.add(state),
              duration: const Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Mutate a rapidly
      a.data = 10;
      await tester.pump(const Duration(milliseconds: 40));
      a.data = 20;
      await tester.pump(const Duration(milliseconds: 40));
      a.data = 15;
      await tester.pump(const Duration(milliseconds: 40));

      expect(logs, isEmpty);

      // Settle
      await tester.pump(const Duration(milliseconds: 110));
      expect(logs, equals([15]));
    });

    testWidgets(
        '2. WhatListener.throttle executes leading edge then trails after window',
        (WidgetTester tester) async {
      final a = WhatController<int>(0);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>.throttle(
              a.what,
              (context, state) => logs.add(state),
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

    testWidgets('3. WhatListener.debounce diagnostics and edge modes',
        (WidgetTester tester) async {
      final target = WhatController<String>('init');
      final logs = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<String>.debounce(
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
      final element = tester
          .element(find.byWidgetPredicate((w) => w is WhatListener<String>));
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
        '5. WhatListener.debounce and WhatListener.throttle factory constructors',
        (WidgetTester tester) async {
      final target = WhatController<int>(1);
      final logs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>.debounce(
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

    testWidgets(
        '6. Parent rebuild with identical targets reuses existing EffectRunner instance',
        (WidgetTester tester) async {
      final target = WhatController<int>(1);
      final logs = <int>[];

      Widget buildTree(int parentVersion) {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Version $parentVersion'),
                WhatListener<int>(
                  target.what,
                  (context, val) => logs.add(val),
                  child: const Text('Child'),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(1));
      final element = tester.element(find.byType(WhatListener<int>));
      final initialRunner = (element as dynamic).terminal as EffectRunner;

      // Parent rebuilds with version 2, but listener target is unchanged
      await tester.pumpWidget(buildTree(2));
      final updatedRunner = (element as dynamic).terminal as EffectRunner;

      // Runner must be preserved (identical) across parent rebuilds with same config
      expect(identical(initialRunner, updatedRunner), isTrue,
          reason:
              'EffectRunner should be reused when listener configuration is identical');

      // Verify listener continues to fire correctly
      target.data = 2;
      await tester.pump();
      expect(logs, equals([2]));
    });

    testWidgets(
        '7. Parent rebuild with altered targets cleanly replaces EffectRunner',
        (WidgetTester tester) async {
      final targetA = WhatController<int>(1);
      final targetB = WhatController<int>(10);
      final logs = <int>[];

      Widget buildTree(What<int> currentTarget) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
              currentTarget,
              (context, val) => logs.add(val),
              child: const Text('Child'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(targetA.what));
      final element = tester.element(find.byType(WhatListener<int>));
      final initialRunner = (element as dynamic).terminal as EffectRunner;

      // Rebuild with targetB
      await tester.pumpWidget(buildTree(targetB.what));
      final updatedRunner = (element as dynamic).terminal as EffectRunner;

      expect(identical(initialRunner, updatedRunner), isFalse,
          reason: 'EffectRunner must be cleanly replaced when target changes');

      // Old target must no longer trigger
      targetA.data = 2;
      await tester.pump();
      expect(logs, isEmpty);

      // New target must trigger
      targetB.data = 20;
      await tester.pump();
      expect(logs, equals([20]));
    });

    testWidgets(
        '8. Parent rebuild with inline lambda guard preserves EffectRunner and evaluates latest scope',
        (WidgetTester tester) async {
      final target = WhatController<int>(0);
      final logs = <int>[];

      Widget buildTree(int threshold) {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Threshold $threshold'),
                WhatListener<int>(
                  target.what,
                  (context, val) => logs.add(val),
                  // Inline lambda guard creates a new function object on each build, capturing latest threshold
                  guard: (val) => val > threshold,
                  child: const Text('Child'),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(5));
      final element = tester.element(find.byType(WhatListener<int>));
      final runner1 = (element as dynamic).terminal as EffectRunner;

      // Mutation with 3 does not meet threshold (5)
      target.data = 3;
      await tester.pump();
      expect(logs, isEmpty);

      // Mutation with 10 meets threshold (5)
      target.data = 10;
      await tester.pump();
      expect(logs, equals([10]));

      // Parent rebuilds updating threshold to 15 (creates new inline lambda guard)
      await tester.pumpWidget(buildTree(15));
      final runner2 = (element as dynamic).terminal as EffectRunner;

      // EffectRunner must remain identical despite inline lambda guard update
      expect(identical(runner1, runner2), isTrue,
          reason: 'Inline lambda guard must not destroy EffectRunner');

      // Mutation with 12 was > 5, but is NOT > 15 (must use latest captured threshold!)
      target.data = 12;
      await tester.pump();
      expect(logs, equals([10]),
          reason: 'Must evaluate updated guard from parent rebuild');

      // Mutation with 20 meets new threshold (> 15)
      target.data = 20;
      await tester.pump();
      expect(logs, equals([10, 20]),
          reason: 'Must evaluate updated guard and allow execution');
    });

    testWidgets(
        '9. Dynamically adding or changing guard preserves EffectRunner while applying new predicate',
        (WidgetTester tester) async {
      final target = WhatController<int>(1);
      final logs = <int>[];

      Widget buildTree(bool hasGuard) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
              target.what,
              (context, val) => logs.add(val),
              guard: hasGuard ? (val) => val > 5 : null,
              child: const Text('Child'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(false));
      final element = tester.element(find.byType(WhatListener<int>));
      final initialRunner = (element as dynamic).terminal as EffectRunner;

      // Rebuild adding a guard — target is unchanged, so runner is preserved!
      await tester.pumpWidget(buildTree(true));
      final updatedRunner = (element as dynamic).terminal as EffectRunner;

      expect(identical(initialRunner, updatedRunner), isTrue,
          reason: 'EffectRunner should be preserved when target is unchanged');

      // Value <= 5 should now be filtered by the newly attached guard
      target.data = 3;
      await tester.pump();
      expect(logs, isEmpty);

      // Value > 5 passes through the dynamic guard
      target.data = 10;
      await tester.pump();
      expect(logs, equals([10]));
    });

    testWidgets(
        '10. WhatListener.debounce dynamic duration update rebinds runner with new silence window',
        (WidgetTester tester) async {
      final target = WhatController<int>(0);
      final logs = <int>[];

      Widget buildTree(Duration duration) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener<int>.debounce(
              target.what,
              (context, val) => logs.add(val),
              duration: duration,
              child: const Text('Child'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(const Duration(milliseconds: 200)));

      // Rebuild with shortened debounce duration (50ms)
      await tester.pumpWidget(buildTree(const Duration(milliseconds: 50)));

      target.data = 42;
      // After 60ms: if old 200ms duration remained, logs would be empty.
      // With rebound 50ms duration, it must have already fired!
      await tester.pump(const Duration(milliseconds: 60));
      expect(logs, equals([42]),
          reason:
              'Debounce duration update must rebind runner and take effect');
    });

    testWidgets(
        '11. WhatListener.throttle dynamic duration update rebinds runner with new window',
        (WidgetTester tester) async {
      final target = WhatController<int>(0);
      final logs = <int>[];

      Widget buildTree(Duration duration) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener<int>.throttle(
              target.what,
              (context, val) => logs.add(val),
              duration: duration,
              child: const Text('Child'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(const Duration(milliseconds: 300)));

      // Rebuild with 50ms duration
      await tester.pumpWidget(buildTree(const Duration(milliseconds: 50)));

      // First mutation fires leading edge
      target.data = 1;
      await tester.pump();
      expect(logs, equals([1]));

      // Wait 60ms (past new 50ms window, but within old 300ms window)
      await tester.pump(const Duration(milliseconds: 60));

      // Second mutation should fire immediately as a new leading edge under 50ms window
      target.data = 2;
      await tester.pump();
      expect(logs, equals([1, 2]),
          reason: 'Throttle duration update must apply new window');
    });

    testWidgets(
        '12. WhatListener.debounce dynamic leading/trailing edge update rebinds runner',
        (WidgetTester tester) async {
      final target = WhatController<int>(0);
      final logs = <int>[];

      Widget buildTree({required bool leading, required bool trailing}) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener<int>.debounce(
              target.what,
              (context, val) => logs.add(val),
              duration: const Duration(milliseconds: 80),
              leading: leading,
              trailing: trailing,
              child: const Text('Child'),
            ),
          ),
        );
      }

      // Start with trailing-only
      await tester.pumpWidget(buildTree(leading: false, trailing: true));

      // Rebuild with leading-only
      await tester.pumpWidget(buildTree(leading: true, trailing: false));

      // Mutation should now fire immediately on leading edge
      target.data = 99;
      await tester.pump();
      expect(logs, equals([99]),
          reason: 'Leading edge must fire immediately with updated setting');

      // Further mutations within 80ms should not fire trailing edge because trailing is false
      target.data = 100;
      await tester.pump(const Duration(milliseconds: 90));
      expect(logs, equals([99]),
          reason: 'Trailing edge must NOT fire when trailing=false');
    });

    testWidgets(
        '13. Pending debounce timer survives across parent rebuilds with identical configuration',
        (WidgetTester tester) async {
      final target = WhatController<int>(0);
      final logs = <int>[];

      Widget buildTree(int parentVersion) {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Version $parentVersion'),
                WhatListener<int>.debounce(
                  target.what,
                  (context, val) => logs.add(val),
                  duration: const Duration(milliseconds: 100),
                  child: const Text('Child'),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(1));

      // 1. Mutate target: starts a 100ms debounce timer
      target.data = 42;
      // Advance by 40ms: timer is in-flight, callback has not fired yet
      await tester.pump(const Duration(milliseconds: 40));
      expect(logs, isEmpty);

      // 2. Parent rebuilds with Version 2 (configuration remains identical)
      // In the original bug, update() would deactivate and kill the pending debounce timer!
      await tester.pumpWidget(buildTree(2));

      // 3. Advance remaining 70ms (total 110ms > 100ms duration)
      await tester.pump(const Duration(milliseconds: 70));

      // Debounce MUST survive parent rebuild and fire cleanly with the latest value
      expect(logs, equals([42]),
          reason:
              'Pending debounce timer must survive parent rebuilds if configuration is identical');
    });

    testWidgets(
        '14. Pending throttle trailing timer survives across parent rebuilds with identical configuration',
        (WidgetTester tester) async {
      final target = WhatController<int>(0);
      final logs = <int>[];

      Widget buildTree(int parentVersion) {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Version $parentVersion'),
                WhatListener<int>.throttle(
                  target.what,
                  (context, val) => logs.add(val),
                  duration: const Duration(milliseconds: 100),
                  child: const Text('Child'),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(1));

      // 1. Leading edge fires immediately
      target.data = 1;
      await tester.pump();
      expect(logs, equals([1]));

      // 2. Second mutation within 100ms window schedules a trailing edge
      target.data = 2;
      await tester.pump(const Duration(milliseconds: 40));
      expect(logs, equals([1]));

      // 3. Parent rebuilds at 40ms with identical configuration
      await tester.pumpWidget(buildTree(2));

      // 4. Advance remaining 70ms (total 110ms > 100ms duration)
      await tester.pump(const Duration(milliseconds: 70));

      // Trailing edge MUST survive parent rebuild and fire
      expect(logs, equals([1, 2]),
          reason:
              'Pending throttle trailing timer must survive parent rebuilds if configuration is identical');
    });

    testWidgets(
        '15. take limits execution count and tears down early (auto deactivation)',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final recorded = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
              counter.what,
              (context, state) => recorded.add(state),
              take: 2,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      final element = tester.element(find.byType(WhatListener<int>));
      final runner = (element as dynamic).terminal as EffectRunner;
      expect(runner.isActive, isTrue);

      counter.data = 1;
      await tester.pump();
      expect(recorded, equals([1]));
      expect(runner.isActive, isTrue);

      counter.data = 2;
      await tester.pump();
      expect(recorded, equals([1, 2]));
      // After reaching take: 2 limit, runner must auto-deactivate
      expect(runner.isActive, isFalse,
          reason: 'Runner must self-deactivate when take quota is exhausted');

      counter.data = 3;
      await tester.pump();
      counter.data = 4;
      await tester.pump();

      expect(recorded, equals([1, 2]),
          reason: 'Must stop executing after exactly 2 runs');
    });

    testWidgets('16. take + guard preserves take tickets on false guard',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final recorded = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
              counter.what,
              (context, state) => recorded.add(state),
              guard: (state) => state.isEven,
              take: 2,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      final element = tester.element(find.byType(WhatListener<int>));
      final runner = (element as dynamic).terminal as EffectRunner;

      // 1. Odd state: guard returns false -> ticket preserved
      counter.data = 1;
      await tester.pump();
      expect(recorded, isEmpty);
      expect(runner.isActive, isTrue);

      // 2. Even state: guard returns true -> ticket 1 consumed
      counter.data = 2;
      await tester.pump();
      expect(recorded, equals([2]));
      expect(runner.isActive, isTrue);

      // 3. Odd state: guard returns false -> ticket preserved
      counter.data = 3;
      await tester.pump();
      expect(recorded, equals([2]));
      expect(runner.isActive, isTrue);

      // 4. Even state: guard returns true -> ticket 2 consumed (exhausted)
      counter.data = 4;
      await tester.pump();
      expect(recorded, equals([2, 4]));
      expect(runner.isActive, isFalse,
          reason: 'Runner must deactivate after 2 passing executions');

      // 5. Subsequent mutations never execute even if even
      counter.data = 6;
      await tester.pump();
      expect(recorded, equals([2, 4]));
    });

    testWidgets(
        '17. Parent rebuild with updated take rebinds EffectRunner, while identical take preserves runner',
        (WidgetTester tester) async {
      final counter = WhatController<int>(0);
      final recorded = <int>[];

      Widget buildTree(int? takeLimit) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener<int>(
              counter.what,
              (context, state) => recorded.add(state),
              take: takeLimit,
              child: const SizedBox.shrink(),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(1));
      final element = tester.element(find.byType(WhatListener<int>));
      final runner1 = (element as dynamic).terminal as EffectRunner;

      // Rebuild with identical take preserves runner
      await tester.pumpWidget(buildTree(1));
      final runner2 = (element as dynamic).terminal as EffectRunner;
      expect(identical(runner1, runner2), isTrue);

      // Rebuild with different take rebinds runner
      await tester.pumpWidget(buildTree(2));
      final runner3 = (element as dynamic).terminal as EffectRunner;
      expect(identical(runner1, runner3), isFalse,
          reason: 'Changing take must rebind runner');
    });

    testWidgets(
        '18. WhatListener.debounce and WhatListener.throttle with take limit',
        (WidgetTester tester) async {
      final debTarget = WhatController<int>(0);
      final thrTarget = WhatController<int>(0);
      final debLogs = <int>[];
      final thrLogs = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WhatListener<int>.debounce(
                  debTarget.what,
                  (context, val) => debLogs.add(val),
                  duration: const Duration(milliseconds: 50),
                  take: 1,
                  child: const Text('Debounce Child'),
                ),
                WhatListener<int>.throttle(
                  thrTarget.what,
                  (context, val) => thrLogs.add(val),
                  duration: const Duration(milliseconds: 50),
                  take: 1,
                  child: const Text('Throttle Child'),
                ),
              ],
            ),
          ),
        ),
      );

      // Throttle leading edge fires immediately with take: 1
      thrTarget.data = 1;
      await tester.pump();
      expect(thrLogs, equals([1]));

      // Further throttle mutations ignored because take is exhausted
      await tester.pump(const Duration(milliseconds: 60));
      thrTarget.data = 2;
      await tester.pump();
      expect(thrLogs, equals([1]),
          reason: 'Throttle take: 1 must exhaust after 1 run');

      // Debounce settles and fires once
      debTarget.data = 10;
      await tester.pump(const Duration(milliseconds: 60));
      expect(debLogs, equals([10]));

      // Further debounce mutations ignored because take is exhausted
      debTarget.data = 20;
      await tester.pump(const Duration(milliseconds: 60));
      expect(debLogs, equals([10]),
          reason: 'Debounce take: 1 must exhaust after 1 run');
    });

    testWidgets(
        '19. Exhausted take listener does not resurrect upon duration update on parent rebuild',
        (WidgetTester tester) async {
      final target = WhatController<int>(0);
      final logs = <int>[];

      Widget buildTree(Duration duration) {
        return MaterialApp(
          home: Scaffold(
            body: WhatListener<int>.debounce(
              target.what,
              (context, val) => logs.add(val),
              duration: duration,
              take: 1,
              child: const Text('Child'),
            ),
          ),
        );
      }

      // Mount with 50ms duration
      await tester.pumpWidget(buildTree(const Duration(milliseconds: 50)));

      // Trigger 1 execution (take: 1 exhausted -> deactivated)
      target.data = 1;
      await tester.pump(const Duration(milliseconds: 60));
      expect(logs, equals([1]));

      final element = tester.element(find.bySubtype<WhatListener<int>>());
      final runner = (element as dynamic).terminal as EffectRunner;
      expect(runner.isActive, isFalse,
          reason: 'Runner must be deactivated after take: 1');

      // Parent rebuilds updating duration from 50ms to 200ms with identical take: 1
      await tester.pumpWidget(buildTree(const Duration(milliseconds: 200)));

      // New mutation must NOT resurrect the dead listener!
      target.data = 2;
      await tester.pump(const Duration(milliseconds: 250));
      expect(logs, equals([1]),
          reason:
              'Exhausted take listener must NOT resurrect upon duration change');
    });
  });
}
