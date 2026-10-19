// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Top-Level Explicit Composed Functor (RawComputedTerminal Backed)
// =============================================================================

/// Top-level architectural functor providing surgical inline reactive widget composition.
///
/// Bridges Flutter's element tree with What's 2-Phase LPDAG engine via an internal [ComponentElement]
/// mixing in `_ReactiveTerminalElementMixin<RawComputedTerminal<Widget>>` and `_ViaTerminalElementMixin`.
/// Evaluates reactive builder closures with an injected [WhatVia] tracker, updating only the exact
/// composed element upon upstream state mutations without rebuilding the surrounding widget tree.
///
/// ## Unified 12-Entrypoint Hierarchy (4 Modes × 3 Child Axes)
/// ```text
/// composed               ((context, via) => ...)
///  ├── .child            ((context, via, child) => ..., child: W)
///  ├── .children         ((context, via, children) => ..., children: [...])
///  │
///  ├── .vsync            ((context, via, vsync) => ...)
///  │    ├── .child       ((context, via, vsync, child) => ..., child: W)
///  │    └── .children    ((context, via, vsync, children) => ..., children: [...])
///  │
///  ├── .animate          (controller, (context, via, controller) => ...)
///  │    ├── .child       (controller, (context, via, controller, child) => ..., child: W)
///  │    └── .children    (controller, (context, via, controller, children) => ..., children: [...])
///  │
///  └── .drive            (onTick, (context, via, value) => ...)
///       ├── .child       (onTick, (context, via, value, child) => ..., child: W)
///       └── .children    (onTick, (context, via, value, children) => ..., children: [...])
/// ```
///
/// ## System Architectural Flow
/// ```text
/// [ Upstream What<T> Mutates ]
///              │
///              │ (Phase 1: O(1) Push-Dirty Invalidation)
///              ▼
/// [ RawComputedTerminal<Widget>.onInvalidated: markNeedsBuild() ]
///              │
///              │ (Flutter Render Pipeline Scheduling)
///              ▼
/// [ _ComposedElement.build() -> terminal.data ]
///              │
///              ├─► If Clean: Returns cached Widget in O(1) (0-Compute)
///              └─► If Dirty: Evaluates user builder(context, via)
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Surgical Rebuild Boundary**: Rebuilds only the exact composed element without invalidating
///    surrounding parent or sibling widget subtrees.
/// 2. **0-Compute Memoization**: Inherits [RawComputedTerminal] cached evaluation, returning the prior
///    widget instance in $O(1)$ when dependencies remain clean.
/// 3. **1-Pass Zero-Allocation Epoch Diffing**: Discards unused dependency branches dynamically in conditional
///    structures without intermediate heap allocation.
/// 4. **Subtree Memoization Isolation**: Supports `.child` and `.children` caching to preserve expensive static
///    subtrees across reactive rebuilds and 60/120fps animation ticks.
///
/// See [ComposedFunctor.call] for primary invocation contracts, parameters, and anti-pattern guidelines.
/// See [ComposedFunctor.child] and [ComposedFunctor.children] for static subtree memoization.
/// See [ComposedVsyncFunctor] for element-level [TickerProvider] provisioning.
/// See [ComposedAnimateFunctor] for durable animation controller binding.
/// See [ComposedDriveFunctor] for continuous frame-ticker drivers.
///
/// ## Examples
/// ```dart
/// final count = WhatController(0);
///
/// Widget build(BuildContext context) {
///   return Column(
///     children: [
///       const Text('Static Header'),
///       composed((context, via) => Text('Count: ${via(count.what)}')),
///     ],
///   );
/// }
/// ```
const composed = ComposedFunctor._();

/// Functor class for creating inline reactive widgets with surgical micro-rebuilds.
final class ComposedFunctor {
  const ComposedFunctor._();

