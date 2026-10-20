// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../framework.dart';

// =============================================================================
// Canonical Durable Animation Controller Engines
// =============================================================================

/// Timeline durability and state preservation policies across dormant deactivations.
///
/// Governs how a [DurableAnimationController] manages accumulated progress, elapsed duration,
/// and staged physics simulations when its host widget unmounts, navigates away, or enters dormancy.
///
/// ## System Architectural Flow
/// ```text
///                     ┌────────────────────────────────────────┐
///                     │            DurabilityPolicy            │
///                     └────────────────────────────────────────┘
///                                          │
///        ┌─────────────────────────────────┼─────────────────────────────────┐
///        ▼                                 ▼                                 ▼
/// ┌──────────────┐                 ┌──────────────┐                  ┌──────────────┐
/// │    resume    │                 │   catchUp    │                  │    reset     │
/// └──────┬───────┘                 └──────┬───────┘                  └──────┬───────┘
///        │                                │                                 │
///        │ Freezes progress locally       │ Measures Δt = clock() - t_dorm  │ Resets value to
///        │ Resumes exact progress         │ Compensates elapsed kinematics  │ initial lowerBound
///        ▼                                ▼                                 ▼
/// [Same Coordinate on Wake]        [Compensated Progress on Wake]    [Baseline on Wake]
/// ```
enum DurabilityPolicy {
  /// Resumes animation playback from the exact progress and state at the time of deactivation.
  ///
  /// Freezes parameter coordinates and animation progress locally during dormant unmounts,
  /// seamlessly resuming playback from the exact frozen value when reactivated.
  ///
  /// This is the default policy, ideal for standard UI transitions (e.g., accordion expansions,
  /// modal sheets, dropdowns, and route transitions).
  resume,

  /// Calculates the wall-clock time elapsed while dormant and catches up to real time upon reactivation.
  ///
  /// Ideal for continuous real-time indicators (e.g., radar sweeps, clocks, and live telemetry feeds).
  catchUp,

  /// Discards progress upon deactivation and resets back to initial parameter values upon reactivation.
  ///
  /// Ideal for transient entrance effects or animations that must restart fresh upon re-entry.
  reset,
}

