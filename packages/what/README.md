<p align="center">
  <img src="https://raw.githubusercontent.com/pioneerjkf/what/main/packages/what/assets/what_core_banner_dark.svg" alt=".what — 2-Phase LPDAG Reactive State Engine" width="100%" />
</p>

<h1 align="center">What</h1>

<p align="center">
  <strong>High-Performance, Glitch-Free 2-Phase LPDAG Reactive State & Computation Engine for Dart</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/what"><img src="https://img.shields.io/pub/v/what.svg?style=flat-square" alt="Pub Version" /></a>
  <a href="https://pub.dev/packages/what/score"><img src="https://img.shields.io/pub/points/what.svg?style=flat-square" alt="Pub Points" /></a>
  <a href="https://github.com/pioneerjkf/what/blob/main/packages/what/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=flat-square" alt="License" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.6+-0175C2.svg?style=flat-square&logo=dart" alt="Dart SDK" /></a>
</p>

---

## Overview

**What** is a high-performance reactive state engine engineered for high-throughput Dart applications (Server, CLI, Backend, and Shared Core Logic). Built upon the **2-Phase LPDAG (Lazy Pull Directed Acyclic Graph)** architecture, What eliminates redundant intermediate calculations, memory thrashing, and "glitches" (diamond dependency race conditions).

### The LPDAG Paradigm: Lazy Pull vs. Eager Push

Traditional reactive streams and observables push eager data payloads through the entire graph on every mutation (**Eager Push DAG**), causing redundant intermediate calculations and transient inconsistent states. Following the proven principles of modern 2-phase signals (such as Preact Signals and alien-signals), What's **LPDAG** divides reactive propagation into two distinct phases:

1. **Push-Dirty (Lightweight Invalidation Pulse)**: When an upstream source mutates, a lightweight dirty flag propagates downstream through the directed acyclic graph. No intermediate data payloads are evaluated or copied during this invalidation phase.
2. **Lazy-Pull (On-Demand Synchronous Evaluation)**: Downstream consumers (terminals, active effect runners, UI elements) pull data only when observed. Intermediate nodes compute and cache their `WhatSnapshot` synchronously. If an upstream node was marked dirty but its computed value has not changed, downstream propagation terminates immediately (Distinct Short-Circuit).

---

## Key Architectural Invariants

* **Separation of Producer and Consumer**: `What<T>` is the read-only, observation-only reactive interface. Mutation methods (`set`, `empty`, `setError`) are encapsulated strictly within `WhatController<T>` / `RawWhatController<T>`.
* **Explicit Dependency Manifest (`WhatVia`)**: All dynamic derivations and effects explicitly declare observed nodes via injected `WhatVia` (e.g., `computed((via) => via(a) + via(b))`). No ambient thread-local stacks.
* **Zero-Overhead Raw Reads**: Accessing `untracked(node)` or `untracked.state(node)` provides direct raw reads with zero tracking overhead.
* **1-Pass Epoch Sweeping**: Dynamic branches (e.g., ternary conditions inside `computed` or `switched`) immediately prune and detach unobserved upstream edges in O(edges) during evaluation.
* **Subscriber-Driven Inactive Dormancy**: When a pipeline has no active downstream terminals (effect runners, active UI elements), all upstream computation edges detach and enter zero-leak dormant state.
* **Pure Dart**: Zero external runtime dependencies; operates seamlessly across Dart VM, AOT, Server, CLI, and Web.

---

## Installation

Add `what` to your `pubspec.yaml`:

```bash
dart pub add what
```

Import the primary libraries:

```dart
// Core LPDAG engine, Dynamic Triad, controllers, snapshots, and async bridges
import 'package:what/what.dart';

// Standalone side-effect dispatchers and reactive pipeline extensions
import 'package:what/effect.dart';
```

---

## Quick Start (Self-Contained)

Copy and run directly with `dart run main.dart`:

