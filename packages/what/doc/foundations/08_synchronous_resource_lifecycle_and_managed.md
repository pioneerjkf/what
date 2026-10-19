# Synchronous Resource Lifecycle and Managed Composition Specification
## (Synchronous Resource Lifecycle, Intrusive Teardown Invariants, In-Place Updates, and Orthogonal Reactive Composition)

> **"Synchronization with rendering frame budgets and reactive composition of asynchronous handles: why external resource management (managed) must remain strictly synchronous."**  
> — *What Framework Core Systems Group*

---

## 1. Overview: The Dilemma of External Resource Lifecycles

In production application development, reactive state topologies manage not only pure immutable data, but also **stateful external resources with distinct lifecycles**: UI controllers (`TextEditingController`, `AnimationController`, `ScrollController`), hardware handles (camera, Bluetooth, sensors), database connections, and communication sockets (`WebSocketChannel`, `Socket`).

These external resources demand a rigorous lifecycle contract:
* **Lazy Allocation**: *They must be instantiated only when actively observed by downstream consumers.*
* **Deterministic Teardown**: *They must be deterministically and synchronously disposed when all observers detach.*
* **Zero Resource Leaks**: *Unobserved nodes must maintain zero background CPU usage and zero open handles.*

The What Framework's [`managed`](../../lib/src/what/managed.dart) operator supervises external lifecycles by **enforcing strictly synchronous creation, update, and teardown (`create`, `update`, `dispose`) while excluding asynchronous dispose handlers**. This specification details the physical and mathematical rationale behind this design, the internal engine mechanics of [`_ManagedWhat<T>`](../../lib/src/what/_internal/_managed.dart), and canonical reactive composition patterns for asynchronous resources.

---

## 2. Physical Constraints of UI Rendering Pipelines: Synchronous Teardown

In Flutter and modern GUI frameworks, widget unmounting and tree destruction execute **strictly via synchronous functions**:

```dart
// Standard UI framework lifecycle disposal signature
@override
void dispose() { // Can NEVER be an async function!
  super.dispose();
}
```

### 2.1 Frame Budget Constraints (16ms / 8ms)
When a navigation pop or screen transition occurs, the rendering pipeline operates under strict 60fps (16.6ms) or 120fps (8.3ms) frame deadlines. The rendering engine must unmount old widgets and prepare the layout of the new screen immediately within the active draw call stack.

### 2.2 Destructive Impact of Asynchronous Blocking
If teardown attempted to block or synchronize via `await resource.close()`, the rendering thread would stall:
* Event loop execution blocks, dropping frames and producing severe UI jank.
* If a network socket teardown experiences packet drops or high latency, the UI freezes completely.

### 2.3 Operating System & Driver Delegation
Production controllers (`CameraController`, `VideoPlayerController`, sockets) expose synchronous `dispose()` signatures. Internally, native drivers and OS runtimes delegate physical resource releases to background threads in a fire-and-forget manner. The reactive framework must honor this boundary rather than attempting to introduce artificial asynchronous waiting barriers.

---

## 3. Re-entrancy Race Conditions Induced by Asynchronous Teardown

If resource nodes in the reactive graph accepted asynchronous `Future<void> Function(T) dispose` callbacks and awaited their completion, the topological DAG would experience critical concurrency failures:

```text
Time ──►
[Screen Exit] ──────► Initiate Async Dispose: await resourceA.close() (Takes 300ms)
                            │
                            │ (100ms later) ── User pops back in via rapid navigation!
                            ▼
[Screen Re-enter] ──► _activate(): Allocate New Resource B ???
```

1. **Split-Brain State and Hardware Collisions**:
   Before prior resource A completes its OS/network close, newly created resource B attempts to acquire the same physical port, hardware lock, or memory mapping. This leads to fatal driver crashes, `SocketException: Address already in use`, or hardware access violations.
2. **Deadlocks on Teardown Failures**:
   If resource A's async teardown rejects with an unhandled network error or timeout, the lifecycle state of resource B becomes undefined.

