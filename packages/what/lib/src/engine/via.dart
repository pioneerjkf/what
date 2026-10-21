// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Scoped Explicit Dependency Tracker (Hybrid Manifest)
// =============================================================================

/// The scoped dependency tracker interface injected into [computed], [RawViaTerminal],
/// and reactive widget build callbacks.
///
/// Unlike implicit global stack tracking, [WhatVia] requires explicit
/// observation calls (`via(node)`) during the evaluation pass. This creates an
/// explicit, deterministic, and AI-friendly dependency manifest while preserving
/// dynamic runtime branching and 1-pass epoch-based pruning.
///
/// ## Data Propagation Flow
/// ```text
/// [Evaluation Scope / RawViaTerminal]
///        │
///        ├─► via(nodeA) ──► Registers DAG edge & returns valid data payload A
///        ├─► via(nodeB) ──► Registers DAG edge & returns valid data payload B
///        │
///        └─► Returns computed result & sweeps obsolete edges (1-Pass Epoch Sweeping)
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero Tracking Stack Overhead**: Dependency registration happens purely via explicit function
///    calls without maintaining or unwinding global thread-local or zone-scoped context stacks.
/// 2. **1-Pass Dynamic Epoch Sweeping**: Unused dependency edges from inactive conditional branches
///    are swept immediately in a single pass at the end of the evaluation turn.
/// 3. **AI Coding Agent Ground Truth**: Explicit manifests prevent AI agents and static analysis tools
///    from missing reactive edges or generating rogue, untracked property reads.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT read reactive nodes untracked inside a derivation closure without
///   wrapping them in `via(...)`.
/// - Do NOT store or reuse the [WhatVia] instance outside the synchronous evaluation closure.
///
/// **BAD:**
/// ```dart
/// final price = WhatController(100);
/// final quantity = WhatController(2);
///
/// // [Anti-Pattern] Reading untracked directly without via() leaves node untracked
/// final badTotal = computed((via) {
///   return untracked(price.what) * untracked(quantity.what); // Untracked! Misses graph invalidations!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// final price = WhatController(100);
/// final quantity = WhatController(2);
///
/// // [Recommended] Explicitly register dependencies through via()
/// final goodTotal = computed((via) {
///   return via(price.what) * via(quantity.what); // Dynamically tracked in LPDAG
/// });
/// ```
///
/// ## Examples
/// ```dart
/// final firstName = WhatController('Jane');
/// final lastName = WhatController('Doe');
///
/// final fullName = computed((via) {
///   return '${via(firstName.what)} ${via(lastName.what)}';
/// });
///
/// // Pattern matching on upstream node state without short-circuiting:
/// final status = computed((via) {
///   final state = via.state(firstName.what);
///   return switch (state.phase) {
///     WhatPhase.valid => 'User: ${state.data}',
///     WhatPhase.empty => 'No user',
///     WhatPhase.error => 'Error: ${state.error}',
///   };
/// });
/// ```
abstract interface class WhatVia {
  /// Scoped watch function that tracks [what] as an upstream dependency
  /// and returns its underlying valid data payload of type [T].
  ///
  /// If [what] is currently in an empty or error state, short-circuits
  /// the current evaluation and propagates that state directly downstream.
  ///
  /// * [what]: The reactive node to observe within this evaluation epoch.
  ///
  /// **Ensures:**
  /// * Registers [what] as an active dependency in the current evaluation epoch.
  /// * Returns the underlying payload [T] when in a valid data state.
  /// * Throws an internal short-circuit sentinel when [what] is empty or has error,
  ///   short-circuiting downstream evaluation.
  ///
  /// ## Examples
  /// ```dart
  /// final counter = WhatController(0);
  /// final doubled = computed((via) => via(counter.what) * 2);
  /// ```
  T call<T>(What<T> what);

  /// Registers [what] as an active dependency in the current evaluation epoch
  /// and returns its 3-phase [WhatState] container without short-circuiting.
  ///
  /// Use this method when you need to defensively inspect empty/error states,
  /// or perform exhaustive 3-state pattern matching inside reactive derivations.
  ///
  /// * [what]: The reactive node to observe within this evaluation epoch.
  ///
  /// **Ensures:**
  /// * Registers [what] as an active dependency in the current evaluation epoch.
  /// * Returns the zero-allocation [WhatState] view of [what].
  ///
  /// ## Examples
  /// ```dart
  /// final user = WhatController.empty<User>();
  ///
  /// // 1. Defensive conditional inspection
  /// final label = computed((via) {
  ///   final userState = via.state(user.what);
  ///   if (userState.isEmpty) return 'Guest';
  ///   return userState.data.name;
  /// });
  ///
  /// // 2. Exhaustive 3-phase pattern matching via phase (Dart 3 switch)
  /// final status = computed((via) {
  ///   final userState = via.state(user.what);
  ///   return switch (userState.phase) {
  ///     WhatPhase.valid => 'Welcome, ${userState.data.name}!',
  ///     WhatPhase.empty => 'Awaiting user sign-in',
  ///     WhatPhase.error => 'Authentication error: ${userState.error}',
  ///   };
  /// });
  /// ```
  WhatState<T> state<T>(What<T> what);

  /// Tethers declarative [tether] to this tracking scope's lifecycle.
  ///
  /// * [tether]: The scoped lifecycle resource or side-effect to attach.
  ///
  /// **Ensures:**
  /// * The tether is automatically activated when this scope activates, and
  ///   deactivated (dormant) when this scope deactivates or is unmounted.
  /// * Emits zero dirty invalidation pulses downstream to parent scopes.
  /// * Returns the identical [tether] instance.
  ///
  /// ## Examples
  /// ```dart
  /// final eventCount = WhatController(0);
  ///
  /// final analyticsLoggerEffect = Effect([eventCount.what], () {
  ///   print('Logged event: ${untracked(eventCount.what)}');
  /// });
  ///
  /// final state = computed((via) {
  ///   via.tether(analyticsLoggerEffect);
  ///   return via(eventCount.what) * 10;
  /// });
  /// ```
  T tether<T extends Tether>(T tether);
}
