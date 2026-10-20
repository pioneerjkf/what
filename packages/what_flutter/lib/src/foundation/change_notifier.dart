// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// ValueListenable -> What Reactive Bridge
// =============================================================================

/// A convenience extension bridging Flutter's [ValueListenable] with the What reactive pipeline.
///
/// Converts any [ValueListenable] (such as [ValueNotifier]) into a demand-driven, read-only
/// [What] node, seamlessly integrating Flutter's foundation primitives into What's 2-Phase
/// LPDAG reactive engine.
///
/// ## System Architectural Flow
/// ```text
/// ┌─────────────────────────────────────────────────────────────────────────────────┐
/// │                     Demand-Driven Listenable Bridge Flow                        │
/// ├─────────────────────────────────────────────────────────────────────────────────┤
/// │                                                                                 │
/// │   [ Initial State: No Active Consumers (isActive == false) ]                   │
/// │   ValueListenable (Dormant) ──► Listenable.addListener is NOT called!           │
/// │                                                                                 │
/// │   [ Event: Terminal Subscribes via via(bridgeWhat) ]                            │
/// │          │                                                                      │
/// │          ▼                                                                      │
/// │   terminal.activate() ──► Bridge executes Listenable.addListener(_listen)       │
/// │                                  │ (Catches up to latest value on activation)   │
/// │                                  ▼                                              │
/// │   Listenable.notifyListeners() ──► Extracts value ──► Distinct Equality Check?  │
/// │                                                          │                      │
/// │                            ┌─────────────────────────────┴────────┐             │
/// │                            ▼ (Identical Value)                    ▼ (Changed)   │
/// │                         [ DROP ]                        Topological Push-Dirty  │
/// │                                                                                 │
/// │   [ Event: Terminal Unmounts / Navigates Away ]                                 │
/// │          │                                                                      │
/// │          ▼                                                                      │
/// │   terminal.deactivate() ──► Bridge executes Listenable.removeListener(_listen)  │
/// │                             (Zero dangling callbacks, zero memory leaks!)       │
/// │                                                                                 │
/// └─────────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Architectural Benefits
/// 1. **Subscriber-Driven Inactive Dormancy**: Listeners are attached to the source [ValueListenable]
///    if and only if active downstream terminals observe this node. Zero callbacks remain when idle.
/// 2. **Activation Catch-Up**: Upon activation, evaluates `setGuarded` to synchronize any value changes
///    that took place while dormant before registering the listener.
/// 3. **Built-In Distinct Deduplication**: Suppresses redundant downstream push-dirty pulses when
///    consecutive notifications emit identical values (or values equal under `equals`).
/// 4. **Microtask Deferral**: Supports [Graceful] policies to defer listener unregistration across
///    rapid widget unmount/remount transitions.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT call `.toWhat()` repeatedly inside `build()` methods or reactive computations without caching,
///   as it instantiates a new [What] node and registers duplicate listeners on every render pass.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Calling toWhat() on every render pass
/// Widget build(BuildContext context) {
///   final countWhat = myNotifier.toWhat(); // Re-subscribed on every build!
///   return composed((context, via) => Text('Count: ${via(countWhat)}'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Bridge once in the state or controller layer
/// class MyController {
///   MyController(this.myNotifier);
///   final ValueNotifier<int> myNotifier;
///   late final countWhat = myNotifier.toWhat();
/// }
/// ```
///
/// ## Examples
/// ```dart
/// final counterNotifier = ValueNotifier<int>(0);
/// final counterWhat = counterNotifier.toWhat();
/// ```
extension ValueListenableWhatExtension<T> on ValueListenable<T> {
  /// Converts this [ValueListenable] into a demand-driven reactive [What] node.
  ///
  /// The listener registration is deferred until the returned [What] node is activated,
  /// and is automatically cleaned up when the node is deactivated.
  ///
  /// * [distinct]: When `true`, suppresses dirty invalidations if consecutive values
  ///   are equal according to [equals]. Defaults to `true`.
  /// * [equals]: An optional custom equality function to compare the previous and next values
  ///   when [distinct] is enabled.
  /// * [graceful]: Optional [Graceful] policy delaying listener deregistration across rapid remounts.
  ///
  /// **Requires:**
  /// * If [equals] is provided, [distinct] MUST be set to `true`.
  ///
  /// **Ensures:**
  /// * Returns a reactive, read-only [What<T>] node reflecting the latest values of this [ValueListenable].
  /// * Subscribes to this [ValueListenable] only while active, and unsubscribes on deactivation.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT invoke `notifier.toWhat(...)` inside widget `build()` methods without caching.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Invoking toWhat() repeatedly inside build
  /// Widget build(BuildContext context) {
  ///   final what = notifier.toWhat(); // Accumulates duplicate bridge nodes!
  ///   return composed((context, via) => Text('${via(what)}'));
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Cache once as a field in a controller or state class
  /// class CounterStore {
  ///   CounterStore(this.notifier);
  ///   final ValueNotifier<int> notifier;
  ///   late final countWhat = notifier.toWhat();
  /// }
  /// ```
  ///
  /// ## Examples
  ///
  /// ### 1. Converting a ValueNotifier in a Controller
  /// ```dart
  /// class CounterController {
  ///   CounterController(this.notifier);
  ///   final ValueNotifier<int> notifier;
  ///   late final countWhat = notifier.toWhat();
  /// }
  /// ```
  ///
  /// ### 2. Consuming Inside an Auto-Tracked WhatWidget
  /// ```dart
  /// base class CounterView extends WhatWidget {
  ///   CounterView(this.controller, {super.key});
  ///   final CounterController controller;
  ///
  ///   @override
  ///   Widget build(BuildContext context, WhatVia via) {
  ///     return Text('Count: ${via(controller.countWhat)}');
  ///   }
  /// }
  /// ```
  What<T> toWhat({
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    Graceful? graceful,
  }) =>
      _ValueListenableWhatPipe<T>(
        this,
        distinct: distinct,
        equals: equals,
        graceful: graceful,
      ).what;
}

