// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/temporal_orchestration_section.dart';

/// Sub-store for Section 08: Temporal Orchestration & Scope Effects
///
/// Coordinates state, rate-limiting effects (Debounce/Throttle), and take execution
/// limit guards for the Section 08 showcase.
class TemporalOrchestrationStore {
  TemporalOrchestrationStore() {
    _initEffects();
  }

  // ---------------------------------------------------------------------------
  // 1. Debounce Lab State & Telemetry
  // ---------------------------------------------------------------------------

  /// The raw search query string entered by the user.
  final _searchQuery = WhatController<String>('');
  What<String> get searchQuery => _searchQuery.what;

  /// Total count of raw keystrokes received.
  final _rawKeyStrokes = WhatController<int>(0);
  What<int> get rawKeyStrokes => _rawKeyStrokes.what;

  /// Total count of debounced API dispatch calls actually executed.
  final _debouncedCalls = WhatController<int>(0);
  What<int> get debouncedCalls => _debouncedCalls.what;

  /// The last search query payload processed by the debounced API dispatch.
  final _lastDispatchedQuery = WhatController<String>('(none)');
  What<String> get lastDispatchedQuery => _lastDispatchedQuery.what;

  /// Configurable debounce silence duration in milliseconds.
  final _debounceDurationMs = WhatController<int>(400);
  What<int> get debounceDurationMs => _debounceDurationMs.what;

  /// Debounce leading edge execution flag.
  final _debounceLeading = WhatController<bool>(false);
  What<bool> get debounceLeading => _debounceLeading.what;

  /// The active debounce [DebounceEffect] instance.
  late DebounceEffect debounceEffect;

  // ---------------------------------------------------------------------------
  // 2. Throttle Lab State & Telemetry
  // ---------------------------------------------------------------------------

  /// Raw trigger counter bumped on every rapid button press.
  final _throttleTrigger = WhatController<int>(0);
  What<int> get throttleTrigger => _throttleTrigger.what;

  /// Total count of rapid user clicks.
  final _rawClickCount = WhatController<int>(0);
  What<int> get rawClickCount => _rawClickCount.what;

  /// Total count of throttled executions actually fired.
  final _throttledRunCount = WhatController<int>(0);
  What<int> get throttledRunCount => _throttledRunCount.what;

  /// Configurable throttle window interval in milliseconds.
  final _throttleDurationMs = WhatController<int>(600);
  What<int> get throttleDurationMs => _throttleDurationMs.what;

  /// Whether leading-edge execution is enabled on throttle.
  final _throttleLeading = WhatController<bool>(true);
  What<bool> get throttleLeading => _throttleLeading.what;

  /// Whether trailing-edge execution is enabled on throttle.
  final _throttleTrailing = WhatController<bool>(true);
  What<bool> get throttleTrailing => _throttleTrailing.what;

  /// The active throttle [ThrottleEffect] instance.
  late ThrottleEffect throttleEffect;

  // ---------------------------------------------------------------------------
  // 3. Take & Reactivation Guard Lab State & Telemetry
  // ---------------------------------------------------------------------------

  static const int takeLimit = 3;

  /// Mutation trigger for the take-limited effect.
  final _takeTrigger = WhatController<int>(0);
  What<int> get takeTrigger => _takeTrigger.what;

  /// Total user attempts/clicks to redeem.
  final _takeClickAttempts = WhatController<int>(0);
  What<int> get takeClickAttempts => _takeClickAttempts.what;

  /// Total times the take-limited effect has actually executed.
  final _takeExecutedCount = WhatController<int>(0);
  What<int> get takeExecutedCount => _takeExecutedCount.what;

  /// Whether the effect has reached its limit and entered permanent dormancy.
  final _isTakeDormant = WhatController<bool>(false);
  What<bool> get isTakeDormant => _isTakeDormant.what;