  /// Creates an inline reactive widget that tracks dependencies dynamically and explicitly via [WhatVia].
  ///
  /// * [builder]: Reactive builder callback receiving [BuildContext] and [WhatVia].
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function without synchronous state mutations.
  ///
  /// **Ensures:**
  /// * Returns a lightweight reactive [Widget] bound to the active [WhatVia] tracking scope.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT read `.peek` directly inside [builder] without wrapping in `via(...)`. Directly reading
  ///   `.peek` performs an untracked read and bypasses reactive invalidations.
  /// - Do NOT trigger state mutations inside [builder], as this violates Flutter's single-pass render contract.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Reading .peek directly inside composed
  /// Widget build(BuildContext context) {
  ///   return composed((context, via) => Text('Count: ${counter.what.peek}')); // NEVER rebuilds!
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Explicitly observe via(node)
  /// Widget build(BuildContext context) {
  ///   return composed((context, via) => Text('Count: ${via(counter.what)}')); // Dynamically tracked
  /// }
  /// ```
  ///
  /// ## Examples
  /// ```dart
  /// composed((context, via) {
  ///   final user = via(userWhat);
  ///   return Text('Hello, ${user.name}');
  /// });
  /// ```
  @pragma('vm:prefer-inline')
  Widget call(
    Widget Function(BuildContext context, WhatVia via) builder, {
    Key? key,
  }) =>
      _ComposedWidget(builder, key: key);

  /// Creates an inline reactive widget with an isolated static [child] subtree.
  ///
  /// Prevents redundant widget reconstructions by passing [child] into [builder] as a pre-constructed,
  /// cached subtree. When reactive dependencies mutate, only the outer container evaluates while [child]
  /// bypasses re-evaluation.
  ///
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], and cached [child].
  /// * [child]: The static subtree to preserve across rebuilds. Must not be null.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function.
  ///
  /// **Ensures:**
  /// * Returns a reactive [Widget] preserving [child] across dependency-driven rebuilds.
  ///
  /// ## Examples
  /// ```dart
  /// composed.child(
  ///   (context, via, child) => Padding(
  ///     padding: EdgeInsets.all(via(paddingWhat)),
  ///     child: child,
  ///   ),
  ///   child: const ExpensiveGraphicWidget(),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget child(
    Widget Function(BuildContext context, WhatVia via, Widget child) builder, {
    required Widget child,
    Key? key,
  }) =>
      _ComposedWithChildWidget(
        builder: builder,
        child: child,
        key: key,
      );

  /// Creates an inline reactive widget with isolated static [children] subtrees.
  ///
  /// Prevents redundant widget reconstructions in multi-child layouts (`Row`, `Column`, `Stack`)
  /// where layout properties are reactive but children remain static.
  ///
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], and cached [children].
  /// * [children]: The static subtrees to preserve across rebuilds. Must not be null.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function.
  ///
  /// **Ensures:**
  /// * Returns a reactive [Widget] preserving [children] across dependency-driven rebuilds.
  ///
  /// ## Examples
  /// ```dart
  /// composed.children(
  ///   (context, via, children) => Row(
  ///     mainAxisAlignment: via(alignmentWhat),
  ///     children: children,
  ///   ),
  ///   children: const [SidebarWidget(), MainContentWidget()],
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget children(
    Widget Function(BuildContext context, WhatVia via, List<Widget> children)
        builder, {
    required List<Widget> children,
    Key? key,
  }) =>
      _ComposedWithChildrenWidget(
        builder: builder,
        children: children,
        key: key,
      );

  /// Functor providing element-managed [TickerProvider] ([vsync]) entrypoints.
  ComposedVsyncFunctor get vsync => const ComposedVsyncFunctor._();

  /// Functor providing [DurableAnimationController] binding entrypoints.
  ComposedAnimateFunctor get animate => const ComposedAnimateFunctor._();

  /// Functor providing frame ticker driver entrypoints.
  ComposedDriveFunctor get drive => const ComposedDriveFunctor._();
}

/// Functor class for creating inline reactive widgets with an element-managed [TickerProvider].
final class ComposedVsyncFunctor {
  const ComposedVsyncFunctor._();

