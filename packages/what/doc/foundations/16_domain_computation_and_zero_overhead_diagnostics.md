# Object-Oriented Domain Computation & Zero-Overhead Reactive Diagnostics Specification
## (Object-Oriented Domain Computation & Zero-Overhead Reactive Diagnostics)

> **"As software scales, inline closures fragment domain logic, while runtime diagnostics compromise release performance. An enterprise reactive system must satisfy object-oriented encapsulation and zero-overhead release diagnostics simultaneously."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: Two Practical Challenges in Enterprise Architectures

While What's 2-Phase LPDAG delivers high performance, enterprise codebases with dozens of engineers encounter two distinct challenges:

1. **Closure Sprawl in Complex Business Domains**:
   Authoring multi-step domain rules (pricing calculations, insurance underwriting, financial models) within inline `computed((via) => ...)` lambdas compromises readability, prevents private helper reuse, and complicates unit testing. Furthermore, developers often instantiate hardware sensors (GPS, accelerometers) or stream connections directly in constructors, draining battery when unrendered.
2. **The Observability Tax**:
   As Directed Acyclic Graphs grow complex, diagnosing why a node rebuilt or identifying which widget holds a node active becomes difficult. Conversely, attaching debug metadata (names, creation stack traces) directly as instance fields inflates object sizes across tens of thousands of nodes in release builds, triggering GC pauses and memory bloat.

The What Framework resolves these challenges through **Class-Based Domain Components ([Computation<T>](../../lib/src/what/computed.dart), [WhatLifecycleAware](../../lib/src/what/computed.dart))** and an `Expando`-backed **Zero-Overhead Diagnostic Ecosystem ([WhatDebug](../../lib/src/engine/debug.dart))**.

---

## 2. Class-Based Domain Components: `Computation<T>`

While inline `computed` lambdas are optimal for concise derivations, [Computation<T>](../../lib/src/what/computed.dart) encapsulates complex domain pipelines into single-responsibility, object-oriented classes:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Computation<T> Component Flow                        │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   class OrderPricingComputation extends Computation<OrderPricing>      │
│   - Encapsulated dependencies (cart, user, promoCode)                  │
│   - Private domain helper methods (_applyPromo, _calculateTax)         │
│   - Precondition guard() returning WhatGuard                           │
│                                                                        │
│   [ Downstream Pull (.data / .snapshot / terminal evaluation) ]       │
│                   │                                                    │
│                   ▼                                                    │
│         [ guard(via).isPass? ]                                         │
│        ├── No  ──► Emits Empty(decision.reason) (compute Bypassed)     │
│        └── Yes ──► Invokes compute(via) with 1-Pass Epoch Sweeping     │
│                         │                                              │
│                         ▼                                              │
│               Returns Fresh [T] Payload (0-Compute on cache hit)       │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Comparison with Inline `computed`

| Characteristic | `computed((via) => ...)` | `Computation<T>` Class |
| :--- | :--- | :--- |
| **Authoring Paradigm** | Inline lambda closure | **Object-oriented domain component class** |
| **Dependency Tracking**| Explicit via `via(node)` / `via.state(node)` | **Explicit via `via(node)` / `via.state(node)`** |
| **Dynamic Branching** | Supported (1-pass Epoch Sweeping) | **Supported (1-pass Epoch Sweeping)** |
| **Private Helper Functions** | Nested closures or global utilities | **Encapsulated instance methods and state** |
| **Precondition Guarding** | Optional `guard:` constructor callback | **Constructor `super(guard: ...)` or overridable `guard(WhatVia via)`** |
| **Lifecycle Hooks** | Requires composition with `managed` | **Direct mixin integration via [WhatLifecycleAware]** |
| **State Inspection Ergonomics** | Returns [What<T>]; requires `untracked(what)` or `untracked.state(what)` outside tracking | **Direct dereference on component (`.data`, `.snapshot`, `.hasData`, `.emptyReason`)** |
| **DAG Integration** | Pass node directly to `via(node)` | **Pass underlying topological handle via [what] (`via(comp.what)`)** |
| **Diagnostics & Labeling** | [withDebugLabel], [debugTrace], `node.debug` | **[withDebugLabel], [debugTrace], and direct [debug] inspection** |

