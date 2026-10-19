// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// WhatProvider<T> & Scoped State Provision System
// =============================================================================

/// An [InheritedWidget] providing a reactive [What<T>] node to descendant widgets with rebuild wave suppression.
///
/// In standard Flutter development, updating inherited widget state triggers wide subtree rebuilds across
/// all dependent elements. `WhatProvider` eliminates these rebuild storms by decoupling structural element
/// scoping from reactive state propagation:
/// * [updateShouldNotify] only returns `true` if the underlying [what] node reference itself changes (`!identical`).
/// * Descendant widgets observe state via `via.of<T>(context)` or `via(context.whatOf<T>())`.
/// * Mutations to the [What] node's payload propagate surgically through What's 2-Phase LPDAG engine directly
///   to leaf terminals, leaving intermediate and sibling widgets completely untouched.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                    WhatProvider Element Architecture                   │
/// ├────────────────────────────────────────────────────────────────────────┤
/// │                                                                        │
/// │   [ WhatProvider<T>(what: myWhat) ] ── (InheritedWidget In Element Tree)
/// │                  │                                                     │
/// │                  │ (updateShouldNotify returns !identical(old, new))   │
/// │                  ▼                                                     │
/// │   [ Intermediate Static Widgets ]  ──► Bypasses Rebuilds (0 Rebuilds!) │
/// │                  │                                                     │
/// │                  ▼                                                     │
/// │   [ Descendant WhatWidget / composed ]                                 │
/// │                  │                                                     │
/// │                  ├─► context.whatOf<T>()    ──► Fetches What<T> node   │
/// │                  └─► via.of<T>(context)     ──► Registers in 2-Phase   │
/// │                                                 LPDAG (Leaf Only Rebuild)
/// │                                                                        │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero Subtree Rebuild Storms**: State mutations inside [what] never trigger wide `InheritedWidget` rebuild passes.
/// 2. **Surgical Leaf Rebuilds**: Only widgets explicitly observing the state via [WhatVia] are invalidated in $O(1)$.
/// 3. **Sound Scoped Discovery**: Seamless context lookup via [WhatBuildContextProviderExtension.whatOf]
///    and [WhatViaContextExtension.of].
///
/// **Warning (Anti-Pattern Prevention):**
/// - Avoid wrapping transient subtrees with new [WhatProvider] instances repeatedly in build methods
///   with newly constructed [What] nodes, which forces tree replacement.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] New controller instantiated per frame in provider
/// Widget build(BuildContext context) {
///   return WhatProvider(what: WhatController(0).what, child: const ChildWidget());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Provide stable cached state
/// class FeaturePage extends StatelessWidget {
///   FeaturePage({super.key});
///   final counter = WhatController(0);
///
///   @override
///   Widget build(BuildContext context) {
///     return WhatProvider<int>(what: counter.what, child: const CounterDisplay());
///   }
/// }
/// ```
///
/// ## Examples
/// ```dart
/// // Providing state at an ancestor level
/// WhatProvider<CounterState>(
///   what: counterController.what,
///   child: const CounterDisplay(),
/// );
///
/// // Consuming in a descendant WhatWidget
/// base class CounterDisplay extends WhatWidget {
///   const CounterDisplay({super.key});
///
///   @override
///   Widget build(BuildContext context, WhatVia via) {
///     final state = via.of<CounterState>(context);
///     return Text('Count: ${state.count}');
///   }
/// }
/// ```
class WhatProvider<T> extends InheritedWidget {
  /// Creates a [WhatProvider] binding [what] into the widget subtree.
  ///
  /// * [what]: The reactive state carrier node to provide.
  /// * [child]: The descendant widget subtree that can query this state.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [what] and [child] must not be null.
  ///
  /// **Ensures:**
  /// * Provisions [what] to descendants with forced rebuild suppression.
  const WhatProvider({
    super.key,
    required this.what,
    required super.child,
  });

  /// The provided reactive state carrier node.
  final What<T> what;

  /// Returns `true` only if the [what] node reference has changed.
  @override
  bool updateShouldNotify(covariant WhatProvider<T> oldWidget) {
    return !identical(oldWidget.what, what);
  }

  /// Retrieves the [What<T>] state from the nearest ancestor [WhatProvider<T>].
  ///
  /// * [context]: The active [BuildContext] to search upwards from.
  ///
  /// **Requires:**
  /// * An ancestor [WhatProvider<T>] must exist in the [context] hierarchy.
  ///
  /// **Ensures:**
  /// * Returns the nearest ancestor [What<T>] node.
  static What<T> of<T>(BuildContext context) => context.whatOf<T>();

