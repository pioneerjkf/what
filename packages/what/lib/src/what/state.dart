// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

/// The universal reactive state protocol in the What framework.
///
/// Implemented by all state-bearing entities:
/// - [WhatController] (and [RawWhatController], imperative state producer)
/// - [WhatSnapshot] (Immutable point-in-time state container)
/// - [RawWhatTerminal] (Reactive consumer sink)
/// - [WhatCoupler] (Dynamic socket relay)
/// - [Computation] (Class-based derivation component)
///
/// Note that [What] itself does not implement [WhatState] directly; instead, it exposes
/// an untracked live view via [WhatUntracked.state] or scoped tracking via [WhatVia.state].
///
/// Guarantees consistent state interrogation ([WhatState.data], [WhatState.hasData], [WhatState.isEmpty],
/// [WhatState.emptyReason], [WhatState.hasError], [WhatState.error], [WhatState.stackTrace]) and declarative pattern
/// matching via [WhatStateMatchExtension].
///
/// ## System Architectural Flow
///
/// ### 1. 3-State Finite State Machine
/// ```text
///                     ┌────────────────────────────────────────┐
///                     │   WhatState<T> 3-State State Machine  │
///                     └────────────────────────────────────────┘
///                            │ (Initial uninitialized / late)
///                            ▼
///                     ┌──────────────┐         Value Resolved        ┌──────────────┐
///                     │    EMPTY     │ ────────────────────────────> │     DATA     │ (hasData == true)
///                     │  (isEmpty)   │ <──────────────────────────── │  (payload:T) │
///                     └──────┬───────┘       .empty([reason])        └──────┬───────┘
///                            │                                              │
///                            │ .setError()                      .setError() │
///                            ▼                                              ▼
///                     ┌─────────────────────────────────────────────────────────────┐
///                     │                            ERROR                            │ (hasError == true)
///                     │              (payload: Object, [StackTrace])                │
///                     └─────────────────────────────────────────────────────────────┘
/// ```
///
/// ### 2. Explicit Dependency Registration vs. Raw Reads
/// ```text
/// [computed / Effect.via Scope]
///             │ (Injected WhatVia parameter)
///             ▼
///      via(sourceWhat)          ──>  [Registers Source Edge & Returns Payload T]
///
/// [Outside Derivation Scope / Raw Read]
///             │
///      untracked(sourceWhat)    ──>  [Pure Direct Field Dereference (Zero Tracking Overhead)]
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero-Overhead Raw Reads & Explicit Tracking**: Reading via [untracked] or [WhatUntracked.state] directly on
///    a node is a pure field dereference with zero tracking overhead and no dynamic tracking stack penalty.
///    Reactive derivations explicitly declare dependencies via the injected [WhatVia] parameter (`via(node)`).
/// 2. **3-State Exclusivity**: A [WhatState] entity is strictly in one of three mutually exclusive states:
///    * **Data** ([WhatState.hasData] == true): Contains a valid payload of type `T` (including `null` for nullable `T?`).
///    * **Empty** ([WhatState.isEmpty] == true): Uninitialized or dormant state with optional [WhatState.emptyReason].
///    * **Error** ([WhatState.hasError] == true): Failure state encapsulating [WhatState.error] and optional [WhatState.stackTrace].
/// 3. **Sound Fail-Fast Extraction**: Reading [WhatState.data] while in Empty or Error state throws [WhatSnapshotExtractionException].
///    Use [WhatState.dataOrNull], [WhatState.dataOrElse], or [WhatStateMatchExtension.match] for safe exhaustive pattern matching.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT read untracked values directly inside a [computed] or `Effect.via` scope without wrapping in `via(...)`,
///   as calling `untracked(node)` performs a pure untracked read.
/// - Do NOT read [WhatState.data] without checking [WhatState.hasData] or handling fallback via [WhatState.dataOrNull] / [WhatState.dataOrElse].
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Reading untracked without via() bypasses dependency registration
/// final badComputed = computed((via) {
///   return untracked(count.what) * 2; // count is NOT tracked!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Explicitly register dependencies through via()
/// final goodComputed = computed((via) {
///   return via(count.what) * 2; // Dynamically and explicitly registered
/// });
/// ```
///
/// ## Examples
/// ```dart
/// final count = WhatController(0);
/// final doubled = computed((via) => via(count.what) * 2);
///
/// print(untracked(doubled)); // 0
/// count.data = 5;
/// print(untracked(doubled)); // 10
/// ```
abstract interface class WhatState<T> {
  /// The underlying snapshot representing this entity's current state.
  WhatSnapshot<T> get snapshot;

