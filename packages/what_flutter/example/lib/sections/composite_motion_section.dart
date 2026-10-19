// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 13: Composite Motion & Multi-Tween Choreography
///
/// Demonstrates how a single master [DurableAnimationController] drives multiple
/// coordinated sub-animations, curved intervals, chained tweens, and multi-property
/// transformations under 1 VSYNC authority with 0 ticker leaks and 0 rebuild overhead.
base class CompositeMotionSectionDemo extends WhatWidget {
  const CompositeMotionSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.compositeMotion;

    return What.constant(store).provide(
      child: ShowcaseCard(
        title: 'Composite Motion & Multi-Tween Choreography',
        badge: 'Single VSYNC · Multi-Tween',
        description:
            'A single master controller orchestrating 6+ concurrent sub-animations, Interval curves, Tween.chain, and TweenSequence without extra Tickers or rebuild leaks.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -------------------------------------------------------------------
            // 0. Architectural Concept Banner
            // -------------------------------------------------------------------
            const _HeaderConceptBanner(),
            const SizedBox(height: 16),

            // -------------------------------------------------------------------
            // 1. Mode Selection Tabs
            // -------------------------------------------------------------------
            const _ModeTabBar(),
            const SizedBox(height: 14),

            // -------------------------------------------------------------------
            // 2. Main Visual Arena (SandboxContainer)
            // -------------------------------------------------------------------
            SandboxContainer(
              minHeight: 320,
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: composed((context, via) {
                final isMounted = via(store.isMounted);
                if (!isMounted) {
                  return const _DormantPlaceholder();
                }

                final activeTab = via(store.activeTab);
                return switch (activeTab) {
                  0 => const _OrigamiMorphStage(),
                  1 => const _MultiCurveRaceStage(),
                  _ => const _ChainedSequenceStage(),
                };
              }),
            ),
            const SizedBox(height: 16),

            // -------------------------------------------------------------------
            // 3. Real-Time Sub-Animation Telemetry Timeline
            // -------------------------------------------------------------------
            const _SubAnimationTelemetryDashboard(),
            const SizedBox(height: 16),

            // -------------------------------------------------------------------
            // 4. Interactive Command Console & Duration Chooser
            // -------------------------------------------------------------------
            const _InteractiveControlConsole(),
            const SizedBox(height: 12),

            // -------------------------------------------------------------------
            // 5. Sub-Animation Isolation Filters (Toggle individual tweens)
            // -------------------------------------------------------------------
            const _SubAnimationFilterChips(),
          ],
        ),
      ),
    );
  }
}