```dart
import 'package:what/what.dart';

void main() async {
  // 1. Create reactive producer controllers (Separation of Producer & Consumer)
  final price = WhatController<int>(100);
  final quantity = WhatController<int>(2);
  final discount = WhatController<int>(10);

  // 2. Pure Synchronous Derivation via Explicit WhatVia
  // Topological pipeline: total pulls from subtotal and discount, where subtotal pulls from price & quantity
  final subtotal = computed((via) => via(price.what) * via(quantity.what));
  final total = computed((via) => via(subtotal) - via(discount.what));

  // 3. Standalone Active Runner with microtask batch compression
  final runner = total.effect(() {
    print('[Effect] Total updated: \$${untracked(total)}');
  }).run();

  // Initial value read via zero-overhead raw read:
  print('Initial total: \$${untracked(total)}'); // Prints: "Initial total: $190"

  // 4. Mutate upstream producers
  // Phase 1 (Push-Dirty): Invalidation pulse propagates with zero computation. No recomputation yet.
  price.set(150);
  quantity.set(3);
  discount.set(50);

  // Phase 2 (Lazy-Pull): Microtask batch fires. Evaluates once without diamond glitches.
  await Future<void>.delayed(Duration.zero);
  // Prints: "[Effect] Total updated: $400" (Calculated once: 150 * 3 - 50 = 400)

  // 5. Zero-Overhead Raw Read (0-allocation, zero ambient overhead)
  print('Raw read: ${untracked(total)}'); // 400

  // 6. Clean up: Enters Subscriber-Driven Inactive Dormancy
  runner.deactivate();
}
```

---

## Core Abstractions

What's reactive engine is organized around three foundational pillars: **Reactive Nodes** (state producers and lazy topological derivations), **Reactive Terminals** (LPDAG boundary sinks and dirty invalidation routers), and **Execution Pipelines** (standalone observers and microtask-batched side-effects).

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                    What Core Architecture & Taxonomy                       │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  1. Reactive Nodes (State & Derivation Topology)                           │
│     ├── Source Handles (Producers)                                         │
│     │    ├── WhatController<T>                 (data) ──(what)──> What<T>  │
│     │    ├── RawWhatController<T>              (data) ──(what)──> What<T>  │
│     │    └── WhatSignalController              ()     ──(what)──> WhatSignal│
│     │                                                                      │
│     ├── The Dynamic Triad (Unified Functors)                               │
│     │    ├── computed                          ((via) => ...)              │
│     │    │    ├── .future                      ((via) => Future<T>)        │
│     │    │    └── .stream                      ((via) => Stream<T>)        │
│     │    ├── switched                          ((via) => What<T>)          │
│     │    └── managed                           (create, update, dispose)   │
│     │                                                                      │
│     └── Fluent Pipeline Operators                                          │
│          ├── what.retained                     ([pending])   // SWR Cache  │
│          ├── what.distinct                     ([equals])                  │
│          ├── what.debounced                    (duration)                  │
│          ├── what.throttled                    (duration)                  │
│          └── what.graceful                     ([policy])    // Mooring    │
│                                                                            │
│  2. Reactive Terminals (LPDAG Boundary & Sinks)                            │
│     ├── RawWhatTerminal<T>                     // Push-dirty gateway sink  │
│     ├── RawComputedTerminal<T>                 // 1-Hop cached terminal    │
│     └── RawViaTerminal<T>                      // Epoch-tracked terminal   │
│                                                                            │
│  3. Execution & Side-Effects (1-Tick Compressed)                           │
│     ├── what.effect                            (() => ...)                 │
│     ├── Effect                                 ([targets], () => ...)      │
│     │    ├── .handled                          ((handle) => ...)           │
│     │    ├── .debounce                         (duration, (action) => ...) │
│     │    └── .throttle                         (duration, (action) => ...) │
│     └── EffectRunner                           (effect.run())              │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 1. Separation of Producer and Consumer

What enforces strict encapsulation between state mutation and state observation:

```dart
// The Producer Handle: owns mutation methods (set, empty, setError)
final WhatController<String> userController = WhatController('Alice');

// The Consumer Handle: read-only, safe to expose across API boundaries
final userWhat = userController.what;

// Zero-overhead raw read:
print(untracked(userWhat)); // "Alice" (0-allocation, direct read)

// Mutation via controller:
userController.set('Bob');
```

For ultra-hot paths where nullable-wrapping overhead must be eliminated, use `RawWhatController<T>`:

```dart
final rawController = RawWhatController<int>(0);
// Producer mutation: property assignment shorthand for rawController.set(10)
rawController.data = 10;
```

---

### 2. Universal State Protocol & Built-in Fault Tolerance (`WhatState` & `WhatSnapshot`)

Unlike primitive value containers that collapse failures or uninitialized states into ambiguous `null`s, reactive states in What are governed by **`WhatState<T>`**, a universal protocol based on an exact **3-State Algebraic Finite State Machine (FSM)**.

