// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

/// Extension bridging Dart's [Future] with the reactive [What] pipeline.
extension FutureWhatExtension<T> on Future<T> {
  /// Converts this [Future] into a reactive [What] node.
  ///
  /// Subscription to the underlying [Future] (`.then`) is deferred until the returned
  /// [What] node is actively observed in a reactive scope. This guarantees lazy execution,
  /// avoiding unnecessary network or compute requests before data is actually required.
  ///
  /// Provide [initialFactory] to seed the node synchronously before the future settles.
  /// If the future completes with an error, [onError] can be supplied to intercept the
  /// failure and return a fallback value; otherwise, the node transitions to an error state.
  ///
  /// ## System Architectural Flow
  /// ```text
  /// [Active Consumer Subscribes] ──> [Future.then()] ──> Resolves Event ──> [What<T>]
  ///                                                              │
  ///       ┌──────────────────────────────────────────────────────┴──────────────────────────────────────────────────────┐
  ///       ▼                                                                                                            ▼
  /// [Success: hasData == true, payload: value]                                            [Error: hasError == true, payload: error]
  /// ```
  ///
  /// ## Architectural Benefits
  /// 1. **Lazy Execution Pipeline**: Defers future attachment until the node is actively observed in the reactive graph.
  /// 2. **State Triad Parity**: Starts in empty state (or initial factory seed) and deterministically transitions to data or error.
  /// 3. **Actionable Recovery**: [onError] allows local recovery, returning fallback data before exposing an error to the graph.
  ///
  /// * [initialFactory]: Optional factory callback returning the initial value before the future completes.
  /// * [onError]: Optional error interceptor converting an error into a valid fallback data instance.
  ///
  /// **Ensures:**
  /// * Returns a [What] node that initializes as empty (or with [initialFactory] value).
  /// * Transitions to a data state upon future completion.
  /// * Transitions to an error state on uncaught error, carrying the original error and stack trace.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT invoke `future.toWhat(...)` repeatedly inside build methods or `computed` closures without caching,
  ///   as it creates a new [What] node and re-attaches listeners on every evaluation.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Invoking toWhat() on every computation pass
  /// final summaryWhat = computed((via) {
  ///   return fetchDetails().toWhat(); // Recreated and discarded continuously!
  /// });
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Create the bridged What once and observe its state
  /// final detailsWhat = fetchDetails().toWhat(
  ///   initialFactory: () => UserDetails.loading(),
  /// );
  /// ```
  ///
  /// ## Examples
  /// ```dart
  /// Future<UserProfile> fetchProfile() async => ...;
  ///
  /// final profileWhat = fetchProfile().toWhat(
  ///   initialFactory: () => UserProfile.guest(),
  ///   onError: (error, stackTrace) => UserProfile.fallback(),
  /// );
  ///
  /// final greeting = profileWhat.peekState.match(
  ///   data: (profile) => 'Welcome, ${profile.name}!',
  ///   empty: () => 'Loading profile...',
  ///   error: (err, stack) => 'Failed to load profile.',
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  What<T> toWhat({
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
  }) =>
      _FutureWhatBridge<T>(
        this,
        initialFactory: initialFactory,
        onError: onError,
      ).what;
}

/// Extension grouping multiple [Future]s into a reactive list of [What] nodes.
extension FutureIterableWhatExtension<T> on Iterable<Future<T>> {
  /// Converts this collection of [Future]s into a reactive list of [What] nodes.
  ///
  /// Each [Future] in this iterable is mapped via [toWhat] with the optional [initialFactory]
  /// and [onError] callbacks. The resulting collection is bundled into a [What] node,
  /// enabling batch observation and collective lifecycle management.
  ///
  /// * [initialFactory]: Optional factory callback returning the initial value before each future completes.
  /// * [onError]: Optional error interceptor converting an error into a valid fallback data instance.
  ///
  /// **Ensures:**
  /// * Returns a constant [What<List<What<T>>>] holding an unmodifiable list of bridged nodes.
  @pragma('vm:prefer-inline')
  What<List<What<T>>> toWhat({
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
  }) =>
      What.constant(List<What<T>>.unmodifiable(map((future) => future.toWhat(
            initialFactory: initialFactory,
            onError: onError,
          ))));
}

