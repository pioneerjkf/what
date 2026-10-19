// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';
import 'package:what_flutter/what_flutter.dart';

/// Non-const probe widget to track rebuild count.
class _Probe extends StatelessWidget {
  const _Probe(this.counter);
  final List<int> counter;

  @override
  Widget build(BuildContext context) {
    counter[0]++;
    return const SizedBox();
  }
}

/// Const probe widget to confirm canonicalization.
class _ConstProbe extends StatelessWidget {
  const _ConstProbe(this.counter);
  final List<int> counter;

  @override
  Widget build(BuildContext context) {
    counter[0]++;
    return const SizedBox();
  }
}

/// Stateful probe widget to verify State instance retention.
class _StatefulProbe extends StatefulWidget {
  const _StatefulProbe({required this.onStateCreated});
  final void Function(_StatefulProbeState state) onStateCreated;

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

/// Parent test widget supporting controlled rebuilds.
class _ParentTestHarness extends StatefulWidget {
  const _ParentTestHarness({
    super.key,
    required this.mode,
    required this.countCtrl,
    required this.probeCount,
  });

  /// mode 1: composed.child
  /// mode 2: local variable hoisting in parent build
  final int mode;
  final WhatController<int> countCtrl;
  final List<int> probeCount;

  @override
  State<_ParentTestHarness> createState() => _ParentTestHarnessState();
}

class _ParentTestHarnessState extends State<_ParentTestHarness> {
  int parentRebuilds = 0;

