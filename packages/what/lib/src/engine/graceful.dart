// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

/// Top-level graceful policy factory and default microtask-deferred grace instance.
///
/// In reactive LPDAG topologies, nodes naturally deactivate when their downstream
/// subscriber count drops to zero (`!_hasTargets`). [Graceful] introduces a configurable
/// buffer window before resources are deallocated or upstream connections are severed:
///
/// 1. **Microtask Buffer ([Graceful.microtask] / `graceful` / `Graceful()`)**:
///    Defers disposal to the Dart microtask queue (1 tick via [_Scheduler]). Coalesces rapid
///    unmount/remount cycles in Flutter widget trees without frame drops or object allocation.
///
/// 2. **Time-based Mooring ([Graceful.period] / `graceful.period(...)`)**:
///    Deploys the hidden global [_MooringTerminal] to anchor the node with a
///    topological [_MooringEdge]. Keeps the node and its upstream dependencies 100% active and
///    listening for the specified duration, retaining cache state across screen navigation.
///
/// ## Sub-Functor & Factory Pathways
/// ```text
/// graceful                           (Default microtask-deferred policy)
///  ├── .microtask                    (Explicit microtask policy handle)
///  ├── .period(Duration)             (Time-based mooring policy)
///  └── call([Duration?])             (Callable shorthand)
/// ```
///
/// ## System Architectural Flow
/// ```text
/// [Subscribers drop to 0]
///           │
///           ▼
///    Graceful policy configured?
///           │
///      ┌────┴────────────────────────┐
/// (No) │                             │ (Yes)
///      ▼                             ▼
/// [Sever Upstream Edges]      [Enter Grace State]
/// [Deallocate Resources]             │
///                                    ├─► Microtask: defers 1 scheduler tick
///                                    └─► Period: anchors via global _MooringTerminal timer
///                                    │
///               ┌────────────────────┴────────────────────┐
///               ▼                                         ▼
///    [New subscriber attaches]                 [Grace period elapses]
///    (Resumes active instantly)                (Deallocates cleanly)
/// ```
///
/// ## Architectural Benefits
/// 1. **Zero-Drop Navigation**: Prevents reloading data when popping and pushing routes.
/// 2. **Flutter Frame Coalescing**: Survives element reparenting and tree rebuilding.
/// 3. **Controlled Mooring**: Time-bounded cache retention prevents unbounded memory growth.
///
/// See [GracefulFactory.call] for complete parameter specifications, execution contracts,
/// and anti-pattern prevention.
///
/// ## Examples
/// ```dart
/// // 1. Default microtask deferral:
/// final feedWhat = feedStream.toWhat(graceful: graceful);
///
/// // 2. Time-based 30-second mooring:
/// final cachedProfile = profileStream.toWhat(
///   graceful: graceful.period(const Duration(seconds: 30)),
/// );
/// ```
const graceful = GracefulFactory._();

/// Represents the graceful deactivation policy for a [What] node.
///
/// Governs the retention duration and deallocation mechanics when downstream
/// subscribers drop to zero.
abstract final class Graceful {
  /// Creates a microtask-deferred deactivation policy (1-tick buffer via [_Scheduler]).
  ///
  /// **Ensures:**
  /// * Returns a microtask-deferred [Graceful] policy instance.
  const factory Graceful() = GracefulFactory._;

  /// Creates a time-based mooring grace period policy for [duration].
  ///
  /// * [duration]: The duration to keep the node moored before deallocating.
  ///
  /// **Ensures:**
  /// * Returns a time-based [Graceful] policy instance.
  const factory Graceful.period(Duration duration) = _PeriodGraceful;

  /// No graceful buffering (idiomatic null sentinel).
  static const Graceful? none = null;

  /// Explicit named constant for the microtask-deferred policy.
  static const Graceful microtask = graceful;

  /// Internal hook executed by a graceful node when subscribers drop to zero.
  _GraceHandle? _enterGrace(_GracefulNodeMixin node);
}

/// Top-level policy functor providing unified DSL access to graceful deactivation policies.
final class GracefulFactory extends _MicrotaskGraceful {
  /// Internal const constructor for [graceful].
  const GracefulFactory._();

  /// Explicit reference to the microtask-deferred grace policy.
  Graceful get microtask => this;

  /// Creates a time-based mooring grace period policy for [duration].
  ///
  /// * [duration]: The time window to keep the node active after last subscriber detaches.
  ///
  /// **Ensures:**
  /// * Returns a time-moored [Graceful] policy instance.
  @pragma('vm:prefer-inline')
  Graceful period(Duration duration) => _PeriodGraceful(duration);

  /// Calling `graceful()` returns the default microtask instance,
  /// or a time-moored policy if [duration] is provided.
  ///
  /// * [duration]: Optional duration for time-based mooring. If omitted, returns microtask deferral.
  ///
  /// **Ensures:**
  /// * Returns a [Graceful] policy instance matching the requested duration.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT set excessively long or infinite mooring durations (e.g. days or hours) on high-memory
  ///   or large data feeds, as nodes will hold active references and prevent garbage collection.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Indefinite retention prevents GC of heavy memory-intensive nodes
  /// final heavyFeed = feedStream.toWhat(graceful: graceful.period(const Duration(days: 365)));
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Bounded grace duration tailored to typical route navigation cycles
  /// final heavyFeed = feedStream.toWhat(graceful: graceful.period(const Duration(seconds: 30)));
  /// ```
  ///
  /// ## Examples
  /// ```dart
  /// graceful(); // microtask deferral
  /// graceful(const Duration(minutes: 5)); // 5-minute mooring
  /// ```
  @pragma('vm:prefer-inline')
  Graceful call([Duration? duration]) => duration != null ? _PeriodGraceful(duration) : this;
}