/// Extension bridging Dart's [Stream] with the reactive [What] pipeline.
extension StreamWhatExtension<T> on Stream<T> {
  /// Converts this [Stream] into a reactive [What] node.
  ///
  /// Bridges asynchronous [Stream] event sequences into synchronous reactive [What] state,
  /// with lazy subscription upon activation and automatic cancellation upon deactivation.
  ///
  /// ## System Architectural Flow
  /// ```text
  /// [Active Consumer Subscribes] ──> [Stream.listen()] ──> Emits Data Pulses ──> [What<T>]
  /// [All Consumers Unsubscribe]  ──> [Subscription.cancel()]
  /// ```
  ///
  /// ## Architectural Benefits
  /// 1. **Lifecycle-Coupled Subscription**: Prevents memory leaks by cancelling subscriptions when unobserved.
  /// 2. **Microtask Cancellation Coalescing**: Supports [graceful] deferral to prevent stream flickering.
  /// 3. **Built-In Distinct Filtering**: Suppresses duplicate consecutive event pulses.
  /// 4. **Exhaustive Pattern Matching**: Supports [WhatStateMatchExtension.match], [WhatStateMatchExtension.matchOrElse], and [WhatStateMatchExtension.matchOrNull] for clean UI branching.
  ///
  /// * [initialFactory]: Optional callback providing an initial value before the Stream emits its first event.
  /// * [onError]: Optional error recovery callback invoked if the Stream emits an error event.
  /// * [cancelOnError]: If `true`, cancels the stream subscription on error.
  /// * [distinct]: When `true`, suppresses dirty notifications on identical consecutive values. Defaults to `true`.
  /// * [equals]: Custom equality comparator used when [distinct] is `true`.
  /// * [graceful]: Policy to defer unsubscription during rapid remounts or transitions.
  ///
  /// **Ensures:**
  /// * Returns a [What] node reflecting the latest emitted stream events.
  /// * Subscription lifecycle is fully synchronized with downstream demand.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT invoke `stream.toWhat(...)` repeatedly inside build methods or `computed` closures without caching,
  ///   as it will establish and cancel separate stream subscriptions on every evaluation.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Converting stream to What on every render loop
  /// Widget build(BuildContext context) {
  ///   final stockWhat = stockStream.toWhat(); // Re-subscribes every frame!
  ///   return composed((context, via) => Text('${via.state(stockWhat).dataOrNull}'));
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Convert stream to What once at the state/controller layer
  /// class StockController {
  ///   late final stockWhat = stockStream.toWhat(
  ///     initialFactory: () => 0.0,
  ///     graceful: graceful,
  ///   );
  /// }
  /// ```
  ///
  /// ## Examples
  /// ```dart
  /// Stream<int> sensorStream = ...;
  ///
  /// final sensorWhat = sensorStream.toWhat(
  ///   initialFactory: () => 0,
  ///   distinct: true,
  ///   graceful: graceful,
  /// );
  ///
  /// final label = sensorWhat.peekState.match(
  ///   data: (value) => 'Reading: $value',
  ///   empty: () => 'Sensor calibrating...',
  ///   error: (err, stack) => 'Sensor failure: $err',
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  What<T> toWhat({
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
    bool? cancelOnError,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    Graceful? graceful,
  }) =>
      _StreamWhatBridge.create<T>(
        this,
        initialFactory: initialFactory,
        onError: onError,
        cancelOnError: cancelOnError,
        distinct: distinct,
        equals: equals,
        graceful: graceful,
      ).what;
}

/// Extension grouping multiple [Stream]s into a reactive list of [What] nodes.
extension StreamIterableWhatExtension<T> on Iterable<Stream<T>> {
  /// Converts this collection of [Stream]s into a reactive list of [What] nodes.
  ///
  /// * [cancelOnError]: If `true`, cancels the stream subscription on error.
  /// * [distinct]: When `true`, suppresses dirty notifications on identical consecutive values. Defaults to `true`.
  /// * [equals]: Custom equality comparator used when [distinct] is `true`.
  ///
  /// **Ensures:**
  /// * Returns a constant [What<List<What<T>>>] holding an unmodifiable list of bridged nodes.
  @pragma('vm:prefer-inline')
  What<List<What<T>>> toWhat({
    bool? cancelOnError,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
  }) =>
      What.constant(List<What<T>>.unmodifiable(map((stream) => stream.toWhat(
            cancelOnError: cancelOnError,
            distinct: distinct,
            equals: equals,
          ))));
}
