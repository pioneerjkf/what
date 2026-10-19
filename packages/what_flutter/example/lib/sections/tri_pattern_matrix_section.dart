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

    return ShowcaseCard(
      title: 'Tri-Pattern Animation & Wake Matrix',
      badge: '3 Canonical Pathways',
      description:
          'Demonstrates the 3 interchangeable ways to animate and couple an external Store controller with Flutter Vsync. All run perfectly synchronized with zero ticker leaks.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    // Pattern B: Value-Driven composed.drive
                    _buildPatternColumnBox(
                      context: context,
                      title: 'Pattern B',
                      method: 'composed.drive',
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
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor.withAlpha(40),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Matrix Controls:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => store.toggleMount(),
                            child: composed(
                              (context, via) => Text(
                                via(store.isMounted)
                                    ? 'Unmount All'
                                    : 'Remount All',
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => store.toggleDirection(),
                            child: const Text('Toggle Direction (.toggle())'),
                          ),
                        ],
                      ),
                    ],
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
    required Widget child,
  }) {
    return SizedBox(
      width: 140,
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
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('100% Synced',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
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
