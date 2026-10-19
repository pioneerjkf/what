// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/reactive_effects_section.dart';

/// Sub-store for Section 07: Reactive Effects & Side-Effect Pipeline
class ReactiveEffectsStore {
  ReactiveEffectsStore() {
    _initEffects();
  }

  // ---------------------------------------------------------------------------
  // Reactive State Controllers
  // ---------------------------------------------------------------------------

  final _counter = WhatController<int>(0);
  final _alertThreshold = WhatController<int>(5);
  final _isTrackingDetails = WhatController<bool>(false);
  final _detailPayload = WhatController<String>('High Priority Task');
  final _untrackedNode = WhatController<int>(100);
  final _isEffectActive = WhatController<bool>(true);
  final _effectRunCount = WhatController<int>(0);
  final _lastThresholdAlert = WhatController<String>('None');
  final _eventLogs = WhatController<List<String>>([]);
  final _lastBurstCount = WhatController<int>(0);
  final _lastSavingsCount = WhatController<int>(0);

  What<int> get counter => _counter.what;
  What<int> get alertThreshold => _alertThreshold.what;
  What<bool> get isTrackingDetails => _isTrackingDetails.what;
  What<String> get detailPayload => _detailPayload.what;
  What<int> get untrackedNode => _untrackedNode.what;
  What<bool> get isEffectActive => _isEffectActive.what;
  What<int> get effectRunCount => _effectRunCount.what;
  What<String> get lastThresholdAlert => _lastThresholdAlert.what;
  What<List<String>> get eventLogs => _eventLogs.what;
  What<int> get lastBurstCount => _lastBurstCount.what;
  What<int> get lastSavingsCount => _lastSavingsCount.what;

  // ---------------------------------------------------------------------------
  // Reactive Effect Instances
  // ---------------------------------------------------------------------------

  late final Effect watchEffect;
  late final Effect tupleEffect;

  /// Single What direct effect on [counter].
  late final Effect singleEffect;

  /// Composite [EffectGroup] bundling all showcase effects into a single lifecycle terminal.
  late final EffectGroup effects;

  void _initEffects() {
    // 1. Dynamic Discovery WhatVia Effect
    // Only tracks nodes wrapped in `via()`. Direct raw reads remain untracked!
    watchEffect = Effect.via((via) {
      final current = via(counter);
      final tracking = via(isTrackingDetails);

      // [Invariant] Untracked Execution Boundary:
      // Reading untrackedNode.data directly does NOT subscribe!
      // ignore: avoid_untracked_what_read
      final untrackedVal = untrackedNode.peek;

      String details;
      if (tracking) {
        // Dynamically discovered edge when tracking == true
        final payload = via(detailPayload);
        details = 'Payload="$payload"';
      } else {
        details = 'Detail Branch Inactive';
      }

      _recordEffectTrigger(
        'Effect.via: count=$current | $details (untracked=$untrackedVal)',
      );
    });

    // 2. Explicit Tuple Effect on 2-tuple (counter, alertThreshold)
    // Skips initial evaluation (0 runs upon activation).
    tupleEffect = (counter, alertThreshold).effect(() {
      final current = counter.peek;
      final threshold = alertThreshold.peek;

      if (current >= threshold) {
        final alertMsg =
            'Threshold Reached! Current ($current) >= Threshold ($threshold)';
        _lastThresholdAlert.set(alertMsg);
        _recordEffectTrigger('TupleEffect: $alertMsg');
      }
    });

    // 3. Explicit Single What Effect
    singleEffect = counter.effect(() {
      final current = counter.peek;
      _recordEffectTrigger(
        'SingleEffect: Direct counter.effect() fired = $current',
      );
    });

    // 4. Composite EffectGroup bundling all effects via tuple extension
    effects = (watchEffect, tupleEffect, singleEffect).group;
  }

  // ---------------------------------------------------------------------------
  // Telemetry & Observability Logging (Showcase UI Monitoring)
  // ---------------------------------------------------------------------------

  /// Architectural Note (Telemetry & Observability vs Derived State):
  ///
  /// * [Anti-Pattern Warning]:
  ///   Mutating business domain state (`controller.set()`) inside an effect to
  ///   produce derived state is a severe anti-pattern in reactive architectures.
  ///   Derived state must always be defined as synchronous, glitch-free [computed].
  ///
  /// * [Legitimate Telemetry Sink] (Production Logging & Telemetry Purposes):
  ///   Updating [effectRunCount] and [eventLogs] inside this effect is not business
  ///   derived state, but a necessary **telemetry UI / live observability** sink to
  ///   visualize trigger counts and real-time logs in the demo widgets.
  ///   In a real-world production app, this corresponds to forwarding events directly
  ///   to external APM consoles or sinks (`analytics.logEvent()`, `datadog.record()`)
  ///   without passing through UI state.
  ///
  /// * [Zero Circular Invalidation Cascades]:
  ///   [effectRunCount] and [eventLogs] are unidirectional terminal leaf sinks.
  ///   Upstream effects never track this logging state via `via()`, ensuring no reentrancy
  ///   loops or dirty cascade pulses occur.
  void _recordEffectTrigger(String message) {
    _effectRunCount.set(_effectRunCount.data + 1);
    _recordLog(message);
  }

