// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Top-Level Transactional Batch Execution Functor
// =============================================================================

/// Top-level transactional batch functor.
///
/// Executes the given action callback within a transactional batch scope, coalescing downstream
/// terminal notifications until the outermost batch scope completes.
///
/// Mutations occurring inside the batch propagate dirty signals eagerly to preserve
/// Read-Your-Own-Writes (RYOW) integrity for derived computations, while terminal
/// invalidations (effects, listeners, UI rebuilds) are deferred and flushed atomically
/// as a single batch when the outermost batch scope completes.
///
/// ## System Architectural Flow
/// ```text
///                     batch(() {
///                       sourceA.data = 10; ──► Push-Dirty Phase 1 (Eager)
///                       sourceB.data = 20; ──► Push-Dirty Phase 1 (Eager)
///                     })
///                             │
///                             ▼ (Outer batch scope exits)
///              [Coalesced Phase 2 Notification Wave]
///                             │
///          ┌──────────────────┴──────────────────┐
///          ▼                                     ▼
///   Terminal Listener A                   Terminal Listener B
///   (Flushed once)                        (Flushed once)
/// ```
///
/// ## Architectural Benefits
/// 1. **Glitch-Free Atomicity**: Intermediate inconsistent states are never dispatched to terminals.
/// 2. **Notification Coalescing**: Reduces redundant microtask scheduling and UI layout passes.
/// 3. **Read-Your-Own-Writes (RYOW)**: In-scope evaluations immediately reflect local mutations.
///
/// See [BatchFunctor.call] for complete parameter specifications, execution contracts,
/// and anti-pattern prevention.
///
/// ## Examples
/// ```dart
/// final counter = WhatController(0);
/// final text = WhatController('hello');
///
/// batch(() {
///   counter.data++;
///   text.data = 'world';
/// }); // All downstream terminal listeners fire once here.
/// ```
const batch = BatchFunctor._();

/// Callable functor managing transactional batch scopes in the reactive LPDAG engine.
final class BatchFunctor {
  /// Internal const constructor for [batch].
  const BatchFunctor._();

  /// Executes [action] within a transactional batch scope.
  ///
  /// Mutations occurring inside the batch propagate dirty signals eagerly to preserve
  /// Read-Your-Own-Writes (RYOW) integrity for derived computations, while terminal
  /// invalidations (effects, listeners, UI rebuilds) are deferred and flushed atomically
  /// as a single batch when the outermost batch scope completes.
  ///
  /// * [action]: The synchronous closure containing reactive state mutations.
  ///
  /// **Requires:**
  /// * [action] must be a synchronous execution block. Asynchronous operations scheduled
  ///   or awaited inside [action] execute after the batch scope has already closed.
  ///
  /// **Ensures:**
  /// * Returns the value produced by [action].
  /// * Defers and coalesces terminal invalidations until the outermost batch completes.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT invoke long-running asynchronous operations inside synchronous `batch()`.
  ///   `batch()` applies to the synchronous execution block only.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Awaiting async work inside synchronous batch
  /// batch(() async {
  ///   counter.data++;
  ///   await Future.delayed(const Duration(seconds: 1)); // Batch already exited synchronously!
  ///   text.data = 'Done';
  /// });
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Wrap synchronous mutation groups in batch()
  /// counter.data++;
  /// await Future.delayed(const Duration(seconds: 1));
  /// batch(() {
  ///   text.data = 'Done';
  ///   status.data = Status.ready;
  /// });
  /// ```
  @pragma('vm:prefer-inline')
  R call<R>(R Function() action) => _BatchScope.run(action);

  /// Whether a transactional batch scope is currently executing.
  ///
  /// **Ensures:**
  /// * Returns `true` if currently within an active batch scope.
  @pragma('vm:prefer-inline')
  bool get isBatching => _BatchScope.isBatching;
}
