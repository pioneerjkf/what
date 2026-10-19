// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// WhatWidget & Reactive Core Element Hierarchy
// =============================================================================

/// A reactive widget that dynamically and explicitly tracks all [What] dependencies
/// declared via [WhatVia] within [build].
///
/// Seamlessly connects Flutter widget rebuild cycles with What's 2-Phase LPDAG engine
/// using 1-pass zero-allocation epoch diffing. Rather than managing manual streams, listeners,
/// or [ChangeNotifier] subscriptions, dependencies are registered dynamically and explicitly
/// via the injected [WhatVia] parameter in [build].
///
/// ## System Architectural Flow
/// ```text
/// [ Upstream What<T> Mutation ]
///        │
///        │ (Phase 1: O(1) Push-Dirty Invalidation)
///        ▼
/// [ RawComputedTerminal<Widget>.onInvalidated: markNeedsBuild() ]
///        │
///        │ (Flutter Engine Frame Pipeline Scheduling)
///        ▼
/// [ WhatElement.rebuild() -> performRebuild() ]
///        │
///        │ (Phase 2: Lazy-Pull Evaluation via terminal.data)
///        ▼
/// ┌────────────────────────────────────────────────────────────┐
/// │ If Clean: Returns cached Widget in O(1) (0-Compute)        │
/// │ If Dirty: Evaluates WhatWidget.build(context, via)         │
/// └────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **0-Compute Memoization**: When ancestor widgets rebuild without invalidating this widget's
///    observed [What] dependencies, `terminal.data` returns the cached widget in $O(1)$ without
///    re-evaluating [build].
/// 2. **Zero Heap Overhead in Hot Path**: Dynamic edge tracking utilizes 1-pass zero-allocation
///    epoch stamping, avoiding intermediate list allocations during rebuilds.
/// 3. **Dormancy Garbage Collection**: When the widget unmounts, all active graph subscriptions
///    detach synchronously via [RawTerminal.deactivate].
/// 4. **No Stateful Mutators**: [WhatWidget] is intentionally immutable and declarative. Never mutate
///    state synchronously inside [build].
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT read `.peek` directly without wrapping in `via(...)`, as untracked reads will not
///   trigger widget rebuilds when state changes.
/// - Do NOT mutate reactive state inside [build], as this triggers reentrancy loops and violates
///   Flutter's rendering contract.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Reading .peek directly bypasses dependency registration
/// class BadCounterWidget extends WhatWidget {
///   BadCounterWidget(this.countWhat, {super.key});
///   final What<int> countWhat;
///
///   @override
///   Widget build(BuildContext context, WhatVia via) {
///     return Text('Count: ${countWhat.peek}'); // NEVER rebuilds!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Explicitly observe dependencies via WhatVia
/// class GoodCounterWidget extends WhatWidget {
///   GoodCounterWidget(this.countWhat, {super.key});
///   final What<int> countWhat;
///
///   @override
///   Widget build(BuildContext context, WhatVia via) {
///     return Text('Count: ${via(countWhat)}'); // Dynamically tracked
///   }
/// }
/// ```
///
/// ## Examples
/// ```dart
/// class CounterPage extends StatelessWidget {
///   CounterPage({super.key});
///   final _counter = WhatController(0);
///
///   @override
///   Widget build(BuildContext context) {
///     return CounterView(counterWhat: _counter.what);
///   }
/// }
///
/// class CounterView extends WhatWidget {
///   CounterView({required this.counterWhat, super.key});
///   final What<int> counterWhat;
///
///   @override
///   Widget build(BuildContext context, WhatVia via) {
///     return Text('Count: ${via(counterWhat)}');
///   }
/// }
/// ```
abstract base class WhatWidget extends Widget {
  const WhatWidget({super.key});

  @override
  WhatElement createElement() => WhatElement(this);

  /// Describes the part of the user interface represented by this widget, with explicit [WhatVia] tracking.
  ///
  /// * [context]: The active Flutter [BuildContext] representing this widget's location in the element tree.
  /// * [via]: The injected [WhatVia] tracker used to dynamically and explicitly discover reactive dependencies.
  ///
  /// **Requires:**
  /// * [build] must be a pure, declarative function without mutations or unhandled asynchronous scheduling.
  ///
  /// **Ensures:**
  /// * Returns a [Widget] representing the current reactive user interface.
  @protected
  Widget build(BuildContext context, WhatVia via);
}

// =============================================================================
// WhatElement
// =============================================================================

/// The element managing the lifecycle of the reactive [RawComputedTerminal<Widget>] for a [WhatWidget].
///
/// Mixes in `_ReactiveTerminalElementMixin<RawComputedTerminal<Widget>>` and `_ViaTerminalElementMixin`
/// to bridge Flutter element lifecycle hooks ([mount], [activate], [deactivate], [reassemble], [unmount])
/// with the reactive LPDAG terminal sink.
base class WhatElement extends ComponentElement
    with
        _ReactiveTerminalElementMixin<RawComputedTerminal<Widget>>,
        _ViaTerminalElementMixin {
  WhatElement(WhatWidget super.widget);

  @override
  WhatWidget get widget => super.widget as WhatWidget;

  @override
  Widget _buildVia(WhatVia via) => widget.build(this, via);
}

