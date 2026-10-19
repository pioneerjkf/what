// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

base class SimulationFlappingSectionDemo extends WhatWidget {
  const SimulationFlappingSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.simulationFlapping;
    final isMounted = via(store.isMounted);
    final isFlappingRunning = via(store.isFlappingRunning);
    final isAutoBounce = via(store.isAutoBounce);
    final intervalMs = via(store.flappingIntervalMs);
    final cycles = via(store.flappingCyclesCompleted);
    final simType = via(store.activeSimulationType);
    final logs = via(store.diagnosticLogs);
    final speed = via(store.speedScale);

    return ShowcaseCard(
      title: 'Physics Simulation Flapping & Stress Verification Lab',
      badge: 'Cases 2-8, 4-8, 6-4',
      description:
          'Run continuous Spring, Gravity, and Friction physics simulations with auto-bounce and adjustable speed while subjecting the controllers to 1000x rapid mounting flapping stress.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Arena
          SandboxContainer(
            minHeight: 270,
            child: isMounted
                ? Column(
                    children: [
                      Row(
                        children: [
                          // Left: Frozen Physics Particle
                          Expanded(
                            child: _buildPhysicsParticle(
                              controller: store.frozenPhysicsCtrl,
                              color: Colors.amber,
                              title: isFlappingRunning
                                  ? 'Frozen Flapping ($cycles/1000)'
                                  : 'Frozen Physics',
                              subtitle:
                                  'Preserves mid-air velocity & height on unmount',
                              context: context,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 170,
                            color: Theme.of(context).dividerColor.withAlpha(50),
                          ),
                          // Right: CatchUp Physics Particle
                          Expanded(
                            child: _buildPhysicsParticle(
                              controller: store.catchUpPhysicsCtrl,
                              color: Colors.cyanAccent,
                              title: isFlappingRunning
                                  ? 'CatchUp Flapping ($cycles/1000)'
                                  : 'CatchUp Physics',
                              subtitle:
                                  'Integrates real wall-clock physics elapsed time',
                              context: context,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Live Physics Delta Comparison Bar (Zero prop-drilling)
                      _PhysicsDeltaGauge(),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Physics Engines Detached (Dormant State)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.indigoAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Active Simulation: $simType. Frozen freezes mid-air; CatchUp integrates wall-clock flight.',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Speed & Flapping Interval Controls Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Simulation Speed:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('0.3x (Slow-Mo / 5s)',
                              style: TextStyle(fontSize: 11)),
                          selected: speed == 0.3,
                          onSelected: (_) => store.setSpeedPreset(0.3),
                        ),
                        ChoiceChip(
                          label: const Text('0.6x (Medium)',
                              style: TextStyle(fontSize: 11)),
                          selected: speed == 0.6,
                          onSelected: (_) => store.setSpeedPreset(0.6),
                        ),
                        ChoiceChip(
                          label: const Text('1.0x (Normal)',
                              style: TextStyle(fontSize: 11)),
                          selected: speed == 1.0,
                          onSelected: (_) => store.setSpeedPreset(1.0),
                        ),
                        ChoiceChip(
                          label: const Text('2.0x (Fast)',
                              style: TextStyle(fontSize: 11)),
                          selected: speed == 2.0,
                          onSelected: (_) => store.setSpeedPreset(2.0),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16, color: Colors.white10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Flapping Stress Mode:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('20ms (Ultra Flapping Stress)',
                              style: TextStyle(fontSize: 11)),
                          selected: intervalMs == 20,
                          onSelected: (_) => store.setFlappingInterval(20),
                        ),
                        ChoiceChip(
                          label: const Text('150ms (Visual Slow Flapping)',
                              style: TextStyle(fontSize: 11)),
                          selected: intervalMs == 150,
                          onSelected: (_) => store.setFlappingInterval(150),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Diagnostic Console
          Container(
            height: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(200),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'PHYSICS FLAPPING TELEMETRY',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isFlappingRunning
                            ? Colors.red.withAlpha(40)
                            : Colors.green.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isFlappingRunning ? Colors.red : Colors.green,
                        ),
                      ),
                      child: Text(
                        isFlappingRunning
                            ? 'FLAPPING STRESS ACTIVE'
                            : 'STEADY STATE',
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: isFlappingRunning ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 12),
                Expanded(
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            'Click test buttons below to run physics simulations during flapping.',
                            style: TextStyle(
                                color: Colors.white54,
                                fontFamily: 'monospace',
                                fontSize: 11),
                          ),
                        )
                      : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 1.5),
                              child: Text(
                                '❯ ${logs[index]}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFF67E8F9),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Controls: Boxed by Functional Role
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role 1: Benchmark & Lifecycle
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Benchmark & Lifecycle:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                isFlappingRunning ? Colors.red : null,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          icon: Icon(
                              isFlappingRunning
                                  ? Icons.stop_circle_rounded
                                  : Icons.bolt_rounded,
                              size: 16),
                          onPressed: isFlappingRunning
                              ? () => store.stopFlappingStress()
                              : () => store.runFlappingStressTest(1000),
                          label: Text(
                            isFlappingRunning
                                ? 'Stop Flapping ($cycles/1000)'
                                : 'Run 1000x Simulation Flapping Stress',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          icon: Icon(
                              isMounted
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 15),
                          onPressed: () => store.toggleMount(),
                          label: Text(
                              isMounted ? 'Unmount (Hide)' : 'Remount (Show)',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.snooze_rounded, size: 15),
                          onPressed: () => store
                              .unmountForDuration(const Duration(seconds: 3)),
                          label: const Text('Sleep 3s',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                    height: 20,
                    color: Theme.of(context).dividerColor.withAlpha(35)),

                // Role 2: Simulation Engine Models
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Simulation Models:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.waves_rounded, size: 15),
                          onPressed: () => store.runSpringSimulation(),
                          label: const Text('Spring (Bounce)',
                              style: TextStyle(fontSize: 12)),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.south_rounded, size: 15),
                          onPressed: () => store.runGravitySimulation(),
                          label: const Text('Gravity (Drop)',
                              style: TextStyle(fontSize: 12)),
                        ),
                        FilledButton.tonalIcon(
                          icon:
                              const Icon(Icons.linear_scale_rounded, size: 15),
                          onPressed: () => store.runFrictionSimulation(),
                          label: const Text('Friction (Glide)',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                    height: 20,
                    color: Theme.of(context).dividerColor.withAlpha(35)),

                // Role 3: Playback Directives & Reset
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Playback & Reset:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          label: Text(
                            isAutoBounce
                                ? 'Auto-Bounce: ON'
                                : 'Auto-Bounce: OFF',
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isAutoBounce,
                          onSelected: (_) => store.toggleAutoBounce(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                          onPressed: () => store.reverseDirection(),
                          label: const Text('Reverse',
                              style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            side: BorderSide(color: Colors.red.withAlpha(100)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          onPressed: () => store.reset(),
                          label: const Text('Reset',
                              style: TextStyle(fontSize: 12)),
                        ),
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

  Widget _buildPhysicsParticle({
    required DurableAnimationController controller,
    required Color color,
    required String title,
    required String subtitle,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Static Title Badge + Pinpoint Live Position
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // [Pinpoint 1] Only position text rebuilds on frame ticks
              composed.animate(
                controller,
                (context, via, ctrl) => Text(
                  'Pos: ${ctrl.value.toStringAsFixed(3)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // [Pinpoint 2] Physics Tube with kinetic particle
          SizedBox(
            height: 100,
            width: double.infinity,
            child: composed.animate.child(
              controller,
              (context, via, ctrl, child) {
                final val = ctrl.value.clamp(0.0, 1.0);
                return CustomPaint(
                  painter: _PhysicsTubePainter(
                    progress: val,
                    color: color,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment((val * 2) - 1.0, 0.0),
                        child: child,
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(180),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Live Physics Lead & Trajectory Delta Gauge with WhatWidget
base class _PhysicsDeltaGauge extends WhatWidget {
  const _PhysicsDeltaGauge({
    What<double>? frozenProgress,
    What<double>? catchUpProgress,
  })  : _injectedFrozenProgress = frozenProgress,
        _injectedCatchUpProgress = catchUpProgress;

  final What<double>? _injectedFrozenProgress;
  final What<double>? _injectedCatchUpProgress;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.simulationFlapping;
    final frozenWhat = _injectedFrozenProgress ?? store.frozenProgress;
    final catchWhat = _injectedCatchUpProgress ?? store.catchUpProgress;
    final frozVal = via(frozenWhat);
    final catchVal = via(catchWhat);
    final diff = (catchVal - frozVal);
    final isCatchAhead = diff > 0.005;

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
                  ? 'CatchUp +${(diff * 100).toStringAsFixed(1)}% Lead'
                  : (diff < -0.005
                      ? 'Frozen +${(-diff * 100).toStringAsFixed(1)}% Lead'
                      : 'In Synchrony (0.0%)'),
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

class _PhysicsTubePainter extends CustomPainter {
  _PhysicsTubePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    // 1. Background Rail Track
    final railPaint = Paint()
      ..color = color.withAlpha(30)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(16, centerY),
      Offset(size.width - 16, centerY),
      railPaint,
    );

    // 2. Spring / Force Coils from left edge to particle
    final particleX = 16 + (progress * (size.width - 32));
    final springPath = Path();
    springPath.moveTo(16, centerY);

    const int coils = 12;
    final coilWidth = (particleX - 16) / coils;
    if (coilWidth > 2) {
      for (int i = 0; i < coils; i++) {
        final x1 = 16 + (i * coilWidth) + (coilWidth / 4);
        final x2 = 16 + (i * coilWidth) + (coilWidth * 3 / 4);
        final yOffset = (i % 2 == 0 ? 1 : -1) * 10.0;
        springPath.quadraticBezierTo(x1, centerY + yOffset, x2, centerY);
      }
      springPath.lineTo(particleX, centerY);

      final springPaint = Paint()
        ..color = color.withAlpha(120)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(springPath, springPaint);
    }

    // 3. Impact boundary rings at 0.0 and 1.0
    final borderPaint = Paint()
      ..color = color.withAlpha(80)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(16, centerY), 16, borderPaint);
    canvas.drawCircle(Offset(size.width - 16, centerY), 16, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PhysicsTubePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
