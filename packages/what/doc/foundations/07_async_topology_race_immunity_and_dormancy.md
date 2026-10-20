# Async Topological Race Immunity & Inactive Dormancy Foundations
## (Dynamic Edge Pruning, Control-Plane vs. Data-Plane Orthogonality, Dual-Layer Ghost State Isolation, and Cold Inactive Dormancy)

> **"Asynchronous task cancellation is not about forcibly terminating thread execution; it is about severing edges in the topological DAG to prevent stale results from propagating."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Dart Async Model and Out-of-Order Anomalies

### 1.1 The Out-of-Order Arrival Problem
In modern reactive frontend applications, asynchronous I/O (network queries, disk operations, compute-heavy tasks) inevitably experiences **out-of-order arrival** due to network latency fluctuations, server loads, and cache hits.

A standard failure scenario proceeds as follows:
1. A user selects Tab A, dispatching request $R_A$.
2. The user immediately switches to Tab B, dispatching request $R_B$.
3. Request $R_B$ hits a local cache, returning response $V_B$ in 10ms. The UI updates to show Tab B.
4. 500ms later, the delayed network response $V_A$ for request $R_A$ finally arrives.

Without strict architectural guards, the presentation layer overwrites the active Tab B view with stale data $V_A$, producing **stale data corruption**.

```text
[Race Condition Vulnerability in Traditional Frameworks]

T1: Request A dispatched (Slow Network) ──────────────────────────────────► Arrival VA (Stale!)
T2: Request B dispatched (Fast Cache)   ──────► Arrival VB (Fresh)          │ (UI Corrupted!)
                                                    ▼                       ▼
                                                UI State: B ─────────► UI State: A (Bug!)
```

### 1.2 Inherent Constraints of Dart `Future`
In the Dart language, the core asynchronous primitive `Future<T>` **has no external `cancel()` method**. Once dispatched, a `Future` closure must settle via the event loop regardless of whether the result is still needed.

Consequently, traditional state management approaches (Bloc, Riverpod, Provider, Redux) relied on fragile patterns:
* **Manual Request Sequence Counters**: Incrementing and comparing an `int _currentRequestId` on every resolution.
* **Complex Cancellation Wrappers**: Manually wiring `package:async`'s `CancelableOperation` across branches.
* **UI-Level Defensive Flags**: Checking widget `mounted` or `isClosed` booleans throughout async callbacks.

These manual guards represent major sources of human error where a single omitted check introduces elusive production defects.

---

## 2. Topological Model: Dynamic Edge Pruning Mechanics

The What Framework does not attempt to abort native Dart asynchronous closures artificially. Instead, it **synchronously severs the topological edges in the LPDAG**, establishing 100% architectural immunity against asynchronous race conditions.

### 2.1 Decoupling the Control Plane and Data Plane
What's asynchronous computation pipelines (`computed.future`, `computed.stream`, `switched`) are driven internally by the `_DeltaWhat<T>` engine (`_FutureComputedWhat<T>` and `_StreamComputedWhat<T>` extending `_EagerDeltaWhat<T>`):

