// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// EffectRunner Public Contract
// =============================================================================

/// An active standalone execution terminal that imperatively controls the lifecycle of an [Effect].
///
/// While declarative [Effect] nodes are typically tethered to reactive tracking scopes
/// via [WhatVia.tether], an [EffectRunner] enables executing effects imperatively
/// outside reactive scopes (e.g. in domain services, ViewModels, or background workers).
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────┐
/// │                Declarative Effect Node                 │
/// └───────────────────────────┬────────────────────────────┘
///                             │ (Active Subscription Edge)
///                             ▼
/// ┌────────────────────────────────────────────────────────┐
/// │                      EffectRunner                      │
/// ├────────────────────────────────────────────────────────┤
/// │ • activate()   ──> Attaches edge, resumes execution    │
/// │ • deactivate() ──> Relinquishes edge (Dormancy)        │
/// │ • isActive     ──> Dual-state health verification      │
/// └────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero-Leak Inactive Dormancy**: When deactivated via [deactivate] (or before `autoStart`),
///    immediately relinquishes its subscription edge, guaranteeing dormant upstream subgraphs when unobserved.
/// 2. **Imperative Standalone Lifecycle**: Controls reactive side-effect execution in services,
///    view models, or CLI tasks outside widget lifecycles.
/// 3. **Subscriber-Driven Dormancy Invariant**: If the same [Effect] instance is shared between
///    a tracking scope (`via.tether`) and an [EffectRunner], deactivating the runner leaves the
///    effect active as long as the tethering scope remains active. The underlying effect enters
///    true dormancy only when **all** observing terminals and tethers have detached.
/// 4. **Dual-State Health Invariant**: [isActive] reflects both the runner's lifecycle state
///    and the underlying effect terminal's status. If the underlying effect deactivates due to
///    exhausting its `take` ticket quota (Early Teardown), [isActive] transitions to `false` automatically.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT call `.run()` repeatedly inside Flutter build methods or reactive derivations without
///   deactivating; unmanaged runners stay attached to upstream effects and cause memory leaks.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Spawning effect runners inside build method causes memory leaks
/// Widget build(BuildContext context) {
///   searchEffect.run(); // New runner created on every render frame!
///   return Text('Searching...');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Manage runner in long-lived lifecycle scope or State class
/// class SearchService {
///   late final EffectRunner _runner;
///
///   void init() {
///     _runner = searchEffect.run();
///   }
///
///   void dispose() => _runner.deactivate();
/// }
/// ```
///
/// ## Examples
/// ```dart
/// final query = WhatController('');
/// final searchEffect = query.what.effect.debounce(
///   const Duration(milliseconds: 300),
///   () => apiService.search(untracked(query.what)),
/// );
///
/// // Start standalone execution:
/// final runner = searchEffect.run();
///
/// // Pause observation:
/// runner.deactivate();
///
/// // Resume observation:
/// runner.activate();
/// ```
abstract interface class EffectRunner implements RawTerminal {
  /// Creates an [EffectRunner] managing standalone execution of [effect].
  ///
  /// * [effect]: The target declarative [Effect] to execute.
  /// * [autoStart]: Whether to activate execution immediately upon construction. Defaults to `true`.
  ///
  /// **Ensures:**
  /// * Attaches an active subscription edge to [effect] if [autoStart] is `true`.
  /// * Returns an active [EffectRunner] governing execution of [effect].
  ///
  /// ## Examples
  /// ```dart
  /// final runner = EffectRunner(myEffect, autoStart: false);
  /// // Start execution later:
  /// runner.activate();
  /// ```
  factory EffectRunner(
    Effect effect, {
    bool autoStart,
  }) = _EffectRunnerImpl;

  /// Activates or resumes observation and execution of the underlying effect.
  ///
  /// **Ensures:**
  /// * Attaches an active subscription edge to [effect] and activates the underlying terminal.
  @override
  void activate();

  /// Deactivates observation and execution, relinquishing this runner's subscription edge.
  ///
  /// **Ensures:**
  /// * Relinquishes this runner's subscription edge and transitions to inactive dormancy.
  @override
  void deactivate();

  /// The underlying [Effect] executed by this runner.
  Effect get effect;

  /// Whether both this runner and its underlying effect terminal are currently active.
  ///
  /// Returns `false` if this runner has been deactivated via [deactivate], or if
  /// the underlying effect terminal has completed early teardown (e.g. exhausted `take` tickets).
  @override
  bool get isActive;
}

// =============================================================================
// EffectRunExtension
// =============================================================================

/// Extension granting declarative [Effect] instances direct invocation of an [EffectRunner].
extension EffectRunExtension on Effect {
  /// Runs this declarative [Effect] as a standalone execution terminal governed by an [EffectRunner].
  ///
  /// * [autoStart]: Whether to activate execution immediately upon construction. Defaults to `true`.
  ///
  /// **Ensures:**
  /// * Returns an [EffectRunner] managing standalone execution of this effect.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT invoke `.run()` inside Flutter build methods or reactive derivations without deactivating.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Calling .run() on every frame rebuild
  /// Widget build(BuildContext context) {
  ///   loggingEffect.run(); // Re-creates and leaks runner
  ///   return Container();
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Run standalone effect in service lifecycle
  /// class LoggingService {
  ///   late final EffectRunner _runner;
  ///   void start() => _runner = loggingEffect.run();
  ///   void stop() => _runner.deactivate();
  /// }
  /// ```
  ///
  /// ## Examples
  /// ```dart
  /// final counter = WhatController(0);
  /// final loggingEffect = counter.what.effect(() => log(untracked(counter.what)));
  /// final runner = loggingEffect.run();
  ///
  /// // Clean up when finished:
  /// runner.deactivate();
  /// ```
  @pragma('vm:prefer-inline')
  EffectRunner run({bool autoStart = true}) => EffectRunner(this, autoStart: autoStart);
}