// =============================================================================
// WhatVsyncWidget & WhatVsyncElement
// =============================================================================

/// A reactive widget that dynamically and explicitly tracks [What] dependencies
/// while providing an element-managed Flutter [TickerProvider]
/// for driving animations and tickers without boilerplate.
///
/// Seamlessly pairs [WhatWidget]'s reactive capabilities with element-level [TickerProvider] lifecycle management,
/// ensuring all tickers created via `vsync` are synchronized with [TickerMode] and safely disposed upon unmount.
///
/// ## System Architectural Flow
/// ```text
/// [ Upstream What<T> Mutation ]
///        │
///        │ (Phase 1: O(1) Push-Dirty Invalidation)
///        ▼
/// [ RawComputedTerminal<Widget>.onInvalidated: markNeedsBuild() ]
///        │
///        │ (Flutter Engine Frame Pipeline Scheduling)
///        ▼
/// [ WhatVsyncElement.rebuild() -> performRebuild() ]
///        │
///        │ (Phase 2: Lazy-Pull Evaluation via terminal.data)
///        ▼
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │ If Clean: Returns cached Widget in O(1) (0-Compute)                    │
/// │ If Dirty: Evaluates WhatVsyncWidget.build(context, via, vsync)         │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero Stateful Ticker Boilerplate**: Eliminates the need for [StatefulWidget] and [SingleTickerProviderStateMixin].
/// 2. **Immutable Const Contract**: Supports `const` constructors with zero mutable state on the widget instance.
/// 3. **Element-Owned Ticker Lifecycle**: The underlying [WhatVsyncElement] provides [TickerProvider] directly,
///    preventing re-binding hazards and memory leaks across rebuilds.
/// 4. **Automatic Ticker Muting**: Integrates with Flutter's [TickerMode], pausing tickers automatically
///    when routes or tabs are hidden or inactive.
/// 5. **0-Compute Memoization**: Inherits [RawComputedTerminal] caching to skip rebuilds when dependencies remain clean.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT create raw [AnimationController] instances inside [build] directly, as rebuilding creates new
///   controllers and leaks resources. Use external durable controllers or initialize persistent resources in a ViewModel.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Re-allocating controller resource inside build()
/// Widget build(BuildContext context, WhatVia via, TickerProvider vsync) {
///   final ctrl = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 300)); // Leak!
///   return FadeTransition(opacity: ctrl, child: const Text('Hello'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Pass vsync to external components or use composed.animate
/// class TabbedHeaderWidget extends WhatVsyncWidget {
///   const TabbedHeaderWidget({required this.tabIndexWhat, super.key});
///   final What<int> tabIndexWhat;
///
///   @override
///   Widget build(BuildContext context, WhatVia via, TickerProvider vsync) {
///     final tabIndex = via(tabIndexWhat);
///     return DefaultTabController(
///       length: 3,
///       initialIndex: tabIndex,
///       child: const TabBar(tabs: [Tab(text: 'A'), Tab(text: 'B'), Tab(text: 'C')]),
///     );
///   }
/// }
/// ```
///
/// ## Examples
/// ```dart
/// class CustomTickerWidget extends WhatVsyncWidget {
///   const CustomTickerWidget({required this.activeWhat, super.key});
///   final What<bool> activeWhat;
///
///   @override
///   Widget build(BuildContext context, WhatVia via, TickerProvider vsync) {
///     final isActive = via(activeWhat);
///     return Text('Active: $isActive, Vsync: $vsync');
///   }
/// }
/// ```
abstract base class WhatVsyncWidget extends Widget {
  /// Initializes a [WhatVsyncWidget] with an optional [key].
  const WhatVsyncWidget({super.key});

  @override
  WhatVsyncElement createElement() => WhatVsyncElement(this);

  /// Describes the part of the user interface represented by this widget, with explicit [WhatVia] tracking
  /// and an injected [TickerProvider].
  ///
  /// * [context]: The active Flutter [BuildContext] representing this widget's location in the element tree.
  /// * [via]: The injected [WhatVia] tracker used to dynamically and explicitly discover reactive dependencies.
  /// * [vsync]: The element-bound [TickerProvider] used to drive or couple animations.
  ///
  /// **Requires:**
  /// * [build] must be a pure, declarative function without unhandled asynchronous mutations.
  ///
  /// **Ensures:**
  /// * Returns a [Widget] representing the current reactive user interface.
  @protected
  Widget build(
    BuildContext context,
    WhatVia via,
    TickerProvider vsync,
  );
}

/// The element managing both the reactive [RawComputedTerminal<Widget>] and [TickerProvider] lifecycle for a [WhatVsyncWidget].
base class WhatVsyncElement extends ComponentElement
    with
        _TickerProviderElementMixin,
        _ReactiveTerminalElementMixin<RawComputedTerminal<Widget>>,
        _ViaTerminalElementMixin {
  /// Creates a [WhatVsyncElement] managing [widget].
  WhatVsyncElement(WhatVsyncWidget super.widget);

  @override
  WhatVsyncWidget get widget => super.widget as WhatVsyncWidget;

  @override
  Widget _buildVia(WhatVia via) => widget.build(this, via, this);
}
