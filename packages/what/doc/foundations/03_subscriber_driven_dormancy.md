# Subscriber-Driven Inactive Dormancy & Pure Lazy Lifecycle Specification
## (Demand-Driven Topological Activation, Cold Resource Cascading, Pure Lazy Functors, and Zero-Overhead Inactive States)

> **"A reactive node unobserved by any active consumer must consume exactly zero runtime resources. True performance is defined by demand-driven topological activation."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Problem Statement: Background Resource Leaks in Reactive Frameworks

Traditional frontend and Flutter state management solutions (GetX, Provider, Bloc, Riverpod) frequently suffer from three structural pitfalls:

1. **Ghost Subscriptions**:  
   When users navigate away from a view or switch tabs, unobserved upstream event streams, periodic timers, or hardware frame tickers continue executing in the background, draining battery, memory, and CPU cycles.
2. **Manual Lifecycle Management Overhead**:  
   Engineers are forced to manually orchestrate `dispose()`, `cancel()`, and `close()` calls across nested controller structures. Maintaining teardowns across dynamic branching conditions (`if-else`, tab switching) is notoriously fragile and error-prone.
3. **Eager Initialization Costs**:  
   Nodes compute or allocate heap objects immediately upon declaration, incurring substantial initialization costs for data models or I/O controllers that may never be rendered on screen.

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│               Traditional Frameworks vs. What Framework Lifecycle              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   [Traditional Frameworks: Eager / Ghost Subscriptions]                       │
│   Declaration ──► [Eager Initialization] ──► [Continuous Background Execution]  │
│   View Unmount ──► [Forgotten dispose()?] ──► Ghost Leak (Battery / CPU Drain) │
│                                                                                 │
│   [What Framework: Subscriber-Driven Inactive Dormancy]                         │
│   Declaration ──► [Cold Dormant State: 0 CPU / 0 I/O / 0 Allocations]           │
│   View Mount   ──► [Demand-Driven Topological Activation (0 -> 1)]              │
│   View Unmount ──► [Instant Recursive Cascading Dormancy (1 -> 0)]              │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

The What Framework resolves these challenges through a core architectural invariant: **Any reactive node lacking active downstream consumers must maintain zero CPU consumption, zero frame ticks, zero active timers, and zero open I/O subscriptions.**

---

## 2. Core Architectural Principle: Demand-Driven Topological Activation

The reactive DAG operates under a demand-driven subscription model. Topological edge attachment is the sole catalyst for node execution.

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                             Dormant State (Inactive)                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  [Source Node] ─── (Disconnected / Unobserved) ───► [Derived Node / Resource]  │
│  (_LifecycleState.inactive)                           (_LifecycleState.inactive)│
│                                                       (Zero CPU / Zero I/O)     │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                                   │
                    UI Mount / Terminal.activate() (Demand)
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                             Active State (Running)                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  [Source Node] ═══════ (Topological Edge Attached) ═══════► [Derived Node]      │
│  (_LifecycleState.running)                                  │                   │
│                                                             ▼                   │
│                                                [Terminal / WhatWidget]          │
│                                                (Mounted in Render Tree)         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 The Two-State Lifecycle Machine (`_LifecycleState`)

