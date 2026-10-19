// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';
import 'package:what_flutter_example/sections/composite_motion_section.dart';
import 'package:what_flutter_example/store/showcase_store.dart';

void main() {
  group('CompositeMotionStore Tests', () {
    test('initializes with expected defaults and repeat mode', () {
      final store = CompositeMotionStore();
      expect(store.isMounted.peek, isTrue);
      expect(store.isPlaying.peek, isTrue);
      expect(store.isPingPong.peek, isTrue);
      expect(store.activeTab.peek, 0);
      expect(store.durationMs.peek, 2400);

      // Verify sub-animation toggle defaults
      expect(store.enableSlideElevation.peek, isTrue);
      expect(store.enable3DRotation.peek, isTrue);
      expect(store.enableBorderRadius.peek, isTrue);
      expect(store.enableColorGradient.peek, isTrue);
      expect(store.enableElasticBadge.peek, isTrue);
      expect(store.enableStaggeredCascade.peek, isTrue);
    });

    test('toggles playback and ping-pong state correctly', () {
      final store = CompositeMotionStore();

      store.togglePlay();
      expect(store.isPlaying.peek, isFalse);

      store.togglePlay();
      expect(store.isPlaying.peek, isTrue);

      store.togglePingPong();
      expect(store.isPingPong.peek, isFalse);

      store.togglePingPong();
      expect(store.isPingPong.peek, isTrue);
    });

    test('sets duration and switches active tabs', () {
      final store = CompositeMotionStore();

      store.setDuration(1200);
      expect(store.durationMs.peek, 1200);
      expect(
          store.masterCtrl.peek.duration, const Duration(milliseconds: 1200));

      store.setActiveTab(1);
      expect(store.activeTab.peek, 1);

      store.setActiveTab(2);
      expect(store.activeTab.peek, 2);
    });

    test('switches durability policy and hot-swaps master controller', () {
      final store = CompositeMotionStore();
      final ctrl0 = store.masterCtrl.peek;
      expect(store.policy.peek, DurabilityPolicy.resume);
      expect(ctrl0.policy, DurabilityPolicy.resume);

      store.setPolicy(DurabilityPolicy.catchUp);
      final ctrl1 = store.masterCtrl.peek;
      expect(store.policy.peek, DurabilityPolicy.catchUp);
      expect(ctrl1.policy, DurabilityPolicy.catchUp);
      expect(identical(ctrl1, ctrl0), isFalse);

      store.setPolicy(DurabilityPolicy.reset);
      final ctrl2 = store.masterCtrl.peek;
      expect(store.policy.peek, DurabilityPolicy.reset);
      expect(ctrl2.policy, DurabilityPolicy.reset);
      expect(identical(ctrl2, ctrl1), isFalse);

      // Setting same policy is a no-op
      store.setPolicy(DurabilityPolicy.reset);
      expect(identical(store.masterCtrl.peek, ctrl2), isTrue);
    });

    test('toggles individual sub-animation isolation flags', () {
      final store = CompositeMotionStore();

      store.toggleSlideElevation();
      expect(store.enableSlideElevation.peek, isFalse);

      store.toggle3DRotation();
      expect(store.enable3DRotation.peek, isFalse);

      store.toggleBorderRadius();
      expect(store.enableBorderRadius.peek, isFalse);

      store.toggleColorGradient();
      expect(store.enableColorGradient.peek, isFalse);

      store.toggleElasticBadge();
      expect(store.enableElasticBadge.peek, isFalse);

      store.toggleStaggeredCascade();
      expect(store.enableStaggeredCascade.peek, isFalse);
    });
  });

  group('CompositeMotionSectionDemo Widget Tests', () {
    testWidgets('renders all tabs and switches seamlessly without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final rootStore = ShowcaseStore();

      await tester.pumpWidget(
        What.constant(rootStore).provide(
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CompositeMotionSectionDemo(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Initial Origami Tab rendered
      expect(find.text('Composite Motion & Multi-Tween Choreography'),
          findsOneWidget);
      expect(find.text('Origami Morphing Entity'), findsOneWidget);
      expect(find.text('3D Morphing Origami'), findsOneWidget);

      // 2. Switch to Multi-Curve Race Tab
      final store = rootStore.sections.compositeMotion;
      store.setActiveTab(1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('5 Concurrent Curves driven by Single Master Timeline:'),
          findsOneWidget);
      expect(find.text('ElasticOut'), findsOneWidget);
      expect(find.text('BounceOut'), findsOneWidget);

      // 3. Switch to Chained Sequence Orbit Tab
      store.setActiveTab(2);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.satellite_alt_rounded), findsOneWidget);

      // 3.5. Test Policy switching via UI chips
      final catchUpChip =
          find.byTooltip('Compensates wall-clock elapsed time while unmounted');
      expect(catchUpChip, findsOneWidget);
      await tester.ensureVisible(catchUpChip);
      await tester.tap(catchUpChip);
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.policy.peek, DurabilityPolicy.catchUp);

      final resetChip = find.byTooltip(
          'Discards progress and restarts from beginning upon remount');
      expect(resetChip, findsOneWidget);
      await tester.ensureVisible(resetChip);
      await tester.tap(resetChip);
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.policy.peek, DurabilityPolicy.reset);

      // 4. Test Dormancy Unmount Toggle and verify Reset policy text in placeholder
      store.toggleMount();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Subtrees Unmounted & Hibernated'), findsOneWidget);
      expect(find.textContaining('Policy: Reset'), findsOneWidget);

      // 5. Remount and verify resumption
      store.toggleMount();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.satellite_alt_rounded), findsOneWidget);

      // 6. Test forward / reverse / reset buttons
      store.reset();
      await tester.pump(const Duration(milliseconds: 50));
      store.playForward();
      await tester.pump(const Duration(milliseconds: 50));
      store.playReverse();
      await tester.pump(const Duration(milliseconds: 50));

      // Flush remaining ticks safely
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