/// A root controller interface governing animation timelines with state durability, dormancy virtualization, and automatic lifecycle coupling.
///
/// [DurableAnimationController] operates on an **Inversion of Control (IoC) Dormancy Model**
/// where physical [Ticker] instances are allocated strictly on demand when mounted in the widget tree
/// (via `composed.animate`) and automatically torn down upon element unmount.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                       DurableAnimationController                       │
/// │                                                                        │
/// │   • Governs durable timeline across dormant unmounts/remounts          │
/// │   • Stores DurabilityPolicy (resume, catchUp, reset)                   │
/// │   • Stages motions programmatically while dormant without ticker errors│
/// └───────────────────────────────────┬────────────────────────────────────┘
///                                     │ mounts via composed.animate(...)
///                                     ▼
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                       ScopedAnimationController                        │
/// │                                                                        │
/// │   • Ephemeral proxy scoped strictly to mounted element lifecycle       │
/// │   • Exposes .view and .drive (auto-purged on unmount to prevent leaks) │
/// └───────────────────────────────────┬────────────────────────────────────┘
///                                     │ provisions on-demand vsync
///                                     ▼
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                     _DurableVsyncSocketElementMixin                    │
/// │                                                                        │
/// │   • Single VSYNC socket host driving the controller                    │
/// │   • Reclaims Ticker synchronously on unmount (zero disposal burden)    │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Framework-Governed Vsync Lifecycle & Zero Disposal Burden**: Physical tickers are allocated
///    strictly on demand when mounted via `composed.animate` and are synchronously torn down
///    at the engine level upon element unmount. Calling `dispose()` manually is strictly redundant;
///    never introduce `StatefulWidget` or manual `.stop()` cascades solely to reclaim tickers.
/// 2. **Single VSYNC Authority & Multi-Widget Orchestration**: A [DurableAnimationController] governs
///    a single, continuous timeline driven by a single host socket. Child widgets observe the controller's
///    reactive state (e.g., via `composed.animate` or reactive transitions) as pure consumers.
/// 3. **Heterogeneous [TickerMode] Isolation**: If two widgets require independent clock lifecycles
///    (for instance, one widget pauses its animation via [TickerMode] while another continues running),
///    they MUST NOT share a single controller. Each independent lifecycle domain must possess its own
///    [DurableAnimationController] instance.
/// 4. **Safe Staged Motion**: Programmatic animations (`forward`, `reverse`, `animateTo`, `fling`, etc.)
///    triggered while dormant are safely staged as `_StagedMotion` and seamlessly executed upon remount.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT create `StatefulWidget` wrappers or `SingleTickerProviderStateMixin` merely to host or dispose
///   a [DurableAnimationController]. Hold the controller in stores, view models, or widget fields, and let
///   `composed.animate` manage ticker allocation.
/// - Do NOT escape [ScopedAnimationController] or its [ScopedAnimationController.view] outside the builder closure.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Manual ticker ceremony, redundant disposal, and escaped view
/// class _MyWidgetState extends State<MyWidget> with SingleTickerProviderStateMixin {
///   late final AnimationController controller; // Requires manual dispose()!
///
///   @override
///   void initState() {
///     super.initState();
///     controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
///   }
///
///   @override
///   void dispose() {
///     controller.dispose(); // Burden of manual lifecycle management
///     super.dispose();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Framework-governed durable lifecycle with zero disposal burden
/// class MyWidget extends StatelessWidget {
///   MyWidget({super.key});
///
///   final controller = DurableAnimationController(
///     duration: const Duration(milliseconds: 300),
///   );
///
///   @override
///   Widget build(BuildContext context) {
///     return composed.animate(
///       controller,
///       (context, via, ctrl) => FadeTransition(
///         opacity: ctrl.view,
///         child: const Text('Durable Motion'),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Examples
/// ```dart
/// final panelController = DurableAnimationController(
///   duration: const Duration(milliseconds: 350),
/// );
///
/// Widget buildPanel(Widget child) {
///   return composed.animate.child(
///     panelController,
///     (context, via, ctrl, c) => SizeTransition(
///       sizeFactor: ctrl.view,
///       child: c,
///     ),
///     child: child,
///   );
/// }
/// ```
sealed class DurableAnimationController {
  /// Creates a state-durable animation controller with bounded limits.
  ///
  /// * [policy]: The timeline durability policy across dormant deactivations.
  ///   Defaults to [DurabilityPolicy.resume].
  /// * [value]: Initial value of the animation. Defaults to [lowerBound].
  /// * [duration]: Forward animation duration.
  /// * [reverseDuration]: Reverse animation duration.
  /// * [debugLabel]: Diagnostic label for debugging output.
  /// * [lowerBound]: Minimum animation value. Defaults to `0.0`.
  /// * [upperBound]: Maximum animation value. Defaults to `1.0`.
  /// * [animationBehavior]: Accessibility behavior override. Defaults to [AnimationBehavior.normal].
  /// * [clock]: Timestamp supplier used when [policy] is [DurabilityPolicy.catchUp]. Defaults to [DateTime.now].
  ///
  /// **Requires:**
  /// * [upperBound] must be greater than or equal to [lowerBound].
  ///
  /// **Ensures:**
  /// * Returns a bounded [DurableAnimationController] governed by [policy].
  factory DurableAnimationController({
    DurabilityPolicy policy = DurabilityPolicy.resume,
    double? value,
    Duration? duration,
    Duration? reverseDuration,
    String? debugLabel,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
    DateTime Function() clock = DateTime.now,
  }) {
    assert(upperBound >= lowerBound);
    return switch (policy) {
      DurabilityPolicy.resume => _FrozenAnimationController(
          value: value,
          duration: duration,
          reverseDuration: reverseDuration,
          debugLabel: debugLabel,
          lowerBound: lowerBound,
          upperBound: upperBound,
          animationBehavior: animationBehavior,
          frozen: true,
        ),
      DurabilityPolicy.catchUp => _CatchUpAnimationController(
          value: value,
          duration: duration,
          reverseDuration: reverseDuration,
          debugLabel: debugLabel,
          lowerBound: lowerBound,
          upperBound: upperBound,
          animationBehavior: animationBehavior,
          clock: clock,
        ),
      DurabilityPolicy.reset => _FrozenAnimationController(
          value: value,
          duration: duration,
          reverseDuration: reverseDuration,
          debugLabel: debugLabel,
          lowerBound: lowerBound,
          upperBound: upperBound,
          animationBehavior: animationBehavior,
          frozen: false,
        ),
    };
  }

