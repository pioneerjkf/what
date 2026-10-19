// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Top-Level Dynamic Switching Functor
// =============================================================================

/// Core declarative dynamic branching functor for reactive switching across disjoint subgraphs.
///
/// Evaluates `select` to dynamically switch between entirely different [What] graph subtrees,
/// flattening downstream subscriptions into a single continuous pipeline.
///
/// ## System Architectural Flow
/// ```text
/// [Switching Condition (e.g. isDark)] ──> Evaluates switched(via)
///                                                    │
///                   ┌────────────────────────────────┴────────────────────────────────┐
///                   ▼                                                                 ▼
///          [Active Branch A (What<T>)]                                       [Active Branch B (What<T>)]
///                   │                                                                 │
///                   └────────────────────────────────┬────────────────────────────────┘
///                                                    ▼ (Flattens into Unary Edge)
///                                           [Downstream Consumer]
/// ```
///
/// ## Architectural Benefits
/// 1. **Dynamic Graph Morphing**: Rewires reactive topology at runtime without tears or manual unsubscriptions.
/// 2. **Subtree Gating**: Prevents instantiating or activating entire downstream reactive subgraphs
///    when prerequisite conditions (e.g. user authentication) are unmet.
/// 3. **Dormant Inactive Branches**: Unselected subgraphs are completely detached from evaluation.
///
/// See [SwitchedFunctor.call] for complete parameter specifications, reactive guards,
/// and specialized dynamic branching patterns.
///
/// ## Examples
/// ```dart
/// final isDark = WhatController(false);
/// final lightTheme = WhatController('Light Theme');
/// final darkTheme = WhatController('Dark Theme');
///
/// final currentTheme = switched((via) => via(isDark.what) ? darkTheme.what : lightTheme.what);
/// ```
const switched = SwitchedFunctor._();

/// Callable functor managing dynamic topology switching.
@immutable
final class SwitchedFunctor {
  const SwitchedFunctor._();

  /// Creates a dynamically switched reactive [What] node with explicit [WhatVia] dependency tracking.
  ///
  /// Evaluates [select] to dynamically switch between entirely different [What] graph subtrees,
  /// flattening downstream subscriptions into a single continuous pipeline.
  ///
  /// * [select]: Pure synchronous selector closure returning the active [What] branch.
  /// * [guard]: Optional precondition check returning [WhatGuard] gating branch switching and providing diagnostic reasons.
  /// * [eager]: If `true`, pre-emptively resolves the selected branch in microtask when active.
  ///   Defaults to `false` (on-demand Lazy evaluation).
  ///
  /// **Ensures:**
  /// * Returns a reactive [What<T>] reflecting the currently selected branch.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Switch between *pre-existing, stable* [What] branches.
  /// - Do NOT instantiate new state controllers directly inside [select] without memoization,
  ///   as creating new nodes on every dependency tick orphans reactive subgraphs.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Re-creates controller on every branch evaluation
  /// final currentTheme = switched((via) {
  ///   return WhatController('Dark').what;
  /// });
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Return pre-existing or cached state nodes
  /// final currentTheme = switched((via) {
  ///   return via(isDark.what) ? darkTheme.what : lightTheme.what;
  /// });
  /// ```
  ///
  /// ## Examples
  ///
  /// ### 1. Simple Dynamic Branch Switching:
  /// ```dart
  /// final isDark = WhatController(false);
  /// final lightTheme = WhatController('Light Theme');
  /// final darkTheme = WhatController('Dark Theme');
  ///
  /// final currentTheme = switched((via) => via(isDark.what) ? darkTheme.what : lightTheme.what);
  /// ```
  ///
  /// ### 2. Subtree Gating with Precondition Guard:
  /// ```dart
  /// final selectedTab = WhatController(0);
  /// final isLoggedIn = WhatController(false);
  ///
  /// // Gating: Entire downstream feed graph is uninstantiated until user is authenticated
  /// final currentFeed = switched(
  ///   (via) => via(selectedTab.what) == 0 ? homeFeed.what : trendingFeed.what,
  ///   guard: (via) => via(isLoggedIn.what).guarded('UserNotAuthenticated'),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  What<T> call<T>(
    What<T> Function(WhatVia via) select, {
    WhatGuard Function(WhatVia via)? guard,
    bool eager = false,
  }) =>
      eager
          ? _EagerSwitchedWhat<T>(
              select: select,
              guard: guard,
            )
          : _LazySwitchedWhat<T>(
              select: select,
              guard: guard,
            );
}