```text
               [Query Parameter / Tab Index / Auth State]
                                  │
                                  ▼ (_deltaTerminal: Control Plane Routing Vector / Δ)
┌────────────────────────────────────────────────────────────────────────┐
│  _DeltaWhat<T> (Relay Socket)                                          │
│                                                                        │
│  [Source Branch A] ──────► [Detached & Swept] (Downstream Targets = 0) │
│                                 ▲                                      │
│                                 │ ── Atomic Re-binding (Edge Severance)│
│  [Source Branch B] ══════► [Active Data Pipeline] ══════════► Consumer │
│      (Data Plane: Value Stream)                                        │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Data Plane (`_source`)**:
   - The primary pipeline delivering payload snapshots to downstream consumers through `_CoupledUnaryRelay`.
2. **Control Plane (`_deltaTerminal`)**:
   - Observes upstream parameter mutations via `RawViaTerminal` to evaluate **structural mutation deltas ($\Delta$)**: *which asynchronous bridge node must couple to the primary pipeline?*

### 2.2 Synchronous Atomic Edge Pruning (`_performCouple`)
The moment a parameter transition (A $\to$ B) occurs in the control plane, `_EagerDeltaWhat` evaluates `_evaluateDelta(via)` in a microtask (or synchronously upon pull) to create the new bridge node, and executes `_performCouple`:

```dart
// packages/what/lib/src/engine/_internal/_relay.dart
abstract base class _CoupledUnaryRelay<N extends _Node> extends _UnaryRelay<N> with _PushOriginMixin {
  ...
  @pragma('vm:prefer-inline')
  void _didUpdateSource(N? oldSource, N? newSource) {
    if (identical(oldSource, newSource) || !_lifecycle.isActive) return;

    if (oldSource != null) {
      oldSource._detachTargetEdgeOptimistically(this); // Key 1: Synchronous edge severance
    }
    if (newSource != null) {
      newSource._attachTargetEdgeOptimistically(this); // Key 2: Coupling new data pipeline
    }
  }

  @mustCallSuper
  @pragma('vm:prefer-inline')
  N? _performCouple(N newSource, [bool queuePush = true]) {
    final oldSource = _source;
    if (identical(oldSource, newSource)) return null;
    _version++;
    _source = newSource;
    _pulledVersion = newSource._version;
    _didUpdateSource(oldSource, newSource);
    if (_lifecycle.isActive && queuePush) {
      _PushScope.queueOrigin(this);
    }
    return oldSource;
  }
}
```

#### Intrusive Zero-Allocation Invariant
`_CoupledUnaryRelay<N>` extends `_UnaryRelay<N>`, which mixes in `_UnaryEdgeMixin<N>`. `_UnaryEdgeMixin<N>` directly implements the intrusive `_TargetEdge` interface:
* The linked-list pointers `_prevTarget` and `_nextTarget` reside directly inside the relay node itself.
* Rebinding from `oldSource` to `newSource` is an $O(1)$ intrusive pointer swap with **zero heap allocations** and zero GC pressure.
* When `oldSource._detachTargetEdgeOptimistically(this)` runs, if `oldSource` has no remaining downstream subscribers (`!_hasTargets`), its `_deactivateOptimistically()` lifecycle method executes synchronously.

---

### 2.3 Dual-Layer Ghost State Isolation

When an asynchronous query branch transitions from A to B while $F_A$ is still in flight, the old bridge node becomes an isolated "Ghost Node":

```text
[T1: Source A Bound]
  Bridge A (_targetHead) ──► TargetEdge ──► _DeltaWhat ──► Consumer

[T2: Transition to Source B (Future A still in flight)]
  Bridge A (_targetHead = null, isActive = false)   (Completely Isolated Ghost Node)
  Bridge B (_targetHead) ──► TargetEdge ──► _DeltaWhat ──► Consumer

[T3: Delayed Network Arrival of Future A]
  Bridge A._controller.set(valueA)
   ├─► Line of Defense 1: _Entry._markDirty()
   │     if (!_lifecycle.isActive) return; // [isActive == false! Exits immediately without queuing to _PushScope]
   └─► Line of Defense 2: _Node._propagateDirty()
         _propagatingTarget = _targetHead; // _targetHead == null!
         while (_propagatingTarget != null) { ... } // [Loop executes 0 times]
   └─► Topological propagation path eliminated: Bits delivered downstream = 0 bits
   └─► Bridge A reference count drops to 0, immediately collected by Dart VM GC
