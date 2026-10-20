# Capability-Based Encapsulation & Fault-Tolerant Exception Isolation Specification
## (Capability-Based Encapsulation, Producer-Consumer Boundary, Engine-Level Exception Isolation, and Self-Healing FSM Recovery)

> **"In large-scale software engineering, architectural robustness is proven not by what developers are permitted to do, but by the structural failure modes the system inherently makes impossible."**  
> — *What Framework Core Systems Group*

---

## 1. Overview: State Management Vulnerabilities in Enterprise Systems

In large-scale production codebases where hundreds of engineers collaborate across distributed domain teams, traditional reactive state frameworks (Provider, Riverpod, Bloc, MobX, generic Signals) confront two primary failure modes:

1. **Producer-Consumer Boundary Violation (Downcasting Breaches)**:  
   Consumer UI widgets receiving a reference intended solely for state observation abuse mutable handles to mutate upstream domain state directly. Conflating readable observables with mutable controllers destroys unidirectional data flow, produces untraceable circular mutation loops, and violates the Principle of Least Privilege.
2. **Graph Poisoning by Uncaught Exceptions**:  
   When a user calculation closure (`computed`) or asynchronous task throws an unhandled exception (`FormatException`, `TypeError`, network timeout), the error escapes the execution stack, aborting the reactive DAG engine. Intermediate nodes are left in uninitialized zombie states, causing cascading `NullCheckError` failures across unrelated UI elements.

The What Framework resolves these challenges through **Capability-Based Security** and **Engine-Level Fault Isolation** invariants embedded at the lowest topological primitives.

---

## 2. Separation of Producer and Consumer: The Has-a Architecture

### 2.1 Interface Hierarchy and Unidirectional Capability Transfer

Read-only observation capabilities and mutable producer handles are strictly isolated across separate, concrete types:

```text
┌────────────────────────────────────────────────────────────────────────┐
│  Consumer Layer (UI / Widgets / Presentation)                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  What<T> (Interface: Pure Opaque DAG Node Handle)                      │
│  • untracked(what) / untracked.state(what)  (Untracked direct read)    │
│  • via(what) / via.state(what)              (Tracked dynamic read)     │
│  * (Exposes ZERO public read getters, ZERO mutation methods)           │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                                   ▲
                                   │ .what getter (Unidirectional Capability Transfer)
┌──────────────────────────────────┴─────────────────────────────────────┐
│  Producer Layer (Domain Store / State Owner)                           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  WhatController<T> / RawWhatController<T>                              │
│  • set data(T value); / void set(T value);                             │
│  • void setGuarded(T Function() test);                                 │
│  • void setError(Object error, [StackTrace? trace]);                   │
│  • void empty([Object? reason]);                                       │
│  • What<T> get what;                                                   │
│  * (Does NOT implement What<T>: Zero Downcasting Risk)                 │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Why Controllers Never Implement `What<T>`

Many reactive libraries design producer handles (e.g., `ValueNotifier`, `BehaviorSubject`, `StateNotifier`) to implement the observable value interface directly for convenience:

```dart
// [Anti-Pattern] Fragile architecture where Controller implements Observable
class CounterController implements Observable<int> { ... }

void renderView(Observable<int> observable) {
  // Consumers can downcast and mutate upstream state illegitimately!
  if (observable is CounterController) {
    observable.setValue(999); // Encapsulation breached at runtime!
  }
}
```

This violates the **Object-Capability Model**: any component that can observe the value also inherits the latent capability to mutate it via dynamic type casting (`is` / `as`).

In What, [`WhatController<T>`](../../lib/src/what/controller.dart#L81) **never inherits or implements [`What<T>`](../../lib/src/what/what.dart#L12)**:
* **Strict "Has-a" Composition**: `WhatController<T>` owns and encapsulates a private physical entry node inside the engine. It exposes the read-only consumer interface solely via `controller.what`.
* **Zero Downcasting Vulnerability**: A `What<T>` instance passed to presentation layers cannot be downcast to a `WhatController` under any circumstance. Attempting `what is WhatController<T>` evaluates to `false` statically or throws a `TypeError` at runtime:
  ```dart
  final controller = WhatController(42);
  final consumerView = controller.what;

  assert(consumerView is What<int>);
  assert(consumerView is! WhatController<int>); // Downcasting is strictly impossible!
  ```
* **Discrete Event Signals**: The identical capability separation governs discrete pulses: [`WhatSignalController`](../../lib/src/what/signal.dart#L10) (producer handle with `emit()`) exposes [`WhatSignal`](../../lib/src/what/signal.dart#L12) (read-only consumer view implementing `What<int>`).

### 2.3 `WhatController` vs. `RawWhatController`: Distinct Filtering vs. Manual Invalidation

The framework provides two controller variants engineered for distinct operational requirements:

| Dimension | [`WhatController<T>`](../../lib/src/what/controller.dart#L81) | [`RawWhatController<T>`](../../lib/src/what/controller.dart#L274) |
| :--- | :--- | :--- |
| **Default Equality Guard** | `distinct: true` (Enabled by default) | **Zero Check** (Equality check completely bypassed) |
| **Invalidation Trigger** | Emits Push-Dirty only when new value differs via `equals` | Emits Push-Dirty on every assignment or explicit `markDirty()` |
| **Primary Use Cases** | Immutable entities, primitives (`int`, `String`), ViewModels | Mutable buffers, high-cadence in-place mutations, streaming I/O |

```dart
// 1. Standard WhatController: Blocks downstream re-rendering on duplicate values
final counter = WhatController(0);
counter.data = 0; // Identical value: suppresses dirty pulses (0 recomputations)!

