// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Auto-Tracked Reactive Computation
// =============================================================================

/// Core declarative reactive computation functor powered by the 2-Phase Lazy-Pull DAG (LPDAG) engine.
///
/// Automatically and dynamically tracks reactive dependencies accessed via [WhatVia],
/// evaluating on-demand with zero redundant executions and zero-allocation 1-pass epoch diffing.
///
/// ## System Architectural Flow
/// ```text
/// [Upstream What States] ──(Mutates)──> [Push-Dirty Notification (O(1))]
///                                                    │
///                                                    ▼ (Marks Stale)
///                                               [computed]
///                                                    │
///                                                    ▼ (Lazy Pull-Data on .peek read)
///                           [1-Pass Epoch Diffing & O(S) Direct Source Scanning]
/// ```
///
/// ## Architectural Benefits
/// 1. **Lazy Pull-Data Scheduling**: Computations run only when requested by downstream consumers or render cycles.
/// 2. **Zero-Allocation Epoch Diffing**: Graph edge registration and stale edge pruning occur inline without heap churn.
/// 3. **Explicit WhatVia Dependency Manifest**: Dynamically records dependencies via `via(node)` with zero dynamic tracking stack overhead.
/// 4. **$O(S)$ Freshness Invariant**: Verifies freshness directly against its $S$ immediate upstream sources.
///
/// ## Execution Modes
///
/// | Mode | Target Use Case | Key Capabilities |
/// | :--- | :--- | :--- |
/// | `computed(...)` | Pure synchronous derivations | Fast-path zero-allocation inline evaluation |
/// | `computed.future(...)` | Single-shot asynchronous requests | Auto-refetch on mutation, precondition gating, SWR cache |
/// | `computed.stream(...)` | Continuous real-time data feeds | `async*` synthesis, WebSocket retain, graceful mooring |
///
/// ## Quick Examples
///
/// ### Synchronous:
/// ```dart
/// final fullName = computed((via) => '${via(firstName.what)} ${via(lastName.what)}');
/// ```
///
/// ### Asynchronous (Future):
/// ```dart
/// final userProfile = computed.future((via) => api.fetchUser(via(userId.what)));
/// ```
///
/// ### Continuous (Stream):
/// ```dart
/// final messages = computed.stream((via) => socket.watchMessages(via(roomId.what)));
/// ```
///
/// For comprehensive real-world patterns (guards, cache preloading, error recovery, graceful policies):
/// - See [ComputedFunctor.call] for synchronous computation details.
/// - See [ComputedFutureFunctor.call] for advanced Future patterns.
/// - See [ComputedStreamFunctor.call] for resilient Stream & WebSocket patterns.
const computed = ComputedFunctor._();

/// Callable functor managing synchronous and asynchronous [What] computations.
final class ComputedFunctor {
  const ComputedFunctor._();

  /// Fast-path synchronous computation using explicit [WhatVia].
  ///
  /// Evaluates [compute] synchronously on-demand via the 2-phase LPDAG (Lazy-Pull DAG).
  ///
  /// * [compute]: Pure synchronous calculation closure receiving [WhatVia] to explicitly track dependencies.
  /// * [guard]: Optional precondition check returning [WhatGuard] gating evaluation and providing diagnostic reasons.
  ///
  /// **Requires:**
  /// * [compute] must be a pure, synchronous function without side-effects or mutations.
  ///
  /// **Ensures:**
  /// * Returns a [What<T>] node reflecting the latest evaluation of [compute].
  /// * Dynamically registers and prunes dependency graph edges on every execution.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT read `.peek` directly without wrapping in `via(...)`, as reading `.peek` directly bypasses dependency tracking.
  /// - Do NOT perform asynchronous operations (`async`/`await`) or mutations inside [compute]. For async operations, use [ComputedFunctor.future] or [ComputedFunctor.stream].
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Reading .peek without via() misses dependency registration
  /// final badComputed = computed((via) => count.what.peek * 2);
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Explicit dependency registration via WhatVia
  /// final goodComputed = computed((via) => via(count.what) * 2);
  /// ```
  ///
  /// ## Examples
  ///
  /// ### 1. Basic Synchronous Derivation:
  /// ```dart
  /// final firstName = WhatController('Jane');
  /// final lastName = WhatController('Doe');
  ///
  /// final fullName = computed((via) => '${via(firstName.what)} ${via(lastName.what)}');
  /// ```
  ///
  /// ### 2. Declarative Event Pulse / Refresh Signal:
  /// ```dart
  /// final refreshSignal = WhatSignalController();
  ///
  /// // Automatically re-evaluates whenever `refreshSignal.emit()` is called:
  /// final snapshot = computed((via) {
  ///   via(refreshSignal.what); // Declarative re-evaluation trigger
  ///   return heavyCalculation(via(source.what));
  /// });
  ///
  /// // Trigger re-evaluation on demand:
  /// refreshSignal.emit();
  /// ```
  @pragma('vm:prefer-inline')
  What<T> call<T>(
    T Function(WhatVia via) compute, {
    WhatGuard Function(WhatVia via)? guard,
  }) =>
      _ComputedWhat<T>(
        compute,
        guard: guard,
      );

