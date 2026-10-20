// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

/// Represents the graceful deactivation policy for a [What] node.
///
/// In reactive LPDAG topologies, nodes naturally deactivate when their downstream
/// subscriber count drops to zero (`!_hasTargets`). [Graceful] introduces a configurable
/// buffer window before resources are deallocated or upstream connections are severed:
///
/// 1. **Microtask Buffer ([Graceful.microtask] / `Graceful()`)**:
///    Defers disposal to the Dart microtask queue (1 tick via [_Scheduler]). Coalesces rapid
///    unmount/remount cycles in Flutter widget trees without frame drops or object allocation.
///
/// 2. **Time-based Mooring ([Graceful.period])**:
///    Deploys the hidden global [_MooringTerminal] to anchor the node with a
///    topological [_MooringEdge]. Keeps the node and its upstream dependencies 100% active and
///    listening for the specified duration, retaining cache state across screen navigation.
///
/// ## Factory Constructors and Named Constants
/// ```text
/// Graceful.microtask                 (Default microtask-deferred policy constant)
/// Graceful()                         (Microtask-deferred policy factory constructor)
/// Graceful.period(Duration)          (Time-based mooring policy)
/// Graceful.none                      (No graceful buffering - idiomatic null sentinel)
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
/// ## Examples
/// ```dart
/// // 1. Default microtask deferral:
/// final feedWhat = feedStream.toWhat(graceful: Graceful.microtask);
///
/// // 2. Time-based 30-second mooring:
/// final cachedProfile = profileStream.toWhat(
///   graceful: const Graceful.period(Duration(seconds: 30)),
/// );
/// ```
abstract final class Graceful {
  /// Creates a microtask-deferred deactivation policy (1-tick buffer via [_Scheduler]).
  ///
  /// **Ensures:**
  /// * Returns a microtask-deferred [Graceful] policy instance.
  const factory Graceful() = _MicrotaskGraceful;

  /// Creates a time-based mooring grace period policy for [duration].
  ///
  /// * [duration]: The duration to keep the node moored before deallocating.
  ///
  /// **Ensures:**
  /// * Returns a time-based [Graceful] policy instance.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT set excessively long or infinite mooring durations (e.g. days or hours) on high-memory
  ///   or large data feeds, as nodes will hold active references and prevent garbage collection.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Indefinite retention prevents GC of heavy memory-intensive nodes
  /// final heavyFeed = feedStream.toWhat(graceful: const Graceful.period(Duration(days: 365)));
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Bounded grace duration tailored to typical route navigation cycles
  /// final heavyFeed = feedStream.toWhat(graceful: const Graceful.period(Duration(seconds: 30)));
  /// ```
  const factory Graceful.period(Duration duration) = _PeriodGraceful;

  /// No graceful buffering (idiomatic null sentinel).
  static const Graceful? none = null;

  /// Explicit named constant for the microtask-deferred policy.
  static const Graceful microtask = _MicrotaskGraceful();

  /// Internal hook executed by a graceful node when subscribers drop to zero.
  _GraceHandle? _enterGrace(_GracefulNodeMixin node);
}
