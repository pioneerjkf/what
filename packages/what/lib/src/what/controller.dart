// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// WhatController<T> & RawWhatController<T> Imperative Producers (Has-a)
// =============================================================================

/// Imperative producer controller managing state mutations into the What reactive DAG.
///
/// Under the strict **Producer/Consumer Separation (Has-a)** architecture:
/// - [WhatController<T>] owns and encapsulates an internal physical reactive DAG entry node.
/// - It does **NOT** implement [What<T>], completely preventing mutation methods from being
///   inadvertently invoked by consumers that only receive the read-only [what] view.
/// - Downcasting a [What<T>] instance back to [WhatController<T>] will fail with a [TypeError],
///   ensuring compile-time and runtime encapsulation of state producers.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────┐
/// │                     Store / Service                    │
/// │                                                        │
/// │   final _count = WhatController<int>(0); // Producer   │
/// │   What<int> get count => _count.what;    // Consumer   │
/// └────────────────────────────────────────────────────────┘
///              │                                 │
///              ▼ (.data = 1 / .set(1))           ▼ (.peek / via(count))
/// ┌──────────────────────────┐     ┌──────────────────────────┐
/// │   WhatController<int>    │ ──> │        What<int>         │
/// └──────────────────────────┘     └──────────────────────────┘
///   (Encapsulated Producer)           (Read-Only DAG Node View)
///                                                │
///                                                ▼ (Push-Dirty / Lazy-Pull)
///                                     [Downstream Derivations]
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Has-a Producer Encapsulation**: A state container does not mix producer and consumer APIs.
///    Mutations can only be initiated by the component owning the [WhatController] handle.
/// 2. **Built-In Distinct Filtering**: By default, [WhatController] suppresses dirty notifications
///    when consecutive assignments match the previous payload, preventing downstream cascade recomputations.
/// 3. **Subscriber-Driven Inactive Dormancy**: Lifecycle hooks (`onActivated`, `onDeactivated`)
///    fire synchronously as downstream consumers connect or disconnect, enabling automated resource pause.
/// 4. **Deterministic 3-State FSM Control**: Supports full 3-state lifecycle transitions
///    ([set], [empty], [setError]) with optional causal attribution reasons (`reason`).
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT expose [WhatController] directly through public getters or widget constructor parameters.
///   Always expose the read-only [what] getter to preserve mutation encapsulation.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Exposing mutable controller handle directly to UI consumers
/// class CounterStore {
///   final count = WhatController(0); // Callers can invoke count.set() arbitrarily!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Encapsulate producer handle and expose read-only What view
/// class CounterStore {
///   final _count = WhatController(0);
///   What<int> get count => _count.what; // Read-only consumer view
///
///   void increment() => _count.data++;
/// }
/// ```
///
/// ## Examples
/// ```dart
/// final counter = WhatController<int>(0);
/// final countView = counter.what;
///
/// print(countView.peek); // 0
/// counter.set(10);
/// print(countView.peek); // 10
/// ```
abstract base class WhatController<T> implements WhatState<T> {
  /// Creates a distinct-filtered [WhatController] initialized with [data].
  ///
  /// Filters out duplicate consecutive value assignments using [equals] (or identical / operator ==)
  /// to suppress redundant downstream dirty pulses.
  ///
  /// * [data]: The initial value to populate the node with.
  /// * [distinct]: When `true`, suppresses dirty notifications on identical values. Defaults to `true`.
  /// * [equals]: Custom equality comparator used when [distinct] is `true`.
  /// * [onActivated]: Callback triggered when the first downstream subscriber connects.
  /// * [onDeactivated]: Callback triggered when all downstream subscribers disconnect.
  /// * [graceful]: Optional [Graceful] policy delaying deactivation when subscribers drop to zero.
  ///
  /// **Ensures:**
  /// * Returns an active [WhatController<T>] in the Data state ([hasData] == true).
  ///
  /// ## Examples
  /// ```dart
  /// final controller = WhatController<int>(
  ///   0,
  ///   onActivated: () => print('Subscribed'),
  ///   onDeactivated: () => print('Dormant'),
  /// );
  /// ```
  factory WhatController(
    T data, {
    bool distinct,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) = _WhatControllerImpl<T>;

  /// Creates a distinct-filtered [WhatController] in an uninitialized (Empty) state.
  ///
  /// Useful for asynchronous resources or data fetched after initialization. Reading `.data`
  /// before setting a value throws [WhatSnapshotExtractionException].
  ///
  /// * [reason]: Optional reason explaining why this controller is uninitialized or empty.
  /// * [distinct]: When `true`, suppresses dirty notifications on identical values. Defaults to `true`.
  /// * [equals]: Custom equality comparator used when [distinct] is `true`.
  /// * [onActivated]: Callback triggered when the first downstream subscriber connects.
  /// * [onDeactivated]: Callback triggered when all downstream subscribers disconnect.
  /// * [graceful]: Optional [Graceful] policy delaying deactivation when subscribers drop to zero.
  ///
  /// **Ensures:**
  /// * Returns a [WhatController<T>] initialized in the Empty state ([isEmpty] == true).
  ///
  /// ## Examples
  /// ```dart
  /// final userController = WhatController<User>.late(reason: 'AwaitingLogin');
  /// print(userController.isEmpty); // true
  /// print(userController.emptyReason); // 'AwaitingLogin'
  /// ```
  factory WhatController.late({
    Object? reason,
    bool distinct,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) = _WhatControllerImpl<T>.late;

  /// Creates a distinct-filtered [WhatController] initialized in an Error state.
  ///
  /// * [error]: The initial exception or error payload.
  /// * [stackTrace]: Optional stack trace associated with the failure.
  /// * [distinct]: When `true`, suppresses dirty notifications on identical values. Defaults to `true`.
  /// * [equals]: Custom equality comparator used when [distinct] is `true`.
  /// * [onActivated]: Callback triggered when the first downstream subscriber connects.
  /// * [onDeactivated]: Callback triggered when all downstream subscribers disconnect.
  /// * [graceful]: Optional [Graceful] policy delaying deactivation when subscribers drop to zero.
  ///
  /// **Ensures:**
  /// * Returns a [WhatController<T>] initialized in the Error state ([hasError] == true).
  ///
  /// ## Examples
  /// ```dart
  /// final controller = WhatController<String>.error(Exception('Failed to load'));
  /// print(controller.hasError); // true
  /// ```
  factory WhatController.error(
    Object error, {
    StackTrace? stackTrace,
    bool distinct,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) = _WhatControllerImpl<T>.error;

  /// The encapsulated read-only reactive node view exposed to downstream consumers.
  ///
  /// Downstream derivations and UI widgets should observe this view rather than the controller.
  What<T> get what;

  /// Injects [data] into the pipeline via property assignment.
  ///
  /// Shorthand alias for [set]. Propagates dirty invalidation pulses downstream if [data]
  /// differs from the existing payload (or if `distinct` is false).
  ///
  /// **Ensures:**
  /// * Transitions this node to the Data state ([hasData] == true) with payload [data].
  set data(T data);

  /// Injects [data] into the pipeline, propagating dirty signals downstream.
  ///
  /// * [data]: The new payload to store and propagate.
  ///
  /// **Ensures:**
  /// * Transitions this node to the Data state ([hasData] == true).
  void set(T data);

  /// Safely executes [test] and injects the returned payload or catches thrown exceptions.
  ///
  /// If [test] executes successfully, the returned value is injected via [set].
  /// If [test] throws an exception, it is caught and transitioned to Error state via [setError].
  ///
  /// * [test]: Synchronous closure returning a new [T] payload or throwing an error.
  ///
  /// **Ensures:**
  /// * On success: Transitions to Data state with the result of [test].
  /// * On exception: Transitions to Error state with the caught error and stack trace.
  ///
  /// ## Examples
  /// ```dart
  /// controller.setGuarded(() => int.parse(rawText));
  /// ```
  void setGuarded(T Function() test);

  /// Injects an error state into the pipeline with optional [stackTrace].
  ///
  /// * [error]: The error or exception object to store.
  /// * [stackTrace]: Optional stack trace associated with the error.
  ///
  /// **Ensures:**
  /// * Transitions this node to the Error state ([hasError] == true).
  void setError(Object error, [StackTrace? stackTrace]);

  /// Injects an empty (uninitialized) state into the pipeline, clearing the current value.
  ///
  /// * [reason]: Optional reason explaining why this state is now empty.
  ///
  /// **Ensures:**
  /// * Transitions this node to the Empty state ([isEmpty] == true).
  void empty([Object? reason]);

  /// Whether this controller's target node is currently observed by downstream subscribers.
  ///
  /// Returns `true` if at least one active terminal or derivation is subscribed to [what].
  bool get isActive;
}

/// Raw unfiltered producer controller bypassing distinct checks and supporting manual [markDirty].
///
/// Engineered for high-throughput mutation sequences, mutable in-place data structures, or
/// performance-critical scenarios where equality checks incur non-trivial overhead.
///
/// ## System Architectural Flow
/// ```text
/// [In-Place Mutation: list.add(item)] ──> controller.markDirty() ──> [Push-Dirty Pulse]
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero Equality Overhead**: Bypasses distinct checks entirely, propagating dirty signals unconditionally.
/// 2. **Manual Dirty Notification**: Allows explicit invalidation for in-place modifications where the
///    reference identity remains unchanged.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT use [RawWhatController] for primitive immutable values (e.g. `int`, `String`) where distinct
///   checks prevent wasteful downstream UI rebuilds. Use standard [WhatController] instead.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Using RawWhatController for immutable primitives wastes distinct suppression
/// final count = RawWhatController(0);
/// count.data = 0; // Triggers redundant downstream rebuilds even when value is unchanged!
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Use RawWhatController for in-place mutable collections with manual markDirty
/// final items = RawWhatController<List<String>>(['initial']);
/// items.data.add('new item');
/// items.markDirty(); // Explicitly notifies downstream subscribers of in-place mutation
/// ```
///
/// ## Examples
/// ```dart
/// final listController = RawWhatController<List<int>>([1, 2, 3]);
/// listController.data.add(4);
/// listController.markDirty(); // Explicitly notify downstream subscribers
/// ```
abstract base class RawWhatController<T> implements WhatController<T> {
  /// Creates an unfiltered [RawWhatController] initialized with [data].
  ///
  /// * [data]: The initial value to populate the node with.
  /// * [onActivated]: Callback triggered when the first downstream subscriber connects.
  /// * [onDeactivated]: Callback triggered when all downstream subscribers disconnect.
  /// * [graceful]: Optional [Graceful] policy delaying deactivation when subscribers drop to zero.
  ///
  /// **Ensures:**
  /// * Returns an unfiltered [RawWhatController<T>] in the Data state ([hasData] == true).
  factory RawWhatController(
    T data, {
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) = _RawWhatControllerImpl<T>;

  /// Creates an unfiltered [RawWhatController] in an uninitialized (Empty) state.
  ///
  /// * [reason]: Optional reason explaining why this controller is uninitialized or empty.
  /// * [onActivated]: Callback triggered when the first downstream subscriber connects.
  /// * [onDeactivated]: Callback triggered when all downstream subscribers disconnect.
  /// * [graceful]: Optional [Graceful] policy delaying deactivation when subscribers drop to zero.
  ///
  /// **Ensures:**
  /// * Returns an unfiltered [RawWhatController<T>] initialized in the Empty state.
  factory RawWhatController.late({
    Object? reason,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) = _RawWhatControllerImpl<T>.late;

  /// Creates an unfiltered [RawWhatController] initialized in an Error state.
  ///
  /// * [error]: The initial exception or error payload.
  /// * [stackTrace]: Optional stack trace associated with the failure.
  /// * [onActivated]: Callback triggered when the first downstream subscriber connects.
  /// * [onDeactivated]: Callback triggered when all downstream subscribers disconnect.
  /// * [graceful]: Optional [Graceful] policy delaying deactivation when subscribers drop to zero.
  ///
  /// **Ensures:**
  /// * Returns an unfiltered [RawWhatController<T>] initialized in the Error state.
  factory RawWhatController.error(
    Object error, {
    StackTrace? stackTrace,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) = _RawWhatControllerImpl<T>.error;

  /// Force-emits a dirty pulse downstream for in-place mutable collections or objects.
  ///
  /// When modifying mutable objects without creating new instance references, invoke
  /// [markDirty] to inform downstream nodes and UI widgets to re-pull fresh state.
  ///
  /// **Ensures:**
  /// * Synchronously marks the underlying node dirty and schedules downstream updates.
  void markDirty();
}
