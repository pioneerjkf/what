// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/widgets.dart';
/// @docImport 'package:what/what.dart';
/// @docImport 'framework.dart';
///
/// High-performance reactive Flutter framework connecting What's 2-Phase LPDAG engine with the Flutter element tree.
///
/// `what_flutter` embeds reactive [RawComputedTerminal] and [RawWhatTerminal] boundary sinks
/// directly into specialized lightweight [Element]s, enabling surgical micro-rebuilds,
/// declarative auto-tracked widgets, zero-boilerplate animations, and leak-free lifecycle-bound state management.
///
/// ## Architectural Overview
///
/// In standard Flutter development, state changes frequently trigger wide subtree rebuilds,
/// leading to frame drops and redundant widget evaluations. `what_flutter` solves this by
/// embedding reactive terminals into [Element] nodes via `_ReactiveTerminalElementMixin`.
///
/// Under the 2-Phase LPDAG architecture:
/// 1. **Phase 1: Push-Dirty ($O(1)$ Invalidation)**: When an upstream [What] mutates, dirty notifications propagate
///    topologically in $O(1)$ to leaf terminals, triggering [Element.markNeedsBuild] without recomputing values.
/// 2. **Phase 2: Lazy-Pull (On-Demand Evaluation)**: During Flutter's render pipeline, only the exact invalidated leaf elements
///    pull and evaluate their dependencies inside [RawComputedTerminal.data], leaving the surrounding
///    widget tree completely untouched.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────────┐
/// │                         Flutter Widget Tree Layer                          │
/// │                                                                            │
/// │   • WhatWidget                           : Auto-tracked Flutter widgets    │
/// │   • composed((context, via) => ...)      : Surgical inline micro-rebuild   │
/// │   • what.build(...)                      : Direct reactive node builders   │
/// │   • composed.animate                     : 60/120fps frame-isolated motion │
/// │   • composed.drive                       : Continuous frame-ticker drivers │
/// └─────────────────────────────────────┬──────────────────────────────────────┘
///                                       │ (1-Pass Zero-Alloc Epoch Diffing / Element Binding)
///                                       ▼
/// ┌────────────────────────────────────────────────────────────────────────────┐
/// │                Flutter Element Patching Layer (Terminal Mixins)            │
/// │                                                                            │
/// │   • _ReactiveTerminalElementMixin        : Mount/Activate/Deactivate sync  │
/// │   • _ViaTerminalElementMixin             : Dynamic branch sink             │
/// │   • _WhatTerminalElementMixin            : 1:1 direct single-source sink   │
/// └─────────────────────────────────────┬──────────────────────────────────────┘
///                                       │ (Push-Dirty Invalidation / Lazy-Pull Evaluation)
///                                       ▼
/// ┌────────────────────────────────────────────────────────────────────────────┐
/// │                    What Topological 2-Phase LPDAG Core                     │
/// │                                                                            │
/// │   • What<T> / WhatController<T>          : Canonical state nodes           │
/// │   • computed                             : Pure memoized derived state     │
/// │   • RawComputedTerminal / RawWhatTerminal: Boundary sinks & dirty routers  │
/// └────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Quick Start
///
/// ### 1. Surgical Inline Micro-Rebuilds (`composed`)
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:what_flutter/what_flutter.dart';
///
/// final counter = WhatController(0);
///
/// class CounterPage extends StatelessWidget {
///   const CounterPage({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: Column(
///         children: [
///           const HeavyHeaderWidget(), // NEVER rebuilds when counter changes!
///           // ONLY this Text rebuilds:
///           composed((context, via) => Text('Count: ${via(counter.what)}')),
///         ],
///       ),
///       floatingActionButton: FloatingActionButton(
///         onPressed: () => counter.data++,
///         child: const Icon(Icons.add),
///       ),
///     );
///   }
/// }
/// ```
///
/// ### 2. Declarative Reactive Widgets (`WhatWidget`)
/// ```dart
/// class UserProfileWidget extends WhatWidget {
///   UserProfileWidget({required this.userWhat, super.key});
///   final What<User> userWhat;
///
///   @override
///   Widget build(BuildContext context, WhatVia via) {
///     final user = via(userWhat);
///     return Text('User: ${user.name}');
///   }
/// }
/// ```
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT execute state mutations inside a `build()` method or within an active
///   reactive evaluation pass. Mutations during build violate Flutter's single-pass
///   layout/render contract and trigger reentrancy exceptions.
/// - Do NOT access `.peek` directly inside [WhatWidget.build] or `composed` without wrapping
///   in `via(...)`. Directly reading `.peek` bypasses dependency registration.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Reading .peek without via() inside composed
/// Widget build(BuildContext context) {
///   return composed((context, via) => Text('${counter.what.peek}')); // Not tracked!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Explicitly observe via(node)
/// Widget build(BuildContext context) {
///   return composed((context, via) => Text('${via(counter.what)}')); // Dynamically tracked
/// }
/// ```
library;

export 'package:what/what.dart';
export 'package:what/effect.dart';
export 'framework.dart' hide DurableAnimationTestingExtension;
