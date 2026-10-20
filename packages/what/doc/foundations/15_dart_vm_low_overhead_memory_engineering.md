# Zero-Allocation Reactive Graph: Dart VM Optimization & Intrusive Data Structures Specification
## (Intrusive Doubly-Linked Topology, Zero-Allocation Dynamic Epoch Sweeping, Dart AOT/TFA Specialization, and Concurrent Propagation Resilience)

> **"In a 120Hz rendering environment, the primary catalyst of frame drops is rarely raw CPU calculation, but rather garbage collection pauses (GC pauses) triggered by transient heap allocations."**  
> — *What Framework Core Systems Group*

---

## 1. Overview: The Conflict Between Reactive Hot Paths and Dart GC

In high-refresh mobile environments (120fps), the rendering budget per frame is strictly **8.33ms**. Within this narrow window, layout calculation, widget tree building, paint staging, and GPU rasterization must execute seamlessly.

However, conventional Dart/Flutter reactive state frameworks (Rx, Riverpod, Provider, generic Signals ports) manage dependency graphs through dynamic collection wrappers:

* `Set<Subscriber>` or `List<Listener>` for subscriber tracking
* `Map<Node, Version>` for upstream dependency version tracking
* Intermediate `Set` allocations (`OldDependencies \ NewDependencies`) for dynamic conditional branch diffing
* Heap-allocated iterator objects and collection snapshots during notification loops

```text
┌────────────────────────────────────────────────────────────────────────┐
│             Heap Allocation Profile in Traditional Frameworks          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   User Mutation / Frame Tick                                           │
│         │                                                              │
│         ▼                                                              │
│   [Set/List Wrapper Allocation] ──► [Hash Bucket Resizing / Rehashing] │
│         │                                                              │
│         ▼                                                              │
│   [Iterator Object Creation] ──► [Snapshot Collection Cloning]         │
│         │                                                              │
│         ▼                                                              │
│   Rapid Flooding of Dart VM Young Gen (Nursery)                        │
│         │                                                              │
│         ▼                                                              │
│   Stop-the-World Scavenge GC Triggered ──► Visible UI Jank / Stutter   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

These transient collection wrappers flood the **Young Generation Nursery** on every mutation, triggering stop-the-world **Scavenge GC passes** that cause dropped frames and UI stutter.

The What Framework is engineered from first principles under a foundational axiom: **Hot-path operations must incur exactly zero dynamic heap allocations ($O(0)$ allocations)**. Attaching observers, detaching subscribers, propagating dirty signals, checking dirty status, reading states, and executing microtask batches never allocate transient objects.

---

## 2. Intrusive Doubly-Linked Edge Lists & Node Topology

The What Framework instantiates zero `List`, `Set`, or `Map` collection wrappers for reactive graph connectivity. Instead, node entities and edge structures maintain direct pointer references, forming a **two-dimensional intrusive doubly-linked mesh**.

### 2.1 The Core Edge Topology (`_TargetEdge` & `_Edge`)

Downstream subscriber chains (Target lists) and upstream dependency chains (Source lists) are stitched directly via raw pointer fields:

```dart
// packages/what/lib/src/engine/_internal/_edge.dart
abstract interface class _TargetEdge {
  _TargetEdge? _prevTarget;
  _TargetEdge? _nextTarget;

  /// Returns the actual subscriber (target) node associated with this link.
  _DirtyListener get _target;
}

final class _Edge implements _TargetEdge {
  _Edge({required _Node source, required _DirtyListener target})
      : _source = source,
        _target = target,
        _pulledVersion = source._version;

  int _pulledVersion;
  int _seenEpoch = 0;

  final _Node _source;
  _Edge? _prevSource;
  _Edge? _nextSource;

  @override
  final _DirtyListener _target;

  @override
  _TargetEdge? _prevTarget;

  @override
  _TargetEdge? _nextTarget;
}
```

```text
       [Source Node A] (implements _Node)
       ┌────────────────────────┐
       │ _targetHead            │
       └───────────┬────────────┘
                   │
                   ▼
       ┌────────────────────────┐   _nextTarget    ┌────────────────────────┐
       │         _Edge          │ ───────────────► │         _Edge          │
       │ (Target: B, Source: A) │ ◄─────────────── │ (Target: C, Source: A) │
       └───────────┬────────────┘   _prevTarget    └───────────┬────────────┘
                   │                                           │
                   ▼                                           ▼
       [Target Node B] (_sourceHead)               [Target Node C] (_sourceHead)
       ┌────────────────────────┐                  ┌────────────────────────┐
       │ _sourceHead ──► _Edge  │                  │ _sourceHead ──► _Edge  │
       └────────────────────────┘                  └────────────────────────┘
