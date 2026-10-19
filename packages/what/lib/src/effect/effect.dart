// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Effect Contract
// =============================================================================

/// An active execution context handle for a handled [Effect] run.
///
/// Encapsulates the execution turn's lifecycle status flags and cleanup callback
/// registration, safeguarding against in-flight race conditions and background
/// zombie execution.
///
/// ## System Architectural Flow
///
/// ### Execution Turn State Machine
/// ```text
/// [Upstream Target Mutation / Turn Initialized]
///                       │
///                       ▼
///        ┌──────────────────────────────┐
///        │     EffectHandle Active      │ (isActive == true, isCancelled == false)
///        │  (Registers Cleanups via RAII)│
///        └──────────────┬───────────────┘
///                       │
///                       ├─► [Upstream Mutates Again] ──┐
///                       │                              │ (Invokes _dispose())
///                       ├─► [Effect Terminal Deactivated]│
///                       │                              │
///                       ▼                              ▼
///        ┌────────────────────────────────────────────────────────┐
///        │                 EffectHandle Disposed                  │ (isActive == false)
///        │       (Executes Registered Cleanups in LIFO Order)     │ (isCancelled == true)
///        └────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **RAII Multi-Registration**: Call [onCleanup] multiple times within a single turn.
///    Cleanups are stored directly on the fast path (single cleanup) without heap list allocation,
///    and composed recursively with `try-finally` chaining when multiple cleanups are added.
/// 2. **Exception Safety during Setup**: If acquiring a second resource throws an exception,
///    previously registered cleanups for earlier resources remain intact and will be executed
///    when the handle is disposed.
/// 3. **Cancellation & Zombie Protection**: Asynchronous or long-running tasks can inspect
///    [isActive] and [isCancelled] to discard stale results if a newer mutation triggered.
/// 4. **Immediate Teardown on Stale Registration**: If [onCleanup] is invoked after this handle
///    has already been cancelled, the cleanup executes immediately to prevent resource leaks.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT retain [EffectHandle] references across multiple effect execution turns.
/// - Do NOT omit cleanup registration for active timers, subscriptions, or sockets acquired
///   inside handled effect callbacks.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Unregistered timer continues running after effect teardown
/// Effect([room.what], () {
///   Timer.periodic(const Duration(seconds: 1), (_) => ping()); // Leaks!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Bind resource teardown directly to the execution handle
/// Effect.handled([room.what], (handle) {
///   final timer = Timer.periodic(const Duration(seconds: 1), (_) => ping());
///   handle.onCleanup(timer.cancel);
/// });
/// ```
///
/// ## Examples
/// ```dart
/// final room = WhatController('lobby');
///
/// final roomEffect = Effect.handled([room.what], (handle) {
///   final timer = Timer.periodic(const Duration(seconds: 5), (_) => sendHeartbeat());
///   handle.onCleanup(timer.cancel);
/// });
/// ```
abstract interface class EffectHandle {
  /// Whether this execution turn is currently active and valid (neither cancelled nor deactivated).
  bool get isActive;

  /// Whether this execution turn has been cancelled by a subsequent invalidation,
  /// node deactivation, or lifecycle teardown.
  bool get isCancelled;

  /// Registers a synchronous cleanup callback to be executed upon turn cancellation or deactivation.
  ///
  /// ## Multi-Registration & Locality of Reference (RAII)
  /// You can call [onCleanup] multiple times within a single effect turn.
  /// Registering cleanups **immediately adjacent to resource acquisition** guarantees
  /// exception safety and modular decomposition:
  ///
  /// ```dart
  /// Effect.handled([room.what], (handle) {
  ///   // Resource 1: acquired and immediately guarded
  ///   final timer = Timer.periodic(const Duration(seconds: 1), (_) => ping());
  ///   handle.onCleanup(timer.cancel);
  ///
  ///   // Resource 2: acquired and immediately guarded
  ///   final sub = eventStream.listen(onEvent);
  ///   handle.onCleanup(sub.cancel);
  /// });
  /// ```
  ///
  /// ### Architectural Rationales
  /// 1. **Exception Safety during Setup**: If an exception is thrown while acquiring a subsequent
  ///    resource, previously registered cleanups remain intact and execute reliably.
  /// 2. **Modular Composition**: Enables passing [EffectHandle] into independent helper functions
  ///    allowing each sub-routine to safely register its own cleanup without overwriting others.
  /// 3. **Clean Conditional Branching**: Resources acquired inside `if` blocks can register their
  ///    respective teardowns directly in-place without nullable tracking variables.
  ///
  /// ## Execution Timing
  /// Cleanups are **NOT** executed immediately when the action function returns.
  /// They remain dormant and active while the current turn is valid, and are executed:
  /// * **Right before the next execution turn begins** (upon upstream mutation).
  /// * **When the effect is deactivated or unmounted** (upon scope exit / disposal).
  ///
  /// * [cleanup]: The synchronous callback to execute when this turn is cancelled or deactivated.
  ///
  /// **Ensures:**
  /// * If this handle is already cancelled, executes [cleanup] immediately.
  /// * Otherwise, chains [cleanup] into the pending teardown pipeline.
  void onCleanup(void Function() cleanup);
}

