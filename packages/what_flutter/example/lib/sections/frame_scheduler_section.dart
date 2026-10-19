// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';

/// Section 13: Frame-Aligned Scheduler Pipelines (`vsync.drive()` & `composed.drive`)
base class FrameSchedulerSectionDemo extends WhatWidget {
  const FrameSchedulerSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    return Column(
      children: [
        // =====================================================================
        // Demo 1: Declarative Multi-Node Pipeline (vsync.drive)
        // =====================================================================
        _HarmonicOscilloscopeDagDemo(),

        const SizedBox(height: 20),

        // =====================================================================
        // Demo 2: Surgical 120fps Inline Micro-Rebuild (composed.drive)
        // =====================================================================
        const _SurgicalLaserRadarInlineDemo(),
      ],
    );
  }
}

/// Demo 1: Isolated Reactive DAG Pipeline (vsync.drive via WhatVsyncWidget)
base class _HarmonicOscilloscopeDagDemo extends WhatVsyncWidget {
  const _HarmonicOscilloscopeDagDemo();

  @override
  Widget build(BuildContext context, WhatVia via, TickerProvider vsync) {
    // Continuous frame-aligned sine wave pipeline
    final sineWaveWhat = vsync.drive((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      return math.sin(t * 3 * math.pi);
    });

    // Elapsed time pipeline for timing stats
    final elapsedSecondsWhat = vsync.drive((elapsed) {
      return elapsed.inMilliseconds / 1000.0;
    });

    final seconds = via(elapsedSecondsWhat);

    return ShowcaseCard(
      title: '1. Reactive DAG Pipeline (vsync.drive -> drivenWhat.build)',
      badge: 'vsync.drive',
      description:
          'vsync.drive() converts Flutter 60fps/120fps frame ticks into reactive What DAG nodes. The resulting drivenWhat directly supports .build.child for static subtree caching.',
      child: Column(
        children: [
          SandboxContainer(
            minHeight: 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Visual Multi-Bar Oscilloscope
                SizedBox(
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(13, (i) {
                      final phaseOffset = (i - 6) * 0.35;
                      final barHeight = 16.0 +
                          ((math.sin(seconds * 3 * math.pi + phaseOffset) + 1) /
                                  2) *
                              48.0;
                      final intensity = (barHeight - 16.0) / 48.0;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: 10,
                        height: barHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Color.lerp(
                            Colors.indigoAccent,
                            Colors.cyanAccent,
                            intensity,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent
                                  .withAlpha((intensity * 120).toInt()),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 14),

                // [Performance] drivenWhat.build.child: Static icon cached with 0 rebuilds across 120fps ticks!
                sineWaveWhat.build.child(
                  (context, sineVal, child) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        child, // Static child
                        Text(
                          'drivenWhat.build.child: Sine = ${sineVal.toStringAsFixed(3)} (${seconds.toStringAsFixed(2)}s)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Demo 2: Surgical 120fps Inline Drive & Static Subtree Isolation
base class _SurgicalLaserRadarInlineDemo extends WhatWidget {
  const _SurgicalLaserRadarInlineDemo();

  @override
  Widget build(BuildContext context, WhatVia via) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShowcaseCard(
      title: '2. Surgical 120fps Inline Drive & Static Caching',
      badge: 'composed.drive.child',
      description:
          'composed.drive.child runs high-performance 120fps frame loops with surgical micro-rebuilds. The parent card is built only ONCE and the static radar backdrop is cached with 0 rebuilds.',
      child: Column(
        children: [
          SandboxContainer(
            minHeight: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Parent Rebuild Isolation Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.green.withAlpha(100),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Surgical 120 FPS Micro-Rebuild (Parent Card: 0 Rebuilds)',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Inline 120fps Dynamic Particle Ring with Cached Static Crosshair Backdrop
                composed.drive.child<double>(
                  (elapsed) => elapsed.inMilliseconds / 1000.0,
                  (context, via, seconds, child) {
                    final angle = seconds * 2.5 * math.pi;
                    final pulseScale = 1.0 + 0.08 * math.sin(seconds * 6);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // [Performance] Cached static backdrop: NEVER rebuilt during 120fps ticks!
                        child,

                        // Dynamic Concentric Pulse Wave
                        Transform.scale(
                          scale: pulseScale,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyanAccent.withAlpha(
                                  (160 * (2.0 - pulseScale))
                                      .clamp(0, 255)
                                      .toInt(),
                                ),
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        // Revolving High-Precision Particle Tracker
                        Transform.rotate(
                          angle: angle,
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.cyanAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyanAccent,
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Center Digital Micro-Telemetry
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(seconds % 60).toStringAsFixed(2)}s',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.cyanAccent,
                              ),
                            ),
                            const Text(
                              '120 FPS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xFF161922)
                          : Colors.grey.shade100,
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Horizontal crosshair
                        Container(
                          width: 140,
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        // Vertical crosshair
                        Container(
                          width: 1,
                          height: 140,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        // Inner reference circle
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                              width: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