### 2.2 Production Implementation Pattern

[Computation<T>](../../lib/src/what/computed.dart) mixes in `_WhatStateMixin<T>` and implements [WhatState<T>](../../lib/src/what/state.dart), allowing external callers and UI widgets to query its state directly without unwrapping. At the same time, it exposes [what](../../lib/src/what/computed.dart) for reactive upstream registration:

```dart
base class OrderPricingComputation extends Computation<OrderPricing> {
  OrderPricingComputation(this.cart, this.user, this.promoCode);

  final What<Cart> cart;
  final What<User> user;
  final What<PromoCode?> promoCode;

  // 1. Precondition Guard: Computes only when cart has items and user profile is loaded
  @override
  WhatGuard guard(WhatVia via) {
    if (via.state(cart).isEmpty || via(cart).items.isEmpty) {
      return WhatGuard.block('Cart is empty.');
    }
    if (via.state(user).isEmpty) {
      return WhatGuard.block('Loading user profile...');
    }
    return WhatGuard.pass;
  }

  // 2. Pure Calculation Pipeline
  @override
  OrderPricing compute(WhatVia via) {
    final items = via(cart).items;
    final subtotal = _calculateSubtotal(items);
    final discount = _applyPromo(subtotal, via.state(promoCode).dataOrNull);
    final tax = _calculateTax(subtotal - discount, via(user).address);
    return OrderPricing(subtotal: subtotal, discount: discount, tax: tax);
  }

  // 3. Encapsulated Domain Helpers
  double _calculateSubtotal(List<CartItem> items) =>
      items.fold(0.0, (acc, item) => acc + item.price * item.quantity);

  double _applyPromo(double subtotal, PromoCode? promo) {
    if (promo == null) return 0.0;
    return promo.percentage != null ? subtotal * promo.percentage! : promo.fixedDiscount ?? 0.0;
  }

  double _calculateTax(double taxable, Address addr) => taxable * addr.taxRate;
}
```

#### Dual Consumption Symmetry
* **Direct Inspection (Imperative & UI Guards)**:
  ```dart
  final pricing = OrderPricingComputation(cartWhat, userWhat, promoWhat);
  
  // Direct state dereferencing without .what or untracked.state
  if (pricing.hasData) {
    print('Total: ${pricing.data.total}');
  } else if (pricing.isEmpty) {
    print('Blocked: ${pricing.emptyReason}');
  }
  ```
* **Topological Integration (Reactive DAGs & Flutter Widgets)**:
  ```dart
  // Inside another computed or Effect:
  final finalInvoice = computed((via) => formatInvoice(via(pricing.what)));

  // Inside Flutter UI:
  WhatWidget(
    pricing.what,
    (via) => Text(pricing.hasData ? '\$${pricing.data.total}' : '${pricing.emptyReason}'),
  );
  ```

---

## 3. Downstream-Driven Lifecycle Interception: `WhatLifecycleAware`

When managing sensors, socket connections, or polling workers, starting background operations inside constructors leaks battery and memory when components are instantiated but never rendered or observed.

The [WhatLifecycleAware](../../lib/src/what/computed.dart) mixin intercepts active subscriber transitions ($0 \to 1$ and $1 \to 0$), enabling lazy activation and deterministic teardown driven strictly by downstream demand:

```text
[Downstream Terminal (WhatWidget / RawWhatTerminal)]
       │ (0 -> 1 active subscribers: terminal.activate())
       ▼
[WhatLifecycleAware Computation Node]
       │ ──► didActivate(): Allocates resource / initializes hardware sensor
       │
       ... (Active Observation Phase: 60/120fps reactive evaluation) ...
       │
       ▼ (1 -> 0 active subscribers: terminal.deactivate())
[WhatLifecycleAware Computation Node]
       │ ──► didDeactivate(): Shuts down sensor / cancels subscription
```

