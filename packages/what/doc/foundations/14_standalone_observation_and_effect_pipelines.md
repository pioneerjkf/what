# Standalone Observation & Side-Effect Pipelines Specification
## (Declarative Effect Contracts, Standalone EffectRunner Lifecycle, 1-Tick Microtask Batching, and RAII Resource Cleanups)

> **"A reactive framework bound exclusively to UI widget trees is only half-engineered. Backend services, CLI utilities, and headless workers require glitch-free observation and safe side-effect dispatching."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Need for UI-Independent Reactivity

Traditional state management frameworks couple deeply to UI component lifecycles (e.g., Flutter's `State.initState`/`dispose`, React's `useEffect`). However, robust application architecture requires reactive processing outside rendering hierarchies:

1. **Background Services & Domain Layers**:  
   Tracking hardware sensors, authentication session expirations, web sockets, and background sync workers without mounted UI elements.
2. **Pure Dart VM Runtimes (CLI, Backend Services)**:  
   Observing LPDAG state transitions and triggering I/O in environments without a Flutter `BuildContext` or render tree.
3. **Differentiating Observation from Action Dispatch**:  
   Failing to separate state observation from external mutation risks re-entrant loops, notification storms, and race conditions.

The What Framework resolves this with **Declarative Side-Effects ([`Effect`](../../lib/src/effect/effect.dart))** and **Standalone Runners ([`EffectRunner`](../../lib/src/effect/runner.dart))**, backed by **1-Tick Microtask Batch Compression ([`_Scheduler`](../../lib/src/engine/_internal/_scheduler.dart))**.

---

## 2. Taxonomy: Declarative Effects vs. Imperative Execution

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Observation vs. Side-Effect Taxonomy                 │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Domain 1: Declarative Side-Effect (Effect) ]                       │
│   • Core Class: Effect (extends Tether)                                │
│   • Modalities: Manifest Unary/N-ary, Handled, Dynamic via, Groups    │
│   • Terminal Engines: _UnaryManifestEffectTerminal, _ViaEffectTerminal │
│   • Invariant: Terminal execution sink, zero data production,          │
│                reference-counted scope lifecycle                       │
│                                                                        │
│   [ Domain 2: Standalone Imperative Execution (EffectRunner) ]         │
│   • Core Class: EffectRunner (implements RawTerminal)                  │
│   • Purpose: Imperative lifecycle control outside UI tethers           │
│   • Invocation: effect.run(), runner.activate(), runner.deactivate()   │
│   • Invariant: Subscriber-driven dormancy, true dormancy when all      │
│                tethers and runners detach                              │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 The Declarative Effect Hierarchy (`Effect`)
Every side-effect in What is represented as a declarative blueprint extending `Tether`:

1. **Manifest Unary (`Effect.unary`, `target.effect(...)`)**:  
   Bound strictly to a single `What<T>` target. Skips initial evaluation on mount and executes upon subsequent mutations.
2. **Manifest N-ary (`Effect(...)`, `targets.effect(...)`, `(a, b).effect(...)`)**:  
   Bound to an explicit collection or Dart 3 Record tuple of targets (`What` nodes).
3. **Handled Manifest (`Effect.handled`, `Effect.handledUnary`)**:  
   Provides an [`EffectHandle`](../../lib/src/effect/effect.dart) for cleanups (`onCleanup`), execution turn status flags (`isActive`, `isCancelled`), and RAII lifecycle teardowns.
4. **Dynamic Discovery (`Effect.via`, `Effect.handledVia`)**:  
   Explicit dependency discovery via `WhatVia` with 1-pass monotonic epoch sweeping.
5. **Rate-Limited Sinks (`DebounceEffect`, `ThrottleEffect`)**:  
   Time-domain rate limiting with configurable `leading` and `trailing` edge policies.
6. **Composite Groups (`EffectGroup`, `Effect.group(...)`, `(e1, e2).group()`)**:  
   Coordinates multiple constituent effects as a single composite lifecycle terminal.

