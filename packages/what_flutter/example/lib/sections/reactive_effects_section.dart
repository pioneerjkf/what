// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 07: Reactive Effects & Side-Effect Pipeline Demo
base class ReactiveEffectsSectionDemo extends WhatWidget {
  const ReactiveEffectsSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.reactiveEffects;
    final isActive = via(store.isEffectActive);

    // [Lifecycle] Declarative Scoped EffectGroup: Automatically bound to Section 07's lifecycle!
    if (isActive) {
      via.tether(store.effects);
    }

    final count = via(store.counter);
    final isTracking = via(store.isTrackingDetails);
    final payload = via(store.detailPayload);
    final untracked = via(store.untrackedNode);
    final threshold = via(store.alertThreshold);
    final effectRuns = via(store.effectRunCount);
    final logs = via(store.eventLogs);
    final lastAlert = via(store.lastThresholdAlert);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // ---------------------------------------------------------------------
        // 0. Zero UI Rebuild Proof Header
        // ---------------------------------------------------------------------
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.indigo.shade900.withAlpha(50)
                : Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.indigo.shade700.withAlpha(100)
                  : Colors.indigo.shade200,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zero-Rebuild Invariant Guaranteed',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Effects execute pure side-effects (logging, analytics, haptics) in isolated reactive terminals without propagating dirty pulses downstream.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Live Effect Execution Counter
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'EFFECT RUNS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '$effectRuns',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ---------------------------------------------------------------------
        // 1. Dynamic Discovery (Effect.via)
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: 'Dynamic Discovery & Untracked Boundary',
          badge: 'Effect.via',
          description:
              'Tracks only dependencies requested via via(). Reading .data outside via() creates an untracked boundary that never triggers effect execution.',
          child: Column(
            children: [
              SandboxContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Counter State: $count',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigoAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isTracking)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: theme.colorScheme.primary.withAlpha(100)),
                        ),
                        child: Text(
                          'Dynamic Branch Active: "$payload"',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      const Text(
                        '(Dynamic branch disabled — payload What is detached from Effect graph)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: store.incrementCounter,
                    child: const Text('Increment (+1)'),
                  ),
                  OutlinedButton(
                    onPressed: store.resetCounter,
                    child: const Text('Reset (0)'),
                  ),
                  FilterChip(
                    label: const Text('Dynamic Branch Tracking'),
                    selected: isTracking,
                    onSelected: store.toggleDetailTracking,
                  ),
                  if (isTracking)
                    OutlinedButton(
                      onPressed: store.cycleDetailPayload,
                      child: const Text('Cycle Payload'),
                    ),
                  Tooltip(
                    message:
                        'Direct .data read inside Effect.via is untracked — clicking this will NOT fire Effect.via!',
                    child: OutlinedButton(
                      onPressed: store.mutateUntracked,
                      child: Text('Mutate Untracked ($untracked)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // 2. Microtask Coalescing & Event Loop Batching
        // ---------------------------------------------------------------------
        _CoalescingCard(),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // 3. Explicit Tuple Effect ((a, b).effect)
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: 'Explicit Tuple Effect & Alert Trigger',
          badge: '(a, b).effect()',
          description:
              'Explicit effects skip initial evaluation (0 runs upon activation) and fire strictly when any of their specified tuple targets mutate.',
          child: Column(
            children: [
              SandboxContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Alert Threshold: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$threshold',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: threshold.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$threshold',
                      onChanged: (val) => store.setAlertThreshold(val.toInt()),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: count >= threshold
                            ? Colors.amber.withAlpha(40)
                            : Colors.grey.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: count >= threshold
                              ? Colors.amber
                              : Colors.grey.withAlpha(70),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              count >= threshold
                                  ? 'ALERT: $lastAlert'
                                  : 'Status: Normal (Counter $count < $threshold)',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: count >= threshold
                                    ? Colors.amber.shade700
                                    : Colors.grey,
                              ),
                            ),
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
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // 3. Effect Lifecycle & Live Event Terminal
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: 'Effect Lifecycle Control & Live Event Terminal',
          badge: 'Lifecycle',
          description:
              'Effects support full activate(), deactivate(), and dispose() lifecycle semantics to guarantee leak-free operation.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Responsive Lifecycle switch & Clear button
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: isActive,
                        onChanged: store.toggleLifecycle,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isActive ? 'Effects Active' : 'Effects Deactivated',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: store.clearLogs,
                    child: const Text('Clear Logs'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Monospaced Event Terminal
              Container(
                height: 170,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF08090C)
                      : const Color(0xFF1E222B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF262936)
                        : const Color(0xFF333846),
                  ),
                ),
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No events captured yet. Mutate state above to trigger effects.',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, idx) {
                          final line = logs[idx];
                          final isTuple = line.contains('TupleEffect');
                          final isSingle = line.contains('SingleEffect');
                          final isVia = line.contains('Effect.via');
                          final isLifecycle = line.contains('Lifecycle');

                          Color textColor =
                              const Color(0xFF38BDF8); // Sky blue 400
                          if (isTuple) {
                            textColor = const Color(0xFFFDE047); // Yellow 300
                          } else if (isSingle) {
                            textColor = const Color(0xFF4ADE80); // Emerald 400
                          } else if (isVia) {
                            textColor = const Color(0xFFC084FC); // Purple 400
                          } else if (isLifecycle) {
                            textColor = const Color(0xFFFB7185); // Rose 400
                          }

                          final match =
                              RegExp(r'^(\[\d{2}:\d{2}:\d{2}\.\d\])\s*(.*)$')
                                  .firstMatch(line);

                          if (match != null) {
                            final time = match.group(1)!;
                            final body = match.group(2)!;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2.5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      body,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 2. Microtask Coalescing & Event Loop Batching Card (WhatWidget)
// =============================================================================

base class _CoalescingCard extends WhatWidget {
  const _CoalescingCard();

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.reactiveEffects;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShowcaseCard(
      title: 'Microtask Coalescing & Event Loop Batching',
      badge: '1-Tick Coalescing',
      description:
          'Demonstrates What Effect microtask batching: Multiple synchronous state mutations in a single event loop tick coalesce into exactly 1 microtask run, completely eliminating redundant side-effect executions.',
      child: Column(
        children: [
          SandboxContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                composed((context, via) {
                  final count = via(store.counter);
                  return Text(
                    'Coalesced Counter: $count',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: Colors.indigoAccent,
                    ),
                  );
                }),
                const SizedBox(height: 12),
                // Coalescing Telemetry Metrics
                composed((context, via) {
                  final burst = via(store.lastBurstCount);
                  final savings = via(store.lastSavingsCount);
                  final hasBurst = burst > 1;
                  final savingsPct = hasBurst
                      ? ((savings / burst) * 100).toStringAsFixed(0)
                      : '0';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.indigo.shade900.withAlpha(30)
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.indigo.shade800.withAlpha(80)
                            : Colors.indigo.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SYNCHRONOUS MUTATIONS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasBurst ? '$burst in 1 Tick' : '1 Single Tick',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: theme.dividerColor.withAlpha(75),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MICROTASK RUNS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Exactly 1 (Coalesced)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: theme.dividerColor.withAlpha(75),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SAVED RUNS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasBurst
                                    ? '$savings ($savingsPct%)'
                                    : '0 (Baseline)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: hasBurst ? Colors.amber : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Action Buttons (Role-based Boxed Controls)
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Burst Mutations:',
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
                          onPressed: () => store.burstMultiMutation(10),
                          child: const Text('Burst 10x (1 Frame)'),
                        ),
                        FilledButton(
                          onPressed: () => store.burstMultiMutation(50),
                          child: const Text('Burst 50x (1 Frame)'),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                  height: 20,
                  color: Theme.of(context).dividerColor.withAlpha(35),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Incremental:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          onPressed: store.incrementCounter,
                          child: const Text('+1 Single Mutation'),
                        ),
                        OutlinedButton(
                          onPressed: store.resetCounter,
                          child: const Text('Reset'),
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
}