  /// Creates an inline reactive widget providing an element-managed [TickerProvider] (`vsync`).
  ///
  /// Allocates a dedicated [TickerProvider] on the host element, eliminating the need for
  /// [StatefulWidget] and [SingleTickerProviderStateMixin]. Automatically synchronizes with
  /// Flutter's [TickerMode] to pause tickers when dormant and disposes cleanly upon unmount.
  ///
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], and [TickerProvider].
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function.
  ///
  /// **Ensures:**
  /// * Returns a reactive [Widget] with an element-managed [TickerProvider].
  ///
  /// ## Examples
  /// ```dart
  /// composed.vsync((context, via, vsync) {
  ///   return LiveClockWidget(vsync: vsync);
  /// });
  /// ```
  @pragma('vm:prefer-inline')
  Widget call(
    Widget Function(BuildContext context, WhatVia via, TickerProvider vsync)
        builder, {
    Key? key,
  }) =>
      _ComposedVsyncWidget(builder, key: key);

  /// Creates an inline reactive widget providing [TickerProvider] and an isolated static [child].
  ///
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], [TickerProvider], and [child].
  /// * [child]: The static subtree to preserve across rebuilds.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function.
  ///
  /// **Ensures:**
  /// * Returns a reactive [Widget] providing [TickerProvider] with cached [child] preservation.
  ///
  /// ## Examples
  /// ```dart
  /// composed.vsync.child(
  ///   (context, via, vsync, child) => AnimatedPanel(
  ///     vsync: vsync,
  ///     child: child,
  ///   ),
  ///   child: const StaticComplexForm(),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget child(
    Widget Function(BuildContext context, WhatVia via, TickerProvider vsync,
            Widget child)
        builder, {
    required Widget child,
    Key? key,
  }) =>
      _ComposedVsyncWithChildWidget(
        builder: builder,
        child: child,
        key: key,
      );

  /// Creates an inline reactive widget providing [TickerProvider] and isolated static [children].
  ///
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], [TickerProvider], and [children].
  /// * [children]: The static subtrees to preserve across rebuilds.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function.
  ///
  /// **Ensures:**
  /// * Returns a reactive [Widget] providing [TickerProvider] with cached [children] preservation.
  ///
  /// ## Examples
  /// ```dart
  /// composed.vsync.children(
  ///   (context, via, vsync, children) => TabCarousel(
  ///     vsync: vsync,
  ///     children: children,
  ///   ),
  ///   children: const [TabOne(), TabTwo()],
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget children(
    Widget Function(BuildContext context, WhatVia via, TickerProvider vsync,
            List<Widget> children)
        builder, {
    required List<Widget> children,
    Key? key,
  }) =>
      _ComposedVsyncWithChildrenWidget(
        builder: builder,
        children: children,
        key: key,
      );
}

/// Functor class for creating inline reactive widgets bound to a [DurableAnimationController].
final class ComposedAnimateFunctor {
  const ComposedAnimateFunctor._();