### 2.2 Standalone Imperative Execution (`EffectRunner`)
While declarative `Effect` instances are typically bound to tracking scopes via `via.tether(effect)`, an [`EffectRunner`](../../lib/src/effect/runner.dart) controls execution imperatively in services, ViewModels, or CLI daemons:

```dart
// packages/what/lib/src/effect/runner.dart
abstract interface class EffectRunner implements RawTerminal {
  factory EffectRunner(Effect effect, {bool autoStart}) = _EffectRunnerImpl;

  @override
  void activate();

  @override
  void deactivate();

  Effect get effect;

  @override
  bool get isActive;
}
```

---

## 3. Microtask Batch Compression Mechanics (`_Scheduler`)

When upstream sources mutate repeatedly within a single event loop turn, invoking listeners synchronously on every mutation causes notification storms, UI layout thrashing, and transient glitches.

All `Effect` terminals mix in [`_ScheduledTerminalMixin`](../../lib/src/engine/_internal/_terminal.dart), routing invalidations through the central [`_Scheduler`](../../lib/src/engine/_internal/_scheduler.dart):

```dart
// packages/what/lib/src/engine/_internal/_terminal.dart
base mixin _ScheduledTerminalMixin on _Terminal implements _TerminalSchedulable {
  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    if (!_lifecycle.isActive) return;
    _Scheduler.instance._scheduleTerminal(this);
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _Scheduler.instance._cancelTerminal(this);
    super._deactivate();
  }
}
```

```text
[Same Synchronous Event Loop Turn]
  counter.set(1);
  counter.set(2);
  counter.set(3);
        │
        ▼ (Push-Dirty Invalidation)
  _ScheduledTerminalMixin._invalidate()
        │
        ▼ (Enqueues into _Scheduler._terminalSet)
  _scheduleTerminal(this) -> scheduleMicrotask(_taskHandler)
        │
        ▼ (Microtask Execution Pass: Settles before frame render)
  _TerminalSchedulerMixin._onTask()
        │
        ├─► 1. Verify target._lifecycle.isActive
        ├─► 2. _DirtySyncable._resolveDirty() -> Abort if upstream didn't actually change
        └─► 3. target._performScheduled() -> Invokes action() exactly ONCE with latest value '3'!
```

### 3.1 Linearized Scheduler Execution Sequence
The central [`_Scheduler`](../../lib/src/engine/_internal/_scheduler.dart) coordinates batch execution across five strictly linearized phases:
1. `_SchedulerBase`: Resets `_isScheduled = false`.
2. `_CoalescedSchedulerMixin`: Flushes trailing coalesced state pulses (`what.coalesced()`) in the DAG first.
3. `_EagerSchedulerMixin`: Resolves eager dynamic routing nodes (`computed.future`, `computed.stream`, `switched`) next.
4. `_TerminalSchedulerMixin`: Flushes active scheduled terminals (`Effect`, `DebounceEffect`, `ThrottleEffect`).
5. `_GracefulSchedulerMixin`: Executes deactivation cleanups (`_MicrotaskGraceHandle`) LAST.

> [!NOTE]
> **Why Graceful Deactivation Runs Last**: Active effects running in the current microtask tick may observe or depend on resources whose subscribers dropped to zero during this epoch. Executing effects first guarantees that resources remain valid throughout effect evaluations, and are only gracefully deactivated after all scheduled side-effects have completed.

---

## 4. Inactive Dormancy and RAII Lifecycle Cleanups

### 4.1 Subscriber-Driven Inactive Dormancy
`Effect` extends `Tether`, which tracks active downstream subscribers via reference counting (`_activateOptimistically()` / `_deactivateOptimistically()`):

```dart
final sensorStream = Stream<double>.periodic(const Duration(seconds: 1), (i) => 25.0 + i);
final sensorData = computed.stream((via) => sensorStream);
final runner = sensorData.what.effect(() => print(untracked(sensorData.what))).run();

// 1. While runner is active:
//    sensorData maintains an active terminal, keeping the physical stream subscription open.

// 2. Deactivating runner:
runner.deactivate();

// 3. Immediately on deactivation:
//    Downstream count hits 0 -> sensorData cancels the stream subscription
//    and enters 0-I/O cold dormancy. Zero background leaks.
```

