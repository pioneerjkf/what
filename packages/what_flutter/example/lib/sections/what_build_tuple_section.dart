// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 03: Direct Value Reactive Functors (what.build)
base class WhatBuildTupleSectionDemo extends WhatWidget {
  const WhatBuildTupleSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.whatBuildTuple;
    final cascadeMode = via(store.cascadeMode);

    return Column(
      children: [
        ShowcaseCard(
          title: '1. Zero-Cost Direct Value Functor (what.build)',
          badge: 'what.build Family',
          description:
              'what.build uses Dart extension types (extension type const) for zero runtime allocation. Direct payloads are received without manual subscription boilerplate.',
          child: Column(
            children: [
              // Pathway selector buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('what.build'),
                      tooltip: 'what.build((context, data) => ...)',
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('.child'),
                      tooltip:
                          'what.build.child((ctx, data, child) => ..., child: ...)',
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('.children'),
                      tooltip:
                          'what.build.children((ctx, data, children) => ..., children: [...])',
                    ),
                  ],
                  selected: {cascadeMode > 2 ? 0 : cascadeMode},
                  onSelectionChanged: (selection) =>
                      store.selectCascadeMode(selection.first),
                ),
              ),
              const SizedBox(height: 16),

              // Interactive Sandbox executing selected cascade pathway
              SandboxContainer(
                minHeight: 120,
                child: _buildWhatCascadePreview(context, store, cascadeMode),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Showcase 2: Multi-Node Composition via composed
        ShowcaseCard(
          title:
              '2. Multi-Node Dynamic Composition (composed(context, (context, via) => ...))',
          badge: 'Auto-Tracking',
          description:
              'Seamlessly composes multiple What dependencies with zero boilerplate and dynamic auto-tracking.',
          child: Column(
            children: [
              SandboxContainer(
                child: composed(
                  (context, via) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Player: ${via(store.user)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Chip(
                            label: Text('Rank #${via(store.rank)}'),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('${via(store.score)} XP'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Controls (Role-based Boxed Controls)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            'Player State Actions:',
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
                                onPressed: store.nextPlayer,
                                child: const Text('Next Player'),
                              ),
                              FilledButton(
                                onPressed: store.addXp,
                                child: const Text('+250 XP'),
                              ),
                              OutlinedButton(
                                onPressed: store.improveRank,
                                child: const Text('Improve Rank'),
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
        ),
      ],
    );
  }

  Widget _buildWhatCascadePreview(
      BuildContext context, WhatBuildTupleStore store, int mode) {
    switch (mode) {
      case 0:
        // 1. what.build((context, data) => ...)
        return store.score.build(
          (context, score) {
            final theme = Theme.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Direct Score: $score pts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'what.build((context, data) => ...)',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontFamily: 'monospace'),
                ),
              ],
            );
          },
        );

      case 1:
        // 2. what.build.child((context, data, child) => ..., child: ...)
        return store.score.build.child(
          (context, score, child) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              child, // Static child
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Score: $score XP',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'what.build.child(..., child: ...)',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11.5,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(40),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber),
            ),
            child: const Text('Cached',
                style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        );

      case 2:
      default:
        // 3. what.build.children((context, data, children) => ..., children: [...])
        return store.score.build.children(
          (context, score, children) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...children,
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total XP: $score',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'what.build.children(..., children: [...])',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11.5,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('[Boost]',
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('[Shield]',
                  style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        );
    }
  }
}
