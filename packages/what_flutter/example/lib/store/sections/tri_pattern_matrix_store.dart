// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/tri_pattern_matrix_section.dart';

/// Sub-store for Section 12: Tri-Pattern Animation Matrix (3 Canonical Ways Side-by-Side)
class TriPatternMatrixStore {
  TriPatternMatrixStore()
      : controller = DurableAnimationController(
          duration: const Duration(seconds: 6),
        ),
        _isMounted = WhatController<bool>(true),
        _patternABuildCount = WhatController<int>(0),
        _patternBBuildCount = WhatController<int>(0),
        _patternCBuildCount = WhatController<int>(0) {
    controller.repeat();
  }

  final DurableAnimationController controller;
  final WhatController<bool> _isMounted;
  What<bool> get isMounted => _isMounted.what;

  final WhatController<int> _patternABuildCount;
  What<int> get patternABuildCount => _patternABuildCount.what;

  final WhatController<int> _patternBBuildCount;
  What<int> get patternBBuildCount => _patternBBuildCount.what;

  final WhatController<int> _patternCBuildCount;
  What<int> get patternCBuildCount => _patternCBuildCount.what;

  void toggleMount() => _isMounted.set(!_isMounted.data);

  void toggleDirection() => controller.toggle();

  void resumeRepeat() => controller.repeat();

  void togglePingPong() => controller.repeat(reverse: true);

  ShowcaseSection get section => ShowcaseSection(
        id: '14_tri_pattern_matrix',
        number: '14',
        title: 'Tri-Pattern Animation Matrix',
        subtitle:
            '3 canonical pathways: composed.animate, composed.drive, composed.animate.child',
        badge: '3 Pathways',
        icon: Icons.account_tree_rounded,
        codeSnippet: '''
// =============================================================================
// [3 Canonical Composed Animation Pathways]
// =============================================================================

// Pattern A: Functional Inline composed.animate (Controller-driven reactive composition)
composed.animate(
  storeCtrl,
  (context, via, ctrl) => RotationTransition(turns: ctrl.view, child: const Icon(Icons.hub)),
);

// Pattern B: Autonomous Continuous composed.drive (Zero-controller frame ticker)
composed.drive(
  (elapsed) => (elapsed.inMilliseconds % 2000) / 2000.0,
  (context, via, turns) => Transform.rotate(angle: turns * 2 * pi, child: const Icon(Icons.grain)),
);

// Pattern C: Static Child Memoization composed.animate.child (Controller + GPU isolation)
composed.animate.child(
  storeCtrl,
  (context, via, ctrl, child) => RotationTransition(turns: ctrl.view, child: child),
  child: const HeavyAssetWidget(), // Repaints on GPU without widget rebuilds!
);''',
        highlights: const [
          '3 Canonical Pathways: composed.animate, composed.drive, and composed.animate.child.',
          'Pattern A & C: Bound to external DurableAnimationController timeline.',
          'Pattern B (composed.drive): Runs autonomously on raw frame ticks without requiring a controller.',
          'Zero-Rebuild GPU Repaints: Heavy widget isolation via .animate.child prevents unnecessary subtree rebuilds.',
        ],
        roadmapTree: '''
[Canonical Animation & Wake Matrix]
 ├── Pattern A: composed.animate(ctrl, ...)            [Controller-Bound]
 ├── Pattern B: composed.drive(onTick, ...)            [Autonomous Frame Ticker]
 └── Pattern C: composed.animate.child(ctrl, ..., child: ...) [Static Child Isolation]
''',
        builder: () => const TriPatternMatrixSectionDemo(),
      );
}