/// A composite [Effect] that groups multiple child effects into a single lifecycle terminal.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────┐
/// │                  EffectGroup Terminal                  │
/// └───────────────────────────┬────────────────────────────┘
///                             │ (Atomic Lifecycle Fan-Out)
///       ┌─────────────────────┼─────────────────────┐
///       ▼                     ▼                     ▼
/// [Child Effect 1]      [Child Effect 2]      [Child Effect 3]
///    (Target A)            (Target B)            (Target C)
/// ```
///
/// Activating or deactivating an [EffectGroup] activates or deactivates all constituent
/// child effects atomically as a single coordinated lifecycle unit.
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Atomic Lifecycle Coordination**: Activation and deactivation commands are fanned out
///    atomically to all member effects without race conditions or partial teardown windows.
///    When bound via `via.tether()`, all grouped effects activate and deactivate together.
/// 2. **Deduplicated Set Semantics**: Duplicate child effect instances passed to [EffectGroup]
///    are automatically deduplicated via `.toSet()`, preventing redundant edge allocations.
/// 3. **Independent Trigger Isolation**: Constituent effects maintain their own independent
///    upstream bindings, guards, rate-limiters, and actions while sharing coordinated lifecycle management.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT manage distinct lifecycle runners or tethers for tightly coupled effects independently;
///   partial deactivations can lead to orphaned background execution.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Managing multiple related effects independently
/// final r1 = effectA.run();
/// final r2 = effectB.run(); // Easily forgotten during cleanup!
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Bundle into a composite group for atomic lifecycle control
/// final groupRunner = EffectGroup([effectA, effectB]).run();
/// // ...
/// groupRunner.deactivate(); // Atomically cleans up both effects
/// ```
///
/// ## Examples
/// ```dart
/// final searchEffect = query.what.effect.debounce(
///   const Duration(milliseconds: 300),
///   () => performSearch(),
/// );
/// final loggingEffect = query.what.effect(() => logQuery());
///
/// final group = EffectGroup([searchEffect, loggingEffect]);
/// final runner = group.run();
/// ```
sealed class EffectGroup extends Effect {
  EffectGroup._() : super._();

  /// Creates an [EffectGroup] containing [effects].
  ///
  /// * [effects]: The collection of child effects to group together. Duplicate instances
  ///   are automatically deduplicated.
  ///
  /// **Ensures:**
  /// * Returns an [EffectGroup] managing the aggregated lifecycle of [effects].
  factory EffectGroup(Iterable<Effect> effects) = _EffectGroup;

  /// The unmodifiable list of unique child effects in this group.
  List<Effect> get effects;
}

