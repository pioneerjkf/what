# 2-Phase LPDAG Topology Engine and Glitch-Freedom Specification
## (The 2-Phase LPDAG Engine: Push-Dirty, Lazy-Pull, Tri-Color States, and Glitch-Free Invariants)

> **"The performance and correctness of a reactive system are not governed by how fast it computes, but by how rigorously it eliminates redundant calculations to zero while maintaining deterministic synchronous consistency without glitches."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Reactive Dilemma

Modern frontend and GUI application state management systems historically bifurcated into two primary architectural models:

1. **Pure Eager Push Models (Eager Streams and Observer Pipelines)**:
   - Whenever an upstream source mutates, new values are eagerly calculated and pushed downstream through all dependent nodes and listeners immediately.
   - **Critical Failure Mode**: In a diamond dependency topology, intermediate nodes evaluate out of order, exposing transient inconsistent states known as **glitches**. Furthermore, unobserved background nodes continuously perform calculations, generating unnecessary CPU cycles and heavy garbage collection overhead.
2. **Pure Lazy Pull Models (Traditional Functional Composition, Pull Streams)**:
   - Consumers pull values on-demand by traversing the graph upward to recompute state.
   - **Critical Failure Mode**: Because downstream nodes have no deterministic way of knowing which upstream node actually mutated, validating cache freshness requires traversing the entire graph with $O(N)$ overhead or executing unconditional recomputations.

The What Framework resolves these structural deficiencies through its **2-Phase LPDAG (Lazy-Pull Directed Acyclic Graph)** architecture. By strictly decoupling invalidation notification (Control Plane) from state evaluation (Data Plane), What achieves mathematically guaranteed glitch-freedom with zero redundant computations.

---

## 2. Diamond Dependencies and the Mathematical Anatomy of Glitches

### 2.1 The Diamond Topology
The canonical reactive consistency failure occurs in diamond-shaped Directed Acyclic Graphs:

```text
        [Source A] (Initial: 1)
         /      \
        ▼        ▼
   [Node B]    [Node C]   (B = A * 2,  C = A + 10)
        \        /
         ▼      ▼
        [Node D]          (D = B + C)
```

**Initial Steady State:**
* $A = 1$
* $B = 1 \times 2 = 2, \quad C = 1 + 10 = 11$
* $D = B + C = 2 + 11 = 13$

### 2.2 Glitch Propagation in Pure Push Models
When $A$ mutates from $1 \to 2$, an eager push engine propagates notifications along arbitrary call-stack or queue orders:
1. $A$ pushes to $B$: $B$ immediately recalculates to $4$ and eagerly pushes to $D$.
2. **Transient Glitch Window**:
   - $D$ evaluates using the updated $B (= 4)$ combined with the stale, un-updated $C (= 11)$, yielding $D = 15$, and immediately emits this intermediate result to the UI or downstream listeners.
   - This represents a transient inconsistent state that cannot logically exist in the application domain.
3. $A$ subsequently pushes to $C$: $C$ recalculates to $12$ and pushes to $D$.
4. $D$ recalculates using $4 + 12 = 16$ and emits to the UI a second time.

In this scenario, $D$ not only executes **two redundant computations**, but also **temporarily exposes an invalid derived value ($15$) to external observers**, causing UI flickering, invariant violations, and redundant side-effects.

---

## 3. Topological Execution Mechanics of the 2-Phase LPDAG

The What Framework decouples invalidation notification from state evaluation into two distinct topological phases, mathematically reducing glitches and redundant computations to zero.