```

#### Dual Lines of Defense in Engine Mechanics:
1. **Line of Defense 1 (Root Inactive Short-Circuit)**:
   In `_Entry._markDirty()` (`packages/what/lib/src/what/_internal/_entry.dart`):
   ```dart
   @mustCallSuper
   @pragma('vm:prefer-inline')
   void _markDirty() {
     _version++;
     if (!_lifecycle.isActive) return;
     _PushScope.queueOrigin(this);
   }
   ```
   Because `oldSource._detachTargetEdgeOptimistically(this)` triggered `_deactivateOptimistically()`, `Bridge A`'s `_lifecycle.isActive` is `false`. When $F_A$ completes late and calls `_controller.set(valueA)`, `_markDirty()` short-circuits immediately. The mutation is **never even enqueued** into `_PushScope`.
2. **Line of Defense 2 (Severed Topological Link Traversal)**:
   Even if dirty propagation were invoked on the node:
   In `_Node._propagateDirty()` (`packages/what/lib/src/engine/_internal/_node.dart`):
   ```dart
   @pragma('vm:prefer-inline')
   void _propagateDirty() {
     final prevPropagating = _propagatingTarget;
     _propagatingTarget = _targetHead;
     try {
       while (_propagatingTarget != null) {
         final curr = _propagatingTarget!;
         _propagatingTarget = curr._nextTarget;
         curr._target._invalidate();
       }
     } finally {
       _propagatingTarget = prevPropagating;
     }
   }
   ```
   Because `_targetHead == null`, the loop body executes zero times and exits immediately.
3. **Prompt Memory Reclamation**:
   `_DeltaWhat` now points exclusively to `Bridge B`. With zero incoming references from the active reactive DAG, `Bridge A` and its controller become eligible for garbage collection the moment the completion microtask finishes.

---

### 2.4 Formal Theorem: Complete Async Race Immunity
> **Theorem**: When control plane parameters transition from state $S_k$ to $S_{k+1}$ at time $t_k$, the completion of asynchronous operation $F_k$ initiated under state $S_k$ can exert exactly $0\%$ influence on the observed state of downstream consumer $C$ at any time $t > t_k$.
>
> **Proof**:
> 1. At time $t_k$, the control-plane parameter mutates, causing `_onDeltaDirty()` to schedule or execute `_performCouple(newSource)`.
> 2. Synchronously in `_didUpdateSource(oldSource, newSource)`, `oldSource._detachTargetEdgeOptimistically(this)` unlinks the intrusive `_TargetEdge` pointing to `_DeltaWhat` in $O(1)$ time.
> 3. With zero remaining downstream consumers on `oldSource`, its `_targetHead` becomes `null`, and `oldSource._deactivateOptimistically()` sets `_lifecycle.isActive = false` synchronously.
> 4. When $F_k$ resolves at future time $t_{\text{arrive}} > t_k$ and invokes `oldSource._controller.set(value)`, `_Entry._markDirty()` inspects `if (!_lifecycle.isActive) return;` and terminates before enqueuing to `_PushScope`.
> 5. Furthermore, even if dirty propagation were invoked, `_propagateDirty()` traverses from `_targetHead = null`, executing the propagation loop zero times.
> 6. Consequently, exactly zero topological paths exist connecting $F_k$ to `_DeltaWhat` and downstream consumer $C$, establishing mathematically complete immunity against out-of-order completions. $\blacksquare$

---

## 3. Inactive Dormancy with Subscriber-Driven Lifecycles

While asynchronous nodes operate with active-eager dispatch when observed, unobserved nodes must never execute unneeded network tasks:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Inactive State (Active Subscribers = 0)              │
│                                                                        │
│ • Upstream mutates 1,000 times ──► Dispatched Async I/O Requests: 0    │
│ • Background CPU usage: 0%                                             │
│ • Microtask Queue: Cancelled & cleared immediately (_cancelEager)      │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                        Consumer Mounts (_activate)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Active State (Active Subscribers ≥ 1)                │
│                                                                        │
│ • Preemptive microtask dispatch (Active-Eager)                         │
│ • Upstream mutations trigger immediate concurrent I/O to reduce delay  │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                        Consumer Unmounts (_deactivate)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Dormant Teardown (Immediate Reclamation)             │
│                                                                        │
│ • StreamSubscription.cancel() invoked synchronously                    │
│ • Pending eager microtasks cancelled via _cancelEager()                │
│ • Flags _needsSwitch = true and enters dormant hibernation             │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Cold Inactive Invariant (Zero-Request Dormancy)
When a node is dormant (`!_lifecycle.isActive`), upstream mutations trigger zero network requests:

```dart
// packages/what/lib/src/what/_internal/_delta.dart
abstract base class _EagerDeltaWhat<T> extends _DeltaWhat<T> implements _EagerSchedulable {
  ...
  @override
  void _onDeltaDirty() {
    _needsSwitch = true;
    _invalidate();
    // Microtasks are scheduled ONLY when active downstream consumers exist!
    if (_lifecycle.isActive) {
      _Scheduler.instance._scheduleEager(this);
    }
  }
}
```

Because `_lifecycle.isActive` is `false`, `_scheduleEager(this)` is bypassed entirely. No microtask is registered, and no asynchronous query closure is invoked.

---

### 3.2 Synchronous Microtask Cancellation & Decoupling upon Deactivation
When the last downstream consumer unmounts, `_deactivate()` executes synchronously:

```dart
// packages/what/lib/src/what/_internal/_delta.dart
// Inside _EagerDeltaWhat:
@mustCallSuper
@override
void _deactivate() {
  _Scheduler.instance._cancelEager(this); // 1. Immediately cancel queued microtasks
  super._deactivate();
}

