// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// What<T> Core Read-Only Reactive Interface
// =============================================================================

/// The core read-only reactive state interface in the What reactive DAG engine.
///
/// Under the strict **Producer/Consumer Separation (Has-a)** architecture:
/// - [What<T>] represents the observation-only view of a reactive node.
/// - It does **NOT** implement [WhatState<T>] or [WhatController<T>] directly on its public interface.
/// - Mutation APIs (`.set()`, `.data =`, `.setGuarded()`, `.setError()`, `.empty([reason])`) are
///   strictly confined to [WhatController<T>] and [RawWhatController<T>].
/// - [What<T>] NEVER implements [WhatController<T>], and underlying physical entry nodes
///   are private to the library, preventing rogue downcasting at runtime.
///
/// Exposes [peek] and [peekState] to inspect node values and live state with zero-overhead
/// direct field dereferencing outside tracking scopes, and explicit [WhatVia] dependency
/// registration within derivation closures (`via(node)` for values, `via.state(node)` for live states).
///
/// ## System Architectural Flow
///
/// ### 1. 3-State Finite State Machine (Observed via .peekState)
/// ```text
///                     ┌────────────────────────────────────────┐
///                     │     What<T> 3-State State Machine      │
///                     └────────────────────────────────────────┘
///                            │ (What.empty<T>() or uninitialized)
///                            ▼
///                     ┌──────────────┐    Controller .set(data)     ┌──────────────┐
///                     │    EMPTY     │ ───────────────────────────> │     DATA     │ (hasData == true)
///                     │  (isEmpty)   │ <─────────────────────────── │  (payload:T) │
///                     └──────┬───────┘   Controller .empty([reason])└──────┬───────┘
///                            │                                             │
///                            │ Controller .setError()        Controller    │
///                            │                               .setError()   │
///                            ▼                                             ▼
///                     ┌────────────────────────────────────────────────────────────┐
///                     │                           ERROR                            │ (hasError == true)
///                     │              (payload: Object, [StackTrace])               │
///                     └────────────────────────────────────────────────────────────┘
/// ```
///
/// ### 2. Explicit Dependency Registration vs. Raw Reads
/// ```text
/// [computed / Effect.via Scope]
///             │ (Injected WhatVia parameter)
///             ▼
///      via(sourceWhat)        ──>  [Registers Source Edge in Active LPDAG & Evaluates T]
///      via.state(sourceWhat)  ──>  [Registers Source Edge & Returns Live WhatState<T>]
///
/// [Outside Derivation Scope / Raw Read]
///             │
///      sourceWhat.peek        ──>  [Pure Direct Field Dereference: Returns T (Zero Overhead)]
///      sourceWhat.peekState   ──>  [Zero-Allocation Live WhatState<T> View]
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero-Overhead Raw Reads & Explicit Tracking**: Reading `.peek`, `.peekState`, etc.,
///    directly on a node is a pure field dereference with zero tracking overhead and no dynamic
///    tracking stack penalty. Reactive derivations explicitly declare dependencies via the injected
///    [WhatVia] parameter (`via(node)`).
/// 2. **3-State Exclusivity**: A [What] node's observed state is strictly in one of three mutually exclusive states:
///    * **Data** ([WhatState.hasData] == true): Contains a valid payload of type `T` (including `null` for `T?`).
///    * **Empty** ([WhatState.isEmpty] == true): Uninitialized or dormant state with optional [WhatState.emptyReason].
///    * **Error** ([WhatState.hasError] == true): Exception state encapsulating [WhatState.error] and optional [WhatState.stackTrace].
/// 3. **Sound Fail-Fast Extraction**: Reading `.peek` while in Empty or Error state throws
///    [WhatSnapshotExtractionException]. Use `.peekState.dataOrNull`, `.peekState.dataOrElse()`, or `.peekState.match()`
///    (or `.peekState.snapshot.match()`) for safe total pattern matching.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT read `.peek` or `.peekState` directly inside a [computed] or `Effect.via` scope without
///   wrapping in `via(...)`, as reading `.peek` directly performs a pure untracked read.
/// - Do NOT mutate a [WhatController] inside a [computed] or effect reading that same node
///   without a terminating condition, as this induces topological reentrancy cycles.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Reading .peek without via() bypasses dependency registration
/// final badComputed = computed((via) {
///   return count.what.peek * 2; // count is NOT tracked!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Explicitly register dependencies through via()
/// final goodComputed = computed((via) {
///   return via(count.what) * 2; // Dynamically and explicitly registered in LPDAG
/// });
/// ```
///
/// ## Examples
/// ```dart
/// final counter = WhatController(0);
/// final doubled = computed((via) => via(counter.what) * 2);
///
/// print(doubled.peek); // 0
/// counter.data = 5;
/// print(doubled.peek); // 10
/// ```
abstract base class What<T> extends _Node {
  What._();

  _WhatState<T> _read();

  /// Reads the current value untracked. Throws [WhatSnapshotExtractionException]
  /// if the node is in Empty or Error state (Fail-Fast).
  T get peek;

  /// Returns an untracked live view of the node's state.
  ///
  /// In practice, returns the node itself (`this`) with zero allocation.
  /// To preserve an immutable snapshot at this point in time, access `.snapshot`.
  WhatState<T> get peekState;

  /// Creates a constant static leaf node holding an immutable valid [data] payload.
  ///
  /// * [data]: The payload to store in this static node.
  ///
  /// **Ensures:**
  /// * Returns a leaf [What<T>] node permanently in the Data state ([WhatState.hasData] == true).
  ///
  /// ## Examples
  /// ```dart
  /// final fixedConfig = What.constant(42);
  /// print(fixedConfig.peek); // 42
  /// ```
  factory What.constant(T data) = _ConstantWhat<T>;

  /// Creates a constant static leaf node permanently in an uninitialized (Empty) state.
  ///
  /// * [emptyReason]: Optional diagnostic object explaining why this node holds no data.
  ///
  /// **Ensures:**
  /// * Returns a leaf [What<T>] node permanently in the Empty state ([WhatState.isEmpty] == true).
  ///
  /// ## Examples
  /// ```dart
  /// final placeholder = What<String>.empty('Awaiting initial login');
  /// print(placeholder.peekState.isEmpty); // true
  /// ```
  factory What.empty([Object? emptyReason]) = _ConstantWhat<T>.empty;

  /// Creates a constant static leaf node permanently in an Error state.
  ///
  /// * [error]: The exception or error payload.
  /// * [stackTrace]: Optional stack trace associated with the failure.
  ///
  /// **Ensures:**
  /// * Returns a leaf [What<T>] node permanently in the Error state ([WhatState.hasError] == true).
  ///
  /// ## Examples
  /// ```dart
  /// final failedNode = What<int>.error(StateError('Resource offline'));
  /// print(failedNode.peekState.hasError); // true
  /// ```
  factory What.error(Object error, [StackTrace? stackTrace]) = _ConstantWhat<T>.error;

  /// Creates a reactive [What] node from a Dart [Future].
  ///
  /// Bridges asynchronous single-value completion into the synchronous reactive LPDAG graph,
  /// lazily initiating the future upon first downstream activation and transitioning from
  /// Empty to Data or Error upon completion.
  ///
  /// ## System Architectural Flow
  /// ```text
  /// [Active Consumer Subscribes] ──> [Future Initiated]
  ///                                           │
  ///            ┌──────────────────────────────┴──────────────────────────────┐
  ///            ▼ (on completion)                                             ▼ (on error)
  ///    [What<T> (Data)]                                              [What<T> (Error)]
  /// ```
  ///
  /// ## Architectural Benefits
  /// 1. **Lazy On-Demand Execution**: Future computation is postponed until an active terminal or UI
  ///    observer requests the value, saving network and CPU bandwidth.
  /// 2. **Deterministic 3-State FSM Integration**: Transitions safely through [WhatSnapshot.empty],
  ///    [WhatSnapshot.new] (Data), or [WhatSnapshot.error], allowing total UI pattern matching.
  /// 3. **Synchronous Fallback Support**: [initialFactory] allows providing an immediate initial payload
  ///    before the asynchronous computation finishes.
  ///
  /// * [future]: The source [Future] to bridge into the reactive LPDAG graph.
  /// * [initialFactory]: Optional callback producing an initial synchronous fallback value.
  /// * [onError]: Optional error recovery callback transforming an exception into a valid [T] payload.
  ///
  /// **Ensures:**
  /// * Returns a reactive [What<T>] node reflecting the resolution of [future].
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT invoke `What.future(...)` repeatedly inside Flutter build methods or `computed` closures
  ///   without caching in a field, as it instantiates a new asynchronous bridge on every evaluation.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Invoking What.future inside build re-executes the future every frame
  /// Widget build(BuildContext context) {
  ///   final profileWhat = What.future(fetchProfile(userId)); // Triggers new fetch on each build!
  ///   return Text('${profileWhat.peekState.dataOrNull?.name}');
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Instantiate What.future once in a state or controller class
  /// class ProfileController {
  ///   late final profileWhat = What.future(fetchProfile(userId));
  /// }
  /// ```
  ///
  /// ## Examples
  /// ```dart
  /// final userProfileWhat = What.future(
  ///   fetchUserProfile('user-101'),
  ///   initialFactory: () => UserProfile.guest(),
  /// );
  /// ```
  factory What.future(
    Future<T> future, {
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
  }) =>
      _FutureWhatBridge<T>(
        future,
        initialFactory: initialFactory,
        onError: onError,
      ).what;

  /// Creates a reactive [What] node from a Dart [Stream].
  ///
  /// Bridges asynchronous event streams into the synchronous reactive LPDAG graph,
  /// establishing a subscription upon activation and cancelling it when all downstream
  /// consumers disconnect.
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
  /// 3. **Built-In Distinct Filtering**: Suppresses duplicate consecutive event pulses when [distinct] is `true`.
  ///
  /// * [stream]: The source [Stream] to bridge into the reactive LPDAG graph.
  /// * [initialFactory]: Optional callback providing an initial state before the Stream emits its first event.
  /// * [onError]: Optional error recovery callback invoked if the Stream emits an error event.
  /// * [cancelOnError]: If `true`, cancels the stream subscription on error.
  /// * [distinct]: When `true`, suppresses dirty notifications on identical consecutive values. Defaults to `true`.
  /// * [equals]: Custom equality comparator used when [distinct] is `true`.
  /// * [graceful]: Optional [Graceful] policy delaying subscription cancellation upon deactivation.
  ///
  /// **Ensures:**
  /// * Returns a reactive [What<T>] node reflecting the latest events of [stream].
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT invoke `What.stream(...)` inside Flutter build methods or reactive derivations without caching,
  ///   as it opens and closes redundant stream subscriptions on every frame.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Opening stream subscription inside build method
  /// Widget build(BuildContext context) {
  ///   final stockWhat = What.stream(stockStream); // Re-subscribes every frame!
  ///   return Text('${stockWhat.peekState.dataOrNull}');
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Instantiate What.stream once in a controller or state holder
  /// class StockController {
  ///   late final stockWhat = What.stream(stockStream, initialFactory: () => 0.0);
  /// }
  /// ```
  ///
  /// ## Examples
  /// ```dart
  /// final stockWhat = What.stream(
  ///   stockPriceStream,
  ///   initialFactory: () => 0.0,
  ///   distinct: true,
  /// );
  /// ```
  factory What.stream(
    Stream<T> stream, {
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
    bool? cancelOnError,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    Graceful? graceful,
  }) =>
      _StreamWhatBridge.create<T>(
        stream,
        initialFactory: initialFactory,
        onError: onError,
        cancelOnError: cancelOnError,
        distinct: distinct,
        equals: equals,
        graceful: graceful,
      ).what;

  // ===========================================================================
  // Dynamic Triad Namespaced Functor Accessors
  // ===========================================================================

  /// Static entrypoint to the [computed] functor for discoverability and namespace disambiguation.
  ///
  /// ```dart
  /// final sum = What.computed((via) => via(a) + via(b));
  /// final profile = What.computed.future((via) => api.fetchUser(via(id)));
  /// final messages = What.computed.stream((via) => socket.watchMessages(via(room)));
  /// ```
  static const computed = ComputedFunctor._();

  /// Static entrypoint to the [switched] functor for discoverability and namespace disambiguation.
  ///
  /// ```dart
  /// final active = What.switched((via) => via(isVip) ? vipFeed : publicFeed);
  /// ```
  static const switched = SwitchedFunctor._();

  /// Static entrypoint to the [managed] functor for discoverability and namespace disambiguation.
  ///
  /// ```dart
  /// final client = What.managed<HttpClient>(
  ///   create: (via) => HttpClient(),
  ///   dispose: (c) => c.close(),
  /// );
  /// ```
  static const managed = ManagedFunctor._();
}

