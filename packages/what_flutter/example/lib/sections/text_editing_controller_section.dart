// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 05: Standard Form Input & Listenable Bridge (`toWhatBy`) Showcase Demo.
base class TextEditingControllerSection extends WhatWidget {
  const TextEditingControllerSection({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.textEditingController;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textController = store.textController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------------------------------------------------------------------
        // Interactive Standard Form Input Sandbox Card
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: 'Native Flutter TextEditingController + toWhatBy Bridge',
          badge: 'Listenable Bridge',
          description:
              'Type in the native TextField below or trigger programmatic updates. Flutter manages the UI and IME input buffer natively, while toWhatBy((c) => c.text) bridges the string updates into What reactive graph with zero overhead.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Real-time Text Input Field
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: 'Native TextField with toWhatBy',
                  hintText: 'Type freely or test cursor placement...',
                  suffixIcon: IconButton(
                    tooltip: 'Clear Input',
                    icon: const Text('×',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    onPressed: store.clear,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E222D)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live Reactive Metrics Bar (Surgical micro-rebuild)
              composed((context, via) {
                final charCount = via(store.charCount);
                final wordCount = via(store.wordCount);
                final mutations = via(store.mutationCount);

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip(
                      context,
                      label: 'Chars',
                      value: '$charCount',
                      color: Colors.blue,
                    ),
                    _buildMetricChip(
                      context,
                      label: 'Words',
                      value: '$wordCount',
                      color: Colors.teal,
                    ),
                    _buildMetricChip(
                      context,
                      label: 'External Mutates',
                      value: '$mutations',
                      color: Colors.purple,
                    ),
                    _buildMetricChip(
                      context,
                      label: 'Lifecycle',
                      value: 'Auto-Managed',
                      color: Colors.green,
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),

              // Mirrored Reactive State Box (Surgical micro-rebuild)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161922)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E3346)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reactive What<String> Stream via .toWhatBy((c) => c.text):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    composed((context, via) {
                      final currentText = via(store.textWhat);
                      return SelectableText(
                        currentText.isEmpty
                            ? '(Empty String - Empty State)'
                            : currentText,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: currentText.isEmpty
                              ? theme.colorScheme.outline
                              : (isDark
                                  ? Colors.amber[200]
                                  : Colors.amber[900]),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // External State Transformation Card
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: 'Programmatic Text Transformations',
          badge: 'Native Controller',
          description:
              'Modify the standard TextEditingController imperatively. The changes immediately propagate downstream to What computed graphs via toWhatBy.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('UPPERCASE'),
                    onPressed: store.toUpperCase,
                  ),
                  ActionChip(
                    label: const Text('lowercase'),
                    onPressed: store.toLowerCase,
                  ),
                  ActionChip(
                    label: const Text('Add "[URGENT]" Tag'),
                    onPressed: () => store.prependTag('[URGENT]'),
                  ),
                  ActionChip(
                    label: const Text('Append "[V2]"'),
                    onPressed: () => store.appendSuffix('[V2]'),
                  ),
                  ActionChip(
                    label: const Text('Korean IME Sample'),
                    onPressed: store.setKoreanSample,
                  ),
                  ActionChip(
                    label: const Text('Reset Greeting'),
                    onPressed: store.resetDefault,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // Architectural Comparison Breakdown
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: 'Architectural Comparison: Pure toWhatBy vs Heavy Wrappers',
          badge: 'Architecture',
          description:
              'Instead of subclassing TextEditingController or coupling it directly with a WhatController, standard Flutter controllers bridge cleanly into What via toWhatBy.',
          child: Column(
            children: [
              _buildComparisonRow(
                context,
                title: 'Data Flow & Single Source of Truth',
                badText:
                    'Complex 2-way controllers tightly couple UI controllers with reactive states, causing ping-pong synchronization hazards.',
                goodText:
                    'Unidirectional flow: Flutter TextEditingController owns the input buffer; What reacts via toWhatBy((c) => c.text).',
              ),
              const Divider(height: 24),
              _buildComparisonRow(
                context,
                title: 'Ecosystem Compatibility',
                badText:
                    'Custom controller subclasses cannot be used with third-party form packages or specialized text controllers.',
                goodText:
                    'Any standard TextEditingController subclass works out of the box with toWhat and toWhatBy.',
              ),
              const Divider(height: 24),
              _buildComparisonRow(
                context,
                title: 'CJK / Korean IME Composition',
                badText:
                    'External state synchronizers that reassign .text during keystrokes break ongoing IME syllable composing ranges.',
                goodText:
                    'Native Flutter input pipeline handles IME seamlessly without state interceptors destroying composing spans.',
              ),
              const Divider(height: 24),
              _buildComparisonRow(
                context,
                title: 'Lifecycle & Memory Leak',
                badText:
                    'Requires converting widgets to StatefulWidget to manage controller allocation and dispose() lifecycles.',
                goodText:
                    'Managed by What.managed<TextEditingController>() for clean auto-disposal upon unmount and Demand-Driven Dormancy.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withAlpha(isDark ? 80 : 60),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color[isDark ? 200 : 800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context, {
    required String title,
    required String badText,
    required String goodText,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bad side
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(isDark ? 25 : 15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withAlpha(isDark ? 70 : 50),
                  ),
                ),
                child: Text(
                  badText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.red[200] : Colors.red[900],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Good side
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(isDark ? 25 : 15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withAlpha(isDark ? 70 : 50),
                  ),
                ),
                child: Text(
                  goodText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.green[200] : Colors.green[900],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