  /// Intuitive keyword alias for [future] (zero-cost inlined).
  ///
  /// See [ComputedFutureFunctor.call] for detailed real-world patterns.
  ComputedFutureFunctor get async => const ComputedFutureFunctor._();

  /// Functor for Future-based single-evaluation asynchronous computations (`computed.future`).
  ///
  /// Supports automatic re-evaluation on upstream mutation, precondition guards (`guard`),
  /// instant cache preloading (`initialFactory`), and error fallback recovery (`onError`).
  ///
  /// See [ComputedFutureFunctor.call] for comprehensive real-world patterns.
  ComputedFutureFunctor get future => const ComputedFutureFunctor._();

  /// Functor for Stream-based continuous asynchronous computations (`computed.stream`).
  ///
  /// Supports `async*` generator synthesis, auto-switching on parameter change,
  /// route transition protection (`graceful.period`), and distinct equality filtering.
  ///
  /// See [ComputedStreamFunctor.call] for comprehensive real-world patterns.
  ComputedStreamFunctor get stream => const ComputedStreamFunctor._();
}

/// Callable functor managing Future-based asynchronous computations (`computed.future`).
final class ComputedFutureFunctor {
  const ComputedFutureFunctor._();

  /// Creates a standard Future-based asynchronous computation node.
  ///
  /// Evaluates [compute] when downstream consumers observe this node. When tracked reactive
  /// dependencies mutate, [compute] re-evaluates automatically.
  ///
  /// * [compute]: Asynchronous closure returning a [Future] producing [T].
  /// * [guard]: Optional precondition check returning [WhatGuard] gating evaluation and providing diagnostic reasons.
  /// * [initialFactory]: Optional callback producing an initial synchronous payload.
  /// * [onError]: Optional error recovery handler.
  ///
  /// **Ensures:**
  /// * Returns a reactive [What<T>] reflecting asynchronous computation results.
  ///
  /// ## Examples
  ///
  /// ### 1. Dynamic Parameter Tracking (Auto-Refetching on Dependency Change):
  /// ```dart
  /// final userId = WhatController('user_123');
  ///
  /// // Automatically re-evaluates and switches when `userId` changes,
  /// // cleanly discarding stale in-flight requests (race-condition immune):
  /// final userProfile = computed.future(
  ///   (via) => userService.fetchProfile(via(userId.what)),
  /// );
  /// ```
  ///
  /// ### 2. Guarded Query with Precondition Gating:
  /// ```dart
  /// final searchQuery = WhatController('');
  ///
  /// // Gates evaluation until the search query has at least 2 non-whitespace characters;
  /// // gracefully halts network call and emits Empty('QueryTooShort') without throwing:
  /// final searchResults = computed.future(
  ///   (via) => searchService.searchProducts(via(searchQuery.what).trim()),
  ///   guard: (via) => (via(searchQuery.what).trim().length >= 2).guarded('QueryTooShort'),
  ///   initialFactory: () => const <Product>[],
  /// );
  /// ```
  ///
  /// ### 3. Resilient Fetching with Instant Cache & Error Fallback:
  /// ```dart
  /// final accountId = WhatController('acc_42');
  ///
  /// // Instant cache render (zero-flicker) while asynchronously fetching fresh data,
  /// // with graceful fallback recovery if the remote endpoint throws:
  /// final accountDetails = computed.future(
  ///   (via) => accountApi.fetchAccountDetails(via(accountId.what)),
  ///   // Provides instant cached data while the asynchronous network call is pending
  ///   initialFactory: () => localDb.peekAccount(accountId.what.peek) ?? AccountDetails.empty,
  ///   // Gracefully recovers from network errors by returning cached or offline data
  ///   onError: (error, st) => localDb.peekAccount(accountId.what.peek) ?? AccountDetails.empty,
  /// );
  /// ```
  ///
  /// ### 4. Manual Refresh Trigger (Pull-to-Refresh / Discrete Event Pulse):
  /// ```dart
  /// final refreshSignal = WhatSignalController();
  ///
  /// // Declaratively refetches whenever `refreshSignal.emit()` is called:
  /// final userList = computed.future((via) {
  ///   via(refreshSignal.what); // Declarative refetch trigger
  ///   return userApi.fetchUsers();
  /// });
  ///
  /// // Trigger fresh fetch on demand:
  /// refreshSignal.emit();
  /// ```
  What<T> call<T>(
    Future<T> Function(WhatVia via) compute, {
    WhatGuard Function(WhatVia via)? guard,
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
  }) =>
      _FutureComputedWhat<T>(
        compute,
        guard: guard,
        initialFactory: initialFactory,
        onError: onError,
      );
}

