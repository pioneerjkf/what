// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 15: Dormant Command Thrashing (Motion Staging & Zero TickerCanceled)
base class DormantThrashingSectionDemo extends WhatWidget {
  const DormantThrashingSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.dormantThrashing;
    final isMounted = via(store.isMounted);
    final lastAction = via(store.lastStagedAction);
    final log = via(store.stagedActionLog);

    return ShowcaseCard(
      title: 'Dormant Command Staging & Thrashing Simulator',
      badge: 'Cases 2-1~2-4, 3-1~3-8, 6-3',
      description:
          'Unmount the widget, smash any driving commands (.forward, .reverse, .toggle, .animateTo, .fling), and observe the live staging inspector. Remount to watch it resume cleanly with 0 TickerCanceled exceptions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMounted
                  ? Colors.green.withAlpha(30)
                  : Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMounted
                    ? Colors.green.withAlpha(100)
                    : Colors.amber.withAlpha(100),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMounted ? Colors.green : Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMounted
                            ? 'LIFECYCLE: ACTIVE (Ticking at 60/120fps)'
                            : 'LIFECYCLE: DORMANT (Unmounted from Tree)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMounted ? Colors.green : Colors.amber,
                            fontSize: 13),
                      ),
                      Text(
                        'Last Staged Action: $lastAction',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Interactive Layout (Responsive LayoutBuilder)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final visualBox = SandboxContainer(
                minHeight: 220,
                child: isMounted
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. Frozen Shuttle
                            _buildLinearShuttle(
                              controller: store.frozenCtrl,
                              title: 'Frozen (Freeze & Staged Replay)',
                              subtitle:
                                  'Freezes on unmount, resumes from exact position',
                              color: Colors.amber,
                              context: context,
                            ),
                            const Divider(height: 16),
                            // 2. CatchUp Shuttle
                            _buildLinearShuttle(
                              controller: store.catchUpCtrl,
                              title: 'CatchUp (Time-Compensated)',
                              subtitle:
                                  'Tracks real-time wall clock elapsed during dormancy',
                              color: Colors.cyanAccent,
                              context: context,
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            const Text(
                              'Visual Renderer Suspended (Both Engines Dormant)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigoAccent),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Smash commands below! Frozen freezes; CatchUp advances with wall clock.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.withAlpha(180)),
                            ),
                          ],
                        ),
                      ),
              );

              final logBox = Container(
                height: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withAlpha(50),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Staged Action Inspector',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Divider(height: 14),
                    Expanded(
                      child: log.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.queue_play_next_rounded,
                                    size: 26,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withAlpha(120),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No actions queued yet.\nClick buttons below to stage motion!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: log.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${index == 0 ? "▶ " : "  "}${log[index]}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: index == 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: index == 0
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: visualBox),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: logBox),
                  ],
                );
              } else {
                return Column(
                  children: [
                    visualBox,
                    const SizedBox(height: 16),
                    logBox,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Command Buttons: Boxed by Functional Role
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
                // Role 1: Lifecycle & Safety Controls
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Lifecycle & Safety:',
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
                            backgroundColor: isMounted
                                ? Colors.amber.withAlpha(50)
                                : Colors.green.withAlpha(50),
                          ),
                          icon: Icon(
                            isMounted
                                ? Icons.visibility_off_rounded
                                : Icons.play_arrow_rounded,
                            size: 16,
                            color: isMounted ? Colors.amber : Colors.green,
                          ),
                          onPressed: () => store.toggleMount(),
                          label: Text(
                            isMounted ? 'Unmount (Hide)' : 'Remount & Play',
                            style: TextStyle(
                              color: isMounted ? Colors.amber : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            side: BorderSide(color: Colors.red.withAlpha(100)),
                          ),
                          icon: const Icon(Icons.stop_rounded, size: 15),
                          onPressed: () => store.stop(),
                          label: const Text('stop()',
                              style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            side: BorderSide(color: Colors.red.withAlpha(100)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          onPressed: () => store.reset(),
                          label: const Text('reset()',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                    height: 20,
                    color: Theme.of(context).dividerColor.withAlpha(35)),

                // Role 2: Directional Drivers
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Directional Drivers:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        FilledButton.tonal(
                          onPressed: () => store.forward(),
                          child: const Text('.forward()',
                              style: TextStyle(fontSize: 12)),
                        ),
                        FilledButton.tonal(
                          onPressed: () => store.reverse(),
                          child: const Text('.reverse()',
                              style: TextStyle(fontSize: 12)),
                        ),
                        FilledButton.tonal(
                          onPressed: () => store.toggle(),
                          child: const Text('.toggle() (5x Churn)',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                    height: 20,
                    color: Theme.of(context).dividerColor.withAlpha(35)),

                // Role 3: Interpolations & Coordinate Jumps
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Interpolations & Jumps:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          onPressed: () => store.animateTo(0.8),
                          child: const Text('.animateTo(0.8, bounce)',
                              style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton(
                          onPressed: () => store.animateTo(0.2),
                          child: const Text('.animateTo(0.2, bounce)',
                              style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton(
                          onPressed: () => store.fling(2.5),
                          child: const Text('.fling(velocity: 2.5)',
                              style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton(
                          onPressed: () => store.repeat(true),
                          child: const Text('.repeat(reverse: true)',
                              style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton(
                          onPressed: () => store.setValue(0.5),
                          child: const Text('value = 0.5 (Direct)',
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

  Widget _buildLinearShuttle({
    required DurableAnimationController controller,
    required String title,
    required String subtitle,
    required Color color,
    required BuildContext context,
  }) {
    return composed.animate.child(
      controller,
      (context, via, ctrl, child) {
        final val = ctrl.value.clamp(0.0, 1.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
                Text(
                  'Value: ${ctrl.value.toStringAsFixed(3)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 6,
                color: color,
                backgroundColor: color.withAlpha(30),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment((val * 2) - 1.0, 0.0),
              child: child,
            ),
          ],
        );
      },
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(140),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