// Inside _DeltaWhat:
@mustCallSuper
@override
void _deactivate() {
  _needsSwitch = true;
  _deltaTerminal.deactivate();            // 2. Stop observing control-plane dependencies
  _performDecouple(false);               // 3. Sever connection to active source
  super._deactivate();
}
```

1. **Queue Purge**: `_Scheduler.instance._cancelEager(this)` removes the node from the microtask queue, ensuring no pending callback fires unexpectedly after unmounting.
2. **Control-Plane Hibernation**: `_deltaTerminal.deactivate()` unlinks dependency edges from control-plane inputs.
3. **Data-Plane Decoupling**: `_performDecouple(false)` severs the edge between `_DeltaWhat` and its active bridge source.

---

### 3.3 Immediate Stream Teardown (`StreamSubscription.cancel()`)
For `computed.stream`, the underlying `_StreamWhatBridge` wires its lifecycle directly into `WhatController`:

```dart
// packages/what/lib/src/what/_internal/_async.dart
base class _PragueVltava<T> {
  _PragueVltava(...) {
    _controller = WhatController<T>.late(
      distinct: distinct,
      equals: equals,
      graceful: graceful,
      onActivated: _subscribe,
      onDeactivated: _unsubscribe, // Hooked directly to subscriber lifecycle!
    );
  }

  void _subscribe() {
    if (_isDone) return;
    _subscription = _stream.listen(
      _controller.set,
      onError: ...,
      onDone: () {
        _isDone = true;
        _unsubscribe();
      },
      cancelOnError: cancelOnError,
    );
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }
}
```

#### Synchronous Teardown Sequence:
1. Consumer unmounts or upstream parameter changes.
2. `_DeltaWhat._deactivate()` invokes `_performDecouple(false)` (or `_didUpdateSource` detaches `oldSource`).
3. `oldSource._detachTargetEdgeOptimistically(this)` unlinks the target edge.
4. Downstream subscriber count drops to zero (`!_hasTargets`).
5. `oldSource._deactivateOptimistically()` executes, invoking `onDeactivated: _unsubscribe`.
6. `_subscription?.cancel()` executes synchronously.

Physical socket connections (WebSockets, gRPC streams) close in lockstep with the UI lifecycle, eliminating resource leaks.

---

### 3.4 Deferred Single-Pass Resolution on Re-mount
If upstream parameters mutate repeatedly during dormancy:
* Intermediate network requests are bypassed entirely.
* Upon remount (`_activate()`), `_EagerDeltaWhat` inspects `_needsSwitch || _deltaTerminal._isSourceDirty`:

```dart
// packages/what/lib/src/what/_internal/_delta.dart
@mustCallSuper
@override
void _activate() {
  super._activate();
  if (_needsSwitch || _deltaTerminal._isSourceDirty) {
    _needsSwitch = false;
    _performSwitchGuarded(false);
    _deltaTerminal._pullVersion();
  }
}
```

* It evaluates **only the latest settled parameter values once synchronously**, coupling to the fresh pipeline with zero roundtrip delay.
* Similarly, if an inactive node is inspected via `untracked(node)` or `_read()`, `_resolve()` catches `_needsSwitch` and executes a guarded switch on-demand.

---

## 4. Reactive Ecosystem Comparison

| Dimension | What Framework | Flutter Riverpod | Bloc / Cubit | TanStack Query |
| :--- | :--- | :--- | :--- | :--- |
| **Race Condition Defense** | **Topological Edge Pruning** (100% Immune) | Manual tokens on `ref.watch` or internal key matching | Manual `transformer: restartable()` required | Query-key-based cache overwrite guards |
| **Boilerplate Overhead** | **Zero (Pure functional declaration)** | Manual cancellation flag checks | Requires RxDart `switchMap` wiring | Manual `AbortSignal` injection |
| **Dart Future Handling** | **Topological isolation** independent of Future | Flag toggles in `onDispose` | Manual `CancelableOperation` | Platform `AbortController` required |
| **Inactive Dormancy** | **100% Zero-Cost Dormancy** (0 I/O) | Risk of leaks if `autoDispose` omitted | Leaks if `Bloc.close()` omitted | Timed retention via `gcTime` |
| **Memory Reclamation** | Synchronous $O(1)$ GC eligibility upon switch | Delayed GC possible | Retained until manual dispose | Reclaimed upon cache expiration |

---

## 5. Engineering Conclusions

1. **Zero-Boilerplate Developer Experience**:  
   Engineers authoring `computed.future` or `computed.stream` write standard async transformation functions without request IDs, cancellation flags, or `isClosed` checks; graph topology guarantees safety automatically.
2. **Dual-Layer Ghost State Isolation**:  
   Out-of-order completions are thwarted by a dual-line architectural defense: the `_markDirty()` inactive guard stops dirty events before queueing to `_PushScope`, and unlinked target edges (`_targetHead == null`) ensure zero downstream propagation if traversed.
3. **Total Subscriber-Driven Lifecycle**:  
   Nodes in dormant hibernation dispatch zero microtasks or I/O requests. When deactivated, pending microtasks are purged via `_cancelEager()`, and active `StreamSubscription` handles are canceled synchronously.
4. **Clean Separation of Concerns**:  
   * **State Framework (What)**: Guarantees topological race condition immunity and inactive resource reclamation.
   * **Network Client (HTTP/Dio/gRPC)**: Manages physical socket bandwidth cancellation (`CancelToken`).  
   These layers remain strictly orthogonal, preserving What core as a pure mathematical LPDAG state engine.
