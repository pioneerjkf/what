// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Precondition Guarding & Algebraic State Gating
// =============================================================================

/// Represents the decision of a reactive guard evaluation in the What Framework.
///
/// Precondition guards act as algebraic fault-barriers across the Dynamic Triad
/// ([computed], [managed], [switched]). Instead of throwing exceptions or returning
/// synthetic fallback types, a guard halts execution or initiates resource disposal,
/// cleanly transitioning the node into the canonical [WhatState.isEmpty] state.
///
/// ### States
/// - [WhatGuard.pass]: Preconditions are satisfied; execution or resource allocation proceeds.
/// - [WhatGuard.block]: Preconditions are unmet; execution is aborted and the node enters an empty state.
///
/// ### Causal Diagnostics ([WhatGuard.reason])
/// When a guard blocks, its associated [reason] payload (e.g. `String`, `Enum`, `Record`) is
/// stored directly into [WhatSnapshot.emptyReason] and [WhatState.emptyReason] with zero boxing overhead.
///
/// ### Examples
///
/// #### 1. Granular Early-Return Pattern:
/// ```dart
/// final checkoutSummary = computed(
///   (via) => calculateCheckout(via(cart), via(address)),
///   guard: (via) {
///     if (via.state(cart).isEmpty) return WhatGuard.block('CartEmpty');
///     if (via.state(address).isEmpty) return WhatGuard.block('AddressRequired');
///     return WhatGuard.pass;
///   },
/// );
/// ```
///
/// #### 2. Declarative Boolean Extension:
/// ```dart
/// final userFeed = switched(
///   (via) => via(isAdmin) ? adminFeed : regularFeed,
///   guard: (via) => via(isLoggedIn).guarded('UserNotAuthenticated'),
/// );
/// ```
///
/// #### 3. Multi-Input Record Tuple Guarding (0-Heap):
/// ```dart
/// final combined = computed(
///   (via) => process(via(a), via(b)),
///   guard: (via) => (via.state(a), via.state(b)).guarded('AwaitingInputs'),
/// );
/// ```
sealed class WhatGuard {
  const WhatGuard._();

  /// Indicates that preconditions are satisfied and execution should proceed.
  static const pass = _PassWhatGuard();

  /// Indicates that preconditions are not satisfied, blocking execution with the specified [reason].
  ///
  /// * [reason]: The diagnostic payload explaining why preconditions were unmet.
  ///
  /// **Ensures:**
  /// * Returns a blocking [WhatGuard] containing [reason].
  @pragma('vm:prefer-inline')
  static WhatGuard block([Object reason = 'PrerequisiteNotMet']) => _BlockWhatGuard(reason);

  /// Convenient factory converting a boolean [condition] into [WhatGuard.pass] or [WhatGuard.block].
  ///
  /// * [condition]: The boolean prerequisite expression to evaluate.
  /// * [reason]: The diagnostic payload used when [condition] evaluates to `false`.
  ///
  /// **Ensures:**
  /// * Returns [WhatGuard.pass] when [condition] is `true`, or a blocking [WhatGuard] with [reason] when `false`.
  @pragma('vm:prefer-inline')
  factory WhatGuard(bool condition, [Object reason = 'PrerequisiteNotMet']) =>
      condition ? WhatGuard.pass : WhatGuard.block(reason);

  /// Whether this guard passed, allowing execution to proceed.
  bool get isPass;

  /// Whether this guard blocked execution, transitioning the node into an empty state.
  bool get isBlock => !isPass;

  /// The diagnostic reason or payload associated with a blocked guard, or `null` if passed.
  Object? get reason;
}

/// Zero-cost compile-time extensions converting booleans into [WhatGuard] decisions.
extension WhatBoolGuardExtension on bool {
  /// Converts this boolean to [WhatGuard.pass] if `true`, or [WhatGuard.block] with [reason] if `false`.
  ///
  /// * [reason]: The diagnostic payload used when this boolean evaluates to `false`.
  ///
  /// **Ensures:**
  /// * Returns [WhatGuard.pass] if `this` is `true`, or a blocking [WhatGuard] with [reason] if `false`.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => this ? WhatGuard.pass : WhatGuard.block(reason);
}