/// Callable functor managing Stream-based continuous asynchronous computations (`computed.stream`).
final class ComputedStreamFunctor {
  const ComputedStreamFunctor._();

  /// Creates a standard Stream-based continuous asynchronous computation node.
  ///
  /// Continuously listens to the stream returned by [compute] and emits updates into the reactive DAG.
  ///
  /// * [compute]: Closure returning a [Stream] producing [T].
  /// * [guard]: Optional precondition check returning [WhatGuard] gating stream creation and providing diagnostic reasons.
  /// * [initialFactory]: Optional callback producing an initial synchronous payload.
  /// * [onError]: Optional error recovery handler.
  /// * [cancelOnError]: Whether to cancel the stream subscription on error.
  /// * [distinct]: When `true`, filters duplicate consecutive events. Defaults to `true`.
  /// * [equals]: Custom equality comparator used when [distinct] is `true`.
  /// * [graceful]: Optional graceful deactivation policy to prevent stream thrashing.
  ///
  /// **Ensures:**
  /// * Returns a reactive [What<T>] synchronized with the continuous stream.
  ///
  /// ## Examples
  ///
  /// ### 1. Dynamic Parameter Tracking (Auto-Switching Stream):
  /// ```dart
  /// final currentRoomId = WhatController('room-1');
  ///
  /// // Automatically unsubscribes from the previous room stream and subscribes
  /// // to the new one whenever [currentRoomId] changes:
  /// final messages = computed.stream(
  ///   (via) => chatService.watchMessages(via(currentRoomId.what)),
  /// );
  /// ```
  ///
  /// ### 2. Offline-First SWR with `async*` (Local Cache Preload + Live Stream):
  /// ```dart
  /// final currentUserId = WhatController('user-1');
  /// final isLoggedIn = WhatController(true);
  ///
  /// // Leverages an `async*` generator to asynchronously load & yield local DB cache
  /// // first, then seamlessly yield* continuous live server updates:
  /// final liveFeed = computed.stream(
  ///   (via) async* {
  ///     final userId = via(currentUserId.what);
  ///
  ///     // 1. Asynchronously load and yield local database cache immediately
  ///     final cachedFeed = await localDatabase.loadFeed(userId);
  ///     if (cachedFeed.isNotEmpty) {
  ///       yield cachedFeed;
  ///     }
  ///
  ///     // 2. Seamlessly transition to continuous live SSE / WebSocket updates
  ///     yield* feedService.watchUserFeed(userId);
  ///   },
  ///   // Gating: only open stream when user is actively logged in
  ///   guard: (via) => via(isLoggedIn.what).guarded('UserNotAuthenticated'),
  /// );
  /// ```
  ///
  /// ### 3. Resilient Live Ticker with `async*` & Graceful Retain (Zero-Thrashing):
  /// ```dart
  /// final selectedSymbol = WhatController('AAPL');
  /// final isNetworkOnline = WhatController(true);
  ///
  /// // Combines async REST baseline snapshot fetching with live WebSocket streaming,
  /// // custom equality filtering, and time-bounded graceful retention across route changes:
  /// final liveStockPrices = computed.stream(
  ///   (via) async* {
  ///     final symbol = via(selectedSymbol.what);
  ///
  ///     // 1. Fetch & yield immediate REST baseline snapshot while establishing socket
  ///     final snapshot = await stockApi.fetchSnapshot(symbol);
  ///     yield snapshot;
  ///
  ///     // 2. Stream real-time price ticks continuously from WebSocket channel
  ///     yield* stockSocket.watchTicks(symbol);
  ///   },
  ///   // Gating: only open stream when symbol is selected and network is active
  ///   guard: (via) => (via(selectedSymbol.what).isNotEmpty && via(isNetworkOnline.what))
  ///       .guarded('AwaitingNetworkOrValidSymbol'),
  ///   // Retains stream subscription for 30s across route pop/push to prevent socket tear-down
  ///   graceful: graceful.period(const Duration(seconds: 30)),
  ///   // Keep listening through transient socket disconnects/reconnects
  ///   cancelOnError: false,
  ///   // Gracefully recover from transient network errors with cached fallback
  ///   onError: (error, st) => stockCache.getLastKnownPrice(selectedSymbol.what.peek),
  ///   distinct: true,
  ///   // Filters out heartbeat/timestamp-only updates to eliminate redundant downstream rebuilds
  ///   equals: (prev, next) => prev.price == next.price && prev.volume == next.volume,
  /// );
  /// ```
  ///
  /// ### 4. Re-subscribing / Reconnecting Stream with Signal:
  /// ```dart
  /// final reconnectSignal = WhatSignalController();
  ///
  /// // Automatically tears down previous subscription and re-subscribes when signal emits:
  /// final liveFeed = computed.stream((via) {
  ///   via(reconnectSignal.what); // Declarative stream restart trigger
  ///   return socketService.watchLiveFeed();
  /// });
  ///
  /// // Trigger reconnect on demand:
  /// reconnectSignal.emit();
  /// ```
  What<T> call<T>(
    Stream<T> Function(WhatVia via) compute, {
    WhatGuard Function(WhatVia via)? guard,
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
    bool? cancelOnError,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    Graceful? graceful,
  }) =>
      _StreamComputedWhat<T>(
        compute,
        guard: guard,
        initialFactory: initialFactory,
        onError: onError,
        cancelOnError: cancelOnError,
        distinct: distinct,
        equals: equals,
        graceful: graceful,
      );
}