  /// Creates a state-durable animation controller with unbounded limits.
  ///
  /// * [policy]: The timeline durability policy across dormant deactivations.
  ///   Defaults to [DurabilityPolicy.resume].
  /// * [value]: Initial value of the animation. Defaults to `0.0`.
  /// * [duration]: Forward animation duration.
  /// * [reverseDuration]: Reverse animation duration.
  /// * [debugLabel]: Diagnostic label for debugging output.
  /// * [animationBehavior]: Accessibility behavior override. Defaults to [AnimationBehavior.preserve].
  /// * [clock]: Timestamp supplier used when [policy] is [DurabilityPolicy.catchUp]. Defaults to [DateTime.now].
  ///
  /// **Ensures:**
  /// * Returns an unbounded [DurableAnimationController] where [lowerBound] is
  ///   [double.negativeInfinity] and [upperBound] is [double.infinity].
  factory DurableAnimationController.unbounded({
    DurabilityPolicy policy = DurabilityPolicy.resume,
    double value = 0.0,
    Duration? duration,
    Duration? reverseDuration,
    String? debugLabel,
    AnimationBehavior animationBehavior = AnimationBehavior.preserve,
    DateTime Function() clock = DateTime.now,
  }) {
    return switch (policy) {
      DurabilityPolicy.resume => _FrozenAnimationController.unbounded(
          value: value,
          duration: duration,
          reverseDuration: reverseDuration,
          debugLabel: debugLabel,
          animationBehavior: animationBehavior,
          frozen: true,
        ),
      DurabilityPolicy.catchUp => _CatchUpAnimationController.unbounded(
          value: value,
          duration: duration,
          reverseDuration: reverseDuration,
          debugLabel: debugLabel,
          animationBehavior: animationBehavior,
          clock: clock,
        ),
      DurabilityPolicy.reset => _FrozenAnimationController.unbounded(
          value: value,
          duration: duration,
          reverseDuration: reverseDuration,
          debugLabel: debugLabel,
          animationBehavior: animationBehavior,
          frozen: false,
        ),
    };
  }

  const DurableAnimationController._();

  /// The durability policy governing timeline preservation across dormant deactivations.
  DurabilityPolicy get policy;

  /// The value at which this animation is deemed to be dismissed.
  double get lowerBound;

  /// The value at which this animation is deemed to be completed.
  double get upperBound;

  /// A label that is used in the [toString] output. Intended to aid with
  /// identifying animation controller instances in debug output.
  String? get debugLabel;

  /// The behavior of the controller when accessibility settings disable animations.
  AnimationBehavior get animationBehavior;

  /// The length of time this animation should last.
  Duration? get duration;
  set duration(Duration? value);

  /// The length of time this animation should last when going in reverse.
  Duration? get reverseDuration;
  set reverseDuration(Duration? value);

  /// Whether the underlying animation controller engine is currently active.
  bool get isActive;

  /// The current value of the animation.
  double get value;

  /// Stops the animation controller and sets the current value of the animation.
  set value(double newValue);

  /// Sets the controller's value to [lowerBound], stopping the animation.
  void reset();

  /// The rate of change of [value] per second.
  double get velocity;

  /// The amount of time that has elapsed since the animation started.
  Duration? get lastElapsedDuration;

  /// The current status of this animation.
  AnimationStatus get status;

  /// Whether this animation is currently animating.
  bool get isAnimating;

  /// Whether this animation is stopped at the beginning ([status] is [AnimationStatus.dismissed]).
  bool get isDismissed => status.isDismissed;

  /// Whether this animation is stopped at the end ([status] is [AnimationStatus.completed]).
  bool get isCompleted => status.isCompleted;

  /// Whether the current aim of the animation is toward completion.
  bool get isForwardOrCompleted => status.isForwardOrCompleted;