```text
═══════════════════════════════════════════════════════════════════════════════
Phase 1: Synchronous Push-Dirty Phase (Control Plane: 0 Compute, 0 Heap Alloc)
═══════════════════════════════════════════════════════════════════════════════
[Source A Mutation] ──► _pushDirty()
                             │
                             ├─► [Relay B]: _markDirty() ──► _dirtyState = check
                             ├─► [Relay C]: _markDirty() ──► _dirtyState = check
                             │        │
                             ▼        ▼
                         [Node D (B + C)]: _markDirty() ──► _dirtyState = check
                                  │
                                  └─► [Terminal]: queueTerminal()
                                           │
                                           ▼ (End-of-push drain)
                                      onInvalidated() ──► Schedule Frame / Notify
                                                          (0 Compute, 0 Read)

═══════════════════════════════════════════════════════════════════════════════
Phase 2: On-Demand Lazy-Pull Phase (Data Plane: Exact Reverse Topological Order)
═══════════════════════════════════════════════════════════════════════════════
Consumer reads terminal.data
       │
       ▼
[Node D._resolve()]
       │
       ├─► B._resolve() ──► B._pull() ──► B = 4  (clean, version++)
       ├─► C._resolve() ──► C._pull() ──► C = 12 (clean, version++)
       │
       └─► D._pull() ────► D = 4 + 12 = 16 (0% Glitch, Exactly 1 Evaluation!)
```

