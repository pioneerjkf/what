# Graceful Lifecycle & Mooring: Zero-Thrashing Transient Retention Specification
## (Graceful Lifecycle & Mooring: Zero-Thrashing Transient Retention, Intrusive Edge Pooling, and Scheduler Prioritization)

> **"During the brief intervals when a user navigates between tabs or triggers screen transitions, destroying expensive WebSockets and query caches only to rebuild them 16ms later induces severe resource churn, unnecessary I/O pressure, and cache thrashing. Mooring is the topological anchor that preserves reactive continuity."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: Transient Unmounts and Subscription Thrashing

In the widget hierarchies of modern GUI applications (Flutter, React, etc.), transient screen transitions happen constantly:

1. **Bottom Navigation Tab Switching**: Moving between tabs temporarily unmounts inactive tab subtrees.
2. **Page Route Push / Pop**: Pushing routes or executing back gestures renders prior routes inactive for hundreds of milliseconds before returning.
3. **Subtree Reparenting & Hero Transitions**: Elements detach from one layout node and re-attach to another during animated transitions.

Traditional pure lazy reactive systems terminate upstream connections immediately when consumer counts reach zero (`!_hasTargets`). This causes **subscription thrashing**:

```text
[Tab Switch Out: t = 0ms] ────> Subscriber count drops to 0
                                 │
                                 ▼ (Aggressive Teardown)
                                WebSocket Closed, In-flight Requests Aborted, Cache Dropped!
                                 │
[Tab Switch In:  t = 300ms] ───> Subscriber count returns to 1
                                 │
                                 ▼ (Re-instantiation)
                                Handshake reopened, Cache re-fetched, Layout Jank / Spinner!
```

Aggressive instant teardown wastes bandwidth, increases backend strain, triggers UI layout flash, and drops rendering frames.

To reconcile pure lazy dormancy with seamless user navigation, the What Framework introduces **Graceful Mooring**.

---

## 2. The Mooring Architecture: Topological Anchoring via `_MooringTerminal`

Mooring anchors unobserved reactive nodes to an internal virtual terminal ([`_MooringTerminal`](../../lib/src/engine/_internal/_mooring.dart)) when subscriber counts temporarily hit zero, keeping upstream pipelines active:

```text
┌────────────────────────────────────────────────────────────────────────┐
│              Graceful Mooring Topology Architecture                    │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [Normal Active State]                                                │
│   Upstream Pipeline ──► Target What ──► [UI Widget Elements]           │
│                                                                        │
│   [Transient Unmount Event: Active Subscribers -> 0]                   │
│   Upstream Pipeline ──► Target What ──► [_MooringTerminal (Anchor)]    │
│                                               │ (Holds _MooringEdge)   │
│                                               ▼ (Grace Period Timer)   │
│                                         [Grace Window: e.g. 500ms]     │
│                                                                        │
│   [Scenario A: Remounted within 500ms]                                 │
│   Target What reused seamlessly! Zero-cost reconnect, 0 I/O refetch.   │
│                                                                        │
│   [Scenario B: Grace period elapsed]                                   │
│   Timer expires -> _MooringTerminal detaches -> Clean Inactive Dormancy│
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 The Tranquil Harbor (`_MooringTerminal`)
Unlike ordinary consumer terminals that pull data and trigger UI rebuilds, [`_MooringTerminal`](../../lib/src/engine/_internal/_mooring.dart#L43) is a tranquil harbor: it holds topological edges purely to prevent upstream lifecycles from sinking into dormant deactivation.

```dart
// packages/what/lib/src/engine/_internal/_mooring.dart
final class _MooringTerminal extends _Terminal {
  _MooringTerminal._();
  static final _MooringTerminal instance = _MooringTerminal._();

  _MooringEdge? _mooringHead;