### 4.2 Shared Multi-Scope Ownership
If the same `Effect` instance is shared between a tracking scope (`via.tether(effect)`) and an `EffectRunner`:
* Deactivating the runner leaves the effect active as long as the tethering scope remains active.
* Unmounting the tethering scope leaves the effect active if the runner is still running.
* The underlying effect enters true dormancy only when **all** observing terminals and runners have detached.

### 4.3 Multi-Registration and RAII Safety (`EffectHandle.onCleanup`)

The [`EffectHandle`](../../lib/src/effect/effect.dart) interface enables registering teardown callbacks to be invoked when an execution turn completes or when the effect deactivates:

```dart
final roomIdWhat = WhatController('room_101').what;

final roomManager = roomIdWhat.effect.handled((handle) {
  // Resource 1: Acquired and immediately guarded
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => ping());
  handle.onCleanup(timer.cancel);

  // Resource 2: Acquired and immediately guarded
  final socket = WebSocket.connect(url);
  handle.onCleanup(socket.close);
}).run();
```

```dart
// packages/what/lib/src/effect/_internal/_base.dart
@override
void onCleanup(void Function() cleanup) {
  if (_isCancelled) {
    try {
      cleanup();
    } catch (error, stackTrace) {
      _handleUncaughtError(error, stackTrace);
    }
    return;
  }
  // Zero-Alloc Fast-Path & Closure-Chained Multi-Registration:
  // 90%+ of effects register exactly 1 cleanup (e.g. CancelToken or Timer).
  // Storing a direct callback in `_cleanup` avoids allocating a heap `List` per effect turn.
  // When multiple cleanups are registered, we recursively chain them via a synthesized
  // closure with `try-finally` to guarantee that subsequent cleanups execute even if an earlier teardown throws.
  final previous = _cleanup;
  if (previous == null) {
    _cleanup = cleanup;
  } else {
    _cleanup = () {
      try {
        previous();
      } finally {
        cleanup();
      }
    };
  }
}
```

#### Three Architectural Rationales for Multi-Registration
1. **Exception Safety during Setup**: If an exception is thrown while acquiring a subsequent resource (e.g. `WebSocket.connect` fails), previously registered cleanups (e.g. `timer.cancel`) remain securely intact and execute deterministically.
2. **Modular Subroutine Composition**: `EffectHandle` can be passed to independent helper functions (e.g. `bindCancelToken(handle)`), allowing each to register its own teardown safely without overwriting previous cleanups.
3. **Clean Conditional Branching**: Resources acquired inside `if` blocks can register their respective teardowns directly in-place without uninitialized nullable variables.

---

## 5. Record-Based Declarative Extensions & Monomorphic Scopes

The What Framework leverages Dart 3 Record extensions (arity 2 through 5) and zero-cost extension types ([`extensions.dart`](../../lib/src/effect/extensions.dart)) to provide fluent observation syntax:

```text
targets.effect                 ((action) => ...)
 ├── .handled                  ((handle) => ...)
 ├── .throttle                 (duration, (action) => ...)
 └── .debounce                 (duration, (action) => ...)
```

### 5.1 Monomorphic Extension Scopes
* **`UnaryWhatEffectScope`**: Wraps a single `What<T>` node with compile-time zero-cost abstraction, dispatching directly to monomorphic unary terminals (`_UnaryManifestEffectTerminal`, `_UnaryDebounceEffectTerminal`, `_UnaryThrottleEffectTerminal`).
* **`WhatEffectScope`**: Wraps `Iterable<What>` nodes for multi-target terminal dispatch.

### 5.2 Record Tuple Combinators
```dart
final userId = WhatController('usr_1');
final authToken = WhatController('tok_abc');
final syncStatus = WhatController('idle');

// Multi-target handled effect on 3-tuple:
final sessionRunner = (userId.what, authToken.what, syncStatus.what).effect.handled((handle) {
  final user = untracked(userId.what);
  final token = untracked(authToken.what);
  final status = untracked(syncStatus.what);
  
  final client = ApiClient.authenticate(user, token);
  handle.onCleanup(client.dispose);
}).run();
```