/// A declarative lifecycle-bound side-effect node that executes an untracked action upon upstream mutations.
///
/// Under the two-plane reactive architecture of the What framework:
/// - **Data Plane ([What])**: Evaluates and propagates state mutations downstream via the
///   2-Phase Push-Dirty / Lazy-Pull DAG.
/// - **Lifecycle Plane ([Tether])**: Declarative lifecycle entities governed by enclosing
///   tracking scopes via [WhatVia.tether] or executed imperatively via [EffectRunner].
/// - An [Effect] encapsulates an internal terminal (`_Terminal`) that acts as a non-propagating
///   terminal sink (`_isNewerThan` always returns `false`), executing pure side-effects
///   (analytics, external I/O sync, storage, audio/haptic feedback) without mutating intermediate
///   DAG nodes or propagating dirty pulses downstream.
///
/// ## System Architectural Flow
/// ```text
///                     Upstream What Invalidation
///                                 │
///                                 ▼ (Push-Dirty Notification)
///                    ┌─────────────────────────┐
///                    │    Schedule Terminal    │ (_Scheduler.instance._scheduleTerminal)
///                    └────────────┬────────────┘
///                                 │ (Scheduled Turn Execution)
///                                 ▼
///                    ┌─────────────────────────┐
///                    │     _resolveDirty()?    │ (2-Phase Verification)
///                    └────────────┬────────────┘
///                                 │
///                  ┌──────────────┴──────────────┐
///           (false)│                             │(true)
///                  ▼                             ▼
///           [Abort execution]           ┌────────────────┐
///         (No actual mutation)          │ Check guard()? │
///                                       └────────┬───────┘
///                                                │
///                                 ┌──────────────┴──────────────┐
///                          (false)│                             │(true / no guard)
///                                 ▼                             ▼
///                          [Skip execution]             [Consume 1 take Ticket]
///                          [Retain tickets]                     │
///                                                               ▼
///                                                  [Execute action() Untracked]
///                                                               │
///                                                  ┌────────────┴────────────┐
///                                                  │ Exhausted take tickets? │
///                                                  └────────────┬────────────┘
///                                                               │(true)
///                                                               ▼
///                                                      [Auto-Deactivate]
///                                                      [Early Teardown]
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero-Glitch Terminal Sinks**: Effects fire only after state transactions settle via the
///    What microtask scheduler, eliminating transient tearing and intermediate glitch states.
/// 2. **Precondition Gating with Ticket Preservation**: When `guard` returns `false`, execution
///    is aborted without consuming `take` tickets.
/// 3. **Sound Early Teardown**: An effect configured with `take` automatically deactivates and
///    detaches its subscription edges once the ticket quota reaches zero.
/// 4. **Dual Execution Models**:
///    * **Manifest Effects** (`Effect`, `Effect.unary`, `Effect.handled`, `Effect.handledUnary`):
///      Attached to explicit target collections; skip initial evaluation (0 runs upon mount)
///      and trigger strictly on subsequent upstream mutations.
///    * **Dynamic Discovery Effects** (`Effect.via`, `Effect.handledVia`):
///      Evaluate initially upon activation to discover dependencies via `via(node)`, re-running
///      when any observed node mutates with 1-pass epoch sweeping.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT mutate observed `targets` synchronously inside `action` without an exit condition,
///   as it induces reentrant invalidation loops.
/// - Do NOT instantiate new [Effect] objects inside build methods without caching or lifecycle tethering.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Synchronously mutating target inside its own effect without an exit condition
/// final counter = WhatController(0);
/// Effect([counter.what], () {
///   counter.set(counter.what.peek + 1); // Triggers infinite invalidation loop!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Perform external I/O or update distinct downstream state
/// final counter = WhatController(0);
/// Effect([counter.what], () {
///   analyticsService.logCounter(counter.what.peek); // Pure side-effect sink
/// });
/// ```
///
/// ## Examples
/// ```dart
/// final user = WhatController('Alice');
/// final auth = WhatController(true);
///
/// final syncEffect = Effect(
///   [user.what, auth.what],
///   () => syncSession(user.what.peek, auth.what.peek),
///   take: 5,
/// );
/// ```
sealed class Effect extends Tether {
  Effect._() : super._();