  /// Whether this state contains a valid, extractable data payload.
  ///
  /// Note that `null` is a valid data payload for nullable types (`T?`) and does not
  /// indicate an empty state.
  bool get hasData;

  /// Whether this state is in an uninitialized or dormant state.
  bool get isEmpty;

  /// The optional reason explaining why this state is empty, or `null` if unspecified or not empty.
  Object? get emptyReason;

  /// Whether this state is in a corrupted state containing an error or exception.
  bool get hasError;

  /// Extracts the underlying data synchronously from this node or state.
  ///
  /// **Requires:**
  /// * Must be in a [hasData] state.
  ///
  /// **Ensures:**
  /// * Returns the underlying payload of type [T].
  ///
  /// **Throws:**
  /// * [WhatSnapshotExtractionException] if [hasData] is `false` (i.e. [isEmpty] or [hasError] is `true`).
  T get data;

  /// Safely extracts the underlying data, returning `null` if not in a [hasData] state.
  ///
  /// **Ensures:**
  /// * Returns the data payload of type [T] when [hasData] is `true`.
  /// * Returns `null` when [isEmpty] or [hasError] is `true`.
  T? get dataOrNull;

  /// Safely extracts the underlying data, returning the result of [fallback] if not in a [hasData] state.
  ///
  /// * [fallback]: Callback invoked to produce a default value when not in a valid data state.
  ///
  /// **Ensures:**
  /// * Returns the underlying data when [hasData] is `true`.
  /// * Evaluates and returns the result of [fallback] when [isEmpty] or [hasError] is `true`.
  T dataOrElse(T Function() fallback);

  /// Extracts the underlying exception or failure object from an error state.
  ///
  /// **Requires:**
  /// * Must be in a [hasError] state.
  ///
  /// **Ensures:**
  /// * Returns the failure [Object].
  ///
  /// **Throws:**
  /// * [WhatSnapshotStateException] if [hasError] is `false`.
  Object get error;

  /// Extracts the call stack trace at the point of failure from an error state.
  ///
  /// **Requires:**
  /// * Must be in a [hasError] state.
  ///
  /// **Ensures:**
  /// * Returns the associated [StackTrace].
  ///
  /// **Throws:**
  /// * [WhatSnapshotStateException] if [hasError] is `false`.
  StackTrace get stackTrace;

  /// Determines if this state is equivalent to [other] using an optional custom [equals] comparator.
  ///
  /// * [other]: The secondary state contract entity to compare against.
  /// * [equals]: Optional custom equality comparison callback.
  ///
  /// **Ensures:**
  /// * Returns `true` if both entities hold equivalent validity states and payloads.
  bool equals(covariant WhatState<T> other, [bool Function(T previous, T next)? equals]);
}

