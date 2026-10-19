// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Signature for multi-target side-effect callback receiving [BuildContext].
typedef WhatListenerActionCallback = void Function(BuildContext context);

/// Signature for unary side-effect callback receiving [BuildContext] and current state.
typedef WhatUnaryListenerActionCallback<T> = void Function(
    BuildContext context, T state);

/// Signature for handling uncaught errors in [WhatListener] and [UnaryWhatListener].
typedef WhatListenerUncaughtErrorCallback = void Function(
  BuildContext context,
  Object error,
  StackTrace stackTrace,
);

// =============================================================================
// WhatListener Widget (Multi-Target Manifest Listener)
// =============================================================================

/// A reactive side-effect listener widget that monitors explicit [targets] without rebuilding the widget tree.
///
/// Composes a high-performance multi-target [Effect] via [EffectRunner] internally, deferring executions
/// to the microtask queue to shield the Flutter build phase from re-entrancy conflicts.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                         WhatListener Lifecycle                         │
/// ├────────────────────────────────────────────────────────────────────────┤
/// │                                                                        │
/// │   [ Upstream Targets Mutate ]                                          │
/// │                │                                                       │
/// │                ▼ (Phase 1: Synchronous Invalidation Wave)              │
/// │   [ Effect Terminal Invalidation ]                                     │
/// │                │                                                       │
/// │                ▼ (Microtask Scheduling)                                │
/// │   [ EffectRunner Event-Loop Microtask Flush ]                          │
/// │                │                                                       │
/// │                ├─► Gating: guard() == true (if provided)               │
/// │                ├─► Ticket Check: take > 0 (if provided)                │
/// │                │                                                       │
/// │                ▼                                                       │
/// │   [ action(context) Executed ]  ──► Rebuild Count: 0 (No UI Invalidation)│
/// │                                                                        │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Rebuild Boundary Isolation (0 Rebuilds)**: Executes purely as a side-effect sink without
///    invalidating or rebuilding the widget element tree ([Element.markNeedsBuild] is never called).
/// 2. **0-Run on Mount Invariant**: Because [targets] are declared explicitly, the listener establishes
///    dependency edges upon mount with zero initial callback executions; [action] runs strictly
///    upon subsequent mutations.
/// 3. **Microtask Deferral**: Defers callback execution to the microtask queue, preventing state mutations
///    from colliding with Flutter's ongoing build or layout passes.
/// 4. **Two-Tier Temporal Compliance**: Supports dedicated time-domain rate limiting
///    ([WhatListener.debounce], [WhatListener.throttle]) operating strictly at the side-effect terminal level.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT trigger state mutations inside [action] that invalidate any node in [targets] without an exit condition,
///   as this triggers re-entrancy feedback loops.
/// - Do NOT use [WhatListener] for rebuilding UI; use [composed] or [WhatWidget] for declarative UI rendering.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Triggering UI rebuilds via setState inside listener
/// WhatListener([counter.what], (context) {
///   setState(() {}); // Breaks 0-rebuild invariant!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Use purely for 1-shot side effects (navigation, dialogs, snackbars)
/// WhatListener([authWhat], (context) {
///   if (authWhat.peek case final user?) {
///     Navigator.of(context).pushReplacementNamed('/dashboard');
///   }
/// });
/// ```
///
/// ## Unary Single-Target Listening
/// To monitor a single [What] node and receive its state directly, use [UnaryWhatListener]
/// or the convenient inline functor `what.listen`.
///
/// ## Examples
/// ```dart
/// WhatListener(
///   [authWhat, errorWhat],
///   (context) {
///     if (errorWhat.peek case final error?) {
///       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
///     }
///   },
///   guard: () => errorWhat.peekState.hasData,
///   take: 1,
///   child: const LoginForm(),
/// );
/// ```
base class WhatListener extends Widget {
  /// Creates a multi-target reactive side-effect listener monitoring [targets].
  ///
  /// * [targets]: The collection of reactive [What] nodes to observe for mutations.
  /// * [action]: Side-effect callback invoked when any observed target mutates.
  /// * [key]: Optional widget key.
  /// * [guard]: Optional boolean predicate gating execution. When false, execution is skipped and [take] tickets are preserved.
  /// * [take]: Optional limit on execution count before automatic deactivation (Early Teardown).
  /// * [onUncaughtError]: Optional error boundary callback invoked on uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [targets] must not be empty.
  /// * [take], if provided, must be a positive integer ($> 0$).
  ///
  /// **Ensures:**
  /// * Returns a [WhatListener] widget bound to [targets] with guaranteed 0-rebuild execution.
  const WhatListener(
    this.targets,
    this.action, {
    super.key,
    this.guard,
    this.take,
    this.onUncaughtError,
    this.child,
  });

  /// Creates a debounced multi-target reactive side-effect listener monitoring [targets].
  ///
  /// Delays [action] execution until upstream invalidations have ceased for at least [duration].
  ///
  /// * [targets]: The collection of reactive [What] nodes to observe.
  /// * [action]: Side-effect callback invoked when the debounce window settles.
  /// * [duration]: The silence window duration required before executing [action].
  /// * [key]: Optional widget key.
  /// * [leading]: Whether to execute [action] immediately on the first mutation. Defaults to `false`.
  /// * [trailing]: Whether to execute [action] on the trailing edge after silence elapses. Defaults to `true`.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback invoked on uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [duration] must be a non-negative [Duration].
  /// * [targets] must not be empty.
  /// * At least one of [leading] or [trailing] must be `true`.
  ///
  /// **Ensures:**
  /// * Returns a debounced [WhatListener] executing [action] after settling.
  ///
  /// ## Examples
  /// ```dart
  /// WhatListener.debounce(
  ///   [queryWhat, filterWhat],
  ///   (context) => fetchSearchResults(context),
  ///   duration: const Duration(milliseconds: 300),
  /// );
  /// ```
  const factory WhatListener.debounce(
    Iterable<What> targets,
    WhatListenerActionCallback action, {
    Key? key,
    required Duration duration,
    bool leading,
    bool trailing,
    bool Function()? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) = _WhatDebounceListener;

  /// Creates a throttled multi-target reactive side-effect listener monitoring [targets].
  ///
  /// Suppresses rapid consecutive invalidations, executing [action] at most once per [duration] window.
  ///
  /// * [targets]: The collection of reactive [What] nodes to observe.
  /// * [action]: Side-effect callback invoked when triggered.
  /// * [duration]: The minimum time interval between consecutive executions.
  /// * [key]: Optional widget key.
  /// * [leading]: Whether to execute [action] on the leading edge. Defaults to `true`.
  /// * [trailing]: Whether to execute [action] on the trailing edge if mutations occurred during the window. Defaults to `true`.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback invoked on uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [duration] must be a non-negative [Duration].
  /// * [targets] must not be empty.
  /// * At least one of [leading] or [trailing] must be `true`.
  ///
  /// **Ensures:**
  /// * Returns a throttled [WhatListener] rate-limiting [action] execution.
  ///
  /// ## Examples
  /// ```dart
  /// WhatListener.throttle(
  ///   [scrollOffsetWhat],
  ///   (context) => syncHaptics(context),
  ///   duration: const Duration(milliseconds: 100),
  /// );
  /// ```
  const factory WhatListener.throttle(
    Iterable<What> targets,
    WhatListenerActionCallback action, {
    Key? key,
    required Duration duration,
    bool leading,
    bool trailing,
    bool Function()? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) = _WhatThrottleListener;

  /// The collection of reactive [What] nodes to monitor for mutations.
  final Iterable<What> targets;

  /// Side-effect callback invoked when any observed target mutates.
  final WhatListenerActionCallback action;

  /// Optional boolean predicate gating execution. When false, execution is skipped and [take] tickets are preserved.
  final bool Function()? guard;

  /// Optional limit on execution count before automatic deactivation (Early Teardown).
  final int? take;

  /// Optional error callback invoked when an uncaught exception is thrown in [action] or [guard].
  final WhatListenerUncaughtErrorCallback? onUncaughtError;

  /// Optional static child widget preserved across reactive notifications.
  final Widget? child;

  @override
  ComponentElement createElement() => _WhatListenerElement(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<What>('targets', targets));
    properties.add(
        ObjectFlagProperty<WhatListenerActionCallback>.has('action', action));
    properties.add(IntProperty('take', take, defaultValue: null));
  }
}

// =============================================================================
// UnaryWhatListener Widget (Unary Single-Target Reactive Listener)
// =============================================================================

/// A reactive side-effect listener widget bound 1:1 to a single [target] node passing state directly to [action].
///
/// Composes an internal unary [Effect] via [EffectRunner] microtask runner, guaranteeing execution outside the Flutter
/// build phase to prevent re-entrancy conflicts without rebuilding the widget tree (Rebuild Count: 0).
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                       UnaryWhatListener Lifecycle                      │
/// ├────────────────────────────────────────────────────────────────────────┤
/// │                                                                        │
/// │   [ Upstream Target Mutates ]                                          │
/// │                │                                                       │
/// │                ▼ (Unary Effect Invalidation)                           │
/// │   [ EffectRunner Microtask Scheduled ]                                 │
/// │                │                                                       │
/// │                ▼                                                       │
/// │   [ Action Execution Turn ]                                            │
/// │        ├─► Guard Verification: guard(target.peek)                      │
/// │        ├─► Ticket Decrement: take count                                │
/// │        └─► action(context, target.peek)  (Rebuild Count: 0)            │
/// │                                                                        │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Direct State Injection**: Automatically extracts and forwards the current payload to [action],
///    eliminating manual `.peek` dereferencing in the callback.
/// 2. **0-Rebuild Execution**: Pure side-effect boundary leaving the widget tree completely intact.
/// 3. **0-Run on Mount Invariant**: Skips initial evaluation upon mount; runs strictly upon subsequent mutations.
/// 4. **Microtask Deferral**: Defers execution to the microtask queue to avoid re-entrancy conflicts with
///    Flutter's active build/layout passes.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Avoid modifying the observed [target] directly inside [action] without a terminating [guard],
///   as this introduces unbounded re-entrancy cascades.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Unbounded reentrancy loop
/// UnaryWhatListener<int>(counter.what, (context, count) {
///   counter.set(count + 1); // Infinite loop!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Guarded or strictly side-effecting action
/// UnaryWhatListener<int>(counter.what, (context, count) {
///   if (count > 10) showMilestoneAlert(context);
/// }, take: 1);
/// ```
///
/// ## Examples
/// ```dart
/// UnaryWhatListener<int>(
///   counter.what,
///   (context, count) => showToast(context, 'Count: $count'),
///   guard: (count) => count > 5,
///   take: 1,
///   child: const MainContent(),
/// );
/// ```
base class UnaryWhatListener<T> extends Widget {
  /// Creates a unary reactive side-effect listener attached strictly to [target].
  ///
  /// * [target]: The single [What] node to observe.
  /// * [action]: Side-effect callback invoked when [target] mutates.
  /// * [key]: Optional widget key.
  /// * [guard]: Optional predicate gating execution based on current state.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback for uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [action] must be a non-null side-effect callback.
  /// * [take], if provided, must be a positive integer ($> 0$).
  ///
  /// **Ensures:**
  /// * Returns a [UnaryWhatListener] attached 1:1 to [target] with guaranteed 0-rebuild execution.
  const UnaryWhatListener(
    this.target,
    this.action, {
    super.key,
    this.guard,
    this.take,
    this.onUncaughtError,
    this.child,
  });

  /// Creates a debounced unary reactive side-effect listener attached strictly to [target].
  ///
  /// Delays [action] execution until [target] mutations have ceased for at least [duration].
  ///
  /// * [target]: The single [What] node to observe.
  /// * [action]: Side-effect callback receiving [BuildContext] and current state.
  /// * [duration]: The silence window duration required before executing [action].
  /// * [key]: Optional widget key.
  /// * [leading]: Whether to execute [action] immediately on the first mutation. Defaults to `false`.
  /// * [trailing]: Whether to execute [action] on the trailing edge after silence elapses. Defaults to `true`.
  /// * [guard]: Optional predicate gating execution based on current state.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback for uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [duration] must be a non-negative [Duration].
  /// * At least one of [leading] or [trailing] must be `true`.
  ///
  /// **Ensures:**
  /// * Returns a debounced [UnaryWhatListener] attached 1:1 to [target].
  ///
  /// ## Examples
  /// ```dart
  /// UnaryWhatListener<String>.debounce(
  ///   searchWhat,
  ///   (context, query) => fetchAutocomplete(context, query),
  ///   duration: const Duration(milliseconds: 300),
  /// );
  /// ```
  const factory UnaryWhatListener.debounce(
    What<T> target,
    WhatUnaryListenerActionCallback<T> action, {
    Key? key,
    required Duration duration,
    bool leading,
    bool trailing,
    bool Function(T state)? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) = _UnaryWhatDebounceListener<T>;

  /// Creates a throttled unary reactive side-effect listener attached strictly to [target].
  ///
  /// Suppresses rapid consecutive mutations on [target], executing [action] at most once per [duration] window.
  ///
  /// * [target]: The single [What] node to observe.
  /// * [action]: Side-effect callback receiving [BuildContext] and current state.
  /// * [duration]: The minimum time interval between consecutive executions.
  /// * [key]: Optional widget key.
  /// * [leading]: Whether to execute [action] on the leading edge. Defaults to `true`.
  /// * [trailing]: Whether to execute [action] on the trailing edge if mutations occurred during the window. Defaults to `true`.
  /// * [guard]: Optional predicate gating execution based on current state.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback for uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [duration] must be a non-negative [Duration].
  /// * At least one of [leading] or [trailing] must be `true`.
  ///
  /// **Ensures:**
  /// * Returns a throttled [UnaryWhatListener] attached 1:1 to [target].
  ///
  /// ## Examples
  /// ```dart
  /// UnaryWhatListener<double>.throttle(
  ///   sliderPositionWhat,
  ///   (context, position) => updatePreview(context, position),
  ///   duration: const Duration(milliseconds: 50),
  /// );
  /// ```
  const factory UnaryWhatListener.throttle(
    What<T> target,
    WhatUnaryListenerActionCallback<T> action, {
    Key? key,
    required Duration duration,
    bool leading,
    bool trailing,
    bool Function(T state)? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) = _UnaryWhatThrottleListener<T>;

  /// The single [What] node to monitor.
  final What<T> target;

  /// Side-effect callback invoked when [target] mutates, receiving [BuildContext] and current state.
  final WhatUnaryListenerActionCallback<T> action;

  /// Optional predicate gating execution based on current state.
  final bool Function(T state)? guard;

  /// Optional limit on execution count before automatic deactivation (Early Teardown).
  final int? take;

  /// Optional error callback invoked when an uncaught exception is thrown in [action] or [guard].
  final WhatListenerUncaughtErrorCallback? onUncaughtError;

  /// Optional static child widget preserved across reactive notifications.
  final Widget? child;

  @override
  ComponentElement createElement() => _UnaryWhatListenerElement<T>(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<What<T>>('target', target));
    properties.add(ObjectFlagProperty<WhatUnaryListenerActionCallback<T>>.has(
        'action', action));
    properties.add(IntProperty('take', take, defaultValue: null));
  }
}
