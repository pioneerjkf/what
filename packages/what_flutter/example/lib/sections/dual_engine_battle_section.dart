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
      store.setMounted(!untracked(store.isSleeping));
    }));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShowcaseCard(
          title:
              'Dual Engine Battle: State Preservation vs Wall-Clock Time Warp',
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
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                icon:
                                    Icon(Icons.rotate_right_rounded, size: 16),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Unbounded Space (-1000~+5000)'),
                                icon:
                                    Icon(Icons.all_inclusive_rounded, size: 16),
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
        ),
        const SizedBox(height: 16),
        _RepeatLoopBudgetLabCard(store: store),
      ],
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
                controller: store.unboundedFrozenCtrl,
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
                controller: store.unboundedCatchUpCtrl,
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
    required DurableAnimationController controller,
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
          child: composed.animate(
            controller,
            (context, via, ctrl) => Column(
              children: [
                Text(
                  ctrl.value.toStringAsFixed(1),
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
            ),
          ),
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

// =============================================================================
// Repeat(count: N) Loop Budget & Dormancy Resumption Lab
// =============================================================================

base class _RepeatLoopBudgetLabCard extends WhatWidget {
  const _RepeatLoopBudgetLabCard({required this.store});

  final DualEngineBattleStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final isMounted = via(store.isRepeatMounted);
    final phase = via(store.repeatPhase);
    final isAutoRunning = via(store.isAutoScenarioRunning);
    final selectedCount = via(store.repeatCount);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShowcaseCard(
      title: 'Repeat(count: N) Loop Budget & Dormancy Lab',
      badge: 'Active + Dormant + Wake Budget Invariant',
      description:
          'Demonstrates loop count integrity across active and dormant lifecycles. '
          'Even when unmounted mid-animation, waking does NOT restart with full count; '
          'it strictly terminates at the exact total accumulated count (Active + Dormancy + Resumed = Total Budget).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phase & Lifecycle Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMounted
                  ? Colors.teal.withAlpha(25)
                  : Colors.amber.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMounted
                    ? Colors.teal.withAlpha(120)
                    : Colors.amber.withAlpha(120),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMounted ? Icons.sync_rounded : Icons.bedtime_rounded,
                  color: isMounted ? Colors.teal : Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMounted
                            ? 'LIFECYCLE: ACTIVE (CatchUp Controller Mounted)'
                            : 'LIFECYCLE: DORMANT (Unmounted from Tree)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMounted ? Colors.teal : Colors.amber,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current Stage: $phase',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Visual Stage Box
          SandboxContainer(
            minHeight: 180,
            child: isMounted
                ? composed.animate(
                    store.repeatCatchUpCtrl,
                    (context, via, ctrl) => _buildLiveRepeatVisualizer(
                      ctrl: ctrl,
                      targetCount: selectedCount,
                      theme: theme,
                      isDark: isDark,
                      context: context,
                    ),
                  )
                : _buildDormantPlaceholder(),
          ),
          const SizedBox(height: 16),

          // Interactive Control Station
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withAlpha(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Target Count Selector
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Target Repeat Budget (Count):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    for (final item in const [
                      (2, 'count: 2 (1 round trip / 4s)'),
                      (4, 'count: 4 (2 round trips / 8s) ★ Recommended'),
                      (6, 'count: 6 (3 round trips / 12s)'),
                    ])
                      ChoiceChip(
                        label:
                            Text(item.$2, style: const TextStyle(fontSize: 11)),
                        selected: selectedCount == item.$1,
                        onSelected: isAutoRunning
                            ? null
                            : (_) => store.setRepeatCount(item.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor.withAlpha(30)),
                const SizedBox(height: 12),

                // Auto Scenario 1-Click Button
                FilledButton.icon(
                  onPressed:
                      isAutoRunning ? null : () => store.runAutoScenario(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: isAutoRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bolt_rounded, size: 20),
                  label: Text(
                    isAutoRunning
                        ? 'Running Auto Simulation (Active -> Dormant -> Awakened)...'
                        : 'Run Auto Scenario: Active -> Dormant -> Wake (Target: $selectedCount legs / ${selectedCount ~/ 2} round trips)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor.withAlpha(30)),
                const SizedBox(height: 12),

                // Manual Step Buttons
                const Text(
                  'Manual Step-by-Step Verification:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isAutoRunning
                          ? null
                          : () => store.startRepeat(reverse: true),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text('1. Start repeat(count: $selectedCount, 2s)',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: isAutoRunning || !isMounted
                          ? null
                          : () => store.hibernateRepeat(),
                      icon: const Icon(Icons.pause_circle_outline_rounded,
                          size: 16),
                      label: const Text('2. Unmount (Hibernate)',
                          style: TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: isAutoRunning || isMounted
                          ? null
                          : () => store.wakeRepeat(),
                      icon: const Icon(Icons.play_circle_outline_rounded,
                          size: 16),
                      label: const Text('3. Remount (Wake)',
                          style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () => store.resetRepeat(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label:
                          const Text('Reset', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Theoretical Explanation Callout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.blueAccent.withAlpha(60),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: Colors.blueAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '💡 Flutter repeat(count: N, reverse: true) Specification & Bug Fix Verification:\n'
                    '• Flutter Official Spec: When reverse: true, count specifies "Directional Legs/Runs", NOT round trips.\n'
                    '  - count: 2 = Forward 1x (0->1) + Reverse 1x (1->0) = Exactly 1 Round Trip (4.0s budget)\n'
                    '  - count: 4 = Forward 2x + Reverse 2x = Exactly 2 Round Trips (8.0s budget)\n'
                    '• Bug (Before Fix): Waking from dormancy restarted with the full initial count, overshooting total loops.\n'
                    '• Fix (Durable): Accurately deducts loops consumed across active & dormant periods, terminating cleanly on budget!',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: isDark ? Colors.blue[100] : Colors.blue[900],
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

  Widget _buildLiveRepeatVisualizer({
    required DurableAnimationController ctrl,
    required int targetCount,
    required ThemeData theme,
    required bool isDark,
    required BuildContext context,
  }) {
    final val = ctrl.value.clamp(0.0, 1.0);
    final isAnimating = ctrl.isAnimating;
    final status = ctrl.status;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Telemetry Row (Responsive Wrap to prevent overflow)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildBadge(
                    label: isAnimating ? 'TICKING' : 'HALTED',
                    color: isAnimating ? Colors.green : Colors.purple,
                    icon: isAnimating
                        ? Icons.motion_photos_on_rounded
                        : Icons.check_circle_rounded,
                  ),
                  _buildBadge(
                    label: 'Status: ${status.name}',
                    color: Colors.cyan,
                  ),
                  _buildBadge(
                    label:
                        'Target: $targetCount legs (${targetCount ~/ 2} round trips)',
                    color: Colors.indigo,
                  ),
                  if (isAnimating)
                    _buildBadge(
                      label: status == AnimationStatus.reverse
                          ? '◀ Reverse (1->0)'
                          : '▶ Forward (0->1)',
                      color: Colors.teal,
                    ),
                ],
              ),
              Text(
                'Value: ${val.toStringAsFixed(3)}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Shuttle Progress Track
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: val,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.indigo, Colors.cyanAccent],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Shuttle Head
          Align(
            alignment: Alignment((val * 2) - 1.0, 0.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withAlpha(150),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == AnimationStatus.reverse
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    val.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isAnimating
                ? (status == AnimationStatus.reverse
                    ? '◀ Reverse phase: moving towards 0.00...'
                    : '▶ Forward phase: moving towards 1.00...')
                : 'Animation Complete: Cleanly terminated at total budget ($targetCount legs / ${targetCount ~/ 2} round trips).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAnimating ? Colors.teal : Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDormantPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              color: Colors.amber,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Visual Renderer Detached (Dormant State)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Wall-clock time continuity is actively running in background.\n'
            'Press "Remount (Wake)" to view compensated progress.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