/// Declarative state pattern matching extension for all [WhatState] implementations
/// (including [WhatSnapshot] and [WhatController]).
extension WhatStateMatchExtension<T> on WhatState<T> {
  /// Exhaustively branches on the three mutually exclusive states of this [WhatState].
  ///
  /// Exactly one of [data], [empty], or [error] will be executed, depending on
  /// the current state. All three branches must be accounted for.
  ///
  /// Unlike [computed] which constructs a new derived [What] node in the reactive DAG,
  /// [match] performs a synchronous, zero-heap evaluation that immediately returns an
  /// arbitrary result value [R] (such as a UI widget or string label) without creating graph edges.
  ///
  /// * [data]: Callback invoked with the payload value when in a valid data state ([hasData] == true).
  /// * [empty]: Callback invoked when in an uninitialized or dormant state ([isEmpty] == true).
  /// * [error]: Callback invoked with the failure object and stack trace when in an error state ([hasError] == true).
  ///
  /// **Ensures:**
  /// * Evaluates exactly one branch synchronously and returns its resulting [R] value.
  ///
  /// **Throws:**
  /// * Throws [StateError] if [data] is omitted when [hasData] is `true`.
  ///
  /// ## Examples
  /// ```dart
  /// final label = state.match(
  ///   data: (value) => 'Value: $value',
  ///   empty: () => 'Loading...',
  ///   error: (err, stack) => 'Error: $err',
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  R match<R>({
    required R Function(T data) data,
    required R Function() empty,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    if (hasData) return data(this.data);
    if (isEmpty) return empty();
    return error(this.error, stackTrace);
  }

  /// Branches on a subset of states, falling back to [orElse] for any unhandled states.
  ///
  /// Any omitted branch ([data], [empty], or [error]) safely delegates to [orElse].
  ///
  /// * [data]: Optional callback invoked with the payload when in a valid data state.
  /// * [empty]: Optional callback invoked when in an empty state.
  /// * [error]: Optional callback invoked when in an error state.
  /// * [orElse]: Fallback callback invoked when the active state does not have a dedicated handler.
  ///
  /// **Ensures:**
  /// * Returns the result of the matching handler, or the result of [orElse] if not matched.
  ///
  /// ## Examples
  /// ```dart
  /// final label = state.matchOrElse(
  ///   data: (value) => 'Value: $value',
  ///   orElse: () => 'Not ready or failed',
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  R matchOrElse<R>({
    R Function(T data)? data,
    R Function()? empty,
    R Function(Object error, StackTrace stackTrace)? error,
    required R Function() orElse,
  }) {
    if (hasData && data != null) return data(this.data);
    if (isEmpty && empty != null) return empty();
    if (hasError && error != null) return error(this.error, stackTrace);
    return orElse();
  }

  /// Branches on a subset of states, returning `null` if the state is unhandled.
  ///
  /// * [data]: Optional callback invoked with the payload when in a valid data state.
  /// * [empty]: Optional callback invoked when in an empty state.
  /// * [error]: Optional callback invoked when in an error state.
  ///
  /// **Ensures:**
  /// * Returns the result of the matching handler, or `null` if the state is not handled.
  ///
  /// ## Examples
  /// ```dart
  /// final value = state.matchOrNull(data: (v) => v); // Returns null if empty or error
  /// ```
  @pragma('vm:prefer-inline')
  R? matchOrNull<R>({
    R Function(T data)? data,
    R Function()? empty,
    R Function(Object error, StackTrace stackTrace)? error,
  }) {
    if (hasData && data != null) return data(this.data);
    if (isEmpty && empty != null) return empty();
    if (hasError && error != null) return error(this.error, stackTrace);
    return null;
  }
}

/// Convenience inspection and filtering methods on an [Iterable] of objects implementing [WhatState].
///
/// Enables fluent queries across collections of stateful entities (such as [WhatController],
/// [RawWhatTerminal], [WhatSnapshot], or [WhatCoupler]).
extension WhatStateCollectionExtension<E extends WhatState<dynamic>> on Iterable<E> {
  /// Returns `true` if every entity in this collection holds a valid data payload ([WhatState.hasData] == `true`).
  @pragma('vm:prefer-inline')
  bool allHaveData() => every((what) => what.hasData);

  /// Returns `true` if at least one entity in this collection is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() => any((what) => what.isEmpty);

  /// Returns `true` if at least one entity in this collection is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() => any((what) => what.hasError);

  /// Filters this collection, returning only the entities holding a valid data payload ([WhatState.hasData] == `true`).
  @pragma('vm:prefer-inline')
  Iterable<E> whereHasData() => where((what) => what.hasData);

  /// Filters this collection, returning only the entities in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  Iterable<E> whereEmpty() => where((what) => what.isEmpty);

