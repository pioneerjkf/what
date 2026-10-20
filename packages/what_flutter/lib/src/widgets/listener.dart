// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Signature for reactive side-effect callback receiving [BuildContext] and current state.
typedef WhatListenerActionCallback<T> = void Function(
    BuildContext context, T state);

/// Signature for handling uncaught errors in [WhatListener].
typedef WhatListenerUncaughtErrorCallback = void Function(
  BuildContext context,
  Object error,
  StackTrace stackTrace,
);

/// Backwards compatibility alias for [WhatListenerActionCallback].
@Deprecated('Use WhatListenerActionCallback instead.')
typedef WhatUnaryListenerActionCallback<T> = WhatListenerActionCallback<T>;

/// Backwards compatibility alias for [WhatListener].
@Deprecated('Use WhatListener instead.')
typedef UnaryWhatListener<T> = WhatListener<T>;

// =============================================================================
// WhatListener Widget (Reactive Side-Effect Listener)
// =============================================================================

/// A reactive side-effect listener widget bound 1:1 to a single [target] node passing state directly to [action].
///
/// Composes an internal unary [Effect] via [EffectRunner] microtask runner, guaranteeing execution outside the Flutter
/// build phase to prevent re-entrancy conflicts without rebuilding the widget tree (Rebuild Count: 0).
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                         WhatListener Lifecycle                         │
/// ├────────────────────────────────────────────────────────────────────────┤
/// │                                                                        │
/// │   [ Upstream Target Mutates ]                                          │
/// │                │                                                       │
/// │                ▼ (Phase 1: Synchronous Invalidation Wave)              │
/// │   [ Effect Terminal Invalidation ]                                     │
/// │                │                                                       │
/// │                ▼ (Microtask Scheduling)                                │
/// │   [ EffectRunner Event-Loop Microtask Flush ]                          │
/// │                │                                                       │
/// │                ├─► Guard Verification: guard(untracked(target))        │
/// │                │                                                       │
/// │                ▼                                                       │
/// │   [ action(context, state) Executed ] ──► Rebuild Count: 0 (Isolated)  │
/// │                                                                        │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Rebuild Boundary Isolation (0 Rebuilds)**: Executes purely as a side-effect sink without
///    invalidating or rebuilding the widget element tree ([Element.markNeedsBuild] is never called).
/// 2. **0-Run on Mount Invariant**: Establishes dependency edges upon mount with zero initial callback
///    executions; [action] runs strictly upon subsequent mutations.
/// 3. **Microtask Deferral**: Defers callback execution to the microtask queue, preventing state mutations
///    from colliding with Flutter's ongoing build or layout passes.
/// 4. **Direct State Injection**: Automatically forwards the current state payload to [action],
///    eliminating manual `untracked(...)` dereferencing.
/// 5. **Two-Tier Temporal Compliance**: Supports dedicated time-domain rate limiting
///    ([WhatListener.debounce], [WhatListener.throttle]) operating strictly at the side-effect terminal level.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT trigger state mutations inside [action] that invalidate [target] without an exit condition,
///   as this triggers re-entrancy feedback loops.
/// - Do NOT use [WhatListener] for rebuilding UI; use [composed] or [WhatWidget] for declarative UI rendering.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Unbounded reentrancy loop
/// WhatListener<int>(counter.what, (context, count) {
///   counter.set(count + 1); // Infinite loop!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Guarded or strictly side-effecting action (navigation, dialogs, snackbars)
/// WhatListener<User?>(authWhat, (context, user) {
///   if (user != null) {
///     Navigator.of(context).pushReplacementNamed('/dashboard');
///   }
/// });
/// ```
///
/// ## Multiple Targets Composition
/// To monitor multiple state nodes simultaneously, compose them into a single derived node via `computed`:
/// ```dart
/// final checkoutState = computed((via) => (
///   user: via(authWhat),
///   count: via(cartWhat).length,
/// ));
///
/// WhatListener(checkoutState, (context, state) {
///   showCheckoutBanner(context, state.user, state.count);
/// });
/// ```
///
/// ## Examples
/// ```dart
/// WhatListener<int>(
///   counter.what,
///   (context, count) => showToast(context, 'Count: $count'),
///   guard: (count) => count > 5,
///   child: const MainContent(),
/// );
/// ```
base class WhatListener<T> extends Widget {
  /// Creates a reactive side-effect listener monitoring [target].
  ///
  /// * [target]: The single [What] node to observe for mutations.
  /// * [action]: Side-effect callback invoked when [target] mutates.
  /// * [key]: Optional widget key.
  /// * [guard]: Optional boolean predicate gating execution based on current state. When false, execution is skipped.
  /// * [take]: Optional maximum number of times this listener may execute before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback invoked on uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [action] must be a non-null side-effect callback.
  /// * [take], if provided, must be greater than or equal to 0.
  ///
  /// **Ensures:**
  /// * Returns a [WhatListener] widget bound to [target] with guaranteed 0-rebuild execution.
  const WhatListener(
    this.target,
    this.action, {
    super.key,
    this.guard,
    this.take,
    this.onUncaughtError,
    this.child,
  });

  /// Creates a debounced reactive side-effect listener monitoring [target].
  ///
  /// Delays [action] execution until upstream invalidations have ceased for at least [duration].
  ///
  /// * [target]: The single [What] node to observe.
  /// * [action]: Side-effect callback invoked when the debounce window settles.
  /// * [duration]: The silence window duration required before executing [action].
  /// * [key]: Optional widget key.
  /// * [leading]: Whether to execute [action] immediately on the first mutation. Defaults to `false`.
  /// * [trailing]: Whether to execute [action] on the trailing edge after silence elapses. Defaults to `true`.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional maximum number of times this listener may execute before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback invoked on uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [duration] must be a non-negative [Duration].
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * [take], if provided, must be greater than or equal to 0.
  ///
  /// **Ensures:**
  /// * Returns a debounced [WhatListener] executing [action] after settling.
  ///
  /// ## Examples
  /// ```dart
  /// WhatListener<String>.debounce(
  ///   searchWhat,
  ///   (context, query) => fetchSearchResults(context, query),
  ///   duration: const Duration(milliseconds: 300),
  /// );
  /// ```
  const factory WhatListener.debounce(
    What<T> target,
    WhatListenerActionCallback<T> action, {
    Key? key,
    required Duration duration,
    bool leading,
    bool trailing,
    bool Function(T state)? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) = _WhatDebounceListener<T>;

  /// Creates a throttled reactive side-effect listener monitoring [target].
  ///
  /// Suppresses rapid consecutive invalidations, executing [action] at most once per [duration] window.
  ///
  /// * [target]: The single [What] node to observe.
  /// * [action]: Side-effect callback invoked when triggered.
  /// * [duration]: The minimum time interval between consecutive executions.
  /// * [key]: Optional widget key.
  /// * [leading]: Whether to execute [action] on the leading edge. Defaults to `true`.
  /// * [trailing]: Whether to execute [action] on the trailing edge if mutations occurred during the window. Defaults to `true`.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional maximum number of times this listener may execute before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback invoked on uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [duration] must be a non-negative [Duration].
  /// * At least one of [leading] or [trailing] must be `true`.
  /// * [take], if provided, must be greater than or equal to 0.
  ///
  /// **Ensures:**
  /// * Returns a throttled [WhatListener] rate-limiting [action] execution.
  ///
  /// ## Examples
  /// ```dart
  /// WhatListener<double>.throttle(
  ///   scrollOffsetWhat,
  ///   (context, offset) => syncHaptics(context, offset),
  ///   duration: const Duration(milliseconds: 100),
  /// );
  /// ```
  const factory WhatListener.throttle(
    What<T> target,
    WhatListenerActionCallback<T> action, {
    Key? key,
    required Duration duration,
    bool leading,
    bool trailing,
    bool Function(T state)? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) = _WhatThrottleListener<T>;

  /// The single [What] node to monitor.
  final What<T> target;

  /// Side-effect callback invoked when [target] mutates, receiving [BuildContext] and current state.
  final WhatListenerActionCallback<T> action;

  /// Optional predicate gating execution based on current state.
  final bool Function(T state)? guard;

  /// Optional limit on execution count before automatic deactivation (Early Teardown).
  final int? take;

  /// Optional error callback invoked when an uncaught exception is thrown in [action] or [guard].
  final WhatListenerUncaughtErrorCallback? onUncaughtError;

  /// Optional static child widget preserved across reactive notifications.
  final Widget? child;

  @override
  ComponentElement createElement() => _WhatListenerElement<T>(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<What<T>>('target', target));
    properties.add(ObjectFlagProperty<WhatListenerActionCallback<T>>.has(
        'action', action));
    properties.add(IntProperty('take', take, defaultValue: null));
  }
}
