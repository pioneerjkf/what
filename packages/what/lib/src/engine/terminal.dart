// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Reactive Terminals & Sinks
// =============================================================================

/// Public contract defining the reactive lifecycle controls of a terminal sink.
///
/// Serves as the unified interface for all What reactive terminals
/// ([RawWhatTerminal], [RawViaTerminal], [RawComputedTerminal]).
///
/// The terminal sink represents the ultimate consumer at the boundary between
/// declarative reactive topology and imperative UI/framework environments.
/// Activation and deactivation commands originate from the terminal and propagate
/// through the DAG all the way to root sources.
///
/// ## System Architectural Flow
/// ```text
/// [External Consumer / UI Framework (e.g. Flutter Element)]
///                    │
///                    ├─► .activate()   ──► Propagates upstream (0 -> 1: allocates / listens)
///                    ├─► .deactivate() ──► Propagates upstream (1 -> 0: deallocates / dormant)
///                    └─► Invalidation  <── Upstream dirty pulses trigger onInvalidated
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Unified Terminal Boundary**: Common polymorphic interface for all reactive sinks.
/// 2. **Lazy Upstream Handshake**: Activation commands propagate upstream on-demand to root sources.
/// 3. **Hot-Reload Reassembly Hook**: [debugForceInvalidate] recursively flushes intermediate caches.
abstract interface class RawTerminal implements LpdagStatus {
  /// Activates the terminal, signaling upstream nodes to attach listeners and allocate resources.
  ///
  /// **Ensures:**
  /// * Transitions this terminal to active state ([isActive] == true).
  /// * Triggers upstream activation handshakes across the reactive DAG.
  void activate();

  /// Deactivates the terminal, detaching from upstream sources and releasing resources.
  ///
  /// **Ensures:**
  /// * Transitions this terminal to inactive state ([isActive] == false).
  /// * Triggers upstream deactivation handshakes if no other downstream consumers remain.
  void deactivate();

  /// Debug & Hot-Reload hook that recursively invalidates upstream intermediate caches
  /// and bumps root dirty versions to force fresh recomputations across the DAG.
  ///
  /// Intended to be invoked inside Flutter Element's `reassemble()` hook during
  /// development Hot Reload cycles.
  void debugForceInvalidate();
}

// =============================================================================
// RawViaTerminal (N-ary Explicit Reactive Evaluator via WhatVia)
// =============================================================================

/// A reactive terminal that executes a compute callback with an injected [WhatVia]
/// explicit dependency manifest handle using Zero-Allocation Epoch Diffing.
///
/// Dependencies are explicitly registered when passed to `via(node)` during evaluation.
///
/// ## System Architectural Flow
/// ```text
/// [terminal.evaluate()]
///        │
///        ├─► 1. Increment epoch counter (++_epoch)
///        ├─► 2. Execute evaluator(via)
///        │         │
///        │         └─► via(node) registers dependency edge with current epoch
///        │
///        └─► 3. _endEpoch(currentEpoch, commitVersions: true) -> 1-pass: detaches unused dependencies & commits versions
/// ```
///
/// ## Architectural Benefits
/// 1. **Dynamic Branching**: Automatically adapts dependency edges across conditional branches.
/// 2. **Zero-Allocation Epoch Diffing**: Sweeps obsolete edges in a single pass without allocating diff sets.
/// 3. **AI Ground Truth**: Explicit `via(...)` tracking prevents missed dependencies.
///
/// ## Examples
/// ```dart
/// final firstName = WhatController('Jane');
/// final lastName = WhatController('Doe');
///
/// final terminal = RawViaTerminal(
///   (via) => '${via(firstName.what)} ${via(lastName.what)}',
///   onInvalidated: () {
///     print('Names changed, need re-evaluation!');
///   },
/// );
///
/// terminal.activate();
/// print(terminal.evaluate()); // 'Jane Doe'
///
/// firstName.data = 'John';    // Prints: Names changed, need re-evaluation!
/// print(terminal.evaluate()); // 'John Doe'
///
/// terminal.deactivate();
/// ```
base class RawViaTerminal<T> extends _RawTerminal with _NaryEdgeMixin<_Node>, _WhatViaEpochMixin, _ViaTerminalMixin<T> {
  /// Creates a synchronous [RawViaTerminal] with the given evaluator and invalidation listener.
  ///
  /// * [evaluator]: The computation closure receiving an injected [WhatVia] dependency tracker.
  /// * [onInvalidated]: Callback invoked synchronously when any observed upstream dependency mutates.
  /// * [onUncaughtError]: Optional error recovery handler for unhandled pull or evaluation exceptions.
  ///
  /// **Requires:**
  /// * [onInvalidated] must be a non-null callback scheduling downstream reaction.
  RawViaTerminal(
    T Function(WhatVia via) evaluator, {
    required super.onInvalidated,
    super.onUncaughtError,
  }) {
    _evaluator = evaluator;
  }
}