  /// Creates a manifest [Effect] attached strictly to explicit [targets].
  ///
  /// * Skips initial evaluation (0 runs upon construction/mount).
  /// * Executes [action] in an untracked environment when any of [targets] mutate.
  /// * If [guard] is provided and returns `false`, execution is skipped and [take] tickets are preserved.
  /// * If [take] is provided, executes at most [take] times and then automatically
  ///   deactivates and detaches from upstream targets (Early Teardown).
  /// * If [onUncaughtError] is provided, it is invoked when an uncaught exception is thrown in [action] or [guard].
  ///
  /// * [targets]: The reactive [What] nodes to monitor for mutations.
  /// * [action]: The untracked callback to invoke upon mutation.
  /// * [guard]: Optional boolean predicate gating execution and preserving tickets when returning `false`.
  /// * [take]: Optional limit on execution count before automatic deactivation. Must be non-negative.
  /// * [onUncaughtError]: Optional error recovery handler invoked on uncaught exceptions.
  ///
  /// **Requires:**
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a manifest [Effect] bound to [targets].
  ///
  /// ## Examples
  /// ```dart
  /// final counter = WhatController(0);
  /// final effect = Effect([counter.what], () {
  ///   print('Counter mutated to: ${counter.what.peek}');
  /// });
  /// ```
  factory Effect(
    Iterable<What> targets,
    void Function() action, {
    bool Function()? guard,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _ManifestEffect;

  /// Creates an optimized unary manifest [Effect] attached strictly to a single explicit [target].
  ///
  /// Provides zero-allocation fast-path dispatch by bypassing intermediate `List` allocations
  /// and linking directly via a specialized unary edge terminal.
  ///
  /// * Skips initial evaluation (0 runs upon construction/mount).
  /// * Executes [action] in an untracked environment when [target] mutates.
  /// * If [guard] is provided and returns `false`, execution is skipped and [take] tickets are preserved.
  /// * If [take] is provided, executes at most [take] times and then automatically
  ///   deactivates and detaches from upstream target (Early Teardown).
  /// * If [onUncaughtError] is provided, it is invoked when an uncaught exception is thrown in [action] or [guard].
  ///
  /// * [target]: The single [What] node to monitor.
  /// * [action]: The untracked callback to execute when [target] mutates.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional execution limit before automatic deactivation.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a unary manifest [Effect] bound to [target].
  ///
  /// ## Examples
  /// ```dart
  /// final query = WhatController('');
  /// final effect = Effect.unary(query.what, () {
  ///   analyticsService.logSearch(query.what.peek);
  /// });
  /// ```
  factory Effect.unary(
    What target,
    void Function() action, {
    bool Function()? guard,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _UnaryManifestEffect;

  /// Creates an explicit dynamic discovery [Effect] using [WhatVia].
  ///
  /// Unlike manifest effects which skip initial evaluation, [Effect.via] evaluates
  /// immediately upon activation to dynamically register dependencies observed via `via(node)`.
  /// Subsequent evaluations occur whenever any registered upstream dependency mutates.
  ///
  /// If an observed node is in an Empty or Error state, invoking `via(node)` throws an internal
  /// sentinel that short-circuits the current turn safely while retaining discovered dependency edges.
  ///
  /// * [action]: The callback executed initially to record dependencies and upon subsequent invalidations.
  /// * [guard]: Optional predicate evaluated before [action] using `via`.
  /// * [onUncaughtError]: Optional error handler invoked when [action] or [guard] throws.
  ///
  /// **Ensures:**
  /// * Returns a dynamic [Effect] with explicit [WhatVia] edge tracking and 1-pass epoch sweeping.
  ///
  /// ## Examples
  /// ```dart
  /// final effect = Effect.via((via) {
  ///   final u = via(user.what);
  ///   final a = via(auth.what);
  ///   syncProfile(u, a);
  /// });
  /// ```
  factory Effect.via(
    void Function(WhatVia via) action, {
    bool Function(WhatVia via)? guard,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _ViaEffect;

  /// Creates a manifest [Effect] attached strictly to explicit [targets] providing an [EffectHandle].
  ///
  /// * Skips initial evaluation (0 runs upon construction/mount).
  /// * Executes [action] with an injected [EffectHandle] in an untracked environment when any of [targets] mutate.
  /// * Prior to subsequent evaluations or deactivation, the previous turn's [EffectHandle]
  ///   is marked cancelled and its registered cleanup callbacks are executed in LIFO order.
  /// * If [guard] is provided and returns `false`, execution is skipped and [take] tickets are preserved.
  /// * If [take] is provided, executes at most [take] times and then automatically deactivates (Early Teardown).
  /// * If [onUncaughtError] is provided, it is invoked when an uncaught exception is thrown in [action] or [guard].
  ///
  /// * [targets]: The reactive [What] nodes to monitor for mutations.
  /// * [action]: The untracked callback receiving an [EffectHandle] to invoke upon mutation.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a manifest [Effect] bound to [targets] with deterministic handle lifecycle management.
  ///
  /// ## Examples
  /// ```dart
  /// final room = WhatController('lobby');
  /// final effect = Effect.handled([room.what], (handle) {
  ///   final timer = Timer.periodic(const Duration(seconds: 1), (_) => ping());
  ///   handle.onCleanup(timer.cancel);
  /// });
  /// ```
  factory Effect.handled(
    Iterable<What> targets,
    void Function(EffectHandle handle) action, {
    bool Function()? guard,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _HandledManifestEffect;

  /// Creates an optimized unary manifest [Effect] attached strictly to a single explicit [target] providing an [EffectHandle].
  ///
  /// * Skips initial evaluation (0 runs upon construction/mount).
  /// * Executes [action] with an injected [EffectHandle] in an untracked environment when [target] mutates.
  /// * Prior to subsequent evaluations or deactivation, the previous turn's [EffectHandle]
  ///   is marked cancelled and its registered cleanup callbacks are executed in LIFO order.
  /// * If [guard] is provided and returns `false`, execution is skipped and [take] tickets are preserved.
  /// * If [take] is provided, executes at most [take] times and then automatically deactivates (Early Teardown).
  /// * If [onUncaughtError] is provided, it is invoked when an uncaught exception is thrown in [action] or [guard].
  ///
  /// * [target]: The single [What] node to monitor.
  /// * [action]: The untracked callback receiving an [EffectHandle] to execute when [target] mutates.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional execution limit before automatic deactivation.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a unary manifest [Effect] bound to [target] with deterministic handle lifecycle management.
  ///
  /// ## Examples
  /// ```dart
  /// final room = WhatController('lobby');
  /// final effect = Effect.handledUnary(room.what, (handle) {
  ///   final sub = eventStream.listen(onEvent);
  ///   handle.onCleanup(sub.cancel);
  /// });
  /// ```
  factory Effect.handledUnary(
    What target,
    void Function(EffectHandle handle) action, {
    bool Function()? guard,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _HandledUnaryManifestEffect;

  /// Creates an explicit dynamic discovery [Effect] using [WhatVia] and [EffectHandle].
  ///
  /// Evaluates immediately upon activation to dynamically register dependencies observed via `via(node)`.
  /// Prior to subsequent evaluations or deactivation, the previous turn's [EffectHandle]
  /// is marked cancelled and its registered cleanup callbacks are invoked.
  ///
  /// * [action]: The callback executed initially to record dependencies and upon subsequent invalidations.
  /// * [guard]: Optional predicate evaluated before [action] using `via`.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Ensures:**
  /// * Returns a dynamic [Effect] with explicit [WhatVia] edge tracking and [EffectHandle] lifecycle.
  ///
  /// ## Examples
  /// ```dart
  /// final effect = Effect.handledVia((via, handle) {
  ///   final currentRoom = via(room.what);
  ///   final client = connectToRoom(currentRoom);
  ///   handle.onCleanup(client.disconnect);
  /// });
  /// ```
  factory Effect.handledVia(
    void Function(WhatVia via, EffectHandle handle) action, {
    bool Function(WhatVia via)? guard,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _HandledViaEffect;

  /// Creates a composite [Effect] grouping [effects] into a single lifecycle terminal.
  ///
  /// Convenience alias for [EffectGroup.new].
  ///
  /// * [effects]: The child effects to group together.
  ///
  /// **Ensures:**
  /// * Returns an [EffectGroup] managing the aggregated lifecycle of [effects].
  factory Effect.group(Iterable<Effect> effects) = _EffectGroup;

  /// The underlying terminal being controlled by this effect.
  _Terminal get _terminal;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _terminal.activate();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _terminal.deactivate();
    super._deactivate();
  }

  @override
  void _debugForceInvalidate(Set<_Node> visited) {
    if (!visited.add(this)) return;
    assert(() {
      _terminal._debugForceInvalidateInternal(visited);
      return true;
    }());
    _debugInvalidateSelf();
  }
}

// =============================================================================
// DebounceEffect Public Contract
// =============================================================================

/// A time-domain stabilization [Effect] that delays execution until invalidation bursts have settled.
///
/// Postpones invoking its action until upstream target mutations have ceased for at least
/// the specified [duration] window. Rapid consecutive invalidations within the window reset
/// the timer, coalescing high-frequency bursts into a single execution.
///
/// ## Timing Sequence Diagram
/// ```text
/// Events:     ──a──b──c──────────────d─────e───────────► (Time)
///                       │◄─duration─►│     │◄─duration─►│
/// Executions: ───────────────────────E──────────────────E (trailing: true)
/// ```
///
/// ### Leading & Trailing Matrix
/// * `leading: false, trailing: true` (Default): Executes once after events settle for [duration].
/// * `leading: true, trailing: false`: Executes immediately upon the first event; suppresses trailing execution.
/// * `leading: true, trailing: true`: Executes immediately on the first event and again after the quiet period if subsequent events arrived.
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Burst Invalidation Suppression**: Collapses rapid-fire events into a single settled execution,
///    ideal for live search queries, autocompletion, or real-time text input.
/// 2. **Settled Precondition Gating**: When configured with `guard` or `take`, predicate evaluation
///    and ticket decrements occur strictly when the debounce window settles, preventing wasted ticket consumption during intermediate bursts.
/// 3. **Automatic Timer Teardown**: Deactivating this effect immediately cancels any active debounce timer,
///    guaranteeing zero ghost executions after scope exit.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT instantiate a new [DebounceEffect] inside Flutter build methods or reactive derivations
///   without caching; rebuilding the widget will recreate the effect and reset the timer continuously.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Instantiating debounce effect inside build method resets timer every frame
/// Widget build(BuildContext context) {
///   searchQuery.what.effect.debounce(const Duration(milliseconds: 300), () => search());
///   return SearchBox();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Define debounce effect at controller/service level or bind via via.tether()
/// class SearchController {
///   final query = WhatController('');
///   late final searchEffect = query.what.effect.debounce(
///     const Duration(milliseconds: 300),
///     () => apiService.search(query.what.peek),
///   );
/// }
/// ```
///
/// ## Examples
/// ```dart
/// final query = WhatController('');
/// final searchEffect = DebounceEffect(
///   [query.what],
///   const Duration(milliseconds: 300),
///   () => apiService.search(query.what.peek),
/// );
/// ```
sealed class DebounceEffect extends Effect {
  DebounceEffect._() : super._();

  /// Creates a [DebounceEffect] attached to explicit [targets].
  ///
  /// * [targets]: The collection of reactive [What] nodes to monitor.
  /// * [duration]: The silence window duration required before executing [action].
  /// * [action]: The untracked callback to execute when the debounce window settles.
  /// * [guard]: Optional predicate gating execution and preserving tickets when returning `false`.
  /// * [leading]: Whether to execute [action] immediately on the first mutation. Defaults to `false`.
  /// * [trailing]: Whether to execute [action] on the trailing edge after silence elapses. Defaults to `true`.
  /// * [take]: Optional maximum number of times this effect may execute before early teardown.
  /// * [onUncaughtError]: Optional error callback invoked when [action] or [guard] throws an uncaught exception.
  ///
  /// **Requires:**
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a [DebounceEffect] attached to [targets].
  ///
  /// ## Examples
  /// ```dart
  /// final query = WhatController('');
  /// final effect = DebounceEffect(
  ///   [query.what],
  ///   const Duration(milliseconds: 300),
  ///   () => apiService.search(query.what.peek),
  /// );
  /// ```
  factory DebounceEffect(
    Iterable<What> targets,
    Duration duration,
    void Function() action, {
    bool Function()? guard,
    bool leading,
    bool trailing,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _ManifestDebounceEffect;

  /// Creates an optimized unary [DebounceEffect] attached to a single explicit [target].
  ///
  /// * [target]: The single [What] node to monitor.
  /// * [duration]: The silence window duration required before executing [action].
  /// * [action]: The untracked callback to execute.
  /// * [guard]: Optional predicate gating execution and preserving tickets when returning `false`.
  /// * [leading]: Whether to execute on the leading edge. Defaults to `false`.
  /// * [trailing]: Whether to execute on the trailing edge. Defaults to `true`.
  /// * [take]: Optional execution limit before deactivation.
  /// * [onUncaughtError]: Optional error recovery handler.
  ///
  /// **Requires:**
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a unary [DebounceEffect] attached to [target].
  ///
  /// ## Examples
  /// ```dart
  /// final query = WhatController('');
  /// final effect = DebounceEffect.unary(
  ///   query.what,
  ///   const Duration(milliseconds: 300),
  ///   () => apiService.search(query.what.peek),
  /// );
  /// ```
  factory DebounceEffect.unary(
    What target,
    Duration duration,
    void Function() action, {
    bool Function()? guard,
    bool leading,
    bool trailing,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _UnaryManifestDebounceEffect;

  /// The debounce silence window duration.
  Duration get duration;

  /// Whether leading edge execution is enabled.
  bool get leading;

  /// Whether trailing edge execution is enabled.
  bool get trailing;
}

// =============================================================================
// ThrottleEffect Public Contract
// =============================================================================

/// A time-domain rate-limiting [Effect] that suppresses rapid consecutive invalidations.
///
/// Guarantees that `action` is executed at most once per [duration] window, preventing
/// downstream I/O thrashing or performance degradation during high-frequency events.
///
/// ## Timing Sequence Diagram
/// ```text
/// Events:     ──a──b──c──────────────d─────e───────────► (Time)
///               │◄─duration─►│         │◄─duration─►│
/// Executions: ──E────────────E─────────E────────────E (leading: true, trailing: true)
/// ```
///
/// ### Leading & Trailing Matrix
/// * `leading: true, trailing: true` (Default): Executes immediately on the first event, and if events arrived during the window, executes again upon window close.
/// * `leading: true, trailing: false`: Executes immediately upon the first event; suppresses any trailing execution.
/// * `leading: false, trailing: true`: Defers execution until the end of the duration window.
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Fixed Execution Frequency Ceiling**: Caps execution frequency at `1 / duration`, preventing
///    expensive operations (like network sync or layout computation) from overloading resources.
/// 2. **Guaranteed Trailing Capture**: With `trailing: true` (default), events occurring during the
///    active cooldown window are captured and executed immediately once the window elapses, ensuring the latest state is never dropped.
/// 3. **Automatic Timer Teardown**: Deactivating this effect immediately cancels any active throttle timer,
///    guaranteeing zero ghost executions after scope exit.
///
/// **Warning (Anti-Pattern Prevention):**
/// - If you require waiting until rapid-fire events completely cease before executing (e.g. typing),
///   use [DebounceEffect] instead of [ThrottleEffect].
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Using throttle for search queries fires incomplete queries during typing
/// final effect = query.what.effect.throttle(const Duration(milliseconds: 300), () => search());
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Use throttle for continuous events like scrolling or window resizing
/// final effect = scrollOffset.what.effect.throttle(
///   const Duration(milliseconds: 100),
///   () => syncScroll(scrollOffset.what.peek),
/// );
/// ```
///
/// ## Examples
/// ```dart
/// final scroll = WhatController(0.0);
/// final scrollThrottle = ThrottleEffect(
///   [scroll.what],
///   const Duration(milliseconds: 100),
///   () => syncScrollOffset(scroll.what.peek),
/// );
/// ```
sealed class ThrottleEffect extends Effect {
  ThrottleEffect._() : super._();

  /// Creates a [ThrottleEffect] attached to explicit [targets].
  ///
  /// * [targets]: The collection of reactive [What] nodes to monitor.
  /// * [duration]: The minimum time interval between consecutive executions.
  /// * [action]: The untracked callback to execute when triggered.
  /// * [guard]: Optional predicate gating execution and preserving tickets when returning `false`.
  /// * [leading]: Whether to execute [action] on the leading edge of the time window. Defaults to `true`.
  /// * [trailing]: Whether to execute [action] on the trailing edge if mutations occurred during the window. Defaults to `true`.
  /// * [take]: Optional maximum number of times this effect may execute before early teardown.
  /// * [onUncaughtError]: Optional error callback invoked when [action] or [guard] throws an uncaught exception.
  ///
  /// **Requires:**
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a [ThrottleEffect] attached to [targets].
  ///
  /// ## Examples
  /// ```dart
  /// final scroll = WhatController(0.0);
  /// final effect = ThrottleEffect(
  ///   [scroll.what],
  ///   const Duration(milliseconds: 100),
  ///   () => syncScroll(scroll.what.peek),
  /// );
  /// ```
  factory ThrottleEffect(
    Iterable<What> targets,
    Duration duration,
    void Function() action, {
    bool Function()? guard,
    bool leading,
    bool trailing,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _ManifestThrottleEffect;

  /// Creates an optimized unary [ThrottleEffect] attached to a single explicit [target].
  ///
  /// * [target]: The single [What] node to monitor.
  /// * [duration]: The minimum time interval between consecutive executions.
  /// * [action]: The untracked callback to execute when triggered.
  /// * [guard]: Optional predicate gating execution and preserving tickets when returning `false`.
  /// * [leading]: Whether to execute on the leading edge. Defaults to `true`.
  /// * [trailing]: Whether to execute on the trailing edge. Defaults to `true`.
  /// * [take]: Optional execution limit before early teardown.
  /// * [onUncaughtError]: Optional error handler.
  ///
  /// **Requires:**
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * If [take] is provided, it must be greater than or equal to `0`.
  ///
  /// **Ensures:**
  /// * Returns a unary [ThrottleEffect] attached to [target].
  ///
  /// ## Examples
  /// ```dart
  /// final scroll = WhatController(0.0);
  /// final effect = ThrottleEffect.unary(
  ///   scroll.what,
  ///   const Duration(milliseconds: 100),
  ///   () => syncScroll(scroll.what.peek),
  /// );
  /// ```
  factory ThrottleEffect.unary(
    What target,
    Duration duration,
    void Function() action, {
    bool Function()? guard,
    bool leading,
    bool trailing,
    int? take,
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) = _UnaryManifestThrottleEffect;

  /// The throttling time window duration.
  Duration get duration;

  /// Whether leading edge execution is enabled.
  bool get leading;

  /// Whether trailing edge execution is enabled.
  bool get trailing;
}

// =============================================================================
// Direct .group Extension Suite (Tuples & Iterable)
// =============================================================================

/// Extension granting a 2-tuple of [Effect] instances direct grouping into [EffectGroup].
extension EffectRecord2Extension on (Effect, Effect) {
  /// The underlying [Effect] instances of this pair.
  List<Effect> get effects => [$1, $2];

  /// Bundles this pair of effects into a composite [EffectGroup].
  ///
  /// **Ensures:**
  /// * Returns an [EffectGroup] managing the aggregated lifecycle of this pair.
  @pragma('vm:prefer-inline')
  EffectGroup get group => EffectGroup(effects);
}

/// Extension granting a 3-tuple of [Effect] instances direct grouping into [EffectGroup].
extension EffectRecord3Extension on (Effect, Effect, Effect) {
  /// The underlying [Effect] instances of this triplet.
  List<Effect> get effects => [$1, $2, $3];

  /// Bundles this triplet of effects into a composite [EffectGroup].
  ///
  /// **Ensures:**
  /// * Returns an [EffectGroup] managing the aggregated lifecycle of this triplet.
  @pragma('vm:prefer-inline')
  EffectGroup get group => EffectGroup(effects);
}

/// Extension granting a 4-tuple of [Effect] instances direct grouping into [EffectGroup].
extension EffectRecord4Extension on (Effect, Effect, Effect, Effect) {
  /// The underlying [Effect] instances of this 4-tuple.
  List<Effect> get effects => [$1, $2, $3, $4];

  /// Bundles this 4-tuple of effects into a composite [EffectGroup].
  ///
  /// **Ensures:**
  /// * Returns an [EffectGroup] managing the aggregated lifecycle of this 4-tuple.
  @pragma('vm:prefer-inline')
  EffectGroup get group => EffectGroup(effects);
}

/// Extension granting a 5-tuple of [Effect] instances direct grouping into [EffectGroup].
extension EffectRecord5Extension on (Effect, Effect, Effect, Effect, Effect) {
  /// The underlying [Effect] instances of this 5-tuple.
  List<Effect> get effects => [$1, $2, $3, $4, $5];

  /// Bundles this 5-tuple of effects into a composite [EffectGroup].
  ///
  /// **Ensures:**
  /// * Returns an [EffectGroup] managing the aggregated lifecycle of this 5-tuple.
  @pragma('vm:prefer-inline')
  EffectGroup get group => EffectGroup(effects);
}

/// Extension granting collections of [Effect] instances direct grouping into [EffectGroup].
extension EffectIterableExtension on Iterable<Effect> {
  /// The underlying [Effect] instances of this collection.
  Iterable<Effect> get effects => this;

  /// Bundles this collection of effects into a composite [EffectGroup].
  ///
  /// **Ensures:**
  /// * Returns an [EffectGroup] managing the aggregated lifecycle of this collection.
  @pragma('vm:prefer-inline')
  EffectGroup get group => EffectGroup(this);
}
