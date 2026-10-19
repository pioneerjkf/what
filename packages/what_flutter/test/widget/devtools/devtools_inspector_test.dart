// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

void main() {
  group('Flutter DevTools Inspector & Diagnostics Properties Tests', () {
    testWidgets(
        'exposes active What dependencies in DiagnosticsNode properties',
        (tester) async {
      final counter = WhatController(10)..debugLabel = 'counterState';
      final title = WhatController('Hello').withDebugLabel('titleState');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _InspectorProbeWidget(
            builder: (context, via) {
              return Text('${via(title.what)}: ${via(counter.what)}');
            },
          ),
        ),
      );

      final element = tester.element(find.byType(_InspectorProbeWidget));
      final diagnostics = element.toDiagnosticsNode();
      final properties = diagnostics.getProperties();

      final depProperties = properties
          .where((p) => p.name?.startsWith('what[') ?? false)
          .toList();
      expect(depProperties.length, equals(2));

      final titleProp = depProperties
          .firstWhere((p) => p.name?.contains('titleState') ?? false);
      expect(titleProp.value, contains('Hello'));

      final counterProp = depProperties
          .firstWhere((p) => p.name?.contains('counterState') ?? false);
      expect(counterProp.value, contains('10'));
    });

    testWidgets('real-time updates of inspector properties on What mutation',
        (tester) async {
      final count = WhatController(0)..debugLabel = 'liveCounter';

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _InspectorProbeWidget(
            builder: (context, via) => Text('Count: ${via(count.what)}'),
          ),
        ),
      );

      final element = tester.element(find.byType(_InspectorProbeWidget));
      var countProp = element
          .toDiagnosticsNode()
          .getProperties()
          .firstWhere((p) => p.name?.contains('liveCounter') ?? false);
      expect(countProp.value, contains('0 (v0)'));

      // Mutate state and pump frame
      count.set(42);
      await tester.pump();

      countProp = element
          .toDiagnosticsNode()
          .getProperties()
          .firstWhere((p) => p.name?.contains('liveCounter') ?? false);
      expect(countProp.value, contains('42 (v1)'));
    });

    testWidgets(
        'dynamic branching in build sweeps inactive dependencies in inspector properties',
        (tester) async {
      final showExtra = WhatController(true)..debugLabel = 'showFlag';
      final branchA = WhatController('Branch A').withDebugLabel('branchA');
      final branchB = WhatController('Branch B').withDebugLabel('branchB');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _InspectorProbeWidget(
            builder: (context, via) {
              if (via(showExtra.what)) {
                return Text(via(branchA.what));
              } else {
                return Text(via(branchB.what));
              }
            },
          ),
        ),
      );

      final element = tester.element(find.byType(_InspectorProbeWidget));

      // Phase 1: showExtra is true -> depends on showFlag and branchA
      var depNames = element
          .toDiagnosticsNode()
          .getProperties()
          .where((p) => p.name?.startsWith('what[') ?? false)
          .map((p) => p.name ?? '')
          .toList();
      expect(depNames.any((n) => n.contains('showFlag')), isTrue);
      expect(depNames.any((n) => n.contains('branchA')), isTrue);
      expect(depNames.any((n) => n.contains('branchB')), isFalse);

      // Phase 2: switch to false -> branchA swept, branchB subscribed
      showExtra.set(false);
      await tester.pump();

      depNames = element
          .toDiagnosticsNode()
          .getProperties()
          .where((p) => p.name?.startsWith('what[') ?? false)
          .map((p) => p.name ?? '')
          .toList();
      expect(depNames.any((n) => n.contains('showFlag')), isTrue);
      expect(depNames.any((n) => n.contains('branchA')), isFalse);
      expect(depNames.any((n) => n.contains('branchB')), isTrue);
    });

    testWidgets(
        'exposes "none (no active subscriptions)" when terminal has 0 dependencies',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _InspectorProbeWidget(
            builder: (context, via) => const Text('Static'),
          ),
        ),
      );

      final element = tester.element(find.byType(_InspectorProbeWidget));
      final properties = element.toDiagnosticsNode().getProperties();
      final emptyProp =
          properties.firstWhere((p) => p.name == 'whatDependencies');
      expect(emptyProp.value, equals('none (no active subscriptions)'));
    });

    testWidgets('exposes tethered effects in inspector properties',
        (tester) async {
      final counter = WhatController(10)..debugLabel = 'counter';
      final effect =
          Effect([counter.what], () {}).withDebugLabel('CounterLogger');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _InspectorProbeWidget(
            builder: (context, via) {
              via.tether(effect);
              return Text('Count: ${via(counter.what)}');
            },
          ),
        ),
      );

      final element = tester.element(find.byType(_InspectorProbeWidget));
      final properties = element.toDiagnosticsNode().getProperties();

      final tetherProp = properties.firstWhere((p) => p.name == 'tether[0]');
      expect(tetherProp.value, contains('CounterLogger'));

      final depProp =
          properties.firstWhere((p) => p.name?.contains('counter') ?? false);
      expect(depProp.value, contains('10'));
    });
  });
}

base class _InspectorProbeWidget extends WhatWidget {
  const _InspectorProbeWidget({required this.builder});
  final Widget Function(BuildContext context, WhatVia via) builder;

  @override
  Widget build(BuildContext context, WhatVia via) => builder(context, via);
}