// =============================================================================
// Listenable -> What Reactive Selector Bridge
// =============================================================================

/// A convenience extension bridging Flutter's generic [Listenable] with the What pipeline via selector extraction.
///
/// Transforms multi-property, high-frequency [Listenable] instances (such as [ScrollController],
/// [TextEditingController], or [AnimationController]) into targeted reactive [What] slices.
///
/// ## System Architectural Flow
/// ```text
/// ┌─────────────────────────────────────────────────────────────────────────────────┐
/// │                    Granular Selector Extraction Bridge Flow                     │
/// ├─────────────────────────────────────────────────────────────────────────────────┤
/// │                                                                                 │
/// │   [ Multi-Property Controller: ScrollController / TextEditingController ]       │
/// │                                                                                 │
/// │   [ Subscriber Connects: terminal.activate() ]                                  │
/// │          │                                                                      │
/// │          ▼                                                                      │
/// │   Listenable.addListener(_listen)                                               │
/// │          │ (High-frequency notifications: scroll, velocity, cursor ticks)       │
/// │          ▼                                                                      │
/// │   select(listenable) ──► Exception thrown?                                      │
/// │          │                      │                                               │
/// │          ▼ (Success: R)         ▼ (Throws: unattached clients, etc.)            │
/// │   Distinct Check?        Transitions to Error State                             │
/// │     │        │           (Safe fault containment without crashing tree)         │
/// │     ▼ (Equal)▼ (Different)                                                      │
/// │   [ DROP ]  Topological Push-Dirty                                              │
/// │                                                                                 │
/// │   [ Subscriber Disconnects: terminal.deactivate() ]                             │
/// │          │                                                                      │
/// │          ▼                                                                      │
/// │   Listenable.removeListener(_listen) ──► [ Dormant: 0 Listeners ]               │
/// │                                                                                 │
/// └─────────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Architectural Benefits
/// 1. **Fine-Grained Extraction**: Transforms multi-property listenables into targeted reactive streams.
/// 2. **Automatic Distinct Filtering**: Filters out high-frequency irrelevant notifications (e.g. scroll
///    velocity changes when only tracking offset thresholds).
/// 3. **Fault Containment**: Safely initializes in an Error state if `selector` throws during construction
///    (e.g., accessing controller metrics before clients are attached), recovering automatically upon activation.
/// 4. **Demand-Driven Lifecycle**: Detaches listener callbacks immediately when downstream consumers unmount.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Avoid calling `toWhatBy(...)` repeatedly in build methods without caching.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Re-creates What pipeline on every build pass
/// Widget build(BuildContext context, WhatVia via) {
///   final offsetWhat = scrollController.toWhatBy((c) => c.offset);
///   return Text('${via(offsetWhat)}');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Cache extracted reactive pipeline once in a field
/// base class ScrollIndicator extends WhatWidget {
///   ScrollIndicator(this.controller, {super.key});
///   final ScrollController controller;
///   late final offsetWhat = controller.toWhatBy((c) => c.hasClients ? c.offset : 0.0);
///
///   @override
///   Widget build(BuildContext context, WhatVia via) {
///     return Text('Offset: ${via(offsetWhat)}');
///   }
/// }
/// ```
///
/// ## Examples
/// ```dart
/// final scrollController = ScrollController();
/// late final offsetWhat = scrollController.toWhatBy((c) => c.hasClients ? c.offset : 0.0);
/// ```
extension ListenableWhatExtension<L extends Listenable> on L {
  /// Converts this [Listenable] into a reactive [What] node by extracting a value
  /// using the provided [selector] function.
  ///
  /// The selector is evaluated immediately upon bridge creation. If [selector] throws
  /// an exception during initialization, the returned node safely initializes in an Error
  /// state ([WhatState.hasError] == `true`), preventing element construction failures.
  /// When active, subsequent change notifications re-evaluate [selector] via `setGuarded`
  /// and automatically transition back to the Data state upon recovery.
  ///
  /// * [selector]: Extraction callback producing value [R] from this [Listenable].
  /// * [distinct]: When `true`, suppresses emissions if consecutive extracted values are equal. Defaults to `true`.
  /// * [equals]: Custom equality function used when [distinct] is enabled.
  /// * [graceful]: Optional policy to defer listener unregistration across rapid remounts.
  ///
  /// **Requires:**
  /// * If [equals] is provided, [distinct] MUST be set to `true`.
  ///
  /// **Ensures:**
  /// * Returns a reactive [What<R>] node reflecting the selected slice of this [Listenable].
  /// * Attaches a listener to this [Listenable] only while active, and detaches upon deactivation.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Avoid invoking `controller.toWhatBy(...)` repeatedly inside `build()` passes without caching.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Invoking toWhatBy inside build creates redundant bridges
  /// Widget build(BuildContext context) {
  ///   final textWhat = textController.toWhatBy((c) => c.text);
  ///   return composed((context, via) => Text(via(textWhat)));
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Declare and cache the projection once in a field
  /// class SearchBarController {
  ///   SearchBarController(this.textController);
  ///   final TextEditingController textController;
  ///   late final textWhat = textController.toWhatBy((c) => c.text, distinct: true);
  /// }
  /// ```
  ///
  /// ## Examples
  ///
  /// ### 1. Scroll Offset Threshold Projection
  /// ```dart
  /// final scrollController = ScrollController();
  /// late final isCollapsedWhat = scrollController.toWhatBy(
  ///   (c) => c.hasClients && c.offset > 100.0,
  ///   distinct: true,
  /// );
  /// ```
  ///
  /// ### 2. TextEditingController Value Slice Extraction
  /// ```dart
  /// final textController = TextEditingController();
  /// late final textWhat = textController.toWhatBy(
  ///   (c) => c.text,
  ///   distinct: true,
  /// );
  /// ```
  What<R> toWhatBy<R>(
    R Function(L target) selector, {
    bool distinct = true,
    bool Function(R previous, R next)? equals,
    Graceful? graceful,
  }) =>
      _ListenableSelectorWhatPipe<L, R>(
        this,
        select: selector,
        distinct: distinct,
        equals: equals,
        graceful: graceful,
      ).what;
}

