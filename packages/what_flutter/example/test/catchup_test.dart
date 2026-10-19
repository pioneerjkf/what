// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';
import 'package:what_flutter_example/sections/dormant_thrashing_section.dart';
import 'package:what_flutter_example/sections/dual_engine_battle_section.dart';
import 'package:what_flutter_example/sections/physics_bounds_section.dart';
import 'package:what_flutter_example/sections/simulation_flapping_section.dart';
import 'package:what_flutter_example/store/showcase_store.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
      'DualEngineBattleSectionDemo correctly mounts and handles dormancy',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = ShowcaseStore();

    await tester.pumpWidget(
      What.constant(store).provide(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DualEngineBattleSectionDemo(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Frozen (Freeze & Resume)'), findsOneWidget);
    expect(find.text('CatchUp (Time-Compensated)'), findsOneWidget);

    // Tap Unmount (Hide) button
    await tester.tap(find.text('Unmount (Hide)'));
    await tester.pump();

    // Verify dormant state
    expect(
        find.text('Widgets are Dormant (Unmounted from Tree)'), findsOneWidget);

    // Tap Remount (Show) button
    await tester.tap(find.text('Remount (Show)'));
    await tester.pump();

    // Verify reactivated state
    expect(find.text('Frozen (Freeze & Resume)'), findsOneWidget);

    store.sections.dualEngineBattle.frozenCtrl.stop();
    store.sections.dualEngineBattle.catchUpCtrl.stop();
  });

  testWidgets(
      'PhysicsBoundsSectionDemo with stiffness 200 and damping 30 settles at exactly 1.000',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
    final store = ShowcaseStore(clock: () => currentTime);
    store.sections.physicsBounds.setSpringStiffness(200.0);
    store.sections.physicsBounds.setSpringDamping(30.0);

    await tester.pumpWidget(
      What.constant(store).provide(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PhysicsBoundsSectionDemo(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tap SpringSimulation (Bounce)
    await tester.tap(find.text('SpringSimulation (Bounce)'));
    await tester.pump();
    await tester.pump(
        const Duration(milliseconds: 350)); // ~0.35s in mid-air (val ~0.948)

    final resValueBefore =
        store.sections.physicsBounds.physicsBoundedFrozenCtrl.value;
    final catchUpValueBefore =
        store.sections.physicsBounds.physicsBoundedCatchUpCtrl.value;

    print(
        'Before unmount (mid-air): Frozen=$resValueBefore, CatchUp=$catchUpValueBefore');
    expect(catchUpValueBefore, closeTo(0.948, 0.05));

    // Tap Unmount (Hide)
    await tester.tap(find.text('Unmount (Hide)'));
    await tester.pump();

    // Advance clock by 3 seconds while unmounted
    currentTime = currentTime.add(const Duration(seconds: 3));

    // Tap Remount (Show)
    await tester.tap(find.text('Remount (Show)'));
    await tester.pump();

    final resValueAfter =
        store.sections.physicsBounds.physicsBoundedFrozenCtrl.value;
    final catchUpValueAfter =
        store.sections.physicsBounds.physicsBoundedCatchUpCtrl.value;

    print(
        'After remount (3s passed): Frozen=$resValueAfter, CatchUp=$catchUpValueAfter');
    expect(
        catchUpValueAfter, equals(1.0)); // [Invariant] Must be exactly 1.000!

    store.sections.physicsBounds.physicsBoundedFrozenCtrl.stop();
    store.sections.physicsBounds.physicsBoundedCatchUpCtrl.stop();
  });

  testWidgets(
      'PhysicsBoundsSectionDemo with default parameters unmounted immediately and remounted after 3s',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
    final store = ShowcaseStore(clock: () => currentTime);

    await tester.pumpWidget(
      What.constant(store).provide(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PhysicsBoundsSectionDemo(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tap SpringSimulation (Bounce)
    await tester.tap(find.text('SpringSimulation (Bounce)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 236)); // ~0.236s in mid-air

    final resValueBefore =
        store.sections.physicsBounds.physicsBoundedFrozenCtrl.value;
    final catchUpValueBefore =
        store.sections.physicsBounds.physicsBoundedCatchUpCtrl.value;

    print(
        'Before unmount: Frozen=$resValueBefore, CatchUp=$catchUpValueBefore');

    // Tap Unmount (Hide)
    await tester.tap(find.text('Unmount (Hide)'));
    await tester.pump();

    // Advance clock by 3 seconds while unmounted
    currentTime = currentTime.add(const Duration(seconds: 3));

    // Tap Remount (Show)
    await tester.tap(find.text('Remount (Show)'));
    await tester.pump();

    final resValueAfter =
        store.sections.physicsBounds.physicsBoundedFrozenCtrl.value;
    final catchUpValueAfter =
        store.sections.physicsBounds.physicsBoundedCatchUpCtrl.value;

    print('After remount: Frozen=$resValueAfter, CatchUp=$catchUpValueAfter');

    // Let 1 frame tick
    await tester.pump(const Duration(milliseconds: 50));
    final resValueAfterTick =
        store.sections.physicsBounds.physicsBoundedFrozenCtrl.value;
    final catchUpValueAfterTick =
        store.sections.physicsBounds.physicsBoundedCatchUpCtrl.value;
    print(
        'After tick: Frozen=$resValueAfterTick, CatchUp=$catchUpValueAfterTick');

    store.sections.physicsBounds.physicsBoundedFrozenCtrl.stop();
    store.sections.physicsBounds.physicsBoundedCatchUpCtrl.stop();
  });

  testWidgets(
      'DormantThrashingSectionDemo handles commands while unmounted for both Frozen and CatchUp',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
    final store = ShowcaseStore(clock: () => currentTime);

    await tester.pumpWidget(
      What.constant(store).provide(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DormantThrashingSectionDemo(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Frozen (Freeze & Staged Replay)'), findsOneWidget);
    expect(find.text('CatchUp (Time-Compensated)'), findsOneWidget);

    // 1. Unmount to enter dormancy
    final unmountBtn = find.text('Unmount (Hide)');
    await tester.ensureVisible(unmountBtn);
    await tester.tap(unmountBtn);
    await tester.pump();

    expect(find.text('Visual Renderer Suspended (Both Engines Dormant)'),
        findsOneWidget);

    // 2. Smash commands during dormancy
    final forwardBtn = find.text('.forward()');
    await tester.ensureVisible(forwardBtn);
    await tester.tap(forwardBtn);
    await tester.pump();

    final animateBtn = find.text('.animateTo(0.8, bounce)');
    await tester.ensureVisible(animateBtn);
    await tester.tap(animateBtn);
    await tester.pump();

    expect(store.sections.dormantThrashing.lastStagedAction.peek,
        contains('animateTo(0.8'));

    // 3. Advance wall-clock time by 2 seconds while dormant (duration is 3s)
    currentTime = currentTime.add(const Duration(seconds: 2));

    // 4. Remount
    final remountBtn = find.text('Remount & Play');
    await tester.ensureVisible(remountBtn);
    await tester.tap(remountBtn);
    await tester.pump();

    expect(find.text('Frozen (Freeze & Staged Replay)'), findsOneWidget);
    expect(find.text('CatchUp (Time-Compensated)'), findsOneWidget);

    // CatchUp advanced by 2s out of 3s, so its value should be significantly higher than 0.0
    final catchUpValue = store.sections.dormantThrashing.catchUpCtrl.value;
    expect(catchUpValue, greaterThan(0.0));

    store.sections.dormantThrashing.frozenCtrl.stop();
    store.sections.dormantThrashing.catchUpCtrl.stop();
  });

  testWidgets(
      'SimulationFlappingSectionDemo executes spring, gravity and flapping stress test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = ShowcaseStore();

    await tester.pumpWidget(
      What.constant(store).provide(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SimulationFlappingSectionDemo(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Frozen Physics'), findsOneWidget);
    expect(find.text('CatchUp Physics'), findsOneWidget);

    // 1. Trigger Spring (Bounce)
    final springBtn = find.text('Spring (Bounce)');
    await tester.ensureVisible(springBtn);
    await tester.tap(springBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 2. Reverse direction
    final reverseBtn = find.text('Reverse');
    await tester.ensureVisible(reverseBtn);
    await tester.tap(reverseBtn);
    await tester.pump();

    expect(store.sections.simulationFlapping.activeSimulationType.peek,
        contains('Upward'));

    // 3. Unmount & Remount during physics simulation
    final unmountBtn = find.text('Unmount (Hide)');
    await tester.ensureVisible(unmountBtn);
    await tester.tap(unmountBtn);
    await tester.pump();

    expect(
        find.text('Physics Engines Detached (Dormant State)'), findsOneWidget);

    final remountBtn = find.text('Remount (Show)');
    await tester.ensureVisible(remountBtn);
    await tester.tap(remountBtn);
    await tester.pump();

    expect(find.text('Frozen Physics'), findsOneWidget);
    expect(find.text('CatchUp Physics'), findsOneWidget);

    store.sections.simulationFlapping.frozenPhysicsCtrl.stop();
    store.sections.simulationFlapping.catchUpPhysicsCtrl.stop();
  });
}