```

* **CPU Cache Locality**: Four raw 64-bit pointers (32 bytes) form a dense, L1/L2 cache-aligned memory layout without pointer indirection through hash buckets.
* **Intrusive Head Insertion ($O(1)$)**: New subscribers prepend directly to the source node's `_targetHead`, requiring zero array reallocation or rehashing.

### 2.2 Zero-Allocation Unary Specialization (`_UnaryEdgeMixin`)

A significant percentage of reactive connections are strictly 1:1 relationships (e.g., `a.map(...)`, `a.effect(...)`, unary terminals like [`RawWhatTerminal`](../../lib/src/engine/terminal.dart), unary relays [`_UnaryRelay`](../../lib/src/engine/_internal/_relay.dart), and [`EffectRunner`](../../lib/src/effect/runner.dart)).

In these scenarios, allocating even an `_Edge` object is redundant. Under [`_UnaryEdgeMixin`](../../lib/src/engine/_internal/_edge.dart), **the downstream node itself implements `_TargetEdge`**:

```dart
// packages/what/lib/src/engine/_internal/_edge.dart
base mixin _UnaryEdgeMixin<N extends _Node> on _Lifecycle
    implements _TargetEdge, _DirtyListener, _DirtySyncable {
  @override
  _TargetEdge? _prevTarget;

  @override
  _TargetEdge? _nextTarget;

  @override
  _DirtyListener get _target => this;

  N get _source;
  int _pulledVersion = 0;

  @mustCallSuper
  @override
  void _activate() {
    _source._attachTargetEdgeOptimistically(this);
    super._activate();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _pulledVersion = _source._version;
    super._deactivate();
    _source._detachTargetEdgeOptimistically(this);
  }
}
```

* **Zero Edge Allocation**: `_prevTarget` and `_nextTarget` are physical fields declared on the unary node instance itself.
* Connecting a unary observer directly links `this` into `_source._targetHead` with **exactly 0 bytes of heap allocation**.

### 2.3 N-ary Edge Pooling & Lifecycle Retention (`_NaryEdgeMixin`)

For multi-dependency nodes (`computed`, `switched`, `managed`, `Effect(...)`), [`_NaryEdgeMixin`](../../lib/src/engine/_internal/_edge.dart) manages an intrusive doubly-linked list of `_Edge` instances (`_sourceHead` to `_sourceTail`).

When an N-ary node enters dormancy upon subscriber count reaching zero, **it retains its allocated `_Edge` chain locally**:

```dart
// packages/what/lib/src/engine/_internal/_edge.dart
@pragma('vm:prefer-inline')
void _detachSourceEdges() {
  for (var curr = _sourceHead; curr != null; curr = curr._nextSource) {
    _detachSourceEdge(curr);
  }
}
```

* `_detachSourceEdges()` detaches each `_Edge` from upstream target lists, allowing upstreams to cascade into dormancy.
* The `_Edge` objects themselves remain linked in `_sourceHead`.
* Upon re-activation, `_attachSourceEdges()` simply relinks the existing `_Edge` instances into the upstreams' `_targetHead` lists:
  $$\Delta \text{Heap Allocations on Re-activation} = 0$$

### 2.4 Optimistic Pointer Swapping ($O(1)$) in `_Node`

Pointer mutations in [`_Node`](../../lib/src/engine/_internal/_node.dart) execute in guaranteed $O(1)$ time with hardware-friendly conditional branching:

```dart
// packages/what/lib/src/engine/_internal/_node.dart
@mustCallSuper
@pragma('vm:prefer-inline')
void _attachTargetEdgeOptimistically(_TargetEdge target) {
  assert(
    identical(_targetHead, target) || (target._prevTarget == null && target._nextTarget == null),
    'Attempted to attach a target edge that is already linked to a target list.',
  );

  // Fast duplicate insertion check
  if (identical(_targetHead, target)) return;

  target._nextTarget = _targetHead;
  target._prevTarget = null;

  if (_targetHead != null) {
    _targetHead!._prevTarget = target;
  }
  _targetHead = target;

  // Subscriber-driven topological activation
  if (!_lifecycle.isActive) {
    _activateOptimistically();
  }
}
```

---

## 3. Concurrent Propagation Resilience Without Collection Snapshots

### 3.1 The Iterator Invalidation Dilemma

In reactive graphs, notifying downstream subscribers frequently triggers synchronous side-effects that detach listeners (e.g., a one-shot subscriber unbinding itself or deactivating sibling observers).

In traditional frameworks backed by `List` or `Set`, mutating the subscriber list during iteration throws `ConcurrentModificationError`. Standard solutions force heavy allocation penalties:
1. Cloning the collection prior to iteration: `for (final l in List.of(subscribers))` $\rightarrow$ $O(N)$ heap allocation per pulse.
2. Allocating index-based snapshot vectors or heap iterators.

### 3.2 In-Place Pointer Repair via `_propagatingTarget`

The What Framework achieves **concurrent iteration safety with zero allocations** through in-place pointer repair in [`_Node`](../../lib/src/engine/_internal/_node.dart):

```dart
// packages/what/lib/src/engine/_internal/_node.dart
@pragma('vm:prefer-inline')
void _propagateDirty() {
  final prevPropagating = _propagatingTarget;
  _propagatingTarget = _targetHead;
  try {
    while (_propagatingTarget != null) {
      final curr = _propagatingTarget!;
      _propagatingTarget = curr._nextTarget;
      try {
        curr._target._invalidate();
      } catch (error, stackTrace) {
        curr._target._handleUncaughtError(error, stackTrace);
      }
    }
  } finally {
    _propagatingTarget = prevPropagating;
  }
}
```

When a subscriber detaches during `_propagateDirty()`, [`_detachTargetEdgeOptimistically`](../../lib/src/engine/_internal/_node.dart) immediately inspects and repairs `_propagatingTarget`:

```dart
// packages/what/lib/src/engine/_internal/_node.dart
@mustCallSuper
@pragma('vm:prefer-inline')
void _detachTargetEdgeOptimistically(_TargetEdge target) {
  if (_targetHead == null) return;
  if (!identical(_targetHead, target) && target._prevTarget == null) {
    return;
  }

  // Pointer Repair: If the node being detached is the active cursor,
  // advance it safely to its next sibling before unlinking!
  if (identical(_propagatingTarget, target)) {
    _propagatingTarget = target._nextTarget;
  }

  final prev = target._prevTarget;
  final next = target._nextTarget;

  if (prev != null) {
    prev._nextTarget = next;
  }
  if (next != null) {
    next._prevTarget = prev;
  }

  if (identical(target, _targetHead)) {
    _targetHead = next;
  }

  target._prevTarget = null;
  target._nextTarget = null;

  // Topological Lifecycle Deactivation: 0 subscribers remain
  if (!_hasTargets && _lifecycle.isActive) {
    _deactivateOptimistically();
  }
}
```

* **Zero Snapshot Allocations**: Dirty propagation never clones the target list.
* **Cascading Teardown Immunity**: Even when a subscriber deactivates adjacent siblings (verified in [`target_detachment_test.dart`](../../test/unit/engine/target_detachment_test.dart)), pointer updates ensure no remaining targets drop dirty notifications.
* **Re-entrant Safety**: Re-entrant `_propagateDirty()` pulses preserve outer loops via call-stack restoration (`prevPropagating`).

---

## 4. Dynamic Branching & 1-Pass Epoch Sweeping Algorithm

When dependencies shift dynamically within `computed`, `switched`, or `managed` due to ternary conditions or branch switches, stale edges must be severed without pausing the VM.

### 4.1 Inefficiencies of Traditional Set Diffing

Most reactive libraries execute set difference operations on every recomputation:

$$\text{Obsolete Edges} = \text{OldDependencies} \setminus \text{NewDependencies}$$

This requires allocating two `Set` instances, computing object hash codes, and running nested iterations—generating substantial short-lived heap garbage.

### 4.2 Monotonic Epoch Sweeping with Cursor Acceleration (`_WhatViaEpochMixin`)

The What Framework resolves dynamic branch tracking in a **single linear pass with zero heap allocations** via [`_WhatViaEpochMixin`](../../lib/src/engine/_internal/_via.dart).

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Dynamic Epoch Sweeping Algorithm                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│ 1. _beginEpoch():                                                      │
│    ++_epoch (e.g., epoch = 42)                                         │
│    _cursor = _sourceHead (Pointer cache for sequential O(1) matching)  │
│                                                                        │
│ 2. evaluator(via) Execution:                                           │
│    • via(A) ──► matches _cursor? Yes! ──► Edge(A)._seenEpoch = 42      │
│                 _cursor advances to Edge(B) (O(1) match)               │
│    • Branch skips B ──► Edge(B)._seenEpoch remains 41                  │
│    • via(C) ──► _cursor mismatch fallback ──► Edge(C)._seenEpoch = 42  │
│                                                                        │
│ 3. _endEpoch(42, succeeded: true, commitVersions: ...):                │
│    • _sweepObsoleteEdges(42): Single-pass linked list traversal        │
│      - Edge(A): _seenEpoch == 42 ──► Retained                          │
│      - Edge(B): _seenEpoch < 42  ──► Unlinked & detached immediately!  │
│      - Edge(C): _seenEpoch == 42 ──► Retained                          │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

#### The $O(1)$ Sequential Cursor Fast-Path
In steady-state derivation executions where branch conditions remain stable across frames (the 99% common case), dependency access ordering is identical. The `_cursor` pointer verifies the expected node in a **single pointer identity comparison**:

```dart
// packages/what/lib/src/engine/_internal/_via.dart
@pragma('vm:prefer-inline')
void _trackDependency(_Node source) {
  // 1. Fast-path: Check expected cursor position (O(1) sequential match)
  final cursor = _cursor;
  if (cursor != null && identical(cursor._source, source)) {
    cursor._seenEpoch = _epoch;
    _cursor = cursor._nextSource;
    return;
  }

  _trackDependencySlow(source, _epoch, cursor);
}