While the consumer handle `What<T>` is strictly an opaque DAG node handle (whose state is inspected via `via.state(what)` or `untracked.state(what)` with zero heap allocation), state producers, headless terminals, and snapshots (`WhatController`, `RawWhatTerminal`, and `WhatSnapshot`) implement `WhatState<T>` directly:

```text
               ┌────────────────────────────────────────┐
               │   WhatState<T> 3-State State Machine   │
               └────────────────────────────────────────┘
                      │ (Initial uninitialized / dormant)
                      ▼
               ┌──────────────┐      Value Resolved      ┌──────────────┐
               │    EMPTY     │ ───────────────────────> │     DATA     │ (hasData == true)
               │  (isEmpty)   │ <─────────────────────── │  (payload:T) │
               └──────┬───────┘     .empty([reason])     └──────┬───────┘
                      │                                         │
                      │ .setError()                 .setError() │
                      ▼                                         ▼
               ┌────────────────────────────────────────────────────────┐
               │                         ERROR                          │ (hasError == true)
               │            (payload: Object, [StackTrace])             │
               └────────────────────────────────────────────────────────┘
```

#### A. 3-State Algebraic Exclusivity & Sound Extraction
* **Data State (`hasData == true`)**: Holds a valid payload of type `T`. For nullable types (`What<User?>`), `null` is a completely valid payload and never aliases to `Empty`.
* **Empty State (`isEmpty == true`)**: Represents uninitialized or dormant state with an optional causal `emptyReason` (e.g., `'AwaitingAuthCredentials'`).
* **Error State (`hasError == true`)**: Encapsulates caught exceptions as first-class state data alongside original `error` and `stackTrace`.
* **Fail-Fast vs. Safe Fallback**: Reading `untracked(node)` while in `Empty` or `Error` state throws `WhatSnapshotExtractionException` immediately. For safe inspection, use `untracked.state(node)` (`.dataOrNull`, `.dataOrElse(() => fallback)`, or exhaustive matching).

#### B. Zero-Heap Total Pattern Matching & Record Tuple Guards
All entities implementing `WhatState` (as well as views returned by `via.state(node)` and `untracked.state(node)`) support zero-allocation synchronous pattern matching and compile-time multi-state guarding across Dart 3 Record tuples (arity 2 through 9):

```dart
// 1. Zero-Heap Synchronous Exhaustive Matching via untracked.state
final status = untracked.state(userWhat).match(
  data: (v) => 'Active: $v',
  empty: () => 'Awaiting initialization...',
  error: (err, stack) => 'Failed: $err',
);

// 2. Multi-Input Guarding via Zero-Allocation Record Tuple
final inputA = WhatController<int>(1).what;
final inputB = WhatController<int>(2).what;
final inputC = WhatController<int>(3).what;

final total = computed(
  (via) => via(inputA) + via(inputB) + via(inputC),
  // Evaluates without allocating List/Set wrapper collections:
  guard: (via) => (via.state(inputA), via.state(inputB), via.state(inputC)).guarded('AwaitingInputs'),
);
```

#### C. Total Fault Isolation & Zero-Ceremony Self-Healing
* **No Red Screen of Death**: Uncaught exceptions thrown inside user derivation closures (`computed`, `managed`) are sandboxed at the `_pull()` boundary and encapsulated within `_ErrorWhatState`. Exceptions never breach the DAG scheduler or crash the Flutter widget tree.
* **Topology Preservation Under Failure**: If an evaluation fails midway, 1-pass epoch sweeping is aborted (`succeeded: false`), freezing existing graph edges and preventing topological corruption.
* **Zero-Ceremony Self-Healing**: Once upstream inputs normalize (e.g. `controller.data = validData`), downstream nodes recover to `_ValidWhatState` automatically on the next pull turn—with **zero manual reset ceremony** (`ref.invalidate()` or retry loops not required).

#### D. Built for Software 3.0 & Autonomous AI Agents
What's deterministic state algebra eliminates the primary sources of AI code generation bugs:
1. **Zero State Desync**: Mutually exclusive states eliminate hallucinated flag combinations (`isLoading: true, isError: true`).
2. **Compiler-Enforced Exhaustiveness**: Omitting an `error` or `empty` branch in `.match()` triggers static analyzer errors, allowing AI agents to self-correct in a closed 1-shot loop.
3. **Explicit AST Signatures (`via`)**: No hidden ambient contexts (Rules of Hooks, ambient Provider scopes) to confuse LLM attention.

