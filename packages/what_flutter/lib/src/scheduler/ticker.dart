// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Extension providing reactive frame-tick driver capabilities directly on Flutter [TickerProvider] instances.
///
/// Bridges Flutter's continuous display VSYNC engine into What's 2-Phase LPDAG reactive graph,
/// converting raw frame ticks into lifecycle-managed, self-disposing [What] streams.
///
/// ## System Architectural Flow
/// ```text
/// [ TickerProvider (State / Element) ]
///                 │
///                 │ .drive(onTick)
///                 ▼
/// [ managed<_TickerDriver<T>> ] ──► Lazy Allocation on Downstream Subscription
///                 │
///                 ▼
/// [ Hardware VSYNC Tick ] ──► onTick(elapsed) ──► WhatController<T>.set()
///                 │
///                 ▼
/// [ Distinct Filter ] ──► Suppresses Invalidation if Unchanged
///                 │
///                 ▼
/// [ Downstream Teardown ] ──► managed triggers tryDispose on Deactivation
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Lazy Allocation & Zero Leaks**: Tickers are instantiated only when downstream subscribers
///    actively observe the node, and are automatically halted and disposed when unobserved.
/// 2. **Hardware VSYNC Alignment**: Computations are synchronized directly with the hardware display
///    refresh cadence (60Hz / 120Hz), eliminating asynchronous timer drift and frame jitter.
/// 3. **Tick Dropping via `distinct`**: Gating identical consecutive results prevents unnecessary
///    re-evaluations and widget rebuilds, conserving CPU and battery life.
/// 4. **Resilient Remount Deferral**: Integrates with [Graceful] policies (e.g. `Graceful.microtask()`)
///    to preserve ticker continuity across quick widget reparenting or route transitions.
///
/// ## Invocation Pathways
/// ```text
/// TickerProvider.drive<T>(onTick, ...) ──► What<T>
/// ```
///
/// For inline UI widget composition that does not require an explicit [TickerProvider],
/// use `composed.drive(...)` instead.
///
/// ## Examples
/// ```dart
/// class RotationIndicatorState extends State<RotationIndicator>
///     with SingleTickerProviderStateMixin {
///   late final angleWhat = drive(
///     (elapsed) => (elapsed.inMicroseconds % 1000000) / 1000000.0 * 2 * math.pi,
///   );
///
///   @override
///   Widget build(BuildContext context) {
///     return composed((context, via) => Transform.rotate(
///       angle: via(angleWhat),
///       child: const Icon(Icons.refresh),
///     ));
///   }
/// }
/// ```
extension WhatTickerProviderDriveExtension on TickerProvider {
  /// Drives a reactive [What<T>] from this [TickerProvider] by evaluating [onTick] on every animation frame tick.
  ///
  /// Integrates Flutter's continuous display VSYNC ticker directly into the reactive LPDAG pipeline,
  /// creating a lifecycle-managed, self-disposing continuous frame pulse stream.
  ///
  /// ## System Architectural Flow
  /// ```text
  /// ┌────────────────────────────────────────────────────────────────────────┐
  /// │               TickerProvider.drive<T> Pipeline Execution               │
  /// ├────────────────────────────────────────────────────────────────────────┤
  /// │                                                                        │
  /// │   [ Downstream Subscriber Subscribes ]                                 │
  /// │                 │                                                      │
  /// │                 │ (Activates managed<_TickerDriver<T>>)                │
  /// │                 ▼                                                      │
  /// │   [ managed: create ] ──► Instantiates _TickerDriver<T>                │
  /// │                 │                                                      │
  /// │                 ├─► initialValue != null ? seeds initialValue          │
  /// │                 │   : seeds onTick(Duration.zero)                      │
  /// │                 │                                                      │
  /// │                 ▼                                                      │
  /// │   [ vsync.createTicker() ] ──► Starts Ticking at VSYNC (60Hz / 120Hz)  │
  /// │                 │                                                      │
  /// │                 ▼ (Continuous Frame Tick)                              │
  /// │   onTick(elapsed: Duration) ──► Computes Output Value [T]              │
  /// │                 │                                                      │
  /// │                 ▼                                                      │
  /// │   [ Distinct Filter: value == previous? ]                              │
  /// │         ├─► (Yes) ──► Drop Invalidation Pulse (0-Rebuild)              │
  /// │         │             Saves CPU, Battery, and Layout Passes            │
  /// │         │                                                              │
  /// │         └─► (No)  ──► Push-Dirty to Terminal (Surgical Update)         │
  /// │                                                                        │
  /// │   [ Downstream Subscribers Unmount / Detach ]                          │
  /// │                 │                                                      │
  /// │                 │ (managed: dispose with optional Graceful delay)      │
  /// │                 ▼                                                      │
  /// │   [ _TickerDriver.tryDispose ] ──► Stops & Disposes Ticker             │
  /// │                                    Empties Reactive Node Controller    │
  /// └────────────────────────────────────────────────────────────────────────┘
  /// ```
  ///
  /// ## Architectural Benefits
  /// 1. **Zero-Leak Lifecycle Coupling**: Automatically spawns the ticker only when downstream
  ///    consumers subscribe, and disposes the ticker synchronously when deactivated.
  /// 2. **Hardware-Synchronized Frame Gating**: Eliminates asynchronous timer drift by aligning
  ///    evaluations directly with the device's display refresh rate.
  /// 3. **Built-In Distinct Filtering**: When [distinct] is `true`, suppresses dirty invalidations
  ///    when consecutive [onTick] calculations yield equal results.
  /// 4. **Fail-Fast Error Trapping**: Exceptions thrown inside [onTick] immediately halt the ticker
  ///    and transition the reactive node into an error state ([WhatSnapshot.error]), preventing runaway
  ///    120fps error cascades.
  /// 5. **Microtask Remount Deferral**: Supports [Graceful] policies (e.g. `Graceful.microtask()`)
  ///    to prevent rapid ticker restarts during widget tree reshuffles.
  /// 6. **Guarded Dynamic Delegation**: Uses [switched] with `.hasData.guarded(...)` to isolate
  ///    uninitialized or torn-down states without runtime null dereference panics.
  ///
  /// * [onTick]: Callback computing state of type [T] from the elapsed frame [Duration].
  /// * [initialValue]: Optional initial value used prior to the first frame tick. When provided,
  ///   skips synchronous evaluation of [onTick] at [Duration.zero]. When `null`, [onTick] is evaluated
  ///   synchronously during driver creation.
  /// * [distinct]: When `true`, suppresses dirty invalidation if consecutive [onTick] evaluations
  ///   produce equal values. Defaults to `false`.
  /// * [equals]: Custom equality comparator used when [distinct] is enabled.
  /// * [graceful]: Optional [Graceful] policy deferring ticker teardown across rapid remounts.
  ///
  /// **Requires:**
  /// * If [equals] is provided, [distinct] MUST be set to `true`.
  /// * [onTick] should be a deterministic function and avoid synchronous mutations to external state.
  ///
  /// **Ensures:**
  /// * Returns a reactive [What<T>] node driven continuously by display frame ticks.
  ///
  /// **Throws:**
  /// * Throws an [AssertionError] in debug mode if [equals] is provided while [distinct] is `false`.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT invoke `vsync.drive(...)` repeatedly inside `build()` methods without caching.
  ///   Invoking `drive(...)` on every build recreates the underlying managed resource pipeline,
  ///   spawning redundant tickers and causing resource thrashing.
  /// - For stateful widgets with [SingleTickerProviderStateMixin], cache the driven node in a
  ///   `late final` field of the `State` class.
  /// - For inline widget rendering without a `StatefulWidget`, use `composed.drive(...)` instead.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Spawning new frame ticker pipeline on every widget build pass
  /// class ClockState extends State<ClockWidget> with SingleTickerProviderStateMixin {
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     final secondWhat = drive((elapsed) => elapsed.inSeconds % 60); // Allocates every frame!
  ///     return composed((context, via) => Text('Second: ${via(secondWhat)}'));
  ///   }
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Cache once in a late final field of State
  /// class ClockState extends State<ClockWidget> with SingleTickerProviderStateMixin {
  ///   late final secondWhat = drive(
  ///     (elapsed) => elapsed.inSeconds % 60,
  ///     distinct: true,
  ///   );
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return composed((context, via) => Text('Second: ${via(secondWhat)}'));
  ///   }
  /// }
  /// ```
  ///
  /// ## Examples
  ///
  /// ### 1. Continuous 120Hz Animation Driver
  /// ```dart
  /// class SpinnerState extends State<SpinnerWidget> with SingleTickerProviderStateMixin {
  ///   late final angleWhat = drive(
  ///     (elapsed) => (elapsed.inMicroseconds % 1000000) / 1000000.0 * 2 * math.pi,
  ///   );
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return composed((context, via) => Transform.rotate(
  ///       angle: via(angleWhat),
  ///       child: const Icon(Icons.autorenew),
  ///     ));
  ///   }
  /// }
  /// ```
  ///
  /// ### 2. Throttled Second Counter with Microtask Remount Protection
  /// ```dart
  /// class TimerState extends State<TimerWidget> with SingleTickerProviderStateMixin {
  ///   late final secondWhat = drive(
  ///     (elapsed) => elapsed.inSeconds,
  ///     distinct: true,
  ///     graceful: Graceful.microtask(),
  ///   );
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return composed((context, via) => Text('Elapsed: ${via(secondWhat)}s'));
  ///   }
  /// }
  /// ```
  What<T> drive<T>(
    T Function(Duration elapsed) onTick, {
    T? initialValue,
    bool distinct = false,
    bool Function(T previous, T next)? equals,
    Graceful? graceful,
  }) {
    assert(
      equals == null || distinct,
      'If [equals] is provided, [distinct] MUST be set to true.',
    );

    final resourceNode = managed<_TickerDriver<T>>(
      eager: true,
      create: (via) {
        return _TickerDriver<T>(
          this,
          onTick: onTick,
          initialValue: initialValue,
          distinct: distinct,
          equals: equals,
        );
      },
      dispose: (driver) {
        driver.tryDispose(this);
      },
      graceful: graceful,
    );

    return switched(
      (via) => via(resourceNode).what,
      guard: (via) => via.state(resourceNode).hasData.guarded(
            untracked.state(resourceNode).emptyReason ?? 'TickerNotInitialized',
          ),
      eager: true,
    );
  }
}
