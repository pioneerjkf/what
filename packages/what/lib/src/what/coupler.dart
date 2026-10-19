// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Dynamic What Couplers & Pipeline Coupling Sockets
// =============================================================================

/// A dynamic reactive socket controller that allows hot-coupling or cold-coupling upstream
/// [What] pipelines at runtime without rebuilding downstream consumers.
///
/// Standard [What] pipelines form a statically connected DAG. [WhatCoupler] introduces a
/// dynamic 1-tier relay proxy in the pipeline, allowing developers to switch the upstream source
/// node dynamically while maintaining unbroken continuity for downstream listeners.
///
/// Following the Producer-Consumer decoupling model of [WhatController], [WhatCoupler] acts
/// as the controller/producer handle and exposes a read-only [what] consumer view, completely
/// encapsulating mutation and coupling capabilities from downstream consumers.
///
/// ## System Architectural Flow
/// ```text
/// [Upstream What A] (Detached on couple)
///        │
///        ▼ (coupler.couple(whatB))
/// ┌─────────────────────┐
/// │   WhatCoupler<T>    │ ──► what (Read-Only) ──► [Downstream Transformations / Terminals]
/// └─────────────────────┘
///        ▲
///        │ (Newly Attached)
/// [Upstream What B]
/// ```
///
/// **Common Use Cases:**
/// * **Environment Coupling:** Dynamically coupling a mock data source with a live API source.
/// * **Session Management:** Switching the active user stream upon authentication state changes.
/// * **Feature Toggles:** Rerouting reactive data flows based on runtime configuration.
///
/// **Warning (Anti-Pattern Prevention):**
/// - **DO NOT** perform circular coupling (e.g. coupling a downstream node that already depends on this coupler).
///   Circular coupling causes infinite dependency loops and topological corruption.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Circular coupling: coupler depends on downstream child
/// final coupler = WhatCoupler<int>.late();
/// final childWhat = computed((via) => via(coupler.what) + 1);
/// coupler.couple(childWhat); // Circular dependency loop!
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Hot-coupling independent upstream sources
/// final mockSource = What.constant('Guest');
/// final liveSource = WhatController<String>('User123');
///
/// final coupler = WhatCoupler<String>(mockSource);
/// final greetingWhat = computed((via) => 'Hello, ${via(coupler.what)}!');
///
/// coupler.couple(liveSource.what); // Safely coupled to live source
/// ```
base class WhatCoupler<T> with _WhatStateMixin<T> implements LpdagStatus {
  /// Creates a [WhatCoupler] initialized with [inbound].
  ///
  /// * [inbound]: The initial upstream [What] pipeline to relay.
  ///
  /// **Ensures:**
  /// * Returns a [WhatCoupler] delegating to [inbound].
  ///
  /// ## Examples
  /// ```dart
  /// final coupler = WhatCoupler(liveSourceWhat);
  /// ```
  WhatCoupler(What<T> inbound) : _proxy = _CoupledWhat<T>(inbound);

  /// Creates a [WhatCoupler] in an uninitialized (empty) state.
  ///
  /// **Ensures:**
  /// * Returns an empty [WhatCoupler] awaiting its first [couple].
  WhatCoupler.late() : _proxy = _CoupledWhat<T>.late();

  /// Creates a [WhatCoupler] initialized in an error state.
  ///
  /// * [error]: The initial failure or exception object.
  /// * [stackTrace]: Optional stack trace associated with the failure.
  ///
  /// **Ensures:**
  /// * Returns a [WhatCoupler] initialized in an error state.
  WhatCoupler.error(Object error, [StackTrace? stackTrace]) : _proxy = _CoupledWhat<T>.error(error, stackTrace);

  final _CoupledWhat<T> _proxy;

  /// Exposes the underlying read-only [What] node for downstream consumers.
  @pragma('vm:prefer-inline')
  What<T> get what => _proxy;

  /// Couples the currently attached inbound source node with [newInbound].
  ///
  /// * [newInbound]: The new upstream [What] node to attach to this coupler.
  ///
  /// **Ensures:**
  /// * If this coupler is currently active, [newInbound] is automatically activated.
  /// * The previously attached node is detached cleanly.
  /// * Returns the previous inbound node, or `null` if none was attached.
  @pragma('vm:prefer-inline')
  What<T>? couple(What<T> newInbound) => _proxy._performCouple(newInbound);

  /// Safely executes [callback] and couples the inbound node to the returned [What].
  ///
  /// * [callback]: A closure returning the new upstream [What] node to attach.
  ///
  /// **Ensures:**
  /// * If [callback] throws, catches the exception and transitions this coupler to an error state.
  /// * Returns the previous inbound node, or `null` if [callback] threw or the new node was identical to the current inbound.
  What<T>? coupleGuarded(What<T> Function() callback) {
    try {
      return couple(callback());
    } catch (error, stackTrace) {
      setError(error, stackTrace);
      return null;
    }
  }

  /// Immediately decouples and detaches the currently attached inbound node.
  ///
  /// **Ensures:**
  /// * Transitions the coupler into an empty state until a new node is coupled.
  @pragma('vm:prefer-inline')
  void decouple() => _proxy._performDecouple();

  /// Decouples the inbound node only if it matches [what].
  ///
  /// * [what]: The candidate [What] node to decouple.
  ///
  /// **Ensures:**
  /// * Returns `true` if [what] matched the currently attached node and was decoupled.
  /// * Returns `false` otherwise without altering coupling state.
  bool tryDecoupling(What<dynamic> what) {
    if (!identical(what, _proxy._source)) return false;
    decouple();
    return true;
  }

  /// Injects an error state into the coupler with optional [stackTrace].
  ///
  /// * [error]: The error or exception object to transition into.
  /// * [stackTrace]: Optional stack trace associated with [error].
  ///
  /// **Ensures:**
  /// * Transitions the coupler to an error state and propagates dirty invalidation downstream.
  /// * Returns the previously attached inbound node.
  What<T> setError(Object error, [StackTrace? stackTrace]) => _proxy._setError(error, stackTrace);

  /// Whether this coupler currently has active downstream subscribers.
  @override
  bool get isActive => _proxy.isActive;

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _read() => _proxy._read();
}