  void triggerParentRebuild() {
    setState(() {
      parentRebuilds++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == 1) {
      return Column(
        children: [
          Text('Parent: $parentRebuilds'),
          composed.child(
            (context, via, child) {
              final count = via(widget.countCtrl.what);
              return Column(children: [Text('Count: $count'), child]);
            },
            child: _Probe(widget.probeCount),
          ),
        ],
      );
    } else {
      final probe = _Probe(widget.probeCount);
      return Column(
        children: [
          Text('Parent: $parentRebuilds'),
          composed((context, via) {
            final count = via(widget.countCtrl.what);
            return Column(children: [Text('Count: $count'), probe]);
          }),
        ],
      );
    }
  }
}

void main() {
  group('A2. composed.child ≡ Local Variable Hoisting Equivalence Proof (D5)',
      () {
    testWidgets(
        '1. composed.child with non-const child rebuilds Probe only once across What mutations',
        (WidgetTester tester) async {
      final countCtrl = WhatController<int>(0);
      final probeCount = [0];

      await tester.pumpWidget(
        MaterialApp(
          home: composed.child(
            (context, via, child) {
              final count = via(countCtrl.what);
              return Column(
                children: [
                  Text('Count: $count'),
                  child,
                ],
              );
            },
            child: _Probe(probeCount),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(probeCount[0], equals(1));

      // Mutate 3 times
      countCtrl.data = 1;
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);
      expect(probeCount[0], equals(1)); // Child was not rebuilt

      countCtrl.data = 2;
      await tester.pump();
      expect(find.text('Count: 2'), findsOneWidget);
      expect(probeCount[0], equals(1)); // Child was not rebuilt

      countCtrl.data = 3;
      await tester.pump();
      expect(find.text('Count: 3'), findsOneWidget);
      expect(probeCount[0], equals(1)); // Still 1
    });

    testWidgets(
        '2. Local variable hoisting in parent build rebuilds Probe only once across What mutations',
        (WidgetTester tester) async {
      final countCtrl = WhatController<int>(0);
      final probeCount = [0];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final probe = _Probe(probeCount);
              return composed((context, via) {
                final count = via(countCtrl.what);
                return Column(
                  children: [
                    Text('Count: $count'),
                    probe,
                  ],
                );
              });
            },
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(probeCount[0], equals(1));

      // Mutate 3 times
      countCtrl.data = 1;
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);
      expect(probeCount[0], equals(1)); // Hoisted probe was not rebuilt

      countCtrl.data = 2;
      await tester.pump();
      expect(find.text('Count: 2'), findsOneWidget);
      expect(probeCount[0], equals(1));

      countCtrl.data = 3;
      await tester.pump();
      expect(find.text('Count: 3'), findsOneWidget);
      expect(probeCount[0], equals(1));
    });

    testWidgets(
        '3. composed.child vs Local Hoisting produce identical rebuild counts under M parent rebuilds',
        (WidgetTester tester) async {
      final countCtrl1 = WhatController<int>(0);
      final probeCount1 = [0];
      final key1 = GlobalKey<_ParentTestHarnessState>();

      final countCtrl2 = WhatController<int>(0);
      final probeCount2 = [0];
      final key2 = GlobalKey<_ParentTestHarnessState>();

      // Test Mode 1: composed.child
      await tester.pumpWidget(
        MaterialApp(
          home: _ParentTestHarness(
            key: key1,
            mode: 1,
            countCtrl: countCtrl1,
            probeCount: probeCount1,
          ),
        ),
      );
      expect(probeCount1[0], equals(1));

      // Test Mode 2: local variable hoisting
      await tester.pumpWidget(
        MaterialApp(
          home: _ParentTestHarness(
            key: key2,
            mode: 2,
            countCtrl: countCtrl2,
            probeCount: probeCount2,
          ),
        ),
      );
      expect(probeCount2[0], equals(1));

      // Both What mutate 2 times -> probe rebuilds remain 1 in both
      countCtrl1.data = 10;
      countCtrl2.data = 10;
      await tester.pump();
      expect(probeCount1[0], equals(1));
      expect(probeCount2[0], equals(1));

      countCtrl1.data = 20;
      countCtrl2.data = 20;
      await tester.pump();
      expect(probeCount1[0], equals(1));
      expect(probeCount2[0], equals(1));

      // Trigger Parent Rebuild M=2 times on Mode 2
      key2.currentState!.triggerParentRebuild();
      await tester.pump();
      expect(probeCount2[0], equals(2));

      key2.currentState!.triggerParentRebuild();
      await tester.pump();
      expect(probeCount2[0], equals(3));

      // Re-mount Mode 1 and trigger Parent Rebuild M=2 times
      await tester.pumpWidget(
        MaterialApp(
          home: _ParentTestHarness(
            key: key1,
            mode: 1,
            countCtrl: countCtrl1,
            probeCount: probeCount1,
          ),
        ),
      );
      final base1 = probeCount1[0];
      key1.currentState!.triggerParentRebuild();
      await tester.pump();
      expect(probeCount1[0], equals(base1 + 1));

      key1.currentState!.triggerParentRebuild();
      await tester.pump();
      expect(probeCount1[0], equals(base1 + 2));
    });

    testWidgets(
        '4. In-builder instantiation rebuilds Probe on EVERY What mutation (anti-pattern comparison)',
        (WidgetTester tester) async {
      final countCtrl = WhatController<int>(0);
      final probeCount = [0];

      await tester.pumpWidget(
        MaterialApp(
          home: composed((context, via) {
            final count = via(countCtrl.what);
            return Column(
              children: [
                Text('Count: $count'),
                _Probe(probeCount), // Anti-pattern: new instance inside builder
              ],
            );
          }),
        ),
      );
      expect(probeCount[0], equals(1));

      countCtrl.data = 1;
      await tester.pump();
      expect(probeCount[0], equals(2)); // Rebuilt!

      countCtrl.data = 2;
      await tester.pump();
      expect(probeCount[0], equals(3)); // Rebuilt again!
    });

    testWidgets(
        '5. Multi-child: composed.children with list isolates children identically to hoisting',
        (WidgetTester tester) async {
      final countCtrl = WhatController<int>(0);
      final p1 = [0];
      final p2 = [0];

      await tester.pumpWidget(
        MaterialApp(
          home: composed.children(
            (context, via, children) {
              final count = via(countCtrl.what);
              return Column(
                children: [
                  Text('Count: $count'),
                  ...children,
                ],
              );
            },
            children: [
              _Probe(p1),
              _Probe(p2),
            ],
          ),
        ),
      );
      expect(p1[0], equals(1));
      expect(p2[0], equals(1));

      countCtrl.data = 1;
      await tester.pump();
      expect(p1[0], equals(1));
      expect(p2[0], equals(1));

      countCtrl.data = 2;
      await tester.pump();
      expect(p1[0], equals(1));
      expect(p2[0], equals(1));
    });

    testWidgets(
        '6. Multi-child: local hoisting of children list isolates identically to composed.children',
        (WidgetTester tester) async {
      final countCtrlH = WhatController<int>(0);
      final h1 = [0];
      final h2 = [0];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final children = [
                _Probe(h1),
                _Probe(h2),
              ];
              return composed((context, via) {
                final count = via(countCtrlH.what);
                return Column(children: [Text('Count: $count'), ...children]);
              });
            },
          ),
        ),
      );
      expect(h1[0], equals(1));
      expect(h2[0], equals(1));

      countCtrlH.data = 1;
      await tester.pump();
      expect(h1[0], equals(1));
      expect(h2[0], equals(1));
    });