  /// Creates an inline reactive widget bound to a [DurableAnimationController].
  ///
  /// Under the Single VSYNC Authority model, the underlying element serves as the physical VSYNC
  /// socket host driving [controller], while providing a [ScopedAnimationController] proxy to [builder].
  /// Listeners attached to the scoped proxy's [ScopedAnimationController.view] are automatically purged
  /// when the host widget unmounts, preventing zombie listener leaks.
  ///
  /// * [controller]: The target durable animation controller.
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], and [ScopedAnimationController].
  /// * [onActivate]: Optional lifecycle callback executed when the controller couples and activates.
  /// * [onDeactivate]: Optional lifecycle callback executed when the controller unmounts or detaches.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function.
  ///
  /// **Ensures:**
  /// * Returns an animated reactive [Widget] with automatic ticker management and proxy leak immunity.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Calling [AnimationController.dispose] manually inside widget wrappers or store teardown hooks
  ///   is strictly redundant under What's Inversion of Control dormancy model and can introduce premature
  ///   invalidation bugs. Let the framework govern ticker allocation.
  ///
  /// ## Examples
  /// ```dart
  /// final controller = DurableAnimationController(duration: const Duration(milliseconds: 300));
  ///
  /// Widget build(BuildContext context) {
  ///   return composed.animate(
  ///     controller,
  ///     (context, via, ctrl) => Opacity(
  ///       opacity: ctrl.value,
  ///       child: const Text('Fading Content'),
  ///     ),
  ///   );
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  Widget call(
    DurableAnimationController controller,
    Widget Function(BuildContext context, WhatVia via,
            ScopedAnimationController controller)
        builder, {
    void Function(ScopedAnimationController controller)? onActivate,
    void Function(ScopedAnimationController controller)? onDeactivate,
    Key? key,
  }) =>
      _ComposedAnimateWidget(
        controller: controller,
        builder: builder,
        onActivate: onActivate,
        onDeactivate: onDeactivate,
        key: key,
      );

  /// Creates an inline reactive widget bound to a [DurableAnimationController] with an isolated static [child].
  ///
  /// Isolates static graphic subtrees into [child], ensuring 60/120fps frame-tick rebuilds re-render
  /// only the animated wrapper without recalculating or laying out the static child hierarchy.
  ///
  /// * [controller]: The target durable animation controller.
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], [ScopedAnimationController], and [child].
  /// * [child]: The static subtree to preserve across rebuilds.
  /// * [onActivate]: Optional lifecycle callback executed when the controller couples and activates.
  /// * [onDeactivate]: Optional lifecycle callback executed when the controller unmounts or detaches.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function.
  ///
  /// **Ensures:**
  /// * Returns an animated reactive [Widget] isolating static [child] from frame-tick rebuilds.
  ///
  /// ## Examples
  /// ```dart
  /// composed.animate.child(
  ///   controller,
  ///   (context, via, ctrl, child) => RotationTransition(turns: ctrl.view, child: child),
  ///   child: const HeavyComplexIcon(),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget child(
    DurableAnimationController controller,
    Widget Function(BuildContext context, WhatVia via,
            ScopedAnimationController controller, Widget child)
        builder, {
    required Widget child,
    void Function(ScopedAnimationController controller)? onActivate,
    void Function(ScopedAnimationController controller)? onDeactivate,
    Key? key,
  }) =>
      _ComposedAnimateWithChildWidget(
        controller: controller,
        builder: builder,
        child: child,
        onActivate: onActivate,
        onDeactivate: onDeactivate,
        key: key,
      );

  /// Creates an inline reactive widget bound to a [DurableAnimationController] with isolated static [children].
  ///
  /// * [controller]: The target durable animation controller.
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], [ScopedAnimationController], and [children].
  /// * [children]: The static subtrees to preserve across rebuilds.
  /// * [onActivate]: Optional lifecycle callback executed when the controller couples and activates.
  /// * [onDeactivate]: Optional lifecycle callback executed when the controller unmounts or detaches.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [builder] must be a pure, declarative function.
  ///
  /// **Ensures:**
  /// * Returns an animated reactive [Widget] isolating static [children] from frame-tick rebuilds.
  ///
  /// ## Examples
  /// ```dart
  /// composed.animate.children(
  ///   controller,
  ///   (context, via, ctrl, children) => SlideTransition(
  ///     position: ctrl.drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
  ///     child: Column(children: children),
  ///   ),
  ///   children: const [HeadlineWidget(), BodyWidget()],
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget children(
    DurableAnimationController controller,
    Widget Function(BuildContext context, WhatVia via,
            ScopedAnimationController controller, List<Widget> children)
        builder, {
    required List<Widget> children,
    void Function(ScopedAnimationController controller)? onActivate,
    void Function(ScopedAnimationController controller)? onDeactivate,
    Key? key,
  }) =>
      _ComposedAnimateWithChildrenWidget(
        controller: controller,
        builder: builder,
        children: children,
        onActivate: onActivate,
        onDeactivate: onDeactivate,
        key: key,
      );
}

/// Functor class for creating inline reactive widgets driven by a continuous frame ticker.
final class ComposedDriveFunctor {
  const ComposedDriveFunctor._();