  /// Count of rejected attempts to re-activate the dormant effect.
  final _guardBlockedAttempts = WhatController<int>(0);
  What<int> get guardBlockedAttempts => _guardBlockedAttempts.what;

  /// The active [Effect] configured with `take: 3`.
  late Effect takeEffect;

  // ---------------------------------------------------------------------------
  // Telemetry & Live Event Log
  // ---------------------------------------------------------------------------

  /// Timestamped live event log history for real-time observability.
  final _eventLogs = WhatController<List<String>>([]);
  What<List<String>> get eventLogs => _eventLogs.what;

  /// Version counter bumped whenever effects are reconfigured, notifying UI to tether latest instances.
  final _effectsVersion = WhatController<int>(0);
  What<int> get effectsVersion => _effectsVersion.what;

  /// Composite [EffectGroup] bundling showcase effects for unified lifecycle management.
  late EffectGroup effects;

  void _initEffects() {
    // 1. Debounce Effect: Fires only after keystroke burst ceases for duration
    debounceEffect = searchQuery.effect.debounce(
      Duration(milliseconds: _debounceDurationMs.data),
      () {
        _debouncedCalls.set(_debouncedCalls.data + 1);
        _lastDispatchedQuery.set(
          _searchQuery.data.isEmpty ? '(cleared)' : _searchQuery.data,
        );
        _recordLog(
          '[Debounce] Dispatched API query "${_lastDispatchedQuery.data}" '
          '(silence: ${_debounceDurationMs.data}ms)',
        );
      },
      leading: _debounceLeading.data,
    );

    // 2. Throttle Effect: Suppresses high-frequency clicks, enforces window rate limit
    throttleEffect = throttleTrigger.effect.throttle(
      Duration(milliseconds: _throttleDurationMs.data),
      () {
        _throttledRunCount.set(_throttledRunCount.data + 1);
        _recordLog(
          '[Throttle] Executed run #${_throttledRunCount.data} '
          '(total clicks: ${_rawClickCount.data}, window: ${_throttleDurationMs.data}ms)',
        );
      },
      leading: _throttleLeading.data,
      trailing: _throttleTrailing.data,
    );

    // 3. Take Effect: Strict execution limit with self-teardown & reactivation guard
    takeEffect = takeTrigger.effect(
      () {
        final current = _takeExecutedCount.data + 1;
        _takeExecutedCount.set(current);
        _recordLog('[Take] Execution $current/$takeLimit succeeded!');
        if (current >= takeLimit) {
          _isTakeDormant.set(true);
          _recordLog(
            '[Dormant] Execution limit reached ($takeLimit)! Early self-teardown executed. '
            'Terminal locked into permanent dormancy.',
          );
        }
      },
      take: takeLimit,
    );

    _syncEffects();
  }

  void _syncEffects() {
    effects = (debounceEffect, throttleEffect, takeEffect).group;
    _effectsVersion.set(_effectsVersion.data + 1);
  }

  // ---------------------------------------------------------------------------
  // Telemetry Logging
  // ---------------------------------------------------------------------------

