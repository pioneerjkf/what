# Algebraic State Protocol & Self-Healing Fault Tolerance Specification
## (Algebraic 3-State FSM, Topology-Preserving Fault Isolation, Zero-Ceremony Self-Healing, and Software 3.0 Determinism)

> **"A reactive graph without a rigorous state algebra is merely a fast pipe for unhandled crashes. True architectural reliability demands that errors and uninitialized states are first-class mathematical entities, completely isolated from engine mechanics, preserving topology under failure, and self-healing the instant inputs normalize."**  
> — *What Framework Core Systems Group*

---

## 1. Overview & Background: The Flaws of Primitive Value Containers

Standard reactive frameworks (Rx, Flutter's `ValueNotifier`, generic Signals ports, and early state libraries) model reactive nodes as **primitive value containers (`T value`)**. In complex real-world applications, this primitive model introduces severe architectural pathologies:

```text
[Failure Cascade in Traditional Reactive Systems]
Upstream Source Throws Exception (e.g. FormatException / NullCheckError)
                           │
                           ▼
Uncaught Exception Escapes Call Stack ──► Destroys DAG Scheduler & Widget Tree
                           │
                           ▼
Node Leaves State Uninitialized (null) ──► Permanent "Poisoned Zombie Node"
                           │
                           ▼
Dynamic Branch Tracking Corrupted ──► Stale Edges Severed Incorrectly
                           │
                           ▼
Manual Intervention Mandated (ref.invalidate / retry ceremony required)
```

1. **The Null Ambiguity Dilemma**:  
   When storing nullable types (`User?`), primitive containers cannot distinguish between `null` as a valid domain payload vs. `null` as an uninitialized or dormant state.
2. **Cascading Exception Storms**:  
   In eager-push architectures, an uncaught exception in a derived calculation instantly traverses the active subscriber tree, executing dozens of downstream selectors and throwing redundant exception logs that freeze the UI thread.
3. **Poisoned Zombie Nodes**:  
   When a user calculation crashes during evaluation, internal tracking variables are left dirty or null. The node becomes an unrecoverable "zombie", requiring manual developer ceremony (`ref.refresh()`, `bloc.add(RetryEvent())`) or a full application restart.
4. **Topology Corruption Under Failure**:  
   In dynamic branching (`condition ? a : b`), an exception midway through computation causes the tracking engine to miscalculate dependencies, permanently severing healthy upstream edges and leaving downstream nodes stranded.

The What Framework resolves these structural defects through the **[`WhatState`](../../lib/src/what/state.dart#L94)** Universal Reactive State Protocol and a deterministic **3-State Algebraic Finite State Machine (FSM)**.

---

## 2. The Universal State Protocol & 3-State Algebraic FSM

In the What Framework, state observation is standardized through the **[`WhatState<T>`](../../lib/src/what/state.dart#L94)** Universal Reactive State Protocol. 

Imperative state controllers ([`WhatController`](../../lib/src/what/controller.dart)), immutable snapshots ([`WhatSnapshot`](../../lib/src/what/snapshot.dart)), consumer terminals ([`RawWhatTerminal`](../../lib/src/engine/terminal.dart#L182)), domain computations ([`Computation`](../../lib/src/what/computed.dart#L468)), and untracked state views ([`untracked.state(what)`](../../lib/src/what/untracked.dart)) all implement the [`WhatState`](../../lib/src/what/state.dart#L94) protocol.

*(Note: [`What`](../../lib/src/what/what.dart) itself is an opaque handle with zero public read getters. Reading raw values or inspecting states outside tracking scopes is provided via the symmetrical [`untracked(what)`](../../lib/src/what/untracked.dart) and [`untracked.state(what)`](../../lib/src/what/untracked.dart) functors).*

```text
                    ┌────────────────────────────────────────┐
                    │   WhatState<T> 3-State State Machine   │
                    └────────────────────────────────────────┘
                           │ (Initial uninitialized / dormant)
                           ▼
                    ┌──────────────┐         Value Resolved        ┌──────────────┐
                    │    EMPTY     │ ────────────────────────────> │     DATA     │ (hasData == true)
                    │  (isEmpty)   │ <──────────────────────────── │  (payload:T) │
                    └──────┬───────┘       .empty([reason])        └──────┬───────┘
                           │                                              │
                           │ .setError()                      .setError() │
                           ▼                                              ▼
                    ┌─────────────────────────────────────────────────────────────┐
                    │                            ERROR                            │ (hasError == true)
                    │              (payload: Object, [StackTrace])                │
                    └─────────────────────────────────────────────────────────────┘
```

### 2.1 State Invariants

An entity governed by [`WhatState<T>`](../../lib/src/what/state.dart#L94) resides strictly within one of three mutually exclusive states:

* **Data State (`hasData == true`)**:  
  Holds a valid payload of type `T`. For nullable types (`T?`), `null` is a completely valid data payload and never transitions the node to `Empty`.
* **Empty State (`isEmpty == true`)**:  
  Represents an uninitialized, awaiting, or dormant state. It carries an optional diagnostic `emptyReason` (such as `'AwaitingAuthCredentials'`) to provide causal explainability across complex pipelines.
* **Error State (`hasError == true`)**:  
  Encapsulates failure directly as a first-class state entity, containing the uncaught `Object error` and optional `StackTrace stackTrace`.

### 2.2 Sound Fail-Fast vs. Safe Extraction & Pattern Matching

To eliminate silent null propagation while preventing unhandled app crashes, [`WhatState`](../../lib/src/what/state.dart#L94) provides multiple extraction tiers:

```dart
final what = WhatController<String>('Alice').what;

// 1. Fail-Fast Extraction (untracked)
// Throws WhatSnapshotExtractionException immediately if isEmpty or hasError
final value = untracked(what);

// 2. Safe Fallback Extraction via WhatState view (untracked.state)
final state = untracked.state(what);
final safeValue = state.dataOrNull ?? 'Guest';
final fallbackValue = state.dataOrElse(() => 'Default');

// 3. Zero-Heap Total Pattern Matching (Compiler-Verified Exhaustive)
final label = state.match(
  data: (v) => 'Active: $v',
  empty: () => 'Awaiting input: ${state.emptyReason ?? "none"}',
  error: (err, stack) => 'Failed: $err',
);

// 4. Sealed Snapshot Matching in Dart 3
final display = switch (what.snapshot) {
  WhatSnapshot(hasData: true, data: final val) => 'User: $val',
  WhatSnapshot(isEmpty: true, emptyReason: final reason) => 'Waiting: $reason',
  WhatSnapshot(hasError: true, error: final err) => 'Error: $err',
};
```

---

## 3. Total Fault Isolation & Non-Escaping Invariants

The core engine implements strict exception sandboxing across every derivation boundary ([`_PullResolver`](../../lib/src/engine/_internal/_pull.dart) and [`_ComputedPullMixin`](../../lib/src/what/_internal/_computed.dart)):

```dart
// packages/what/lib/src/what/_internal/_computed.dart
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

### 3.1 Non-Escaping Invariant
No exception thrown within user closures (`_compute`, `create`, `update`, `guard`) is permitted to escape the `_pull()` evaluation boundary into the LPDAG engine or the Flutter build pipeline.

* **Short-Circuit vs. Failure Demarcation**:
  - When `error is _ViaShortCircuit`:  
    The short-circuit sentinel (thrown when `via(node)` reads an unready `Empty` or `Error` dependency) is unpacked cleanly via [`_WhatState.fromCaught()`](../../lib/src/what/_internal/_state.dart#L114). Because `succeeded = true`, `_endEpoch` sweeps obsolete edges up to the point of short-circuit, and retypes the state via `_retype<T>()` with **zero memory reallocations**.
  - When an unexpected user exception escapes (`error is! _ViaShortCircuit`):  
    It is encapsulated within `_ErrorWhatState<T>(error, stackTrace)`. Crucially, `succeeded = false` ensures that existing dependency edges are **frozen**, preventing premature disconnection of healthy upstream sources.
* **Engine Stability**: Exceptions do not crash the DAG scheduler or poison internal state into `null`.
* **Declarative Propagation**: Failures travel downstream purely as **first-class state data**.

### 3.2 Cascading Storm Immunity via 2-Phase LPDAG
In the **Push-Dirty Phase (Phase 1)**, an error transition emits only a lightweight dirty notification pulse downstream. Zero computation or exception throwing occurs during the push turn.

In the **Lazy-Pull Phase (Phase 2)**, only nodes actively observed by connected terminals evaluate on-demand. Unobserved or background derivations incur zero CPU cycles and produce zero redundant log spam.

---

## 4. Topology Preservation Under Failure (`succeeded: false`)

In dynamic derivations (`computed`, `switched`), branching conditions shift dependencies across evaluation turns:

```dart
final useRemote = WhatController(true).what;
final remoteSource = WhatController('remote').what;
final localSource = WhatController('local').what;

final branch = computed((via) {
  if (via(useRemote)) {
    return via(remoteSource); // If remoteSource throws FormatException!
  }
  return via(localSource);
});
```

### 4.1 The Partial Evaluation Vulnerability
If an exception occurs after reading `useRemote` but before reading `remoteSource`, standard reactive engines executing naive set diffing or intermediate sweeping would assume unread dependencies are obsolete, prematurely unlinking healthy upstream edges.

### 4.2 The 1-Pass Sweep Skip Invariant
The What Framework guards dynamic topology via the `succeeded` epoch flag:

```dart
// packages/what/lib/src/engine/_internal/_via.dart
@pragma('vm:prefer-inline')
void _endEpoch(int currentEpoch, {required bool succeeded, required bool commitVersions}) {
  _cursor = null;
  if (succeeded) {
    _sweepObsoleteEdges(currentEpoch, commitVersions: commitVersions);
  }
  // When succeeded == false:
  // Edge unlinking is completely aborted! The existing topology remains frozen.
}
```

* **Topological Freezing**: When evaluation fails, 1-pass epoch sweeping is completely bypassed.
* **Zero Ghost Disconnects**: Upstream dependency edges remain intact in the intrusive doubly-linked list.
* **Instant Recovery**: The moment upstream inputs normalize, the next evaluation turn successfully re-reads the full dependency path without topological amnesia.

---

## 5. Zero-Ceremony Self-Healing Dynamics

In the What Framework, an error state is strictly defined as a **transient cached projection of current upstream inputs**, rather than a terminal failure state.

```text
[Self-Healing Lifecycle Flow]
Upstream Error Input ──► Downstream Evaluates to _ErrorWhatState (Isolated)
                                  │
Upstream Fixes Input (controller.data = validData)
                                  │
                                  ▼
Push-Dirty Pulse Propagates (Phase 1 Invalidation)
                                  │
                                  ▼
Subsequent Lazy-Pull on Next Frame / Access (Phase 2)
                                  │
                                  ▼
Downstream Re-evaluates Automatically ──► Recovers to _ValidWhatState (Self-Healed!)
(No ref.invalidate, no retry loops, zero manual reset ceremony)
```

1. **Zero Reset Ceremony**:  
   Developers never need to call `clearError()`, `retry()`, or `reset()`. The act of mutating the upstream source with valid data automatically invalidates the downstream cache.
2. **Transparent Downstream Propagations**:  
   Any downstream node observing an upstream error automatically transitions to an error state or holds in a guarded `Empty` state, and automatically resolves to `Valid` the instant the root source recovers.

---

## 6. Zero-Allocation Interrogation & Multi-Guarding

### 6.1 Dart AOT Devirtualization (Single-Instruction Dereference)
While [`WhatState`](../../lib/src/what/state.dart#L94) is exposed publicly as an open abstract interface, internal node implementations bridge through [`_WhatStateMixin`](../../lib/src/what/_internal/_state.dart#L34) to a strictly closed, library-private sealed container (`_WhatState<T>`):

```dart
// packages/what/lib/src/what/_internal/_state.dart
// Monomorphic field access proved by Dart AOT Type Flow Analysis (TFA)
base mixin _WhatStateMixin<T> implements WhatState<T> {
  _WhatState<T> _read();

  @override
  @pragma('vm:prefer-inline')
  T get data => _read().data; // Compiles to single CPU movq offset(%rax), %rax
}
```

Outside derivation scopes, reading `.data` or `.hasData` is devirtualized into a single CPU memory dereference with **zero VTable dispatch overhead, zero dynamic tracking lookup, and zero heap allocation**.

### 6.2 Zero-Heap Record Tuple Multi-Guards
To protect complex multi-input derivations from evaluating amidst upstream errors or uninitialized states, What provides compile-time extensions across Dart 3 Record tuples (arity 2 through 9 via [`WhatStateRecord2Extension`](../../lib/src/what/state.dart#L345) to [`WhatStateRecord9Extension`](../../lib/src/what/state.dart#L660)):

```dart
final a = WhatController(1).what;
final b = WhatController(2).what;
final c = WhatController(3).what;

final total = computed(
  (via) => via(a) + via(b) + via(c),
  // Zero-Heap Record Multi-Guard: evaluates on CPU registers & call stack
  guard: (via) => (via.state(a), via.state(b), via.state(c)).guarded('AwaitingInputs'),
);
```

* **No Collection Wrappers**: Evaluates across tuple fields (`$1.hasData && $2.hasData && $3.hasData`) without allocating temporary `List` or `Set` objects on the heap.
* **Preemptive Computation Abort**: If any upstream entity enters an Error or Empty state, the heavy derivation closure is aborted at the threshold, preventing downstream exception propagation and preserving CPU cycles.

---

## 7. Software 3.0 & AI-Agentic Determinism

The architectural decisions in [`WhatState`](../../lib/src/what/state.dart#L94) provide a profound advantage when interacting with **autonomous AI coding agents** (e.g. Claude, Cursor, Antigravity, Copilot):

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Software 3.0 / AI-Native Determinism                 │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. Elimination of State Machine Explosion                             │
│     - AI cannot introduce "forgot-to-reset-error" flag desync bugs.    │
│     - Self-healing is an inherent engine invariant.                    │
│                                                                        │
│  2. Compiler-Enforced Exhaustiveness (match / sealed switch)           │
│     - Missing error or empty branches trigger static compile errors.   │
│     - AI agents self-correct in a closed 1-shot loop.                  │
│                                                                        │
│  3. Explicit AST Signatures (WhatVia)                                  │
│     - Eliminates ambient rules (Rules of Hooks, Provider scopes).      │
│     - Pure, deterministic AST tokens verified by what_lints.           │
│                                                                        │
│  4. Structural Debugging via Sandboxed Snapshots                       │
│     - Failures yield precise ErrorWhatSnapshot telemetry rather        │
│       than catastrophic unhandled runner crashes.                      │
│     - AI diagnoses root causes with 100% signal clarity.               │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Eradication of State Desynchronization**:  
   In traditional frameworks, AI code generation frequently suffers from subtle bugs where `isLoading`, `isError`, and `data` flags get out of sync. Under [`WhatState`](../../lib/src/what/state.dart#L94), the 3 states are mutually exclusive at the type level, eliminating hallucinated state combinations.
2. **Compiler-Driven 1-Shot Self-Correction**:  
   Because [`WhatStateMatchExtension.match`](../../lib/src/what/state.dart#L207) and sealed snapshots demand exhaustive handling of `data`, `empty`, and `error`, any omission is flagged immediately by `dart analyze`. The AI agent receives an unambiguous compiler error and corrects the code in a single prompt turn.
3. **High Token Density**:  
   Complex multi-state resource bindings are expressed in 3 to 5 lines of declarative code rather than 80+ lines of Redux/Bloc boilerplate. Lower token counts dramatically reduce LLM attention degradation and context drift.

---

## 8. Core Engineering Invariants

| # | Invariant Name | Mathematical / Topological Rule | Verification Mechanism |
| :---: | :--- | :--- | :--- |
| **I** | **3-State Algebraic Exclusivity** | State space is partitioned into strictly disjoint subsets: $\mathcal{S} = \text{Data} \sqcup \text{Empty} \sqcup \text{Error}$. | Enforced by private sealed class `_WhatState<T>` and compiler-verified exhaustive branches. |
| **II** | **Nullable Payload Integrity** | For nullable type $T?$, $v = \text{null} \implies v \in \text{Data}$. `null` is never conflated with `Empty`. | Validated by `WhatSnapshot<String?>(null).hasData == true`. |
| **III** | **Non-Escaping Isolation** | All runtime exceptions within compute/create/guard closures are captured within `_ErrorWhatState<T>`. | Verified by try-catch sandboxing in `_ComputedPullMixin._pull()`. |
| **IV** | **Topological Freezing on Failure** | $succeeded = \text{false} \implies \text{abort}(\_sweepObsoleteEdges)$. Graph edges remain intact during errors. | Enforced by `_endEpoch` check on `succeeded` flag in `_via.dart`. |
| **V** | **Zero-Ceremony Self-Healing** | Normalization of root source automatically resolves downstream error caches to valid data on subsequent lazy pull. | Validated by LPDAG 2-Phase dirty pulse invalidation and pull resolution. |
| **VI** | **Zero-Overhead Interrogation** | Reading `.data` or `.hasData` outside derivation scopes compiles to monomorphic field dereferences. | Proved by Dart AOT TFA devirtualization and benchmark suite tests. |
