// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Canonical Functor Cascade Extensions
// =============================================================================

/// Extensions on a single [What] providing the [build] and [listen] functor entry points.
///
/// ## Canonical Invocation & Cascade Hierarchy
/// ```text
/// what
///  ├── .build                    ((context, data) => ...)       [Declarative UI Rendering]
///  │    ├── .child               ((context, data, child) => ..., child: W)
///  │    ├── .children            ((context, data, children) => ..., children: [...])
///  │    └── .async               (data: ..., loading: ..., error: ..., empty: ...)
///  │
///  └── .listen                   ((context, state) => ...)      [0-Rebuild Side Effects]
///       ├── .debounce            (duration, (context, state) => ...)
///       └── .throttle            (duration, (context, state) => ...)
/// ```
///
/// Built using Dart extension types (`extension type const`), `what.build` and `what.listen` incur
/// **zero runtime allocation overhead** while providing a fully type-safe, fluent, and canonical API for
/// inline reactive UI composition and 0-rebuild side-effect dispatch.
///
/// ## 2-Phase LPDAG & Terminal Invariant Architecture
/// Unlike [composed] which uses [RawComputedTerminal] for dynamic multi-dependency discovery,
/// `what.build` provisions a dedicated 1:1 [RawWhatTerminal] hosted inside an internal [ComponentElement]
/// (`_InlineSingleWhatElement`, etc.) mixing in `_WhatTerminalElementMixin<T>`.
///
/// ## System Architectural Flow
/// ```text
/// [ Upstream What<T> Mutates ]
///              │
///              │ (Phase 1: O(1) Push-Dirty Invalidation)
///              ▼
/// [ RawWhatTerminal<T>.onInvalidated: markNeedsBuild() ]
///              │
///              │ (Flutter Render Pipeline Scheduling)
///              ▼
/// [ _InlineSingleWhatElement.build() ]
///              │
///              ├─► .build()        ──► Evaluates builder(context, what.peek)
///              ├─► .build.child()  ──► If hasData: builder(..., child) | Else: returns child (fallback)
///              └─► .build.children ──► If hasData: builder(..., children) | Else: returns SizedBox.shrink()
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero-Copy Auto-Healing Gateway**: Directly routes dirty invalidation pulses to [Element.markNeedsBuild]
///    in $O(1)$ without allocating intermediate tracking collections.
/// 2. **Empty/Error State Fallback**: When [WhatState.hasData] is `false`, builder variants with a static
///    `child` parameter return the fallback `child` (or [SizedBox.shrink] for children), protecting
///    against extraction exceptions during uninitialized states.
/// 3. **Subtree Isolation**: Static subtrees passed via `child` or `children` are pre-constructed and
///    bypass re-evaluation when the enclosing reactive element rebuilds.
/// 4. **Zero Runtime Allocation**: Backed by `extension type const`, dispatching directly to dedicated 1:1 elements.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Avoid instantiating static child trees inside the builder closure, which forces them to rebuild on every emission.
///   Pass static subtrees to the `child:` or `children:` parameter to isolate them from rebuilds.
/// - When invoking `what.build((context, data) => ...)`, ensure this [What] node contains valid data.
///   If the target node is uninitialized or in an error state, reading `.peek` throws [WhatSnapshotExtractionException].
///   Use `what.build.child` or `what.build.async` for safe uninitialized/asynchronous state handling.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Static icon/chart recreated on every emission
/// counterWhat.build(
///   (context, count) => Row(children: [Text('$count'), const HeavyChartWidget()]),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Static subtree cached and passed via child parameter
/// counterWhat.build.child(
///   (context, count, child) => Row(children: [Text('$count'), child]),
///   child: const HeavyChartWidget(),
/// );
/// ```
extension WhatFlutterExtension<T> on What<T> {
  /// Entry point for inline reactive build functors.
  @pragma('vm:prefer-inline')
  WhatBuildFunctor<T> get build => WhatBuildFunctor._(this);

  /// Entry point for inline reactive side-effect listener functors.
  @pragma('vm:prefer-inline')
  WhatListenFunctor<T> get listen => WhatListenFunctor._(this);
}

/// Zero-cost compile-time functor for [WhatFlutterExtension.build].
extension type const WhatBuildFunctor<T>._(What<T> _what) {
  /// Creates an inline reactive widget bound 1:1 to this [What<T>] node.
  ///
  /// * [builder]: Pure widget construction callback receiving [BuildContext] and current data payload.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure widget construction callback.
  /// * [_what] should contain valid data of type [T]. If evaluated while [_what] has no data,
  ///   reading `.peek` throws [WhatSnapshotExtractionException]. For uninitialized or asynchronous states,
  ///   use [child] or [async].
  ///
  /// **Ensures:**
  /// * Returns a lightweight reactive [Widget] bound 1:1 to [_what].
  ///
  /// ## Examples
  /// ```dart
  /// countWhat.build((context, count) => Text('Count: $count'));
  /// ```
  @pragma('vm:prefer-inline')
  Widget call(
    Widget Function(BuildContext context, T data) builder, {
    Key? key,
  }) =>
      _InlineSingleWhatWidget<T>(
        key: key,
        what: _what,
        builder: builder,
      );

