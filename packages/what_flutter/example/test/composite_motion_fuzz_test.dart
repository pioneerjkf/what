// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';
import 'package:what_flutter_example/sections/composite_motion_section.dart';
import 'package:what_flutter_example/store/showcase_store.dart';

void main() {
  testWidgets(
      'Combinatorial stress test on all controls in CompositeMotionSection',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rootStore = ShowcaseStore();
    final store = rootStore.sections.compositeMotion;

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

    // Define all user-facing interactions
    final actions = <String, Future<void> Function()>{
      'play_pause': () async {
        final btn = find.widgetWithText(
            FilledButton, store.isPlaying.peek ? 'Pause' : 'Play');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'ping_pong': () async {
        final btn = find.widgetWithText(OutlinedButton,
            store.isPingPong.peek ? 'Ping-Pong: ON' : 'Ping-Pong: OFF');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'forward': () async {
        final btn = find.widgetWithText(OutlinedButton, 'Forward');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'reverse': () async {
        final btn = find.widgetWithText(OutlinedButton, 'Reverse');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'reset': () async {
        final btn = find.widgetWithText(OutlinedButton, 'Reset');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'unmount_mount': () async {
        final btn = find.widgetWithText(FilledButton,
            store.isMounted.peek ? 'Unmount (Hibernate)' : 'Mount (Wake)');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'speed_fast': () async {
        final btn = find.text('1.2s Fast');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'speed_normal': () async {
        final btn = find.text('2.4s Normal');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'speed_slow': () async {
        final btn = find.text('4.0s Slow-Mo');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'policy_resume': () async {
        final btn = find.text('Resume');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'policy_catchup': () async {
        final btn = find.text('Catch-Up');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'policy_reset': () async {
        final btn = find.text('Reset');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'tab_origami': () async {
        final btn = find.text('3D Morphing Origami');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'tab_multicurve': () async {
        final btn = find.text('Multi-Curve Race');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'tab_chained': () async {
        final btn = find.text('Chained Sequence Orbit');
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'toggle_slide': () async {
        final chip = find.widgetWithText(FilterChip, 'Slide/Elevate');
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'toggle_tilt': () async {
        final chip = find.widgetWithText(FilterChip, '3D Tilt');
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'toggle_radius': () async {
        final chip = find.widgetWithText(FilterChip, 'Radius Morph');
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'toggle_gradient': () async {
        final chip = find.widgetWithText(FilterChip, 'Gradient');
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'toggle_badge': () async {
        final chip = find.widgetWithText(FilterChip, 'Elastic Badge');
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
      'toggle_cascade': () async {
        final chip = find.widgetWithText(FilterChip, 'Cascade Chips');
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    };

    final actionKeys = actions.keys.toList();
    final random = Random(42);

    // Run 100 random combinations
    for (int i = 0; i < 100; i++) {
      final key = actionKeys[random.nextInt(actionKeys.length)];
      await actions[key]!();

      // Check invariants
      expect(tester.takeException(), isNull,
          reason: 'Exception thrown after action $key at step $i');

      // Progress value must be valid
      final progress = store.masterProgress.peek;
      expect(progress.isNaN, isFalse, reason: 'Progress is NaN at step $i');
      expect(progress >= -0.01 && progress <= 1.01, isTrue,
          reason: 'Progress $progress out of range at step $i');
    }

    // Pump a second to verify no leaking animation or crash
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'State machine edge cases: completion sync, speed change, and policy switch',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rootStore = ShowcaseStore();
    final store = rootStore.sections.compositeMotion;

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

    // Case 1: Play Forward until completion -> isPlaying and button must reflect stopped state!
    final forwardBtn = find.widgetWithText(OutlinedButton, 'Forward');
    await tester.tap(forwardBtn);
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.isPlaying.peek, isTrue);

    // Pump past the 2400ms duration so forward completes
    await tester.pump(const Duration(milliseconds: 3000));

    // The animation has completed (stopped at 1.0)
    expect(store.masterCtrl.peek.isAnimating, isFalse,
        reason: 'Animation should have stopped at 1.0');
    expect(store.isPlaying.peek, isFalse,
        reason: 'isPlaying should be false when forward completes');

    // Case 2: Changing duration while paused
    store.reset();
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.isPlaying.peek, isFalse);

    // While paused at 0.0, set duration
    store.setDuration(1200);
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.isPlaying.peek, isFalse,
        reason: 'Changing duration while paused should NOT start playing!');

    // Case 3: Switch policy while at t = 0.5
    store.playForward();
    await tester.pump();
    await tester
        .pump(const Duration(milliseconds: 600)); // Halfway through 1200ms
    final halfwayT = store.masterCtrl.peek.value;

    // Switch policy to catchUp - value must be preserved!
    store.setPolicy(DurabilityPolicy.catchUp);
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.masterCtrl.peek.value, closeTo(halfwayT, 0.1),
        reason: 'Policy switch should preserve animation value');
  });

  testWidgets(
      'Reproduction: Reset policy -> Unmount -> Mount -> Play/Pause button and direction',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rootStore = ShowcaseStore();
    final store = rootStore.sections.compositeMotion;

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

    // Let animation play to t = 0.2 (< 0.5)
    await tester.pump(const Duration(milliseconds: 480));

    // 1. Select Reset policy
    final resetPolicyChip = find.text('Reset');
    await tester.tap(resetPolicyChip.first);
    await tester.pump(const Duration(milliseconds: 50));

    // Let it advance a bit
    await tester.pump(const Duration(milliseconds: 200));

    // 2. Unmount
    final unmountBtn = find.widgetWithText(FilledButton, 'Unmount (Hibernate)');
    await tester.tap(unmountBtn);
    await tester.pump(const Duration(milliseconds: 100));

    // 3. Mount
    final mountBtn = find.widgetWithText(FilledButton, 'Mount (Wake)');
    await tester.tap(mountBtn);
    await tester.pump(const Duration(milliseconds: 100));

    // Inspect UI button text
    final pauseBtnFinder = find.widgetWithText(FilledButton, 'Pause');
    final playBtnFinder = find.widgetWithText(FilledButton, 'Play');

    // 4. Click the button once
    if (pauseBtnFinder.evaluate().isNotEmpty) {
      await tester.tap(pauseBtnFinder);
    } else {
      await tester.tap(playBtnFinder);
    }
    await tester.pump(const Duration(milliseconds: 100));

    // 5. Click the button second time
    final secondBtn = find.widgetWithText(
        FilledButton, store.isPlaying.peek ? 'Pause' : 'Play');
    await tester.tap(secondBtn);
    await tester.pump(); // Flush tap and schedule first animation tick
    await tester
        .pump(const Duration(milliseconds: 100)); // Advance animation time

    // Assertions for reproduction test
    expect(store.masterCtrl.peek.value, greaterThan(0.0));
    expect(store.isPlaying.peek, isTrue);
  });

  testWidgets(
      'Reset policy during Reverse Phase: Unmount at t=0.49 moving left, then Remount',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rootStore = ShowcaseStore();
    final store = rootStore.sections.compositeMotion;

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

    // 1. Select Reset policy first
    final resetPolicyChip = find.text('Reset');
    await tester.tap(resetPolicyChip.first);
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.policy.peek, equals(DurabilityPolicy.reset));

    // Duration is 2400ms.
    // 0ms ~ 2400ms: Forward (0.0 -> 1.0)
    // 2400ms ~ 4800ms: Reverse (1.0 -> 0.0)
    // To get to t ~ 0.49 in reverse:
    // 2400ms + (1.0 - 0.49) * 2400ms = 2400ms + 1224ms = 3624ms
    await tester.pump(const Duration(milliseconds: 3624));
    final tBeforeUnmount = store.masterCtrl.peek.value;
    expect(tBeforeUnmount, closeTo(0.49, 0.05));
    expect(store.masterCtrl.peek.status, equals(AnimationStatus.reverse));

    // 2. Unmount (Hibernate)
    final unmountBtn = find.widgetWithText(FilledButton, 'Unmount (Hibernate)');
    await tester.tap(unmountBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.isMounted.peek, isFalse);

    // 3. Remount (Wake)
    final mountBtn = find.widgetWithText(FilledButton, 'Mount (Wake)');
    await tester.tap(mountBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.isMounted.peek, isTrue);

    // Under Reset policy, value should have reset cleanly to 0.0 (NOT 0.49 and NOT 0.85!)
    expect(store.masterCtrl.peek.value, closeTo(0.0, 0.05));
    // Since it was playing before unmount, it should restart playing forward from 0.0
    expect(store.isPlaying.peek, isTrue);
    expect(store.masterCtrl.peek.isAnimating, isTrue);
    expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);

    // Let it play forward 200ms
    await tester.pump(const Duration(milliseconds: 200));
    expect(store.masterCtrl.peek.value, greaterThan(0.0));
    expect(store.masterCtrl.peek.status, equals(AnimationStatus.forward));

    // 4. Now pause it
    final pauseBtn = find.widgetWithText(FilledButton, 'Pause');
    await tester.tap(pauseBtn);
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.isPlaying.peek, isFalse);
    expect(store.masterCtrl.peek.isAnimating, isFalse);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);

    // 5. Unmount while paused
    await tester.tap(find.widgetWithText(FilledButton, 'Unmount (Hibernate)'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.isMounted.peek, isFalse);

    // 6. Remount while paused
    await tester.tap(find.widgetWithText(FilledButton, 'Mount (Wake)'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.isMounted.peek, isTrue);

    // Must still be paused at 0.0!
    expect(store.isPlaying.peek, isFalse);
    expect(store.masterCtrl.peek.isAnimating, isFalse);
    expect(store.masterCtrl.peek.value, closeTo(0.0, 0.01));
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);

    // 7. Single tap on Play resumes playback from 0.0!
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.isPlaying.peek, isTrue);
    expect(store.masterCtrl.peek.isAnimating, isTrue);
    expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);
  });
}