Topological lifecycle boundaries must be demarcated **atomically within synchronous turns** to guarantee system stability.

### Deep Architectural Evaluation: FIFO Asynchronous Queues and Their Rejection

During internal framework R&D, an asynchronous FIFO queue model (serializing async dispose and create tasks in a linear queue) was modeled and evaluated.

While theoretically preventing concurrent collisions, this model introduced four fatal bottlenecks in interactive UI environments:

1. **Head-of-Line Blocking**:
   When a user leaves and re-enters within 100ms, the queue must wait for `await resourceA.close()` (200ms) to finish. The user stares at a frozen loading indicator; **prior screen teardowns directly block subsequent screen activations**.
2. **Queue Stacking Storms**:
   Rapid tab switching cascades unobserved open/close tasks in the queue, stalling the app for seconds.
3. **Collision with Graceful Mooring (0ms Instant Reuse)**:
   For rapid re-entries, preserving the existing instance in 0ms is optimal. An asynchronous queue destroys the instance, making 0ms recovery impossible.
4. **Cascading Failure**:
   An unhandled network exception during `close()` leaves the queue deadlocked.

Consequently, What Framework converged on three definitive lifecycle rules:
* **Teardown is isolated synchronously (Fire-and-forget)**, eliminating frame stalls.
* **Rapid re-entries leverage `Graceful` mooring for 0ms instant reuse**.
* **Asynchronous readiness is composed via `computed.future`**.

---

## 4. Internal Engine Mechanics: `_ManagedWhat<T>`

The lifecycle management engine is implemented in [`_ManagedWhat<T>`](../../lib/src/what/_internal/_managed.dart):

```dart
// packages/what/lib/src/what/_internal/_managed.dart
abstract base class _ManagedWhat<T> extends _NaryRelay<_Node>
    with _WhatViaEpochMixin, _WhatStateMixin<T>, _WhatPeekMixin<T>, _PullResolver<T>, _PullRelay<T>
    implements What<T> { ... }
```

### 4.1 Cold Inactive Invariant (Zero-Leak Dormancy)
When a `managed` node is unobserved (`!_lifecycle.isActive`), it refuses to instantiate the underlying resource:

```dart
// packages/what/lib/src/what/_internal/_managed.dart
@override
@pragma('vm:prefer-inline')
void _resolve() {
  if (_isResolving) {
    throw LpdagCycleError(
      'Cyclic evaluation loop detected in $runtimeType while resolving state.',
    );
  }
  if (!_lifecycle.isActive) {
    _state ??= _EmptyWhatState<T>();
    return;
  }
  super._resolve();
}
```

* Reading `.peek` or `_read()` on an inactive `managed` node returns `_EmptyWhatState<T>()`.
* **The `create` callback is never invoked while dormant**, guaranteeing 0 CPU, 0 allocations, and 0 open handles until an active downstream consumer mounts.

---

### 4.2 Synchronous Deactivation Teardown
When the last downstream consumer detaches (`_deactivate()`), the resource is torn down immediately:

```dart
// packages/what/lib/src/what/_internal/_managed.dart
@mustCallSuper
@override
void _deactivate() {
  _disposeCurrent();
  super._deactivate();
}

void _disposeCurrent() {
  final oldState = _state;
  _state = null;
  _dirtyState = _DirtyState.dirty;
  if (oldState != null && oldState.hasData) {
    try {
      _disposeResource.call(oldState.data);
    } catch (error, stackTrace) {
      _handleUncaughtError(error, stackTrace);
    }
  }
}
```

1. **State Nullification**: `_state = null` and `_dirtyState = _DirtyState.dirty`.
2. **Synchronous Disposal**: `_disposeResource.call(oldState.data)` executes synchronously.
3. **Resilient Exception Handling**: Any exception thrown by external resource disposal is caught and safely dispatched to `_handleUncaughtError` via [`LpdagUncaughtErrorHandler`](../../lib/src/engine/error_handler.dart), preventing crashes in the reactive engine.

---

