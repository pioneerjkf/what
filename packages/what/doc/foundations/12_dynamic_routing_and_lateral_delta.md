# Dynamic Routing Foundations: Mainstream Pipeline & Lateral Control Delta Specification
## (Mainstream Data Pipeline, Lateral Control-Plane Delta, Atomic Intrusive Edge Swapping, 1-Pass Epoch Pruning, and Imperative Coupling Sockets)

> **"Decoupling the data plane from the control plane: the foundational theory of dynamic topological DAG routing."**  
> — *What Framework Core Systems Group*

---

## 1. Background: Conceptual Ambiguity in Reactive "Triggers"

In traditional reactive frameworks, the term "trigger" creates severe structural confusion when handling dynamic branching (`if-else`, tab switching, dynamic data source swapping):

* **Conflation of Data Flow and Control Flow**:  
  Classifying both payload sources (`_source`) and branching conditions (`trigger`) as generic, undifferentiated "upstream dependencies" obscures the system's primary data pipeline. A mutation in a boolean tab flag triggers the same generic graph invalidation as an updated list of 1,000 domain entities.
* **Control Logic Bloat & Intermediate Glitches**:  
  When branch decision logic is placed at the center of the reactive graph, conditional state evaluation pollutes data transformation pipelines. Intermediate unneeded branch evaluations cause transient null pointer exceptions, invalidation cascades, and ghost state leakage.
* **Subtree Gating & Dormancy Leaks**:  
  Without strict plane decoupling, unselected conditional branches often remain connected to the reactive graph, consuming CPU cycles, retaining memory, and processing background events even when completely inactive.

To resolve these defects at the mathematical level, the What Framework establishes a core principle borrowed from distributed systems and hardware networking: **the strict physical separation between the Data Plane and the Control Plane** within the reactive LPDAG.

---

## 2. Core Architecture: Data Plane vs. Control Plane

Nodes powered by `_DeltaWhat<T>` (`switched`, `computed.future`, `computed.stream`) split reactive topology into two orthogonal, independently managed planes:

```text
               [Lateral Control Plane: Routing Vector (Δ)]
               (selectedTab, authState, queryParam, userId)
                                  │
                                  ▼ (_deltaTerminal: RawViaTerminal<What<T>>)
┌────────────────────────────────────────────────────────────────────────┐
│  _DeltaWhat<T> (Dynamic Relay Socket)                                  │
│                                                                        │
│  [Source Branch A] ──────► [Detached & Swept] (Downstream Targets = 0) │
│                                 ▲                                      │
│                                 │ ── Atomic Re-binding (Edge Severance)│
│  [Source Branch B] ══════► [Active Data Pipeline] ══════════► Consumer │
│      (Mainstream Data Plane: Payload Stream V)                         │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Mainstream Data Plane (`_source`)
* **Responsibility**: The continuous, high-throughput pipeline delivering data payload snapshots ($V$, e.g., domain models, feeds, collections) directly to downstream consumers.
* **Topology**: Modeled as an intrusive `_CoupledUnaryRelay<What<T>>`. It extends `_UnaryRelay<What<T>>`, which mixes in `_UnaryEdgeMixin<What<T>>`.
* **Zero-Overhead Invariant**: While coupled, payload value transitions ($\Delta V$) propagate through the intrusive `_TargetEdge` pointer list directly to downstream targets via `_target._invalidate()`, introducing zero dynamic dispatch or branch evaluation overhead.

### 2.2 Lateral Control Plane (`_deltaTerminal`)
* **Responsibility**: Observes no payload data; purely evaluates **structural mutation deltas ($\Delta$)**: *which upstream source node must couple to the mainstream pipeline?*
* **Topology**: Modeled as an intrusive `RawViaTerminal<What<T>>` mixing in `_NaryEdgeMixin<_Node>`, `_WhatViaEpochMixin`, and `_ViaTerminalMixin<What<T>>`.
* **Mechanics**:  
  When lateral routing conditions (e.g. `selectedTab`, `authState`) mutate, `_deltaTerminal` triggers `_onDeltaDirty()`, which flags `_needsSwitch = true`. The active branch in the mainstream data plane is then atomically rebound to the newly resolved `What<T>` source.

---

## 3. Foundational Engine: `_DeltaWhat<T>` Architecture

Dynamic rerouting is the universal control mechanism shared by functional branching (`switched`) and asynchronous bridge swapping (`computed.future`, `computed.stream`). Both build directly upon the `_DeltaWhat<T>` abstraction:

```dart
// packages/what/lib/src/what/_internal/_delta.dart
abstract base class _DeltaWhat<T> extends _CoupledUnaryRelay<What<T>>
    with _WhatStateMixin<T>
    implements What<T> {
  _DeltaWhat() : super.late() {
    _deltaTerminal = RawViaTerminal(_evaluateDelta, onInvalidated: _onDeltaDirty);
  }

  late final RawViaTerminal<What<T>> _deltaTerminal;
  bool _needsSwitch = true;
  bool _isResolving = false;

  bool get _isGuarded => false;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _deltaTerminal.activate();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _needsSwitch = true;
    _deltaTerminal.deactivate();
    _performDecouple(false);
    super._deactivate();
  }

  @override
  @pragma('vm:prefer-inline')
  bool get _isSourceDirty => _deltaTerminal._isSourceDirty || super._isSourceDirty;

  @override
  @pragma('vm:prefer-inline')
  void _pullVersion() {
    _deltaTerminal._pullVersion();
    super._pullVersion();
  }
  ...
}
```

### 3.1 Subclass Specialization Contract
Subclasses implement a single synchronous factory method:
```dart
What<T> _evaluateDelta(WhatVia via);
```
* **Functional Branching (`switched`)**: Evaluates user-defined `select(via)` and optional `guard(via)` to dynamically return pre-existing or cached `What<T>` subtrees.
* **Asynchronous Computation (`computed.future`, `computed.stream`)**: Evaluates `compute(via)` to instantiate fresh `_FutureWhatBridge` or `_StreamWhatBridge` handles, rebinding them immediately to the mainstream data plane.

### 3.2 Short-Circuit Fault Propagation (`_performSwitchGuarded`)
Control-plane routing logic evaluated inside `_evaluateDelta(via)` can encounter empty or error states from upstream lateral dependencies. Rather than crashing the LPDAG or bypassing the data plane, `_DeltaWhat` traps `_ViaShortCircuit` and couples the corresponding algebraic state directly into the mainstream pipeline:

```dart
// packages/what/lib/src/what/_internal/_delta.dart
@mustCallSuper
void _performSwitchGuarded([bool queuePush = true]) {
  try {
    final result = _deltaTerminal.evaluate();
    _performCouple(result, queuePush);
  } catch (error, stackTrace) {
    if (error is _ViaShortCircuit) {
      final state = error.state;
      if (state is _EmptyWhatState) {
        _performCouple(What.empty(state.emptyReason), queuePush);
        return;
      }
      if (state is _ErrorWhatState) {
        _performCouple(What.error(state.error, state.stackTrace), queuePush);
        return;
      }
    }
    _performCouple(_catchError(error, stackTrace), queuePush);
  }
}
```

* **Empty Short-Circuit**: If an upstream dependency is empty, `_performSwitchGuarded` couples `What.empty(state.emptyReason)` as the active source.
* **Error Short-Circuit**: If an upstream dependency fails, `What.error(state.error, state.stackTrace)` is coupled without throwing an uncaught exception.
* **Evaluator Exceptions**: Arbitrary exceptions thrown inside `select` or `guard` are trapped and converted to `What.error(error, stackTrace)`.
* **Zero Discontinuity**: In all failure cases, downstream consumers observe a valid, unbroken algebraic state transition through the existing `What<T>` contract.

### 3.3 Guarded Precondition Inactive Protection
When a `_DeltaWhat` node is configured with a precondition guard (`guard: (via) => ...`), the node handles dormant state evaluations with strict version preservation:

```dart
// packages/what/lib/src/what/_internal/_delta.dart in _resolve()
if (_needsSwitch) {
  _needsSwitch = false;
  _performSwitchGuarded(false);
  // If inactive and the guard failed (yielding What.empty), do not advance
  // `_deltaTerminal._pullVersion()`. Acknowledging upstream versions while
  // dormant would falsely clear `_isSourceDirty`, locking the node into an
  // empty state even after activation. Defer resolution by keeping `_needsSwitch = true`.
  if (!_lifecycle.isActive && _isGuarded && _source._read().isEmpty) {
    _needsSwitch = true;
    return;
  }
  _deltaTerminal._pullVersion();
}
```

This invariant guarantees that if an inactive node is read while its guard fails, it does not falsely acknowledge upstream versions; upon activation or next read, it re-evaluates cleanly once the guard passes.

### 3.4 Cyclic Dependency Detection (`LpdagCycleError`)
Dynamic routing must never introduce circular dependency loops into the DAG. `_DeltaWhat` enforces cycle prevention at two distinct boundaries:
1. **Resolution Loop**: `_resolve()` sets `_isResolving = true`. If a downstream consumer attempts to re-enter `_resolve()` recursively during upstream pull, it immediately throws `LpdagCycleError`.
2. **Evaluation Loop**: `_deltaTerminal.evaluate()` sets `_isEvaluating = true`. If the selector closure reads a downstream node that triggers `_deltaTerminal.evaluate()` reentrantly, `RawViaTerminal` throws `LpdagCycleError`.

---

## 4. Orthogonal Scheduling Policies: Lazy vs. Eager

Evaluation scheduling decouples across two distinct policies matching the performance requirements of different reactive tasks:

| Dimension | `_LazyDeltaWhat<T>` (Default On-Demand) | `_EagerDeltaWhat<T>` (Preemptive Microtask) |
| :--- | :--- | :--- |
| **Applicable Primitives** | `switched(..., eager: false)` | `computed.future`, `computed.stream`, `switched(..., eager: true)` |
| **Class Hierarchy** | `extends _DeltaWhat<T>` | `extends _DeltaWhat<T> implements _EagerSchedulable` |
| **Switch Timing** | On-demand when consumers pull (`_read()`, `untracked(node)`, `.snapshot`) | Scheduled preemptively in microtask tick while active |
| **Activation Behavior** | Activates `_deltaTerminal`; defers evaluation | Synchronously resolves switch if `_needsSwitch` or dirty |
| **Deactivation Behavior** | Deactivates `_deltaTerminal` & decouples source | Cancels pending microtask, deactivates terminal & decouples source |
| **Push-Origin Dispatch** | Passive: marks downstream `Check`/`Dirty` | Active: microtask dispatches `_PushScope.queueOrigin(this)` |
| **Design Objective** | Zero-cost branch switching for dormant/unobserved nodes | Eliminates async I/O latency, prevents event dropping |

### 4.1 Lazy Scheduling Mechanics (`_LazyDeltaWhat<T>`)
```dart
// packages/what/lib/src/what/_internal/_delta.dart
abstract base class _LazyDeltaWhat<T> extends _DeltaWhat<T> {
  _LazyDeltaWhat();

  @override
  void _onDeltaDirty() {
    _needsSwitch = true;
    _invalidate();
  }
}
```
* When control-plane routing state mutates, `_onDeltaDirty()` marks `_needsSwitch = true` and pushes a dirty notification downstream (`_invalidate()`).
* **Zero Switch Overhead**: Neither `_deltaTerminal.evaluate()` nor `_performCouple()` is executed until a downstream consumer actually pulls the node (`_resolve()` / `_read()`).
* If the consumer never observes the branch (e.g. unrendered UI tabs, inactive background views), the branch decision closure is never executed, saving CPU cycles and allocations.

### 4.2 Eager Scheduling Mechanics (`_EagerDeltaWhat<T>`)
```dart
// packages/what/lib/src/what/_internal/_delta.dart
abstract base class _EagerDeltaWhat<T> extends _DeltaWhat<T> implements _EagerSchedulable {
  _EagerDeltaWhat();

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

  @mustCallSuper
  @override
  void _deactivate() {
    _Scheduler.instance._cancelEager(this);
    super._deactivate();
  }

  @override
  void _onDeltaDirty() {
    _needsSwitch = true;
    _invalidate();
    if (_lifecycle.isActive) {
      _Scheduler.instance._scheduleEager(this);
    }
  }

  @override
  void _performScheduledEager() {
    if (!_lifecycle.isActive || !_needsSwitch) return;
    _needsSwitch = false;
    _performSwitchGuarded(true);
  }
}
```
* **Preemptive Microtask Queue**: When active, `_onDeltaDirty()` enqueues the node into `_Scheduler.instance._scheduleEager(this)`.
* **Immediate Origin Push**: When `_performScheduledEager()` runs in the microtask, it passes `queuePush = true` to `_performSwitchGuarded()`. This registers the relay as a push origin via `_PushScope.queueOrigin(this)`, broadcasting a push-dirty pulse downstream immediately upon branch swap.
* **Activation Synchronization**: The moment an `_EagerDeltaWhat` transitions from inactive to active, `_activate()` synchronously evaluates the pending switch so downstream listeners receive the fresh active branch without a 1-frame microtask lag.
* **Pull-Before-Tick Coalescing**: If a consumer reads `untracked(node)` or `.snapshot` *before* the scheduled microtask tick runs, `_resolve()` executes `_performSwitchGuarded(false)` synchronously and resets `_needsSwitch = false`. When the microtask tick subsequently fires, it early-returns cleanly without redundant evaluation.

---

## 5. Atomic Pointer Swapping, 1-Pass Epoch Sweeping, and Inactive Cold Dormancy

A classical defect in dynamic reactive branching is **ghost edge leakage**: inactive branches lingering in upstream target dependency sets, leading to memory leaks and invalidation cascades.

The What Framework pairs **$O(1)$ atomic intrusive pointer swapping** with **1-Pass Monotonic Epoch Sweeping**:

```dart
// packages/what/lib/src/engine/_internal/_relay.dart
abstract base class _CoupledUnaryRelay<N extends _Node> extends _UnaryRelay<N> with _PushOriginMixin {
  ...
  @pragma('vm:prefer-inline')
  void _didUpdateSource(N? oldSource, N? newSource) {
    if (identical(oldSource, newSource) || !_lifecycle.isActive) return;

    if (oldSource != null) {
      oldSource._detachTargetEdgeOptimistically(this); // [1] Sever old source immediately
    }
    if (newSource != null) {
      newSource._attachTargetEdgeOptimistically(this); // [2] Atomically attach new source
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

### 5.1 Intrusive Zero-Allocation Invariant ($O(1)$)
`_CoupledUnaryRelay<N>` extends `_UnaryRelay<N>`, which mixes in `_UnaryEdgeMixin<N>`. `_UnaryEdgeMixin<N>` directly implements the intrusive `_TargetEdge` interface:
* The linked-list pointers `_prevTarget` and `_nextTarget` reside directly inside the relay node object itself.
* Severing `oldSource` and attaching `newSource` is an $O(1)$ intrusive pointer swap with **zero heap allocations** and zero GC pressure.

### 5.2 Total Ghost State Isolation
When the control plane rebinds the data plane from Branch A to Branch B:
1. `oldSource._detachTargetEdgeOptimistically(this)` instantly removes the relay node from Branch A's downstream target list.
2. If Branch A has an in-flight asynchronous computation (e.g. an uncancelable Dart `Future`), its late-arriving completion executes `_controller.set(...)`, which triggers `_propagateDirty()`.
3. Because `_targetHead` on Branch A no longer contains this relay, **the dirty pulse hits a dead end and terminates immediately with zero bits propagated downstream**.

### 5.3 Dual-Plane Inactive Cold Dormancy
When downstream subscribers drop to zero, `_DeltaWhat._deactivate()` enforces complete resource reclamation across both planes:
```dart
// packages/what/lib/src/what/_internal/_delta.dart
@mustCallSuper
@override
void _deactivate() {
  _needsSwitch = true;
  _deltaTerminal.deactivate(); // Control plane: detaches all lateral upstream edges
  _performDecouple(false);    // Data plane: detaches mainstream upstream edge
  super._deactivate();
}
```
* **Control Plane Dormancy**: `_deltaTerminal.deactivate()` detaches all observed lateral upstream edges.
* **Data Plane Dormancy**: `_performDecouple(false)` detaches the mainstream source from `_source` and resets `_source` to `What.empty()`.
* **Zero Retention**: Both planes release their upstream connections completely. Upstream subgraphs enter true cold dormancy, stopping timers, closing stream subscriptions, and becoming immediately eligible for garbage collection.

### 5.4 Control Plane 1-Pass Monotonic Epoch Sweeping
Inside `_deltaTerminal` (`RawViaTerminal`), dynamic dependencies observed across conditional branches are maintained via `_WhatViaEpochMixin`:
```dart
// packages/what/lib/src/engine/_internal/_via.dart
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
      curr._pulledVersion = curr._source._version;
    }
    curr = next;
  }
}
```
* During `evaluate()`, `++_epoch` monotonically increments the evaluation counter.
* Lateral sources read via `via(node)` mark their connecting edge with `_seenEpoch = currentEpoch`.
* In a single $O(\text{edges})$ traversal, unread edges from previous branches are detached immediately, while retained edges commit their upstream versions in the same pass.
* This eliminates temporary `Set` or `List` allocations during dynamic branch switching.

---

## 6. Unified Functor Ecosystem: Declarative Dynamic Branching (`switched`)

The `switched` top-level functor provides a clean, declarative entry point for functional dynamic branching across disjoint subgraphs:

```dart
// packages/what/lib/src/what/switched.dart
const switched = SwitchedFunctor._();

final class SwitchedFunctor {
  const SwitchedFunctor._();

  What<T> call<T>(
    What<T> Function(WhatVia via) select, {
    WhatGuard Function(WhatVia via)? guard,
    bool eager = false,
  }) =>
      eager
          ? _EagerSwitchedWhat<T>(select: select, guard: guard)
          : _LazySwitchedWhat<T>(select: select, guard: guard);
}
```

### 6.1 Architectural Flow
```text
[Control Condition (e.g. isOnline)] ──► Evaluates switched(via)
                                                  │
                 ┌────────────────────────────────┴────────────────────────────────┐
                 ▼                                                                 ▼
        [Live Branch (What<T>)]                                           [Cached Branch (What<T>)]
                 │                                                                 │
                 └────────────────────────────────┬────────────────────────────────┘
                                                  ▼ (Flattens into Unary Edge)
                                         [Downstream Consumer]
```

### 6.2 Precondition Gating with `WhatGuard`
`switched` supports precondition guards to gate branch switching and avoid instantiating heavy subtrees until prerequisites are satisfied:
```dart
final selectedTab = WhatController(0);
final isLoggedIn = WhatController(false);

final currentFeed = switched(
  (via) => via(selectedTab.what) == 0 ? homeFeed.what : trendingFeed.what,
  // Gating: Entire downstream feed graph remains uninstantiated until user authenticates
  guard: (via) => via(isLoggedIn.what).guarded('UserNotAuthenticated'),
);
```

### 6.3 Best Practices & Anti-Pattern Prevention
* **Switch Between Pre-Existing Stable Branches**:  
  Return pre-existing or cached `What<T>` nodes from `select`.
* **DO NOT Instantiate State Nodes Inside `select`**:  
  Creating new `WhatController` instances inside `select` on every dependency tick orphans reactive subgraphs and breaks lifecycle continuity.

```dart
// BAD: Re-creates controller on every branch evaluation
final currentTheme = switched((via) {
  return WhatController('Dark').what; // Anti-pattern: allocates new node every tick!
});

// GOOD: Return pre-existing or cached state nodes
final currentTheme = switched((via) {
  return via(isDark.what) ? darkTheme.what : lightTheme.what;
});
```

---

## 7. Production Code Example

The following example demonstrates dynamic routing between a live asynchronous network feed (`computed.future`) and an offline cache pipeline (`computed`), with seamless downstream effect observation:

```dart
import 'package:what/what.dart';
import 'package:what/effect.dart';

// 1. Two independent data plane pipelines
Future<List<String>> fetchLiveStockQuotes() async => ['AAPL: \$180', 'GOOG: \$140'];
List<String> getOfflineCachedQuotes() => ['AAPL: \$175 (cached)'];

final liveStockFeed = computed.future(
  (via) => fetchLiveStockQuotes(),
  initialFactory: () => const <String>[],
);
final cachedStockFeed = computed((via) => getOfflineCachedQuotes());

// 2. Control plane routing state (Online/offline toggle)
final isOnlineMode = WhatController<bool>(true);

// 3. Switched: Dynamic routing of data plane based on control plane delta (Δ)
final activeStockFeed = switched<List<String>>(
  (via) => via(isOnlineMode.what) ? liveStockFeed : cachedStockFeed,
);

// 4. Downstream consumers receive uninterrupted stream continuity across branch switches
void main() {
  final monitor = Effect.via((via) {
    final quotes = via(activeStockFeed);
    print('Active stock quotes: $quotes');
  }).run();

  // Initially prints: Active stock quotes: []
  // After fetch settles: Active stock quotes: [AAPL: $180, GOOG: $140]

  // Switch to offline cached feed dynamically:
  isOnlineMode.data = false;
  // Prints: Active stock quotes: [AAPL: $175 (cached)]

  // Clean up standalone effect runner:
  monitor.deactivate();
}
```

* Downstream consumers remain completely oblivious to whether the active source is `liveStockFeed` or `cachedStockFeed`.
* Branch switches rebind active edges atomically, streaming fresh values through the existing consumer interface without widget unmounts.

---

## 8. Imperative Relay Socket: `WhatCoupler<T>` & `_CoupledWhat<T>`

Where `switched` provides **declarative routing** conditioned on reactive state, [`WhatCoupler<T>`](../../lib/src/what/coupler.dart) provides an **imperative relay socket** for hot-coupling or cold-coupling upstream sources from external domains (auth handlers, environment toggles, dynamic DI containers).

```text
[Upstream Pipeline A] (Detached on couple)
       │
       ▼ (coupler.couple(liveSource.what))
┌─────────────────────┐
│   WhatCoupler<T>    │ ──► coupler.what (Read-Only) ──► [Downstream Consumers]
└─────────────────────┘
       ▲
       │ (Newly Attached via 1-tier relay proxy)
[Upstream Pipeline B]
```

### 8.1 Key Invariants
1. **Producer-Consumer Capability Decoupling**:  
   `WhatCoupler<T>` acts as the mutable manager handle, exposing the read-only `coupler.what` (`What<T>`) view to consumers. Direct state reading is supported on the coupler itself (`coupler.data`, `coupler.snapshot`, `coupler.isEmpty`, `coupler.hasData`, etc.) or via `untracked(coupler.what)`.
2. **Coupling Modalities**:
   - `WhatCoupler(inbound)`: Pre-coupled with initial pipeline.
   - `WhatCoupler.late()`: Uninitialized empty state awaiting the initial `couple()` call.
   - `WhatCoupler.error(error, [stackTrace])`: Initialized in error state.
3. **Comprehensive Socket Operations**:
   - `coupler.couple(newInbound)`: Atomically swaps inbound source, updates version, and queues push origin, returning the previous inbound node or `null`.
   - `coupler.coupleGuarded(callback)`: Executes callback safely, catching exceptions and transitioning to error state on failure.
   - `coupler.decouple()`: Immediately detaches inbound node, transitioning the coupler into an empty state.
   - `coupler.tryDecoupling(what)`: Conditionally decouples only if `what` matches the currently coupled source.
   - `coupler.setError(error, [stackTrace])`: Injects a manual error state into the relay.
4. **Circular Dependency Immunity (`LpdagCycleError`)**:  
   The underlying `_CoupledWhat<T>` node guards its `_resolve()` path with `_isResolving`. Attempts to couple downstream descendants back upstream are trapped and throw `LpdagCycleError`, preserving DAG acyclicity.
5. **Subscriber-Driven Dormancy Proxying**:  
   `coupler.isActive` directly reflects whether downstream consumers are subscribed to `coupler.what`. When dormant, `WhatCoupler` holds no active upstream edge on its source.

---

## 9. Implementation & Verification Matrix

| Architectural Guarantee | Behavioral Specification | Engine Implementation Anchor | Test Suite Verification |
| :--- | :--- | :--- | :--- |
| **Data/Control Plane Decoupling** | Payload stream ($V$) and routing vector ($\Delta$) execute on independent, orthogonal DAG planes. | [`_DeltaWhat`](../../lib/src/what/_internal/_delta.dart), [`RawViaTerminal`](../../lib/src/engine/terminal.dart) | [`switched_test.dart` (test 1)](../../test/unit/what/switched_test.dart) |
| **Atomic Intrusive Pointer Swap** | Old source detached and new source attached via $O(1)$ zero-allocation pointer update. | [`_CoupledUnaryRelay._didUpdateSource`](../../lib/src/engine/_internal/_relay.dart) | [`coupler_test.dart` (1.1, 1.2)](../../test/unit/what/coupler_test.dart) |
| **Short-Circuit Fault Propagation** | Upstream empty/error states inside selector trapped via `_ViaShortCircuit` and coupled safely. | [`_DeltaWhat._performSwitchGuarded`](../../lib/src/what/_internal/_delta.dart) | [`switched_test.dart`](../../test/unit/what/switched_test.dart) |
| **1-Pass Monotonic Epoch Sweeping** | Obsolete control-plane edges detached and retained edge versions committed in a single $O(N)$ pass. | [`_WhatViaEpochMixin._sweepObsoleteEdges`](../../lib/src/engine/_internal/_via.dart) | [`switched_test.dart` (test 2)](../../test/unit/what/switched_test.dart) |
| **Dual-Plane Inactive Cold Dormancy** | Both data-plane and control-plane edges severed upon zero downstream subscribers. | [`_DeltaWhat._deactivate`](../../lib/src/what/_internal/_delta.dart) | [`coupler_test.dart` (3.3)](../../test/unit/what/coupler_test.dart) |
| **Eager Preemptive Microtask Switch** | Active eager nodes queue microtask via `_Scheduler` and broadcast via `_PushScope.queueOrigin`. | [`_EagerDeltaWhat`](../../lib/src/what/_internal/_delta.dart) | [`async_computed_test.dart`](../../test/unit/what/async_computed_test.dart) |
| **Imperative Relay Socket Continuity** | Upstream sources hot-swapped without disrupting downstream subscriptions or unmounting widgets. | [`WhatCoupler`](../../lib/src/what/coupler.dart), [`_CoupledWhat`](../../lib/src/what/_internal/_coupler.dart) | [`coupler_test.dart` (1.1, 4.1)](../../test/unit/what/coupler_test.dart) |
| **Circular Dependency Trapping** | Reentrant coupling or branch resolution loops trapped and rejected via `LpdagCycleError`. | [`_CoupledWhat._resolve`](../../lib/src/what/_internal/_coupler.dart), [`_DeltaWhat._resolve`](../../lib/src/what/_internal/_delta.dart) | [`coupler_test.dart` (2.1)](../../test/unit/what/coupler_test.dart) |

---

## 10. Engineering Conclusions

The **Dynamic Routing Foundations: Mainstream Pipeline & Lateral Control Delta** architecture provides the mathematical foundation for runtime graph morphing in What Framework:

1. **Separation of Concerns**: Treating the data plane as an intrusive unary pipeline and the control plane as an $N$-ary routing terminal eliminates control bloat and intermediate glitches.
2. **Deterministic Resource Safety**: Synchronous intrusive edge severance guarantees that disconnected branches instantly become dead-ends for asynchronous events, eliminating ghost states and race conditions.
3. **Dual Modality Harmony**: Declarative branch selection (`switched`) and imperative socket coupling (`WhatCoupler`) share the exact same underlying `_CoupledUnaryRelay` engine, ensuring uniform performance, zero memory leaks, and glitch-free consistency across the entire framework.