// =============================================================================
// 1. Explicit Tracking Component Computations
// =============================================================================

/// An explicit [WhatVia]-tracking, class-based component computation base class.
///
/// [Computation] elevates reactive computations into reusable, encapsulated domain components.
/// While inline [computed] closures are ideal for concise formulas, [Computation] is designed
/// for complex domain derivations:
///
/// 1. **Explicit [WhatVia] Dependency Tracking**: All upstream dependencies are explicitly
///    declared via [WhatVia] inside [compute] and [guard] with 1-pass zero-allocation Epoch diffing.
/// 2. **Object-Oriented Encapsulation**: Cleanly organize complex derivation logic with
///    private helper methods, constructor injection, and encapsulated instance state.
/// 3. **Dynamic Conditional Branching**: Seamlessly rewires dependency edges when branching
///    on runtime conditions (`if (flag) via(a) else via(b)`).
/// 4. **Built-In Reactive Guards**: Override [guard] with [WhatGuard] to gate computation
///    and transition to an empty state without throwing exceptions or returning nullable hacks.
/// 5. **Lifecycle Integration**: Implement [WhatLifecycleAware] to cleanly coordinate
///    with external services/streams via [WhatLifecycleAware.didActivate] and [WhatLifecycleAware.didDeactivate].
/// 6. **Direct Ergonomics**: Access computed state directly (`.data`, `.snapshot`, `.hasData`,
///    `.isEmpty`, `.emptyReason`) on the component instance without chaining `.what`.
///
/// ## Comparison Matrix
/// | Feature | `computed((via) => ...)` | `Computation<T>` |
/// | :--- | :---: | :---: |
/// | **Style** | Inline lambda | Class component |
/// | **Dependency Tracking** | **Explicit** ([WhatVia]) | **Explicit** ([WhatVia]) |
/// | **Dynamic Branching** | Supported | Supported |
/// | **Helper Methods** | Awkward (closures) | **Natural** (class methods) |
/// | **Reactive Guards** | Optional parameter | **Overridable methods** |
/// | **Lifecycle Hooks** | Via separate node | **[WhatLifecycleAware]** |
///
/// ## System Architectural Flow
/// ```text
/// [Constructor: class OrderSummaryComp extends Computation<OrderSummary>]
///                                    │
///                    Instantiates internal _ComputationWhat
///                                    │
/// [Downstream Reads .data / .snapshot]
///                                    │ (Pull-Data on-demand)
///                                    ▼
///                             [guard(via).isPass?]
///                            ├── No  ──> Emits Empty(guard.reason) [compute() NOT called]
///                            └── Yes ──> Invokes compute(via) with 1-Pass Epoch Diffing
///                                             │
///                                             ▼
///                                  Returns computed [T] payload
/// ```
///
/// ## Examples
///
/// ### 1. Complex Domain Component with Helper Methods:
/// ```dart
/// class OrderPricingComputation extends Computation<OrderPricing> {
///   OrderPricingComputation(this.cart, this.user, this.promoCode);
///
///   final What<Cart> cart;
///   final What<User> user;
///   final What<PromoCode?> promoCode;
///
///   @override
///   OrderPricing compute(WhatVia via) {
///     final items = via(cart).items;
///     final subtotal = _calculateSubtotal(items);
///     final discount = _applyPromo(subtotal, via(promoCode));
///     final tax = _calculateTax(subtotal - discount, via(user).location);
///     return OrderPricing(subtotal: subtotal, discount: discount, tax: tax);
///   }
///
///   double _calculateSubtotal(List<CartItem> items) => ...;
///   double _applyPromo(double subtotal, PromoCode? promo) => ...;
///   double _calculateTax(double taxable, Location loc) => ...;
/// }
///
/// // Usage:
/// final pricing = OrderPricingComputation(cartWhat, userWhat, promoWhat);
/// print(pricing.data.total);
/// ```
///
/// ### 2. Guarded Computation with Granular Preconditions & UI Guidance:
/// ```dart
/// class LoanQuoteComputation extends Computation<LoanQuote> {
///   LoanQuoteComputation(this.incomeWhat, this.creditScoreWhat);
///
///   final What<IncomeInfo> incomeWhat;
///   final What<CreditScore> creditScoreWhat;
///
///   @override
///   WhatGuard guard(WhatVia via) {
///     if (via.state(incomeWhat).isEmpty) return WhatGuard.block('Please enter income information first.');
///     if (via.state(creditScoreWhat).isEmpty) return WhatGuard.block('Credit score verification is in progress.');
///     return WhatGuard.pass;
///   }
///
///   @override
///   LoanQuote compute(WhatVia via) =>
///       LoanQuote.calculate(via(incomeWhat), via(creditScoreWhat));
/// }
///
/// // Downstream UI usage:
/// // ElevatedButton(
/// //   onPressed: quote.hasData ? () => submit() : null,
/// //   child: Text(quote.hasData ? 'Apply Now' : '${quote.emptyReason}'),
/// // );
/// ```
abstract base class Computation<T> with _WhatStateMixin<T> implements LpdagStatus {
  Computation({
    WhatGuard Function(WhatVia via)? guard,
  }) : _guard = guard {
    _what = _ComputationWhat.create(this);
  }

  late final What<T> _what;
  final WhatGuard Function(WhatVia via)? _guard;

  /// Exposes the underlying topological [What] node that powers this computation.
  @pragma('vm:prefer-inline')
  What<T> get what => _what;

  /// Optional precondition check evaluated prior to [compute].
  ///
  /// Defaults to invoking [_guard] if supplied in constructor, or [WhatGuard.pass] otherwise.
  /// Can be overridden by subclasses for custom precondition logic.
  /// Dependencies accessed inside [guard] are explicitly tracked via [via].
  WhatGuard guard(WhatVia via) => _guard?.call(via) ?? WhatGuard.pass;

  /// Performs the actual synchronous calculation.
  ///
  /// All reactive dependencies accessed inside this method are explicitly tracked via [via]
  /// using 1-pass zero-allocation Epoch diffing.
  T compute(WhatVia via);

  /// Indicates whether the underlying topological node is currently active in the graph.
  @override
  @pragma('vm:prefer-inline')
  bool get isActive => what.isActive;

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _read() => _what._read();
}

