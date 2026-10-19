// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/unbounded_coordinates_section.dart';

/// Sub-store for Section 16: Extreme Coordinate Space & Infinite Dimensions (-1000 ~ +5000)
class UnboundedCoordinatesStore {
  UnboundedCoordinatesStore({DateTime Function()? clock})
      : unboundedFrozenCtrl = DurableAnimationController.unbounded(
          value: 0.0,
        ),
        unboundedCatchUpCtrl = DurableAnimationController.unbounded(
          policy: DurabilityPolicy.catchUp,
          value: 0.0,
          duration: const Duration(seconds: 6),
          clock: clock ?? DateTime.now,
        ),
        _isMounted = WhatController<bool>(true),
        _currentTarget = WhatController<double>(0.0);

  final DurableAnimationController unboundedFrozenCtrl;
  final DurableAnimationController unboundedCatchUpCtrl;
  final WhatController<bool> _isMounted;
  What<bool> get isMounted => _isMounted.what;

  final WhatController<double> _currentTarget;
  What<double> get currentTarget => _currentTarget.what;

  void toggleMount() => _isMounted.set(!_isMounted.data);

  void runUnboundedJump(double target) {
    _currentTarget.set(target);
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

  void resetToZero() {
    _currentTarget.set(0.0);
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

  ShowcaseSection get section => ShowcaseSection(
        id: '16_unbounded_coordinates',
        number: '16',
        title: 'Extreme Coordinates & Unbounded Space',
        subtitle:
            'Infinite coordinate tracking (-1000 ~ +5000) with Frozen vs CatchUp',
        badge: 'Unbounded',
        icon: Icons.all_inclusive_rounded,
        codeSnippet: '''
// =============================================================================
// [Extreme Coordinates & Infinite State Space (-∞ ~ +∞)]
// =============================================================================
final frozenUnbounded = FrozenAnimationController.unbounded(value: 0.0);
final catchUpUnbounded = CatchUpAnimationController.unbounded(
  value: 0.0,
  duration: const Duration(seconds: 6),
);

// Jump smoothly across extreme coordinates:
frozenUnbounded.animateTo(5000.0, duration: const Duration(seconds: 6));
catchUpUnbounded.animateTo(5000.0, duration: const Duration(seconds: 6));

// When unmounted during motion:
// - Frozen freezes at exact coordinate (e.g. 1240.0) and resumes on remount.
// - CatchUp calculates dormant elapsed time and advances immediately to 3800.0!''',
        highlights: const [
          'Unbounded Controllers: Full support for infinite coordinate spaces (-∞ ~ +∞).',
          'Extreme Coordinates: Seamless motion across negative (-500) and massive positive (+5000) coordinates.',
          'Dual State Recovery: Compare frozen coordinate resumption vs real-time wall-clock jump.',
          '6-Second Smooth Trajectory: Clear, observable digital meters for real-time progress verification.',
        ],
        roadmapTree: '''
[Unbounded Coordinate Space Architecture]
 ├── FrozenAnimationController.unbounded (Infinite state space, frozen on unmount)
 └── CatchUpAnimationController.unbounded   (Wall-clock time tracked across infinite space)
''',
        builder: () => UnboundedCoordinatesSectionDemo(),
      );
}