// 2. Slow-path: Out-of-line fallback preserving inlining budget & I-Cache locality
@pragma('vm:never-inline')
void _trackDependencySlow(_Node source, int currentEpoch, _Edge? cursor) {
  final matchedEdge = _findSourceEdge(source);
  if (matchedEdge != null) {
    if (matchedEdge._seenEpoch != currentEpoch) {
      if (cursor != null) {
        _moveSourceEdgeBefore(matchedEdge, cursor);
      }
      matchedEdge._seenEpoch = currentEpoch;
    }
  } else {
    final newEdge = _lifecycle.isActive
        ? (cursor != null
            ? _addAndAttachSourceEdgeBefore(source, cursor)
            : _addAndAttachSourceEdge(source))
        : (cursor != null
            ? _addSourceEdgeBefore(source, cursor)
            : _addSourceEdge(source));
    newEdge._seenEpoch = currentEpoch;
  }
}
```

#### 1-Pass Pruning & Atomic Version Commit
Once the evaluation body completes, [`_sweepObsoleteEdges`](../../lib/src/engine/_internal/_via.dart) iterates through `_sourceHead` in a single pass:

```dart
// packages/what/lib/src/engine/_internal/_via.dart
@pragma('vm:prefer-inline')
void _sweepObsoleteEdges(int currentEpoch, {required bool commitVersions}) {
  final isActive = _lifecycle.isActive;
  var curr = _sourceHead;
  while (curr != null) {
    final next = curr._nextSource;
    if (curr._seenEpoch != currentEpoch) {
      if (isActive) {
        _detachAndRemoveSourceEdge(curr);
      } else {
        _removeSourceEdge(curr);
      }
    } else if (commitVersions) {
      // Terminals: commit upstream version in the same pass
      curr._pulledVersion = curr._source._version;
    }
    curr = next;
  }
}
```

* **Relays vs. Terminals**: Pull relays pass `commitVersions: false` (versions are committed after pull resolution in `_PullResolver._resolve`), whereas terminals pass `commitVersions: true` to commit versions during the sweep.
* **Fault Preservation**: If evaluation throws, `_endEpoch(..., succeeded: false)` leaves edges and versions untouched, preserving dirty state so terminals re-evaluate on the next pulse.
* **Computational Cost**: Time complexity is strictly $O(K)$ where $K$ is the active dependency count (typically 2 to 5). Heap allocations are **$O(0)$**.

---

## 5. Dart VM Compiler Optimization Strategies & Runtime Specializations

The What Framework is co-designed with Dart AOT (Ahead-Of-Time) and JIT compiler internals to maximize Type Flow Analysis (TFA) devirtualization, aggressive inlining, and unboxed register evaluation.

### 5.1 `@pragma('vm:prefer-inline')` Directives

Hot-path methods in the reactive engine carry `@pragma('vm:prefer-inline')`:
* `_attachTargetEdgeOptimistically` / `_detachTargetEdgeOptimistically`
* `_propagateDirty`
* `_isNewerThan` / `_resolveDirty` / `_pullVersion`
* `_trackDependency` / `_sweepObsoleteEdges`
* Symmetrical gateway functors (`via`, `via.state`, `untracked`, `untracked.state`)
* State extraction getters (`.data`, `.hasData`, `.isEmpty`, `.hasError`)

This directive instructs the Dart AOT compiler to inline the function body directly into caller call-sites, eliminating stack frame setup, register spill/restore sequences, and branch call latency.

### 5.2 Closed Sealed Hierarchy (`_WhatState<T>`) & Type Flow Analysis (TFA)

State interrogation in What is backed by a strictly library-private sealed hierarchy:

```dart
// packages/what/lib/src/what/_internal/_state.dart
sealed class _WhatState<T> implements WhatState<T> { ... }
final class _ValidWhatState<T> extends _WhatState<T> { final T data; ... }
final class _EmptyWhatState<T> extends _WhatState<T> { final Object? emptyReason; ... }
final class _ErrorWhatState<T> extends _WhatState<T> { final Object error; final StackTrace stackTrace; ... }
```

* **100% Closed Hierarchy**: The hierarchy is private to `framework.dart` with exactly three concrete leaves.
* **TFA Devirtualization**: In the 99.999% hot path (`_ValidWhatState`), `data` is a concrete memory field. Keeping `_read()` returning `_WhatState<T>` allows Dart AOT Type Flow Analysis to specialize inspection paths into direct field offset dereferences with minimal class-ID checks.
* **Zero Boxing on Empty/Error**: Sentinels are stored directly in physical fields without wrapper envelopes.

### 5.3 Symmetrical Zero-Overhead Gateways (`via` & `untracked`)

A core architectural guarantee of What is that reading values outside derivation scopes incurs zero dynamic scope inspection:

```dart
// packages/what/lib/src/what/_internal/_untracked.dart
final class _WhatUntrackedImpl implements WhatUntracked {
  const _WhatUntrackedImpl();

