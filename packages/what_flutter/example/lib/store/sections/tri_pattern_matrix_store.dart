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

  ShowcaseSection get section => ShowcaseSection(
        id: '14_tri_pattern_matrix',
        number: '14',
        title: 'Tri-Pattern Animation Matrix',
        subtitle:
            '3 canonical pathways: composed.animate, ctrl.animate, ctrl.animate.child',
        badge: '3 Pathways',
        icon: Icons.account_tree_rounded,
        codeSnippet: '''
// =============================================================================
// [3 Canonical Ways to Animate an External Durable Controller]
// =============================================================================

// Pattern A: Functional Inline composed.animate (Zero boilerplate, reactive composition)
composed.animate(
  storeCtrl,
  (via, ctrl) => RotationTransition(turns: ctrl.view, child: const Icon(Icons.hub)),
);

// Pattern B: Controller-Centric Self-Vsync (Direct .animate on controller instance)
storeCtrl.animate(
  (via, ctrl) => RotationTransition(turns: ctrl.view, child: const Icon(Icons.grain)),
);

// Pattern C: Static Child Memoization (.animate.child isolates heavy asset repaints)
storeCtrl.animate.child(
  (via, ctrl, child) => RotationTransition(turns: ctrl.view, child: child),
  child: const HeavyAssetWidget(), // Repaints on GPU without widget rebuilds!
);''',
        highlights: const [
          '3 Canonical Pathways: composed.animate, ctrl.animate, and ctrl.animate.child.',
          '100% Self-Vsync Lifecycle: Zero manual TickerProvider management; automatically wakes on mount and hibernates on unmount.',
          'Zero-Rebuild GPU Repaints: Heavy widget isolation via .animate.child prevents unnecessary subtree rebuilds.',
          'Scoped Listener Purge: All listeners registered on ctrl.view are 100% cleanly detached on unmount.',
        ],
        roadmapTree: '''
[Canonical Animation & Wake Matrix]
 ├── Pattern A: composed.animate(ctrl, (via, ctrl) => ...)                    [Functional Composition]
 ├── Pattern B: ctrl.animate((via, ctrl) => ...)                              [Controller Direct]
 └── Pattern C: ctrl.animate.child((via, ctrl, child) => ..., child: ...)     [Static Child Isolation]
''',
        builder: () => TriPatternMatrixSectionDemo(),
      );
}
