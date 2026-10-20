# What Core Foundations Specification
> Official technical whitepapers on What Framework's reactive philosophy and pure Dart LPDAG engine invariants.

This directory provides the definitive engineering specifications for the What Framework operating in platform-agnostic, pure Dart environments. It details the core design principles, topological Directed Acyclic Graph (DAG) engine mechanisms, and fundamental invariants that guarantee high-throughput, memory-efficient reactive computing.

---

## Foundations Whitepapers (01 ~ 19)

01. [**2-Phase LPDAG Topology: Push-Dirty, Lazy-Pull, and Glitch-Free Invariants**](01_lpdag_two_phase_engine_and_glitch_freedom.md)
    - Elimination of diamond dependency glitches and formal proof of synchronous consistency.
    - The Tri-Color state machine (`Clean`, `Check`, `Dirty`) and zero-compute short-circuit evaluation via `_resolveDirty()`.

02. [**Explicit Dependency Manifest: WhatVia, 1-Pass Epoch Sweeping, and Zero Ambient Tracking**](02_explicit_dependency_manifest_and_epoch_sweeping.md)
    - Elimination of ambient thread-local stacks in favor of deterministic `WhatVia` dependency registration.
    - Physical decoupling of data and lifecycle planes via `via.tether()` and $O(\text{edges})$ zero-allocation 1-pass epoch sweeping.

03. [**Subscriber-Driven Inactive Dormancy & Pure Lazy Lifecycle**](03_subscriber_driven_dormancy.md)
    - Convergence of CPU cycles and asynchronous event ticks to zero in the absence of active consumers.
    - Prevention of background memory leaks and demand-driven topological edge synthesis.

04. [**Capability-Based Encapsulation & Fault-Tolerant Exception Isolation**](04_capability_security_and_fault_isolation.md)
    - Strict physical type decoupling between `WhatController` and `What` to prevent unauthorized downcasting mutations.
    - Isolated error containment via `_ErrorWhatState` and self-healing propagation mechanics.

05. [**Algebraic State Protocol & Self-Healing Fault Tolerance Specification**](05_algebraic_state_protocol_and_self_healing_fault_tolerance.md)
    - 3-State Algebraic Finite State Machine (`Data`, `Empty`, `Error`) and null-safety clarity (`WhatState<T>`).
    - Topology-preserving fault isolation (`succeeded: false`), zero-ceremony self-healing, and Software 3.0 (AI-Agentic) determinism.

06. [**Asynchronous Pipeline and Scheduling Invariants: The Physics of Async Reactivity**](06_asynchronous_pipeline_and_scheduling.md)
    - Reconciling synchronous pull semantics with asynchronous push streams.
    - Active-Eager microtask dispatch invariants to prevent two-turn pipeline stalls and event drop anomalies.

07. [**Async Topological Race Immunity & Inactive Dormancy Foundations**](07_async_topology_race_immunity_and_dormancy.md)
    - Overcoming uncancelable Dart `Future` limits through synchronous topological edge pruning (`_detachTargetEdgeOptimistically`).
    - 100% immunity against out-of-order stale overwrites and instant socket reclamation during dormancy.

08. [**Synchronous Resource Lifecycle and Managed Composition**](08_synchronous_resource_lifecycle_and_managed.md)
    - Why external resource lifecycle supervision (`managed`) must remain strictly synchronous within frame budget constraints.
    - Orthogonal composition patterns combining synchronous lifecycle handles with asynchronous state (`computed.future`/`computed.stream`).

09. [**Graceful Lifecycle & Mooring: Zero-Thrashing Transient Retention**](09_graceful_lifecycle_and_mooring_terminal.md)
    - Virtual topological anchoring via `_MooringTerminal` and `_MooringEdge` to withstand transient zero-subscriber intervals.
    - Mitigation of unmount/remount churn and ordering guarantees in the cleanup scheduler.

10. [**Fine-Grained Reactive Collections: Keyed Divergence & Transactional List State**](10_reactive_collections_and_keyed_divergence.md)
    - Atomic transactional batching (`.edit`) collapsing collection mutations into a single push-dirty pulse.
    - Fine-grained `.elements` slicing and identity-preserving item cache pools (`.keyed.map()`).

11. [**Polymorphic Refreshable Pipeline & Zero-Boilerplate SWR**](11_polymorphic_refreshable_and_swr.md)
    - First-class signal binding (`WhatSignal`) to drive standard declarative refresh triggers.
    - Dual-facet Stale-While-Revalidate (SWR) buffering via `.retained()` for flicker-free background recomputations.

12. [**Dynamic Routing Foundations: Mainstream Pipeline & Lateral Control Delta**](12_dynamic_routing_and_lateral_delta.md)
    - Structural separation between payload data planes (`_source`) and topological control planes (`_deltaTerminal`).
    - Declarative branch switching (`switched`) and imperative relay socket bridging (`WhatCoupler`).

13. [**Two-Tier Temporal Architecture: State-Domain Smoothing vs. Effect-Domain Rate Limiting**](13_two_tier_temporal_architecture_and_scheduling.md)
    - Orthogonal separation between state-domain buffering (`debounced`, `throttled`, `coalesced`) and effect-domain execution rate limiting (`Effect.debounce`/`throttle`).
    - Elimination of the Initial Evaluation Dilemma and intermediate topological limbo states.

14. [**Standalone Observation & Side-Effect Pipelines: Effect, EffectRunner, and Microtask Batching**](14_standalone_observation_and_effect_pipelines.md)
    - Framework-independent declarative side-effects (`Effect`) and execution-oriented pipelines (`EffectRunner`).
    - Resource Acquisition Is Initialization (RAII) guarantees via `EffectHandle.onCleanup` and declarative Record extensions.

