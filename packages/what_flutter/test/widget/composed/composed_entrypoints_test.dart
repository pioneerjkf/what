// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';

class _TestTheme extends InheritedWidget {
  const _TestTheme({
    required this.color,
    required super.child,
  });

  final Color color;

  static Color of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TestTheme>()!.color;
  }

  @override
  bool updateShouldNotify(_TestTheme oldWidget) => color != oldWidget.color;
}

void main() {
  group('A6: Composed 4-Entrypoint Standard Suite', () {
    testWidgets(
      'composed: context is composed own element, rebuilds isolatedly on InheritedWidget change',
      (tester) async {
        var parentBuildCount = 0;
        var composedBuildCount = 0;
        BuildContext? capturedOuterContext;
        BuildContext? capturedInnerContext;

        final themeColor = WhatController(Colors.red);
        final dummyWhat = WhatController(0);

        final innerTree = Builder(
          builder: (outerContext) {
            parentBuildCount++;
            capturedOuterContext = outerContext;
            return Column(
              children: [
                composed((innerContext, innerVia) {
                  composedBuildCount++;
                  capturedInnerContext = innerContext;
                  innerVia(dummyWhat.what);
                  final activeColor = _TestTheme.of(innerContext);
                  return Container(color: activeColor);
                }),
              ],
            );
          },
        );

        Widget buildTree() {
          return composed((context, via) {
            final color = via(themeColor.what);
            return _TestTheme(
              color: color,
              child: innerTree,
            );
          });
        }

        await tester.pumpWidget(MaterialApp(home: buildTree()));
        expect(parentBuildCount, equals(1));
        expect(composedBuildCount, equals(1));
        expect(
          identical(capturedOuterContext, capturedInnerContext),
          isFalse,
          reason: 'Inner context must be composed own element (descendant)',
        );

        // Update Theme
        themeColor.data = Colors.blue;
        await tester.pump();

        // Composed must rebuild because it accessed _TestTheme via innerContext,
        // but parent Builder must NOT rebuild!
        expect(parentBuildCount, equals(1));
        expect(composedBuildCount, equals(2));
      },
    );

    testWidgets(
      'Regression: regular composed does NOT rebuild on TickerMode toggle',
      (tester) async {
        var composedBuildCount = 0;
        final tickerEnabled = WhatController(true);

        final innerWidget = composed((context, via) {
          composedBuildCount++;
          return const Text('Static content');
        });

        await tester.pumpWidget(
          MaterialApp(
            home: composed((context, via) {
              final enabled = via(tickerEnabled.what);
              return TickerMode(
                enabled: enabled,
                child: innerWidget,
              );
            }),
          ),
        );

        expect(composedBuildCount, equals(1));

        // Toggle TickerMode
        tickerEnabled.data = false;
        await tester.pump();

        // The regular composed element must NOT register dependency on TickerMode,
        // so its buildCount should remain 1.
        expect(
          composedBuildCount,
          equals(1),
          reason: 'Regular composed must not depend on TickerMode',
        );
      },
    );

    testWidgets(
      'composed.vsync: drives multiple tickers, syncs TickerMode, cancels tickers on unmount',
      (tester) async {
        Ticker? ticker1;
        Ticker? ticker2;
        var ticker1Ticks = 0;
        var ticker2Ticks = 0;

        final showWidget = WhatController(true);
        final tickerEnabled = WhatController(true);

        Widget buildVsyncTree() {
          return composed((context, via) {
            final show = via(showWidget.what);
            final enabled = via(tickerEnabled.what);
            if (!show) {
              return const SizedBox.shrink();
            }
            return TickerMode(
              enabled: enabled,
              child: composed.vsync((context, via, vsync) {
                ticker1 ??= vsync.createTicker((_) => ticker1Ticks++);
                ticker2 ??= vsync.createTicker((_) => ticker2Ticks++);
                return const Text('Vsync active');
              }),
            );
          });
        }

        await tester.pumpWidget(MaterialApp(home: buildVsyncTree()));
        expect(ticker1, isNotNull);
        expect(ticker2, isNotNull);

        ticker1!.start();
        ticker2!.start();
        expect(ticker1!.isActive, isTrue);
        expect(ticker2!.isActive, isTrue);
        expect(ticker1!.isTicking, isTrue);
        expect(ticker2!.isTicking, isTrue);

        await tester.pump(const Duration(milliseconds: 50));
        expect(ticker1Ticks, greaterThan(0));
        expect(ticker2Ticks, greaterThan(0));

        // Mute via TickerMode
        tickerEnabled.data = false;
        await tester.pump();

        expect(ticker1!.isActive, isTrue);
        expect(ticker1!.isTicking, isFalse,
            reason: 'Ticker muted by TickerMode');
        expect(ticker2!.isTicking, isFalse,
            reason: 'Ticker muted by TickerMode');

        final ticksBeforeMute = ticker1Ticks;
        await tester.pump(const Duration(milliseconds: 50));
        expect(ticker1Ticks, equals(ticksBeforeMute));

        // Unmount
        showWidget.data = false;
        await tester.pump();

        expect(ticker1!.isActive, isFalse,
            reason: 'Ticker cancelled on unmount');
        expect(ticker2!.isActive, isFalse,
            reason: 'Ticker cancelled on unmount');
      },
    );

    testWidgets(
      'composed.animate: supplies context, binds controller lifecycle, fires onActivate/onDeactivate',
      (tester) async {
        final ctrl = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );
        var activatedCount = 0;
        var deactivatedCount = 0;
        BuildContext? capturedContext;
        ScopedAnimationController? scopedCtrl;

        final showWidget = WhatController(true);

        Widget buildTree() {
          return composed((context, via) {
            final show = via(showWidget.what);
            if (!show) {
              return const SizedBox.shrink();
            }
            return composed.animate(
              ctrl,
              (context, via, controller) {
                capturedContext = context;
                scopedCtrl = controller;
                return Text('Anim: ${controller.value.toStringAsFixed(2)}');
              },
              onActivate: (c) => activatedCount++,
              onDeactivate: (c) => deactivatedCount++,
            );
          });
        }

        await tester.pumpWidget(MaterialApp(home: buildTree()));

        expect(capturedContext, isNotNull);
        expect(scopedCtrl, isNotNull);
        expect(activatedCount, equals(1));
        expect(deactivatedCount, equals(0));

        // Unmount to test deactivate
        showWidget.data = false;
        await tester.pump();

        expect(deactivatedCount, equals(1));
      },
    );

    testWidgets(
      'composed.drive: supplies context and value, updates on every frame',
      (tester) async {
        BuildContext? capturedContext;
        final capturedValues = <double>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.drive<double>(
              (elapsed) => elapsed.inMilliseconds / 1000.0,
              (context, via, value) {
                capturedContext = context;
                capturedValues.add(value);
                return Text('Value: $value');
              },
            ),
          ),
        );

        expect(capturedContext, isNotNull);
        expect(capturedValues, isNotEmpty);
        final initialCount = capturedValues.length;

        await tester.pump(const Duration(milliseconds: 50));
        expect(capturedValues.length, greaterThan(initialCount));
        expect(capturedValues.last, greaterThan(0.0));
      },
    );
  });

  group('A6: Composed Child & Children Axis Suite', () {
    testWidgets(
      'composed.child: child build count remains 1 on reactive rebuild and received child is identical',
      (tester) async {
        var composedBuildCount = 0;
        var childBuildCount = 0;
        Widget? receivedChild;

        final counter = WhatController(0);
        final childWidget = _BuildCounterWidget(
          onBuild: () => childBuildCount++,
          label: 'static-child',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: composed.child(
              (context, via, child) {
                composedBuildCount++;
                receivedChild = child;
                final count = via(counter.what);
                return Column(
                  children: [
                    Text('Count: $count'),
                    child,
                  ],
                );
              },
              child: childWidget,
            ),
          ),
        );

        expect(composedBuildCount, equals(1));
        expect(childBuildCount, equals(1));
        expect(identical(receivedChild, childWidget), isTrue);

        // Mutate reactive state
        counter.data = 1;
        await tester.pump();

        expect(composedBuildCount, equals(2));
        expect(childBuildCount, equals(1),
            reason: 'Child must not rebuild when composed rebuilds');
        expect(identical(receivedChild, childWidget), isTrue);
      },
    );

    testWidgets(
      'composed.children: children build counts remain 1 when container property mutates',
      (tester) async {
        var composedBuildCount = 0;
        var childABuildCount = 0;
        var childBBuildCount = 0;
        List<Widget>? receivedChildren;

        final alignment = WhatController(MainAxisAlignment.start);
        final childA = _BuildCounterWidget(
          onBuild: () => childABuildCount++,
          label: 'child-A',
        );
        final childB = _BuildCounterWidget(
          onBuild: () => childBBuildCount++,
          label: 'child-B',
        );
        final childrenList = [childA, childB];

        await tester.pumpWidget(
          MaterialApp(
            home: composed.children(
              (context, via, children) {
                composedBuildCount++;
                receivedChildren = children;
                final align = via(alignment.what);
                return Row(
                  mainAxisAlignment: align,
                  children: children,
                );
              },
              children: childrenList,
            ),
          ),
        );

        expect(composedBuildCount, equals(1));
        expect(childABuildCount, equals(1));
        expect(childBBuildCount, equals(1));
        expect(identical(receivedChildren, childrenList), isTrue);

        // Mutate container layout property
        alignment.data = MainAxisAlignment.center;
        await tester.pump();

        expect(composedBuildCount, equals(2));
        expect(childABuildCount, equals(1), reason: 'childA must not rebuild');
        expect(childBBuildCount, equals(1), reason: 'childB must not rebuild');
      },
    );

    testWidgets(
      'composed.child: parent rebuilding with new child instance updates correctly (no stale child)',
      (tester) async {
        var childABuildCount = 0;
        var childBBuildCount = 0;
        final childSelector = WhatController(true);

        Widget buildTree() {
          return composed((context, via) {
            final selectA = via(childSelector.what);
            final activeChild = selectA
                ? _BuildCounterWidget(
                    key: const ValueKey('A'),
                    onBuild: () => childABuildCount++,
                    label: 'ChildA',
                  )
                : _BuildCounterWidget(
                    key: const ValueKey('B'),
                    onBuild: () => childBBuildCount++,
                    label: 'ChildB',
                  );

            return composed.child(
              (innerContext, innerVia, child) {
                return Container(child: child);
              },
              child: activeChild,
            );
          });
        }

        await tester.pumpWidget(MaterialApp(home: buildTree()));
        expect(childABuildCount, equals(1));
        expect(childBBuildCount, equals(0));
        expect(find.text('ChildA'), findsOneWidget);

        // Switch child instance from parent
        childSelector.data = false;
        await tester.pump();

        expect(childABuildCount, equals(1));
        expect(childBBuildCount, equals(1));
        expect(find.text('ChildB'), findsOneWidget);
      },
    );

    testWidgets(
      'composed.vsync.child: child does not rebuild during vsync ticker progress',
      (tester) async {
        var childBuildCount = 0;
        var composedBuildCount = 0;
        Ticker? activeTicker;

        final child = _BuildCounterWidget(
          onBuild: () => childBuildCount++,
          label: 'vsync-child',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync.child(
              (context, via, vsync, child) {
                composedBuildCount++;
                activeTicker ??= vsync.createTicker((_) {});
                return child;
              },
              child: child,
            ),
          ),
        );

        expect(composedBuildCount, equals(1));
        expect(childBuildCount, equals(1));
        activeTicker!.start();

        await tester.pump(const Duration(milliseconds: 50));
        expect(childBuildCount, equals(1),
            reason: 'Child must not rebuild during vsync activity');
      },
    );

    testWidgets(
      'composed.animate.child: child does not rebuild during controller animation',
      (tester) async {
        final ctrl = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );
        var childBuildCount = 0;

        final child = _BuildCounterWidget(
          onBuild: () => childBuildCount++,
          label: 'anim-child',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: composed.animate.child(
              ctrl,
              (context, via, controller, child) {
                return RotationTransition(
                  turns: controller.view,
                  child: child,
                );
              },
              child: child,
            ),
          ),
        );

        expect(childBuildCount, equals(1));

        ctrl.forward();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(childBuildCount, equals(1),
            reason: 'Child must not rebuild while controller animates');
      },
    );

    testWidgets(
      'composed.drive.child: child does not rebuild on frame ticker updates',
      (tester) async {
        var childBuildCount = 0;
        final child = _BuildCounterWidget(
          onBuild: () => childBuildCount++,
          label: 'drive-child',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: composed.drive.child<double>(
              (elapsed) => elapsed.inMilliseconds / 1000.0,
              (context, via, value, child) {
                return Column(
                  children: [
                    Text('Value: $value'),
                    child,
                  ],
                );
              },
              child: child,
            ),
          ),
        );

        expect(childBuildCount, equals(1));

        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(childBuildCount, equals(1),
            reason: 'Child must not rebuild on frame ticker ticks');
      },
    );

    testWidgets(
      'Regression: composed.child & composed.children do NOT rebuild on TickerMode toggle',
      (tester) async {
        var childComposedBuildCount = 0;
        var childrenComposedBuildCount = 0;
        final tickerEnabled = WhatController(true);

        final innerChildWidget = composed.child(
          (c, v, child) {
            childComposedBuildCount++;
            return child;
          },
          child: const Text('Child'),
        );

        final innerChildrenWidget = composed.children(
          (c, v, children) {
            childrenComposedBuildCount++;
            return Column(children: children);
          },
          children: const [Text('Children')],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: composed((context, via) {
              final enabled = via(tickerEnabled.what);
              return TickerMode(
                enabled: enabled,
                child: Column(
                  children: [
                    innerChildWidget,
                    innerChildrenWidget,
                  ],
                ),
              );
            }),
          ),
        );

        expect(childComposedBuildCount, equals(1));
        expect(childrenComposedBuildCount, equals(1));

        // Toggle TickerMode
        tickerEnabled.data = false;
        await tester.pump();

        expect(childComposedBuildCount, equals(1),
            reason: 'composed.child must not depend on TickerMode');
        expect(childrenComposedBuildCount, equals(1),
            reason: 'composed.children must not depend on TickerMode');
      },
    );
  });
}

class _BuildCounterWidget extends StatelessWidget {
  const _BuildCounterWidget({
    super.key,
    required this.onBuild,
    this.label = 'child',
  });

  final VoidCallback onBuild;
  final String label;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(label);
  }
}