  /// Starts running this animation forwards (towards the end).
  ///
  /// * [from]: Optional starting point. If omitted, continues from current [value].
  ///
  /// **Ensures:**
  /// * Returns a [TickerFuture] completing when forward animation reaches [upperBound].
  /// * **Dormancy Invariant**: When dormant (no active VSYNC attached), the motion intention
  ///   is staged and immediately returns a completed [TickerFuture] to guarantee the zero-leak
  ///   Subscriber-driven Inactive Dormancy invariant and prevent orphaned async suspension leaks.
  ///   When an active VSYNC is attached, the staged motion seamlessly resumes.
  TickerFuture forward({double? from});

  /// Starts running this animation in reverse (towards the beginning).
  ///
  /// * [from]: Optional starting point. If omitted, continues from current [value].
  ///
  /// **Ensures:**
  /// * Returns a [TickerFuture] completing when reverse animation reaches [lowerBound].
  /// * **Dormancy Invariant**: When dormant (no active VSYNC attached), the motion intention
  ///   is staged and immediately returns a completed [TickerFuture] to guarantee the zero-leak
  ///   Subscriber-driven Inactive Dormancy invariant and prevent orphaned async suspension leaks.
  ///   When an active VSYNC is attached, the staged motion seamlessly resumes.
  TickerFuture reverse({double? from});

  /// Toggles the direction of this animation.
  ///
  /// * [from]: Optional starting point.
  ///
  /// **Ensures:**
  /// * Reverses if currently running forward or completed; forwards otherwise.
  TickerFuture toggle({double? from});

  /// Drives the animation from its current value to the given target, "forward".
  ///
  /// * [target]: Target value within `[lowerBound, upperBound]`.
  /// * [duration]: Optional override for animation duration.
  /// * [curve]: Transition curve (defaults to [Curves.linear]).
  ///
  /// **Ensures:**
  /// * Returns a [TickerFuture] completing when animation reaches [target].
  TickerFuture animateTo(double target,
      {Duration? duration, Curve curve = Curves.linear});

  /// Drives the animation from its current value to the given target, "backward".
  ///
  /// * [target]: Target value within `[lowerBound, upperBound]`.
  /// * [duration]: Optional override for animation duration.
  /// * [curve]: Transition curve (defaults to [Curves.linear]).
  ///
  /// **Ensures:**
  /// * Returns a [TickerFuture] completing when animation reaches [target].
  TickerFuture animateBack(double target,
      {Duration? duration, Curve curve = Curves.linear});

  /// Starts running this animation in the forward direction, and restarts when complete.
  ///
  /// * [min]: Optional lower bound for repeating loops (defaults to [lowerBound]).
  /// * [max]: Optional upper bound for repeating loops (defaults to [upperBound]).
  /// * [reverse]: Whether to oscillate back and forth (yo-yo mode).
  /// * [period]: Optional period override for a single loop cycle.
  /// * [count]: Optional maximum iteration loop count before stopping.
  ///
  /// **Ensures:**
  /// * Repeats continuously until cancelled, stopped, or reaching [count].
  TickerFuture repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  });

  /// Drives the animation with a spring and initial velocity.
  ///
  /// * [velocity]: Initial speed of the animation.
  /// * [springDescription]: Physical spring parameters.
  /// * [animationBehavior]: Accessibility behavior override.
  ///
  /// **Ensures:**
  /// * Animates physics-based spring behavior to completion or equilibrium.
  TickerFuture fling({
    double velocity = 1.0,
    SpringDescription? springDescription,
    AnimationBehavior? animationBehavior,
  });

  /// Drives the animation according to the given [simulation].
  ///
  /// Unlike standard Flutter [AnimationController], [DurableAnimationController] preserves
  /// the accumulated simulation elapsed time across dormant deactivations, seamlessly resuming
  /// physics execution upon remount without restarting the simulation from $t = 0.0$.
  ///
  /// * [simulation]: The physical motion simulation to run.
  ///
  /// **Ensures:**
  /// * Runs physics simulation with continuous time preservation across dormant unmounts.
  TickerFuture animateWith(Simulation simulation);

  /// Drives the animation according to the given [simulation] with a status of reverse.
  ///
  /// Seamlessly preserves accumulated run time across dormant deactivations and resumes
  /// in reverse upon remount.
  ///
  /// * [simulation]: The physical motion simulation to run in reverse.
  ///
  /// **Ensures:**
  /// * Runs physics simulation in reverse with dormancy preservation.
  TickerFuture animateBackWith(Simulation simulation);

  /// Stops running this animation.
  ///
  /// * [canceled]: When `true` (default), marks the returned ticker future as canceled.
  ///
  /// **Ensures:**
  /// * Stops active ticking immediately without clearing current [value].
  void stop({bool canceled = true});

  /// Whether this controller is currently in a dormant state (hibernated / inactive without an active [TickerProvider]).
  bool get isDormant;

  /// Returns detailed diagnostic string representation for debug output.
  String toStringDetails();

  // ---------------------------------------------------------------------------
  // Internal Framework Lifecycle & Raw View Directives
  // ---------------------------------------------------------------------------

  void _attachVsync(TickerProvider vsync);
  bool _detachVsync(TickerProvider vsync);
  void _hibernate();
  void _attachScopedView(_ScopedProxyAnimationView view);
  void _detachScopedView(_ScopedProxyAnimationView view);
  Animation<double> get _view;
}