---

## 6. Production Code Scenarios

### 6.1 Headless CLI Daemon and Server Monitoring
```dart
import 'dart:io';
import 'package:what/what.dart';
import 'package:what/effect.dart';

enum ServerHealth { healthy, degraded, critical }

void main() async {
  final serverHealth = WhatController<ServerHealth>(ServerHealth.healthy);

  // Standalone effect running outside any UI framework
  final healthRunner = serverHealth.what.effect(() {
    final status = serverHealth.data;
    print('[Health Monitor] Server status changed to: $status');
    if (status == ServerHealth.critical) {
      triggerEmergencyAlert();
    }
  }).run();

  // Gracefully deactivate upon OS signal:
  ProcessSignal.sigterm.watch().listen((_) {
    healthRunner.deactivate();
    exit(0);
  });
}
```

### 6.2 Dynamic Conditional Side-Effects (`Effect.via` + `run()`)
```dart
import 'package:what/what.dart';
import 'package:what/effect.dart';

final speedWhat = WhatController<int>(50).what;
final limitWhat = WhatController<int>(60).what;

// Evaluates dependencies dynamically, triggering alerts only when condition holds
final speedMonitor = Effect.via((via) {
  final currentSpeed = via(speedWhat);
  final speedLimit = via(limitWhat);

  if (currentSpeed > speedLimit) {
    print('WARNING: Speed limit exceeded! ($currentSpeed > $speedLimit)');
  }
}).run();
```

### 6.3 Throttled Multi-Target Analytics Pipeline
```dart
import 'package:what/what.dart';
import 'package:what/effect.dart';

final scrollOffset = WhatController<double>(0.0);
final pageIndex = WhatController<int>(0);

// Throttled multi-target effect running standalone
final analyticsRunner = (scrollOffset.what, pageIndex.what).effect.throttle(
  const Duration(milliseconds: 200),
  () => sendAnalytics(untracked(scrollOffset.what), untracked(pageIndex.what)),
  leading: true,
  trailing: true,
).run();
```

---

## 7. Core Engineering Invariants

1. **Terminal Sink Exclusivity**:  
   Effects never produce state and never act as upstream reactive sources in the LPDAG, guaranteeing that side-effect executions cannot create infinite topological update cycles.
2. **1-Tick Microtask Batching**:  
   Multiple synchronous state mutations within a single turn collapse into a single settled evaluation at the end of the microtask pass.
3. **Upstream Priming Invariant (Zero Runs on Mount)**:  
   Manifest effect terminals synchronously prime upstream target versions upon activation without invoking action callbacks. Actions fire strictly upon subsequent mutations.
4. **Glitch-Free Diamond Consistency**:  
   In diamond topologies where multiple upstream dependencies mutate in the same turn, active effect terminals evaluate only after all state transactions settle, eliminating transient split-brain reads.
5. **Zero-Leak Inactive Cold Dormancy**:  
   Deactivating an `EffectRunner` relinquishes its subscription edge immediately. When all subscribers detach, underlying `What` sources cascade into 0-I/O dormancy.
6. **Deterministic RAII Teardown**:  
   Cleanups registered via `handle.onCleanup` execute in reverse acquisition order with recursive `try-finally` safety prior to the next evaluation turn or upon deactivation.

---

## 8. Engineering Conclusions

The **Standalone Observation & Side-Effect Pipelines** architecture delivers a universal, UI-decoupled reactive execution model for the What Framework:

1. **Freedom from UI Framework Constraints**: Decoupling effect execution from widget trees allows domain services, CLI tools, and server workers to leverage the full power of What's LPDAG reactive engine.
2. **Mathematical Invariant Guarantees**: Intrusive terminal mixins, 1-tick microtask batching, and upstream priming eliminate transient glitches, redundant layout recalculations, and false initial side-effect dispatches.
3. **Rock-Solid Resource Management**: Subscriber-driven inactive dormancy paired with multi-registration RAII cleanups guarantees zero memory leaks, zero zombie background timers, and seamless resource reclamation.

