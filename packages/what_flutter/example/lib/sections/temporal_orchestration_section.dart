// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 08: Temporal Orchestration & Scope Effects Demo
///
/// Demonstrates time-domain rate-limiting effects ([DebounceEffect], [ThrottleEffect]),
/// and execution limit bounds ([take: int?]) with the Reactivation Guard.
base class TemporalOrchestrationSectionDemo extends WhatWidget {
  const TemporalOrchestrationSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.temporalOrchestration;

    // Re-tether latest effects whenever effectsVersion changes
    final _ = via(store.effectsVersion);
    via.tether(store.debounceEffect);
    via.tether(store.throttleEffect);
    via.tether(store.takeEffect);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------------------------------------------------------------------
        // 0. Temporal Guarantees Header
        // ---------------------------------------------------------------------
        _HeaderBanner(theme: theme, isDark: isDark),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // 1. Debounce Lab (Keystroke Silence Window)
        // ---------------------------------------------------------------------
        _DebounceLabCard(store: store),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // 2. Throttle Lab (Rapid Click / Event Storm Suppression)
        // ---------------------------------------------------------------------
        _ThrottleLabCard(store: store),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // 3. Take Limit & Reactivation Guard Lab
        // ---------------------------------------------------------------------
        _TakeGuardLabCard(store: store),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // 4. Real-Time Telemetry & Observability Log Console
        // ---------------------------------------------------------------------
        _TelemetryLogCard(store: store),
      ],
    );
  }
}

// =============================================================================
// 0. Header Banner
// =============================================================================

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.theme, required this.isDark});

  final ThemeData theme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.teal.shade900.withAlpha(60) : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.teal.shade700.withAlpha(120)
              : Colors.teal.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Time-Domain Orchestration & Scope Lifecycle Guarantees',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Throttle & Debounce suppress high-frequency invalidations across time windows. '
            'The Reactivation Guard permanently locks out revived terminals upon take limits. '
            'Store effects bind declaratively to the widget scope via tether() with zero manual overhead.',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. Debounce Lab Card
// =============================================================================