// 2. RawWhatController: In-place mutation notifications
final buffer = RawWhatController<List<int>>([1, 2, 3]);
buffer.data.add(4); // Same reference identity
buffer.markDirty(); // Explicitly notifies downstream subscribers of in-place mutation!
```

---

## 3. Engine-Level Fault Isolation & Self-Healing Resilience

In a Directed Acyclic Graph (DAG), an unhandled exception thrown inside an intermediate derivation risks crashing the entire downstream rendering hierarchy.

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│              Escaping Exception Catastrophe vs. Total Fault Isolation           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   [Traditional Reactive Graph: Uncaught Exception Collapse]                     │
│   User compute() throws FormatException                                        │
│          │                                                                      │
│          ▼                                                                      │
│   Escapes through resolver stack ──► _state left null / uninitialized           │
│          │                                                                      │
│          ▼                                                                      │
│   Cascading NullCheckErrors / Engine Freeze ──► Red Screen of Death             │
│                                                                                 │
│   [What Framework: Engine-Level Exception Isolation]                            │
│   User compute() throws FormatException                                        │
│          │                                                                      │
│          ▼                                                                      │
│   Trapped inside _pull() ──► Encapsulated into _ErrorWhatState(error, trace)   │
│          │                                                                      │
│          ▼                                                                      │
│   Topological DAG edges preserved ──► Propagates downstream as 1st-class FSM   │
│          │                                                                      │
│          ▼ (Upstream inputs normalize)                                          │
│   Automatic Self-Healing Recovery ──► Restores _ValidWhatState seamlessly!      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 The Danger of Escaping Uncaught Exceptions

In 2-Phase LPDAG engines, [`_PullResolver._resolve()`](../../lib/src/engine/_internal/_pull.dart#L47) maintains recursion guards (`_isResolving`) to detect cycles (`LpdagCycleError`):

```dart
// packages/what/lib/src/engine/_internal/_pull.dart
@pragma('vm:prefer-inline')
void _resolve() {
  if (_isResolving) {
    throw LpdagCycleError(
      'Cyclic evaluation loop detected in $runtimeType while resolving state.',
    );
  }
  _isResolving = true;
  try {
    // ...
    if (_dirtyState == _DirtyState.dirty || _state == null) {
      _state = _pull(); // What happens if an unhandled exception escapes here?
      _dirtyState = _DirtyState.clean;
      _pullVersion();
    }
  } finally {
    _isResolving = false;
  }
}
```

If user code inside `_pull()` allowed exceptions to escape up the call stack:
1. `_state` would remain uninitialized (`null`).
2. Subsequent reads from UI or downstream nodes would crash with cascading `NullCheckError` failures.
3. The node would become an unrecoverable **poisoned zombie node**.

### 3.2 The Total Derivation Isolation Invariant

The What Framework enforces an engine invariant: **No user-originated exception may escape the `_pull()` evaluation boundary.**

```dart
// packages/what/lib/src/what/_internal/_computed.dart
@override
@pragma('vm:prefer-inline')
_WhatState<T> _pull() {
  if (this case final _Node node) {
    node._version++;
  }
  final currentEpoch = _beginEpoch();
  _WhatState<T> state;
  var succeeded = true;
  try {
    final guard = _guard;
    if (guard != null) {
      final decision = guard(_via);
      if (!decision.isPass) {
        state = _EmptyWhatState<T>(decision.reason);
        return state;
      }
    }
    final result = _compute(_via);
    final current = _state;
    if (current case final _ValidWhatState<T> s) {
      s.update(result);
      state = s;
    } else {
      state = _ValidWhatState<T>(result);
    }
  } catch (error, stackTrace) {
    succeeded = error is _ViaShortCircuit;
    state = _WhatState.fromCaught(error, stackTrace);
  } finally {
    _endEpoch(currentEpoch, succeeded: succeeded, commitVersions: false);
  }
  return state;
}
```

#### Short-Circuit vs. Failure Demarcation:
1. **Short-Circuit Signal (`error is _ViaShortCircuit`)**:  
   Thrown when an upstream dependency accessed via `via(node)` is in an `Empty` or `Error` state.
   - `_WhatState.fromCaught` unpacks the upstream state directly via `error.state._retype<T>()`, forwarding the reason or error without reallocating objects.
   - `succeeded = true`: The derivation completed its evaluation sequence as intended, safely unlinking stale branches in `_endEpoch`.
2. **User Exception (`error is! _ViaShortCircuit`)**:  
   Thrown when user business logic encounters a bug or parse error.
   - Encapsulated cleanly into an [`_ErrorWhatState<T>(error, stackTrace)`](../../lib/src/what/_internal/_state.dart).
   - `succeeded = false`: Stale branch edges and versions are left untouched, ensuring that the node remains dirty and can retry re-evaluation once upstream inputs change.
3. **Preserved DAG Topology**: Even if closures throw `Exception` or `Error`, the node's internal state machine and topological edges remain intact.
4. **Self-Healing Recovery**: Once upstream inputs return to valid states, the subsequent Pull turn executes `_compute(_via)` cleanly, restoring `_ValidWhatState` automatically without manual resets or controller disposal.

### 3.3 Terminal & Lifecycle Exception Dispatch (`LpdagUncaughtErrorHandler`)

While derivation exceptions are encapsulated as first-class `Error` states, exceptions occurring outside derivation bounds (e.g. within terminal invalidation callbacks or asynchronous lifecycle cleanups in `managed`) are routed through [`_dispatchUncaughtError`](../../lib/src/engine/_internal/_uncaught.dart#L10):

```dart
// packages/what/lib/src/engine/_internal/_uncaught.dart
@pragma('vm:prefer-inline')
void _dispatchUncaughtError(Object error, StackTrace stackTrace, {Object? context}) {
  final handler = LpdagUncaughtErrorHandler.instance;
  if (handler != null) {
    try {
      handler.onUncaughtError(error, stackTrace, context: context);
    } catch (handlerError, handlerStack) {
      Zone.current.handleUncaughtError(handlerError, handlerStack);
    }
  }
  Zone.current.handleUncaughtError(error, stackTrace);
}
```

1. **Downstream Terminal Routing**: [`_Node._handleUncaughtError`](../../lib/src/engine/_internal/_node.dart#L149) first traverses downstream edges to deliver the failure to active terminals via `terminal._handleUncaughtError`.
2. **Global Telemetry Integration**: If no active terminal intercepts the failure, it routes to [`LpdagUncaughtErrorHandler.instance`](../../lib/src/engine/uncaught.dart#L11). Applications attach centralized telemetry (e.g., Sentry, Firebase Crashlytics) without incurring hot-path performance penalties:
   ```dart
   LpdagUncaughtErrorHandler.instance = MyTelemetryHandler(
     onUncaughtError: (error, stackTrace, {context}) {
       Sentry.captureException(error, stackTrace: stackTrace, extra: {'node': context});
     },
   );
   ```
3. **Zero Core Collapse**: Exceptions in one terminal or callback never abort the global DAG engine; sibling terminals and unaffected nodes continue processing smoothly.

---

## 4. 3-State FSM Snapshots & Zero-Allocation Multi-Guarding

Every stateful entity in What conforms to a deterministic **3-State Finite State Machine**:

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        3-State Finite State Machine (FSM)                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│                               ┌──────────────┐                                  │
│                               │    EMPTY     │ (Uninitialized / Dormant)        │
│                               │  (isEmpty)   │ [Optional causal emptyReason]    │
│                               └──────┬───────┘                                  │
│                                      │                                          │
│                    .set(data)        │        .empty([reason])                  │
│               ┌──────────────────────┴──────────────────────┐                   │
│               ▼                                             ▼                   │
│       ┌──────────────┐                               ┌──────────────┐           │
│       │     DATA     │ ────────────────────────────► │    ERROR     │           │
│       │  (hasData)   │          .setError()          │  (hasError)  │           │
│       │ (payload: T) │ ◄──────────────────────────── │ (error, trace│           │
│       └──────────────┘          .set(data)           └──────────────┘           │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

* **Data (`hasData == true`)**: Contains a valid payload of type `T`. Note that `null` is a valid payload for nullable types (`T?`) and is **never** conflated with missing data.
* **Empty (`isEmpty == true`)**: Uninitialized, gated, or dormant state with an optional causal attribution reason ([`emptyReason`](../../lib/src/what/state.dart#L59)).
* **Error (`hasError == true`)**: Failure state capturing the underlying failure object and stack trace.

### 4.1 Zero-Allocation Record Multi-Guarding (`(a, b, c).guarded()`)

When derivations depend on multiple upstream inputs, evaluating readiness using `List` allocations incurs garbage collection pressure. The What Framework provides zero-cost Dart 3 Record extensions (arity 2 through 9):

```dart
final userId = WhatController<String>.late();
final authToken = WhatController<String>.late();
final userRole = WhatController<String>.late();