  void _recordLog(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond ~/ 100)}';
    final list = List<String>.from(_eventLogs.data)
      ..insert(0, '[$timeStr] $message');
    if (list.length > 20) list.removeLast();
    _eventLogs.set(list);
  }

  // ---------------------------------------------------------------------------
  // Interactive Actions
  // ---------------------------------------------------------------------------

  void incrementCounter() => _counter.set(_counter.data + 1);

  void setCounter(int val) => _counter.set(val);

  /// Fires [count] synchronous mutations in a single event loop tick
  /// to visually demonstrate microtask batch coalescing (N mutations -> 1 run).
  void burstMultiMutation([int count = 10]) {
    for (int i = 0; i < count; i++) {
      _counter.set(_counter.data + 1);
    }
    _lastBurstCount.set(count);
    _lastSavingsCount.set(count - 1);
    _recordLog(
        '[Storm] $count synchronous mutations coalesced into 1 microtask batch!');
  }

  void resetCounter() {
    _counter.set(0);
    _lastBurstCount.set(0);
    _lastSavingsCount.set(0);
    _lastThresholdAlert.set('None');
    _recordLog('Counter reset to 0');
  }

  void toggleDetailTracking(bool val) {
    _isTrackingDetails.set(val);
    _recordLog('Dynamic tracking toggled: $val');
  }

  void cycleDetailPayload() {
    const presets = [
      'High Priority Task',
      'Background Syncing',
      'Telemetry Report',
      'Database Invalidation',
    ];
    final curIdx = presets.indexOf(_detailPayload.data);
    final next = presets[(curIdx + 1) % presets.length];
    _detailPayload.set(next);
  }

  void setAlertThreshold(int value) {
    _alertThreshold.set(value);
  }

  void mutateUntracked() {
    _untrackedNode.set(_untrackedNode.data + 1);
    _recordLog(
      'Mutated untrackedNode to ${untrackedNode.peek} (Should NOT trigger Effect.via)',
    );
  }

  void toggleLifecycle(bool activate) {
    _isEffectActive.set(activate);
    if (activate) {
      _recordLog(
          'Lifecycle: Scoped effects ACTIVATED via effect() in WhatWidget');
    } else {
      _recordLog(
          'Lifecycle: Scoped effects DORMANT (swept from reactive scope)');
    }
  }

  void clearLogs() {
    _eventLogs.set([]);
  }

  // ---------------------------------------------------------------------------
  // Showcase Section Metadata
  // ---------------------------------------------------------------------------

  ShowcaseSection get section => ShowcaseSection(
        id: '09_reactive_effects',
        number: '09',
        title: 'Reactive Effects & Side-Effect Pipeline',
        subtitle:
            'Untracked side-effects with zero UI dirty pulses & dynamic discovery',
        badge: 'Effects',
        icon: Icons.bolt_rounded,
        codeSnippet: '''
// 1. Declarative Widget Lifecycle (via.tether) - ZERO manual dispose()!
// Automatically activates on mount and cleanly auto-disposes on unmount.
// Eliminates boilerplate, memory leaks, and dispose-trauma forever!
base class UserAlertWidget extends WhatWidget {
  @override
  Widget build(BuildContext context, WhatVia via) {
    // Declarative Anchoring: Zero manual dispose() required!
    via.tether((counter, threshold).effect(() {
      if (counter.data >= threshold.data) {
        showToast('VIP Threshold Reached: \${counter.data}');
      }
    }));

    return Text('Counter: \${via(counter)}');
  }
}

// 2. Dynamic Discovery WhatVia Effect
// Only tracks nodes wrapped in `via()`. Reading directly is NOT tracked!
final watchEffect = Effect.via((via) {
  final count = via(counter);
  if (via(isTracking)) {
    print('Tracked: \${via(details)}');
  }
  final untracked = unobservedNode.data; // Untracked boundary
});

// 3. EffectGroup for Clean Batch Tethering
// In your Store or Controller, bundle effects without managing disposers:
final effects = EffectGroup([
  watchEffect,
  counter.effect(() => print('Counter changed!')),
]);

// Any widget can anchor the entire group in 1 line:
// via.tether(store.effects); // Auto-activated & auto-disposed!''',
        highlights: const [
          'Zero-Dispose via.tether(): Automatically anchors effects to widget lifecycle with zero manual dispose() boilerplate or memory leak trauma.',
          'Zero UI Dirty Pulses: Executes pure side-effects without triggering widget tree rebuilds.',
          'Dynamic Dependency Discovery: Explicit WhatVia branch pruning & untracked execution boundary.',
          'Declarative EffectGroup: Bundles multiple store effects for zero-cost batch lifecycle tethering.',
        ],
        roadmapTree: '''
[What Reactive Effect Pipeline]
 ├── via.tether(effect)                -> Zero-Dispose Declarative Widget Lifecycle
 ├── Effect.via((via) => ...)          -> Dynamic Discovery with 1-Pass Epoch Sweeping
 ├── (s1, s2).effect(() => ...)        -> Explicit Tuple Effect (0 initial run)
 ├── source.effect(() => ...)          -> Explicit Single What Effect
 └── EffectGroup([e1, e2, ...])        -> Zero-Cost Batch Lifecycle Management
''',
        builder: () => ReactiveEffectsSectionDemo(),
      );
}