/// Declarative computation and pipeline transformation operators on [What].
///
/// Provides fluent combinators to decorate reactive nodes with distinct filtering,
/// rate limiting (debounce/throttle), microtask batching, and cache retention policies.
extension WhatComputationExtension<T> on What<T> {
  /// Filters out consecutive duplicate payloads using [equals] (or identical / operator ==).
  ///
  /// During the 2-phase LPDAG lazy-pull evaluation pass, this node pulls the upstream payload
  /// and compares it with the previous payload. If identical, this node's version does not advance
  /// ([_isNewerThan] returns `false`), short-circuiting downstream recomputations.
  ///
  /// ## Data Propagation Flow
  /// ```text
  /// Upstream:   ──[A]──[A]──[B]──[B]──[C]──>
  /// Distinct:   ──[A]───────[B]───────[C]──>
  /// ```
  ///
  /// * [equals]: Optional custom equality comparator. Defaults to `identical(a, b) || a == b`.
  ///
  /// **Ensures:**
  /// * Returns a [What<T>] node that only propagates dirty notifications when values change.
  ///
  /// ## Examples
  /// ```dart
  /// final distinctUser = userWhat.distinct((prev, next) => prev.id == next.id);
  /// ```
  @pragma('vm:prefer-inline')
  What<T> distinct([bool Function(T previous, T next)? equals]) => _DistinctWhat<T>(this, equals: equals);

