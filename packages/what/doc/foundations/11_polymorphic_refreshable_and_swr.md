# Polymorphic Refreshable Pipeline & Zero-Boilerplate SWR Specification
## (Polymorphic Refreshable Pipeline, SWR Buffering, and Honest Fault Propagation)

> **"A refreshable reactive pipeline that preserves stale data during recomputations: zero-boilerplate Stale-While-Revalidate (SWR) buffering, decoupled pending facet synchronization, and honest fault propagation under the 3-state algebraic protocol."**  
> — *What Framework Core Systems Group*

---

## 1. Background: The Structural Limits of Traditional Asynchronous Refreshing

Implementing pull-to-refresh, background revalidation, or manual data recomputation in modern GUI applications typically incurs excessive ceremony and architectural fragility:

1. **State Mutation Boilerplate**: Engineers author and orchestrate manual `fetchData()`, `refresh()`, and `retry()` methods across disparate service or store classes.
2. **Layout Flashing & Spinner Churn**: Setting an intermediate `isLoading = true` flag during recomputation tears down active UI layouts to render loading spinners. This destroys scroll positions, loses focus, and induces severe screen flicker.
3. **Compound Coordination Tax**: In pipelines combining derived nodes (`computed`), dynamic branches (`switched`), and external handles (`managed`), tracking which node requires re-evaluation and coordinating decoupled loading spinners becomes mathematically unmanageable.

---

## 2. Core Architecture: SWR Pipelines and Reactive Re-evaluation

The What Framework resolves these limits through **`.retained()` Stale-While-Revalidate (SWR) buffering** and **declarative signal invalidation**, enabling any reactive node to refresh asynchronously without UI layout thrashing.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        SWR Pipeline Architecture                       │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [Upstream Query Source] ──► .retained(pending: isPendingCoupler)     │
│   (e.g. computed.future)                  │                            │
│                                           ▼ (Presents Stale Data)      │
│   [UI / Builder Terminal] ◄── [Buffered What<T> (Zero Layout Flash)]   │
│                                           │                            │
│   [Refresh Trigger] ───────► refreshSignal.emit() / controller.data =  │
│                              (Synchronous Phase 1 Push-Dirty Signal)   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Uniform Node Invalidation & Re-evaluation
* **`computed.future`**: When upstream dependencies mutate or refresh signals emit, prior futures are detached and fresh queries are dispatched. Intermediate unresolved states emit `WhatSnapshot.empty`.
* **`managed`**: Upstream changes trigger in-place `update` callbacks or synchronous teardown and recreation.
* **`switched`**: Replaces the active dependency branch atomically while preserving downstream continuity.
* **`WhatCoupler`**: Relays an external or dynamically discovered node, detaching previous subscriptions upon substitution.

### 2.2 First-Class Signal Dependency Manifest (`via(signal.what)`)
The framework eliminates bespoke refresh interfaces or lifecycle mixins. Producers create a [WhatSignalController] handle and expose its read-only [WhatSignalController.what] view. Consumers register a dependency on the signal via `via(refreshSignal.what)` inside computation closures:

```dart
final refreshSignal = WhatSignalController();

// Explicit dependency tracking via WhatVia:
final userProfile = computed.future((via) {
  via(refreshSignal.what); // Automatically marks dirty & refetches when emitted!
  return fetchProfile(via(userId.what));
});
```

When `refreshSignal.emit()` is called, the Push-Dirty signal propagates synchronously through the DAG. Downstream subscribers lazily re-evaluate on demand.

---

## 3. Zero-Boilerplate SWR (Stale-While-Revalidate)

Appending `.retained()` to any reactive pipeline unlocks **Stale-While-Revalidate (SWR)** caching in a single declarative expression:

```dart
// 1. Signal-based refresh trigger (Producer handle)
final refreshSignal = WhatSignalController();

// 2. Asynchronous data query pipeline
final userFeed = computed.future((via) {
  via(refreshSignal.what);
  return api.fetchUserTimeline();
});

// 3. Promoted to an SWR buffered node with a dedicated pending facet coupler
final isPendingCoupler = WhatCoupler<bool>.late();
final bufferedFeed = userFeed.retained(pending: isPendingCoupler);
final isPending = isPendingCoupler.what;
```

### 3.1 Lifecycle Under Successful Revalidation

```text
[Refresh Triggered] ──► refreshSignal.emit()
                              │
                              ▼
           ┌─────────────────────────────────────┐
           │ bufferedFeed (SWR Retained Data)    │
           │  * hasData: true                    │
           │  * data: 'Retains stale payload'    │
           │                                     │
           │ isPending (Pending Facet Pipeline)  │
           │  * data: true                       │
           └─────────────────────────────────────┘
                              │
                    [Network Fetch Complete]
                              ▼
           ┌─────────────────────────────────────┐
           │ bufferedFeed (Settled Fresh State)  │
           │  * hasData: true                    │
           │  * data: 'Transitions to fresh data'│
           │                                     │
           │ isPending (Pending Facet Pipeline)  │
           │  * data: false                      │
           └─────────────────────────────────────┘
```

