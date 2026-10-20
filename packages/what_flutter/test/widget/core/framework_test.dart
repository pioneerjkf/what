// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

// Test WhatWidget implementations
base class CounterWhatWidget extends WhatWidget {
  const CounterWhatWidget({
    super.key,
    required this.counterWhat,
    this.prefix = 'Count',
  });

  final What<int> counterWhat;
  final String prefix;

  @override
  Widget build(BuildContext context, WhatVia via) {
    return Text('$prefix: ${via(counterWhat)}');
  }
}

base class ContextAwareWhatWidget extends WhatWidget {
  const ContextAwareWhatWidget({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final themeState = context.whatOf<String>();
    return Text('Theme: ${via(themeState)}');
  }
}

base class OptionalContextWhatWidget extends WhatWidget {
  const OptionalContextWhatWidget({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final optionalTheme = context.maybeWhatOf<String>();
    return Text('Theme: ${via(optionalTheme) ?? "default"}');
  }
}

base class ViaOfWhatWidget extends WhatWidget {
  const ViaOfWhatWidget({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final theme = via.of<String>(context);
    return Text('Theme: $theme');
  }
}

base class ViaMaybeOfWhatWidget extends WhatWidget {
  const ViaMaybeOfWhatWidget({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final optionalTheme = via.maybeOf<String>(context);
    return Text('Theme: ${optionalTheme ?? "default"}');
  }
}

abstract class _TestBaseClass {
  String get val;
}

class _TestChildClass implements _TestBaseClass {
  _TestChildClass(this.val);
  @override
  final String val;
}

void main() {
  group('WhatWidget & WhatElement Tests', () {
    testWidgets('renders initial data and updates on What state mutation',
        (tester) async {
      final controller = WhatController<int>(0);
      final targetWhat = controller.what;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CounterWhatWidget(counterWhat: targetWhat),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      controller.set(1);
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);

      controller.set(42);
      await tester.pump();
      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets(
        'rebuilds with force: true when parent passes new widget configuration',
        (tester) async {
      final controller1 = WhatController<int>(10);
      final controller2 = WhatController<int>(20);

      Widget createHost({
        required What<int> targetWhat,
        required String prefix,
      }) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: CounterWhatWidget(
            key: const ValueKey('counter_what'),
            counterWhat: targetWhat,
            prefix: prefix,
          ),
        );
      }

      await tester.pumpWidget(
          createHost(targetWhat: controller1.what, prefix: 'Initial'));
      expect(find.text('Initial: 10'), findsOneWidget);

      // Update widget with new prefix and new controller
      await tester.pumpWidget(
          createHost(targetWhat: controller2.what, prefix: 'Updated'));
      expect(find.text('Updated: 20'), findsOneWidget);

      controller2.set(99);
      await tester.pump();
      expect(find.text('Updated: 99'), findsOneWidget);
    });

    testWidgets(
        'upstream distinct short-circuits build evaluation when state value is unchanged',
        (tester) async {
      final source = WhatController<int>(0, distinct: false);
      final isEven = computed((via) => via(source.what) % 2 == 0).distinct();

      int buildCount = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: composed((context, via) {
            buildCount++;
            return Text('Even: ${via(isEven)}');
          }),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Even: true'), findsOneWidget);

      // Mutate source: 0 -> 2 (both even).
      source.data = 2;
      await tester.pump();

      // buildCount MUST remain 1 because isEven evaluated to identical state (distinct)!
      expect(buildCount, 1);
      expect(find.text('Even: true'), findsOneWidget);

      // Mutate source: 2 -> 3 (even -> odd).
      source.data = 3;
      await tester.pump();

      // buildCount increments because isEven mutated to false!
      expect(buildCount, 2);
      expect(find.text('Even: false'), findsOneWidget);
    });

    testWidgets('cleans up RawViaTerminal on unmount', (tester) async {
      final controller = WhatController<int>(5);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CounterWhatWidget(counterWhat: controller.what),
        ),
      );

      expect(find.text('Count: 5'), findsOneWidget);

      // Unmount
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      expect(find.text('Count: 5'), findsNothing);

      // Mutation after unmount should not throw or cause errors
      expect(() => controller.set(10), returnsNormally);
      await tester.pump();
    });

    testWidgets('supports const WhatWidget instantiation', (tester) async {
      final theme = WhatController<String>('Dark');

      // Const instantiation verification:
      const staticWidget = ContextAwareWhatWidget();
      expect(staticWidget, isNotNull);

      await tester.pumpWidget(
        theme.what.provide(
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: ContextAwareWhatWidget(),
          ),
        ),
      );

      expect(find.text('Theme: Dark'), findsOneWidget);
    });
  });

  group('WhatProvider & WhatBuildContextExtension Tests', () {
    testWidgets('whatOf<T>() reactively subscribes to WhatProvider<T>',
        (tester) async {
      final themeController = WhatController<String>('Dark');

      await tester.pumpWidget(
        themeController.what.provide(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ContextAwareWhatWidget(),
          ),
        ),
      );

      expect(find.text('Theme: Dark'), findsOneWidget);

      themeController.set('Light');
      await tester.pump();
      expect(find.text('Theme: Light'), findsOneWidget);
    });

    testWidgets('maybeWhatOf<T>() handles absent WhatProvider<T> gracefully',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: OptionalContextWhatWidget(),
        ),
      );

      expect(find.text('Theme: default'), findsOneWidget);
    });

    testWidgets('maybeWhatOf<T>() subscribes when WhatProvider<T> is present',
        (tester) async {
      final themeController = WhatController<String>('Custom');

      await tester.pumpWidget(
        themeController.what.provide(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: OptionalContextWhatWidget(),
          ),
        ),
      );

      expect(find.text('Theme: Custom'), findsOneWidget);

      themeController.set('Custom2');
      await tester.pump();
      expect(find.text('Theme: Custom2'), findsOneWidget);
    });

    testWidgets('via.of<T>(context) reactively subscribes to WhatProvider<T>',
        (tester) async {
      final themeController = WhatController<String>('Dark');

      await tester.pumpWidget(
        themeController.what.provide(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: const ViaOfWhatWidget(),
          ),
        ),
      );

      expect(find.text('Theme: Dark'), findsOneWidget);

      themeController.set('Light');
      await tester.pump();
      expect(find.text('Theme: Light'), findsOneWidget);
    });

    testWidgets(
        'via.maybeOf<T>(context) handles absent WhatProvider<T> gracefully',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: const ViaMaybeOfWhatWidget(),
        ),
      );

      expect(find.text('Theme: default'), findsOneWidget);
    });

    testWidgets(
        'via.maybeOf<T>(context) subscribes when WhatProvider<T> is present',
        (tester) async {
      final themeController = WhatController<String>('Custom');

      await tester.pumpWidget(
        themeController.what.provide(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: const ViaMaybeOfWhatWidget(),
          ),
        ),
      );

      expect(find.text('Theme: Custom'), findsOneWidget);

      themeController.set('Custom2');
      await tester.pump();
      expect(find.text('Theme: Custom2'), findsOneWidget);
    });

    testWidgets(
        'WhatProvider updateShouldNotify returns false for identical what reference',
        (tester) async {
      final controller = WhatController<int>(0);

      final widget1 = WhatProvider<int>(
        what: controller.what,
        child: const SizedBox.shrink(),
      );

      final widget2 = WhatProvider<int>(
        what: controller.what,
        child: const SizedBox.shrink(),
      );

      expect(widget1.updateShouldNotify(widget2), isFalse);

      final otherController = WhatController<int>(0);
      final widget3 = WhatProvider<int>(
        what: otherController.what,
        child: const SizedBox.shrink(),
      );

      expect(widget1.updateShouldNotify(widget3), isTrue);
    });

    testWidgets(
        'whatOf<T>() throws FlutterError when WhatProvider<T> is absent',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              return Text('${context.whatOf<int>()}');
            },
          ),
        ),
      );

      final dynamic exception = tester.takeException();
      expect(exception, isA<FlutterError>());
      expect(
        exception.toString(),
        contains('No ancestor WhatProvider<int> found'),
      );
    });

    testWidgets(
        'maybeWhatOf<T>() returns canonical What.constantNull singleton when absent',
        (tester) async {
      late What<int?> extracted1;
      late What<String?> extracted2;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              extracted1 = context.maybeWhatOf<int>();
              extracted2 = context.maybeWhatOf<String>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(extracted1, What.constantNull), isTrue);
      expect(identical(extracted2, What.constantNull), isTrue);
      expect(identical(extracted1, extracted2), isTrue);
    });

    testWidgets(
        'whatOf<T>() requires exact type match and fails on supertype unless explicitly provided',
        (tester) async {
      final childWhat =
          WhatController<_TestChildClass>(_TestChildClass('exact_payload'))
              .what;

      // 1. Provided as WhatProvider<_TestChildClass>
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatProvider<_TestChildClass>(
            what: childWhat,
            child: Builder(
              builder: (context) {
                // Exact type succeeds
                expect(
                  untracked(context.whatOf<_TestChildClass>()).val,
                  equals('exact_payload'),
                );
                // Supertype lookup fails with FlutterError
                expect(
                  () => context.whatOf<_TestBaseClass>(),
                  throwsA(isA<FlutterError>()),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // 2. Explicitly provided as WhatProvider<_TestBaseClass>
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WhatProvider<_TestBaseClass>(
            what: childWhat,
            child: Builder(
              builder: (context) {
                // Supertype lookup succeeds now that it is explicitly provisioned
                expect(
                  untracked(context.whatOf<_TestBaseClass>()).val,
                  equals('exact_payload'),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });
  });

  group('Animation & Vsync Lifecycle Tests', () {
    testWidgets('provides vsync and drives animation via What.managed',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedBoxWidget(),
        ),
      );

      expect(find.text('Progress: 0%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 50%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 100%'), findsOneWidget);
    });

    testWidgets('cleanly disposes tickers when unmounted', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedBoxWidget(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 50%'), findsOneWidget);

      // Unmount the widget by replacing it with an empty container
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(AnimatedBoxWidget), findsNothing);
    });

    testWidgets('mutes ticker when TickerMode is disabled', (tester) async {
      Widget createHost(bool enabled, Widget child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: TickerMode(
            enabled: enabled,
            child: child,
          ),
        );
      }

      final animatedBox = AnimatedBoxWidget();

      await tester.pumpWidget(createHost(true, animatedBox));
      expect(find.text('Progress: 0%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 50%'), findsOneWidget);

      // Disable TickerMode with same widget instance
      await tester.pumpWidget(createHost(false, animatedBox));

      // Advancing time should not advance animation while muted
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 50%'), findsOneWidget);

      // Re-enable TickerMode
      await tester.pumpWidget(createHost(true, animatedBox));

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Progress: 100%'), findsOneWidget);
    });

    testWidgets(
        'Uncaught error inside terminal invalidation is reported to FlutterError',
        (tester) async {
      final ctrl = WhatController<int>(1);
      FlutterErrorDetails? reportedDetails;
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        reportedDetails = details;
      };

      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ctrl.what.build((_, data) => Text('Count: $data')),
          ),
        );

        expect(find.text('Count: 1'), findsOneWidget);

        // Find the reactive element
        final reactiveElement = tester.allElements.firstWhere(
          (e) =>
              e.runtimeType.toString().contains('What') ||
              e.runtimeType.toString().contains('What'),
        );

        final dynamic dynamicElement = reactiveElement;
        dynamicElement.handleTerminalUncaughtError(
          Exception('Terminal unhandled failure'),
          StackTrace.current,
        );

        expect(reportedDetails, isNotNull);
        expect(reportedDetails!.library, 'what_flutter');
        expect(reportedDetails!.exception.toString(),
            contains('Terminal unhandled failure'));
      } finally {
        FlutterError.onError = prevOnError;
      }
    });

    testWidgets(
        'WhatVsyncWidget provides active vsync and tracks What dependencies',
        (tester) async {
      final counter = WhatController<int>(0);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CounterVsyncWhatWidget(counterWhat: counter.what),
        ),
      );

      expect(find.text('Count: 0, Vsync: true'), findsOneWidget);

      counter.set(1);
      await tester.pump();
      expect(find.text('Count: 1, Vsync: true'), findsOneWidget);
    });

    testWidgets(
        'WhatWidget couples external controller via controller.animate and disposes cleanly on unmount',
        (tester) async {
      final ctrl = DurableAnimationController(
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedVsyncWhatWidget(controller: ctrl),
        ),
      );

      expect(find.text('Value: 0.0'), findsOneWidget);

      ctrl.value = 0.5;
      await tester.pump();
      expect(find.text('Value: 0.5'), findsOneWidget);

      // Unmount safely
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(AnimatedVsyncWhatWidget), findsNothing);
    });
  });
}