---

### 3. The Dynamic Triad

The core reactive graph in What is driven by three unified functors:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                  The Dynamic Triad Canonical Architecture                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  1. computed: Pure Derivations & Async Pipelines                           │
│     ├── (via) => T                     : Pure synchronous derivation       │
│     ├── .future((via) => Future<T>)    : Async single-shot fetch (SWR)     │
│     └── .stream((via) => Stream<T>)    : Real-time continuous stream / WS  │
│         * Common Options: guard: (via) => WhatGuard                        │
│                                                                            │
│  2. switched: Dynamic Pipeline Switching (Unified Entrypoint)              │
│     └── (via) => What<T>               : Dynamic DAG edge redirection      │
│         * Options: eager: false (Pure Lazy, default) │ eager: true         │
│                    guard: (via) => WhatGuard                                │
│                                                                            │
│  3. managed: Pure Synchronous External Resource Lifecycle                  │
│     └── call(create, update, dispose)  : Supervised resource allocation    │
│         * Hooks:   create:  (via) => T                                     │
│                    update:  (via, current) => T (optional)                 │
│                    dispose: (resource) => void                             │
│         * Options: eager: false (Lazy, default) │ eager: true              │
│                    guard: (via) => WhatGuard │ graceful: Graceful           │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### A. `computed`: Pure State Derivations

Derives a new reactive state synchronously from one or more upstream nodes. Supports dynamic edge pruning, precondition gating (`guard`), and declarative signal triggers via `via(signal.what)`:

```dart
final searchQuery = WhatController('');
final refreshTrigger = WhatSignalController();

// Guarded Synchronous Derivation:
// Gates evaluation until query has >= 2 characters; emits Empty('QueryTooShort') without throwing:
final searchResults = computed(
  (via) {
    via(refreshTrigger.what); // Declarative re-evaluation trigger
    return performSearch(via(searchQuery.what));
  },
  guard: (via) => (via(searchQuery.what).trim().length >= 2).guarded('QueryTooShort'),
);
```

* **Dynamic Edge Pruning (1-Pass Epoch Sweeping)**: If a branch is skipped in a conditional evaluation, What automatically detaches the unused dependency in $O(\text{edges})$:
  ```dart
  final isDev = WhatController(true);
  final devConfig = WhatController('Debug Config');
  final prodConfig = WhatController('Release Config');

  final activeConfig = computed((via) {
    // When isDev is true, prodConfig edge is completely detached!
    return via(isDev.what) ? via(devConfig.what) : via(prodConfig.what);
  });
  ```
