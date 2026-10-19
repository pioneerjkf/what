// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 14: Flutter Physics Simulation Arena (Spring, Gravity, Friction - Frozen vs CatchUp)
base class PhysicsBoundsSectionDemo extends WhatWidget {
  const PhysicsBoundsSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final PhysicsBoundsStore store =
        via.of<ShowcaseStore>(context).sections.physicsBounds;
    // [Lifecycle] Declarative Scoped Effect: Automatically reconfigures spring parameters while section is active!
    via.tether((store.springStiffness, store.springDamping).effect(() {
      if (store.physicsBoundedFrozenCtrl.isAnimating) {
        store.runSpringSimulation();
      }
    }));

    return ShowcaseCard(
      title: 'Flutter Physics Simulation Arena (Spring, Gravity, Friction)',
      badge: 'Cases 1-2, 1-5, 3-5, 3-6',
      description:
          'Compare how DurabilityPolicy.resume (freezes mid-bounce on hide) and DurabilityPolicy.catchUp (compensates wall-clock drop time) drive Flutter physics simulations.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Physics Visual Arena (Dual Visualizers)
          SandboxContainer(
            minHeight: 220,
            child: composed((context, via) {
              final isMounted = via(store.isMounted);
              return isMounted
                  ? Column(
                      children: [
                        Row(
                          children: [
                            // Left: Frozen Physics Ball
                            Expanded(
                              child: _buildPhysicsVisualizer(
                                controller: store.physicsBoundedFrozenCtrl,
                                title: 'Frozen Physics',
                                subtitle: 'Freezes in mid-air',
                                color: Colors.orangeAccent,
                                context: context,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 160,
                              color:
                                  Theme.of(context).dividerColor.withAlpha(50),
                            ),
                            // Right: CatchUp Physics Ball
                            Expanded(
                              child: _buildPhysicsVisualizer(
                                controller: store.physicsBoundedCatchUpCtrl,
                                title: 'CatchUp Physics',
                                subtitle: 'Wall-clock trajectory',
                                color: Colors.cyanAccent,
                                context: context,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // [Architecture] Multi-Controller Synthesis (Zero prop-drilling)
                        _PhysicsHeightDeltaGauge(),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            'Physics Engine Dormant (Visual Tree Unmounted)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigoAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Simulations preserve exact velocity and progress or wall-clock settle.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    );
            }),
          ),
          const SizedBox(height: 16),

          // Interactive Control Panel (Role-based Boxed Controls)
          Container(
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
                // Role Group 1: Physics Parameters
                const Text(
                  'Physics Parameters:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: composed((context, via) {
                        final stiffness = via(store.springStiffness);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spring Stiffness: ${stiffness.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Slider(
                              value: stiffness,
                              min: 10,
                              max: 200,
                              onChanged: (v) => store.setSpringStiffness(v),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: composed((context, via) {
                        final damping = via(store.springDamping);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spring Damping: ${damping.toStringAsFixed(1)}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Slider(
                              value: damping,
                              min: 1,
                              max: 30,
                              onChanged: (v) => store.setSpringDamping(v),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: composed((context, via) {
                        final friction = via(store.frictionDrag);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Friction Drag: ${friction.toStringAsFixed(3)}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Slider(
                              value: friction,
                              min: 0.01,
                              max: 0.3,
                              onChanged: (v) => store.setFrictionDrag(v),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
                Divider(
                  height: 20,
                  color: Theme.of(context).dividerColor.withAlpha(35),
                ),
                // Role Group 2: Simulation Engines
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Simulation Engines:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        FilledButton(
                          onPressed: () => store.runSpringSimulation(),
                          child: const Text('SpringSimulation (Bounce)'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => store.runGravitySimulation(),
                          child: const Text('GravitySimulation (Drop)'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => store.runFrictionSimulation(),
                          child: const Text('FrictionSimulation (Slide)'),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                  height: 20,
                  color: Theme.of(context).dividerColor.withAlpha(35),
                ),
                // Role Group 3: Engine Lifecycle & Stress Churn
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Lifecycle & Stress:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        composed((context, via) {
                          final isMounted = via(store.isMounted);
                          return FilledButton.tonal(
                            onPressed: () => store.toggleMount(),
                            child: Text(isMounted
                                ? 'Unmount (Hide)'
                                : 'Remount (Show)'),
                          );
                        }),
                        _buildFlappingButton(store),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlappingButton(PhysicsBoundsStore store) {
    return composed((context, via) {
      final isFlapping = via(store.isFlappingRunning);
      if (isFlapping) {
        return _buildRunningFlappingButton(store);
      }
      return _buildIdleFlappingButton(store);
    });
  }

  Widget _buildRunningFlappingButton(PhysicsBoundsStore store) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.redAccent,
      ),
      icon: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      ),
      onPressed: () => store.stopFlappingStress(),
      label: composed((context, via) {
        final cycles = via(store.flappingCycles);
        return Text('Stop Flapping ($cycles/30)');
      }),
    );
  }

  Widget _buildIdleFlappingButton(PhysicsBoundsStore store) {
    return FilledButton.icon(
      icon: const Icon(Icons.flash_on_rounded, size: 16),
      onPressed: () => store.runFlappingStress(30),
      label: const Text('Rapid Flapping (30x Stress)'),
    );
  }

  Widget _buildPhysicsVisualizer({
    required DurableAnimationController controller,
    required String title,
    required String subtitle,
    required Color color,
    required BuildContext context,
  }) {
    return composed.animate.child(
      controller,
      (context, via, ctrl, child) {
        final val = ctrl.value;
        // Map val (0.0=top, 1.0=ground) safely within container bounds (-32px to +24px)
        final bounceOffset = 24.0 - (56.0 * (1.0 - val.clamp(0.0, 1.5)));
        final squashScaleX = 1.0 + (val > 0.9 ? (val - 0.9) * 1.5 : 0.0);
        final squashScaleY = 1.0 - (val > 0.9 ? (val - 0.9) * 1.2 : 0.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Static Title Badge (0 rebuilds during bounce)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withAlpha(100)),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // [Visualizer] Pinpoint: Bouncing & Squashing Particle Visualizer
            Transform.translate(
              offset: Offset(0, bounceOffset),
              child: Transform.scale(
                scaleX: squashScaleX.clamp(0.7, 1.4),
                scaleY: squashScaleY.clamp(0.7, 1.4),
                child: child,
              ),
            ),
            const SizedBox(height: 20),

            // Live Height Telemetry Text
            Text(
              'Height: ${val.toStringAsFixed(3)}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),

            // Static Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(160),
              blurRadius: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Realtime Height & Bounce Delta Gauge via WhatWidget Multi-Controller Synthesis
base class _PhysicsHeightDeltaGauge extends WhatWidget {
  const _PhysicsHeightDeltaGauge({
    What<double>? frozenProgress,
    What<double>? catchUpProgress,
  })  : _injectedFrozenProgress = frozenProgress,
        _injectedCatchUpProgress = catchUpProgress;

  final What<double>? _injectedFrozenProgress;
  final What<double>? _injectedCatchUpProgress;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.physicsBounds;
    final frozenWhat = _injectedFrozenProgress ?? store.frozenProgress;
    final catchUpWhat = _injectedCatchUpProgress ?? store.catchUpProgress;
    final frozVal = via(frozenWhat);
    final catchVal = via(catchUpWhat);
    final delta = (catchVal - frozVal);
    final isCatchAhead = delta > 0.005;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Frozen: ${frozVal.toStringAsFixed(3)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isCatchAhead
                  ? Colors.cyanAccent.withAlpha(30)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isCatchAhead
                  ? 'CatchUp Drop Delta: +${delta.toStringAsFixed(3)}'
                  : (delta < -0.005
                      ? 'Frozen Drop Delta: +${(-delta).toStringAsFixed(3)}'
                      : 'Physics in Perfect Sync (0.000)'),
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: isCatchAhead ? Colors.cyanAccent : Colors.white70,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CatchUp: ${catchVal.toStringAsFixed(3)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.cyanAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