  /// Coalesces multiple synchronous invalidations into a single microtask flush.
  ///
  /// Collapses bursty upstream mutations occurring in the same event-loop turn into
  /// a single downstream dirty pulse, minimizing redundant UI layout and render passes.
  ///
  /// ## Data Propagation Flow
  /// ```text
  /// Upstream (Same Tick): ──[A][B][C]───────────────────────>
  /// Coalesced (Trailing): ──────────────[C (Microtask Flush)]─>
  /// ```
  ///
  /// * [leading]: If `true`, propagates the first dirty pulse immediately upon invalidation.
  /// * [trailing]: If `true`, schedules a deferred dirty pulse on the microtask queue. Defaults to `true`.
  ///
  /// **Ensures:**
  /// * Returns a [What<T>] node that batches synchronous invalidation bursts.
  ///
  /// ## Examples
  /// ```dart
  /// final batchedSearch = searchResultsWhat.coalesced();
  /// ```
  @pragma('vm:prefer-inline')
  What<T> coalesced({bool leading = false, bool trailing = true}) =>
      _CoalescedWhat<T>(this, leading: leading, trailing: trailing);

  /// Debounces downstream invalidation pulses across quiet periods of [duration].
  ///
  /// Postpones downstream dirty propagation until [duration] has elapsed without
  /// any new upstream mutations. Useful for search autocomplete queries and window resizing.
  ///
  /// ## Data Propagation Flow
  /// ```text
  /// Upstream:   ──[A]──[B]──[C]────────────────────[D]─────────>
  /// Debounced:  ───────────────────[C (after silence)]────[D]───>
  /// ```
  ///
  /// * [duration]: The quiet window duration to wait before firing.
  /// * [leading]: If `true`, emits an immediate pulse on the first incoming mutation. Defaults to `false`.
  /// * [trailing]: If `true`, emits a pulse after [duration] of silence. Defaults to `true`.
  ///
  /// **Dormant State Semantics (Raw Reads):**
  /// While this node is inactive (unobserved by active terminals or effects), reading
  /// `.peek` or `.peekState` bypasses temporal timers and synchronously pulls the latest
  /// upstream state on demand (Subscriber-driven Inactive Dormancy).
  ///
  /// **Ensures:**
  /// * Returns a [What<T>] node rate-limiting notifications via debounce.
  ///
  /// ## Examples
  /// ```dart
  /// final debouncedQuery = searchInputWhat.debounced(const Duration(milliseconds: 300));
  /// ```
  @pragma('vm:prefer-inline')
  What<T> debounced(
    Duration duration, {
    bool leading = false,
    bool trailing = true,
  }) =>
      _DebouncedWhat<T>(this, duration, leading: leading, trailing: trailing);