* **Asynchronous Computations**: For asynchronous single-shot queries and continuous streams, see `computed.future` and `computed.stream` in [Asynchronous Data Ingress & SWR](#4-asynchronous-data-ingress--swr).

#### B. `switched`: Dynamic Pipeline Switching

Dynamically switches between entirely different upstream `What<T>` pipelines based on runtime state, flattening branch switches into a single continuous edge:

```dart
final selectedTab = WhatController(0);
final isLoggedIn = WhatController(false);

// Subtree Gating: Entire feed graph is uninstantiated until user is authenticated
final currentFeed = switched(
  (via) => via(selectedTab.what) == 0 ? homeFeed.what : trendingFeed.what,
  guard: (via) => via(isLoggedIn.what).guarded('UserNotAuthenticated'),
);
```

* **Zero-Cost Lazy Switching**: Evaluates the target branch strictly on-demand (`eager: false` by default). Use `eager: true` for pre-emptive evaluation.
* **⚠️ Anti-Pattern Prevention**: Switch between *pre-existing, stable* `What` branches. Do NOT instantiate new `What` nodes inside `switched(...)` without memoization, as it allocates orphan subgraphs on every dependency tick.

#### C. `managed`: External Resource Lifecycle Management

Supervises external synchronous resources (timers, sockets, hardware handles) strictly coupled to subscriber presence. Supports in-place instance updates (`update`), precondition gating (`guard`), and declarative signal triggers via `via(signal.what)`:

```dart
final serverPort = WhatController(8080);
final reconnectTrigger = WhatSignalController();

final apiClient = managed<ApiClient>(
  create: (via) {
    via(reconnectTrigger.what); // Declaratively disposes & re-creates on pulse
    return ApiClient(port: via(serverPort.what));
  },
  // In-place reuse: update existing instance without tearing down connections
  update: (via, current) {
    current.updatePort(via(serverPort.what));
    return current; // Returning same instance skips dispose()!
  },
  dispose: (client) => client.close(),
);

// Trigger manual reconnection:
reconnectTrigger.emit();
```

* **Inactive Dormancy**: When no terminals observe the managed node, `dispose` is executed synchronously, leaving zero lingering resources or memory leaks.
* **Precondition Guards (`guard`)**: Halts allocation until prerequisites are ready (e.g. auth token available), gracefully emitting `Empty(emptyReason)` without throwing exceptions.
* **Transient Mooring (`graceful`)**: Pass `graceful: const Graceful.period(Duration(...))` to prevent disposal thrashing during UI route transitions.

---

### 4. Precondition Guarding: Zero-Leak Resource Gating (`guard`)

In traditional state managers, gating execution on unready prerequisites (e.g. unauthenticated user, empty query) requires imperative `if` checks, throws artificial exceptions, or causes **zombie resource leaks** on logout.

What establishes **Precondition Guarding** as a first-class algebraic fault barrier across the entire Dynamic Triad (`computed`, `managed`, `switched`):

```dart
// 1. Declarative ApiClient: Automatically disposes upon logout without imperative hooks!
final tokenWhat = WhatController<String>('token_123').what;
final loggedInWhat = WhatController<bool>(true).what;

final clientHandle = managed<ApiClient>(
  create: (via) => ApiClient(port: 8080),
  dispose: (client) => client.close(),
  // Gated on active session: when loggedIn becomes false, engine immediately disposes the client!
  guard: (via) => (via(loggedInWhat) && via.state(tokenWhat).hasData)
      .guarded('AwaitingAuthentication'),
);

// 2. Multi-Input Gating & Granular Diagnostic Reasons:
final cartWhat = WhatController<Cart>(Cart()).what;
final addressWhat = WhatController<Address>(const Address()).what;

final orderSummary = computed(
  (via) => OrderPricing(total: via(cartWhat).items.length * 10.0),
  guard: (via) {
    if (via.state(cartWhat).isEmpty) return WhatGuard.block('CartIsEmpty');
    if (via.state(addressWhat).isEmpty) return WhatGuard.block('AddressRequired');
    return WhatGuard.pass;
  },
);
```

* **Deterministic Auto-Disposal**: When dependencies in `guard` collapse (e.g. `isLoggedIn` becomes `false`), `managed` nodes **immediately invoke `dispose()` and transition to `Empty`**. No manual teardown logic required on logout.
* **Execution Gating**: Gated `computed` derivations and asynchronous I/O (`computed.future`, `computed.stream`) are aborted at the threshold, preventing unneeded network traffic.
* **Zero-Heap Record Tuples**: Multi-state checks like `(via.state(a), via.state(b)).guarded()` evaluate on the call stack with **0 heap allocations**.
* [Read Deep-Dive Whitepaper: 18. Precondition Guarding & Algebraic State Gating](doc/foundations/18_precondition_guarding_and_algebraic_gating.md)

---

### 5. Discrete Reactive Signals (`WhatSignal`)

For discrete, stateless event pulses (e.g. user taps, manual refresh triggers, socket reconnects), What provides `WhatSignalController` and `WhatSignal`, eliminating the anti-pattern of mutating dummy state values (such as `counter++`):

```dart
// 1. The Producer Handle: emits discrete event pulses
final refreshTrigger = WhatSignalController(
  onActivated: () => print('Downstream observers connected'),
  onDeactivated: () => print('All observers detached; entered dormancy'),
);

// 2. The Consumer View: read-only WhatSignal (implements What<int>)
final WhatSignal signalWhat = refreshTrigger.what;

// 3. Declarative pipeline binding via WhatVia:
final userFeed = computed.future((via) {
  via(signalWhat); // Declaratively refetches when signal emits
  return api.fetchUserFeed();
});

// 4. Emit monotonic sequence tick (0 -> 1 -> 2 ...):
refreshTrigger.emit();
```

* **Zero-Allocation Version Sequence**: Monotonic sequence ticks ensure downstream `.distinct()` filters never drop consecutive pulses.
* **Subscriber-Driven Dormancy**: `onActivated` / `onDeactivated` hooks enable automatic start/stop of hardware sensors or polling intervals when UI mounts or unmounts.

---

### 6. Reactive Collections & Atomic Drafts (`WhatListController`)

What provides specialized reactive collection controllers (`WhatListController`, `WhatSetController`, `WhatMapController`) featuring Immer-style isolated draft buffers and automatic immutability freezing:

```text
[WhatListController] ──> .edit((draft) { draft.add(item); })
                                 │
                                 ▼ (Equality Guard: Previous vs Next)
                      [Modified? ── Yes ──> Freezes List.unmodifiable & Push-Dirty (1 Pulse)]
                                 └── No   ──> No-Op (Zero Downstream Recomputations)
```

```dart
final todoList = WhatListController<TodoItem>([]);

// 1. Atomic Draft Transaction: batches multiple operations into at most 1 invalidation pulse
todoList.edit((draft) {
  draft.add(TodoItem(id: '1', title: 'Engine verification'));
  draft.add(TodoItem(id: '2', title: 'Release core library'));
  draft.sort((a, b) => a.title.compareTo(b.title));
});

// 2. Immutability Enforcement: external mutations throw UnsupportedError
// todoList.data.add(item); // Throws UnsupportedError! Always use .edit()

// 3. Safe guarded editing: automatically captures exceptions into an error state
todoList.editGuarded((draft) {
  draft.removeWhere((item) => item.id == '1');
});

// 4. Declarative aggregation operators across What nodes
final priceNodes = WhatController<List<What<int>>>([
  WhatController(100).what,
  WhatController(250).what,
]);
final totalSum = priceNodes.what.sum();
```

---

### 7. Graceful Deactivation & Mooring Buffer (Zero-Thrashing)

Under **Subscriber-Driven Inactive Dormancy**, What nodes immediately detach from upstream sources and release resources when their subscriber count drops to zero. However, transient lifecycle drops (such as UI route navigation, tab switching, or brief widget unmounts) can cause rapid 0-subscriber flickers.

What eliminates subscription thrashing through **Graceful Deactivation Policies**:

```dart
// 1. Time-Based Mooring: retain warm cache across screen navigation (0ms instant reuse)
final userFeedWhat = computed.future((via) => api.fetchUserFeed())
    .graceful(const Graceful.period( Duration(minutes: 2)));

// 2. Microtask Buffer: coalesces 1-tick frame transitions (Hero animations / unmount-remount)
final telemetryStream = What.stream(
  stockMarketChannel.streamFor('AAPL'),
  graceful: Graceful.microtask,
);

// 3. Supervised managed resource with mooring buffer (strictly synchronous lifecycle)
final liveClient = managed<ApiClient>(
  create: (via) => ApiClient(port: 8080),
  dispose: (client) => client.close(),
  graceful: const Graceful.period( Duration(seconds: 30)),
);
```

* **Microtask Buffer (`Graceful.microtask` / `Graceful()`)**: Defers disposal by 1 Dart microtask tick (default), completely eliminating subscription thrashing during rapid widget unmount/remount cycles without GC allocations.
* **Time-Based Mooring (`Graceful.period(Duration)`)**: Deploys a topological anchor (`_MooringTerminal`) that keeps the node and its upstream dependencies active and warm for the specified duration.

---

### 8. Side-Effects: `Effect`, `via.tether`, `EffectRunner` & `EffectHandle`

What completely separates side-effects into declarative first-class entities with strict lifecycle binding and asynchronous race-condition guards.

#### A. Scope-Bound Lifecycle via `via.tether()`
Tethering binds an effect's lifespan directly to an enclosing reactive scope. When the scope deactivates, tethered effects automatically sleep (Zero-Leak):

```dart
final searchQuery = WhatController('');
final filter = WhatController('all');

final searchPipeline = computed((via) {
  // Automatically activated and deactivated in lockstep with searchPipeline:
  via.tether((searchQuery.what, filter.what).effect(() {
    analytics.logSearch(untracked(searchQuery.what), untracked(filter.what));
  }));
  return via(searchQuery.what);
});
```

#### B. Standalone Execution & Lifecycle Control (`EffectRunner`)
Outside UI scopes, run standalone effects with full pause and resume capability:

```dart
final syncEffect = userWhat.effect.debounce(
  const Duration(milliseconds: 300),
  () => cloudSync(untracked(userWhat)),
);

// Start standalone execution:
final runner = syncEffect.run(autoStart: true);

// Pause observation (puts upstream LPDAG pipeline into dormancy, 0-CPU):
runner.deactivate();

// Resume observation:
runner.activate();
```

#### C. In-Flight Race Guards & Multi-Cleanup RAII (`EffectHandle`)
Using `Effect.handled` protects against stale asynchronous overwrites and setup failures:

```dart
Effect.handled([roomId.what], (handle) async {
  // 1. Multi-Registration RAII: register cleanups immediately adjacent to resource acquisition
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => ping());
  handle.onCleanup(timer.cancel);

  final socket = await WebSocket.connect('ws://example.com/rooms/${untracked(roomId.what)}');
  handle.onCleanup(socket.close);

  // 2. In-flight cancellation guard: prevent stale overwrite across async gaps
  final initialData = await socket.first;
  if (handle.isCancelled) return; // Stale turn cancelled by newer roomId; safe exit

  applyRoomData(initialData);
});
```

---

### 9. Asynchronous Data Ingress & Dynamic Couplers (`WhatCoupler`)

What seamlessly bridges asynchronous primitives and provides hot-swappable 1-tier relay sockets for seamless runtime rewiring.

```dart
// 1. computed.future with SWR caching & discrete refresh triggers
final selectedUserId = WhatController('user_123');
final refreshTrigger = WhatSignalController();

final userProfileWhat = computed.future((via) async {
  via(refreshTrigger.what);
  return await apiService.fetchUser(via(selectedUserId.what));
});

// 2. computed.stream with automatic subscription lifecycle management
final activeSymbol = WhatController('AAPL');
final liveStockPricesWhat = computed.stream((via) {
  final symbol = via(activeSymbol.what);
  return stockMarketChannel.streamFor(symbol);
});
```

#### Dynamic Pipeline Switching (`WhatCoupler`)
Hot-swap upstream data sources (e.g. Guest session ➔ Live user session, Mock ➔ Remote API) without rebuilding or disconnecting downstream consumers:

```text
[Upstream A] (Detached on couple)
     │
     ▼ (coupler.couple(upstreamB))
┌──────────────────┐
│  WhatCoupler<T>  │ ──► what (Read-Only) ──► [Downstream UI & Pipelines Remain Connected!]
└──────────────────┘
     ▲
     │ (Newly Attached)
[Upstream B]
```

```dart
// Create socket relay initialized with guest source:
final userCoupler = WhatCoupler<User>(guestUserWhat);

// Downstream pipelines observe coupler.what once and never drop:
final welcomeBanner = computed((via) => 'Hello, ${via(userCoupler.what).name}');

// On login success: Hot-swap upstream source with 0ms latency:
userCoupler.couple(authenticatedUserWhat);
```

---

### 10. Enterprise Observability & Diagnostics

In enterprise environments, What provides global telemetry for uncaught reactive errors with **zero hot-path overhead**, alongside comprehensive debug tools.

```dart
// 1. Zero-Overhead Uncaught Error Handler
LpdagUncaughtErrorHandler.instance = MyTelemetryHandler(
  onUncaughtError: (error, stackTrace, {context}) {
    // context points directly to the originating reactive node or terminal
    Sentry.captureException(error, stackTrace: stackTrace, extra: {'node': context});
  },
);

// 2. Zero-overhead debug topology inspection in development
print(userWhat.debug.describe());
print(userWhat.debug.snapshot());
```

---

## Core Engine Deep-Dive Whitepapers
 
To understand the mathematical and architectural foundations of What's LPDAG engine:

1. [Whitepaper 01: LPDAG Two-Phase Engine & Glitch-Freedom](doc/foundations/01_lpdag_two_phase_engine_and_glitch_freedom.md)
2. [Whitepaper 02: Explicit Dependency Manifest: WhatVia & 1-Pass Epoch Sweeping](doc/foundations/02_explicit_dependency_manifest_and_epoch_sweeping.md)
3. [Whitepaper 03: Subscriber-Driven Inactive Dormancy & Pure Lazy Lifecycle](doc/foundations/03_subscriber_driven_dormancy.md)
4. [Whitepaper 04: Capability-Based Encapsulation & Fault-Tolerant Exception Isolation](doc/foundations/04_capability_security_and_fault_isolation.md)
5. [Whitepaper 05: Algebraic State Protocol & Self-Healing Fault Tolerance Specification](doc/foundations/05_algebraic_state_protocol_and_self_healing_fault_tolerance.md)
6. [Whitepaper 06: Asynchronous Pipeline and Scheduling Invariants: The Physics of Async Reactivity](doc/foundations/06_asynchronous_pipeline_and_scheduling.md)
7. [Whitepaper 07: Async Topological Race Immunity & Inactive Dormancy Foundations](doc/foundations/07_async_topology_race_immunity_and_dormancy.md)
8. [Whitepaper 08: Synchronous Resource Lifecycle and Managed Composition](doc/foundations/08_synchronous_resource_lifecycle_and_managed.md)
9. [Whitepaper 09: Graceful Lifecycle & Mooring: Zero-Thrashing Transient Retention](doc/foundations/09_graceful_lifecycle_and_mooring_terminal.md)
10. [Whitepaper 10: Fine-Grained Reactive Collections: Keyed Divergence & Transactional List State](doc/foundations/10_reactive_collections_and_keyed_divergence.md)
11. [Whitepaper 11: Polymorphic Refreshable Pipeline & Zero-Boilerplate SWR](doc/foundations/11_polymorphic_refreshable_and_swr.md)
12. [Whitepaper 12: Dynamic Routing Foundations: Mainstream Pipeline & Lateral Control Delta](doc/foundations/12_dynamic_routing_and_lateral_delta.md)
13. [Whitepaper 13: Two-Tier Temporal Architecture: State-Domain Smoothing vs. Effect-Domain Rate Limiting](doc/foundations/13_two_tier_temporal_architecture_and_scheduling.md)
14. [Whitepaper 14: Declarative Side-Effect Pipelines: Effect, EffectRunner, and Microtask Batching](doc/foundations/14_standalone_observation_and_effect_pipelines.md)
15. [Whitepaper 15: Zero-Allocation Reactive Graph: Dart VM Optimization & Intrusive Data Structures](doc/foundations/15_dart_vm_low_overhead_memory_engineering.md)
16. [Whitepaper 16: Object-Oriented Domain Computation & Zero-Overhead Reactive Diagnostics](doc/foundations/16_domain_computation_and_zero_overhead_diagnostics.md)
17. [Whitepaper 17: Imperative Signals & Transient Events Specification](doc/foundations/17_imperative_signals_and_transient_events.md)
18. [Whitepaper 18: Precondition Guarding & Algebraic State Gating: The Unified Fault-Barrier of the Dynamic Triad](doc/foundations/18_precondition_guarding_and_algebraic_gating.md)
19. [Whitepaper 19: Terminal Architecture & Headless Sink Mechanics Specification](doc/foundations/19_terminal_architecture_and_headless_sink_mechanics.md)


---

## API Summary Table

| Symbol | Category | Description |
| :--- | :--- | :--- |
| `What<T>` | Core | Read-only, observation-only reactive node interface in the LPDAG graph. |
| `WhatController<T>` | Core | Producer handle owning mutation methods (`set`, `empty`, `setError`). |
| `RawWhatController<T>` | Core | Unboxed, ultra-hot path state producer for non-nullable values. |
| `WhatSignalController` | Signal | Producer handle for emitting discrete pulse events (`emit`). |
| `WhatSignal` | Signal | Read-only consumer view emitting monotonic sequence ticks for discrete events. |
| `WhatVia` | Engine | Dynamic dependency registration handle passed to reactive functors. |
| `computed((via) => ...)` | Triad | Synchronous pure reactive derivation functor. |
| `switched((via) => ...)` | Triad | Dynamic reactive pipeline branch switching functor. |
| `managed(create:, dispose:, ...)` | Triad | External resource lifecycle supervisor with inactive dormancy. |
| `Graceful` / `graceful` | Lifecycle | Deactivation buffering policy (microtask deferral & time-based mooring). |
| `Effect` / `EffectRunner` | Effects | Dynamic side-effect execution pipeline with debounce/throttle support. |
| `WhatSnapshot<T>` | Contract | Immutable three-state container (`data`, `empty`, `error`). |
| `WhatListController<T>` | Collection | List state producer supporting transactional batch edits (`edit`). |
| `WhatSetController<E>` | Collection | Set state producer supporting transactional batch edits (`edit`). |
| `WhatMapController<K, V>` | Collection | Map state producer supporting transactional batch edits (`edit`). |
| `RawWhatTerminal<T>` | Low-Level | Low-level consumer sink for building custom UI framework integrations. |

---

## Contributing

Contributions, issues, and feature requests are welcome!
Feel free to check out the [Issues page](https://github.com/pioneerjkf/what/issues).

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Format and verify code (`dart format . && dart analyze && dart test`)
4. Commit your changes (`git commit -m 'feat: add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

---

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