// =============================================================================
// RawComputedTerminal (N-ary Explicit Reactive Computed Terminal via WhatVia)
// =============================================================================

/// A reactive terminal that combines dynamic [WhatVia] dependency tracking with
/// on-demand lazy state resolution, caching, and dirty short-circuiting.
///
/// Unlike passive 1:1 terminals or stateless evaluators, [RawComputedTerminal] acts as
/// an engineered **1-hop leaf computed node**:
/// * State is resolved lazily on-demand when accessed via [data], [snapshot], etc.
/// * Uninvalidated subsequent reads return cached results with zero computation (0-Compute).
/// * Push-Dirty invalidations directly invoke `onInvalidated` in a single hop.
///
/// ## System Architectural Flow
/// ```text
/// [Upstream Nodes Mutate]
///           │ (Push-Dirty Invalidation Wave)
///           ▼
/// [RawComputedTerminal] ──► onInvalidated() (1-Hop Notification)
///           │
///           ▼ (External read: terminal.data / terminal.snapshot)
/// [Lazy-Pull Evaluation]
///           ├─► If clean: returns cached state in O(1) (0-Compute)
///           └─► If dirty: re-evaluates via(node) and updates cache
/// ```
///
/// ## Architectural Benefits
/// 1. **1-Hop Invalidation Latency**: Bypasses intermediate relay layers, delivering dirty pulses directly to UI.
/// 2. **Cached Zero-Compute Reads**: Subsequent reads while clean incur zero recalculation overhead.
/// 3. **Short-Circuiting Protection**: Propagates Empty or Error states without crashing formulas.
///
/// ## Examples
/// ```dart
/// final price = WhatController(100);
/// final quantity = WhatController(2);
///
/// final totalTerminal = RawComputedTerminal(
///   (via) => via(price.what) * via(quantity.what),
///   onInvalidated: () {
///     // Schedule Flutter Element rebuild or UI redraw
///   },
/// );
///
/// totalTerminal.activate();
/// print(totalTerminal.data); // 200 (computed & cached)
/// print(totalTerminal.data); // 200 (0-Compute, returned from cache)
///
/// price.data = 150;          // Marks terminal check/dirty and invokes onInvalidated
/// print(totalTerminal.data); // 300 (lazily recomputed on read)
///
/// totalTerminal.deactivate();
/// ```
base class RawComputedTerminal<T> extends _RawTerminal
    with _NaryEdgeMixin<_Node>, _WhatViaEpochMixin, _WhatStateMixin<T>, _PullResolver<T>, _ComputedPullMixin<T> {
  /// Creates a [RawComputedTerminal] with the given compute callback and invalidation listener.
  ///
  /// * [_compute]: The computation closure receiving an injected [WhatVia] dependency tracker.
  /// * [onInvalidated]: Callback invoked synchronously when any observed upstream dependency mutates.
  /// * [onUncaughtError]: Optional error recovery handler for unhandled pull or evaluation exceptions.
  /// * [guard]: Optional reactive guard isolating precondition checks.
  RawComputedTerminal(
    this._compute, {
    required super.onInvalidated,
    super.onUncaughtError,
    WhatGuard Function(WhatVia via)? guard,
  }) : _guard = guard;

  @override
  final T Function(WhatVia via) _compute;

  @override
  final WhatGuard Function(WhatVia via)? _guard;

  @override
  void _invalidateInScope() {
    if (_dirtyState == _DirtyState.clean) {
      _dirtyState = _DirtyState.check;
    }
    super._invalidateInScope();
  }

  /// Manually marks this terminal as dirty without resolving immediately,
  /// ensuring that the next read (e.g. Flutter build) will re-evaluate.
  ///
  /// **Ensures:**
  /// * Transitions internal dirty state to dirty.
  @pragma('vm:prefer-inline')
  void markDirty() {
    _dirtyState = _DirtyState.dirty;
  }

  @override
  void debugForceInvalidate() {
    assert(() {
      _dirtyState = _DirtyState.dirty;
      _state = null;
      return true;
    }());
    super.debugForceInvalidate();
  }
}

// =============================================================================
// RawWhatTerminal (1:1 What Reactive Sink & Low-Level Passive Gateway)
// =============================================================================