  /// Creates an inline reactive widget with an isolated static [child] subtree and fallback protection.
  ///
  /// When [_what] contains valid data, invokes [builder] with [BuildContext], data payload, and [child].
  /// When [_what] does not contain data ([WhatState.hasData] == false), returns [child] directly,
  /// protecting against extraction exceptions during uninitialized states.
  ///
  /// * [builder]: Reactive builder callback receiving [BuildContext], current data payload, and cached [child].
  /// * [child]: The static subtree to preserve across rebuilds, also used as fallback when uninitialized.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure widget construction callback.
  ///
  /// **Ensures:**
  /// * Returns a reactive [Widget] isolating [child] from rebuilds and using [child] as uninitialized fallback.
  ///
  /// ## Examples
  /// ```dart
  /// userWhat.build.child(
  ///   (context, user, child) => Row(children: [Text(user.name), child]),
  ///   child: const HeavyAvatar(),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget child(
    Widget Function(BuildContext context, T data, Widget child) builder, {
    required Widget child,
    Key? key,
  }) =>
      _InlineSingleWhatWithChildWidget<T>(
        key: key,
        what: _what,
        builder: builder,
        child: child,
      );

  /// Creates an inline reactive widget with isolated static [children] subtrees and fallback protection.
  ///
  /// When [_what] contains valid data, invokes [builder] with [BuildContext], data payload, and [children].
  /// When [_what] does not contain data ([WhatState.hasData] == false), returns [SizedBox.shrink],
  /// protecting against extraction exceptions during uninitialized states.
  ///
  /// * [builder]: Reactive builder callback receiving [BuildContext], current data payload, and cached [children].
  /// * [children]: The static subtrees to preserve across rebuilds.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure widget construction callback.
  ///
  /// **Ensures:**
  /// * Returns a reactive [Widget] isolating [children] from rebuilds.
  ///
  /// ## Examples
  /// ```dart
  /// menuWhat.build.children(
  ///   (context, menu, children) => Column(children: [Header(menu.title), ...children]),
  ///   children: const [HeavyChart(), HeavyFooter()],
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget children(
    Widget Function(BuildContext context, T data, List<Widget> children)
        builder, {
    required List<Widget> children,
    Key? key,
  }) =>
      _InlineSingleWhatWithChildrenWidget<T>(
        key: key,
        what: _what,
        builder: builder,
        children: children,
      );

  /// Creates an inline reactive widget handling all 4 asynchronous states declaratively.
  ///
  /// Combines `data`, `loading`, `error`, and `empty` into a clean inline reactive widget
  /// backed by [WhatAsyncBuilder] with native Stale-While-Revalidate (SWR) preservation.
  ///
  /// * [key]: Optional widget key.
  /// * [data]: Builder callback invoked when target node contains active data.
  /// * [loading]: Builder callback invoked when waiting for asynchronous initialization.
  /// * [error]: Optional builder callback invoked when target node holds an error.
  /// * [empty]: Optional builder callback invoked when data payload is empty.
  /// * [pending]: Optional external boolean node signaling non-blocking in-flight refresh.
  /// * [preserveDataOnPending]: If `true` (default), preserves active data display while pending.
  ///
  /// **Requires:**
  /// * [data] and [loading] callbacks must be non-null.
  ///
  /// **Ensures:**
  /// * Declaratively maps reactive state to the corresponding UI view without nested if-else blocks.
  ///
  /// ## Examples
  /// ```dart
  /// profileWhat.build.async(
  ///   data: (context, user) => ProfileCard(user: user),
  ///   loading: (context) => const ShimmerPlaceholder(),
  ///   error: (context, err, stack) => ErrorCard(error: err),
  ///   empty: (context) => const EmptyCard(),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget async({
    Key? key,
    required Widget Function(BuildContext context, T data) data,
    required Widget Function(BuildContext context) loading,
    Widget Function(BuildContext context, Object error, StackTrace stackTrace)?
        error,
    Widget Function(BuildContext context)? empty,
    What<bool>? pending,
    bool preserveDataOnPending = true,
  }) =>
      WhatAsyncBuilder<T>(
        key: key,
        what: _what,
        data: data,
        loading: loading,
        error: error,
        empty: empty,
        pending: pending,
        preserveDataOnPending: preserveDataOnPending,
      );
}

// =============================================================================
// WhatListenFunctor (Unary Side-Effect Terminal Functor)
// =============================================================================