Every reactive node and terminal implements [`_Lifecycle`](../../lib/src/engine/_internal/_lifecycle.dart#L25), which maintains a two-state finite state machine governed by [`_LifecycleState`](../../lib/src/engine/_internal/_lifecycle.dart#L14):

```dart
// packages/what/lib/src/engine/_internal/_lifecycle.dart
enum _LifecycleState {
  inactive,
  running;

  @pragma('vm:prefer-inline')
  bool get isActive => this != inactive;
}
```

* **Dormant (`_LifecycleState.inactive`)**: The object is dormant. It holds immutable configuration references only. It registers zero event listeners, allocates no background resources, and performs zero evaluations.
* **Running (`_LifecycleState.running`)**: The object is topologically linked to an active consumer. It participates in 2-Phase LPDAG invalidations and resolves derivations on demand.

### 2.2 Activation and Deactivation Transitions in `_Node`

Topological transitions in [`_Node`](../../lib/src/engine/_internal/_node.dart#L48) occur automatically based on the presence of downstream targets (`_hasTargets => _targetHead != null`):

```dart
// packages/what/lib/src/engine/_internal/_node.dart
@mustCallSuper
@pragma('vm:prefer-inline')
void _attachTargetEdgeOptimistically(_TargetEdge target) {
  // ... pointer linking ...
  if (!_lifecycle.isActive) {
    _activateOptimistically(); // 0 -> 1 Subscribers: Wake from dormancy
  }
}

@mustCallSuper
@pragma('vm:prefer-inline')
void _detachTargetEdgeOptimistically(_TargetEdge target) {
  // ... pointer unlinking ...
  if (!_hasTargets && _lifecycle.isActive) {
    _deactivateOptimistically(); // 1 -> 0 Subscribers: Return to dormancy
  }
}
```

1. **Subscriber-Driven Activation ($0 \rightarrow 1$)**:  
   When the first downstream subscriber attaches to `_targetHead`, [`_activateOptimistically()`](../../lib/src/engine/_internal/_lifecycle.dart#L45) transitions the node from `inactive` to `running`. The node connects its upstream source edges via [`_activate()`](../../lib/src/engine/_internal/_edge.dart#L61) and prepares for lazy-pull resolution.
2. **Instant Deactivation on Zero Subscribers ($1 \rightarrow 0$)**:  
   When the last downstream subscriber detaches (`!_hasTargets`), [`_deactivateOptimistically()`](../../lib/src/engine/_internal/_lifecycle.dart#L55) immediately transitions the node back to `inactive`. The node unlinks from its upstream sources via [`_deactivate()`](../../lib/src/engine/_internal/_edge.dart#L68).

### 2.3 Recursive Cascading Dormancy

Dormancy cascades recursively up the reactive hierarchy. When a UI element unmounts:

```text
[UI Screen Unmounts]
        │
        ▼ (deactivate())
[Terminal] ──(detaches edge)──► [Derived Node B]
                                       │ (targetHead == null ──► deactivates)
                                       ▼ (detaches edge)
                                [Root Source A / managed]
                                       │ (targetHead == null ──► deactivates)
                                       ▼
                                [Cold Dormancy: Sockets Closed, Timers Cancelled]
```

* **No Orphan Background Tasks**: Because upstream edges are detached the moment a node enters dormancy, upstream nodes also detect when their subscriber count hits zero, propagating deactivation all the way to root sources.
* **Edge Retention for Zero-Allocation Wake-Up**: Under [`_NaryEdgeMixin`](../../lib/src/engine/_internal/_edge.dart#L95), detaching upstream edges unlinks them from upstream target lists but preserves the allocated `_Edge` instances in `_sourceHead`. If the node reactivates later, it relinks the existing edges with **zero heap allocations**.

---

## 3. Pure Lazy Standardization vs. Eager Scheduling

The What Framework enforces pure laziness across synchronous derivations and external resource management:

### 3.1 Pure Lazy Standardization (`computed`, `switched`, `managed`)

* **`computed`**: Pure synchronous derivations evaluate strictly upon on-demand pull (`_resolve()`). Even if active, a `computed` node whose dependencies mutated only re-evaluates when an active terminal pulls its value.
* **`switched` (`eager: false`)**: Dynamic branching functors default to on-demand lazy evaluation. Inactive branch alternatives remain unobserved and uncomputed.
* **`managed` (`eager: false`)**: Synchronous external resource managers default to lazy initialization. The `create()` callback executes only when an active consumer establishes a subscription and pulls data.

### 3.2 Asynchronous Pipelines and Cold I/O (`computed.future`, `computed.stream`)

While asynchronous ingress bridges use the microtask scheduler for dispatch, their underlying I/O lifecycle is strictly bound to subscriber presence:

```dart
// Continuous WebSocket or SSE feed
final liveMarketFeed = computed.stream((via) {
  final symbol = via(selectedSymbol.what);
  return marketClient.subscribeToSymbol(symbol);
});
```

* **Cold I/O Invariant**: If `selectedSymbol` changes 1,000 times while `liveMarketFeed` is unobserved, **zero network connections or WebSocket subscriptions are created**.
* **Instant Cancellation on Unmount**: When the last UI subscriber detaches, the underlying `StreamSubscription` cancels synchronously. No background packets are decoded or dispatched.

---

## 4. Production Architecture Patterns

### 4.1 Synchronous External Resource Lifecycle (`managed`)

External handles requiring deterministic acquisition and disposal (hardware sensors, FFI pointers, periodic timers, native sound handles) are wrapped via [`managed`](../../lib/src/what/managed.dart#L51):

```dart
final tickInterval = WhatController(const Duration(seconds: 1));

// Timer handle is instantiated ONLY while observed by an active screen
final heartbeatTimer = managed<Timer>(
  create: (via) => Timer.periodic(via(tickInterval.what), (t) => sendPing()),
  dispose: (timer) => timer.cancel(),
);
```

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     managed<T> Lifecycle State Transitions                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Screen Mounts ──► Terminal connects ──► First Pull ──► create() executed     │
│                                                                  │              │
│   Upstream Mutates ──► update() executed (or dispose() + create())               │
│                                                                  │              │
│   Screen Unmounts ──► Subscribers = 0 ──► dispose() executed ──► Timer Cancelled│
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

* **No Manual Cleanup**: The engineer never writes `initState` or `dispose` overrides in widgets. The reactive topology manages the native handle automatically.

### 4.2 Asynchronous Continuous Data Feeds (`computed.stream`)

```dart
final currentRoomId = WhatController('room-general');

final roomMessages = computed.stream(
  (via) => chatService.watchMessages(via(currentRoomId.what)),
);
```

* **Automatic Subscription Swapping**: When `currentRoomId` changes, the previous room's stream subscription cancels automatically before the new stream subscription opens.
* **Background Silence**: When the chat screen closes, `roomMessages` deactivates, closing the stream subscription and preventing memory leaks or background network traffic.

### 4.3 Flutter Animation Tickers (`composed.drive` & `WhatVsyncWidget`)

In `package:what_flutter`, frame tickers driven by `composed.drive` or [`WhatVsyncWidget`](../../../what_flutter/lib/src/widgets/framework.dart#L205) synchronize directly with the Flutter display VSYNC pipeline:

```dart
base class PulseIndicator extends WhatWidget {
  const PulseIndicator({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    // 60/120Hz frame ticks execute ONLY while mounted in the active render tree
    return composed.drive<double>(
      (elapsed) => (sin(elapsed.inMilliseconds * 0.005) + 1.0) / 2.0,
      (context, via, value) => Opacity(
        opacity: value,
        child: const Icon(Icons.circle, color: Colors.blue),
      ),
    );
  }
}
```

* **Element-Bound VSYNC**: Tickers are tied directly to the widget's `WhatElement`. When the route navigates away or is obscured in an inactive tab, Flutter's `TickerMode` and What's deactivation hook suspend frame ticking immediately, eliminating phantom battery drain.

### 4.4 Dynamic Branch Pruning & Dead Subgraph Dormancy (`switched`)

When switching between heterogeneous views or algorithms via `switched`:

```dart
final isAdvancedMode = WhatController(false);

final activeDashboard = switched((via) {
  return via(isAdvancedMode.what) ? advancedAnalytics : simpleOverview;
});
```

* **1-Pass Pruning**: When `isAdvancedMode` toggles from `true` to `false`, `_sweepObsoleteEdges` unlinks `advancedAnalytics`.
* **Zero Background Ripples**: `advancedAnalytics` loses its downstream edge and cascades into complete dormancy. Even if its upstream data feeds fluctuate, it executes zero compute turns and consumes zero CPU cycles.

---

## 5. Transient Buffer Retention: Graceful Lifecycle & Mooring

Immediate deactivation upon unmount can introduce undesirable thrashing in fast-moving user interfaces:
* **Route Transitions**: If a user pushes a detail view and navigates back 200ms later, destroying and reconstructing state, network sockets, or video decoders causes visible loading spinners and jank.
* **Hero Animations & Element Reparenting**: During element tree restructuring, an element unmounts from its original position and remounts at the target destination within the same tick.

The What Framework resolves this with a two-tiered **Graceful Lifecycle** architecture ([`Graceful`](../../lib/src/engine/graceful.dart)):

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│               Graceful Deactivation & Mooring Architecture                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Active Subscribers Drop to 0                                                  │
│                │                                                                │
│                ▼                                                                │
│   [_GracefulNodeMixin._detachTargetEdgeOptimistically]                          │
│                │                                                                │
│       ┌────────┴────────────────────────────────────────┐                       │
│       ▼                                                 ▼                       │
│   [Tier 1: Microtask Deferral]             [Tier 2: Time-Based Mooring]         │
│   (Graceful.microtask)                     (Graceful.period(Duration))          │
│   • Defers deactivation by 1 microtask     • Anchors node to _MooringTerminal   │
│   • Coalesces element reparenting          • Pooled _MooringEdge holds edge     │
│   • Zero timer allocations                 • Non-pulling invariant protects CPU │
│       │                                                 │                       │
│       ├────────────────────────┬────────────────────────┤                       │
│       ▼ (Remounted within tick)▼ (Remounted in window)  ▼ (Timeout expires)     │
│   [Cancel Handle: 0ms Reuse]   [Unmoor: 0ms Warm Reuse] [Natural Cascade Teardown]
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Tier 1: Microtask Deferral (`Graceful()` / `Graceful.microtask`)

Implemented via [`_MicrotaskGraceHandle`](../../lib/src/engine/_internal/_graceful.dart#L19) and [`_GracefulSchedulerMixin`](../../lib/src/engine/_internal/_scheduler.dart#L181):
* Defers deactivation until the trailing microtask pass of the current tick.
* If a new consumer attaches before the microtask runs, `_attachTargetEdgeOptimistically` cancels the grace handle immediately:
  $$\Delta \text{Allocations} = 0, \quad \Delta \text{Deactivations} = 0$$
* Prevents teardown churn during Flutter element reparenting and Hero transitions.

### 5.2 Tier 2: Time-Based Mooring (`Graceful.period(Duration)` / `_MooringTerminal`)

For long-lived route transitions, nodes are moored to the global [`_MooringTerminal`](../../lib/src/engine/_internal/_mooring.dart#L43):

1. **Topological Docking**: The node is anchored via a virtual [`_MooringEdge`](../../lib/src/engine/_internal/_mooring.dart#L12), maintaining `_hasTargets == true` so the node remains in `_LifecycleState.running`.
2. **The Non-Pulling Invariant**:  
   ```dart
   // packages/what/lib/src/engine/_internal/_mooring.dart
   @override
   void _invalidate() {
     // Tranquil harbor: strictly drops invalidation ripples without pulling data.
   }
   ```
   While moored, upstream invalidations mark the node dirty, but `_MooringTerminal` **never pulls or computes data**. It consumes zero CPU cycles for unobserved state updates.
3. **$O(1)$ Intrusive Edge Unmooring**: `_MooringTerminal` manages `_MooringEdge` instances through intrusive doubly-linked pointers, achieving $O(1)$ insertion and detachment without lingering heap overhead.
4. **Early Return vs. Expiration**:
   - **Early Return**: If a consumer reconnects before the duration expires, the timer cancels, the mooring edge unmoors, and cached state is delivered with **0ms instant latency**.
   - **Expiration**: If the timer expires without re-entry, `_MooringTerminal.unmoor()` detaches the edge, dropping the subscriber count to zero and triggering synchronous cascading teardown.

---

## 6. Core Engineering Invariants

1. **Zero-Leak Inactive Invariant**:  
   Dormant nodes (`_LifecycleState.inactive`) maintain zero active CPU execution, run zero timers, register zero frame callbacks, and maintain zero open I/O subscriptions.
2. **Topological Demand Invariant**:  
   Node activation is strictly subscriber-driven (`_hasTargets => _targetHead != null`). No node activates spontaneously or eagerly without an active downstream edge.
3. **Recursive Cascade Dormancy Invariant**:  
   Unmounting a terminal detaches its source edges, recursively propagating deactivation up the LPDAG for all upstream nodes whose subscriber counts drop to zero.
4. **Cold I/O Invariant**:  
   Mutating upstream inputs of unobserved asynchronous or managed derivations (`computed.stream`, `managed`) triggers zero network requests, socket handshakes, or resource allocations.
5. **Edge Retention Across Dormancy Invariant**:  
   N-ary nodes detaching from upstreams preserve their internal `_Edge` structures in `_sourceHead`, enabling subsequent re-activations with zero heap allocations.
6. **Non-Pulling Mooring Invariant**:  
   The `_MooringTerminal` holds graph edges purely to prevent premature deactivation; its invalidation handler never pulls or computes unobserved state.

---

## 7. Engineering Conclusions

The **Subscriber-Driven Inactive Dormancy & Pure Lazy Lifecycle** architecture eliminates the chronic resource leakage and boilerplate overhead that plague traditional reactive frameworks:

1. **Zero Manual Cleanup Overhead**: Developers declare resources, streams, and ticker pipelines declaratively without writing manual `dispose()`, `cancel()`, or `close()` logic.
2. **Deterministic Battery & CPU Efficiency**: Background tasks, tickers, and I/O connections are strictly bounded by actual UI observation, guaranteeing zero phantom resource consumption when screens are hidden or unmounted.
3. **Seamless Transient Retention**: Two-tiered Graceful Mooring eliminates route-switching thrashing and element reparenting penalties, providing instant 0ms cache reuse without sacrificing zero-leak invariants.
