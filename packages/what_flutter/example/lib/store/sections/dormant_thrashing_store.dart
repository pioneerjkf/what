// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/dormant_thrashing_section.dart';

/// Sub-store for Section 15: Dormant Command Thrashing (Motion Staging & Zero TickerCanceled)
class DormantThrashingStore {
  DormantThrashingStore({DateTime Function()? clock})
      : frozenCtrl = DurableAnimationController(
          policy: DurabilityPolicy.resume,
          duration: const Duration(seconds: 3),
        ),
        catchUpCtrl = DurableAnimationController(
          policy: DurabilityPolicy.catchUp,
          duration: const Duration(seconds: 3),
          clock: clock ?? DateTime.now,
        ),
        _isMounted = WhatController<bool>(true),
        _stagedActionLog = WhatController<List<String>>([]),
        _lastStagedAction = WhatController<String>('Idle (No Staged Motion)'),
        _stagedTargetValue = WhatController<double>(0.0);

  final DurableAnimationController frozenCtrl;
  final DurableAnimationController catchUpCtrl;
  DurableAnimationController get controller => frozenCtrl;
  final WhatController<bool> _isMounted;
  final WhatController<List<String>> _stagedActionLog;
  final WhatController<String> _lastStagedAction;
  final WhatController<double> _stagedTargetValue;

  What<bool> get isMounted => _isMounted.what;
  What<List<String>> get stagedActionLog => _stagedActionLog.what;
  What<String> get lastStagedAction => _lastStagedAction.what;
  What<double> get stagedTargetValue => _stagedTargetValue.what;

  void toggleMount() => _isMounted.set(!_isMounted.data);

  void _recordStaged(String action, [double? target]) {
    _lastStagedAction.set(action);
    if (target != null) {
      _stagedTargetValue.set(target);
    }
    final nextList = List<String>.from(_stagedActionLog.data)
      ..insert(0, action);
    if (nextList.length > 8) nextList.removeLast();
    _stagedActionLog.set(nextList);
  }

  void forward() {
    frozenCtrl.forward();
    catchUpCtrl.forward();
    _recordStaged('forward() [Target: 1.0]');
  }

  void reverse() {
    frozenCtrl.reverse();
    catchUpCtrl.reverse();
    _recordStaged('reverse() [Target: 0.0]');
  }

  void toggle() {
    frozenCtrl.toggle();
    catchUpCtrl.toggle();
    _recordStaged('toggle() [Flipped direction]');
  }

  void animateTo(double target, [Curve curve = Curves.bounceOut]) {
    frozenCtrl.animateTo(target, curve: curve);
    catchUpCtrl.animateTo(target, curve: curve);
    _recordStaged('animateTo($target, curve: ${curve.runtimeType})', target);
  }

  void repeat(bool reverse) {
    frozenCtrl.repeat(reverse: reverse);
    catchUpCtrl.repeat(reverse: reverse);
    _recordStaged('repeat(reverse: $reverse)');
  }

  void fling(double velocity) {
    frozenCtrl.fling(velocity: velocity);
    catchUpCtrl.fling(velocity: velocity);
    _recordStaged('fling(velocity: $velocity)');
  }

  void stop() {
    frozenCtrl.stop();
    catchUpCtrl.stop();
    _recordStaged('stop() [Cancelled Staging]');
  }

  void reset() {
    frozenCtrl.reset();
    catchUpCtrl.reset();
    _recordStaged('reset() [Value -> 0.0]');
  }

  void setValue(double value) {
    frozenCtrl.value = value;
    catchUpCtrl.value = value;
    _recordStaged('value = $value [Zero-Notification Direct Setter]');
  }

  ShowcaseSection get section => ShowcaseSection(
        id: '15_dormant_thrashing',
        number: '15',
        title: 'Dormant Command Thrashing',
        subtitle:
            'Safe motion staging, command queueing & Zero TickerCanceled (Frozen vs CatchUp)',
        badge: 'Lifecycle Safe',
        icon: Icons.flash_on_rounded,
        codeSnippet: '''
// =============================================================================
// [1. Safe Motion Staging in Dormant State (Frozen & CatchUp)]
// =============================================================================
final frozen = FrozenAnimationController(duration: const Duration(seconds: 3));
final catchUp = CatchUpAnimationController(duration: const Duration(seconds: 3));

// Smash commands from Store / ViewModel even when widgets are unmounted!
// Staged gracefully into local delegates without throwing StateError or TickerCanceled:
frozen.toggle();
catchUp.toggle();
frozen.animateTo(0.8, curve: Curves.bounceOut);
catchUp.animateTo(0.8, curve: Curves.bounceOut);

// =============================================================================
// [2. Zero-Notification Direct Setter Invariant]
// =============================================================================
// Modifying value or durations while dormant emits 0 redundant notifications:
frozen.value = 0.5;
catchUp.value = 0.5;

// Remounting automatically resyncs:
// - Frozen replays staged motion starting from frozen progress.
// - CatchUp calculates elapsed dormant wall-clock and compensates progress!
composed.animate(frozen, (via, ctrl) => RocketShuttle(controller: ctrl));
composed.animate(catchUp, (via, ctrl) => SpaceShuttle(controller: ctrl));''',
        highlights: const [
          'Dual Motion Staging: forward, reverse, toggle, animateTo, and fling queued without crash.',
          'Zero TickerCanceled Guarantee: Completely immune to unhandled Flutter ticker cancellation exceptions.',
          'Zero-Notification Guarantee: Value & duration mutations while dormant emit 0 notifications.',
          'Frozen vs CatchUp Replay: Frozen replays from frozen spot; CatchUp compensates wall-clock time.',
        ],
        roadmapTree: '''
[Dormant State Delegate State Machine]
 ├── _FrozenDormantControlDelegate    (Freezes on unmount, replays from frozen position)
 │    ├── forward()         -> StagedMode.forward
 │    ├── reverse()         -> StagedMode.reverse
 │    ├── toggle()          -> Flips staged target direction
 │    ├── animateTo(t, c)   -> StagedMode.animateTo (Preserves Curve & Duration)
 │    ├── fling(velocity)   -> StagedMode.fling (Physics preserved)
 │    └── stop() / reset()  -> StagedMode.idle (Cancels pending motion)
 │
 ├── _CatchUpDormantControlDelegate   (Compensates wall-clock duration elapsed while unmounted)
 │    └── activate(vsync)   -> applyElapsedCompensation(dt) -> replays remaining duration
 │
 └── resync(TickerProvider) -> _ActiveAnimationControlDelegate (Replays staged motion)
''',
        builder: () => DormantThrashingSectionDemo(),
      );
}