/// An interface representing an animation controller scoped strictly to a presentation
/// widget lifecycle, exposing the Flutter-compatible [view] and [drive].
///
/// In `what_flutter`, [DurableAnimationController] does not expose [view] at its root
/// to eliminate zombie listener leaks outside presentation trees.
/// [ScopedAnimationController] is provided strictly within mounted widget builders
/// (such as `composed.animate(...)`), guaranteeing that all registered listeners are automatically
/// purged upon element unmount.
///
/// ## System Architectural Flow
/// ```text
/// [composed.animate(controller, builder)]
///                 │
///                 ▼ (Mounts & Couples)
/// [ScopedAnimationController (ctrl)] ──> [ctrl.view / ctrl.drive] ──> [Leaf Animation Widgets]
///                 │
///                 ▼ (Unmounts / Deactivates)
/// [Proxy Disposed] ──> [Listeners Purged] (Zero zombie listener leaks)
/// ```
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT cache or escape [ScopedAnimationController] or its [view] into class fields,
///   view models, outer closures, or long-lived collections.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Escaping scoped view to outer class field
/// class _MyPageState extends State<MyPage> {
///   Animation<double>? leakedView;
///
///   @override
///   Widget build(BuildContext context) {
///     return composed.animate(controller, (context, via, ctrl) {
///       leakedView = ctrl.view; // Danger: leaked reference to unmounted view!
///       return FadeTransition(opacity: ctrl.view, child: const SizedBox());
///     });
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Confine scoped view access strictly to the builder closure
/// Widget build(BuildContext context) {
///   return composed.animate(controller, (context, via, ctrl) {
///     return FadeTransition(opacity: ctrl.view, child: const SizedBox());
///   });
/// }
/// ```
abstract interface class ScopedAnimationController
    implements DurableAnimationController {
  /// Returns an [Animation<double>] view coupled strictly to this mounted widget.
  ///
  /// All listeners registered on this view are automatically isolated and purged when
  /// the host widget unmounts, preventing zombie listener leaks.
  Animation<double> get view;

  /// Passes the [view] of this animation through an [Animatable] to create a transformed [Animation].
  ///
  /// * [child]: The tween/animatable used to transform animation values.
  ///
  /// **Ensures:**
  /// * Returns an [Animation<U>] driven by this mounted controller.
  Animation<U> drive<U>(Animatable<U> child);
}

