# What Flutter Foundations Specification
> Official technical whitepapers on What Framework's Flutter rendering engine integration and UI reactive architecture invariants.

This directory provides the definitive engineering specifications for the junction between the Flutter framework and the What reactive engine. It covers 2-Phase LPDAG rendering pipeline integration, widget element lifecycle coordination, high-throughput functional functor cascades, durable animation systems, CJK IME composition integrity, and DevTools diagnostics.

---

## Foundations Whitepapers (01 ~ 15)

01. [**2-Phase LPDAG Engine Integration & Surgical Micro-Rebuilds**](01_two_phase_lpdag_and_surgical_micro_rebuilds.md)
    - Phase 1: Push-Dirty (0-computation topological flag propagation) and isolated `markNeedsBuild()` dispatch.
    - Phase 2: Lazy-Pull (on-demand evaluation synchronized with Flutter's render pass).
    - 100% suppression of parent/sibling rebuilds and glitch-free UI rendering.

02. [**Widget Tree Lifecycle Invariants & Subscriber-Driven Dormancy**](02_element_lifecycle_and_dormancy_invariants.md)
    - Lifecycle contracts across `_ReactiveTerminalElementMixin`: `mount`, `activate`, `deactivate`, `unmount`.
    - Instant topological edge detachment (dormancy) on route pops and offstage transitions.
    - 1-Pass Epoch Sweeping for conditional branch pruning and hot reload (`reassemble`) cache invalidation.

03. [**Functor Ecosystem: composed & what.build Zero-Alloc Cascades**](03_functor_ecosystem_and_zero_alloc_cascades.md)
    - The `composed` functor family: multi-state composition, 120fps animation isolation, persistent frame drivers, and listeners.
    - `what.build`: Dart `extension type const` zero-heap-allocation cascades.
    - Static subtree memoization (`child:`, `children:`) and the architectural decision tree.

04. [**Declarative Side-Effect Isolation & Zero-Rebuild Terminals**](04_declarative_side_effects_and_zero_rebuild.md)
    - Rebuild Count: 0 invariant (firewalls widget element tree from side-effect invalidations).
    - Zero-Run on Mount invariant and microtask-deferred dispatch (`scheduleMicrotask`).
    - Conditional filtering (`guard`) and time-domain rate limiting (`debounce`, `throttle`).

05. [**Scoped State Provision & Rebuild Suppression**](05_scoped_state_and_rebuild_suppression.md)
    - Scoped dependency injection container: `WhatProvider`.
    - Reference identity invariant in `updateShouldNotify` (`!identical(old.what, new.what)`).
    - Suppression of indiscriminate `InheritedWidget` subtree rebuilds and dynamic scope unwrapping via `switched`.

06. [**Durable Animations & Wall-Clock Compensation Invariants**](06_durable_animations_and_wall_clock.md)
    - Elimination of Ticker leaks upon widget unmount; configurable state preservation via `DurableAnimationController` and `DurabilityPolicy` (`resume`, `catchUp`, `reset`).
    - 8 staged motion archetypes, $C^1$ continuity restoration via `_TimeOffsetSimulation`, and internal proxy listener isolation.

07. [**Frame Ticker Scheduler & VSYNC Pipeline Engine**](07_frame_ticker_and_vsync_engine.md)
    - 120Hz ProMotion hardware VSYNC synchronization via `composed.drive`.
    - Leak-free lifecycle handles via `managed<_TickerDriver<T>>` and automatic `resync`.
    - Power-efficient high-frequency tick dropping via `distinct: true`.

08. [**Zero-Jump Form Binding & IME Integrity Invariants**](08_form_binding_and_ime_integrity.md)
    - Resolving impedance mismatches between unidirectional reactive state and bidirectional `TextEditingController` handles.
    - Preventing cursor jumping during mid-string edits; preserving CJK (Korean, Japanese, Chinese) IME composition buffers.
    - Mutually exclusive re-entrancy ping-pong shields, smart selection clamping, and declarative form resets via `clearOnEmpty`.

09. [**Declarative UI Refresh & Stale-While-Revalidate Patterns**](09_declarative_refresh_and_swr_ui.md)
    - Declarative coupling of `RefreshIndicator` and `.retained()` SWR buffers.
    - `WhatAsyncBuilder`: 4-state isolation (`data`, `loading`, `error`, `empty`) and intelligent collection emptiness detection.
    - `WhatPendingIndicator`: Lightweight non-intrusive progress canvas driven by `composed.drive`.

10. [**Context Environment Virtualization & Scope Proxies**](10_context_environment_virtualization.md)
    - Granular reactive projections (`size`, `viewInsets`, `platformBrightness`) eliminating `MediaQuery.of` subtree rebuild cascades.
    - Material/Cupertino design token and UI scope (`form`, `focus`, `navigator`) virtualization.
    - Zero-allocation runtime proxies via Dart `extension type`.

11. [**Listenable Interoperability & Reactive Bridges**](11_listenable_interoperability_and_bridges.md)
    - Standard Flutter bridges: `ValueListenable.toWhat()` and `Listenable.toWhatBy(selector)`.
    - Demand-driven activation: listeners are maintained only while active render widgets observe the node.
    - Graceful unmount buffering preventing listener thrashing during rapid route transitions.

12. [**Flutter DevTools Inspection & Diagnostics Architecture**](12_devtools_inspection_and_diagnostics.md)
    - Native DevTools integration via `_ReactiveTerminalElementMixin.debugFillProperties`.
    - Real-time visualization of active dependencies (`what[i]`) and lifecycle tethers (`tether[i]`).
    - Hot reload cache invalidation via `debugForceInvalidate()` and zero-overhead release build guarantees.

13. [**Declarative Routing & Navigation Sync**](13_declarative_routing_and_navigation_sync.md)
    - Synchronizing reactive graph state with declarative routers (`GoRouter`, Navigator 2.0) via `.toListenable()`.
    - Clean lifecycle binding without memory leaks, distinct filtering preventing route rebuild thrashing, and transient route triggers via [`WhatSignal`](https://github.com/pioneerjkf/what/blob/main/packages/what/doc/foundations/17_imperative_signals_and_transient_events.md) (from `package:what`).

14. [**Scroll Kinematics & Reactive Pagination**](14_scroll_kinematics_and_pagination.md)
    - Zero-allocation bridging of high-frequency 60/120fps `ScrollController` offsets via `.observe()`.
    - Isolating scroll kinematics from widget tree rebuilds via `composed.child` to eliminate jank in complex sliver hierarchies.

15. [**Widget Testing & Frame Pumping Mechanics**](15_widget_testing_and_pump_mechanics.md)
    - Deterministic UI verification with `WidgetTester` across 2-Phase LPDAG and asynchronous SWR lifecycles.
    - Exact temporal pump control (`pump()` vs. `pumpAndSettle()`), fake async timers, and isolated micro-rebuild verification.

---

## Foundational Pillars Matrix

| Pillar | Core Engineering Value | Implementation Mechanism | Related Whitepaper |
| :--- | :--- | :--- | :--- |
| **Surgical Render** | Rebuild scope: whole subtree $\to$ one leaf element | 2-Phase LPDAG + Leaf Element direct wiring + 1-Pass Epoch Sweeping | 01, 02 |
| **Zero-Alloc Functor** | Syntactic elegance & execution speed | `composed` Functors + `what.build` `extension type const` | 03 |
| **Zero-Rebuild Effect** | Clean separation of render & effects | `WhatListener` + EffectRunner + `scheduleMicrotask` | 04 |
| **Suppressed Scope** | Blocks indiscriminate global rebuilds | `WhatProvider` + `!identical` identity suppression + `switched` | 05 |
| **Durable Motion** | Physical time & motion continuity | Wall-clock compensation (`CatchUp`) + State freezing (`Frozen`) + $C^1$ continuity | 06, 07 |
| **IME Form Integrity** | Uncompromised typing fidelity | CJK IME buffer shield + Cursor jump prevention + Mutually exclusive ping-pong shield | 08 |
| **Zero-Flicker SWR** | Continuous user immersion | Stale cache retention + `WhatAsyncBuilder` + `WhatPendingIndicator` | 09 |
| **Context Virtualization** | Granular environment token projection | `WhatViaContextExtension` (`via.of<T>(context)`) | 10 |
| **Demand-Driven Bridge**| Full Flutter ecosystem interop | `toWhat` / `toWhatBy` + Demand-driven listener lifecycle management | 11 |
| **Native Diagnostics** | Transparent live debugging | `debugFillProperties` + DevTools Inspector + Hot reload resilience | 12 |
| **Declarative Router** | 100% route-state synchronization | `.toListenable()` + [`WhatSignal`](https://github.com/pioneerjkf/what/blob/main/packages/what/doc/foundations/17_imperative_signals_and_transient_events.md) (`what`) + distinct filter | 13 |
| **Kinematic Scroll** | 120fps jank-free scroll binding | `.observe()` + `composed.child` isolation | 14 |
| **Deterministic Test** | Zero-flakiness reactive testing | Frame pump control + `WhatAsyncBuilder` pump mechanics | 15 |
