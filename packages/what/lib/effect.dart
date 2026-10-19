// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// @docImport 'src/framework.dart';
/// @docImport 'what.dart';
///
/// Reactive side-effect pipelines and temporal rate limiters.
///
/// `package:what/effect.dart` provides an expressive suite of non-propagating reactive
/// terminals: declarative [Effect], time-domain rate limiters ([ThrottleEffect], [DebounceEffect]),
/// finite execution bounds with reactive guards (`guard`, `take`), and composite grouping ([EffectGroup]).
///
/// ## Architectural Overview
///
/// In the What DAG architecture, reactive state nodes ([What]) adhere strictly
/// to the **Push-Dirty / Lazy-Pull** paradigm. Side-effects (such as analytics,
/// logging, audio/haptic feedback, or external I/O sync) MUST NOT mutate intermediate DAG
/// nodes to produce business state.
///
/// Instead, side-effects are modeled as **Terminal Sinks**:
/// - **Terminal Non-Propagation**: Effects do not propagate dirty pulses downstream; they consume
///   signals at graph terminal boundaries without creating cascading DAG cycles.
/// - **Declarative Blueprints**: [Effect], [DebounceEffect], and [ThrottleEffect] can be defined
///   declaratively and attached to tracking scopes via `via.tether()`.
/// - **Zero-Glitch Invariant**: Effects are flushed only after state transactions settle, guaranteeing
///   that multi-node updates are read consistently without transient tearing.
///
/// ## System Architectural Flow
///
/// ```text
/// ┌────────────────────────────────────────────────────────┐
/// │               What Reactive Topology                  │
/// ├───────────────────────────┬────────────────────────────┤
/// │   State Pipeline Domain   │     Side-Effect Domain     │
/// │  (package:what/what)    │   (package:what/effect)   │
/// ├───────────────────────────┼────────────────────────────┤
/// │ • Push-Dirty / Lazy-Pull  │ • Terminal Sinks           │
/// │ • What / Computed / FSM  │ • Non-propagating actions  │
/// │ • State Synchronous SSOT  │ • Debounce / Throttle      │
/// │ • 1 node = 1 allocation   │ • Scope-bound via via.tether│
/// └───────────────────────────┴────────────────────────────┘
/// ```
///
/// ## Architectural Benefits
///
/// 1. **Cycle-Free Terminal Boundaries**: Effects never act as reactive sources for upstream nodes,
///    guaranteeing that side-effect executions cannot create infinite topological update cycles.
/// 2. **Transaction-Safe Flush**: Effects fire only after state transactions settle, eliminating transient
///    tearing or intermediate state reads.
/// 3. **Declarative Lifecycle Management**: Tethering via `via.tether()` automatically aligns effect lifetimes
///    with active subscription scopes, preventing background memory and listener leaks.
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT mutate upstream [WhatController] nodes inside an [Effect] without an explicit guard or exit condition;
///   uncontrolled mutations induce reentrant event loops.
/// - Do NOT instantiate new effects repeatedly inside Flutter build methods or dynamic loop passes without
///   persisting them in a field or binding them to a lifecycle scope.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Uncontrolled state mutation inside side-effect creates reentrancy loop
/// final counter = WhatController(0);
/// final effect = counter.what.effect(() {
///   counter.set(counter.what.peek + 1); // Mutates source node without guard!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] One-way terminal sink for external interactions
/// final counter = WhatController(0);
/// final effect = counter.what.effect(() {
///   analyticsService.logCount(counter.what.peek); // Pure side-effect sink
/// });
/// ```
///
/// ## Examples
///
/// ### 1. Fluent Single-Node Debounce:
/// ```dart
/// final searchQuery = WhatController('');
///
/// // Debounce searches to execute 300ms after user stops typing
/// final searchRunner = searchQuery.what.effect
///     .debounce(
///       const Duration(milliseconds: 300),
///       () => fetchSearchResults(searchQuery.what.peek),
///     )
///     .run();
/// ```
///
/// ### 2. Scope-Bound Lifecycle with `via.tether()`:
/// ```dart
/// final user = WhatController(User(id: 'u1'));
/// final settings = WhatController(Settings());
///
/// // Inside a computation scope or terminal:
/// final term = RawViaTerminal(
///   (via) {
///     via.tether((user.what, settings.what).effect(() {
///       analytics.track('User updated: ${user.what.peek.id}');
///     }));
///   },
///   onInvalidated: () {},
/// );
/// ```
library;

export 'src/framework.dart'
    show
        // Core Effects & Groups (Declarative)
        Effect,
        EffectGroup,
        EffectHandle,
        Tether,
        // Standalone Execution Runner
        EffectRunExtension,
        EffectRunner,
        // Time-Domain Rate Limiting
        DebounceEffect,
        ThrottleEffect,
        // Direct What .effect Scopes & Extension Suite
        UnaryWhatEffectScope,
        WhatEffectExtension,
        WhatEffectScope,
        WhatIterableEffectExtension,
        WhatRecord2EffectExtension,
        WhatRecord3EffectExtension,
        WhatRecord4EffectExtension,
        WhatRecord5EffectExtension,
        // Direct .group Extension Suite for Effect
        EffectIterableExtension,
        EffectRecord2Extension,
        EffectRecord3Extension,
        EffectRecord4Extension,
        EffectRecord5Extension;
