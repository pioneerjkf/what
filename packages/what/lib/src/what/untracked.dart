// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Untracked Raw Read Accessor (WhatUntracked & untracked)
// =============================================================================

/// The untracked raw-read accessor interface for the What reactive DAG engine.
///
/// Under the **Explicit Dependency Manifest** architecture, reactive nodes ([What])
/// are opaque DAG handles that do not expose direct value getters on their public
/// instance surface.
///
/// [WhatUntracked] serves as the explicit gateway for untracked, zero-overhead
/// raw reads outside reactive tracking scopes (or inside derivations when a dependency
/// should intentionally not be tracked).
///
/// ## System Architectural Symmetry
/// ```text
/// ┌──────────────────────────────────────┬──────────────────────────────────────┐
/// │   Tracked Access (Scoped WhatVia)    │  Untracked Access (Global Functor)   │
/// ├──────────────────────────────────────┼──────────────────────────────────────┤
/// │ via(node)           (Tracks + Data)  │ untracked(node)      (No-op + Data)  │
/// │ via.state(node)     (Tracks + State) │ untracked.state(node)(No-op + State) │
/// └──────────────────────────────────────┴──────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero Tracking Overhead**: Reading via [untracked] executes a direct field dereference
///    without querying or mutating ambient scope stacks.
/// 2. **AI & Linter Determinism**: By eliminating getter properties on [What], AI coding
///    assistants and developers cannot inadvertently introduce "silent unreactivity" bugs
///    by accessing values without explicit routing.
/// 3. **Fail-Fast Extraction**: Reading [untracked] on a node in Empty or Error state throws
///    [WhatSnapshotExtractionException], preserving fail-fast safety.
///
/// ## Examples
/// ```dart
/// final counter = WhatController(0);
/// final doubled = computed((via) => via(counter.what) * 2);
///
/// // 1. Imperative untracked read in tests / event handlers:
/// print(untracked(doubled)); // 0
///
/// // 2. Untracked state inspection:
/// final state = untracked.state(counter.what);
/// if (state.hasData) {
///   print('Data: ${state.data}');
/// }
/// ```
abstract interface class WhatUntracked {
  /// Reads the current value of [what] untracked.
  ///
  /// Throws [WhatSnapshotExtractionException] if the node is in Empty or Error state (Fail-Fast).
  ///
  /// * [what]: The reactive node to read untracked.
  T call<T>(What<T> what);

  /// Returns an untracked live view of the node's 3-phase [WhatState].
  ///
  /// In practice, returns the node itself (`what`) with zero allocation.
  /// To preserve an immutable snapshot at this point in time, access `.snapshot`.
  ///
  /// * [what]: The reactive node to inspect untracked.
  WhatState<T> state<T>(What<T> what);
}

/// Global untracked accessor singleton.
///
/// Use this functor to read reactive nodes without registering dependency edges.
const WhatUntracked untracked = _WhatUntrackedImpl();