/// Zero-cost compile-time functor for [WhatFlutterExtension.listen].
extension type const WhatListenFunctor<T>._(What<T> _target) {
  /// Listens to this [What<T>] node and executes [action] when its state mutates without rebuilding.
  ///
  /// Composes a high-performance unary [Effect] via [EffectRunner] internally, deferring executions
  /// to the microtask queue to shield the Flutter build phase from re-entrancy conflicts.
  ///
  /// * [action]: Side-effect callback receiving [BuildContext] and current state payload.
  /// * [key]: Optional widget key.
  /// * [guard]: Optional boolean predicate gating execution. When false, execution is skipped.
  /// * [take]: Optional limit on execution count before automatic deactivation (Early Teardown).
  /// * [onUncaughtError]: Optional error boundary callback for uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [action] must be a non-null side-effect callback.
  /// * [take], if provided, must be a positive integer ($> 0$).
  ///
  /// **Ensures:**
  /// * Returns a [UnaryWhatListener] attached 1:1 to [_target].
  /// * Guarantees 0 rebuilds of the widget tree (Rebuild Count: 0).
  /// * Skips initial evaluation upon mount (0-Run on Mount Invariant); executes strictly upon subsequent mutations.
  ///
  /// ## Examples
  /// ```dart
  /// counter.what.listen(
  ///   (context, count) => showToast(context, 'Count: $count'),
  ///   guard: (count) => count > 5,
  ///   take: 1,
  ///   child: const MainContent(),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget call(
    WhatUnaryListenerActionCallback<T> action, {
    Key? key,
    bool Function(T state)? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) =>
      UnaryWhatListener<T>(
        _target,
        action,
        key: key,
        guard: guard,
        take: take,
        onUncaughtError: onUncaughtError,
        child: child,
      );

  /// Delays [action] execution until mutations on this node have ceased for at least [duration].
  ///
  /// * [duration]: The silence window duration required before executing [action].
  /// * [action]: Side-effect callback receiving [BuildContext] and current state payload.
  /// * [key]: Optional widget key.
  /// * [leading]: Whether to execute [action] immediately on the first mutation. Defaults to `false`.
  /// * [trailing]: Whether to execute [action] on the trailing edge after silence elapses. Defaults to `true`.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback for uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [duration] must be a non-negative [Duration].
  /// * At least one of [leading] or [trailing] must be `true`.
  ///
  /// **Ensures:**
  /// * Returns a debounced [UnaryWhatListener] with guaranteed 0-rebuild execution.
  ///
  /// ## Examples
  /// ```dart
  /// searchWhat.listen.debounce(
  ///   const Duration(milliseconds: 300),
  ///   (context, query) => fetchSuggestions(context, query),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget debounce(
    Duration duration,
    WhatUnaryListenerActionCallback<T> action, {
    Key? key,
    bool leading = false,
    bool trailing = true,
    bool Function(T state)? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) =>
      UnaryWhatListener<T>.debounce(
        _target,
        action,
        duration: duration,
        key: key,
        leading: leading,
        trailing: trailing,
        guard: guard,
        take: take,
        onUncaughtError: onUncaughtError,
        child: child,
      );

  /// Suppresses rapid consecutive mutations on this node, executing [action] at most once per [duration].
  ///
  /// * [duration]: The minimum time interval between consecutive executions.
  /// * [action]: Side-effect callback receiving [BuildContext] and current state payload.
  /// * [key]: Optional widget key.
  /// * [leading]: Whether to execute [action] on the leading edge. Defaults to `true`.
  /// * [trailing]: Whether to execute [action] on the trailing edge if mutations occurred during the window. Defaults to `true`.
  /// * [guard]: Optional boolean predicate gating execution.
  /// * [take]: Optional limit on execution count before automatic deactivation.
  /// * [onUncaughtError]: Optional error boundary callback for uncaught exceptions.
  /// * [child]: Optional static child widget preserved across reactive notifications.
  ///
  /// **Requires:**
  /// * [duration] must be a non-negative [Duration].
  /// * At least one of [leading] or [trailing] must be `true`.
  ///
  /// **Ensures:**
  /// * Returns a throttled [UnaryWhatListener] with guaranteed 0-rebuild execution.
  ///
  /// ## Examples
  /// ```dart
  /// scrollWhat.listen.throttle(
  ///   const Duration(milliseconds: 100),
  ///   (context, offset) => triggerHaptic(context),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget throttle(
    Duration duration,
    WhatUnaryListenerActionCallback<T> action, {
    Key? key,
    bool leading = true,
    bool trailing = true,
    bool Function(T state)? guard,
    int? take,
    WhatListenerUncaughtErrorCallback? onUncaughtError,
    Widget? child,
  }) =>
      UnaryWhatListener<T>.throttle(
        _target,
        action,
        duration: duration,
        key: key,
        leading: leading,
        trailing: trailing,
        guard: guard,
        take: take,
        onUncaughtError: onUncaughtError,
        child: child,
      );
}