base class _DormantPlaceholder extends WhatWidget {
  const _DormantPlaceholder();

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<CompositeMotionStore>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final policy = via(store.policy);
    final policyDetails = switch (policy) {
      DurabilityPolicy.resume =>
        'Policy: Resume -- Freezes on unmount, resumes from exact position upon waking.',
      DurabilityPolicy.catchUp =>
        'Policy: Catch-Up -- Calculates dormant wall-clock elapsed time and warps forward.',
      DurabilityPolicy.reset =>
        'Policy: Reset -- Discards progress and restarts from initial parameter values.',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            size: 40,
            color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
          ),
          const SizedBox(height: 10),
          const Text(
            'Subtrees Unmounted & Hibernated',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              policyDetails,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.indigoAccent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Master VSYNC is detached; 0 frame ticks allocated on GPU.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 0. Header Concept Banner
// =============================================================================

class _HeaderConceptBanner extends StatelessWidget {
  const _HeaderConceptBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.indigo.shade900.withAlpha(80)
            : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.indigo.shade800.withAlpha(120)
              : Colors.indigo.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.layers_rounded,
              color: Colors.indigoAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 Master Timeline -> Multi-Curve & Multi-Tween Choreography',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 3),
                Text(
                  'Avoid spawning multiple AnimationControllers for complex UI. Slice 1 master timeline using Interval, chain CurveTweens, and combine distinct Tweens in lockstep.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. Mode Tab Bar
// =============================================================================

base class _ModeTabBar extends WhatWidget {
  const _ModeTabBar();

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<CompositeMotionStore>(context);
    final activeTab = via(store.activeTab);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTabItem(context, store, 0, '3D Morphing Origami',
              Icons.style_rounded, activeTab == 0),
          _buildTabItem(context, store, 1, 'Multi-Curve Race',
              Icons.speed_rounded, activeTab == 1),
          _buildTabItem(context, store, 2, 'Chained Sequence Orbit',
              Icons.all_inclusive_rounded, activeTab == 2),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, CompositeMotionStore store,
      int index, String label, IconData icon, bool isSelected) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => store.setActiveTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : Colors.grey,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2A. Tab 0: 3D Origami Morphing Stage
// =============================================================================

base class _OrigamiMorphStage extends WhatWidget {
  const _OrigamiMorphStage();

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<CompositeMotionStore>(context);
    final masterCtrl = via(store.masterCtrl);
    return composed.animate(masterCtrl, (context, via, ctrl) {
      // 1. Read isolation filter flags
      final enableSlideElevation = via(store.enableSlideElevation);
      final enable3DRotation = via(store.enable3DRotation);
      final enableBorderRadius = via(store.enableBorderRadius);
      final enableColorGradient = via(store.enableColorGradient);
      final enableElasticBadge = via(store.enableElasticBadge);
      final enableCascade = via(store.enableStaggeredCascade);

      // -----------------------------------------------------------------------
      // Sub-Animation Pipeline
      // -----------------------------------------------------------------------
      // Sub-Motion 1: Staggered Slide & Elevation (0.00 ~ 0.35, easeOutBack)
      final slideOffset = enableSlideElevation
          ? Tween<Offset>(
              begin: const Offset(0, 0.35),
              end: Offset.zero,
            )
              .animate(CurvedAnimation(
                parent: ctrl.view,
                curve: const Interval(0.00, 0.35, curve: Curves.easeOutBack),
              ))
              .value
          : Offset.zero;

      final elevation = enableSlideElevation
          ? Tween<double>(begin: 2.0, end: 18.0)
              .animate(CurvedAnimation(
                parent: ctrl.view,
                curve: const Interval(0.05, 0.40, curve: Curves.easeOut),
              ))
              .value
          : 6.0;

      // Sub-Motion 2: 3D Perspective Rotation & Tilt (0.15 ~ 0.55, easeInOutCubic)
      final tiltY = enable3DRotation
          ? Tween<double>(begin: -0.22, end: 0.0)
              .animate(CurvedAnimation(
                parent: ctrl.view,
                curve: const Interval(0.15, 0.55, curve: Curves.easeInOutCubic),
              ))
              .value
          : 0.0;

      final tiltX = enable3DRotation
          ? Tween<double>(begin: 0.12, end: 0.0)
              .animate(CurvedAnimation(
                parent: ctrl.view,
                curve: const Interval(0.15, 0.55, curve: Curves.easeInOutCubic),
              ))
              .value
          : 0.0;

      // Sub-Motion 3: Shape & Corner Radius Morph (0.30 ~ 0.70, easeInOutBack)
      final borderRadius = enableBorderRadius
          ? (BorderRadiusTween(
                begin: BorderRadius.circular(44),
                end: BorderRadius.circular(16),
              )
                  .animate(CurvedAnimation(
                    parent: ctrl.view,
                    curve:
                        const Interval(0.30, 0.70, curve: Curves.easeInOutBack),
                  ))
                  .value ??
              BorderRadius.circular(16))
          : BorderRadius.circular(16);

      // Sub-Motion 4: Color Spectrum Dual-Gradient (0.20 ~ 0.80, linear)
      final startColor = enableColorGradient
          ? (ColorTween(
                begin: const Color(0xFF6366F1), // Indigo
                end: const Color(0xFF06B6D4), // Cyan
              )
                  .animate(CurvedAnimation(
                    parent: ctrl.view,
                    curve: const Interval(0.20, 0.80, curve: Curves.linear),
                  ))
                  .value ??
              const Color(0xFF6366F1))
          : const Color(0xFF6366F1);

      final endColor = enableColorGradient
          ? (ColorTween(
                begin: const Color(0xFF8B5CF6), // Purple
                end: const Color(0xFF10B981), // Emerald
              )
                  .animate(CurvedAnimation(
                    parent: ctrl.view,
                    curve: const Interval(0.20, 0.80, curve: Curves.linear),
                  ))
                  .value ??
              const Color(0xFF8B5CF6))
          : const Color(0xFF8B5CF6);

      // Sub-Motion 5: Elastic Badge Scale & Pulse (0.45 ~ 0.80, elasticOut)
      final badgeScale = enableElasticBadge
          ? Tween<double>(begin: 0.5, end: 1.15)
              .animate(CurvedAnimation(
                parent: ctrl.view,
                curve: const Interval(0.45, 0.80, curve: Curves.elasticOut),
              ))
              .value
          : 1.0;

      // Sub-Motion 6: Staggered Cascade Chips (0.55 ~ 1.00)
      final chip1Progress = enableCascade
          ? CurvedAnimation(
              parent: ctrl.view,
              curve: const Interval(0.55, 0.75, curve: Curves.easeOutCubic),
            ).value
          : 1.0;

      final chip2Progress = enableCascade
          ? CurvedAnimation(
              parent: ctrl.view,
              curve: const Interval(0.68, 0.88, curve: Curves.easeOutCubic),
            ).value
          : 1.0;

      final chip3Progress = enableCascade
          ? CurvedAnimation(
              parent: ctrl.view,
              curve: const Interval(0.80, 1.00, curve: Curves.easeOutCubic),
            ).value
          : 1.0;

      // -----------------------------------------------------------------------
      // Visual Presentation Assembly
      // -----------------------------------------------------------------------
      return Center(
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(tiltY)
            ..rotateX(tiltX),
          alignment: Alignment.center,
          child: FractionalTranslation(
            translation: slideOffset,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  colors: [startColor, endColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: startColor.withAlpha(90),
                    blurRadius: elevation * 1.5,
                    offset: Offset(0, elevation * 0.7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Elastic Badge & Title
                  Row(
                    children: [
                      Transform.scale(
                        scale: badgeScale,
                        child: const _OrigamiBadgeIcon(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Origami Morphing Entity',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              't = ${ctrl.value.toStringAsFixed(3)} | 6 Active Sub-Tweens',
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Staggered Cascade Chips (No emoji, Material icons used)
                  _buildCascadeChip(
                    icon: Icons.bolt_rounded,
                    label: 'DAG Throughput',
                    value: '142,000 ops/s',
                    progress: chip1Progress,
                  ),
                  const SizedBox(height: 8),
                  _buildCascadeChip(
                    icon: Icons.timer_outlined,
                    label: 'Frame Latency',
                    value: '0.34 ms (Budget: 16ms)',
                    progress: chip2Progress,
                  ),
                  const SizedBox(height: 8),
                  _buildCascadeChip(
                    icon: Icons.shield_outlined,
                    label: 'Memory Overhead',
                    value: '0 Leaks | 0 Rebuilds',
                    progress: chip3Progress,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCascadeChip({
    required IconData icon,
    required String label,
    required String value,
    required double progress,
  }) {
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1.0 - progress) * 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(50),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withAlpha(40)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrigamiBadgeIcon extends StatelessWidget {
  const _OrigamiBadgeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(50),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withAlpha(120),
          width: 1.5,
        ),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

// =============================================================================
// 2B. Tab 1: Multi-Curve Velocity Arena
// =============================================================================

base class _MultiCurveRaceStage extends WhatWidget {
  const _MultiCurveRaceStage();

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<CompositeMotionStore>(context);
    final masterCtrl = via(store.masterCtrl);
    return composed.animate(masterCtrl, (context, via, ctrl) {
      final t = ctrl.value;

      final tracks = [
        _CurveTrackDef('Linear', Curves.linear, Colors.blueGrey, t),
        _CurveTrackDef('EaseOutCubic', Curves.easeOutCubic, Colors.indigo, t),
        _CurveTrackDef('EaseInOutBack', Curves.easeInOutBack, Colors.purple, t),
        _CurveTrackDef('ElasticOut', Curves.elasticOut, Colors.teal, t),
        _CurveTrackDef('BounceOut', Curves.bounceOut, Colors.amber, t),
      ];

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '5 Concurrent Curves driven by Single Master Timeline:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Master t: ${t.toStringAsFixed(3)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.indigoAccent,
                  ),
                ),
              ],
            ),
          ),
          for (final track in tracks) ...[
            _buildTrackRow(track),
            const SizedBox(height: 10),
          ],
        ],
      );
    });
  }

  Widget _buildTrackRow(_CurveTrackDef track) {
    final transformed = track.curve.transform(track.masterT.clamp(0.0, 1.0));
    // Clamped for layout bounds, but displayed accurately
    final posNorm = transformed.clamp(-0.2, 1.2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = math.max(30.0, constraints.maxWidth - 160);
        final knobX = (posNorm * (trackWidth - 24)).clamp(0.0, trackWidth - 24);

        return Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                track.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: track.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: track.color.withAlpha(60)),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Finish Line
                    Positioned(
                      right: 12,
                      top: 4,
                      bottom: 4,
                      child: Container(
                        width: 2,
                        color: track.color.withAlpha(100),
                      ),
                    ),
                    // Runner Sphere
                    Positioned(
                      left: knobX,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: track.color,
                          boxShadow: [
                            BoxShadow(
                              color: track.color.withAlpha(120),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 50,
              child: Text(
                transformed.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: track.color,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CurveTrackDef {
  const _CurveTrackDef(this.name, this.curve, this.color, this.masterT);
  final String name;
  final Curve curve;
  final Color color;
  final double masterT;
}

// =============================================================================
// 2C. Tab 2: Chained Sequence Orbit
// =============================================================================

base class _ChainedSequenceStage extends WhatWidget {
  const _ChainedSequenceStage();

  static final _orbitOffsetSequence = TweenSequence<Offset>([
    TweenSequenceItem(
      tween: Tween<Offset>(
        begin: const Offset(-80, -40),
        end: const Offset(80, -40),
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween<Offset>(
        begin: const Offset(80, -40),
        end: const Offset(80, 40),
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween<Offset>(
        begin: const Offset(80, 40),
        end: const Offset(-80, 40),
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween<Offset>(
        begin: const Offset(-80, 40),
        end: const Offset(-80, -40),
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 25,
    ),
  ]);

  static final _orbitColorSequence = TweenSequence<Color?>([
    TweenSequenceItem(
      tween: ColorTween(
        begin: const Color(0xFF38BDF8),
        end: const Color(0xFFF43F5E),
      ),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: ColorTween(
        begin: const Color(0xFFF43F5E),
        end: const Color(0xFFA855F7),
      ),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: ColorTween(
        begin: const Color(0xFFA855F7),
        end: const Color(0xFF10B981),
      ),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: ColorTween(
        begin: const Color(0xFF10B981),
        end: const Color(0xFF38BDF8),
      ),
      weight: 25,
    ),
  ]);

  static final _scaleSequence = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.4)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.4, end: 0.8)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.8, end: 1.3)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.3, end: 1.0)
          .chain(CurveTween(curve: Curves.bounceOut)),
      weight: 25,
    ),
  ]);

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<CompositeMotionStore>(context);
    final masterCtrl = via(store.masterCtrl);
    return composed.animate(masterCtrl, (context, via, ctrl) {
      final offset = _orbitOffsetSequence.evaluate(ctrl.view);
      final color = _orbitColorSequence.evaluate(ctrl.view) ?? Colors.cyan;
      final scale = _scaleSequence.evaluate(ctrl.view);
      final angle = ctrl.value * 2 * math.pi;

      return Center(
        child: SizedBox(
          height: 180,
          width: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Perimeter Guide Track
              Container(
                width: 200,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withAlpha(40),
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
              ),
              // Center Core Pulsar
              Transform.rotate(
                angle: -angle * 0.5,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withAlpha(120)),
                  ),
                  child: Center(
                    child: Text(
                      '${(ctrl.value * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              // Orbiting Satellite Node
              Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withAlpha(140),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.satellite_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// =============================================================================
// 3. Real-Time Sub-Animation Telemetry Timeline
// =============================================================================

class _SubAnimationTelemetryDashboard extends StatelessWidget {
  const _SubAnimationTelemetryDashboard();

  @override
  Widget build(BuildContext context) {
    final store = context.whatOf<CompositeMotionStore>().peek;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3346) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timeline_rounded,
                      size: 16, color: Colors.indigoAccent),
                  const SizedBox(width: 6),
                  const Text(
                    'Interval Telemetry',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  composed((context, via) {
                    final activeTab = via(store.activeTab);
                    final tabBadge = switch (activeTab) {
                      0 => 'Origami',
                      1 => 'Curves',
                      _ => 'Orbit',
                    };
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.indigo.withAlpha(80)),
                      ),
                      child: Text(
                        tabBadge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              composed((context, via) {
                final t = via(store.masterProgress);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withAlpha(35),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.indigo.withAlpha(80)),
                  ),
                  child: Text(
                    't = ${t.toStringAsFixed(3)} (${(t * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigoAccent,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Master Progress Bar
          composed((context, via) {
            final t = via(store.masterProgress);
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: t.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
              ),
            );
          }),
          const SizedBox(height: 14),

          // Sub-Animation Interval Windows (Tab-Aware Dynamic Content)
          composed((context, via) {
            final t = via(store.masterProgress);
            final activeTab = via(store.activeTab);

            return switch (activeTab) {
              0 => _buildOrigamiTelemetry(t),
              1 => _buildMultiCurveTelemetry(t),
              _ => _buildChainedSequenceTelemetry(t),
            };
          }),
        ],
      ),
    );
  }

  Widget _buildOrigamiTelemetry(double t) {
    const intervals = [
      _IntervalDef('Slide & Elevate', 0.00, 0.35, Colors.blue),
      _IntervalDef('3D Tilt & Angle', 0.15, 0.55, Colors.cyan),
      _IntervalDef('Radius Morph', 0.30, 0.70, Colors.purple),
      _IntervalDef('Color Gradient', 0.20, 0.80, Colors.pink),
      _IntervalDef('Elastic Badge', 0.45, 0.80, Colors.teal),
      _IntervalDef('Cascade Chips', 0.55, 1.00, Colors.amber),
    ];

    return Column(
      children: [
        for (final item in intervals) ...[
          _buildIntervalRow(item, t),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildMultiCurveTelemetry(double t) {
    const curves = [
      _CurveDef('Curves.linear', Curves.linear, Colors.blueGrey),
      _CurveDef('Curves.easeOutCubic', Curves.easeOutCubic, Colors.indigo),
      _CurveDef('Curves.easeInOutBack', Curves.easeInOutBack, Colors.purple),
      _CurveDef('Curves.elasticOut', Curves.elasticOut, Colors.teal),
      _CurveDef('Curves.bounceOut', Curves.bounceOut, Colors.amber),
    ];

    return Column(
      children: [
        for (final item in curves) ...[
          _buildCurveRow(item, t),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildChainedSequenceTelemetry(double t) {
    const orbitIntervals = [
      _IntervalDef('Phase 1: North (→)', 0.00, 0.25, Color(0xFF38BDF8)),
      _IntervalDef('Phase 2: East (↓)', 0.25, 0.50, Color(0xFFF43F5E)),
      _IntervalDef('Phase 3: South (←)', 0.50, 0.75, Color(0xFFA855F7)),
      _IntervalDef('Phase 4: West (↑)', 0.75, 1.00, Color(0xFF10B981)),
    ];

    return Column(
      children: [
        for (final item in orbitIntervals) ...[
          _buildIntervalRow(item, t),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildIntervalRow(_IntervalDef item, double currentT) {
    final isDone = currentT > item.end;
    final isActive = currentT >= item.start && currentT <= item.end;
    final progressInInterval = isDone
        ? 1.0
        : isActive
            ? ((currentT - item.start) / (item.end - item.start))
                .clamp(0.0, 1.0)
            : 0.0;

    final badgeText = isDone
        ? 'DONE'
        : isActive
            ? '${(progressInInterval * 100).toInt()}%'
            : 'IDLE';
    final badgeColor = isDone
        ? Colors.greenAccent
        : isActive
            ? item.color
            : Colors.grey;

    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(
            item.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? item.color
                  : (isDone ? Colors.grey.shade400 : Colors.grey),
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '[${item.start.toStringAsFixed(2)}-${item.end.toStringAsFixed(2)}]',
            style: const TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final startX = item.start * totalW;
              final endX = item.end * totalW;
              final width = endX - startX;

              return SizedBox(
                height: 12,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Base track
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Interval boundary
                    Positioned(
                      left: startX,
                      width: width,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: item.color
                              .withAlpha(isActive ? 120 : (isDone ? 60 : 30)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Current Playhead Marker
                    Positioned(
                      left: totalW > 2
                          ? (currentT.clamp(0.0, 1.0) * totalW)
                              .clamp(0.0, totalW - 2)
                          : 0.0,
                      child: Container(
                        width: 2,
                        height: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: (isActive || isDone)
                  ? badgeColor.withAlpha(35)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: (isActive || isDone)
                    ? badgeColor.withAlpha(120)
                    : Colors.grey.withAlpha(40),
              ),
            ),
            child: Text(
              badgeText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: badgeColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurveRow(_CurveDef item, double currentT) {
    final transformed = item.curve.transform(currentT.clamp(0.0, 1.0));
    final posNorm = transformed.clamp(-0.2, 1.2);

    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(
            item.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: item.color,
            ),
          ),
        ),
        const SizedBox(
          width: 64,
          child: Text(
            '[0.00-1.00]',
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final runnerX = (posNorm.clamp(0.0, 1.0) * (totalW - 4))
                  .clamp(0.0, totalW - 4);
              final masterX = (currentT.clamp(0.0, 1.0) * (totalW - 2))
                  .clamp(0.0, totalW - 2);

              return SizedBox(
                height: 12,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Base track
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: item.color.withAlpha(30),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Transformed fill
                    Container(
                      width: runnerX + 2,
                      height: 4,
                      decoration: BoxDecoration(
                        color: item.color.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Master playhead needle
                    Positioned(
                      left: masterX,
                      child: Container(
                        width: 1.5,
                        height: 10,
                        color: Colors.redAccent.withAlpha(140),
                      ),
                    ),
                    // Curve playhead needle
                    Positioned(
                      left: runnerX,
                      child: Container(
                        width: 3,
                        height: 12,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: item.color.withAlpha(35),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: item.color.withAlpha(100)),
            ),
            child: Text(
              '${(transformed * 100).toInt()}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: item.color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntervalDef {
  const _IntervalDef(this.name, this.start, this.end, this.color);
  final String name;
  final double start;
  final double end;
  final Color color;
}

class _CurveDef {
  const _CurveDef(this.name, this.curve, this.color);
  final String name;
  final Curve curve;
  final Color color;
}

// =============================================================================
// 4. Interactive Control Console & Duration Chooser
// =============================================================================

class _InteractiveControlConsole extends StatelessWidget {
  const _InteractiveControlConsole();

  @override
  Widget build(BuildContext context) {
    final store = context.whatOf<CompositeMotionStore>().peek;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Master Controls:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              // Duration Selector
              composed((context, via) {
                final currentMs = via(store.durationMs);
                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Speed: ',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    _buildSpeedChip(
                        store, 1200, '1.2s Fast', currentMs == 1200),
                    _buildSpeedChip(
                        store, 2400, '2.4s Normal', currentMs == 2400),
                    _buildSpeedChip(
                        store, 4000, '4.0s Slow-Mo', currentMs == 4000),
                  ],
                );
              }),
            ],
          ),
          // Durability Policy Chooser
          composed((context, via) {
            final currentPolicy = via(store.policy);
            return Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Policy:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                _buildPolicyChip(
                  store,
                  DurabilityPolicy.resume,
                  'Resume',
                  'Freezes on unmount, resumes from exact position upon remount',
                  currentPolicy == DurabilityPolicy.resume,
                ),
                _buildPolicyChip(
                  store,
                  DurabilityPolicy.catchUp,
                  'Catch-Up',
                  'Compensates wall-clock elapsed time while unmounted',
                  currentPolicy == DurabilityPolicy.catchUp,
                ),
                _buildPolicyChip(
                  store,
                  DurabilityPolicy.reset,
                  'Reset',
                  'Discards progress and restarts from beginning upon remount',
                  currentPolicy == DurabilityPolicy.reset,
                ),
              ],
            );
          }),
          const SizedBox(height: 10),
          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              composed((context, via) {
                final isPlaying = via(store.isPlaying);
                return FilledButton.tonalIcon(
                  onPressed: () => store.togglePlay(),
                  icon: Icon(isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  label: Text(isPlaying ? 'Pause' : 'Play'),
                );
              }),
              composed((context, via) {
                final isPingPong = via(store.isPingPong);
                return OutlinedButton.icon(
                  onPressed: () => store.togglePingPong(),
                  icon: const Icon(Icons.sync_alt_rounded),
                  label: Text(isPingPong ? 'Ping-Pong: ON' : 'Ping-Pong: OFF'),
                );
              }),
              OutlinedButton.icon(
                onPressed: () => store.playForward(),
                icon: const Icon(Icons.fast_forward_rounded),
                label: const Text('Forward'),
              ),
              OutlinedButton.icon(
                onPressed: () => store.playReverse(),
                icon: const Icon(Icons.fast_rewind_rounded),
                label: const Text('Reverse'),
              ),
              OutlinedButton.icon(
                onPressed: () => store.reset(),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              ),
              composed((context, via) {
                final isMounted = via(store.isMounted);
                return FilledButton.tonal(
                  onPressed: () => store.toggleMount(),
                  child: Text(
                    isMounted ? 'Unmount (Hibernate)' : 'Mount (Wake)',
                    style: TextStyle(
                      color: isMounted ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedChip(
      CompositeMotionStore store, int ms, String label, bool isSelected) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => store.setDuration(ms),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigoAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.indigoAccent : Colors.grey.withAlpha(60),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyChip(
    CompositeMotionStore store,
    DurabilityPolicy policy,
    String label,
    String tooltip,
    bool isSelected,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => store.setPolicy(policy),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.indigoAccent.withAlpha(40)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  isSelected ? Colors.indigoAccent : Colors.grey.withAlpha(50),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.indigoAccent : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. Sub-Animation Filter Chips
// =============================================================================

base class _SubAnimationFilterChips extends WhatWidget {
  const _SubAnimationFilterChips();

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<CompositeMotionStore>(context);
    final activeTab = via(store.activeTab);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: switch (activeTab) {
        0 => _buildOrigamiFilterChips(context, store),
        1 => _buildMultiCurveInfo(context),
        _ => _buildChainedSequenceInfo(context),
      },
    );
  }

  Widget _buildOrigamiFilterChips(
      BuildContext context, CompositeMotionStore store) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Isolate Tweens:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildFilterChip(
                store.enableSlideElevation,
                'Slide/Elevate',
                store.toggleSlideElevation,
              ),
              _buildFilterChip(
                store.enable3DRotation,
                '3D Tilt',
                store.toggle3DRotation,
              ),
              _buildFilterChip(
                store.enableBorderRadius,
                'Radius Morph',
                store.toggleBorderRadius,
              ),
              _buildFilterChip(
                store.enableColorGradient,
                'Gradient',
                store.toggleColorGradient,
              ),
              _buildFilterChip(
                store.enableElasticBadge,
                'Elastic Badge',
                store.toggleElasticBadge,
              ),
              _buildFilterChip(
                store.enableStaggeredCascade,
                'Cascade Chips',
                store.toggleStaggeredCascade,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiCurveInfo(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.speed_rounded, size: 16, color: Colors.indigoAccent),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Curve Velocity Arena: 5 Curves evaluate simultaneously from 1 Master Durable Timeline.',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildChainedSequenceInfo(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.route_rounded, size: 16, color: Colors.teal),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Sequence Phases: 4x25% Weighted TweenSequence driving Offset, Color, and Scale in lockstep.',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    What<bool> what,
    String label,
    VoidCallback onToggle,
  ) {
    return composed((context, via) {
      final isEnabled = via(what);
      return FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 10)),
        selected: isEnabled,
        onSelected: (_) => onToggle(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    });
  }
}