  /// Filters this collection, returning only the entities in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  Iterable<E> whereError() => where((what) => what.hasError);
}

// =============================================================================
// WhatState Record Tuple Extensions (Zero Heap Allocation)
// =============================================================================

/// High-performance multi-state inspection and reactive guard extensions on 2-tuples of [WhatState].
///
/// Provides zero-heap inspection methods ([allHaveData], [hasAnyEmpty], [hasAnyError])
/// and precondition gating ([guarded]) across 2 [WhatState] entities.
///
/// ## Why Record Tuples instead of `List`
/// While `[a, b].allHaveData()` allocates a `List` on the heap and executes dynamic
/// iterators, `(a, b).allHaveData()` evaluates on CPU registers and the call stack with
/// zero heap allocations and single-read eager dependency registration.
///
/// ## Unified Guard Pattern Across the Dynamic Triad
/// Record tuples serve as the canonical multi-prerequisite guard for all nodes in the
/// **Dynamic Triad** (`computed`, `switched`, `managed`):
///
/// ```dart
/// // 1. Multi-input calculation (computed)
/// final total = computed(
///   (via) => via(a) + via(b) + via(c),
///   guard: (via) => (via.state(a), via.state(b), via.state(c)).guarded(),
/// );
///
/// // 2. Protected external resource (managed)
/// final client = managed(
///   create: (via) => WebSocketClient(via(url), token: via(token)),
///   dispose: (ws) => ws.close(),
///   guard: (via) => (via.state(url), via.state(token)).guarded('AwaitingAuthCredentials'),
/// );
///
/// // 3. Gated dynamic branch switching (switched)
/// final activeFeed = switched(
///   (via) => via(isVip) ? vipFeed : publicFeed,
///   guard: (via) => (via.state(session), via.state(userProfile)).guarded('AwaitingSession'),
/// );
/// ```
extension WhatStateRecord2Extension on (WhatState, WhatState) {
  /// Returns `true` if all entities in this tuple hold a valid data payload ([WhatState.hasData] == `true`).
  ///
  /// Evaluates across all tuple elements with zero heap allocations and pure field dereferences.
  @pragma('vm:prefer-inline')
  bool allHaveData() {
    final d1 = $1.hasData, d2 = $2.hasData;
    return d1 && d2;
  }

  /// Evaluates across all entities in this tuple, returning [WhatGuard.pass] if all have data,
  /// or [WhatGuard.block] with [reason] if any entity is empty or in error.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);

  /// Returns `true` if at least one entity in this tuple is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() {
    final e1 = $1.isEmpty, e2 = $2.isEmpty;
    return e1 || e2;
  }

  /// Returns `true` if at least one entity in this tuple is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() {
    final err1 = $1.hasError, err2 = $2.hasError;
    return err1 || err2;
  }
}

/// Zero-cost compile-time extensions on 3-tuples of [WhatState].
extension WhatStateRecord3Extension on (WhatState, WhatState, WhatState) {
  /// Returns `true` if all entities in this tuple hold a valid data payload ([WhatState.hasData] == `true`).
  ///
  /// Evaluates across all tuple elements with zero heap allocations and pure field dereferences.
  @pragma('vm:prefer-inline')
  bool allHaveData() {
    final d1 = $1.hasData, d2 = $2.hasData, d3 = $3.hasData;
    return d1 && d2 && d3;
  }

  /// Evaluates across all entities in this tuple, returning [WhatGuard.pass] if all have data,
  /// or [WhatGuard.block] with [reason] if any entity is empty or in error.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);

  /// Returns `true` if at least one entity in this tuple is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() {
    final e1 = $1.isEmpty, e2 = $2.isEmpty, e3 = $3.isEmpty;
    return e1 || e2 || e3;
  }

  /// Returns `true` if at least one entity in this tuple is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() {
    final err1 = $1.hasError, err2 = $2.hasError, err3 = $3.hasError;
    return err1 || err2 || err3;
  }
}

/// Zero-cost compile-time extensions on 4-tuples of [WhatState].
extension WhatStateRecord4Extension on (WhatState, WhatState, WhatState, WhatState) {
  /// Returns `true` if all entities in this tuple hold a valid data payload ([WhatState.hasData] == `true`).
  ///
  /// Evaluates across all tuple elements with zero heap allocations and pure field dereferences.
  @pragma('vm:prefer-inline')
  bool allHaveData() {
    final d1 = $1.hasData, d2 = $2.hasData, d3 = $3.hasData, d4 = $4.hasData;
    return d1 && d2 && d3 && d4;
  }

  /// Evaluates across all entities in this tuple, returning [WhatGuard.pass] if all have data,
  /// or [WhatGuard.block] with [reason] if any entity is empty or in error.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);

  /// Returns `true` if at least one entity in this tuple is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() {
    final e1 = $1.isEmpty, e2 = $2.isEmpty, e3 = $3.isEmpty, e4 = $4.isEmpty;
    return e1 || e2 || e3 || e4;
  }

  /// Returns `true` if at least one entity in this tuple is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() {
    final err1 = $1.hasError, err2 = $2.hasError, err3 = $3.hasError, err4 = $4.hasError;
    return err1 || err2 || err3 || err4;
  }
}