final profileQuery = computed(
  (via) => fetchProfile(via(userId.what), via(authToken.what), via(userRole.what)),
  // Evaluates on CPU registers with ZERO heap allocations
  guard: (via) => (
    via.state(userId.what),
    via.state(authToken.what),
    via.state(userRole.what),
  ).guarded('AwaitingCredentials'),
);
```

* **Short-Circuit Gating**: If any credential node is empty or in error, the guard returns `WhatGuard.block('AwaitingCredentials')`. `computed` transitions directly to `Empty` with the given reason, preventing the derivation closure from executing on uninitialized data.

---

## 5. Explicit Dependency Manifest (`WhatVia`) and Ambient Side-Effect Isolation

The What Framework rejects implicit ambient dependency tracking through Zone values or thread-local globals (e.g., `value.read()`).

```dart
// Explicit dependency manifest in What
final firstName = WhatController('Grace');
final lastName = WhatController('Hopper');

final fullName = computed((via) => '${via(firstName.what)} ${via(lastName.what)}');
```

### 5.1 Pitfalls of Ambient Implicit Tracking

In frameworks relying on global active-observer stacks:
1. **Asynchronous Context Bleed**: Crossing asynchronous gaps (`await`) detaches ambient thread-local contexts or bleeds tracking into unrelated microtasks.
2. **Accidental Subscriptions (Ghost Subscriptions)**: Helper functions or logging statements that inspect properties inadvertently register unwanted reactive dependencies.

### 5.2 Architectural Guarantees of `WhatVia`

* **Compile-Time Traceability**: Dependencies are declared explicitly through the injected `via(...)` handle, enabling static analysis and linter verification (`avoid_untracked_what_read`).
* **Synchronous Epoch Confinement**: Graph edges are linked strictly within synchronous evaluation passes, guaranteeing immunity to asynchronous context leaks.
* **Automatic Short-Circuit Gating**: Calling `via(source)` evaluates upstream state. If the target is non-data, `via` throws `_ViaShortCircuit` immediately, terminating downstream execution before arithmetic errors or null-pointer crashes occur.

---

## 6. Core Engineering Invariants

1. **Capability Boundary Invariant**:  
   Producer interfaces (`WhatController`, `RawWhatController`, `WhatSignalController`) and observation interfaces (`What`, `WhatSignal`) are distinct types; downcasting from consumer to producer is impossible by design.
2. **Distinct vs. Raw Invariant**:  
   `WhatController` enforces shallow equality filtering (`distinct: true`) to suppress duplicate downstream pulses; `RawWhatController` bypasses equality checks for high-throughput and in-place mutable collections.
3. **Total Derivation Isolation Invariant**:  
   All exceptions within user computation closures are captured via `_WhatState.fromCaught()`; zero user exceptions escape `_pull()`.
4. **Self-Healing Recovery Invariant**:  
   Nodes in error states recover automatically to valid data states upon upstream input normalization on the subsequent pull turn without manual intervention.
5. **Two-Tier Error Telemetry Invariant**:  
   Terminal and lifecycle uncaught errors are dispatched to active terminal handlers and `LpdagUncaughtErrorHandler.instance` without halting DAG processing.
6. **Explicit Manifest Invariant**:  
   Reactive dependencies are registered exclusively through injected `WhatVia` instances and never via ambient global state.

---

## 7. Engineering Conclusions

The **Capability-Based Encapsulation & Fault-Tolerant Exception Isolation** architecture provides an unyielding foundation for enterprise software engineering:

1. **Structural Enforcement of Unidirectional Data Flow**: Strict type separation between producers and consumers eliminates accidental mutations and downcasting exploits at compile time.
2. **Resilience to Runtime Failures**: By encapsulating exceptions into first-class FSM states at the engine evaluation boundary, What completely prevents graph poisoning, zombie nodes, and cascading UI crashes.
3. **Automated Self-Healing**: Pipelines recover effortlessly from transient failures as upstream dependencies settle, eliminating tedious manual error recovery code.
