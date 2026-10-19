// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// LPDAG Lifecycle Status Contract
// =============================================================================

/// A status interface representing the current lifecycle state of an LPDAG node.
///
/// Provides a read-only view into the reactive lifecycle state of any node in the
/// topological graph. The What framework operates on a lazy, consumer-driven activation model:
/// nodes are activated lazily when a downstream terminal connects and demands data, and are
/// deactivated when the last consumer disconnects. This interface allows developers and tools
/// to safely observe these transitions without exposing mutable state.
///
/// ## System Architectural Flow
/// ```text
/// [Terminal / Downstream Consumer]
///        │ (activate() / 0 -> 1 subscribers)
///        ▼
/// [LpdagStatus.isActive == true] (Allocates resources / listens to streams)
///        │ (deactivate() / 1 -> 0 subscribers)
///        ▼
/// [LpdagStatus.isActive == false] (Disposes resources / enters dormant state)
/// ```
///
/// ## Architectural Benefits
/// 1. **Lazy Consumer-Driven Activation**: Subscriptions, timers, and heavy resources are
///    instantiated only when demanded by active downstream terminals.
/// 2. **Observable Zero-Cost Boundary**: Exposes read-only lifecycle status without mutation risks.
/// 3. **Leak-Free Dormancy**: Guarantees that unobserved nodes release active subscriptions cleanly.
///
/// ## Examples
/// ```dart
/// final counter = WhatController(0);
/// print(counter.what.isActive); // false (no downstream terminals yet)
///
/// final terminal = RawWhatTerminal(
///   counter.what,
///   onInvalidated: () {},
/// );
///
/// terminal.activate();
/// print(counter.what.isActive); // true
/// print(terminal.isActive);     // true
///
/// terminal.deactivate();
/// print(counter.what.isActive); // false
/// ```
abstract interface class LpdagStatus {
  /// Whether the node is currently active (connected to a downstream terminal).
  ///
  /// **Ensures:**
  /// * Returns `true` if connected to at least one downstream consumer.
  bool get isActive;
}