  /// Creates an inline reactive widget driven by a continuous frame ticker.
  ///
  /// Converts continuous elapsed duration pulses from a frame ticker into reactive state of type [T]
  /// via [onTick], re-evaluating [builder] synchronously on each frame tick.
  ///
  /// * [onTick]: Callback converting frame elapsed duration to state of type [T].
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], and current driven value [T].
  /// * [initialValue]: Optional initial value before the first frame tick.
  /// * [distinct]: When `true`, suppresses rebuilds when the driven value equals the previous value.
  /// * [equals]: Optional equality comparison function used when [distinct] is `true`.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [onTick] must be a pure, deterministic conversion function.
  ///
  /// **Ensures:**
  /// * Returns an inline reactive [Widget] driven continuously by element frame ticks.
  ///
  /// ## Examples
  /// ```dart
  /// composed.drive<double>(
  ///   (elapsed) => (elapsed.inMilliseconds % 1000) / 1000.0,
  ///   (context, via, progress) => CircularProgressIndicator(value: progress),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget call<T>(
    T Function(Duration elapsed) onTick,
    Widget Function(BuildContext context, WhatVia via, T value) builder, {
    T? initialValue,
    bool distinct = false,
    bool Function(T previous, T next)? equals,
    Key? key,
  }) =>
      _ComposedDriveWidget<T>(
        onTick: onTick,
        builder: builder,
        initialValue: initialValue,
        distinct: distinct,
        equals: equals,
        key: key,
      );

  /// Creates an inline reactive widget driven by a continuous frame ticker with an isolated static [child].
  ///
  /// * [onTick]: Callback converting frame elapsed duration to state of type [T].
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], current driven value [T], and [child].
  /// * [child]: The static subtree to preserve across frame ticks.
  /// * [initialValue]: Optional initial value before first frame tick.
  /// * [distinct]: When `true`, suppresses rebuilds when computed value equals previous value.
  /// * [equals]: Optional equality comparison function for distinct filtering.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [onTick] must be a pure conversion function.
  ///
  /// **Ensures:**
  /// * Returns an inline reactive [Widget] driven by frame ticks while isolating [child].
  ///
  /// ## Examples
  /// ```dart
  /// composed.drive.child<double>(
  ///   (elapsed) => (elapsed.inMicroseconds % 1000000) / 1000000.0,
  ///   (context, via, progress, child) => Transform.rotate(
  ///     angle: progress * 2 * math.pi,
  ///     child: child,
  ///   ),
  ///   child: const HeavyDialGraphic(),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget child<T>(
    T Function(Duration elapsed) onTick,
    Widget Function(BuildContext context, WhatVia via, T value, Widget child)
        builder, {
    required Widget child,
    T? initialValue,
    bool distinct = false,
    bool Function(T previous, T next)? equals,
    Key? key,
  }) =>
      _ComposedDriveWithChildWidget<T>(
        onTick: onTick,
        builder: builder,
        child: child,
        initialValue: initialValue,
        distinct: distinct,
        equals: equals,
        key: key,
      );

  /// Creates an inline reactive widget driven by a continuous frame ticker with isolated static [children].
  ///
  /// * [onTick]: Callback converting frame elapsed duration to state of type [T].
  /// * [builder]: Reactive builder callback receiving [BuildContext], [WhatVia], current driven value [T], and [children].
  /// * [children]: The static subtrees to preserve across frame ticks.
  /// * [initialValue]: Optional initial value before first frame tick.
  /// * [distinct]: When `true`, suppresses rebuilds when computed value equals previous value.
  /// * [equals]: Optional equality comparison function for distinct filtering.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [onTick] must be a pure conversion function.
  ///
  /// **Ensures:**
  /// * Returns an inline reactive [Widget] driven by frame ticks while isolating [children].
  ///
  /// ## Examples
  /// ```dart
  /// composed.drive.children<double>(
  ///   (elapsed) => (elapsed.inMilliseconds % 500) / 500.0,
  ///   (context, via, progress, children) => Opacity(
  ///     opacity: progress,
  ///     child: Row(children: children),
  ///   ),
  ///   children: const [BadgeWidget(), LabelWidget()],
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  Widget children<T>(
    T Function(Duration elapsed) onTick,
    Widget Function(
            BuildContext context, WhatVia via, T value, List<Widget> children)
        builder, {
    required List<Widget> children,
    T? initialValue,
    bool distinct = false,
    bool Function(T previous, T next)? equals,
    Key? key,
  }) =>
      _ComposedDriveWithChildrenWidget<T>(
        onTick: onTick,
        builder: builder,
        children: children,
        initialValue: initialValue,
        distinct: distinct,
        equals: equals,
        key: key,
      );
}