### 4.3 2-Phase Non-Destructive Invalidation vs. Lazy Pull Disposal
In the 2-Phase LPDAG engine, when an upstream dependency mutates:
1. **Phase 1 (Non-Destructive Dirty Push)**:
   The mutation pushes a dirty pulse downstream (`_markDirty()`). **It does NOT prematurely destroy the existing resource.**
2. **Phase 2 (Lazy Pull Re-creation / Update)**:
   Only when a downstream consumer reads `.data` or `.snapshot` does `_pull()` execute. It disposes the stale resource and creates or updates to the new instance in a single atomic turn.
3. **Thrashing Immunity**:
   If an upstream parameter changes 100 times before anyone reads, intermediate re-creations and disposals are completely bypassed. Only the final settled state triggers disposal and re-creation!

---

## 5. High-Throughput Optimization: Zero-Allocation In-Place Updates (`update`)

Destroying and recreating external resources on every upstream parameter change incurs heavy overhead:
* Driver handle churn, frame drops, and GC pressure.
* Unnecessary widget unmounts due to controller identity changes.

To eliminate this, `managed` provides a built-in **`update: (via, current)` callback**:

```dart
final scrollController = managed(
  create: (via) => ScrollController(
    initialScrollOffset: via(savedOffset.what),
  ),
  update: (via, controller) {
    // Retains existing controller instance; updates properties in-place!
    final targetOffset = via(savedOffset.what);
    if (controller.hasClients) {
      controller.jumpTo(targetOffset);
    }
    return controller; // Returning identical instance skips dispose()!
  },
  dispose: (controller) => controller.dispose(),
);
```

### Internal Update Execution Logic

```dart
// packages/what/lib/src/what/_internal/_managed.dart
final currentState = _state;
if (currentState != null && currentState.hasData && _updateResource != null) {
  final current = currentState.data;
  final next = _updateResource.call(_via, current);
  if (!identical(current, next)) {
    _version++;
    try {
      _disposeResource.call(current); // Dispose old instance only if replaced!
    } catch (error, stackTrace) {
      _handleUncaughtError(error, stackTrace);
    }
  }
  if (currentState case final _ValidWhatState<T> s) {
    s.update(next);
    return _state = s;
  } else {
    return _state = _ValidWhatState(next);
  }
} else {
  _disposeCurrent();
  _version++;
  final res = _createResource.call(_via);
  ...
}
```

| Return Value from `update` | `dispose()` Called on Old Instance? | Reference Identity Preserved? | Version Increment |
| :--- | :--- | :--- | :--- |
| **`identical(current, next)`** | **No** (Disposal bypassed) | **Yes** (Same object instance) | **No** (Suppressed) |
| **`!identical(current, next)`** | **Yes** (Old instance disposed) | **No** (New object instance) | **Yes** (`_version++`) |
| **`update` omitted** | **Yes** (`_disposeCurrent()`) | **No** (Full re-creation) | **Yes** (`_version++`) |

---

## 6. Precondition Gating with `guard` and `reason`

External resources frequently depend on authentication tokens, permissions, or network connectivity. `managed` supports declarative precondition gating:

```dart
final webSocket = managed<WebSocketChannel>(
  guard: (via) => via.state(authToken.what).hasData.guarded('AwaitingAuthToken'),
  create: (via) => WebSocketChannel.connect(
    Uri.parse('wss://api.example.com/feed?token=${via(authToken.what)}'),
  ),
  dispose: (channel) => channel.sink.close(),
);
```

### Invariants:
1. **Allocation Suppression**: While `guard.isPass == false`, `create()` is **never called**. The node emits `EmptyWhatState('AwaitingAuthToken')`.
2. **Deterministic Teardown on Revocation**: If the token transitions to empty or invalid while active, `_disposeCurrent()` executes immediately, closing the open socket before transitioning to `EmptyWhatState`.

---

## 7. Scheduling Policies: Lazy, Eager, and Graceful Mooring

`managed` provides fine-grained scheduling policies matching diverse operational requirements:

```dart
What<T> call<T>({
  WhatGuard Function(WhatVia via)? guard,
  required T Function(WhatVia via) create,
  T Function(WhatVia via, T current)? update,
  required void Function(T resource) dispose,
  bool eager = false,
  Graceful? graceful,
});
```

### 7.1 Lazy (`eager: false`, Default)
* Resource allocation and updates are deferred until a downstream consumer reads `.data` or `.snapshot`.
* Avoids allocating resources for unrendered tabs or off-screen components.

### 7.2 Eager (`eager: true`)
* Backed by [`_EagerManagedWhat<T>`](../../lib/src/what/_internal/_managed.dart#L157).
* Resolves immediately upon terminal activation.
* When upstream dependencies mutate while active, it automatically microtask-schedules updates via `_Scheduler.instance._scheduleEager(this)`.
* On deactivation, pending microtask evaluations are purged via `_Scheduler.instance._cancelEager(this)`.

### 7.3 Graceful Mooring (`graceful: Graceful`)
* Backed by [`_GracefulNodeMixin`](../../lib/src/engine/_internal/_graceful.dart).
* When downstream subscribers drop to zero (e.g., during screen pop/push transitions or page swiping), deallocation is buffered for a microtask or a duration (`graceful.period(Duration(milliseconds: 300))`).
* **0ms Instant Reuse**: If a subscriber reconnects within the mooring window, the existing instance is reused immediately with zero teardown and zero re-allocation.

---

## 8. Canonical Architecture: Single Responsibility Principle (SRP) and Reactive Composition

The cleanest pattern for asynchronous resources is to avoid monolithic God nodes and instead **compose two single-responsibility reactive nodes orthogonally**:

* **`managed`**: Oversees the pure instance **lifecycle (allocation and synchronous disposal)**.
* **`computed.future` / `stream`**: Tracks the resource's **asynchronous readiness (initialization, error handling, completion)**.

### Production Example: Hardware Resource Requiring Asynchronous Initialization

```dart
// 1. Instance Lifecycle Management: Instantiates on subscription; disposes on detachment
final cameraInstance = managed(
  create: (via) => CameraController(via(selectedCamera.what)),
  dispose: (camera) {
    // Synchronous disposal delegating async work to the background (Fire-and-Forget)
    unawaited(camera.dispose());
  },
);

// 2. Asynchronous Readiness Pipeline: Observes camera.initialize() completion
final cameraReady = computed.future((via) async {
  final camera = via(cameraInstance);
  await camera.initialize();
  return camera; // Fully initialized camera handle
});
```

### Architectural Benefits:
1. **State Transparency**:
   The presentation layer queries `cameraReady.snapshot` to distinguish `isEmpty` (initial loading indicator), `hasError` (permission denied), and `hasData` (preview feed).
2. **Zero Resource Leaks**:
   When the screen unmounts, `cameraInstance` triggers `dispose` immediately, releasing hardware handles.
3. **Race-Condition Free**:
   If the screen unmounts during initialization, `_FutureWhatBridge` severs the topological edge, preventing stale completion callbacks from corrupting UI state.

---

## 9. Engineering Conclusions

1. **Synchronous Teardown Invariant**:  
   `managed` enforces strictly synchronous `dispose` signatures, conforming to GUI rendering frame budgets (16ms/8ms) and preventing asynchronous split-brain re-entrancy bugs.
2. **Dual-Phase Non-Destructive Invalidation**:  
   Dirty propagation does not prematurely destroy external resources. Allocation and disposal occur atomically on demand upon downstream consumer read.
3. **Zero-Allocation In-Place Updates (`update`)**:  
   Returning the same instance from `update: (via, current)` updates properties in-place, bypassing disposal and recreation, eliminating widget rebinds and GC overhead.
4. **Cold Inactive Dormancy**:  
   Unobserved nodes maintain zero open handles and refuse to allocate resources until downstream observers activate.
5. **Orthogonal Reactive Composition**:  
   Separating instance lifecycles ([`managed`](../../lib/src/what/managed.dart)) from asynchronous readiness pipelines ([`computed.future`](../../lib/src/what/computed.dart)) achieves mathematically sound, leak-free external resource management.