/// Convenience extension providing [observe] directly on [DurableAnimationController].
extension DurableAnimationControllerObserveExtension
    on DurableAnimationController {
  /// Observes this controller's animated [value] as a reactive [What<double>].
  ///
  /// ### Caution: VSYNC Coupling (Passive Observer)
  /// [observe] is a **passive observer** of this controller's timeline and does NOT
  /// generate physical VSYNC ticks on its own.
  ///
  /// For this [What] node to emit updates, the controller must have an active VSYNC host
  /// actively animating it in the widget tree (e.g., via `composed.animate(...)`).
  ///
  /// ## System Architectural Flow
  /// ```text
  /// [composed.animate (Active VSYNC Socket)] ──> [DurableAnimationController (Timeline)]
  ///                                                              │
  ///                                                              ▼
  /// [controller.observe() (Passive What<double>)] <──────────────┘
  /// ```
  ///
  /// * [distinct]: When `true` (default), suppresses pulses if animated value does not change.
  /// * [equals]: Custom equality function.
  /// * [graceful]: Optional teardown deferral policy.
  ///
  /// **Ensures:**
  /// * Emits updated [double] values whenever the controller's animation updates.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Calling `controller.observe()` without mounting the controller in an active VSYNC socket
  ///   (such as `composed.animate`) will produce a dormant [What] that never ticks.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Expecting observe() to tick without a mounted VSYNC host
  /// final ctrl = DurableAnimationController(duration: const Duration(seconds: 1))..forward();
  /// final animatedWhat = ctrl.observe(); // Never receives ticks because no vsync is mounted!
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Mount controller via composed.animate, observe timeline reactively elsewhere
  /// final ctrl = DurableAnimationController(duration: const Duration(seconds: 1));
  /// final animatedWhat = ctrl.observe();
  ///
  /// Widget build(BuildContext context) {
  ///   return Column(
  ///     children: [
  ///       composed.animate(ctrl, (context, via, c) => FadeTransition(opacity: c.view, child: const Text('Host'))),
  ///       composed((context, via) => Text('Progress: ${via(animatedWhat).toStringAsFixed(2)}')),
  ///     ],
  ///   );
  /// }
  /// ```
  What<double> observe({
    bool distinct = true,
    bool Function(double previous, double next)? equals,
    Graceful? graceful,
  }) =>
      _view.toWhat(
        distinct: distinct,
        equals: equals,
        graceful: graceful,
      );
}

/// Lifecycle control extension for [DurableAnimationController], exposed strictly
/// for testing harnesses and internal framework bindings.
///
/// This extension is marked with `@visibleForTesting` and is hidden from `package:what_flutter/what_flutter.dart`.
/// Import `package:what_flutter/testing.dart` to access these utilities in unit tests.
@visibleForTesting
extension DurableAnimationTestingExtension on DurableAnimationController {
  /// Attaches a [TickerProvider] as an active vsync holder.
  @visibleForTesting
  void attachVsync(TickerProvider vsync) => _attachVsync(vsync);

  /// Detaches a [TickerProvider] from the active vsync holder pool.
  @visibleForTesting
  bool detachVsync(TickerProvider vsync) => _detachVsync(vsync);

  /// Hibernates the controller, stopping the active ticker and clearing vsync holders.
  @visibleForTesting
  void hibernate() => _hibernate();

  /// Wakes this controller by attaching [vsync].
  @visibleForTesting
  void wake(TickerProvider vsync) => attachVsync(vsync);

  /// Returns the underlying raw view strictly for unit testing harnesses.
  @visibleForTesting
  Animation<double> get view => _view;

  /// Drives an animatable using the raw view strictly for unit testing harnesses.
  @visibleForTesting
  Animation<U> drive<U>(Animatable<U> child) => child.animate(_view);
}

/// A test-only [TickerProvider] implementation for unit tests and harnesses.
///
/// Marked with `@visibleForTesting` and hidden from `package:what_flutter/what_flutter.dart`.
/// Import `package:what_flutter/testing.dart` to access this in unit tests.
@visibleForTesting
base class TestDurableVSync implements _DurableTickerProvider {
  /// Creates a test-only durable vsync provider.
  const TestDurableVSync({
    bool isActive = true,
    Ticker Function(TickerCallback onTick)? tickerFactory,
  })  : _isActive = isActive,
        _tickerFactory = tickerFactory;

  final bool _isActive;
  final Ticker Function(TickerCallback onTick)? _tickerFactory;

  @override
  bool get isDurableVsyncActive => _isActive;

  @override
  Ticker createTicker(TickerCallback onTick) =>
      _tickerFactory != null ? _tickerFactory(onTick) : Ticker(onTick);
}