  /// Retrieves the [What<T?>] state from the nearest ancestor [WhatProvider<T>], if present.
  ///
  /// * [context]: The active [BuildContext] to search upwards from.
  ///
  /// **Ensures:**
  /// * Returns the ancestor provider's [What<T>], or [What.constant(null)] if no matching ancestor provider exists.
  static What<T?> maybeOf<T>(BuildContext context) => context.maybeWhatOf<T>();
}

/// A convenience extension for converting a [What] into a [WhatProvider].
extension WhatProvideExtension<T> on What<T> {
  /// Wraps [child] in a [WhatProvider<T>] providing this reactive [What] node.
  ///
  /// * [child]: The descendant widget subtree receiving this state.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [child] must not be null.
  ///
  /// **Ensures:**
  /// * Returns a [WhatProvider<T>] embedding this reactive [What] node.
  ///
  /// ## Examples
  /// ```dart
  /// counterWhat.provide(child: const CounterDisplay());
  /// ```
  WhatProvider<T> provide({Key? key, required Widget child}) =>
      WhatProvider<T>(key: key, what: this, child: child);
}

/// Context-aware reactive lookup extensions on [BuildContext] for [WhatProvider].
extension WhatBuildContextProviderExtension on BuildContext {
  /// Reactively subscribes to an ancestor [WhatProvider] and returns its inner [What<T>] state.
  ///
  /// **Requires:**
  /// * An ancestor [WhatProvider<T>] must exist in the widget tree when evaluated.
  ///
  /// **Ensures:**
  /// * Registers this [BuildContext] as a dependent on the ancestor [WhatProvider<T>]
  ///   and returns its inner [What<T>] reactive node.
  ///
  /// **Throws:**
  /// * Throws [AssertionError] in debug mode if no matching [WhatProvider<T>] is found in the current hierarchy.
  @pragma('vm:prefer-inline')
  What<T> whatOf<T>() {
    final provider = dependOnInheritedWidgetOfExactType<WhatProvider<T>>();
    assert(
      provider != null,
      'No ancestor WhatProvider<$T> found in the current BuildContext hierarchy.',
    );
    return provider!.what;
  }

  /// Reactively subscribes to an optional ancestor [WhatProvider] and returns its inner [What<T?>] state.
  ///
  /// **Ensures:**
  /// * Returns the ancestor provider's [What<T>], or [What.constant(null)] if no matching ancestor provider exists.
  @pragma('vm:prefer-inline')
  What<T?> maybeWhatOf<T>() {
    final provider = dependOnInheritedWidgetOfExactType<WhatProvider<T>>();
    return provider?.what ?? What.constant(null);
  }
}

/// Context-aware reactive observation extensions on [WhatVia] for [WhatProvider].
extension WhatViaContextExtension on WhatVia {
  /// Reactively discovers and observes an ancestor [WhatProvider<T>] within [context].
  ///
  /// Connects [WhatBuildContextProviderExtension.whatOf] with this [WhatVia] tracking scope in a single,
  /// fluent call, eliminating nested `via(context.whatOf<T>())` boilerplate.
  ///
  /// * [context]: The active [BuildContext] to locate the ancestor provider from.
  ///
  /// **Requires:**
  /// * An ancestor [WhatProvider<T>] must exist in the [context] widget tree.
  ///
  /// **Ensures:**
  /// * Subscribes this reactive tracking scope to the ancestor [What<T>] node.
  /// * Returns the underlying value of type [T].
  ///
  /// ## Examples
  /// ```dart
  /// @override
  /// Widget build(BuildContext context, WhatVia via) {
  ///   final store = via.of<ShowcaseStore>(context);
  ///   return Text(store.title);
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  T of<T>(BuildContext context) => this(context.whatOf<T>());

  /// Reactively discovers and observes an optional ancestor [WhatProvider<T>] within [context].
  ///
  /// Connects [WhatBuildContextProviderExtension.maybeWhatOf] with this [WhatVia] tracking scope in a single,
  /// fluent call, eliminating nested `via(context.maybeWhatOf<T>())` boilerplate.
  ///
  /// * [context]: The active [BuildContext] to locate the ancestor provider from.
  ///
  /// **Ensures:**
  /// * Subscribes this reactive tracking scope to the ancestor [What<T?>] node if found,
  ///   or [What.constant(null)] if no matching provider exists.
  /// * Returns the underlying value of type [T?].
  ///
  /// ## Examples
  /// ```dart
  /// @override
  /// Widget build(BuildContext context, WhatVia via) {
  ///   final theme = via.maybeOf<AppTheme>(context);
  ///   return Text(theme?.name ?? 'Default');
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  T? maybeOf<T>(BuildContext context) => this(context.maybeWhatOf<T>());
}
