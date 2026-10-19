// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/framework.dart';
import '../../models/section.dart';
import '../../sections/composed_functors_section.dart';

/// Sub-store for Section 02: Declarative Inline composed()
class ComposedFunctorsStore {
  final _score = WhatController<int>(100);
  final _level = WhatController<int>(1);
  final _cascadeMode = WhatController<int>(
      0); // 0: basic, 1: context, 2: child, 3: children, 4: child.context

  What<int> get score => _score.what;
  What<int> get level => _level.what;
  What<int> get cascadeMode => _cascadeMode.what;

  void addScore() => _score.set(_score.data + 50);
  void levelUp() => _level.set(_level.data + 1);
  void selectCascadeMode(int mode) => _cascadeMode.set(mode);
  void reset() {
    _score.set(100);
    _level.set(1);
    _cascadeMode.set(0);
  }

  ShowcaseSection get section => ShowcaseSection(
        id: '02_composed_functors',
        number: '02',
        title: 'Declarative Inline composed()',
        subtitle: 'Surgical micro-rebuilds & static subtree caching',
        badge: 'Functors',
        icon: Icons.layers_rounded,
        codeSnippet: '''
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

// 1. Basic inline composed (Explicit WhatVia manifest):
composed((via) {
  final score = via(scoreWhat);
  return Text('Score: \$score');
});

// 2. composed with Context:
composed.context((context, via) {
  final theme = Theme.of(context);
  final score = via(scoreWhat);
  return Text('Active: \$score', style: theme.textTheme.titleMedium);
});

// 3. composed with Static Child Caching (Zero rebuilds on child):
composed.child((via, child) {
  final level = via(levelWhat);
  return Row(children: [child!, Text('Lv.\$level')]);
}, child: const StaticHeavyShieldIcon());

// 4. composed.animate (Replaces AnimatedBuilder with 60/120fps direct ticks):
composed.animate(
  controller,
  (via, ctrl) => ScaleTransition(scale: ctrl, child: const Icon(Icons.star)),
);

// 5. composed.drive (Continuous Frame Ticker Driver without controller):
composed.drive<double>(
  (elapsed) => (math.sin(elapsed.inMilliseconds / 300.0) + 1.0) / 2.0,
  (via, val) => Opacity(opacity: val, child: const GlowingBox()),
);

// 6. Multi-What Synthesis via WhatVia:
composed((via) {
  final diff = via(whatA) - via(whatB);
  return Text('Diff: \$diff');
});''',
        highlights: const [
          'Surgical Micro-Rebuilds: Rebuilds only the inner subtree, leaving parents untouched.',
          '.child / .children Caching: Isolates heavy static subtrees from rebuilding across frame updates.',
          'composed.animate: High-performance replacement for AnimatedBuilder without boilerplate.',
          'composed.drive: Instant continuous frame ticker driver without declaring any AnimationController.',
          'Multi-What Dynamic Discovery: Reads any number of states via via(node) with 1-pass epoch sweeping.',
          'Zero Prop-Drilling: Eliminates dedicated widget subclass boilerplate entirely.',
        ],
        roadmapTree: '''
composed                  ((via) => ...) // 1. Multi-State Reactivity
 ├── .context             ((context, via) => ...)
 │    ├── .child          ((context, via, child) => ..., child: ...)
 │    └── .children       ((context, via, children) => ..., children: ...)
 ├── .child               ((via, child) => ..., child: ...)
 │    └── .context        ((context, via, child) => ..., child: ...)
 ├── .children            ((via, children) => ..., children: ...)
 │    └── .context        ((context, via, children) => ..., children: ...)
 │
 ├── .animate             (controller, (via, controller) => ...) // 2. 60/120fps Active Animation
 │    ├── .context        (controller, (context, via, controller) => ...)
 │    │    ├── .child     (controller, (context, via, controller, child) => ..., child: ...)
 │    │    └── .children  (controller, (context, via, controller, children) => ..., children: ...)
 │    ├── .child          (controller, (via, controller, child) => ..., child: ...)
 │    │    └── .context   (controller, (context, via, controller, child) => ..., child: ...)
 │    └── .children       (controller, (via, controller, children) => ..., children: ...)
 │         └── .context   (controller, (context, via, controller, children) => ..., children: ...)
 │
 └── .drive               ((elapsed) => ..., (via, value) => ...) // 3. Continuous Frame Ticker
      ├── .context        ((elapsed) => ..., (context, via, value) => ...)
      │    ├── .child     ((elapsed) => ..., (context, via, value, child) => ..., child: ...)
      │    └── .children  ((elapsed) => ..., (context, via, value, children) => ..., children: ...)
      ├── .child          ((elapsed) => ..., (via, value, child) => ..., child: ...)
      │    └── .context   ((elapsed) => ..., (context, via, value, child) => ..., child: ...)
      └── .children       ((elapsed) => ..., (via, value, children) => ..., children: ...)
           └── .context   ((elapsed) => ..., (context, via, value, children) => ..., children: ...)
''',
        builder: () => ComposedFunctorsSectionDemo(),
      );
}
