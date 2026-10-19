// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 11: Dual Engine Battle (Frozen vs CatchUp Wall-Clock Comparison)
base class DualEngineBattleSectionDemo extends WhatWidget {
  const DualEngineBattleSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.dualEngineBattle;
    // [Lifecycle] Declarative Scoped Effect: Synchronizes mounting state from sleep dormancy
    via.tether(store.isSleeping.effect(() {
      store.setMounted(!store.isSleeping.peek);
    }));

    return ShowcaseCard(
      title: 'Dual Engine Battle: State Preservation vs Wall-Clock Time Warp',
      badge: 'Cases 1-1, 1-4, 4-1~4-3',
      description:
          'Compare how DurabilityPolicy.resume (freezes on hide, resumes from exact spot) and DurabilityPolicy.catchUp (compensates wall-clock elapsed time) handle dormancy.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SandboxContainer(
            minHeight: 240,
            child: composed(
              (context, via) {
                final isMounted = via(store.isMounted);
                final isSleeping = via(store.isSleeping);

                if (!isMounted) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSleeping
                              ? 'SLEEPING (3s Time Warp)'
                              : 'UNMOUNTED (Ticker Detached)',
                          style: TextStyle(
                            color: isSleeping ? Colors.amber : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isSleeping
                              ? 'Simulating Wall-Clock Dormancy Sleep...'
                              : 'Widgets are Dormant (Unmounted from Tree)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.indigoAccent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Frozen is frozen at progress. CatchUp is silently advancing in time.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final isUnbounded = via(store.isUnboundedMode);
                if (isUnbounded) {
                  return _buildUnboundedBattleView(store, context);
                }
                return _buildPlanetaryOrbitBattleView(store, context);
              },
            ),
          ),
          const SizedBox(height: 16),
          // Interactive Action Triggers (Role-based Boxed Controls)
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
                // Mode Switcher: Orbit vs Unbounded
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Simulation Mode:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    composed((context, via) {
                      final isUnbounded = via(store.isUnboundedMode);
                      return SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Planetary Orbit (0~1)'),
                            icon: Icon(Icons.rotate_right_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Unbounded Space (-1000~+5000)'),
                            icon: Icon(Icons.all_inclusive_rounded, size: 16),
                          ),
                        ],
                        selected: {isUnbounded},
                        onSelectionChanged: (set) =>
                            store.setUnboundedMode(set.first),
                      );
                    }),
                  ],
                ),
                Divider(
                  height: 20,
                  color: Theme.of(context).dividerColor.withAlpha(35),
                ),
                // Role Group 1: Dormancy & Lifecycle
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Dormancy & Lifecycle:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
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
                        composed((context, via) {
                          final isSleeping = via(store.isSleeping);
                          return FilledButton(
                            onPressed: isSleeping
                                ? () => store.cancelSleep()
                                : () => store.triggerSimulatedSleep(3),
                            child: Text(isSleeping
                                ? 'Cancel Sleep'
                                : 'Sleep 3s (Time Warp & Remount)'),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                Divider(
                  height: 20,
                  color: Theme.of(context).dividerColor.withAlpha(35),
                ),
                // Role Group 2: Mode Specific Controls
                composed((context, via) {
                  final isUnbounded = via(store.isUnboundedMode);
                  if (isUnbounded) {
                    return _buildUnboundedWarpsControls(store);
                  }
                  return _buildTrajectoryModeControls(store);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnboundedWarpsControls(DualEngineBattleStore store) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Unbounded Warps:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.fast_forward_rounded, size: 16),
          onPressed: () => store.runUnboundedJump(5000.0),
          label: const Text('Warp to +5000.0'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.fast_rewind_rounded, size: 16),
          onPressed: () => store.runUnboundedJump(-1000.0),
          label: const Text('Warp to -1000.0'),
        ),
        OutlinedButton(
          onPressed: () => store.resetUnboundedToZero(),
          child: const Text('Reset (0.0)'),
        ),
      ],
    );
  }

  Widget _buildTrajectoryModeControls(DualEngineBattleStore store) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Trajectory Mode:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        OutlinedButton(
          onPressed: () => store.togglePingPong(),
          child: composed((context, via) {
            final isPingPong = via(store.isPingPong);
            return Text(isPingPong
                ? 'Ping-Pong: ON (Reverse)'
                : 'Ping-Pong: OFF (Loop)');
          }),
        ),
      ],
    );
  }

  Widget _buildUnboundedBattleView(
    DualEngineBattleStore store,
    BuildContext context,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildUnboundedMeter(
                title: 'Frozen (Unbounded)',
                progressWhat: store.unboundedFrozenProgress,
                color: Colors.amber,
                context: context,
              ),
            ),
            Container(
              width: 1,
              height: 160,
              color: Theme.of(context).dividerColor.withAlpha(50),
            ),
            Expanded(
              child: _buildUnboundedMeter(
                title: 'CatchUp (Unbounded)',
                progressWhat: store.unboundedCatchUpProgress,
                color: Colors.cyanAccent,
                context: context,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanetaryOrbitBattleView(
    DualEngineBattleStore store,
    BuildContext context,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // Left: Frozen Orbit
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withAlpha(120)),
                    ),
                    child: const Text(
                      'Frozen (Freeze & Resume)',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildOrbitView(
                    controller: store.frozenCtrl,
                    color: Colors.amber,
                    subtitle: 'Freezes on unmount',
                    context: context,
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 160,
              color: Theme.of(context).dividerColor.withAlpha(50),
            ),
            // Right: CatchUp Orbit
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: Colors.cyanAccent.withAlpha(120)),
                    ),
                    child: const Text(
                      'CatchUp (Time-Compensated)',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildOrbitView(
                    controller: store.catchUpCtrl,
                    color: Colors.cyanAccent,
                    subtitle: 'Advances with wall-clock',
                    context: context,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // [Architecture] Multi-Controller Synthesis (Zero prop-drilling)
        const _DualOrbitDeltaGauge(),
      ],
    );
  }

  Widget _buildOrbitView({
    required DurableAnimationController controller,
    required Color color,
    required String subtitle,
    required BuildContext context,
  }) {
    return composed.animate.child(
      controller,
      (context, via, ctrl, child) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: ctrl.view,
            child: child,
          ),
          const SizedBox(height: 10),
          Text(
            'Progress: ${(ctrl.value * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(80), width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -40),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color, blurRadius: 10, spreadRadius: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnboundedMeter({
    required String title,
    required What<double> progressWhat,
    required Color color,
    required BuildContext context,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(120)),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(80),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: composed((context, via) {
            final val = via(progressWhat);
            return Column(
              children: [
                Text(
                  val.toStringAsFixed(1),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Continuous Infinite Coordinate',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

/// Realtime Synchrony & Orbit Delta Gauge via WhatWidget Multi-Controller Synthesis
base class _DualOrbitDeltaGauge extends WhatWidget {
  const _DualOrbitDeltaGauge({
    What<double>? frozenProgress,
    What<double>? catchUpProgress,
  })  : _injectedFrozenProgress = frozenProgress,
        _injectedCatchUpProgress = catchUpProgress;

  final What<double>? _injectedFrozenProgress;
  final What<double>? _injectedCatchUpProgress;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.dualEngineBattle;
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
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Frozen: ${(frozVal * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.amber,
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
                  ? 'CatchUp Lead: +${(delta * 100).toStringAsFixed(1)}%'
                  : (delta < -0.005
                      ? 'Frozen Lead: +${(-delta * 100).toStringAsFixed(1)}%'
                      : 'Orbits in Phase (0.0%)'),
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
                'CatchUp: ${(catchVal * 100).toStringAsFixed(1)}%',
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