  /// Throttles downstream invalidation pulses to at most once per [duration].
  ///
  /// Enforces a maximum execution frequency across continuous mutation streams
  /// such as scroll listeners, sensor streams, or drag gestures.
  ///
  /// ## Data Propagation Flow
  /// ```text
  /// Upstream:   ──[A]──[B]──[C]──────────[D]──[E]──[F]─────────>
  /// Throttled:  ──[A]───────────────[C]──[D]───────────────[F]──>
  /// ```
  ///
  /// * [duration]: The minimum interval between downstream dirty notifications.
  /// * [leading]: If `true`, emits a pulse immediately on the first event. Defaults to `true`.
  /// * [trailing]: If `true`, emits a pulse at the close of the throttle window if new events arrived. Defaults to `true`.
  ///
  /// **Dormant State Semantics (Raw Reads):**
  /// While this node is inactive (unobserved by active terminals or effects), reading
  /// `.peek` or `.peekState` bypasses temporal timers and synchronously pulls the latest
  /// upstream state on demand (Subscriber-driven Inactive Dormancy).
  ///
  /// **Ensures:**
  /// * Returns a [What<T>] node rate-limiting notifications via throttle.
  ///
  /// ## Examples
  /// ```dart
  /// final throttledScroll = scrollOffsetWhat.throttled(const Duration(milliseconds: 50));
  /// ```
  @pragma('vm:prefer-inline')
  What<T> throttled(
    Duration duration, {
    bool leading = true,
    bool trailing = true,
  }) =>
      _ThrottledWhat<T>(this, duration, leading: leading, trailing: trailing);

