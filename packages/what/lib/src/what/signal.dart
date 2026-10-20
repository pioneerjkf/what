// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// What Signal & Signal Controller (Discrete Event Notification)
// =============================================================================

/// A specialized reactive [What] node representing a discrete event signal.
///
/// Implements [What<int>] by emitting a monotonically increasing dirty version sequence (tick count).
/// Observing this node inside reactive scopes (e.g. `computed`, `effect`, or reactive widget scopes) causes
/// downstream subscribers to re-evaluate whenever the signal is emitted via [WhatSignalController.emit].
///
/// ## System Architectural Flow
/// ```text
/// [User Tap / External Event]
///              │
///              ▼ (signalController.emit())
/// ┌───────────────────────────┐
/// │   WhatSignalController    │ (Producer Handle)
/// └───────────────────────────┘
///              │
///              ▼ (.what)
/// ┌───────────────────────────┐
/// │        WhatSignal         │ (Consumer View, implements What<int>)
/// └───────────────────────────┘
///              │
///              ▼ (Explicit Dependency Manifest via WhatVia)
/// ┌────────────────────────────────────────┐ ┌────────────────────────────────┐
/// │ computed.future((via) {                │ │ computed((via) {               │
/// │   via(refreshTrigger.what);            │ │   final tick = via(sig.what)...│
/// │   return api.fetchUserFeed();          │ │   return 'Event tick #$tick';  │
/// │ });                                    │ │ });                            │
/// └────────────────────────────────────────┘ └────────────────────────────────┘
/// ```
///
/// ## Two Idiomatic Consumption Patterns
///
/// ### Pattern A: Discrete Invalidation / Refetch Trigger (Zero-Data Pulse)
/// When a computation needs to be invalidated or re-evaluated whenever an event occurs,
/// declare the dependency via `via(refreshTrigger.what)`:
/// ```dart
/// final refreshTrigger = WhatSignalController();
///
/// // Declaratively re-evaluates/refetches whenever `refreshTrigger.emit()` is called:
/// final userFeed = computed.future((via) {
///   via(refreshTrigger.what); // Subscribes to discrete event pulse
///   return api.fetchUserFeed();
/// });
/// ```
///
/// ### Pattern B: Explicit Dynamic Read via `WhatVia` (When Tick Count is Needed)
/// When the computation specifically reads or displays the tick sequence number:
/// ```dart
/// final pulseSignal = WhatSignalController();
///
/// final pulseCounter = computed((via) {
///   final tick = via(pulseSignal.what);
///   return 'Event tick #$tick';
/// });
/// ```
///
/// ## Key Capabilities
/// 1. **Zero-Allocation Version Sequence**: Emits internal sequence ticks (`0 -> 1 -> 2 ...`),
///    guaranteeing that downstream `.distinct()` filters will **never drop** or suppress consecutive pulses.
/// 2. **Producer-Consumer Decoupling**: Emitters hold the [WhatSignalController] handle,
///    while consumers only receive read-only [WhatSignal].
/// 3. **100% LPDAG Integration**: Drop-in compatible with [WhatVia], [Effect], and all pipeline transformations.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT expose [WhatSignalController] directly to public UI layers; expose the read-only [WhatSignalController.what] view to prevent arbitrary signal emissions.
/// - Do NOT read signals via `untracked(...)` directly without wrapping in `via(...)`, as untracked reads will miss discrete pulses.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Exposing mutable signal controller handle directly to UI consumers
/// class RefreshService {
///   final refreshSignal = WhatSignalController(); // Callers can invoke emit() uncontrollably!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Encapsulate signal controller and expose read-only WhatSignal
/// class RefreshService {
///   final _refreshSignal = WhatSignalController();
///   WhatSignal get refreshSignal => _refreshSignal.what;
///
///   void refresh() => _refreshSignal.emit();
/// }
/// ```
///
/// ## Examples
/// ```dart
/// final refreshSignal = WhatSignalController();
///
/// final userFeed = computed.future((via) {
///   via(refreshSignal.what); // Dynamically tracks signal pulse
///   return fetchFeed();
/// });
///
/// // Trigger refresh
/// refreshSignal.emit();
/// ```
abstract base class WhatSignal implements What<int> {}

/// Producer controller handle for emitting discrete reactive signals.
///
/// Exposes a read-only [what] consumer view for downstream observation,
/// completely encapsulating emission capabilities.
abstract base class WhatSignalController implements LpdagStatus {
  /// Creates a [WhatSignalController] with optional subscriber lifecycle hooks.
  ///
  /// * [onActivated]: Callback invoked when the signal transitions from 0 to 1 active downstream subscriber.
  /// * [onDeactivated]: Callback invoked when the signal drops to 0 active subscribers.
  factory WhatSignalController({
    void Function()? onActivated,
    void Function()? onDeactivated,
  }) = _WhatSignalControllerImpl;

  /// The encapsulated read-only [WhatSignal] view exposed to downstream consumers.
  WhatSignal get what;

  /// Emits a discrete signal pulse, advancing the internal dirty sequence and notifying downstream observers.
  void emit();

  /// Whether this controller's target signal node is currently observed by downstream subscribers.
  @override
  bool get isActive;
}
