// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// @docImport 'src/framework.dart';
/// @docImport 'effect.dart';
///
/// High-performance 2-Phase Lazy-Pull DAG (LPDAG) reactive state management core.
///
/// The What framework provides an ultra-fast, topological reactive state engine
/// engineered for predictable state synchronization and minimal memory overhead.
///
/// ## Core Architectural Pillars
///
/// 1. **2-Phase LPDAG Execution Engine**:
///    - **Phase 1: Push-Dirty (Lightweight Invalidation)**: When a state mutation occurs in
///      a producer node ([WhatController]), a lightweight dirty bit propagates downstream along
///      directed graph edges. Intermediate nodes are marked stale immediately, but no values
///      are recomputed prematurely.
///    - **Phase 2: Lazy-Pull (On-Demand Evaluation)**: Derived nodes ([computed]) and
///      subscribers lazily evaluate and cache values only when actively requested by downstream
///      terminals or UI render passes.
///
/// 2. **Single-Tier Reactivity**:
///    - Eliminates redundant wrapper layers: a state container is itself the physical DAG node.
///    - Guarantees 1 state variable = 1 heap allocation with zero abstraction tax.
///
/// 3. **The Dynamic Triad**:
///    - [computed]: Pure functional derived computations with dependency tracking and optional reactive guards.
///    - [switched]: Dynamic topological morphing that switches downstream dependency branches at runtime.
///    - [managed]: External resource lifecycle supervision (such as WebSockets, controllers) tied to subscriber presence.
///
/// 4. **Three-State FSM ([WhatSnapshot])**:
///    - Every node deterministically exists in one of three mutually exclusive states:
///      Valid (`hasData`), Empty (`isEmpty`), or Error (`hasError`).
///    - Respects `null` as a valid payload in nullable types (`T?`) rather than treating it as absent.
///
/// ## System Architectural Flow
///
/// ```text
/// [User Event / Input]
///         │
///         ▼ (counter.data = 1 / counter.set(1))
/// ┌───────────────────────┐
/// │  WhatController<int>  │ (Producer Controller Handle)
/// └───────────────────────┘
///         │
///         ▼ (counter.what)
/// ┌───────────────────────┐
/// │       What<int>       │ (Leaf State Node)
/// └───────────────────────┘
///         │
///         ▼ (Phase 1: Push-Dirty Signal - Zero-Copy)
/// ┌───────────────────────┐
/// │    computed() / What  │ (Marked Dirty / Stale)
/// └───────────────────────┘
///         │
///         ▼ (Phase 1: Push-Dirty Signal)
/// ┌───────────────────────┐
/// │  Terminal / Builder   │ (Schedules Rebuild / Render Pass)
/// └───────────────────────┘
///         │
///         ▼ (Phase 2: Lazy-Pull Request)
///      untracked(doubled) ──> Evaluates fresh computation in O(1)
/// ```
///
/// ## Key Invariants & Separation of Concerns
///
/// 1. **Producer/Consumer Separation**: [What] is observation-only; state mutation is strictly
///    encapsulated within [WhatController].
/// 2. **Zero-Overhead Raw Reads**: Reading via [untracked] or [WhatUntracked.state] outside a derivation
///    closure is a direct field dereference with zero tracking penalty and no dynamic tracking stack.
/// 3. **Explicit Dependency Manifest**: All dynamic reactive dependencies in [computed] and derivations
///    must be explicitly declared via the injected `via` handle (`via(node)`).
/// 4. **State vs. Side-Effects**: State pipelines are strictly separated from terminal side-effects.
///    Import `package:what/what.dart` for state DAGs, and `package:what/effect.dart` for terminal side-effects.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT read reactive nodes untracked directly inside [computed] without `via(...)`; doing so bypasses
///   reactive tracking and leads to stale derivations.
/// - Do NOT mutate a [WhatController] inside [computed] or during render passes, as this causes infinite cycles.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Untracked read inside computed scope
/// final doubled = computed((via) => untracked(counter.what) * 2); // Misses graph invalidations!
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Explicitly registered via injected handle
/// final doubled = computed((via) => via(counter.what) * 2); // Dynamically tracked in LPDAG
/// ```
///
/// ## Quick Start
///
/// ```dart
/// import 'package:what/what.dart';
///
/// void main() {
///   // 1. Declare a mutable leaf state
///   final counter = WhatController(0);
///
///   // 2. Declare a derived computation
///   final doubled = computed((via) => via(counter.what) * 2);
///
///   print(untracked(doubled)); // 0
///
///   // 3. Mutate state
///   counter.data = 5;
///   print(untracked(doubled)); // 10
///
///   // 4. Safe pattern matching via phase (Dart 3 Exhaustive Switch)
///   final message = switch (counter.phase) {
///     WhatPhase.valid => 'Count is ${counter.data}',
///     WhatPhase.empty => 'No data yet',
///     WhatPhase.error => 'Error: ${counter.error}',
///   };
///   print(message);
/// }
/// ```
library;

export 'src/framework.dart'
    hide
        // Reflector Domain symbols (exported exclusively via package:what/reflector.dart)
        LpdagReflector,
        LpdagStatusReflectorExtension,
        WhatReflector,
        // Effect Domain symbols (exported exclusively via package:what/effect.dart)
        DebounceEffect,
        Effect,
        EffectGroup,
        EffectHandle,
        EffectIterableExtension,
        EffectRecord2Extension,
        EffectRecord3Extension,
        EffectRecord4Extension,
        EffectRecord5Extension,
        EffectRunExtension,
        EffectRunner,
        ThrottleEffect,
        UnaryWhatEffectScope,
        WhatEffectExtension,
        WhatEffectScope,
        WhatIterableEffectExtension,
        WhatRecord2EffectExtension,
        WhatRecord3EffectExtension,
        WhatRecord4EffectExtension,
        WhatRecord5EffectExtension;
