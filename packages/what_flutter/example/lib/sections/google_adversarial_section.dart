// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

base class GoogleAdversarialSectionDemo extends WhatWidget {
  const GoogleAdversarialSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.googleAdversarial;
    final isChurnRunning = via(store.isChurnRunning);
    final isReversed = via(store.isReversed);
    final cycles = via(store.churnCyclesCompleted);
    final logs = via(store.adversarialLogs);
    final isMounted = via(store.isMounted);

    return ShowcaseCard(
      title: 'Google & Flutter Engine Team Adversarial Verification Suite',
      badge: 'Cases 1-3, 2-5~2-7, 4-4~4-7',
      description:
          'Subject the animation controllers to rapid mounting flapping stress (1000x rapid mount/unmount cycles), NTP clock rewinds (-1 hour jump), and non-frozen reset modes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Arena
          SandboxContainer(
            minHeight: 240,
            child: isMounted
                ? Row(
                    children: [
                      // Left: Quantum Forcefield Shield
                      Expanded(
                        child: _buildQuantumShield(
                          controller: store.churnFrozenCtrl,
                          color: Colors.greenAccent,
                          title: isChurnRunning
                              ? 'Shield Flapping ($cycles/1000)'
                              : 'Quantum Shield (0 Leaks)',
                          subtitle: 'Freezes forcefield angle on unmount',
                          context: context,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 180,
                        color: Theme.of(context).dividerColor.withAlpha(50),
                      ),
                      // Right: Tactical Sonar Radar
                      Expanded(
                        child: _buildCyberRadar(
                          controller: store.churnCatchUpCtrl,
                          color: Colors.cyanAccent,
                          title: isChurnRunning
                              ? 'Sonar Churn ($cycles/1000)'
                              : 'Tactical Sonar (Real-Time)',
                          subtitle: 'Continuous wall-clock radar sweep',
                          context: context,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          'All Churn Arena Subtrees Dormant',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigoAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stress events queued or completed while unmounted: zero memory leaks.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Diagnostic Console
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(200),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'ADVERSARIAL STRESS CONSOLE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 12),
                Expanded(
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            'Click test buttons below to run adversarial tests.',
                            style: TextStyle(
                                color: Colors.white54,
                                fontFamily: 'monospace',
                                fontSize: 11),
                          ),
                        )
                      : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            return Text(
                              '❯ ${logs[index]}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Triggers: Boxed by Functional Role
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
                // Role 1: Stress Benchmark & Mount
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Stress Benchmark:',
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
                            backgroundColor: isChurnRunning ? Colors.red : null,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          icon: Icon(
                            isChurnRunning
                                ? Icons.stop_circle_rounded
                                : Icons.bolt_rounded,
                            size: 16,
                          ),
                          onPressed: isChurnRunning
                              ? () => store.stopFlappingStress()
                              : () => store.runFlappingStressTest(1000),
                          label: Text(
                            isChurnRunning
                                ? 'Stop Flapping ($cycles/1000)'
                                : 'Run 1000x Ultra Flapping Stress',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          icon: Icon(
                            isMounted
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 15,
                          ),
                          onPressed: () => store.toggleMount(),
                          label: Text(
                            isMounted ? 'Unmount (Hide)' : 'Remount (Show)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                    height: 20,
                    color: Theme.of(context).dividerColor.withAlpha(35)),

                // Role 2: Adversarial Injections & Tests
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Adversarial Injections:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.history_rounded, size: 15),
                          onPressed: () => store.simulateNtpRewind(),
                          label: const Text('Simulate NTP Clock Rewind (-1h)',
                              style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                          onPressed: () => store.toggleDirection(),
                          label: Text(
                            isReversed
                                ? 'Direction: Reverse (Ping-Pong)'
                                : 'Direction: Forward (Loop)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.replay_rounded, size: 15),
                          onPressed: () => store.testNonFrozenReset(),
                          label: const Text('Test frozen: false Reset',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                    height: 20,
                    color: Theme.of(context).dividerColor.withAlpha(35)),

                // Role 3: Dormant Command Staging (Thrashing Immunity)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Dormant Motion Staging:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 15),
                          onPressed: () => store.stageForward(),
                          label: const Text('Stage forward()',
                              style: TextStyle(fontSize: 12)),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.arrow_back_rounded, size: 15),
                          onPressed: () => store.stageReverse(),
                          label: const Text('Stage reverse()',
                              style: TextStyle(fontSize: 12)),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.bolt_rounded, size: 15),
                          onPressed: () => store.stageFling(2.5),
                          label: const Text('Stage fling(2.5)',
                              style: TextStyle(fontSize: 12)),
                        ),
                        composed((context, via) {
                          final last = via(store.lastStagedAction);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.indigo.withAlpha(80)),
                            ),
                            child: Text(
                              'Queue: $last',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.indigoAccent,
                              ),
                            ),
                          );
                        }),
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

  Widget _buildQuantumShield({
    required DurableAnimationController controller,
    required Color color,
    required String title,
    required String subtitle,
    required BuildContext context,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 104,
          height: 104,
          child: composed.animate.child(
            controller,
            (context, via, ctrl, child) => Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(104, 104),
                  painter: _QuantumShieldPainter(
                    progress: ctrl.value,
                    color: color,
                  ),
                ),
                child,
              ],
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withAlpha(140), blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
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
        const SizedBox(height: 4),
        composed.animate(
          controller,
          (context, via, ctrl) {
            final val = ctrl.value;
            final degrees = (val * 360.0).toStringAsFixed(0);
            final percent = (val * 100.0).toStringAsFixed(1);
            return Text(
              '$degrees°  ($percent%)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCyberRadar({
    required DurableAnimationController controller,
    required Color color,
    required String title,
    required String subtitle,
    required BuildContext context,
  }) {
    return composed.animate.child(
      controller,
      (context, via, ctrl, child) {
        final val = ctrl.value;
        final degrees = (val * 360.0).toStringAsFixed(0);
        final percent = (val * 100.0).toStringAsFixed(1);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(104, 104),
                    painter: _CyberRadarPainter(
                      progress: val,
                      color: color,
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: color, blurRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            child,
            const SizedBox(height: 4),
            Text(
              '$degrees°  ($percent%)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
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
    );
  }
}

class _QuantumShieldPainter extends CustomPainter {
  _QuantumShieldPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer segmented tick ring
    final tickPaint = Paint()
      ..color = color.withAlpha(60)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const numTicks = 20;
    for (int i = 0; i < numTicks; i++) {
      final angle = (i * 2 * math.pi / numTicks) + (progress * 2 * math.pi);
      final p1 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 5);
      final p2 = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 2. Hexagonal energy field
    final hexPath = Path();
    const sides = 6;
    final hexRadius = radius * 0.72;
    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * math.pi / sides) - (progress * 2 * math.pi);
      final pt = center + Offset(math.cos(angle), math.sin(angle)) * hexRadius;
      if (i == 0) {
        hexPath.moveTo(pt.dx, pt.dy);
      } else {
        hexPath.lineTo(pt.dx, pt.dy);
      }
    }
    hexPath.close();

    final hexFillPaint = Paint()
      ..color = color.withAlpha(25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hexPath, hexFillPaint);

    final hexStrokePaint = Paint()
      ..color = color.withAlpha(160)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(hexPath, hexStrokePaint);

    // 3. Dynamic arc gauge (showing progress)
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      arcPaint,
    );

    // 4. Central pulsing glow core
    final pulseRadius =
        radius * (0.32 + 0.08 * math.sin(progress * 2 * math.pi));
    final coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [color.withAlpha(100), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: pulseRadius));
    canvas.drawCircle(center, pulseRadius, coreGlow);
  }

  @override
  bool shouldRepaint(covariant _QuantumShieldPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _CyberRadarPainter extends CustomPainter {
  _CyberRadarPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Concentric radar grid rings
    final gridPaint = Paint()
      ..color = color.withAlpha(40)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius * 0.35, gridPaint);
    canvas.drawCircle(center, radius * 0.70, gridPaint);
    canvas.drawCircle(center, radius, gridPaint);

    // 2. Crosshair grid lines (+ axis)
    final axisPaint = Paint()
      ..color = color.withAlpha(50)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      axisPaint,
    );

    // 3. Rotating Sweeping Sonar Beam (Sector Gradient)
    final sweepAngle = (progress * 2 * math.pi) - (math.pi / 2);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          Colors.transparent,
          color.withAlpha(15),
          color.withAlpha(150),
        ],
        stops: const [0.0, 0.4, 1.0],
        transform: GradientRotation(sweepAngle - (math.pi / 2)),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    // 4. Leading sweep line
    final sweepLinePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0;
    final lineEnd =
        center + Offset(math.cos(sweepAngle), math.sin(sweepAngle)) * radius;
    canvas.drawLine(center, lineEnd, sweepLinePaint);

    // 5. Radar Targets (Blips) that light up
    final targets = [
      Offset(center.dx + radius * 0.45, center.dy - radius * 0.35),
      Offset(center.dx - radius * 0.50, center.dy + radius * 0.40),
      Offset(center.dx + radius * 0.30, center.dy + radius * 0.60),
    ];

    for (final target in targets) {
      final angleToTarget =
          (math.atan2(target.dy - center.dy, target.dx - center.dx) +
                  (2 * math.pi)) %
              (2 * math.pi);
      final normalizedSweep = (sweepAngle + (2 * math.pi)) % (2 * math.pi);
      final diff =
          (normalizedSweep - angleToTarget + (2 * math.pi)) % (2 * math.pi);
      final brightness = diff < 1.0 ? (1.0 - diff).clamp(0.25, 1.0) : 0.25;

      final blipPaint = Paint()
        ..color = color.withAlpha((brightness * 255).toInt())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(target, 3.5, blipPaint);

      if (brightness > 0.6) {
        final blipRingPaint = Paint()
          ..color = color.withAlpha(((brightness - 0.5) * 200).toInt())
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(target, 7.0, blipRingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberRadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