### 3.1 Production Lifecycle Implementation

```dart
base class LocationTrackingComputation extends Computation<GpsCoordinates> with WhatLifecycleAware {
  LocationTrackingComputation(this.gpsService);

  final GpsService gpsService;
  StreamSubscription<GpsCoordinates>? _subscription;
  final _coordinates = WhatController<GpsCoordinates>.empty('AwaitingGpsFix');

  @override
  void didActivate() {
    super.didActivate();
    // Warm up GPS hardware only when an active consumer mounts and subscribes
    _subscription = gpsService.locationStream.listen(
      (coords) => _coordinates.data = coords,
      onError: (err, st) => _coordinates.setError(err, st),
    );
  }

  @override
  void didDeactivate() {
    super.didDeactivate();
    // Terminate GPS hardware immediately when all consumers unmount
    _subscription?.cancel();
    _subscription = null;
    _coordinates.empty('GpsSensorDormant');
  }

  @override
  GpsCoordinates compute(WhatVia via) => via(_coordinates.what);
}
```

* **Exception Isolation**: In `_LifecycleAwareComputationWhat`, invocations of `didActivate()` and `didDeactivate()` are safely enclosed in `try-catch` blocks and dispatched to `_handleUncaughtError`, guaranteeing that subscriber lifecycle errors never corrupt the core topological graph.
* **Exact Transition Boundaries**: Activation hooks trigger strictly when the active downstream subscriber edge count transitions from $0 \to 1$. Adding additional downstream consumers ($1 \to 2$) does not trigger redundant activations; similarly, deactivation triggers only when total consumers drop to zero ($1 \to 0$).

---

## 4. Dart VM Zero-Overhead Diagnostics (`WhatDebug`)

Attaching debug labels, allocation metadata, and creation stack traces to node instances permanently inflates object memory. In large-scale apps with tens of thousands of reactive nodes, instance field bloat induces severe GC latency and increases heap pressure.

What resolves this by combining **Dart VM `assert` tree-shaking** with **[Expando](../../lib/src/engine/_internal/_debug.dart)** tables, achieving **zero memory overhead in release builds**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Zero-Overhead Diagnostic Architecture                │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Release / Profile Mode Build (assert disabled) ]                   │
│   • Node Object Size: Minimal fields only (_targetHead, _version, etc.)│
│   • Debug Extensions: Stripped completely by Dart Compiler / Tree-Shake │
│   • GC Footprint: Exactly 0 extra bytes!                               │
│                                                                        │
│   [ Debug Mode Build (assert enabled) ]                                │
│   • Assert-guarded Expando mapping: Node ──► Stored Externally         │
│   • WhatDebug.snapshot(): Captures real-time DAG topology & 3-state    │
│   • debugForceInvalidate(): Recursively invalidates cache on Hot Reload│
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Weak-Referenced Metadata and Inspection Snapshots

Debug labels and creation stack traces are stored externally in global `Expando` hash tables (`_debugLabels` and `_debugLocations`). Because `Expando` maintains weak references to keys, disposing or dropping references to a reactive node or terminal allows the Dart VM Garbage Collector to reclaim all associated debug metadata immediately.

```dart
// 1. Attach debug labels in debug mode (Assert-guarded, No-op in release mode)
final counter = WhatController(0).withDebugLabel('DashboardCounter');
final pricing = OrderPricingComputation(cartWhat, userWhat, promoWhat)
    .withDebugLabel('PricingComponent');

// 2. Direct inspection on Computation or What
final compSnapshot = pricing.debug.snapshot();
print(compSnapshot.name);         // "PricingComponent"
print(compSnapshot.isActive);     // false (No active terminal attached yet)
print(compSnapshot.targetCount);  // 0 (Connected downstream edges)

// 3. Connect a terminal to observe lifecycle transition
final terminal = RawWhatTerminal(pricing.what, onInvalidated: () {})..activate();

final activeSnapshot = pricing.debug.snapshot();
print(activeSnapshot.isActive);    // true
print(activeSnapshot.targetCount); // 1
print(activeSnapshot.hasData);     // true
print(activeSnapshot.description); // "<payload> (v1)"

terminal.deactivate();
```