// =============================================================================
// What -> ValueListenable Reverse Bridge
// =============================================================================

/// A convenience extension bridging a reactive [What] node into Flutter's [ValueListenable].
///
/// Bridges What's reactive topology back to Flutter's foundation primitives, allowing
/// any reactive node to be consumed by widgets that require a standard [ValueListenable]
/// (such as [ValueListenableBuilder] or third-party animation controls).
///
/// ## System Architectural Flow
/// ```text
/// ┌─────────────────────────────────────────────────────────────────────────────────┐
/// │                    Reverse ValueListenable Mooring Architecture                 │
/// ├─────────────────────────────────────────────────────────────────────────────────┤
/// │                                                                                 │
/// │   [ Reactive DAG: What<T> ]                                                     │
/// │          │                                                                      │
/// │          ▼ (.toListenable(sync: bool))                                          │
/// │   _WhatValueListenable<T>                                                       │
/// │          │                                                                      │
/// │          ├─► .value ──► Evaluates untracked(_what) (Throws if Empty or Error)   │
/// │          │                                                                      │
/// │          ├─► .addListener(cb) ──► First Listener? (wasEmpty)                     │
/// │          │                             │                                        │
/// │          │                             ▼                                        │
/// │          │                      RawWhatTerminal.activate()                      │
/// │          │                      (Moored to What DAG; sync or coalesced)         │
/// │          │                                                                      │
/// │          ├─► Upstream Mutation ──► Terminal Invalidated                         │
/// │          │                             │                                        │
/// │          │                             ▼                                        │
/// │          │                      _notify() iterates listeners with               │
/// │          │                      FlutterError isolation per callback             │
/// │          │                                                                      │
/// │          └─► .removeListener(cb) ──► Last Listener? (_head == null)              │
/// │                                        │                                        │
/// │                                        ▼                                        │
/// │                                 RawWhatTerminal.deactivate()                    │
/// │                                 (Returns to Dormancy: 0 Standing Listeners)     │
/// │                                                                                 │
/// └─────────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Architectural Benefits
/// 1. **Zero-Overhead Terminal Mooring**: The internal [RawWhatTerminal] is created and activated
///    if and only if one or more Flutter listeners are registered. When all listeners are unlinked
///    (`_head == null`), it transitions to dormancy.
/// 2. **Flexible Invalidation Modes**: Supports immediate synchronous notifications (`sync: true`)
///    to satisfy standard Flutter expectations, or microtask batching (`sync: false`) via
///    [WhatComputationExtension.coalesced].
/// 3. **Fault-Tolerant Listener Notification**: Exceptions thrown inside registered Flutter listener
///    callbacks are caught and reported cleanly via [FlutterError.reportError], preventing starvation
///    of subsequent listeners.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT call `what.toListenable()` repeatedly inside `build()` passes or render loops,
///   as it creates a new [ValueListenable] instance with duplicate terminals on every frame.
/// - Ensure the [What] node contains valid data before reading [ValueListenable.value], as reading
///   an uninitialized (Empty) or Error node throws [WhatSnapshotExtractionException].
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Instantiating toListenable on every build pass
/// Widget build(BuildContext context) {
///   final listenable = countWhat.toListenable(); // Re-created every frame!
///   return ValueListenableBuilder<int>(
///     valueListenable: listenable,
///     builder: (context, value, _) => Text('Value: $value'),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Cache listenable bridge once in a controller or state object
/// class CounterViewModel {
///   CounterViewModel(this.countWhat);
///   final What<int> countWhat;
///   late final ValueListenable<int> countListenable = countWhat.toListenable();
/// }
/// ```
///
/// ## Examples
/// ```dart
/// final counter = WhatController<int>(0);
/// final ValueListenable<int> listenable = counter.what.toListenable();
/// ```
extension WhatListenableExtension<T> on What<T> {
  /// Converts this [What] into a standard Flutter [ValueListenable].
  ///
  /// The underlying [RawWhatTerminal] is created and activated only when the first
  /// listener attaches to the returned [ValueListenable], and is deactivated when the
  /// last listener detaches, maintaining zero standing overhead during dormancy.
  ///
  /// * [sync]: If `true` (default), notifies listeners synchronously upon state mutation,
  ///   preserving Flutter's standard [ValueListenable] contract. If `false`, applies
  ///   microtask batch coalescing via [WhatComputationExtension.coalesced].
  ///
  /// **Ensures:**
  /// * Returns a [ValueListenable<T>] whose [ValueListenable.value] accesses this [What<T>] node via [untracked].
  /// * Dynamically activates graph subscriptions on the first listener and deactivates on the last.
  ///
  /// **Throws:**
  /// * Throws [WhatSnapshotExtractionException] when accessing [ValueListenable.value]
  ///   if this node is in an Empty or Error state.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT call `what.toListenable()` repeatedly inside `build()` passes without caching.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Recreating listenable bridge in build
  /// Widget build(BuildContext context) {
  ///   return ValueListenableBuilder<int>(
  ///     valueListenable: countWhat.toListenable(), // New terminal on every build!
  ///     builder: (context, value, _) => Text('$value'),
  ///   );
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Declare and cache listenable bridge in controller or state
  /// class CounterState extends State<CounterWidget> {
  ///   late final countListenable = widget.countWhat.toListenable();
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return ValueListenableBuilder<int>(
  ///       valueListenable: countListenable,
  ///       builder: (context, value, _) => Text('$value'),
  ///     );
  ///   }
  /// }
  /// ```
  ///
  /// ## Examples
  ///
  /// ### 1. Bridging to ValueListenableBuilder
  /// ```dart
  /// final counter = WhatController<int>(0);
  /// final ValueListenable<int> listenable = counter.what.toListenable();
  ///
  /// Widget build(BuildContext context) {
  ///   return ValueListenableBuilder<int>(
  ///     valueListenable: listenable,
  ///     builder: (context, value, _) => Text('Count: $value'),
  ///   );
  /// }
  /// ```
  ///
  /// ### 2. Microtask Batch Coalesced Listenable
  /// ```dart
  /// // Coalesces multiple synchronous state mutations into a single microtask notification
  /// final coalescedListenable = streamWhat.toListenable(sync: false);
  /// ```
  ValueListenable<T> toListenable({bool sync = true}) =>
      _WhatValueListenable<T>(this, sync: sync);
}