1. **Zero Layout Flash**: While background queries fetch fresh data (during which upstream emits an intermediate `Empty` state), `.retained()` intercepts the empty state and presents the last known `Valid` snapshot.
2. **Decoupled Loading Indicators**: Presentation widgets observe `isPending.data` independently to display non-intrusive progress bars or pull-to-refresh spinners without tearing down active views.

---

### 3.2 Honest Fault Propagation & Error Disjointness

In the What Framework, state representation is governed by the **3-State Algebraic Protocol** ($Empty \oplus Valid \oplus Error$). States are strictly mutually exclusive: a node cannot simultaneously possess valid data and an active error.

Naively attempting to preserve stale cache data during an active error corrupts system semantics and conceals runtime failures from error boundaries.

The engine's `_RetainedWhat` node strictly enforces **Honest Fault Propagation**:

```text
[Refresh Triggered] ──► Upstream in-flight re-evaluation (Pending: true)
                                │
                                ▼
           [Revalidation Fails with Exception / Error]
                                │
                                ▼
           ┌─────────────────────────────────────┐
           │ bufferedFeed (Synchronously Cleared)│
           │  * hasData: false                   │
           │  * hasError: true                   │
           │  * error: NetworkException(...)     │
           │                                     │
           │ isPending (Pending Facet Pipeline)  │
           │  * data: false                      │
           └─────────────────────────────────────┘
```

1. **Synchronous Cache Clearance**: When upstream evaluates to an `_ErrorWhatState`, `_RetainedWhat` synchronously clears `_retainedState = null` and surfaces the error immediately.
2. **Immediate Pending Reset**: The pending facet transitions synchronously to `false`, ensuring spinners do not hang indefinitely.
3. **Resilient Domain Fallback**: If an application requires offline fallback behavior, it must be declared explicitly in userland via error handling combinators or secondary cache nodes, rather than by falsifying core state contracts.

---

## 4. Pure Dart Observation Example

In pure Dart environments (CLI tooling, background workers, domain services), `Effect.via` combined with `EffectRunExtension.run` observes SWR pipeline transitions with zero-overhead short-circuiting:

```dart
import 'dart:async';
import 'package:what/what.dart';
import 'package:what/effect.dart';

void main() async {
  // 1. Pipeline configuration
  final refreshSignal = WhatSignalController();
  final userFeed = computed.future((via) async {
    via(refreshSignal.what);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return 'User Feed Snapshot';
  });

  final isPendingCoupler = WhatCoupler<bool>.late();
  final bufferedFeed = userFeed.retained(pending: isPendingCoupler);
  final isPending = isPendingCoupler.what;

  // 2. Register standalone SWR runner (activates pipeline and dispatches initial query)
  final runner = Effect.via((via) {
    final pending = via(isPending);
    final state = via.state(bufferedFeed);

    if (pending) {
      print('[SWR] Background revalidation in progress... (Current: ${state.dataOrNull})');
    } else if (state.hasData) {
      print('[SWR] Settled data: ${state.data}');
    } else if (state.hasError) {
      print('[SWR] Revalidation error: ${state.error}');
    }
  }).run();

  // 3. Trigger asynchronous refresh
  refreshSignal.emit();

  // Wait for asynchronous query to settle
  await Future<void>.delayed(const Duration(milliseconds: 20));

  // 4. Teardown when complete
  runner.deactivate();
}
```

---

## 5. Core Architectural Invariants

The Polymorphic Refreshable & SWR subsystem adheres to five foundational invariants:

1. **Stale-While-Revalidate Data Continuity (Zero-Flicker Invariant)**:
   Intermediate `Empty` states occurring during upstream re-evaluation or refresh are masked; the node retains the prior valid data payload to eliminate UI layout thrashing.
2. **Honest Fault Propagation (Error Disjointness Invariant)**:
   Upstream errors immediately clear the retained cache, transition the node to `hasError: true`, honestly propagate the exception downstream, and synchronously reset `isPending` to `false`.
3. **Independent Pending Facet Decoupling**:
   An independent `WhatCoupler<bool>` facet dynamically synchronizes with internal pending states without coupling to the data payload's value equality or triggering redundant version increments.
4. **Subscriber-Driven Inactive Dormancy**:
   When all downstream subscribers detach (subscriber count = 0), the retained pipeline suspends evaluations and timer emissions under standard subscriber-driven dormancy.
5. **Topological Glitch-Freedom in Diamond Topologies**:
   In diamond dependency graphs where downstream observers read both the retained data node and the pending facet, both facets evaluate consistently within a single synchronous turn without intermediate glitch states.

---

## 6. Engineering Conclusions

The **Polymorphic Refreshable Pipeline & SWR Buffering** architecture resolves the tension between dynamic asynchronous recomputation and GUI presentation stability.

By decoupling the pending facet via `WhatCoupler<bool>` and masking intermediate `Empty` transitions while strictly upholding **Honest Fault Propagation**, the What Framework provides effortless, zero-flicker Stale-While-Revalidate caching without compromising algebraic state integrity.
