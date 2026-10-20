# LPDAG: Lazy Pull Directed Acyclic Graph

> **The Reactive Architectural Foundation of the What Engine**  
> *Author: Youngjune Jeon / what project*

---

## Executive Summary

Modern state management frameworks face a fundamental tension between **responsiveness**, **computational efficiency**, and **correctness (glitch-freedom)**. 

Traditional reactive frameworks (such as Rx, Stream-based architectures, and basic event emitters) rely on an **Eager Push DAG** model. Whenever any upstream state mutates, data payloads are forcefully pushed downstream through every connected node, causing redundant intermediate calculations, memory thrashing, and transient inconsistent states known as **"glitches"** (the Diamond Problem).

To eliminate these structural inefficiencies, **What** is built upon the **LPDAG (Lazy Pull Directed Acyclic Graph)** architecture. An LPDAG decouples **invalidation signaling** from **computation execution**:
1. **Push-Dirty**: Invalidation notifications travel downstream eagerly with zero data payload and zero heap allocations.
2. **Lazy-Pull**: Actual values are evaluated synchronously on-demand only when a consumer explicitly pulls them (e.g., during UI render frames).

---

## 1. The Glitch Problem in Eager Push Systems

Consider a canonical "Diamond Dependency" graph:

```text
       ┌───────────┐
       │   Root    │  (e.g., count = 1)
       └─────┬─────┘
             │
      ┌──────┴──────┐
      ▼             ▼
┌───────────┐ ┌───────────┐
│  Left (A) │ │ Right (B) │  (A = count * 2,  B = count + 10)
└─────┬─────┘ └─────┬─────┘
      │             │
      └──────┬──────┘
             ▼
       ┌───────────┐
       │  Sum (C)  │  (C = A + B)
       └───────────┘
```

### The Eager Push Failure Mode
In an eager push engine:
1. `Root` changes from `1` to `2`.
2. `Root` pushes the new value `2` to `Left (A)`.
3. `Left (A)` calculates `2 * 2 = 4` and **immediately pushes** `4` to `Sum (C)`.
4. `Sum (C)` computes `4 + Right(old: 11) = 15`. **[GLITCH: Transient inconsistent state!]**
5. `Root` then pushes `2` to `Right (B)`.
6. `Right (B)` calculates `2 + 10 = 12` and pushes `12` to `Sum (C)`.
7. `Sum (C)` computes `4 + 12 = 16`.

**Consequences**:
* `Sum (C)` was calculated **twice** instead of once.
* Downstream UI or side-effects witnessed an invalid, temporary state (`15`), potentially triggering wrong animations, network calls, or assertion failures.

---

## 2. The LPDAG Solution: Two-Phase Reactive Propagation

The LPDAG architecture resolves the Diamond Problem completely and reduces CPU cycles to the theoretical minimum through two strictly decoupled phases:

```text
Phase 1: Eager Push-Dirty                  Phase 2: Lazy Pull-Data
(Zero-allocation notification pulse)       (Topologically ordered evaluation)

      Root (mutated)                             Consumer (UI / Terminal)
            │                                               │
     [dirty pulse]                                    [pull .data]
            ▼                                               ▼
      ┌─────┴─────┐                                      Sum (C)
      │           │                                   ┌─────┴─────┐
   Left (A)   Right (B)                          Left (A)      Right (B)
      │           │                                   │           │
     [dirty pulse]                                 [pull]      [pull]
      ▼           ▼                                   └─────┬─────┘
         Sum (C)                                            ▼
      (marked check)                                   Root (clean)
```

### Phase 1: Push-Dirty (Lightweight Invalidation)
When an upstream node (e.g., `WhatController`) updates:
* It increments its internal `_version`.
* It traverses downstream along intrusive `_TargetEdge` pointers, marking each dependent relay node's dirty state as `_DirtyState.check`.
* **Early Pruning**: If a node is already marked non-clean (`check` or `dirty`) in the current cycle, propagation immediately terminates along that branch, preventing redundant traversals.
* **Cost**: $O(\text{edges})$ pointer traversal with **zero heap allocations** and **zero user computation logic execution**.

