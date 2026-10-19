// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 02: composed() Declarative Inline Functors & Static Subtree Caching
base class ComposedFunctorsSectionDemo extends WhatWidget {
  ComposedFunctorsSectionDemo({super.key});

  final _animCtrl = DurableAnimationController(
    duration: const Duration(seconds: 1),
  );

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.composedFunctors;
    final cascadeMode = via(store.cascadeMode);

    return Column(
      children: [
        ShowcaseCard(
          title: '1. Orthogonal Functor Cascades Switcher',
          badge: 'composed Family',
          description:
              'Test the 4 canonical entrypoints of composed. Each entrypoint receives BuildContext as the 1st parameter with full reactive isolation.',
          child: Column(
            children: [
              // Pathway selector buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('composed'),
                      tooltip: 'composed((context, via) => ...)',
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('.vsync'),
                      tooltip: 'composed.vsync((context, via, vsync) => ...)',
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('.animate'),
                      tooltip:
                          'composed.animate(ctrl, (context, via, c) => ...)',
                    ),
                    ButtonSegment(
                      value: 3,
                      label: Text('.drive'),
                      tooltip:
                          'composed.drive(evaluator, (context, via, val) => ...)',
                    ),
                  ],
                  selected: {cascadeMode.clamp(0, 3)},
                  onSelectionChanged: (selection) =>
                      store.selectCascadeMode(selection.first),
                ),
              ),
              const SizedBox(height: 16),

              // Interactive Sandbox executing selected cascade pathway
              SandboxContainer(
                minHeight: 120,
                child: _buildCascadePreview(
                    context, store, cascadeMode.clamp(0, 3)),
              ),
              const SizedBox(height: 16),

              // Controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: store.addScore,
                    child: const Text('Add 50 Score'),
                  ),
                  FilledButton.tonal(
                    onPressed: store.levelUp,
                    child: const Text('Level Up'),
                  ),
                  OutlinedButton(
                    onPressed: store.reset,
                    child: const Text('Reset All'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Showcase 2: Static Subtree Zero-Rebuild Proof
        ShowcaseCard(
          title: '2. Static Subtree Caching Proof (composed.child)',
          badge: '0-Rebuild Cache',
          description:
              'The static shield icon is passed via composed.child. Even when score and level rapidly change, the static child is rebuilt EXACTLY ONCE.',
          child: SandboxContainer(
            minHeight: 100,
            child: composed.child(
              (context, via, child) {
                final score = via(store.score);
                final level = via(store.level);
                final theme = Theme.of(context);

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(60),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      child, // [Static Subtree] Rebuilt 0 times during score ticks!
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Player Status: Level $level',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Score: $score pts (Micro-rebuilding text only)',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              child: _RebuildCounterIcon(
                label: 'Static Subtree',
                color: Colors.blueAccent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Showcase 3: Continuous Frame Ticker Driving without Controller
        ShowcaseCard(
          title: '3. Continuous Frame Ticker Driving (composed.drive)',
          badge: 'Zero-Controller Ticker',
          description:
              'composed.drive connects continuous physics or oscillation functions directly to the frame scheduler without declaring an AnimationController or StatefulWidget.',
          child: SandboxContainer(
            minHeight: 90,
            child: composed.drive<double>(
              (elapsed) =>
                  (math.sin(elapsed.inMilliseconds / 400.0) + 1.0) / 2.0,
              (context, via, double value) {
                final theme = Theme.of(context);
                return Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary
                              .withAlpha((80 + 175 * value).toInt()),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withAlpha((100 * value).toInt()),
                              blurRadius: 16 * value + 4,
                              spreadRadius: 4 * value,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 12 + 10 * value,
                            height: 12 + 10 * value,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Realtime Sin-Wave: ${value.toStringAsFixed(3)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Continuous 60/120fps via composed.drive',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCascadePreview(
      BuildContext context, ComposedFunctorsStore store, int mode) {
    switch (mode) {
      case 0:
        // 1. composed((context, via) => ...)
        return composed((context, via) {
          final score = via(store.score);
          return _PreviewRow(
            color: Colors.amber,
            label: 'composed((context, via) => ...)',
            value: '$score pts',
          );
        });

      case 1:
        // 2. composed.vsync((context, via, vsync) => ...)
        return composed.vsync((context, via, vsync) {
          final score = via(store.score);
          final theme = Theme.of(context);
          return _PreviewRow(
            color: theme.colorScheme.primary,
            label: 'composed.vsync((context, via, vsync) => ...)',
            value: '$score pts (vsync active)',
          );
        });

      case 2:
        // 3. composed.animate
        return composed.animate(
          _animCtrl,
          (context, via, c) {
            final score = via(store.score);
            return _PreviewRow(
              color: Colors.purpleAccent,
              label: 'composed.animate (progress: ${(c.value * 100).toInt()}%)',
              value: '$score pts',
            );
          },
          onActivate: (c) => c.repeat(reverse: true),
        );

      case 3:
      default:
        // 4. composed.drive((elapsed) => ..., (context, via, val) => ...)
        return composed.drive<double>(
          (elapsed) => (math.sin(elapsed.inMilliseconds / 400.0) + 1.0) / 2.0,
          (context, via, double value) {
            final score = via(store.score);
            return _PreviewRow(
              color: Colors.orangeAccent,
              label: 'composed.drive (wave: ${value.toStringAsFixed(2)})',
              value: '$score pts',
            );
          },
        );
    }
  }
}

base class _PreviewRow extends WhatWidget {
  const _PreviewRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WhatVia via) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// A zero-boilerplate rebuild counter widget powered by WhatWidget.
base class _RebuildCounterIcon extends WhatWidget {
  _RebuildCounterIcon({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  final List<int> _buildCount = [0];

  @override
  Widget build(BuildContext context, WhatVia via) {
    _buildCount[0]++;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Build #${_buildCount[0]}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
