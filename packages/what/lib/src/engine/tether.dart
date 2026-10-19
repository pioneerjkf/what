// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Tether Base Contract
// =============================================================================

/// Top-level declarative lifecycle-bound entity in the What reactive DAG.
///
/// A [Tether] represents a non-propagating lifecycle node whose active state
/// is strictly governed by enclosing tracking scopes via [WhatVia.tether].
///
/// ## Architectural Separation of Concerns
/// In the What framework, reactivity is organized across two decoupled planes:
/// 1. **Data Plane ([What])**: Reactive nodes that evaluate and propagate state mutations
///    downstream via the 2-Phase Push-Dirty / Lazy-Pull DAG.
/// 2. **Lifecycle Plane ([Tether])**: Declarative entities (such as side-effects, resource
///    cleanups, or stream listeners) whose activation, deactivation, and epoch sweeping
///    are bound directly to an enclosing reactive scope.
///
/// ## System Architectural Flow
/// ```text
/// [Enclosing Scope (computed / terminal)]
///            │
///            ▼ (via.tether(tetherNode))
///     [Tether Node (e.g. Effect)]
///            │
///            ├─► Scope activates   ──► Tether activates (allocates / listens)
///            ├─► Scope deactivates ──► Tether deactivates (dormant / releases)
///            └─► Non-propagating   ──► Never emits dirty pulses upstream
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Subscriber-Driven Dormancy**: A [Tether] is automatically activated when its enclosing
///    scope activates, and deactivated (dormant) when the scope becomes dormant or is swept
///    during dynamic epoch pruning.
/// 2. **Non-Propagating Invariant**: Tethers never emit dirty invalidation pulses or newer versions
///    downstream to parent watch scopes.
/// 3. **1-Pass Dynamic Epoch Pruning**: Tethers declared in inactive conditional branches are
///    automatically detached and swept in a single pass at the end of the evaluation turn.
///
/// ## Examples
/// ```dart
/// final loggingEffect = Effect([userId.what], () {
///   analytics.logEvent('user_updated');
/// });
///
/// final userDashboard = computed((via) {
///   // Binds the lifecycle of loggingEffect to the active lifetime of this computed node:
///   via.tether(loggingEffect);
///   return 'Dashboard for ${via(userId.what)}';
/// });
/// ```
abstract base class Tether extends _Node {
  /// Internal const constructor for [Tether] subclasses.
  Tether._();

  /// Tethers never report newer versions to parent watch scopes.
  @override
  @pragma('vm:prefer-inline')
  bool _isNewerThan(int version) => false;
}