base class _DebounceLabCard extends WhatWidget {
  const _DebounceLabCard({required this.store});

  final TemporalOrchestrationStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final rawKeystrokes = via(store.rawKeyStrokes);
    final debouncedCalls = via(store.debouncedCalls);
    final lastQuery = via(store.lastDispatchedQuery);
    final durationMs = via(store.debounceDurationMs);
    final leading = via(store.debounceLeading);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShowcaseCard(
      title: 'Debounce Lab: Burst Keystroke Stabilization',
      badge: 'DebounceEffect',
      description:
          'Delays execution until upstream mutations cease for a silence window ($durationMs ms). '
          'Ideal for search queries, autosave, and burst smoothing without redundant API requests.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SandboxContainer(
            minHeight: 160,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live Input Field
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type fast to test debounce...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1B1E28)
                          : const Color(0xFFFFFFFF),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: store.updateSearchQuery,
                  ),
                ),
                const SizedBox(height: 16),

                // Metrics Comparison Gauge
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetricBadge(
                      label: 'RAW KEYSTROKES',
                      value: '$rawKeystrokes',
                      color: Colors.amber,
                    ),
                    Text(
                      '→',
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _MetricBadge(
                      label: 'DEBOUNCED API CALLS',
                      value: '$debouncedCalls',
                      color: Colors.tealAccent,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blueGrey.shade900
                            : Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.blueGrey.shade700
                              : Colors.blueGrey.shade200,
                        ),
                      ),
                      child: Text(
                        'Last Dispatched: "$lastQuery"',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.blueGrey.shade100
                              : Colors.blueGrey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Control Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton(
                onPressed: store.simulateFastTyping,
                child: const Text('Simulate Rapid Typing (x6)'),
              ),
              OutlinedButton(
                onPressed: store.resetDebounce,
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              Text(
                'Window: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ChoiceChip(
                label: const Text('200ms'),
                selected: durationMs == 200,
                onSelected: (_) => store.setDebounceDelay(200),
              ),
              ChoiceChip(
                label: const Text('400ms'),
                selected: durationMs == 400,
                onSelected: (_) => store.setDebounceDelay(400),
              ),
              ChoiceChip(
                label: const Text('800ms'),
                selected: durationMs == 800,
                onSelected: (_) => store.setDebounceDelay(800),
              ),
              FilterChip(
                label: const Text('Leading Edge'),
                selected: leading,
                onSelected: store.toggleDebounceLeading,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. Throttle Lab Card
// =============================================================================

base class _ThrottleLabCard extends WhatWidget {
  const _ThrottleLabCard({required this.store});

  final TemporalOrchestrationStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final rawClicks = via(store.rawClickCount);
    final throttledRuns = via(store.throttledRunCount);
    final intervalMs = via(store.throttleDurationMs);
    final leading = via(store.throttleLeading);
    final trailing = via(store.throttleTrailing);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final suppressedClicks =
        rawClicks > throttledRuns ? rawClicks - throttledRuns : 0;

    return ShowcaseCard(
      title: 'Throttle Lab: High-Frequency Event Suppression',
      badge: 'ThrottleEffect',
      description:
          'Enforces a minimum interval ($intervalMs ms) between executions. '
          'Suppresses rapid-fire clicks, aggressive scroll events, and protects backend APIs.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SandboxContainer(
            minHeight: 160,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rapid-fire Action Button
                FilledButton.tonal(
                  onPressed: store.fireRapidClick,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  child: const Text('RAPID FIRE CLICK!'),
                ),
                const SizedBox(height: 16),

                // Metrics Comparison Gauge
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetricBadge(
                      label: 'RAW CLICKS',
                      value: '$rawClicks',
                      color: Colors.deepOrangeAccent,
                    ),
                    Text(
                      '→',
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _MetricBadge(
                      label: 'THROTTLED RUNS',
                      value: '$throttledRuns',
                      color: Colors.greenAccent,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.shade900.withAlpha(50)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.red.shade800
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        'Suppressed: $suppressedClicks clicks',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.redAccent : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Control Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => store.burstClicks(8),
                child: const Text('Fire Burst (x8)'),
              ),
              OutlinedButton(
                onPressed: store.resetThrottle,
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              Text(
                'Window: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ChoiceChip(
                label: const Text('300ms'),
                selected: intervalMs == 300,
                onSelected: (_) => store.setThrottleInterval(300),
              ),
              ChoiceChip(
                label: const Text('600ms'),
                selected: intervalMs == 600,
                onSelected: (_) => store.setThrottleInterval(600),
              ),
              ChoiceChip(
                label: const Text('1200ms'),
                selected: intervalMs == 1200,
                onSelected: (_) => store.setThrottleInterval(1200),
              ),
              FilterChip(
                label: const Text('Leading'),
                selected: leading,
                onSelected: store.toggleThrottleLeading,
              ),
              FilterChip(
                label: const Text('Trailing'),
                selected: trailing,
                onSelected: store.toggleThrottleTrailing,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. Take Limit & Reactivation Guard Lab Card
// =============================================================================

base class _TakeGuardLabCard extends WhatWidget {
  const _TakeGuardLabCard({required this.store});

  final TemporalOrchestrationStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final clicks = via(store.takeClickAttempts);
    final executed = via(store.takeExecutedCount);
    final isDormant = via(store.isTakeDormant);
    final blockedAttempts = via(store.guardBlockedAttempts);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShowcaseCard(
      title: 'Take Bound & Reactivation Guard: Limited Execution & Dormancy',
      badge: 'take: int?',
      description:
          'Effects with `take: N` automatically detach listeners (Early Teardown) upon reaching '
          'the execution limit. The Reactivation Guard guarantees permanent dormancy, blocking '
          'accidental revival by parent groups.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SandboxContainer(
            minHeight: 160,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ticket Punch Card Representation
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(TemporalOrchestrationStore.takeLimit,
                      (index) {
                    final isUsed = index < executed;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUsed
                            ? (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isUsed ? Colors.grey : theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ticket #${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUsed
                                  ? Colors.grey
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            isUsed ? 'REDEEMED' : 'READY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isUsed ? Colors.grey : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Status Badge
                if (isDormant)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.purple.shade900.withAlpha(70)
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? Colors.purple.shade700
                            : Colors.purple.shade200,
                      ),
                    ),
                    child: Text(
                      'Permanent Dormancy Enforced (Blocked Revivals: $blockedAttempts)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.purple.shade200
                            : Colors.purple.shade800,
                      ),
                    ),
                  )
                else
                  Text(
                    'Tickets Remaining: ${TemporalOrchestrationStore.takeLimit - executed}/'
                    '${TemporalOrchestrationStore.takeLimit} (Clicks: $clicks)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Control Bar (Role-based Boxed Controls)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        'Take Controls:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FilledButton(
                            onPressed: isDormant ? null : store.claimTakeTicket,
                            child: const Text('Redeem Ticket'),
                          ),
                          FilledButton.tonal(
                            onPressed: store.attemptForceReactivation,
                            child: const Text('Force Reactivate (Test Guard)'),
                          ),
                          OutlinedButton(
                            onPressed: store.resetTakeLab,
                            child: const Text('Reset Lab (New Effect)'),
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
}

// =============================================================================
// 4. Telemetry Log Card
// =============================================================================

base class _TelemetryLogCard extends WhatWidget {
  const _TelemetryLogCard({required this.store});

  final TemporalOrchestrationStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final logs = via(store.eventLogs);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShowcaseCard(
      title: 'Real-Time Telemetry & Observability Console',
      badge: 'Live Console',
      description:
          'Chronological log stream of time-domain rate-limiting dispatches '
          'and reactivation guard rejections.',
      actions: [
        TextButton(
          onPressed: store.clearLogs,
          child: const Text('Clear Console'),
        ),
      ],
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1117) : const Color(0xFF1E212B),
          borderRadius: BorderRadius.circular(10),
        ),
        child: logs.isEmpty
            ? Center(
                child: Text(
                  'No events recorded yet. Interact with any lab above!',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final match = RegExp(r'^(\[\d{2}:\d{2}:\d{2}\.\d\])\s*(.*)$')
                      .firstMatch(log);

                  Color logColor = const Color(0xFF67E8F9); // Crisp Cyan
                  if (log.contains('[Dormant]')) {
                    logColor = const Color(0xFFFB7185); // Rose
                  } else if (log.contains('[Guard Active]')) {
                    logColor = const Color(0xFFFDE047); // Amber
                  } else if (log.contains('[Take]')) {
                    logColor = const Color(0xFF38BDF8); // Sky blue
                  } else if (log.contains('[Debounce]')) {
                    logColor = const Color(0xFF34D399); // Emerald
                  } else if (log.contains('[Throttle]')) {
                    logColor = const Color(0xFFC084FC); // Purple
                  }

                  if (match != null) {
                    final time = match.group(1)!;
                    final body = match.group(2)!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
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
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: logColor,
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
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: logColor,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// =============================================================================
// Common Metric Badge Helper
// =============================================================================

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3144) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