15. [**Zero-Allocation Reactive Graph: Dart VM Optimization & Intrusive Data Structures**](15_dart_vm_low_overhead_memory_engineering.md)
    - Intrusive doubly linked lists (`_TargetEdge`, `_Edge`) achieving zero heap allocation on hot invalidation paths.
    - Monotonically incrementing counters (`++_epoch`), memory compactness, and `@pragma('vm:prefer-inline')` optimization.

16. [**Object-Oriented Domain Computation & Zero-Overhead Reactive Diagnostics**](16_domain_computation_and_zero_overhead_diagnostics.md)
    - Class-based domain derivation encapsulation (`Computation<T>`) and downstream lifecycle hooks (`WhatLifecycleAware`).
    - Zero-cost release diagnostics using `Expando`-backed metadata (`WhatDebug`) and development hot reload invalidation harnesses.

17. [**Imperative Signals & Transient Events Specification**](17_imperative_signals_and_transient_events.md)
    - Decoupling persistent state from ephemeral event pulses (`WhatSignal`, `WhatSignalController`).
    - Elimination of zombie payloads, remount re-triggering glitches, and unified single-pass dirty pulse emission via `What<int>` tick sequence.

18. [**Precondition Guarding & Algebraic State Gating: The Unified Fault-Barrier of the Dynamic Triad**](18_precondition_guarding_and_algebraic_gating.md)
    - Declarative precondition execution gating across `computed`, `managed`, and `switched`.
    - Deterministic auto-disposal upon prerequisite collapse, zero-heap multi-guarding across Dart 3 Record tuples, and seamless convergence to `Empty(emptyReason)`.

19. [**Terminal Architecture & Headless Sink Mechanics Specification**](19_terminal_architecture_and_headless_sink_mechanics.md)
    - The topological boundary of LPDAG: Source, Intermediate, and Sink nodes (`RawTerminal`).
    - Grounding the active boundary ($0 \leftrightarrow 1$), `RawWhatTerminal` zero-copy SSOT, `RawViaTerminal` 1-pass sweeps, and `RawComputedTerminal` 0-compute caching in headless environments.

---

## Foundational Pillars

| Pillar | Core Engineering Value | Implementation Mechanism |
| :--- | :--- | :--- |
| **2-Phase LPDAG** | Zero glitches & short-circuiting | Push-Dirty (0-Compute) + Lazy-Pull topological sync + Tri-Color (`Clean/Check/Dirty`) |
| **WhatVia Manifest** | Deterministic topology & zero-overhead reads | Explicit `WhatVia` parameter + pure field dereference (`.data`) + 1-pass monotonic epoch sweeping |
| **Dormancy** | Zero idle resource consumption | Inactive state suspends all upstream computation and I/O (pure on-demand lazy) |
| **Fault Isolation** | System integrity & capability security | Strict producer/consumer type decoupling (LSP) + snapshot error encapsulation (`_ErrorWhatState`) |
| **Algebraic State & Self-Healing**| 3-State FSM, topology freezing & AI determinism | `WhatState<T>` + non-escaping `_ErrorWhatState` + `succeeded: false` sweep abort + Zero-Ceremony Self-Healing |
| **Precondition Guarding**| Zero-leak resource gating & fault barrier | Declarative `guard(via)` + deterministic auto-disposal (`_disposeCurrent`) + 0-heap Dart 3 Record multi-guards |
| **Async Physics** | Low-latency asynchronous pipelines | Active-Eager microtask scheduling prevents event loss, deadlocks, and two-turn frame stalls |
| **Race Immunity** | Zero-boilerplate race condition safety | Synchronous edge severance (`_detachTargetEdgeOptimistically`) prevents stale async overwrites |
| **Pure Managed** | Deterministic synchronous lifecycles | Purely synchronous resource lifecycle prevents unmount race conditions and tear-down deadlocks |
| **Graceful Mooring** | Zero subscription thrashing | Virtual topological anchoring (`_MooringTerminal`) retains resources across rapid remounts |
| **Keyed Divergence** | Preserved local collection state | Transactional draft (`edit`) + keyed cache pools preserve instance identity across sorting |
| **Refreshable SWR** | Declarative flicker-free revalidation | First-class `WhatSignal` injection + dual-facet `.retained()` stale data retention buffer |
| **Dynamic Routing** | Data and control plane decoupling | Topological isolation of payload streams ($V$) and structural deltas ($\Delta$) (`_DeltaWhat`, `WhatCoupler`) |
| **Two-Tier Temporal**| Predictable temporal coordination | Relay-level push-dirty dampening orthogonally isolated from explicit target effect schedulers |
| **Standalone Effect**| Universal runtime compatibility | 1-tick microtask batching + RAII `onCleanup` registration + declarative Record tuple extensions |
| **Zero-Allocation VM**| Zero GC pauses on 120fps hot paths | Intrusive doubly linked lists + 1-pass epoch sweeping + `@pragma('vm:prefer-inline')` |
| **Domain & Diagnostics**| Enterprise scale & transparent debugging | Object-oriented `Computation<T>` + `WhatLifecycleAware` + zero-cost release `WhatDebug` |
| **Imperative Signals**| Ephemeral pulses without zombie state | `WhatSignalController` + `WhatSignal` (`What<int>` monotonic tick) + pure zero-payload event pulse |
| **Terminal Sinks**| Topological sink boundary & headless execution | `RawTerminal` taxonomy (Unary SSOT / N-ary Via / Leaf Computed) + active boundary ($0 \leftrightarrow 1$) |