  void _recordLog(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond ~/ 100)}';
    final list = List<String>.from(_eventLogs.data)
      ..insert(0, '[$timeStr] $message');
    if (list.length > 25) list.removeLast();
    _eventLogs.set(list);
  }

  void clearLogs() {
    _eventLogs.set([]);
  }

  // ---------------------------------------------------------------------------
  // Lab 1: Debounce Actions
  // ---------------------------------------------------------------------------

  void updateSearchQuery(String query) {
    _rawKeyStrokes.set(_rawKeyStrokes.data + 1);
    _searchQuery.set(query);
  }

  void simulateFastTyping() {
    const sequence = ['L', 'Lo', 'Lot', 'Lotu', 'Lotus', 'Lotus What'];
    for (int i = 0; i < sequence.length; i++) {
      _rawKeyStrokes.set(_rawKeyStrokes.data + 1);
      _searchQuery.set(sequence[i]);
    }
    _recordLog(
      '[Rapid Typing] Sent ${sequence.length} keystrokes instantaneously. '
      'Waiting ${_debounceDurationMs.data}ms for debounced dispatch...',
    );
  }

  void setDebounceDelay(int ms) {
    _debounceDurationMs.set(ms);
    _recreateDebounceEffect();
    _recordLog('[Config] Debounce duration updated to ${ms}ms');
  }

  void toggleDebounceLeading(bool val) {
    _debounceLeading.set(val);
    _recreateDebounceEffect();
    _recordLog('[Config] Debounce leading edge toggled to $val');
  }

  void _recreateDebounceEffect() {
    debounceEffect = searchQuery.effect.debounce(
      Duration(milliseconds: _debounceDurationMs.data),
      () {
        _debouncedCalls.set(_debouncedCalls.data + 1);
        _lastDispatchedQuery.set(
          _searchQuery.data.isEmpty ? '(cleared)' : _searchQuery.data,
        );
        _recordLog(
          '[Debounce] Dispatched query "${_lastDispatchedQuery.data}" '
          '(${_debounceDurationMs.data}ms)',
        );
      },
      leading: _debounceLeading.data,
    );
    _syncEffects();
  }

  void resetDebounce() {
    _searchQuery.set('');
    _rawKeyStrokes.set(0);
    _debouncedCalls.set(0);
    _lastDispatchedQuery.set('(none)');
    _recordLog('Debounce Lab reset');
  }

  // ---------------------------------------------------------------------------
  // Lab 2: Throttle Actions
  // ---------------------------------------------------------------------------

  void fireRapidClick() {
    _rawClickCount.set(_rawClickCount.data + 1);
    _throttleTrigger.set(_throttleTrigger.data + 1);
  }

  void burstClicks([int count = 8]) {
    for (int i = 0; i < count; i++) {
      _rawClickCount.set(_rawClickCount.data + 1);
      _throttleTrigger.set(_throttleTrigger.data + 1);
    }
    _recordLog(
      '[Click Storm] $count clicks fired instantaneously! '
      'Throttle window (${_throttleDurationMs.data}ms) limits executions.',
    );
  }

  void setThrottleInterval(int ms) {
    _throttleDurationMs.set(ms);
    _recreateThrottleEffect();
    _recordLog('[Config] Throttle interval updated to ${ms}ms');
  }

  void toggleThrottleLeading(bool val) {
    _throttleLeading.set(val);
    _recreateThrottleEffect();
    _recordLog('[Config] Throttle leading edge toggled to $val');
  }

  void toggleThrottleTrailing(bool val) {
    _throttleTrailing.set(val);
    _recreateThrottleEffect();
    _recordLog('[Config] Throttle trailing edge toggled to $val');
  }

  void _recreateThrottleEffect() {
    throttleEffect = throttleTrigger.effect.throttle(
      Duration(milliseconds: _throttleDurationMs.data),
      () {
        _throttledRunCount.set(_throttledRunCount.data + 1);
        _recordLog(
          '[Throttle] Executed run #${_throttledRunCount.data} '
          '(total clicks: ${_rawClickCount.data})',
        );
      },
      leading: _throttleLeading.data,
      trailing: _throttleTrailing.data,
    );
    _syncEffects();
  }

  void resetThrottle() {
    _rawClickCount.set(0);
    _throttledRunCount.set(0);
    _throttleTrigger.set(0);
    _recordLog('Throttle Lab reset');
  }

  // ---------------------------------------------------------------------------
  // Lab 3: Take & Reactivation Guard Actions
  // ---------------------------------------------------------------------------

  void claimTakeTicket() {
    _takeClickAttempts.set(_takeClickAttempts.data + 1);
    _takeTrigger.set(_takeTrigger.data + 1);
  }

  void attemptForceReactivation() {
    // In declarative scope-bound reactivity, once an effect reaches its take limit,
    // the Reactivation Guard permanently locks it into dormancy.
    // Even if the parent scope re-evaluates or re-attaches, the exhausted effect never executes.
    _guardBlockedAttempts.set(_guardBlockedAttempts.data + 1);
    _recordLog(
      '[Guard Active] Reactivation Guard Active! Exhausted Effect is permanently dormant. '
      'Scope re-evaluation cannot revive it.',
    );
  }

  void resetTakeLab() {
    _takeClickAttempts.set(0);
    _takeExecutedCount.set(0);
    _isTakeDormant.set(false);
    _guardBlockedAttempts.set(0);
    _takeTrigger.set(0);

    // Create a fresh effect instance
    takeEffect = takeTrigger.effect(
      () {
        final current = _takeExecutedCount.data + 1;
        _takeExecutedCount.set(current);
        _recordLog('[Take] Execution $current/$takeLimit succeeded!');
        if (current >= takeLimit) {
          _isTakeDormant.set(true);
          _recordLog(
            '[Dormant] Execution limit reached ($takeLimit)! Early self-teardown executed. '
            'Terminal locked into permanent dormancy.',
          );
        }
      },
      take: takeLimit,
    );
    _syncEffects();

    _recordLog(
        'Take & Reactivation Guard Lab reset with a fresh take: 3 Effect');
  }

  // ---------------------------------------------------------------------------
  // Showcase Section Metadata
  // ---------------------------------------------------------------------------

  ShowcaseSection get section => ShowcaseSection(
        id: '10_temporal_orchestration',
        number: '10',
        title: 'Temporal Orchestration & Scope Effects',
        subtitle:
            'Time-domain rate limiting (Debounce/Throttle), Take guards & Scope-bound Effects',
        badge: 'Time & Effect',
        icon: Icons.timer_outlined,
        codeSnippet: '''
// 1. Debounce Effect: Postpones execution until quiet for duration
final debounce = queryWhat.effect.debounce(
  const Duration(milliseconds: 350),
  () => fetchAutocomplete(queryWhat.data),
  leading: false,
);

// 2. Throttle Effect: Enforces minimum time interval between runs
final throttle = clickWhat.effect.throttle(
  const Duration(milliseconds: 600),
  () => sendHapticFeedback(),
  leading: true,
  trailing: true,
);

// 3. Execution Limit & Reactivation Guard (take: 3)
// Automatically disposes listeners after 3 runs; permanent dormancy
final limited = buttonWhat.effect(
  () => claimFreeGift(),
  take: 3,
);

// In UI Widget:
// tether(debounce); tether(throttle); tether(limited);
''',
        highlights: const [
          'DebounceEffect: Postpones execution until bursts cease for a silence window',
          'ThrottleEffect: Suppresses high-frequency invalidations with leading & trailing edge controls',
          'take: int?: Automatic early self-teardown with Reactivation Guard preventing accidental revival',
          'Scope-bound Effect & EffectGroup: Declarative lifecycle management via tether() with zero manual activation boilerplate',
        ],
        roadmapTree: '''
[What Temporal Orchestration Pipeline]
 ├── source.effect.debounce(duration, ...)  -> Trailing/Leading Silence Window
 │    ├── leading: false (default)          -> Fire after quiet period
 │    └── leading: true                     -> Fire immediately, suppress bursts
 │
 ├── source.effect.throttle(duration, ...)  -> Guaranteed Min Interval
 │    ├── leading: true                     -> Fire first event immediately
 │    └── trailing: true                    -> Fire final accumulated event
 │
 ├── source.effect(..., take: N)            -> Self-Teardown Reactivation Guard
 │    └── Closes listener after N runs      -> Permanent Dormancy (0 leak)
 │
 └── EffectGroup([e1, e2, ...])             -> Batch Temporal Lifecycle Tethering
''',
        builder: () => TemporalOrchestrationSectionDemo(),
      );
}