### 3.1 Phase 1: Synchronous Push-Dirty Phase (Control Plane)
1. When a source node mutates via [`WhatController.set`](../../lib/src/what/what.dart), it invokes [`_DirtyPusher._pushDirty()`](../../lib/src/engine/_internal/_dirty.dart#L33).
2. The dirty wave traverses downstream through intrusive target edges via [`_Node._propagateDirty()`](../../lib/src/engine/_internal/_node.dart#L130).
3. Intermediate relay nodes ([`_PullRelay`](../../lib/src/engine/_internal/_relay.dart#L133)) receive `_invalidate()` and mark their internal state as `_DirtyState.check`.
4. Leaf consumers ([`_RawTerminal`](../../lib/src/engine/_internal/_terminal.dart#L72)) are enqueued into [`_PushScope._flushTerminalHead`](../../lib/src/engine/_internal/_push.dart#L20).
5. **Phase 1 Invariants**:
   - **Zero User Closures Executed**: No derivation functions or selectors run during Phase 1.
   - **Zero Heap Allocations**: Edits walk intrusive doubly linked list pointers without allocating queue objects or closures.
   - **$O(E)$ Bounds**: Traversal is strictly bounded by the number of active downstream edges $E$.

### 3.2 Phase 2: On-Demand Lazy-Pull Phase (Data Plane)
1. Downstream consumers (e.g. Flutter widgets during layout/build or [`RawWhatTerminal.data`](../../lib/src/engine/terminal.dart)) pull data via `_read()` &rarr; `_resolve()`.
2. [`_PullResolver._resolve()`](../../lib/src/engine/_internal/_pull.dart#L47) inspects `_dirtyState`:
   - If `_DirtyState.clean` (on active nodes): Returns the cached `_state` in $O(1)$ immediate field access.
   - If `_DirtyState.check`: Calls `_resolveDirty()` to verify whether upstream sources actually mutated.
   - If `_DirtyState.dirty` (or if `_resolveDirty()` confirms an upstream version increment): Executes `_pull()` to compute the new value, updates `_dirtyState = _DirtyState.clean`, and synchronizes versions via `_pullVersion()`.
3. **Glitch-Free Guarantee**: In diamond topologies, when $D$ resolves, it recursively forces $B$ and $C$ to resolve completely before $D$ executes its own computation closure. Intermediate states are mathematically inaccessible.

---

## 4. Tri-Color State Machine: Clean, Check, Dirty

Every derived node ([`_PullResolver<T>`](../../lib/src/engine/_internal/_pull.dart#L18)) maintains a 3-state finite state machine governed by [`_DirtyState`](../../lib/src/engine/_internal/_dirty.dart#L7):

```text
             _markDirty() (Push Phase)
   ┌──────────────────────────────────────────────┐
   │                                              ▼
┌───────┐       _resolveDirty() == true       ┌───────┐
│ Clean │ ──────────────────────────────────► │ Dirty │
└───────┘                                     └───────┘
   ▲   │                                          │
   │   └───────────────┐                          │ _pull() completes
   │                   ▼                          │
   │               ┌───────┐                      │
   │               │ Check │ ─────────────────────┘
   │               └───────┘   _resolveDirty() == true
   │                   │
   └───────────────────┘
     _resolveDirty() == false (0-Compute Short-Circuit! Cache Reused)
```

### 4.1 State Definitions
* **`_DirtyState.clean`**:
  - The node's cached state (`_state`) is fully synchronized with all upstream source versions.
  - On active clean nodes, accessing `.data` or `.snapshot` is an immediate $O(1)$ field dereference (dormant nodes verify upstream versions first; dirty nodes trigger a lazy pull).
* **`_DirtyState.check`**:
  - The node received a Push-Dirty invalidation pulse, but **whether upstream outputs actually changed has not yet been determined**.
  - During lazy evaluation (Pull), upstream dependencies must be verified first via `_resolveDirty()`.
* **`_DirtyState.dirty`**:
  - An upstream mutation has been verified, or the node was explicitly invalidated via `debugForceInvalidate()`.
  - Reading the node requires executing `_pull()` to recompute the value.

### 4.2 Why Mark `check` Rather Than `dirty` in `_markDirty()`?
In [`_PullRelay`](../../lib/src/engine/_internal/_relay.dart#L137):

```dart
base mixin _PullRelay<T> on _Relay, _PullResolver<T> {
  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  void _markDirty() {
    if (_dirtyState != _DirtyState.clean) return;
    _dirtyState = _DirtyState.check; // Crucial: marked as check, not dirty
    super._markDirty();
  }
}
```

If the Push phase marked nodes as `dirty` unconditionally, **short-circuit memoization** would be impossible.

By marking nodes as `check`, What enables downstream short-circuiting in [`_PullResolver`](../../lib/src/engine/_internal/_pull.dart#L58):

```dart
if (_dirtyState == _DirtyState.check) {
  // Recursively resolve upstream relays and verify whether their versions incremented
  if (!_resolveDirty() && _state != null) {
    _dirtyState = _DirtyState.clean;
    _pullVersion();
    return; // Short-circuit! Upstream had no net change; return cached state without recomputing!
  }
  _dirtyState = _DirtyState.dirty;
}
if (_dirtyState == _DirtyState.dirty || _state == null) {
  _state = _pull(); // Execute computation closure
  _dirtyState = _DirtyState.clean;
  _pullVersion();
}
```

#### The 0-Compute Short-Circuit Scenario
1. Source $A$ changes from $1 \to 3$.
2. Relay $B$ is defined as `computed((via) => via(A).isOdd).distinct()`.
3. Push Phase: Invalidation transitions Relay $B$ and downstream Terminal $C$ to `check`.
4. Pull Phase: When Terminal $C$ is accessed, Relay $B$ is resolved first.
5. Relay $B$'s previous value was `true`, and its new value evaluates to `true`. Because `.distinct()` filters out consecutive duplicate payloads, Relay $B$'s version does not increment (`_version` unchanged).
6. Consequently, Terminal $C$'s `_resolveDirty()` returns `false`.
7. **Result**: Terminal $C$ **skips its compute closure entirely, retains its cached snapshot, and returns immediately in $O(1)$ time**.

> [!NOTE]
> **Architectural Rationale: Why `computed` Intentionally Omits Implicit Equality Checking**
>
> In the What framework, basic `computed` nodes intentionally do **not** perform implicit `Object.==` checks or early cutoffs on every pull. This deliberate design decision stems from core performance and safety principles:
>
> 1. **Zero-Overhead Hot Path**: Dart's `Object.==` is a virtual method dispatch. For collections, records, and complex domain models, unconditional equality comparisons on every derivation pull introduce non-trivial CPU overhead. Keeping `computed` free of implicit checks ensures peak VM throughput.
> 2. **Clean Separation of Concerns**: `computed` focuses solely on reactive derivation. Payload-level equality filtering and early cutoff are explicitly delegated to the [`.distinct([equals])`](../../lib/src/what/what.dart) combinator.
> 3. **Avoidance of Stale States in Mutable References**: If a computed value mutates internal fields while retaining reference equality, an automatic `identical`/`==` check could prematurely drop notifications, causing silent UI desynchronization. Requiring explicit `.distinct()` ensures developers consciously declare when equality semantics are safe to enforce.


---

## 5. Topological Edge Architecture & Intrusive Memory Optimization

The What Framework rejects external collection wrappers (`List<Edge>`, `Set<Node>`) to track topological graph edges, eliminating heap churn and GC overhead.

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│               Intrusive Doubly Linked Graph Edge Topology                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   [Source Node]                                                                 │
│   _targetHead ──► [_TargetEdge 1] ◄──► [_TargetEdge 2] ◄──► [_TargetEdge 3]     │
│                         │                    │                    │             │
│                         ▼                    ▼                    ▼             │
│                     Target A             Target B             Target C          │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

1. **Intrusive Pointers ([`_TargetEdge`](../../lib/src/engine/_internal/_edge.dart#L8))**:
   Edges maintain intrusive `_prevTarget` and `_nextTarget` pointer fields directly on the edge instances.
2. **$O(1)$ Edge Attachment and Removal**:
   Connecting or detaching a subscriber is an $O(1)$ linked-list insertion/removal without reallocating arrays.
3. **Dual Edge Modalities**:
   - **[`_UnaryEdgeMixin`](../../lib/src/engine/_internal/_edge.dart#L44)**: Optimizes 1:1 topological connections (e.g. single-source relays, transformers), requiring zero intermediate edge wrapper objects.
   - **[`_NaryEdgeMixin`](../../lib/src/engine/_internal/_edge.dart#L95)**: Manages dynamic multi-source dependencies (e.g. [`computed`](../../lib/src/what/computed.dart) and [`switched`](../../lib/src/what/switched.dart)), maintaining both upstream `_sourceHead` and downstream `_targetHead` intrusive lists.
4. **Monotonic Version Tracking**:
   - Every `_Node` maintains an integer `_version = 0`.
   - Mutating a controller or completing a computation increments `_version++`.
   - Edges store `_pulledVersion` to detect staleness synchronously:
     ```dart
     bool get _isSourceDirty => _source._isNewerThan(_pulledVersion);
     ```

---

## 6. Transactional Batch Coalescing (`batch` & `_BatchScope`)

When multiple sources mutate in the same synchronous turn, the engine coalesces invalidation waves into an $O(1)$ single dispatch without consuming microtask queues:

```dart
batch(() {
  controllerA.set(10);
  controllerB.set(20);
  controllerC.set(30);
}); // Exactly 1 terminal notification wave flushes here!
```

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│               Transactional Batch Execution Pipeline                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   batch(() {                                                                    │
│     sourceA.set(10); ──► Phase 1 Push-Dirty (Eagerly marks downstream 'check')   │
│     sourceB.set(20); ──► Phase 1 Push-Dirty (Eagerly marks downstream 'check')   │
│     sourceC.set(30); ──► Phase 1 Push-Dirty (Eagerly marks downstream 'check')   │
│   });                                                                           │
│            │                                                                    │
│            ▼ (Outermost batch scope exits)                                      │
│   [Coalesced Phase 2 Terminal Notification Wave]                                │
│   Terminal A, Terminal B, Terminal C flushed exactly once!                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 6.1 Read-Your-Own-Writes (RYOW) Guarantee
Unlike batch systems that delay dirty propagation, What's [`_PushScope`](../../lib/src/engine/_internal/_push.dart#L16) propagates Phase 1 dirty signals **eagerly** inside `batch()`:
- Intermediate reads within the batch immediately reflect the latest upstream mutations.
- Only Phase 2 terminal dispatches (such as Flutter `markNeedsBuild()` or side-effect callbacks) are deferred until the outermost batch exits.

### 6.2 Trampoline Reentrancy Protection
If a terminal flush callback executes new mutations, [`_PushScope._drain()`](../../lib/src/engine/_internal/_push.dart#L65) uses a trampoline loop:
- The flush yields immediately back to Phase 1 so new dirty states propagate through the graph before subsequent terminals are flushed.
- This prevents call stack recursion and guarantees deterministic event ordering.

> [!WARNING]
> **Anti-Pattern Warning: Asynchronous Code Inside `batch()`**  
> `batch()` applies strictly to synchronous execution turns. Awaiting a `Future` inside `batch()` will exit the batch scope prematurely before the asynchronous task finishes.

---

## 7. Diagnostics, Cycle Detection, and Re-entrancy Protection

### 7.1 $O(1)$ Cycle Detection ([`LpdagCycleError`](../../lib/src/engine/exception.dart#L74))
In cyclic topologies ($A \to B \to A$), recursive pull models risk infinite stack overflows. What implements an $O(1)$ recursion bit in [`_PullResolver._resolve()`](../../lib/src/engine/_internal/_pull.dart#L48):
```dart
if (_isResolving) {
  throw LpdagCycleError(
    'Cyclic evaluation loop detected in $runtimeType while resolving state.',
  );
}
_isResolving = true;
try {
  ...
} finally {
  _isResolving = false;
}
```
If a node attempts to read its own state while resolution is in-flight, it immediately aborts with an informative diagnostic error.

### 7.2 Reentrancy Guard ([`LpdagReentrancyError`](../../lib/src/engine/exception.dart#L34))
A node cannot initiate a new `_pushDirty()` phase while it is already actively propagating dirty signals. In [`_DirtyPusher._pushDirty()`](../../lib/src/engine/_internal/_dirty.dart#L33):
```dart
if (_isPushingDirty) {
  throw LpdagReentrancyError(''
      'Reentrant call to _pushDirty detected. A dirty point cannot '
      'push again while it is currently in its push phase.');
}
```

---

## 8. Core Engineering Invariants

1. **Zero-Computation Push Invariant**:  
   The Push phase never executes user computation closures and never allocates memory on the heap.
2. **Glitch-Free Topological Invariant**:  
   In any arbitrary DAG topology (including complex diamond graphs and multi-level meshes), consumers observe a single, topologically coherent state without transient intermediate values.
3. **Tri-Color Short-Circuit Invariant**:  
   If upstream sources mutate but intermediate derivations evaluate to identical outputs, downstream recomputations are skipped in $O(1)$ time.
4. **Intrusive Memory Invariant**:  
   Edges are linked directly using intrusive pointers (`_prevTarget`, `_nextTarget`), guaranteeing zero collection overhead and zero GC pressure in steady state.
5. **Deterministic Cycle & Reentrancy Isolation**:  
   Cyclic pull loops and reentrant push cycles are trapped in $O(1)$ time, protecting the Dart VM call stack from overflow.

---

## 9. Engineering Conclusions

1. **Orthogonal Plane Separation**:  
   Separating the Control Plane (Phase 1 Push-Dirty) from the Data Plane (Phase 2 Lazy-Pull) eliminates the classic trade-offs between push and pull reactive systems.
2. **Glitch Elimination at Minimum Cost**:  
   What achieves complete glitch immunity without requiring costly $O(V + E)$ topological sorting passes on every state mutation.
3. **Natural Dormancy**:  
   Unobserved nodes never pull data or execute computations during Phase 1, eliminating background CPU drain.
4. **Intrusive High-Performance Data Structures**:  
   Intrusive linked lists and bitfield flags deliver maximum execution speed with minimal memory footprint on the Dart VM.
5. **Transactional Predictability**:  
   Batching coalesces UI rebuilds into single atomic frames while preserving immediate in-scope consistency (RYOW).