/// Zero-cost compile-time extensions on 5-tuples of [WhatState].
extension WhatStateRecord5Extension on (
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
) {
  /// Returns `true` if all entities in this tuple hold a valid data payload ([WhatState.hasData] == `true`).
  ///
  /// Evaluates across all tuple elements with zero heap allocations and pure field dereferences.
  @pragma('vm:prefer-inline')
  bool allHaveData() {
    final d1 = $1.hasData;
    final d2 = $2.hasData;
    final d3 = $3.hasData;
    final d4 = $4.hasData;
    final d5 = $5.hasData;
    return d1 && d2 && d3 && d4 && d5;
  }

  /// Evaluates across all entities in this tuple, returning [WhatGuard.pass] if all have data,
  /// or [WhatGuard.block] with [reason] if any entity is empty or in error.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);

  /// Returns `true` if at least one entity in this tuple is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() {
    final e1 = $1.isEmpty;
    final e2 = $2.isEmpty;
    final e3 = $3.isEmpty;
    final e4 = $4.isEmpty;
    final e5 = $5.isEmpty;
    return e1 || e2 || e3 || e4 || e5;
  }

  /// Returns `true` if at least one entity in this tuple is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() {
    final err1 = $1.hasError;
    final err2 = $2.hasError;
    final err3 = $3.hasError;
    final err4 = $4.hasError;
    final err5 = $5.hasError;
    return err1 || err2 || err3 || err4 || err5;
  }
}

/// Zero-cost compile-time extensions on 6-tuples of [WhatState].
extension WhatStateRecord6Extension on (
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
) {
  /// Returns `true` if all entities in this tuple hold a valid data payload ([WhatState.hasData] == `true`).
  @pragma('vm:prefer-inline')
  bool allHaveData() {
    final d1 = $1.hasData;
    final d2 = $2.hasData;
    final d3 = $3.hasData;
    final d4 = $4.hasData;
    final d5 = $5.hasData;
    final d6 = $6.hasData;
    return d1 && d2 && d3 && d4 && d5 && d6;
  }

  /// Evaluates across all entities in this tuple, returning [WhatGuard.pass] if all have data,
  /// or [WhatGuard.block] with [reason] if any entity is empty or in error.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);

  /// Returns `true` if at least one entity in this tuple is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() {
    final e1 = $1.isEmpty;
    final e2 = $2.isEmpty;
    final e3 = $3.isEmpty;
    final e4 = $4.isEmpty;
    final e5 = $5.isEmpty;
    final e6 = $6.isEmpty;
    return e1 || e2 || e3 || e4 || e5 || e6;
  }

  /// Returns `true` if at least one entity in this tuple is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() {
    final err1 = $1.hasError;
    final err2 = $2.hasError;
    final err3 = $3.hasError;
    final err4 = $4.hasError;
    final err5 = $5.hasError;
    final err6 = $6.hasError;
    return err1 || err2 || err3 || err4 || err5 || err6;
  }
}

/// Zero-cost compile-time extensions on 7-tuples of [WhatState].
extension WhatStateRecord7Extension on (
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
) {
  /// Returns `true` if all entities in this tuple hold a valid data payload ([WhatState.hasData] == `true`).
  @pragma('vm:prefer-inline')
  bool allHaveData() {
    final d1 = $1.hasData;
    final d2 = $2.hasData;
    final d3 = $3.hasData;
    final d4 = $4.hasData;
    final d5 = $5.hasData;
    final d6 = $6.hasData;
    final d7 = $7.hasData;
    return d1 && d2 && d3 && d4 && d5 && d6 && d7;
  }

  /// Evaluates across all entities in this tuple, returning [WhatGuard.pass] if all have data,
  /// or [WhatGuard.block] with [reason] if any entity is empty or in error.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);

  /// Returns `true` if at least one entity in this tuple is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() {
    final e1 = $1.isEmpty;
    final e2 = $2.isEmpty;
    final e3 = $3.isEmpty;
    final e4 = $4.isEmpty;
    final e5 = $5.isEmpty;
    final e6 = $6.isEmpty;
    final e7 = $7.isEmpty;
    return e1 || e2 || e3 || e4 || e5 || e6 || e7;
  }

  /// Returns `true` if at least one entity in this tuple is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() {
    final err1 = $1.hasError;
    final err2 = $2.hasError;
    final err3 = $3.hasError;
    final err4 = $4.hasError;
    final err5 = $5.hasError;
    final err6 = $6.hasError;
    final err7 = $7.hasError;
    return err1 || err2 || err3 || err4 || err5 || err6 || err7;
  }
}