### Phase 2: Lazy-Pull (On-Demand Evaluation)
When a consumer (such as a Flutter widget via `RawWhatTerminal` / `RawViaTerminal`) reads `.data`:
1. The node enters `_resolve()`. If marked `_DirtyState.check`, it queries its upstream dependencies via `_resolveDirty()`.
2. **Distinct Short-Circuit**: If all upstreams evaluate to unchanged distinct values, the node resets its state to `_DirtyState.clean`, synchronizes versions, and returns its cached state in **$O(1)$** without re-evaluating its compute closure.
3. **Topological Pull**: If an upstream dependency is genuinely dirty, the node marks itself as `_DirtyState.dirty` and recursively resolves upstreams in topological order. Both `Left (A)` and `Right (B)` pull `Root`'s latest state before `Sum (C)` executes.
4. `Sum (C)` executes **exactly once**, yielding `16` directly. **Zero glitches, zero redundant calculations.**

---

## 3. Structural Comparison

| Dimension | Eager Push DAG (Rx / Stream) | Pull-Only (Polling / Lazy Getters) | **What LPDAG** |
| :--- | :--- | :--- | :--- |
| **Propagation Trigger** | On mutation (Push) | On read (Pull) | **Push Invalidation + Pull Data** |
| **Evaluation Timing** | Eager (Immediate) | Lazy (On-Demand) | **Strictly Lazy (On-Demand)** |
| **Diamond Glitch** | Susceptible (requires complex scheduler queues) | None (always computes fresh) | **Impossible by design (Glitch-Free)** |
| **Unobserved Changes** | Calculates wastefully through entire graph | Never calculates | **Zero calculations (Dirty mark only)** |
| **Memory Allocation** | High (ephemeral event streams, closure wrappers) | Zero | **Zero-allocation hot paths (Intrusive edges)** |
| **Batching Overhead** | Requires event-loop debounce / tick delay | N/A | **Synchronous $O(1)$ batching (`_PushScope`)** |

---

## 4. Architectural Boundaries in What

