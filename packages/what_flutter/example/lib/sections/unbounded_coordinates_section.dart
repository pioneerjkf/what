// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 16: Extreme Coordinate Space & Infinite Dimensions (-1000 ~ +5000)
base class UnboundedCoordinatesSectionDemo extends WhatWidget {
  const UnboundedCoordinatesSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.unboundedCoordinates;
    final isMounted = via(store.isMounted);
    final target = via(store.currentTarget);

    return ShowcaseCard(
      title: 'Extreme Coordinate Space & Infinite Dimensions (-∞ ~ +∞)',
      badge: 'Target: ${target.toStringAsFixed(0)}',
      description:
          'Drive Unbounded controllers across extreme coordinate ranges (-1000 ~ +5000). Compare Frozen (freezes on hide) vs CatchUp (tracks real-time progress).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coordinate Monitors Arena
          SandboxContainer(
            minHeight: 180,
            child: isMounted
                ? Row(
                    children: [
                      // Left: Frozen Unbounded
                      Expanded(
                        child: _buildMonitor(
                          controller: store.unboundedFrozenCtrl,
                          title: 'Frozen (-∞ ~ +∞)',
                          subtitle: 'Freezes at coordinate on hide',
                          color: Colors.purpleAccent,
                          context: context,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 140,
                        color: Theme.of(context).dividerColor.withAlpha(50),
                      ),
                      // Right: CatchUp Unbounded
                      Expanded(
                        child: _buildMonitor(
                          controller: store.unboundedCatchUpCtrl,
                          title: 'CatchUp (-∞ ~ +∞)',
                          subtitle: 'Advances with wall-clock time',
                          color: Colors.cyanAccent,
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
                          'Unbounded Engines are Dormant (Unmounted)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigoAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coordinates remain anchored or continue simulated forward movement.',
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

          // Interactive Control Buttons: Boxed by Functional Role
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
                // Role 1: Extreme Warps
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Extreme Warps:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        FilledButton.icon(
                          icon:
                              const Icon(Icons.fast_forward_rounded, size: 16),
                          onPressed: () => store.runUnboundedJump(5000.0),
                          label: const Text('Warp to +5000.0 (Beyond Bounds)'),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.fast_rewind_rounded, size: 16),
                          onPressed: () => store.runUnboundedJump(-1000.0),
                          label:
                              const Text('Warp to -1000.0 (Negative Bounds)'),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                    height: 20,
                    color: Theme.of(context).dividerColor.withAlpha(35)),

                // Role 2: Lifecycle & Reset
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Lifecycle & Reset:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
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
                              style: const TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          onPressed: () => store.resetToZero(),
                          label: const Text('Reset to 0.0',
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

  Widget _buildMonitor({
    required DurableAnimationController controller,
    required String title,
    required String subtitle,
    required Color color,
    required BuildContext context,
  }) {
    return composed.animate.child(
      controller,
      (context, via, ctrl, child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child, // Static Badge (0 rebuilds)
            const SizedBox(height: 14),

            // [Pinpoint Rebuild] Only the big numeric counter text rebuilds on frame ticks
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ctrl.value.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Static Subtitle (0 rebuilds)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