// =============================================================================
// 2. Lifecycle Interception
// =============================================================================

/// A mixin for computations to intercept and react to downstream lifecycle state changes.
///
/// Mix this into a [Computation] to receive notification callbacks
/// ([didActivate] and [didDeactivate]) triggered by downstream terminals.
/// Custom computations frequently manage external resources (e.g. timers, web sockets, hardware sensors).
/// Initializing these resources in constructor code causes battery and memory leaks.
/// This mixin propagates lifecycle state *in reverse* from downstream consumers, ensuring heavy
/// resources are active only when actively observed.
///
/// ## Lifecycle Propagation Flow (Consumer-Driven)
/// ```text
/// [Downstream Terminal (e.g. RawWhatTerminal / UI Widget)]
///        │ (0 -> 1 subscribers: terminal.activate())
///        ▼
/// [WhatLifecycleAware Computation Node]
///        │ (Invokes didActivate(): allocates heavy resources / starts updates)
///        │
///        ... (Active Observation Phase) ...
///        │
///        ▼ (1 -> 0 subscribers: terminal.deactivate())
/// [WhatLifecycleAware Computation Node]
///        │ (Invokes didDeactivate(): cleanly releases resources / stops updates)
/// ```
///
/// **Warning (Anti-Pattern Prevention):**
/// - [didDeactivate] MUST cleanly and synchronously release any resources allocated during [didActivate].
/// - NEVER start infinite timers or unmanaged streams in the constructor; always defer to [didActivate].
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Starting persistent service in constructor leads to battery/memory leaks
/// class LeakyLocationComputation extends Computation<Location> {
///   LeakyLocationComputation(this.gpsService) {
///     gpsService.startUpdates(); // Starts immediately even if unobserved!
///   }
///   final GpsService gpsService;
///
///   @override
///   Location compute(WhatVia via) => gpsService.currentLocation;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Deferred allocation and deterministic teardown via WhatLifecycleAware
/// class LocationComputation extends Computation<Location> with WhatLifecycleAware {
///   LocationComputation(this.gpsService);
///   final GpsService gpsService;
///
///   @override
///   void didActivate() {
///     super.didActivate();
///     gpsService.startUpdates();
///   }
///
///   @override
///   void didDeactivate() {
///     super.didDeactivate();
///     gpsService.stopUpdates();
///   }
///
///   @override
///   Location compute(WhatVia via) => gpsService.currentLocation;
/// }
/// ```
base mixin WhatLifecycleAware {
  /// Invoked when the first downstream terminal attaches and activates the pipeline (0 -> 1 subscribers).
  ///
  /// **Ensures:**
  /// * Called exactly once when transitioning from zero to one active downstream consumer.
  @mustCallSuper
  void didActivate() {}

  /// Invoked when the last downstream terminal detaches and deactivates the pipeline (1 -> 0 subscribers).
  ///
  /// **Ensures:**
  /// * Called exactly once when active downstream consumers drop to zero.
  @mustCallSuper
  void didDeactivate() {}
}