The clarity of an LPDAG depends on maintaining strict separation between topological vertices, pipeline boundaries, and external side-effects.

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                      1. External Input Boundaries                       │
│    WhatController<T> • WhatListController • WhatSetController • WhatMap │
│    Async Bridges: future.toWhat() • stream.toWhat()                     │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ (Push-Dirty Invalidation)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              2. Pure LPDAG Core Engine (package:what/what.dart)         │
│    • Scalar State Vertices: What<T>                                     │
│    • Collection State Vertices: What<List<T>>, Set, Map & .elements     │
│    • Derivation Vertices: computed, computed.future, switched           │
│    • In-Place State Containers: _ValidWhatState<T> (s.update)           │
│    • Intrusive Linked Edges: _TargetEdge, _Edge                         │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ (Lazy-Pull on Consumption)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   3. Observation & Terminal Boundaries                  │
│    • Consumer Gateways: RawWhatTerminal<T>, RawViaTerminal<T>           │
│    • Reactive UI Bindings: WhatWidget, composed, WhatListener           │
│    • Side-Effect Sinks (package:what/effect.dart):                      │
│      Effect, ThrottleEffect, DebounceEffect, EffectGroup, EffectRunner  │
└─────────────────────────────────────────────────────────────────────────┘
```

### What Belongs in the Pure LPDAG?
* Any node that holds a **`WhatState`** (or can lazily derive one via `.data` / `.snapshot`).
* Any node that emits **Push-Dirty** pulses and supports **Lazy-Pull** queries.
* Nodes must be pure state carriers with deterministic topological dependencies.

### What Does NOT Belong in the Pure LPDAG?
1. **Side-Effects (`Effect`, `ThrottleEffect`, `DebounceEffect`, `EffectGroup`)**:
   * Effects are terminal sinks. They consume dirty notifications to execute external side-effects (analytics, logging, haptics, I/O), but they **produce no `.data`** to be pulled by downstream DAG nodes. Hence, they reside in `package:what/effect.dart` and terminate without cascading DAG cycles.

---

## 5. Engine Hardening & Production Invariants

To achieve high-frequency throughput in production Flutter runtimes (such as 120Hz micro-animations and deep dependency trees), the What LPDAG engine enforces several rigorous structural invariants:

### 5.1. $O(S)$ Optimized Source Traversal
Dynamic dependency discovery in `computed`, `switched`, and `managed` nodes resolves source changes with strict $O(S)$ computational complexity (where $S$ is the number of active sources). By utilizing sequential forward cursor sweeps and diffing directly across intrusive `_Edge` pointers (`_prevSource` / `_nextSource`), What achieves zero heap allocations during steady-state dependency resolution.

### 5.2. `_propagatingTarget` Reentrancy & Cursor Protection
During Phase 1 Push-Dirty propagation (`_propagateDirty`), downstreams may synchronously attach or detach dependent nodes (such as dynamic conditional branches or element lifecycle triggers). To prevent concurrent modification exceptions without incurring snapshot array allocations:
- The engine maintains an intrusive cursor pointer (`_propagatingTarget`).
- If an edge is unlinked during active traversal, the cursor advances safely to `target._nextTarget`.
- Early pruning skips nodes already marked non-clean in the current cycle, guaranteeing that propagation terminates immediately along convergent graph paths.

### 5.3. `_PushScope` 2-Phase Transaction & Trampoline Execution
Mutations and invalidations are coordinated by `_PushScope`:
- **Phase 1 (Causes)**: Invalidation origins are queued in `_pushOriginHead` and drained via DFS dirty propagation, marking downstream nodes without running consumer logic.
- **Phase 2 (Effects)**: Terminals are queued in `_flushTerminalHead` and flushed synchronously once all dirty paths settle.
- **Trampoline Loop**: If a terminal callback synchronously triggers another state mutation (reentrancy), `_PushScope` yields back to Phase 1 immediately. This flattens recursive calls into an iterative loop, preventing call-stack overflow while maintaining strict causal ordering.

### 5.4. In-Place State Mutation & Zero-Allocation Hot Paths
For continuous updates on scalar or collection states, `_ValidWhatState` provides in-place data mutation via `s.update(data)`:
- Avoids allocating new wrapper objects on high-frequency update loops.
- Internal inspection paths leverage Dart VM single-instruction class ID comparisons (`state is _ValidWhatState`), avoiding `SubtypeTestCache` runtime lookups.

### 5.5. `RawWhatTerminal` Zero-Copy Gateway & Hot Reload Integrity
`RawWhatTerminal` bridges the pure LPDAG graph with Flutter elements as a zero-copy Single Source of Truth (SSOT) gateway:
- **Zero-Allocation Source Swapping**: `terminal.swapSource(newWhat)` dynamically updates upstream observations without reconstructing terminal listeners or re-allocating heap handles.
- **Synchronous Push Dispatch**: Invalidation pulses dispatch synchronously to `onInvalidated` via `_PushScope` without queueing delay, leaving scheduling (e.g. `element.markNeedsBuild()`) strictly to the consuming framework. For standalone asynchronous execution, `EffectRunner` provides lifecycle-managed scheduling.
- **Hot-Reload Integrity**: Through `debugForceInvalidate()`, active terminals coordinate with element lifecycle hooks (`reassemble()`) to recursively invalidate upstream caches across the DAG, guaranteeing fresh state resolution across development cycles without cache desynchronization.

### 5.6. Bounded Retention with `_MooringTerminal`
Transient nodes and in-flight subscriptions across tab or route switches are anchored via `graceful` policies:
- `Graceful.microtask` (default): Defers deallocation by 1 scheduler tick, coalescing rapid unmount/remount passes without object churn.
- `Graceful.period(duration)`: Anchors the node to the global `_MooringTerminal` via a topological `_MooringEdge`, holding upstream dependencies active until the specified grace window elapses without severing the LPDAG reactive chain.

### 5.7. `_ViaShortCircuit` Non-Data State Propagation
When a derivation observes an upstream node in a non-data state (e.g. `WhatState.empty` or `WhatState.error`):
- `WhatVia` throws an internal `_ViaShortCircuit` sentinel implementing `Error`.
- This short-circuits execution before evaluating user computation logic, preventing `NullThrownError` or invalid calculation passes.
- The parent node catches the sentinel and retypes it to forward the Empty/Error state directly through the DAG.

---

## 6. Conclusion

The **LPDAG (Lazy Pull Directed Acyclic Graph)** is the foundational paradigm that enables What to achieve ultra-high throughput and glitch-free correctness in Dart and Flutter. By enforcing a strict boundary between eager invalidation and lazy evaluation, What guarantees:
* **Zero wasted compute** on non-rendered or rapid-burst state mutations.
* **Zero glitches** across complex multi-branch diamond topologies.
* **Deterministic, reproducible state transitions** across the entire application lifecycle.
