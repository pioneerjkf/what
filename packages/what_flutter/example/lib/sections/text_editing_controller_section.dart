// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 05: Zero-Jump Form Binding & WhatTextEditingController Showcase Demo.
base class TextEditingControllerSection extends WhatWidget {
  const TextEditingControllerSection({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.textEditingController;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textController = via(store.textControllerWhat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------------------------------------------------------------------
        // Interactive Two-Way Form Sandbox Card
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: 'Interactive Two-Way Reactive Form Sandbox',
          badge: '2-Way Binding',
          description:
              'Type in the TextField below or trigger external transformations. Notice that the cursor NEVER jumps to the end, Korean IME composition remains intact, and 0 re-entrant ping-pong loops occur.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Real-time Text Input Field
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: 'Reactive Two-Way Input',
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
                      'Underlying WhatController<String> State (SSOT):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    composed((context, via) {
                      final currentText = via(store.query.what);
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
          title: 'Zero-Jump Programmatic State Transformations',
          badge: 'Smart Clamping',
          description:
              'Simulate backend API updates, formatting, or programmatic overrides. In naive Flutter code, these actions blow away cursor offsets. WhatTextEditingController clamps the cursor safely at the same relative position.',
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
                    label: const Text('Korean IME Test'),
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
          title: 'Architectural Comparison: Why Native 2-Way Binding Fails',
          badge: 'Core Invariants',
          description:
              'Flutter TextEditingController was designed for imperative mutations. When connected to reactive state graphs, four fatal bugs arise.',
          child: Column(
            children: [
              _buildComparisonRow(
                context,
                title: 'Cursor Jumping (Offset -1)',
                badText:
                    'Naive `controller.text = val` resets selection to -1, forcefully warping the cursor to the end of the text on every keystroke.',
                goodText:
                    'WhatTextEditingController guards UI input from self-echo and clamps prior selection bounds safely on external updates.',
              ),
              const Divider(height: 24),
              _buildComparisonRow(
                context,
                title: 'CJK / Korean IME Composition',
                badText:
                    'External string re-assignment destroys ongoing composing sessions (`composing`), splitting syllables into individual jamo (e.g. ㄱ+ㅏ).',
                goodText:
                    '0-mutation short-circuit leaves `TextEditingValue.composing` 100% untouched while user types.',
              ),
              const Divider(height: 24),
              _buildComparisonRow(
                context,
                title: 'Ping-Pong Infinite Loop',
                badText:
                    'UI input notifies controller, controller mutates state, state notifies controller listener, looping infinitely until crash.',
                goodText:
                    'Mutual exclusion flags (`_isUpdatingFromUI`, `_isUpdatingFromWhat`) enforce strict unidirectional single-turn propagation.',
              ),
              const Divider(height: 24),
              _buildComparisonRow(
                context,
                title: 'Lifecycle & Memory Leak',
                badText:
                    'Requires converting every widget to StatefulWidget and writing boilerplate `initState()` and `dispose()` for every field.',
                goodText:
                    '`bindTextController(this)` binds directly to WhatWidget/Element lifecycle, disposing automatically upon unmount.',
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