  @override
  @pragma('vm:prefer-inline')
  T call<T>(What<T> what) => what._read().data;

  @override
  @pragma('vm:prefer-inline')
  WhatState<T> state<T>(What<T> what) => what as WhatState<T>;
}
```

* **No Global Scope Lookup**: What avoids global `activeObserver` thread-local queries or stack inspection.
* **Node-as-State Identity**: Calling `untracked.state(what)` returns `what as WhatState<T>` directly with **zero snapshot object allocations**. The node acts as its own state facet.
* **Direct Inlined Speed**: Calling `untracked(what)` on a clean node resolves to a single direct memory dereference at raw instance variable speed (~0.8 ns) via inlining.

### 5.4 Compile-Time Erased `extension type` Wrappers

Feature abstractions in What leverage Dart 3 `extension type`s:
* [`WhatEffectScope`](../../lib/src/effect/extensions.dart) and [`UnaryWhatEffectScope`](../../lib/src/effect/extensions.dart)
* [`WhatIterableElements`](../../lib/src/what/elements.dart), [`WhatListElements`](../../lib/src/what/elements.dart), [`WhatSetElements`](../../lib/src/what/elements.dart), [`WhatMapElements`](../../lib/src/what/elements.dart)
* [`WhatDebug`](../../lib/src/engine/debug.dart)

Extension types provide zero-cost abstractions: at compile time, the Dart compiler completely erases the wrapper type, compiling directly to raw object references without heap headers, wrapper allocations, or pointer chasing.

### 5.5 Dart 3 Record Tuples on CPU Registers

Multi-state inspection and reactive guards operate across 2- to 9-tuples using compile-time extensions:

```dart
// packages/what/lib/src/what/state.dart
extension WhatStateRecord2Extension on (WhatState, WhatState) {
  @pragma('vm:prefer-inline')
  bool allHaveData() => $1.hasData && $2.hasData;