### 4.2 Comprehensive Diagnostic Surface

The What diagnostic ecosystem provides targeted zero-overhead extensions across all major abstractions:

| Target Type | Debug Extension | Available Capabilities |
| :--- | :--- | :--- |
| **`What<T>`** | [WhatDebugExtension](../../lib/src/engine/debug.dart) | `.debug` ([WhatDebug]), `.debugLabel`, `.withDebugLabel()`, `.debugTrace()`, `.debugVersion`, `.debugSourceCount` |
| **`Computation<T>`** | [ComputationDebugExtension](../../lib/src/engine/debug.dart) | `.debug` ([WhatDebug]), `.debugLabel`, `.withDebugLabel()`, `.debugTrace()` |
| **`WhatController<T>`** | [WhatControllerDebugExtension](../../lib/src/engine/debug.dart) | `.debugLabel`, `.withDebugLabel()`, `.debugTrace()` (synchronizes label to underlying `what`) |
| **`WhatSignalController`** | [WhatSignalControllerDebugExtension](../../lib/src/engine/debug.dart) | `.debugLabel`, `.withDebugLabel()`, `.debugTrace()` |
| **`WhatCoupler<T>`** | [WhatCouplerDebugExtension](../../lib/src/engine/debug.dart) | `.debug` ([WhatDebug]), `.debugLabel`, `.withDebugLabel()`, `.debugTrace()`, `.debugVersion` |
| **`RawTerminal`** | [RawTerminalDebugExtension](../../lib/src/engine/debug.dart) | `.debugLabel`, `.withDebugLabel()`, `.debugTrace()`, `.debugDependencies`, `.debugTethers` |
| **`Tether` / `Effect`** | [TetherDebugExtension](../../lib/src/engine/debug.dart), [EffectDebugExtension](../../lib/src/engine/debug.dart) | `.debugLabel`, `.withDebugLabel()`, `.debugTrace()`, `.debugDependencies` |

* **[WhatDebugSnapshot](../../lib/src/engine/debug.dart)**: An immutable value object capturing a complete instant state snapshot:
  - `name`: Assigned debug label, falling back to runtime class type.
  - `version`: Internal DAG mutation version counter.
  - `isActive` & `targetCount`: Live topological connection indicators.
  - `hasData`, `hasError`, `isEmpty`, `data`, `error`, `emptyReason`: 3-state algebraic status.
  - `customProperties`: Type-specific diagnostics (e.g., `needsSwitch` and `activeSource` for `switched`, `hasResource` for `managed`, `isPending` for `retained`).

---

## 5. Flutter Hot Reload Cache Invalidation Harness: `debugForceInvalidate()`

During Flutter development, modifying calculation formulas inside a `computed` closure or `Computation.compute()` often leads to confusion if the screen continues displaying stale memoized values after a Hot Reload.

What's terminal interface ([RawTerminal](../../lib/src/engine/terminal.dart)) standardizes a dedicated recovery hook for the hot reload lifecycle:

```dart
// packages/what/lib/src/engine/terminal.dart
abstract interface class RawTerminal implements LpdagStatus {
  ...
  /// Debug & Hot-Reload hook that recursively invalidates upstream intermediate caches
  /// and bumps root dirty versions to force fresh recomputations across the DAG.
  ///
  /// Intended to be invoked inside Flutter Element's `reassemble()` hook during
  /// development Hot Reload cycles.
  void debugForceInvalidate();
}
```

### 5.1 Operational Mechanics

