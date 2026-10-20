// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

base class TriPatternMatrixSectionDemo extends WhatWidget {
  const TriPatternMatrixSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.triPatternMatrix;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShowcaseCard(
      title: 'Tri-Pattern Animation & Wake Matrix',
      badge: '3 Canonical Pathways',
      description:
          'Demonstrates the 3 interchangeable ways to render animations in What. '
          'Pattern A & C bind to an external Store controller, while Pattern B runs autonomously on raw frame ticks.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Controller Telemetry Status Bar
          composed.animate(
            store.controller,
            (context, via, ctrl) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withAlpha(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          ctrl.isAnimating
                              ? Icons.sync_rounded
                              : Icons.pause_circle_outline,
                          size: 16,
                          color: ctrl.isAnimating ? Colors.green : Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Store Controller: ${ctrl.status.name.toUpperCase()} (${ctrl.isAnimating ? "Animating" : "Halted at ${ctrl.value.toStringAsFixed(2)}"})',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ctrl.isAnimating ? Colors.green : Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Value: ${(ctrl.value * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
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

          // Main Tri-Pattern Comparison Stage
          SandboxContainer(
            minHeight: 220,
            child: composed.child(
              (context, via, child) => via(store.isMounted)
                  ? child
                  : const Center(
                      child: Text('All 3 Animation Subtrees are Dormant.'),
                    ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Pattern A: Functional Inline composed.animate
                    _buildPatternColumnBox(
                      context: context,
                      title: 'Pattern A',
                      method: 'composed.animate',
                      roleBadge: 'Controller-Bound',
                      badgeColor: Colors.indigoAccent,
                      statusWidget: composed.animate(
                        store.controller,
                        (context, via, ctrl) => Text(
                          ctrl.isAnimating ? 'Spinning (6s)' : 'Halted (0.00)',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color:
                                ctrl.isAnimating ? Colors.green : Colors.amber,
                          ),
                        ),
                      ),
                      child: composed.animate(
                        store.controller,
                        (context, via, ctrl) {
                          return RotationTransition(
                            turns: ctrl.view,
                            child: _buildGeometryBox(Colors.indigoAccent),
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),

                    // Pattern B: Value-Driven composed.drive (Zero controller)
                    _buildPatternColumnBox(
                      context: context,
                      title: 'Pattern B',
                      method: 'composed.drive',
                      roleBadge: 'Autonomous Ticker',
                      badgeColor: Colors.purpleAccent,
                      statusWidget: const Text(
                        'Always Running (2s)',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.purpleAccent,
                        ),
                      ),
                      child: composed.drive(
                        (elapsed) => (elapsed.inMilliseconds % 2000) / 2000.0,
                        (context, via, turns) => Transform.rotate(
                          angle: turns * 2 * 3.141592653589793,
                          child: _buildGeometryBox(Colors.purpleAccent),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),

                    // Pattern C: Static Child Memoization (composed.animate.child)
                    _buildPatternColumnBox(
                      context: context,
                      title: 'Pattern C',
                      method: 'composed.animate.child',
                      roleBadge: 'Controller + Static Child',
                      badgeColor: Colors.tealAccent,
                      statusWidget: composed.animate(
                        store.controller,
                        (context, via, ctrl) => Text(
                          ctrl.isAnimating ? 'Spinning (6s)' : 'Halted (0.00)',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color:
                                ctrl.isAnimating ? Colors.green : Colors.amber,
                          ),
                        ),
                      ),
                      child: composed.animate.child(
                        store.controller,
                        (context, via, ctrl, child) => RotationTransition(
                          turns: ctrl.view,
                          child: child,
                        ),
                        child: _buildGeometryBox(Colors.tealAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Action Triggers (Role-based Boxed Controls)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.dividerColor.withAlpha(40),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Controls:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => store.toggleMount(),
                  child: composed(
                    (context, via) => Text(
                      via(store.isMounted) ? 'Unmount All' : 'Remount All',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => store.toggleDirection(),
                  child: const Text('Single-Shot Toggle (.toggle())'),
                ),
                OutlinedButton(
                  onPressed: () => store.resumeRepeat(),
                  child: const Text('Resume Repeat (.repeat())'),
                ),
                OutlinedButton(
                  onPressed: () => store.togglePingPong(),
                  child: const Text('Ping-Pong (.repeat(reverse: true))'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Architecture Note Callout
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
                const Icon(Icons.info_outline_rounded,
                    color: Colors.blueAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '💡 Architecture & Synchronization Note:\n'
                    '• Pattern A & C share the Store\'s DurableAnimationController. In Flutter, .toggle() executes a single-shot forward/reverse run which cleanly halts upon reaching 0.0 or 1.0.\n'
                    '• Pattern B uses composed.drive, which is an autonomous frame ticker with zero controller overhead. It runs continuously and is unaffected by controller mutations.',
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

  Widget _buildPatternColumnBox({
    required BuildContext context,
    required String title,
    required String method,
    required String roleBadge,
    required Color badgeColor,
    required Widget child,
    Widget? statusWidget,
  }) {
    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(method,
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 14),
            child,
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withAlpha(90)),
              ),
              child: Text(
                roleBadge,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            if (statusWidget != null) ...[
              const SizedBox(height: 6),
              statusWidget,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeometryBox(Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
        color: color.withAlpha(35),
      ),
    );
  }
}