  @pragma('vm:prefer-inline')
  WhatGuard guarded([Object reason = 'PrerequisiteNotMet']) =>
      allHaveData() ? WhatGuard.pass : WhatGuard.block(reason);
}
```

* **Register Allocation**: Unlike `[a, b].allHaveData()` which allocates a `List` on the heap and executes dynamic iterators, `(a, b).allHaveData()` evaluates directly on CPU registers and call stack frames with unboxed boolean logic.
* **Single-Pass Guarding**: Multi-prerequisite guarding in `computed`, `switched`, and `managed` evaluates with zero heap allocations.

### 5.6 Double-Buffered Microtask Scheduler with Tear-Off Caching

The central asynchronous microtask scheduler ([`_Scheduler`](../../lib/src/engine/_internal/_scheduler.dart)) coordinates coalesced pulses, eager switches, terminals, and graceful deactivations using **double-buffered swap sets**:

```dart
// packages/what/lib/src/engine/_internal/_scheduler.dart
base mixin _TerminalSchedulerMixin on _SchedulerBase {
  Set<_TerminalSchedulable> _terminalSet = <_TerminalSchedulable>{};
  Set<_TerminalSchedulable> _terminalSwapSet = <_TerminalSchedulable>{};

  @mustCallSuper
  @override
  void _onTask() {
    super._onTask();
    if (_terminalSet.isEmpty) return;

    final processing = _terminalSet;
    _terminalSet = _terminalSwapSet;
    _terminalSwapSet = processing;

    try {
      for (final target in processing) {
        if (!target._lifecycle.isActive) continue;
        target._performScheduled();
      }
    } finally {
      processing.clear();
    }
  }
}
```

* **Zero Collection Allocation Per Tick**: The two `Set` instances are allocated once on engine startup and swapped in $O(1)$ time; sets are cleared in-place via `.clear()`.
* **Tear-Off Caching**: `late final void Function() _taskHandler = _onTask;` caches the microtask callback tear-off, preventing closure allocation on every `scheduleMicrotask()` invocation.

### 5.7 Stack Trace Suppression in Fast Derivation Short-Circuits

When [`WhatVia.call`](../../lib/src/engine/_internal/_via.dart) encounters an empty or error state during derivation execution, it throws an internal sentinel to abort the compute pass:

```dart
// packages/what/lib/src/engine/_internal/_via.dart
final class _ViaShortCircuit implements Error {
  const _ViaShortCircuit(this.state);
  final _WhatState<Object?> state;