```text
[Flutter Hot Reload triggers Element.reassemble()]
       │
       ▼ (Assert-guarded, 0 cost in Release)
[activeTerminal.debugForceInvalidate()]
       │
       ▼ Recursively walks upstream topological DAG with Set<_Node> visited cycle protection
┌────────────────────────────────────────────────────────────────────────┐
│                      Cache Invalidation Traversal                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Upstream Traversal: Unary, N-ary, and Delta edge traversal          │
│ 2. Intermediate Computed Nodes (_PullRelay, _ComputedWhatBase, etc.):   │
│    • _dirtyState = _dirty                                              │
│    • _state = null / _cachedState = null (Clears memoized payload)     │
│ 3. Push Roots / Origin Entries (_Entry):                               │
│    • _dirtyVersion++ (Forces downstream version comparison checks)     │
└────────────────────────────────────────────────────────────────────────┘
       │
       ▼
[Next Screen Frame Render / Pull Phase]
Re-evaluates fresh computation closures with modified code in 0ms!
```

* **Zero-Release Overhead**: In `_Terminal`, `debugForceInvalidate()` is wrapped directly in an `assert`:
  ```dart
  @override
  void debugForceInvalidate() {
    assert(() {
      _debugForceInvalidateInternal(<_Node>{});
      return true;
    }());
  }
  ```
  In release and profile builds, this hook compiles into an absolute no-op without running the graph traversal.
* **Flutter Element Integration**: What's Flutter widgets (`WhatWidget`, `WhatListener`, `_ViaTerminalElementMixin`) hook into `Element.reassemble()` to automatically trigger `terminal.debugForceInvalidate()` during Flutter Hot Reload.

---

## 6. Core Engineering Invariants

1. **Zero-Release Overhead Invariant**:
   All debug metadata storage (`Expando`), creation stack trace capturing, and `debugForceInvalidate()` traversals are strictly assert-gated. In release and profile builds, assertions are tree-shaken by the Dart compiler, resulting in exactly 0 extra heap allocations, 0 field bloat on nodes, and 0 runtime CPU penalty.
2. **Weak-Key GC Isolation Invariant**:
   All diagnostic metadata is stored in `Expando` hash tables. Diagnostic registries never hold strong references to reactive nodes, ensuring nodes are immediately collected by the Dart VM GC when application references drop.
3. **Reverse Subscriber Lifecycle Invariant**:
   `WhatLifecycleAware.didActivate()` and `didDeactivate()` fire strictly and deterministically on active subscriber boundary transitions ($0 \to 1$ and $1 \to 0$). Intermediate subscription churn ($1 \to 2$ or $2 \to 1$) never triggers redundant activations or deactivations.
4. **Precondition Gating & Error Containment Invariant**:
   When `Computation.guard()` evaluates to `isBlock`, `compute()` is strictly bypassed and the node transitions into `WhatState.isEmpty` with `emptyReason`. Uncaught exceptions thrown inside `guard()` or `compute()` are isolated into `WhatState.hasError` via `_WhatState.fromCaught()`, preserving DAG topological consistency and allowing self-healing when inputs update.
5. **Hot-Reload Cache Coherency Invariant**:
   Invoking `debugForceInvalidate()` recursively sweeps up the DAG, clearing cached states (`_state = null`, `_dirtyState = _dirty`) and incrementing root dirty versions (`_dirtyVersion++`), ensuring that hot reload re-evaluates updated business closures immediately without desynchronization.

---

## 7. Engineering Conclusions

**Object-Oriented Domain Computation ([Computation](../../lib/src/what/computed.dart))** and **Zero-Overhead Diagnostics ([WhatDebug](../../lib/src/engine/debug.dart))** elevate What beyond a simple reactive store into a comprehensive domain modeling framework.

Engineers encapsulate complex business rules into modular classes, enjoy real-time DAG inspection and hot reload resilience in development, and deploy with maximum native efficiency in production.
