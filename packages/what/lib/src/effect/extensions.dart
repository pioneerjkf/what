// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Effect Scopes (Zero-Allocation Extension Types)
// =============================================================================

/// Canonical scoped namespace for declarative reactive [Effect] creation targeting multiple [What] nodes.
///
/// Compile-time zero-cost abstraction wrapping multiple [What] nodes with
/// direct monomorphic multi-target terminal dispatch.
///
/// ## Sub-Functor & Invocation Pathways
/// ```text
/// targets.effect                 ((action) => ...)
///  ├── .handled                  ((handle) => ...)
///  ├── .throttle                 (duration, (action) => ...)
///  └── .debounce                 (duration, (action) => ...)
/// ```
///
/// ## Mechanics & Lifecycle Characteristics
/// As a Dart 3 extension type (`extension type const WhatEffectScope`), this abstraction
/// introduces zero runtime heap allocation overhead. Invocations dispatch directly to
/// multi-target manifest terminals ([_NaryManifestEffectTerminal], [_NaryDebounceEffectTerminal],
/// [_NaryThrottleEffectTerminal]), coordinating multiple upstream reactive nodes under a single
/// non-propagating lifecycle terminal.
///
/// ## System Architectural Flow
/// ```text
/// [Source Nodes: (A, B, ...)]
///               │
///               ▼ (Push-Dirty Invalidation)
///   [WhatEffectScope Namespace]
///               │
///        ┌──────┴──────────────────────────┬────────────────────────┐
///        │ .call() / .handled()            │ .throttle()            │ .debounce()
///        ▼                                 ▼                        ▼
/// [N-ary Manifest Terminal]     [N-ary Throttle Terminal] [N-ary Debounce Terminal]
///        │                                 │                        │
///        └────────────────────────┬────────┴────────────────────────┘
///                                 ▼
///                     [Execute Untracked Action]
/// ```
///
/// ## Architectural Benefits
/// 1. **Zero Heap Overhead**: Erases entirely at compile time to static terminal constructor calls.
/// 2. **Fluent Method-Chaining Ergonomics**: Enables chaining `.handled`, `.throttle`, and `.debounce`
///    directly from tuples (e.g. `(user.what, auth.what).effect`) or `Iterable<What>` collections.
/// 3. **Multi-Dependency Edge Consolidation**: Coordinates multiple upstream triggers into a single
///    action turn without intermediate relay allocations.
///
/// ## Examples
/// ```dart
/// final user = WhatController('Alice');
/// final auth = WhatController(true);
///
/// // Create a multi-target effect off a tuple:
/// final syncEffect = (user.what, auth.what).effect(() {
///   syncProfile(user.what.peek, auth.what.peek);
/// });
/// ```
extension type const WhatEffectScope(Iterable<What> _targets) {
  /// Defines an explicit manifest [Effect] attached to the scoped targets.
  ///
  /// * Skips initial evaluation (0 runs upon construction/mount).
  /// * Executes [action] in an untracked environment when any of the scoped targets mutate.
  /// * If [guard] is provided and returns `false`, execution is skipped and [take] tickets are preserved.
  /// * If [take] is provided, executes at most [take] times and then automatically deactivates (Early Teardown).
  /// * If [onUncaughtError] is provided, it is invoked when an uncaught exception is thrown in [action] or [guard].
  ///
  /// * [action]: The untracked callback to invoke upon mutation.
  /// * [guard]: Optional boolean predicate gating execution and preserving tickets when `false`.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a manifest [Effect] bound to the scoped targets.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT mutate scoped targets synchronously inside [action] without an exit condition.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Mutating target inside its own effect action
  /// [counter.what].effect(() {
  ///   counter.set(counter.what.peek + 1); // Triggers infinite invalidation loop!
  /// });
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Perform external side-effects
  /// [counter.what].effect(() {
  ///   analyticsService.log(counter.what.peek);
  /// });
  /// ```
  ///
  /// ## Examples
  /// ```dart
  /// final effect = [user.what, role.what].effect(() {
  ///   refreshPermissions(user.what.peek, role.what.peek);
  /// });
  /// ```
  @pragma('vm:prefer-inline')
  Effect call(
    void Function() action, {
    bool Function()? guard,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) =>
      Effect(
        _targets,
        action,
        guard: guard,
        take: take,
        onUncaughtError: onUncaughtError,
      );

  /// Defines an explicit handled [Effect] attached to the scoped targets providing an [EffectHandle].
  ///
  /// * Skips initial evaluation (0 runs upon construction/mount).
  /// * Executes [action] with an [EffectHandle] in an untracked environment when any of the scoped targets mutate.
  /// * Prior to subsequent evaluations or deactivation, the previous turn's [EffectHandle]
  ///   is marked cancelled and its registered cleanup callbacks are executed in LIFO order.
  /// * If [guard] is provided and returns `false`, execution is skipped and [take] tickets are preserved.
  /// * If [take] is provided, executes at most [take] times and then automatically deactivates (Early Teardown).
  /// * If [onUncaughtError] is provided, it is invoked when an uncaught exception is thrown in [action] or [guard].
  ///
  /// * [action]: The untracked callback receiving an [EffectHandle] to invoke upon mutation.
  /// * [guard]: Optional boolean predicate gating execution and preserving tickets when `false`.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a handled [Effect] with deterministic lifecycle cleanup capabilities.
  ///
  /// ## Examples
  /// ```dart
  /// final effect = (room.what, server.what).effect.handled((handle) {
  ///   final client = connect(room.what.peek, server.what.peek);
  ///   handle.onCleanup(client.close);
  /// });
  /// ```
  @pragma('vm:prefer-inline')
  Effect handled(
    void Function(EffectHandle handle) action, {
    bool Function()? guard,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) =>
      Effect.handled(
        _targets,
        action,
        guard: guard,
        take: take,
        onUncaughtError: onUncaughtError,
      );

  /// Defines an explicit rate-limited [ThrottleEffect] attached to the scoped targets.
  ///
  /// Guarantees that [action] is executed at most once per [duration] window across all targets.
  ///
  /// * [duration]: The minimum time interval between consecutive executions.
  /// * [action]: The untracked callback to execute when triggered.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [leading]: Whether to execute on the leading edge of the time window. Defaults to `true`.
  /// * [trailing]: Whether to execute on the trailing edge if mutations arrived during window. Defaults to `true`.
  /// * [take]: Optional maximum number of times this effect may execute.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a [ThrottleEffect] attached to the scoped targets.
  ///
  /// ## Examples
  /// ```dart
  /// final effect = (scrollX.what, scrollY.what).effect.throttle(
  ///   const Duration(milliseconds: 100),
  ///   () => syncViewport(scrollX.what.peek, scrollY.what.peek),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  ThrottleEffect throttle(
    Duration duration,
    void Function() action, {
    bool Function()? guard,
    bool leading = true,
    bool trailing = true,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) =>
      ThrottleEffect(
        _targets,
        duration,
        action,
        guard: guard,
        leading: leading,
        trailing: trailing,
        take: take,
        onUncaughtError: onUncaughtError,
      );

  /// Defines an explicit time-stabilized [DebounceEffect] attached to the scoped targets.
  ///
  /// Delays executing [action] until invalidation bursts across all targets have ceased for at least [duration].
  ///
  /// * [duration]: The silence window duration required before executing [action].
  /// * [action]: The untracked callback to execute when the debounce window settles.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [leading]: Whether to execute immediately on first mutation. Defaults to `false`.
  /// * [trailing]: Whether to execute on trailing edge after silence elapses. Defaults to `true`.
  /// * [take]: Optional maximum number of times this effect may execute.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a [DebounceEffect] attached to the scoped targets.
  ///
  /// ## Examples
  /// ```dart
  /// final effect = (filter.what, sort.what).effect.debounce(
  ///   const Duration(milliseconds: 300),
  ///   () => fetchFiltered(filter.what.peek, sort.what.peek),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  DebounceEffect debounce(
    Duration duration,
    void Function() action, {
    bool Function()? guard,
    bool leading = false,
    bool trailing = true,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) =>
      DebounceEffect(
        _targets,
        duration,
        action,
        guard: guard,
        leading: leading,
        trailing: trailing,
        take: take,
        onUncaughtError: onUncaughtError,
      );
}

/// Specialized scoped namespace for declarative reactive [Effect] creation targeting a single [What].
///
/// Compile-time zero-cost abstraction wrapping a single [What] node with
/// zero heap allocation and direct monomorphic unary terminal dispatch.
///
/// ## Sub-Functor & Invocation Pathways
/// ```text
/// target.effect                  ((action) => ...)
///  ├── .handled                  ((handle) => ...)
///  ├── .throttle                 (duration, (action) => ...)
///  └── .debounce                 (duration, (action) => ...)
/// ```
///
/// ## Mechanics & Lifecycle Characteristics
/// As a specialized Dart 3 extension type (`extension type const UnaryWhatEffectScope`),
/// this namespace bypasses intermediate collections and iterator overhead, constructing
/// specialized unary terminals ([_UnaryManifestEffectTerminal], [_UnaryDebounceEffectTerminal],
/// [_UnaryThrottleEffectTerminal]) that directly link to the underlying source node.
///
/// ## System Architectural Flow
/// ```text
/// [Single Target: target.what]
///               │
///               ▼ (Push-Dirty Invalidation)
/// [UnaryWhatEffectScope Namespace]
///               │
///        ┌──────┴──────────────────────────┬────────────────────────┐
///        │ .call() / .handled()            │ .throttle()            │ .debounce()
///        ▼                                 ▼                        ▼
/// [Unary Manifest Terminal]     [Unary Throttle Terminal] [Unary Debounce Terminal]
///        │                                 │                        │
///        └────────────────────────┬────────┴────────────────────────┘
///                                 ▼
///                     [Execute Untracked Action]
/// ```
///
/// ## Architectural Benefits
/// 1. **Zero Heap Allocation**: Directly links the single source node without allocating `List<What>`.
/// 2. **Monomorphic Dispatch**: Specialized unary terminals yield optimal V8 and Dart AOT inlining.
/// 3. **Fluent Ergonomics**: Accessible directly off any [What] node via `target.effect`.
///
/// ## Examples
/// ```dart
/// final counter = WhatController(0);
/// final effect = counter.what.effect(() {
///   print('New counter value: ${counter.what.peek}');
/// });
/// ```
extension type const UnaryWhatEffectScope(What _target) {
  /// Defines an explicit manifest [Effect] attached to this node.
  ///
  /// * Skips initial evaluation (0 runs upon construction/mount).
  /// * Executes [action] in an untracked environment when this node mutates.
  /// * If [guard] is provided and returns `false`, execution is skipped and [take] tickets are preserved.
  /// * If [take] is provided, executes at most [take] times then automatically deactivates (Early Teardown).
  /// * If [onUncaughtError] is provided, it is invoked when an uncaught exception is thrown in [action] or [guard].
  ///
  /// * [action]: The untracked callback to invoke upon mutation.
  /// * [guard]: Optional boolean predicate gating execution and preserving tickets when `false`.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a unary manifest [Effect] bound to this node.
  ///
  /// ## Examples
  /// ```dart
  /// final counter = WhatController(0);
  /// final effect = counter.what.effect(() {
  ///   analyticsService.logCounter(counter.what.peek);
  /// });
  /// ```
  @pragma('vm:prefer-inline')
  Effect call(
    void Function() action, {
    bool Function()? guard,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) =>
      Effect.unary(
        _target,
        action,
        guard: guard,
        take: take,
        onUncaughtError: onUncaughtError,
      );

  /// Defines an explicit handled [Effect] attached to this node providing an [EffectHandle].
  ///
  /// * Skips initial evaluation (0 runs upon construction/mount).
  /// * Executes [action] with an [EffectHandle] in an untracked environment when this node mutates.
  /// * Prior to subsequent evaluations or deactivation, the previous turn's [EffectHandle]
  ///   is marked cancelled and its registered cleanup callbacks are executed in LIFO order.
  /// * If [guard] is provided and returns `false`, execution is skipped and [take] tickets are preserved.
  /// * If [take] is provided, executes at most [take] times then automatically deactivates (Early Teardown).
  /// * If [onUncaughtError] is provided, it is invoked when an uncaught exception is thrown in [action] or [guard].
  ///
  /// * [action]: The untracked callback receiving an [EffectHandle] to invoke upon mutation.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a unary handled [Effect] bound to this node.
  ///
  /// ## Examples
  /// ```dart
  /// final room = WhatController('lobby');
  /// final effect = room.what.effect.handled((handle) {
  ///   final timer = Timer.periodic(const Duration(seconds: 1), (_) => ping());
  ///   handle.onCleanup(timer.cancel);
  /// });
  /// ```
  @pragma('vm:prefer-inline')
  Effect handled(
    void Function(EffectHandle handle) action, {
    bool Function()? guard,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) =>
      Effect.handledUnary(
        _target,
        action,
        guard: guard,
        take: take,
        onUncaughtError: onUncaughtError,
      );

  /// Defines an explicit rate-limited [ThrottleEffect] attached to this node.
  ///
  /// Rate-limits triggers to at most once per [duration].
  ///
  /// * [duration]: The minimum time interval between consecutive executions.
  /// * [action]: The untracked callback to execute when triggered.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [leading]: Whether to execute on the leading edge. Defaults to `true`.
  /// * [trailing]: Whether to execute on the trailing edge. Defaults to `true`.
  /// * [take]: Optional execution limit before early teardown.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a unary [ThrottleEffect] attached to this node.
  ///
  /// ## Examples
  /// ```dart
  /// final scroll = WhatController(0.0);
  /// final effect = scroll.what.effect.throttle(
  ///   const Duration(milliseconds: 100),
  ///   () => syncScroll(scroll.what.peek),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  ThrottleEffect throttle(
    Duration duration,
    void Function() action, {
    bool Function()? guard,
    bool leading = true,
    bool trailing = true,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) =>
      ThrottleEffect.unary(
        _target,
        duration,
        action,
        guard: guard,
        leading: leading,
        trailing: trailing,
        take: take,
        onUncaughtError: onUncaughtError,
      );

  /// Defines an explicit time-stabilized [DebounceEffect] attached to this node.
  ///
  /// Delays trigger execution until [duration] passes with no new mutations on this node.
  ///
  /// * [duration]: The silence window duration required before executing [action].
  /// * [action]: The untracked callback to execute when the debounce window settles.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [leading]: Whether to execute immediately on first mutation. Defaults to `false`.
  /// * [trailing]: Whether to execute on trailing edge after silence elapses. Defaults to `true`.
  /// * [take]: Optional execution limit before early teardown.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a unary [DebounceEffect] attached to this node.
  ///
  /// ## Examples
  /// ```dart
  /// final query = WhatController('');
  /// final effect = query.what.effect.debounce(
  ///   const Duration(milliseconds: 300),
  ///   () => apiService.search(query.what.peek),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  DebounceEffect debounce(
    Duration duration,
    void Function() action, {
    bool Function()? guard,
    bool leading = false,
    bool trailing = true,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) =>
      DebounceEffect.unary(
        _target,
        duration,
        action,
        guard: guard,
        leading: leading,
        trailing: trailing,
        take: take,
        onUncaughtError: onUncaughtError,
      );
}

// =============================================================================
// Direct .effect Extension Suite (Single, Tuples & Iterable)
// =============================================================================

/// Extension granting a single [What] node direct access to reactive effect namespaces.
extension WhatEffectExtension on What {
  /// Opens a scoped namespace for declarative reactive [Effect] creation targeting this node.
  ///
  /// **Ensures:**
  /// * Returns a compile-time zero-cost [UnaryWhatEffectScope] wrapping this node.
  @pragma('vm:prefer-inline')
  UnaryWhatEffectScope get effect => UnaryWhatEffectScope(this);
}

/// Extension granting a 2-tuple of [What] instances access to reactive effect namespaces.
extension WhatRecord2EffectExtension on (What, What) {
  /// The underlying [What] nodes of this pair.
  List<What> get whats => [$1, $2];

  /// Opens a scoped namespace for declarative reactive [Effect] creation targeting this pair.
  ///
  /// **Ensures:**
  /// * Returns a compile-time zero-cost [WhatEffectScope] wrapping this pair.
  @pragma('vm:prefer-inline')
  WhatEffectScope get effect => WhatEffectScope(whats);
}

/// Extension granting a 3-tuple of [What] instances access to reactive effect namespaces.
extension WhatRecord3EffectExtension on (What, What, What) {
  /// The underlying [What] nodes of this triplet.
  List<What> get whats => [$1, $2, $3];

  /// Opens a scoped namespace for declarative reactive [Effect] creation targeting this triplet.
  ///
  /// **Ensures:**
  /// * Returns a compile-time zero-cost [WhatEffectScope] wrapping this triplet.
  @pragma('vm:prefer-inline')
  WhatEffectScope get effect => WhatEffectScope(whats);
}

/// Extension granting a 4-tuple of [What] instances access to reactive effect namespaces.
extension WhatRecord4EffectExtension on (What, What, What, What) {
  /// The underlying [What] nodes of this 4-tuple.
  List<What> get whats => [$1, $2, $3, $4];

  /// Opens a scoped namespace for declarative reactive [Effect] creation targeting this 4-tuple.
  ///
  /// **Ensures:**
  /// * Returns a compile-time zero-cost [WhatEffectScope] wrapping this 4-tuple.
  @pragma('vm:prefer-inline')
  WhatEffectScope get effect => WhatEffectScope(whats);
}

/// Extension granting a 5-tuple of [What] instances access to reactive effect namespaces.
extension WhatRecord5EffectExtension on (What, What, What, What, What) {
  /// The underlying [What] nodes of this 5-tuple.
  List<What> get whats => [$1, $2, $3, $4, $5];

  /// Opens a scoped namespace for declarative reactive [Effect] creation targeting this 5-tuple.
  ///
  /// **Ensures:**
  /// * Returns a compile-time zero-cost [WhatEffectScope] wrapping this 5-tuple.
  @pragma('vm:prefer-inline')
  WhatEffectScope get effect => WhatEffectScope(whats);
}

/// Extension granting collections of [What] instances access to reactive effect namespaces.
extension WhatIterableEffectExtension on Iterable<What> {
  /// The underlying [What] nodes of this collection.
  Iterable<What> get whats => this;

  /// Opens a scoped namespace for declarative reactive [Effect] creation targeting this collection.
  ///
  /// **Ensures:**
  /// * Returns a compile-time zero-cost [WhatEffectScope] wrapping this collection.
  @pragma('vm:prefer-inline')
  WhatEffectScope get effect => WhatEffectScope(this);
}