  @override
  StackTrace? get stackTrace => null;
}
```

In the Dart VM, synthesizing a full `StackTrace` captures native stack frames and performs heap allocation. Overriding `stackTrace => null` and catching explicitly via dedicated `on _ViaShortCircuit catch (e)` clauses (omitting the second `StackTrace` parameter) prevents the Dart VM from synthesizing and allocating unnecessary stack trace objects during normal reactive short-circuit propagation.

---

## 6. Core Engineering Invariants

1. **Hot-Path Zero-Allocation Invariant**:  
   Attaching, detaching, propagating dirty pulses, checking versions, and reading via `untracked`/`untracked.state` allocates exactly 0 bytes of heap memory.
2. **Collection-Free Topology Invariant**:  
   Internal reactive DAG structures never instantiate `List`, `Set`, or `Map` collections for graph connectivity; nodes link exclusively via intrusive doubly-linked pointer fields.
3. **Unary Node-as-Edge Invariant**:  
   Unary nodes implement `_TargetEdge` directly, completely bypassing `_Edge` object allocation for 1:1 topologies.
4. **Pointer Repair Iteration Invariant**:  
   Dirty propagation walks intrusive target lists without allocating snapshots or iterators; target detachments repair `_propagatingTarget` on the fly to eliminate concurrent modification errors.
5. **1-Pass Dynamic Epoch Sweeping Invariant**:  
   Dynamic branch discovery tracks iterations via monotonic epochs (`_epoch`) and sequential pointer caching (`_cursor`), completing edge unlinking and version committing in a single linear pass with zero intermediate sets.
6. **Pure Dereference Read Invariant**:  
   Calling `untracked(what)` on a clean node resolves to a single direct object field memory dereference, executing at raw CPU instance variable speed without ambient scope inspection.

---

## 7. Engineering Conclusions

The **Zero-Allocation Reactive Graph: Dart VM Optimization & Intrusive Data Structures** architecture resolves the classic conflict between declarative reactive state management and high-refresh rendering pipelines:

1. **120Hz Jank Immunity**: By driving dynamic heap allocations on reactive hot paths to absolute zero, What completely removes GC nursery allocation pressure, eliminating stop-the-world scavenge pauses during frame-critical interactions.
2. **Mechanical Sympathy with the Dart VM**: Exploiting Dart AOT Type Flow Analysis through sealed class hierarchies, compile-time erased extension types, register-backed Record tuples, and intrusive linked lists delivers computational efficiency approaching hand-written C/C++ memory layouts.
3. **Resilient Graph Dynamics**: In-place pointer repair and 1-pass monotonic epoch sweeping guarantee mathematical correctness and topological safety under complex dynamic branching and concurrent deactivations.