/// Zero-cost compile-time extensions on 8-tuples of [WhatState].
extension WhatStateRecord8Extension on (
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
) {
  /// Returns `true` if all entities in this tuple hold a valid data payload ([WhatState.hasData] == `true`).
  @pragma('vm:prefer-inline')
  bool allHaveData() {
    final d1 = $1.hasData;
    final d2 = $2.hasData;
    final d3 = $3.hasData;
    final d4 = $4.hasData;
    final d5 = $5.hasData;
    final d6 = $6.hasData;
    final d7 = $7.hasData;
    final d8 = $8.hasData;
    return d1 && d2 && d3 && d4 && d5 && d6 && d7 && d8;
  }

  /// Evaluates across all entities in this tuple, returning [WhatGuard.pass] if all have data,
  /// or [WhatGuard.block] with [reason] if any entity is empty or in error.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);

  /// Returns `true` if at least one entity in this tuple is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() {
    final e1 = $1.isEmpty;
    final e2 = $2.isEmpty;
    final e3 = $3.isEmpty;
    final e4 = $4.isEmpty;
    final e5 = $5.isEmpty;
    final e6 = $6.isEmpty;
    final e7 = $7.isEmpty;
    final e8 = $8.isEmpty;
    return e1 || e2 || e3 || e4 || e5 || e6 || e7 || e8;
  }

  /// Returns `true` if at least one entity in this tuple is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() {
    final err1 = $1.hasError;
    final err2 = $2.hasError;
    final err3 = $3.hasError;
    final err4 = $4.hasError;
    final err5 = $5.hasError;
    final err6 = $6.hasError;
    final err7 = $7.hasError;
    final err8 = $8.hasError;
    return err1 || err2 || err3 || err4 || err5 || err6 || err7 || err8;
  }
}

/// Zero-cost compile-time extensions on 9-tuples of [WhatState].
extension WhatStateRecord9Extension on (
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
  WhatState,
) {
  /// Returns `true` if all entities in this tuple hold a valid data payload ([WhatState.hasData] == `true`).
  @pragma('vm:prefer-inline')
  bool allHaveData() {
    final d1 = $1.hasData;
    final d2 = $2.hasData;
    final d3 = $3.hasData;
    final d4 = $4.hasData;
    final d5 = $5.hasData;
    final d6 = $6.hasData;
    final d7 = $7.hasData;
    final d8 = $8.hasData;
    final d9 = $9.hasData;
    return d1 && d2 && d3 && d4 && d5 && d6 && d7 && d8 && d9;
  }

  /// Evaluates across all entities in this tuple, returning [WhatGuard.pass] if all have data,
  /// or [WhatGuard.block] with [reason] if any entity is empty or in error.
  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) => allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);

  /// Returns `true` if at least one entity in this tuple is in an empty state ([WhatState.isEmpty] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyEmpty() {
    final e1 = $1.isEmpty;
    final e2 = $2.isEmpty;
    final e3 = $3.isEmpty;
    final e4 = $4.isEmpty;
    final e5 = $5.isEmpty;
    final e6 = $6.isEmpty;
    final e7 = $7.isEmpty;
    final e8 = $8.isEmpty;
    final e9 = $9.isEmpty;
    return e1 || e2 || e3 || e4 || e5 || e6 || e7 || e8 || e9;
  }

  /// Returns `true` if at least one entity in this tuple is in an error state ([WhatState.hasError] == `true`).
  @pragma('vm:prefer-inline')
  bool hasAnyError() {
    final err1 = $1.hasError;
    final err2 = $2.hasError;
    final err3 = $3.hasError;
    final err4 = $4.hasError;
    final err5 = $5.hasError;
    final err6 = $6.hasError;
    final err7 = $7.hasError;
    final err8 = $8.hasError;
    final err9 = $9.hasError;
    return err1 || err2 || err3 || err4 || err5 || err6 || err7 || err8 || err9;
  }
}