  @override
  void _invalidate() {
    // Tranquil harbor: strictly drops all invalidation ripples without pulling data.
  }
  ...
}
```

#### Non-Pulling Invariant
`_MooringTerminal._invalidate()` is strictly a no-op. It never eagerly evaluates or pulls data, avoiding redundant CPU consumption while moored.

#### Pure LPDAG Dynamic Dormancy
`_MooringTerminal` activates only when one or more nodes are actively moored (`wasEmpty -> _activateOptimistically()`). When all moored edges detach (`_mooringHead == null`), it deactivates back into dormancy (`_deactivateOptimistically()`).

---

### 2.2 Intrusive Edge Management (`_MooringEdge`)
`_MooringTerminal` manages lightweight intrusive [`_MooringEdge`](../../lib/src/engine/_internal/_mooring.dart#L12) instances:
* When a node enters period grace, `moor(node, duration)` instantiates a lightweight `_MooringEdge` and prepends it to `_mooringHead` via intrusive pointers (`_prevMooring`, `_nextMooring`) in $O(1)$.
* When unmoored or expired, the edge is unlinked in $O(1)$ and released for instant minor GC collection.
* **Ephemeral Short-Lived Scavenging**: Without object pooling overhead, short-lived edges evaporate cleanly in Dart's generational new space without promotion to old generation.

---

## 3. Grace Policy Modalities: Microtask Deferral vs. Time-Based Mooring

The What Framework provides two distinct grace policy implementations matching different temporal scopes:

```text
                     ┌────────────────────────────────────────┐
                     │          Graceful Policy DSL           │
                     └────────────────────────────────────────┘
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  ▼                                               ▼
     [Graceful.microtask / Graceful()]              [Graceful.period(Duration)]
     • Single microtask tick buffer                 • Bounded time-window retention
     • Zero edge allocations (No Timer)             • Anchors via _MooringTerminal
     • Coalesces Flutter frame reparenting          • Retains cache across route navigation
```

### 3.1 Microtask Deferral (`Graceful.microtask` / `Graceful()`)
* **Underlying Engine**: Backed by [`_MicrotaskGraceHandle`](../../lib/src/engine/_internal/_graceful.dart#L19) and [`_Scheduler`](../../lib/src/engine/_internal/_scheduler.dart).
* **Zero-Allocation Optimization**: It does **not** allocate `_MooringEdge` objects or Dart `Timer` handles. It registers directly in `_Scheduler.instance._scheduleGraceHandle(this)`.
* **Application**: Perfect for Flutter widget tree rebuilding, `Hero` transitions, and list element reparenting occurring within the same event loop tick.

### 3.2 Time-Based Mooring (`Graceful.period(Duration)`)
* **Underlying Engine**: Backed by [`_PeriodGraceHandle`](../../lib/src/engine/_internal/_mooring.dart#L114) and `_MooringTerminal`.
* **Application**: Multi-second retention for screen navigation (bottom navigation bars, master-detail transitions, tab pages).
* **Stream In-Flight Continuity**: WebSockets and broadcast streams remain connected; events arriving while unobserved are buffered and available instantly upon remount.

### 3.3 Factory Constructors and Named Constants

```dart
// 1. Direct Default Microtask Deferral (Constant or Constructor):
final formState = managed(
  create: (via) => FormValidator(),
  dispose: (v) => v.dispose(),
  graceful: Graceful.microtask, // or const Graceful()
);

// 2. Time-Based Mooring Window (Explicit .period):
final userProfile = computed.future(
  (via) => fetchProfile(via(userId.what)),
).graceful(const Graceful.period(Duration(seconds: 30)));

// 3. WhatController Direct Attachment:
final counter = WhatController(
  0,
  graceful: const Graceful.period(Duration(minutes: 5)),
);

