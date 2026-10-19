// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import '../../models/section.dart';
import '../../sections/frame_scheduler_section.dart';

/// Sub-store for Section 13: Frame-Aligned Scheduler (vsync.drive & composed.drive)
class FrameSchedulerStore {
  ShowcaseSection get section => ShowcaseSection(
        id: '16_frame_scheduler',
        number: '16',
        title: 'Frame-Aligned Scheduler & Inline composed.drive',
        subtitle:
            'Reactive 120fps ticker pipelines & surgical inline micro-rebuilds',
        badge: 'Scheduler',
        icon: Icons.speed_rounded,
        codeSnippet: '''
// =========================================================================
// [1. Declarative Ticker Pipeline: composed.drive.child]
// =========================================================================
Widget buildHarmonicOscilloscope() {
  return composed.drive.child(
    (elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      return math.sin(t * 3 * math.pi);
    },
    (via, sine, child) => Column(children: [child!, Text('Sine: \$sine')]),
    child: const StaticOscilloscopeHeader(),
  );
}

// =========================================================================
// [2. Surgical Inline Functor: composed.drive.child]
// =========================================================================
Widget build120FpsPulseRing() {
  // ShowcaseCard & parent layout are built ONLY ONCE (0 rebuild overhead)!
  return composed.drive.child<double>(
    (elapsed) => elapsed.inMilliseconds / 1000.0,
    (via, seconds, staticBackdrop) {
      return Stack(
        children: [
          staticBackdrop!, // [Performance] Static crosshair is NEVER rebuilt!
          Transform.rotate(angle: seconds * 2.5 * math.pi, child: const RadarTracker()),
        ],
      );
    },
    child: const StaticCrosshairGrid(),
  );
}''',
        highlights: const [
          'Pattern 1 (vsync.drive): Embeds 60fps/120fps frame ticks into What reactive DAG.',
          'Pattern 2 (composed.drive): Surgical inline micro-rebuilds without widget class boilerplate.',
          '.child / .children Caching: Completely isolates static backdrops and grids from 120fps ticks.',
          'Zero Ticker Leaks: Automatically stops and releases Tickers upon element deactivation.',
        ],
        roadmapTree: '''
[1. Frame-Aligned DAG Stream (vsync.drive)]
 vsync.drive(onTick)                    -> What<T>
  └── drivenWhat.build                 ((data) => ...)
       ├── .context                     ((context, data) => ...)
       ├── .child                       ((data, child) => ..., child: ...)
       │    └── .context                ((context, data, child) => ..., child: ...)
       └── .children                    ((data, children) => ..., children: ...)
            └── .context                ((context, data, children) => ..., children: ...)

[2. Surgical Inline 120fps Functor (composed.drive)]
 composed.drive                    ((elapsed) => ..., (via, value) => ...)
  ├── .child                            ((elapsed) => ..., (via, value, child) => ..., child: ...)
  └── .children                         ((elapsed) => ..., (via, value, children) => ..., children: ...)
''',
        builder: () => FrameSchedulerSectionDemo(),
      );
}