  /// Buffers deactivation of this node with a [graceful] policy when downstream subscribers drop to zero.
  ///
  /// Prevents premature disposal and rapid tear-down/re-setup of expensive upstream resources
  /// (e.g. WebSockets, hardware sensors, camera feeds) during brief UI route transitions or tab switches.
  ///
  /// ## System Architectural Flow
  /// ```text
  /// Subscribers Drop to 0 ──> [Graceful Timer Started]
  ///                                  │
  ///            ┌─────────────────────┴─────────────────────┐
  ///            ▼ (New Subscriber Arrives)                  ▼ (Timer Expires)
  ///    [Timer Cancelled, Node Kept Alive]          [Node Safely Deactivated]
  /// ```
  ///
  /// * [graceful]: The mooring policy configuration. Defaults to a 5-minute mooring period if omitted.
  ///
  /// **Ensures:**
  /// * Returns a [What<T>] node shielded by the specified deactivation grace policy.
  ///
  /// ## Examples
  /// ```dart
  /// final resilientFeed = liveFeedWhat.graceful(
  ///   const Graceful.period(Duration(seconds: 30)),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  What<T> graceful([
    Graceful graceful = const Graceful.period(Duration(minutes: 5)),
  ]) =>
      _GracefulWhat<T>(this, graceful: graceful);

  /// Creates a retained node maintaining prior valid data during pending re-evaluations (SWR).
  ///
  /// Implements the Stale-While-Revalidate pattern by masking intermediate Empty states
  /// while an upstream asynchronous refresh is in progress, ensuring zero UI flickering.
  ///
  /// ## System Architectural Flow
  /// ```text
  /// Upstream:   [Data 1] ───> [Empty (Pending Fetch)] ───> [Data 2]
  /// Retained:   [Data 1] ───> [Data 1 (Retained)]    ───> [Data 2]
  /// Pending:    (false)  ───> (true)                 ───> (false)
  /// ```
  ///
  /// * [pending]: Optional [WhatCoupler<bool>] dynamically synchronized with the internal pending facet.
  ///
  /// **Ensures:**
  /// * Returns a [What<T>] node preserving the last valid payload across pending recomputations.
  ///
  /// ## Examples
  /// ```dart
  /// final pendingCoupler = WhatCoupler<bool>.late();
  /// final swrFeed = remoteFeedWhat.retained(pending: pendingCoupler);
  /// ```
  @pragma('vm:prefer-inline')
  What<T> retained({WhatCoupler<bool>? pending}) => _RetainedWhat<T>(this, pending);
}