// 4. Stream Extension Mooring:
final feedWhat = socketStream.toWhat(
  initialFactory: () => const <Message>[],
  graceful: const Graceful.period(Duration(seconds: 15)),
);
```

---

## 4. Topological Mechanics: `_GracefulNodeMixin`

Nodes with graceful support mix in [`_GracefulNodeMixin`](../../lib/src/engine/_internal/_graceful.dart#L77):

```dart
// packages/what/lib/src/engine/_internal/_graceful.dart
base mixin _GracefulNodeMixin on _Node {
  Graceful get _graceful;
  _GraceHandle? _graceHandle;

  @mustCallSuper
  @override
  void _attachTargetEdgeOptimistically(_TargetEdge target) {
    super._attachTargetEdgeOptimistically(target);
    if (_graceHandle case final handle?) {
      _graceHandle = null;
      handle.cancel(); // Early reconnect cancels grace period!
    }
  }

  @mustCallSuper
  @override
  void _detachTargetEdgeOptimistically(_TargetEdge target) {
    if (target is! _MooringEdge &&
        _graceHandle == null &&
        identical(_targetHead, target) &&
        target._nextTarget == null) {
      _graceHandle = _graceful._enterGrace(this); // Pre-detach mooring!
    }
    super._detachTargetEdgeOptimistically(target);
  }

  @mustCallSuper
  @override
  void _deactivateOptimistically() {
    if (_graceHandle != null) return; // Intercepts and aborts premature deactivation!
    super._deactivateOptimistically();
  }
}
```

### 4.1 Pre-Detach Mooring Sequence
When the last active subscriber detaches:
1. `_detachTargetEdgeOptimistically(target)` checks `identical(_targetHead, target) && target._nextTarget == null`.
2. Before detaching `target`, it calls `_graceful._enterGrace(this)`.
3. For period grace, `_MooringTerminal.instance.moor(node, duration)` links `_MooringEdge` to the node **before** the old target unlinks.
4. When `super._detachTargetEdgeOptimistically(target)` executes, `_hasTargets` remains `true` because `_MooringEdge` is connected. The node **never sinks into deactivation**.
5. For microtask grace, `_graceHandle` intercepts `_deactivateOptimistically()`, aborting deactivation during the active frame.

---

### 4.2 0ms Instant Reuse (Early Reconnect)
If a new subscriber attaches before the grace period expires:
1. `_attachTargetEdgeOptimistically(newTarget)` runs.
2. `handle.cancel()` executes:
   - For period grace: cancels the running `Timer`, detaches and releases `_MooringEdge`.
   - For microtask grace: removes the handle from `_Scheduler`.
3. **Zero Latency**: State is rendered in **0 nanoseconds** without re-fetching, re-connecting, or rebuilding controllers.

---

### 4.3 Clean Expiration (Grace Window Elapsed)
If no subscriber reconnects before expiration:
1. For period grace: `_PeriodGraceHandle._onExpired()` unmoors `_MooringEdge`. `node._detachTargetEdgeOptimistically(edge)` runs. With 0 subscribers remaining, `node._deactivateOptimistically()` executes cleanly.
2. For microtask grace: `_Scheduler` executes `_MicrotaskGraceHandle._onExpired()` at the tail of the tick, triggering natural deactivation.
3. Upstream pipelines cascade into true inactive dormancy with zero lingering timers or memory leaks.

---

## 5. Scheduler Prioritization & Mixin Linearization

In [`_Scheduler`](../../lib/src/engine/_internal/_scheduler.dart), mixin linearization dictates the exact order of batch microtask passes:

```dart
// packages/what/lib/src/engine/_internal/_scheduler.dart
base class _Scheduler extends _SchedulerBase
    with
        _CoalescedSchedulerMixin, // 1. Flush trailing coalesced dirty pulses
        _EagerSchedulerMixin,     // 2. Preemptive eager branch switching
        _TerminalSchedulerMixin,  // 3. Execute active terminals (Effects)
        _GracefulSchedulerMixin   // 4. Deactivation cleanup (Strictly LAST!)
```

### Why Graceful Deactivation MUST Run Last
Even if subscriber counts drop to zero during an active tick, **active effects running in that same tick may still observe or depend on resources whose subscribers dropped to zero during this epoch.**

If deactivation ran before effect execution:
* Executing effects would encounter destroyed connections or disposed controllers, throwing `StateError` anomalies.
* By scheduling [`_GracefulSchedulerMixin`](../../lib/src/engine/_internal/_scheduler.dart#L181) strictly at the tail of the scheduler loop, all side-effects and reads complete safely against coherent state before deallocations commence.

---

## 6. Engineering Conclusions

1. **Zero-Thrashing Invariant**:  
   Transient screen navigation and widget reparenting occurring within the grace window never trigger destructive `dispose()` or network disconnection cycles.
2. **0ms Instant Reuse**:  
   Early reconnects restore active UI rendering with zero network delay, zero re-fetching, and zero loading spinners.
3. **Tranquil Harbor (`_MooringTerminal`)**:  
   The nominal mooring terminal holds topological edges without pulling data or triggering recomputations, maintaining pure passive anchoring.
4. **Intrusive $O(1)$ Edge Management**:  
   `_MooringEdge` instances utilize intrusive linked-list pointers, achieving $O(1)$ insertion and detachment without long-term heap retention or old-gen promotion.
5. **Scheduler Order Invariant**:  
   Within `_Scheduler`, graceful deactivations execute strictly after all active effects and terminals settle, guaranteeing exception-free lifecycle transitions.