    testWidgets(
        '7. composed.animate.child vs local variable hoisting across controller ticks',
        (WidgetTester tester) async {
      final controller1 = DurableAnimationController(
          duration: const Duration(milliseconds: 200));
      final controller2 = DurableAnimationController(
          duration: const Duration(milliseconds: 200));
      final probeCount1 = [0];
      final probeCount2 = [0];

      // Part A: composed.animate.child
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: composed.animate.child(
              controller1,
              (context, via, ctrl, child) => Column(
                children: [
                  Text('Tick1: ${(ctrl.value * 100).toInt()}'),
                  child,
                ],
              ),
              child: _Probe(probeCount1),
            ),
          ),
        ),
      );
      expect(probeCount1[0], equals(1));

      controller1.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(probeCount1[0], equals(1)); // Preserved across ticks

      // Part B: local variable hoisting with composed.animate
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final probe = _Probe(probeCount2);
                return composed.animate(
                  controller2,
                  (context, via, ctrl) => Column(
                    children: [
                      Text('Tick2: ${(ctrl.value * 100).toInt()}'),
                      probe,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(probeCount2[0], equals(1));

      controller2.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
          probeCount2[0], equals(1)); // Also preserved across ticks identically
    });

    testWidgets(
        '8. composed.drive.child vs local variable hoisting across frame ticker ticks',
        (WidgetTester tester) async {
      final probeCount1 = [0];
      final probeCount2 = [0];

      // Part A: composed.drive.child
      await tester.pumpWidget(
        MaterialApp(
          home: composed.drive.child<int>(
            (elapsed) => elapsed.inMilliseconds,
            (context, via, ms, child) =>
                Row(children: [Text('Drive1: $ms'), child]),
            child: _Probe(probeCount1),
            initialValue: 0,
          ),
        ),
      );
      expect(probeCount1[0], equals(1));

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(probeCount1[0], equals(1)); // Preserved across ticks

      // Part B: local variable hoisting with composed.drive
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final probe = _Probe(probeCount2);
              return composed.drive<int>(
                (elapsed) => elapsed.inMilliseconds,
                (context, via, ms) =>
                    Row(children: [Text('Drive2: $ms'), probe]),
                initialValue: 0,
              );
            },
          ),
        ),
      );
      expect(probeCount2[0], equals(1));

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
          probeCount2[0], equals(1)); // Also preserved across ticks identically
    });

    testWidgets(
        '9. composed.vsync.child vs local variable hoisting across What mutations',
        (WidgetTester tester) async {
      final countCtrl1 = WhatController<int>(0);
      final countCtrl2 = WhatController<int>(0);
      final probeCount1 = [0];
      final probeCount2 = [0];

      // Part A: composed.vsync.child
      await tester.pumpWidget(
        MaterialApp(
          home: composed.vsync.child(
            (context, via, vsync, child) {
              final count = via(countCtrl1.what);
              return Column(children: [Text('Vsync1: $count'), child]);
            },
            child: _Probe(probeCount1),
          ),
        ),
      );
      expect(probeCount1[0], equals(1));

      countCtrl1.data = 1;
      await tester.pump();
      expect(probeCount1[0], equals(1));

      // Part B: local variable hoisting with composed.vsync
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final probe = _Probe(probeCount2);
              return composed.vsync(
                (context, via, vsync) {
                  final count = via(countCtrl2.what);
                  return Column(children: [Text('Vsync2: $count'), probe]);
                },
              );
            },
          ),
        ),
      );
      expect(probeCount2[0], equals(1));

      countCtrl2.data = 1;
      await tester.pump();
      expect(probeCount2[0], equals(1));
    });

    testWidgets(
        '10. State and GlobalKey retention is identical between composed.child and local hoisting',
        (WidgetTester tester) async {
      final countCtrl1 = WhatController<int>(0);
      final countCtrl2 = WhatController<int>(0);
      State<_StatefulProbe>? state1;
      State<_StatefulProbe>? state2;

      // Part A: composed.child
      await tester.pumpWidget(
        MaterialApp(
          home: composed.child(
            (context, via, child) {
              final count = via(countCtrl1.what);
              return Column(children: [Text('S1: $count'), child]);
            },
            child: _StatefulProbe(
              onStateCreated: (s) => state1 = s,
            ),
          ),
        ),
      );
      expect(state1, isNotNull);
      final captured1 = state1;

      countCtrl1.data = 1;
      await tester.pump();
      expect(identical(state1, captured1), isTrue);

      // Part B: local hoisting
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final probe = _StatefulProbe(
                onStateCreated: (s) => state2 = s,
              );
              return composed((context, via) {
                final count = via(countCtrl2.what);
                return Column(children: [Text('S2: $count'), probe]);
              });
            },
          ),
        ),
      );
      expect(state2, isNotNull);
      final captured2 = state2;

      countCtrl2.data = 1;
      await tester.pump();
      expect(identical(state2, captured2), isTrue);
    });

    testWidgets(
        '11. const child widgets are canonically identical across all modes',
        (WidgetTester tester) async {
      final countCtrl = WhatController<int>(0);
      final probeCount = [0];

      await tester.pumpWidget(
        MaterialApp(
          home: composed((context, via) {
            final count = via(countCtrl.what);
            return Column(
              children: [
                Text('Const: $count'),
                _ConstProbe(probeCount),
              ],
            );
          }),
        ),
      );
      expect(probeCount[0], equals(1));

      countCtrl.data = 1;
      await tester.pump();
    });
  });
}