base class CounterVsyncWhatWidget extends WhatVsyncWidget {
  const CounterVsyncWhatWidget({
    super.key,
    required this.counterWhat,
  });

  final What<int> counterWhat;

  @override
  Widget build(
    BuildContext context,
    WhatVia via,
    TickerProvider vsync,
  ) {
    final count = via(counterWhat);
    return Text(
        'Count: $count, Vsync: ${(vsync as dynamic) is TickerProvider}');
  }
}

base class AnimatedVsyncWhatWidget extends WhatWidget {
  const AnimatedVsyncWhatWidget({
    super.key,
    required this.controller,
  });

  final DurableAnimationController controller;

  @override
  Widget build(
    BuildContext context,
    WhatVia via,
  ) {
    return composed.animate(
      controller,
      (context, via, ctrl) => Text('Value: ${ctrl.value.toStringAsFixed(1)}'),
    );
  }
}

class AnimatedBoxWidget extends StatefulWidget {
  const AnimatedBoxWidget({super.key});

  @override
  State<AnimatedBoxWidget> createState() => _AnimatedBoxWidgetState();
}

class _AnimatedBoxWidgetState extends State<AnimatedBoxWidget>
    with SingleTickerProviderStateMixin {
  late final What<AnimationController> animation = What.managed(
    create: (via) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward(),
    dispose: (c) => c.dispose(),
  );

  @override
  Widget build(BuildContext context) {
    return composed((context, via) {
      final animCtrl = via(animation);
      return AnimatedBuilder(
        animation: animCtrl,
        builder: (context, child) {
          return Text('Progress: ${(animCtrl.value * 100).toInt()}%');
        },
      );
    });
  }
}