/// A concrete low-level reactive terminal designed specifically for 1:1 [What] pipelines.
///
/// It acts as a **Zero-Copy Auto-Healing Gateway** bridging What's 2-Phase LPDAG
/// (Push-Dirty / Lazy-Pull) topology to external framework schedulers (e.g. Flutter's
/// `Element.markNeedsBuild()`, state rebuilds, or unit test callbacks).
///
/// Unlike intermediate transform nodes (`computed`) which cache derived values,
/// [RawWhatTerminal] never shadows or copies state (`_read() => _source._read()`).
/// This guarantees zero heap allocation and eliminates cache desynchronization.
///
/// ## Architectural Role: Pure Synchronous Raw Gateway
/// Dispatches invalidation pulses **synchronously** to `onInvalidated` via
/// [_PushScope] without scheduling delay. Multiple mutations occurring within the same
/// push wave or batch ([batch]) are coalesced into a single synchronous dispatch.
///
/// For asynchronous microtask-coalesced observations and side-effects, use [Effect]
/// (e.g. `node.effect(() => ...).run()`).
///
/// ## Data Flow
/// ```text
/// [Upstream What<T>]
///        │ (Push-Dirty when state mutates)
///        ▼
/// [RawWhatTerminal<T>] ──► Invokes onInvalidated callback (Synchronous batch flush)
///        │ (Pull-Data on evaluate/read: Zero-Copy SSOT)
///        ▼
/// External Consumer (e.g. Flutter Widget setState / Element markNeedsBuild)
///        │
/// Reads terminal.data / terminal.snapshot (O(1) synchronous read from source)
/// ```
///
/// ## Architectural Benefits
/// 1. **Zero-Copy SSOT Pass-Through**: Reads delegate directly to upstream source with zero heap caching.
/// 2. **Synchronous Invalidation Dispatch**: No microtask latency for UI frame scheduling.
/// 3. **Dynamic Source Swapping**: Supports [swapSource] without reallocating terminal handles.
///
/// **Warning (Anti-Pattern Prevention):**
/// - **DO NOT** perform heavy synchronous calculations or state evaluations inside `onInvalidated`.
///   `onInvalidated` should ONLY schedule a frame, task, or state rebuild, preserving lazy evaluation.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Performing synchronous payload processing inside onInvalidated
/// final term = RawWhatTerminal(counter.what, onInvalidated: () {
///   final data = counter.what.peek; // Forces premature pull during push-dirty wave!
///   heavyRender(data);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Only schedule a deferred frame or UI rebuild in onInvalidated
/// final term = RawWhatTerminal(counter.what, onInvalidated: () {
///   element.markNeedsBuild(); // Schedules Flutter build pass for lazy-pull
/// });
/// ```
///
/// ## Examples
/// ```dart
/// final counter = WhatController(0);
///
/// final terminal = RawWhatTerminal(
///   counter.what,
///   onInvalidated: () {
///     print('State updated: schedule rebuild');
///   },
/// );
///
/// terminal.activate();
/// print(terminal.data); // 0 (direct read from source)
///
/// counter.data = 42;    // Synchronously triggers onInvalidated
/// print(terminal.data); // 42
///
/// terminal.deactivate();
/// ```
base class RawWhatTerminal<T> extends _RawTerminal
    with _UnaryEdgeMixin<What<T>>, _WhatStateMixin<T>, _WhatTerminalMixin<T>
    implements WhatState<T> {
  /// Creates a synchronous [RawWhatTerminal] listening to [source].
  ///
  /// * [source]: The upstream [What<T>] node to observe.
  /// * [onInvalidated]: Callback invoked synchronously when [source] mutates.
  /// * [onUncaughtError]: Optional error recovery handler for uncaught exceptions.
  ///
  /// **Requires:**
  /// * [source] must be a valid [What<T>] node.
  /// * [onInvalidated] must be a non-null callback scheduling downstream reaction.
  RawWhatTerminal(
    What<T> source, {
    required super.onInvalidated,
    super.onUncaughtError,
  }) {
    _source = source;
    _pulledVersion = source._version;
  }

  /// The upstream [What] currently observed by this terminal.
  What<T> get source => _source;

  /// Dynamically swaps the upstream source node without reallocating the terminal.
  ///
  /// * [newSource]: The new [What<T>] node to observe.
  ///
  /// **Ensures:**
  /// * Re-links target edge to [newSource] if the terminal is currently active.
  /// * Synchronizes pulled version with [newSource].
  void swapSource(What<T> newSource) {
    if (identical(_source, newSource)) return;
    if (_lifecycle.isActive) {
      _source._detachTargetEdgeOptimistically(this);
      _source = newSource;
      _source._attachTargetEdgeOptimistically(this);
      _pulledVersion = _source._version;
    } else {
      _source = newSource;
      _pulledVersion = newSource._version;
    }
  }
}
