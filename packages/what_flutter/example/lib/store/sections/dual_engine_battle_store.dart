// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/dual_engine_battle_section.dart';

/// Sub-store for Section 13: Dual Engine Battle & Unbounded Motion
class DualEngineBattleStore {
  DualEngineBattleStore({DateTime Function()? clock})
      : frozenCtrl = DurableAnimationController(
          policy: DurabilityPolicy.resume,
          duration: const Duration(seconds: 4),
        ),
        catchUpCtrl = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          duration: const Duration(seconds: 4),
          clock: clock ?? DateTime.now,
        ),
        unboundedFrozenCtrl = DurableAnimationController.unbounded(
          value: 0.0,
        ),
        unboundedCatchUpCtrl = DurableAnimationController.unbounded(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 6),
          clock: clock ?? DateTime.now,
        ),
        _isMounted = WhatController<bool>(true),
        _isSleeping = WhatController<bool>(false),
        _isPingPong = WhatController<bool>(false),
        _isUnboundedMode = WhatController<bool>(false),
        _unboundedTarget = WhatController<double>(0.0) {
    frozenCtrl.repeat();
    catchUpCtrl.repeat();
  }

  final DurableAnimationController frozenCtrl;
  final DurableAnimationController catchUpCtrl;
  final DurableAnimationController unboundedFrozenCtrl;
  final DurableAnimationController unboundedCatchUpCtrl;

  final WhatController<bool> _isMounted;
  final WhatController<bool> _isSleeping;
  final WhatController<bool> _isPingPong;
  final WhatController<bool> _isUnboundedMode;
  final WhatController<double> _unboundedTarget;

  What<bool> get isMounted => _isMounted.what;
  What<bool> get isSleeping => _isSleeping.what;
  What<bool> get isPingPong => _isPingPong.what;
  What<bool> get isUnboundedMode => _isUnboundedMode.what;
  What<double> get unboundedTarget => _unboundedTarget.what;

  /// Cached reactive bridge nodes observing controller progress (zero allocation in build).
  late final What<double> frozenProgress = frozenCtrl.observe();
  late final What<double> catchUpProgress = catchUpCtrl.observe();
  late final What<double> unboundedFrozenProgress =
      unboundedFrozenCtrl.observe();
  late final What<double> unboundedCatchUpProgress =
      unboundedCatchUpCtrl.observe();

  void toggleMount() => _isMounted.set(!_isMounted.data);
  void setMounted(bool value) => _isMounted.set(value);
  void setUnboundedMode(bool value) => _isUnboundedMode.set(value);

  void togglePingPong() {
    final next = !_isPingPong.data;
    _isPingPong.set(next);
    frozenCtrl.repeat(reverse: next);
    catchUpCtrl.repeat(reverse: next);
  }

  void runUnboundedJump(double target) {
    _unboundedTarget.set(target);
    unboundedFrozenCtrl.animateTo(
      target,
      duration: const Duration(seconds: 6),
      curve: Curves.linear,
    );
    unboundedCatchUpCtrl.animateTo(
      target,
      duration: const Duration(seconds: 6),
      curve: Curves.linear,
    );
  }

  void resetUnboundedToZero() {
    _unboundedTarget.set(0.0);
    unboundedFrozenCtrl.animateTo(
      0.0,
      duration: const Duration(seconds: 4),
      curve: Curves.linear,
    );
    unboundedCatchUpCtrl.animateTo(
      0.0,
      duration: const Duration(seconds: 4),
      curve: Curves.linear,
    );
  }

  Future<void> triggerSimulatedSleep(int seconds) async {
    if (_isSleeping.data) return;
    _isSleeping.set(true); // Automatically unmounts via sleepMountSyncEffect

    await Future<void>.delayed(Duration(seconds: seconds));

    if (_isSleeping.data) {
      _isSleeping.set(false); // Automatically remounts via sleepMountSyncEffect
    }
  }

  void cancelSleep() {
    _isSleeping.set(false); // Automatically remounts via sleepMountSyncEffect
  }

  ShowcaseSection get section => ShowcaseSection(
        id: '13_dual_engine_battle',
        number: '13',
        title: 'Dual Engine Battle & Unbounded Motion',
        subtitle:
            'Frozen vs Catch-Up wall-clock time warp & unbounded coordinates (-1000 ~ +5000)',
        badge: 'Time Warp & Unbounded',
        icon: Icons.compare_arrows_rounded,
        codeSnippet: '''
// =============================================================================
// [1. Resume: Freezes on unmount, resumes from exact position]
// =============================================================================
final frozenCtrl = DurableAnimationController(
  policy: DurabilityPolicy.resume,
  duration: const Duration(seconds: 4),
)..repeat();

// =============================================================================
// [2. CatchUp: Calculates dormant wall-clock elapsed time on remount]
// =============================================================================
final catchUpCtrl = DurableAnimationController(
  policy: DurabilityPolicy.catchUp,
  duration: const Duration(seconds: 4),
)..repeat();

// =============================================================================
// [3. Unbounded Coordinates: Continuous infinite space (-∞ ~ +∞)]
// =============================================================================
final unboundedCtrl = DurableAnimationController.unbounded(
  policy: DurabilityPolicy.catchUp,
  value: 0.0,
);
unboundedCtrl.animateTo(5000.0, duration: const Duration(seconds: 6));''',
        highlights: const [
          'Engine Battle: Side-by-side comparison of Frozen and CatchUp controllers.',
          'DurabilityPolicy.resume: Freezes on unmount, seamlessly resumes on remount.',
          'DurabilityPolicy.catchUp: Compensates wall-clock elapsed time while unmounted.',
          'Unbounded Motion: Infinite coordinate navigation (-1000.0 ~ +5000.0) without range clamping.',
        ],
        roadmapTree: '''
[Engine Selection Roadmap]
 ├── DurabilityPolicy.resume          (Pauses on unmount, resumes from frozen value on remount)
 │    └── Ideal for: Tabs, BottomSheets, Modal Dialogs, Scroll-Out Lists
 │
 ├── DurabilityPolicy.catchUp         (Calculates dormant wall-clock elapsed time on remount)
 │    └── Ideal for: Radar Scanners, Clocks, Planetary Orbits, Periodic Pollers
 │
 └── DurableAnimationController.unbounded (Infinite coordinate spaces without [0.0, 1.0] limits)
''',
        builder: () => DualEngineBattleSectionDemo(),
      );
}
