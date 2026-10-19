// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/src/animation/durable/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DurableAnimationController Inline Animate Functor Test Suite', () {
    // =========================================================================
    // 1. composed.animate Direct Self-Vsync Functor Tests
    // =========================================================================
    group('1. Direct composed.animate() Functors (Self-Vsync)', () {
      testWidgets(
          'composed.animate() directly renders widget, performs 60/120fps rebuilds and manages lifecycle',
          (WidgetTester tester) async {
        final ctrl = DurableAnimationController(
          duration: const Duration(milliseconds: 300),
        );

        expect(ctrl.isDormant, isTrue);
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed.animate(
                ctrl,
                (context, via, controller) {
                  buildCount++;
                  return Text('Progress: ${(controller.value * 100).toInt()}%');
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Progress: 0%'), findsOneWidget);
        expect(ctrl.isDormant, isFalse);
        expect(buildCount, equals(1));

        // Animate
        final forwardFuture = ctrl.forward();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('Progress: 50%'), findsOneWidget);
        expect(buildCount, greaterThan(1));

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        await forwardFuture;
        expect(ctrl.isCompleted, isTrue);
        expect(find.text('Progress: 100%'), findsOneWidget);

        // Unmount -> controller detaches safely
        await tester.pumpWidget(const SizedBox());
        expect(ctrl.isDormant, isTrue);
        expect(ctrl.value, equals(1.0)); // State preserved!

        ctrl.hibernate();
      });

      testWidgets('composed.animate() accesses BuildContext',
          (WidgetTester tester) async {
        final ctrl = DurableAnimationController();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(primaryColor: Colors.purple),
            home: Scaffold(
              body: composed.animate(
                ctrl,
                (context, via, controller) => Container(
                  color: Theme.of(context).primaryColor,
                  child: const Text('Context Self-Vsync'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Context Self-Vsync'), findsOneWidget);
        ctrl.hibernate();
      });

      testWidgets('composed.animate.child() isolates static child',
          (WidgetTester tester) async {
        final ctrl = DurableAnimationController(
            duration: const Duration(milliseconds: 300));
        var childBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed.animate.child(
                ctrl,
                (context, via, controller, child) => Column(
                  children: [
                    Text('Value: ${(controller.value * 100).toInt()}%'),
                    child,
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    childBuildCount++;
                    return const Text('Isolated Self-Vsync Child');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Isolated Self-Vsync Child'), findsOneWidget);
        expect(find.text('Value: 0%'), findsOneWidget);
        expect(childBuildCount, equals(1));

        ctrl.forward();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('Value: 50%'), findsOneWidget);
        // Static child remains built only 1 time!
        expect(childBuildCount, equals(1));

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(childBuildCount, equals(1));

        ctrl.hibernate();
      });

      testWidgets('composed.animate.children() renders multi-child widget',
          (WidgetTester tester) async {
        final ctrl = DurableAnimationController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: composed.animate.children(
                ctrl,
                (context, via, controller, children) => Row(children: children),
                children: const [Text('Item 1'), Text('Item 2')],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        ctrl.hibernate();
      });
    });

    // =========================================================================
    // 2. WhatWidget Lifecycle and Reassemble
    // =========================================================================
    group('2. WhatWidget Lifecycle and Reassemble', () {
      testWidgets('WhatWidget updates and supports reassemble',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: _ReassembleProbeWhatWidget(text: 'Initial Host'),
          ),
        );
        expect(find.text('Initial Host'), findsOneWidget);

        // Update widget with new builder instance -> triggers update
        await tester.pumpWidget(
          const MaterialApp(
            home: _ReassembleProbeWhatWidget(text: 'Updated Host'),
          ),
        );
        expect(find.text('Updated Host'), findsOneWidget);

        // Trigger element.reassemble() on _ViaTerminalElementMixin
        final element = tester.element(find.byType(_ReassembleProbeWhatWidget));
        // ignore: invalid_use_of_protected_member
        element.reassemble();
        await tester.pump();
        expect(find.text('Updated Host'), findsOneWidget);
      });
    });
  });
}

base class _ReassembleProbeWhatWidget extends WhatWidget {
  const _ReassembleProbeWhatWidget({required this.text});
  final String text;

  @override
  Widget build(BuildContext context, WhatVia via) => Text(text);
}
