# Two-Tier Temporal Architecture: State-Domain Smoothing vs. Effect-Domain Rate Limiting Specification
## (Temporal Dirty Gatekeeping, Microtask Coalescing, Asynchronous Silence Buffering, Upstream Priming, and Isolated Terminal Sinks)

> **"Manipulating the time domain is the most dangerous intruder into reactive synchronous consistency. Treating state stream smoothing and side-effect dispatch delays within a single unified category inevitably casts the reactive graph into topological limbo."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Collision of Temporal Operators and Synchronous LPDAGs

In reactive systems, debounce, throttle, and coalesce operators are essential for managing high-frequency user and sensor inputs (search typing, slider drags, sensor streams, window resizes). However, naively porting traditional Rx or event stream approaches directly into a synchronous **LPDAG (Lazy Push-Dirty, Pull-Evaluation Directed Acyclic Graph)** induces severe topological failures.

The What Framework's 2-Phase LPDAG strictly adheres to the **Push-Dirty ($O(1)$) + Lazy-Pull (On-Demand)** model. Attempting to delay invalidation (dirty) pulses arbitrarily inside dynamic downstream terminals causes three critical anomalies:

1. **The Initial Evaluation Dilemma**: Dynamic dependency scopes (`WhatVia`) must establish tracking edges synchronously upon mounting. If a terminal delays its initial execution, edges remain unformed (0 edges), dropping upstream mutations occurring during the delay. Conversely, if the terminal runs immediately on mount, side-effects (e.g., network queries) fire with uninitialized, empty payloads.
2. **Cache Limbo & Read-Uncommitted Anomalies**: If an upstream node mutates to a fresh version while an observing terminal holds an asynchronous timer, allowing uncommitted reads leaks intermediate, transient state to sibling UI widgets, causing split-brain presentation glitches.
3. **Engine Scheduler Pollution**: Mixing asynchronous platform `Timer` callbacks arbitrarily into the synchronous microtask batch scheduler (`_Scheduler`) breaks deterministic topological evaluation order and transactional atomicity.

To resolve these defects at the architectural level, What separates time-domain operations into two strictly decoupled tiers: the **State Domain** (Tier 1) and the **Effect Domain** (Tier 2).

---

## 2. The Two-Tier Temporal Architecture

```text
┌────────────────────────────────────────────────────────────────────────┐
│               Two-Tier Temporal Architecture in What                   │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Tier 1: State Domain ]                                             │
│   • Target: Reactive State Pipelines (What<T>)                         │
│   • Primitives: what.debounced, what.throttled, what.coalesced         │
│   • Core Class: _GatedRelayWhat<T> (Temporal Dirty Gatekeeper)         │
│   • Mechanism: Push-Dirty pulse attenuation at relay node level        │
│   • Invariant: Read-Committed Cache SSOT, Zero intermediate leak       │
│                                                                        │
│   [ Tier 2: Effect Domain ]                                            │
│   • Target: Terminal Execution Sinks (Side-Effects)                    │
│   • Primitives: DebounceEffect, ThrottleEffect, target.effect.*        │
│   • Core Class: _DebounceEffectTerminal, _ThrottleEffectTerminal       │
│   • Mechanism: Upstream Priming (0 runs on mount), Timer scheduling    │
│   • Invariant: Zero state production, Early Teardown, Clean disposal   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Tier 1: State Domain Temporal Operators (`what.debounced`, `what.throttled`, `what.coalesced`)

In the State Domain, temporal damping occurs not at terminal endpoints, but **at intermediate LPDAG relay nodes**, attenuating downstream Push-Dirty pulses before they reach consumers:

| Relay Operator | Damping Mechanism | Scheduler Foundation | Canonical Use Cases |
| :--- | :--- | :--- | :--- |
| **`what.debounced(duration)`** | Holds dirty pulse until silence period expires | Asynchronous `Timer` | Search auto-complete, window resize |
| **`what.throttled(duration)`** | Emits at most one dirty pulse per duration window | Asynchronous `Timer` | Scroll offset, sensor streams |
| **`what.coalesced()`** | Compresses multi-mutations in a single turn | **1-Tick Microtask** | Batch cascades, frame stabilization |

```text
[Upstream Source] ──(Push-Dirty: A -> B -> C)──► [_GatedRelayWhat Relay Node]
                                                          │ (Gate Closed: Holds dirty pulse)
                                                          │ (Intermediate reads return cached 'A')
                                                          ▼ (After silence / window close)
                                                 [_emitTrailing() Unlocks Gate]
                                                          │
                                                          ▼ (Push-Dirty Pulse Released: Version++)
                                             [Downstream Terminals / Consumers]
                                             (Lazy-Pull: Pulls latest state 'C' synchronously!)
```

### 3.1 The Temporal Dirty Gatekeeper (`_GatedRelayWhat<T>`)

All state-domain temporal and batching relays inherit from [`_GatedRelayWhat<T>`](../../lib/src/what/_internal/_what.dart):

```dart
// packages/what/lib/src/what/_internal/_what.dart
abstract base class _GatedRelayWhat<T> extends _StaticUnaryRelay<What<T>>
    with _WhatStateMixin<T>, _WhatPeekMixin<T>, _PullResolver<T>, _PullRelay<T>, _PushOriginMixin
    implements What<T> {
  _GatedRelayWhat(
    super.source, {
    required this.leading,
    required this.trailing,
  }) : assert(leading || trailing, 'At least one of leading or trailing must be true.');

  final bool leading;
  final bool trailing;
  bool _hasTrailingPending = false;

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _pull() => _state = _source._read();

  @pragma('vm:prefer-inline')
  void _emitTrailing() {
    _hasTrailingPending = false;
    _dirtyState = _DirtyState.dirty;
    _version++;
    _PushScope.queueOrigin(this);
  }
}
```

#### The 3-Phase Gatekeeping Lifecycle & Cache Invariant
1. **Upstream Invalidation & Suppression (Ticking Window)**:  
   When the upstream `_source` mutates, `_invalidate()` intercepts the event. Instead of marking itself dirty or propagating flags downstream, it starts or resets a timer (or microtask). During this window, `_dirtyState` remains `_DirtyState.clean`.
2. **Cache Integrity (Read Committed)**:  
   If any downstream node or external caller reads `.data`, `.peek`, `.snapshot`, or `via(node)` during this delay window, `_PullResolver._resolve` sees `_dirtyState == _DirtyState.clean`, **completely bypasses `_pull()`**, and immediately returns the previously committed cached `_state`.  
   *Guarantee*: Downstream computations (e.g. SWR, search API calls) are never contaminated by uncommitted intermediate mutations.
3. **Gate Unlocking & Push Propagation (`_emitTrailing`)**:  
   When the timer or microtask elapses, `_emitTrailing()` transitions `_dirtyState` to `_DirtyState.dirty`, bumps `_version++`, and enqueues this node into `_PushScope.queueOrigin(this)`. Only then are downstream observers marked dirty and notified to pull the fresh upstream state via `_pull()`.

### 3.2 Microtask Burst Coalescing (`_CoalescedWhat<T>`)

```dart
// packages/what/lib/src/what/_internal/_what.dart
final class _CoalescedWhat<T> extends _GatedRelayWhat<T> implements _CoalescedSchedulable {
  _CoalescedWhat(
    super.source, {
    super.leading = false,
    super.trailing = true,
  });

  bool _isCoalesceScheduled = false;
  bool _isLeadingCooldown = false;

  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    if (!_lifecycle.isActive) return;

    if (leading && !_isLeadingCooldown) {
      _isLeadingCooldown = true;
      if (!_isCoalesceScheduled) {
        _isCoalesceScheduled = true;
        _Scheduler.instance._scheduleCoalesced(this);
      }
      super._invalidate();
      return;
    }

    if (trailing) {
      _hasTrailingPending = true;
    }

    if (!_isCoalesceScheduled) {
      _isCoalesceScheduled = true;
      _Scheduler.instance._scheduleCoalesced(this);
    }
  }

  @override
  void _performCoalesce() {
    _isCoalesceScheduled = false;
    _isLeadingCooldown = false;
    if (!_lifecycle.isActive) return;

    if (_hasTrailingPending && trailing) {
      _emitTrailing();
    }
  }
}
```
* **Zero Platform Timer Overhead**: Uses Dart's microtask queue via `_Scheduler.instance._scheduleCoalesced(this)`.
* **Burst Compression**: 100 consecutive synchronous state changes within the same event loop turn collapse into exactly 1 trailing dirty notification before the rendering frame begins.

### 3.3 Debouncing & Throttling Relays (`_DebouncedWhat<T>`, `_ThrottledWhat<T>`)

```dart
// packages/what/lib/src/what/_internal/_what.dart
final class _DebouncedWhat<T> extends _TemporalRelayWhat<T> {
  _DebouncedWhat(
    super.source,
    super.duration, {
    super.leading = false,
    super.trailing = true,
  });
  ...
  @override
  void _invalidate() {
    if (!_lifecycle.isActive) return;

    if (leading && !_isLeadingCooldown) {
      _isLeadingCooldown = true;
      _cancelTimer();
      _timer = Timer(duration, _onTimerExpired);
      super._invalidate();
      return;
    }

    if (trailing) _hasTrailingPending = true;
    _cancelTimer();
    _timer = Timer(duration, _onTimerExpired);
  }
}
```
* **Configurable Edges**: Supports `leading` (immediate fire on initial mutation) and `trailing` (fire after silence window).
* **Assertion Validation**: Enforces `assert(leading || trailing)` at construction time to prevent no-op zombie relays.
* **Inactive Dormancy & Raw Reads**: When unobserved (`!_lifecycle.isActive`), reading `.peek` or `.peekState` bypasses temporal timers and synchronously resolves the latest upstream state on demand. Deactivation cancels active timers synchronously.

---

## 4. Tier 2: Effect Domain Temporal Sinks (`DebounceEffect`, `ThrottleEffect`)

The Effect Domain governs **terminal execution sinks** (analytics logging, audio/haptic feedback, disk storage, network dispatches) that produce zero reactive state and consume only side-effects:

```text
[Explicit What Target] ──(Invalidation Pulse)──► [DebounceEffect / ThrottleEffect]
                                                          │
                                                          ├── [Leading Edge: Schedules in microtask]
                                                          ├── [Cooldown: Manages isolated Timer]
                                                          ├── [Trailing Edge: Schedules on expiry]
                                                          └── [Executes untracked action() sink]
```

### 4.1 Upstream Priming Invariant (Zero Runs on Mount)

To resolve the Initial Evaluation Dilemma, all manifest effect terminals mix in [`_UnaryEffectPrimeMixin`](../../lib/src/effect/_internal/_base.dart) or [`_NaryEffectPrimeMixin`](../../lib/src/effect/_internal/_base.dart):

```dart
// packages/what/lib/src/effect/_internal/_base.dart
base mixin _UnaryEffectPrimeMixin on _Terminal, _UnaryEdgeMixin<What> {
  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _source._resolve();
    _pullVersion();
  }
}
```

* **Synchronous Edge Synchronization**: Upon activation (`_activate()`), the terminal resolves its target and synchronizes `_pulledVersion = _source._version`.
* **Zero Runs on Mount**: The action callback executes **0 times** upon construction or mounting. It fires strictly when *subsequent* mutations arrive from upstream targets.

### 4.2 Debounce & Throttle Terminal Engines

```dart
// packages/what/lib/src/effect/_internal/_base.dart
abstract base class _DebounceEffectTerminal extends _ManifestEffectTerminal {
  ...
  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    if (!_lifecycle.isActive) return;
    if (_takeLimit != null && _remaining <= 0) return;

    if (leading && !_isLeadingCooldown) {
      _Scheduler.instance._scheduleTerminal(this);
      _isLeadingCooldown = true;
    } else if (trailing) {
      _hasTrailingPending = true;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, _onDebounceTimerExpired);
  }

  void _onDebounceTimerExpired() {
    _debounceTimer = null;
    _isLeadingCooldown = false;
    if (!_lifecycle.isActive) return;
    if (_takeLimit != null && _remaining <= 0) return;

    if (_hasTrailingPending && trailing) {
      _hasTrailingPending = false;
      _Scheduler.instance._scheduleTerminal(this);
    }
  }
}
```

* **Microtask Invalidation Batching**: When edges fire (leading or trailing), the terminal schedules execution via `_Scheduler.instance._scheduleTerminal(this)`, preserving microtask batch consistency.
* **Finite Execution Guard (`take`)**: Once `_remaining <= 0`, incoming pulses are discarded and the terminal executes `deactivate()` immediately (Early Teardown).
* **Guarded Execution (`guard`)**: If `guard?.call() == false`, action execution is skipped and `take` tickets are preserved.

### 4.3 Fluent Scoped DSL (`UnaryWhatEffectScope`, `WhatEffectScope`)

Using compile-time zero-cost extension types ([extensions.dart](../../lib/src/effect/extensions.dart)), developers define debounce and throttle effects directly on `What` instances:

```dart
final searchInput = WhatController('');

// Fluent unary debounce effect:
final searchEffect = searchInput.what.effect.debounce(
  const Duration(milliseconds: 300),
  () => api.search(searchInput.what.peek),
);

// Standalone execution outside widget lifecycles:
final runner = searchEffect.run();
runner.deactivate(); // Cancels internal timer and detaches edge
```

---

## 5. Structural Contradictions in Dynamic Terminal Debouncing

Why introducing debounce directly inside dynamic tracking scopes (`WhatVia`) is mathematically contradictory:

```dart
// [Anti-Pattern] Structural contradiction when placing debounce inside dynamic tracking
effect((via) {
  // If a 300ms debounce were applied directly to this dynamic scope:
  // Should this block run immediately to register via() edges, or wait 300ms?
});
```

1. **If Execution Is Delayed**:
   - For 300ms post-mount, the block never executes.
   - `via(...)` is uncalled; the LPDAG engine has zero knowledge of which dependency edges to establish.
   - Any upstream state mutations occurring during that 300ms window are dropped silently.
2. **If Executed Immediately, Then Delayed Thereafter**:
   - Opening a search screen immediately fires a network query with an empty string `""`.
   - Conditional branches (ternary expressions) re-evaluating on asynchronous timer ticks destabilize topological graph invariants and cause race conditions.

**Definitive Engineering Principle:**
* **"What to Observe" (Topological Edge Tracking)**: Must be determined **synchronously**.
* **"When to Notify" (Notification Timing)**: Must be damped within **intermediate state relay nodes** (`what.debounced`) or **explicit manifest effect sinks** (`DebounceEffect`).

---

## 6. Core Engineering Invariants

1. **State-Effect Orthogonality**:
   - State-domain nodes always cache valid algebraic state (`_WhatState<T>`) and support on-demand Lazy-Pull.
   - Effect-domain sinks never produce state, cannot be observed via `via(effect)`, and cannot serve as upstream sources in the LPDAG.
2. **Read-Committed Dirty Gatekeeping**:
   - During active debounce/throttle cooldown periods, `_GatedRelayWhat<T>` keeps `_dirtyState == _DirtyState.clean`. Reads return the previous committed snapshot without evaluating intermediate mutations.
3. **Upstream Priming & Zero Mount Runs**:
   - Manifest effect terminals prime upstream sources on mount without executing action callbacks, eliminating initial empty-state side-effect dispatches.
4. **Zero-Leak Inactive Cold Dormancy**:
   - When downstream subscribers drop to zero, `_deactivate()` synchronously cancels active `Timer`s (`_timer?.cancel()`) or pending microtasks (`_Scheduler.instance._cancelCoalesced(this)`), guaranteeing zero memory or timer leaks.
5. **Finite Execution Safety**:
   - Effects configured with `take(n)` sever upstream edges immediately upon consuming their quota, ensuring permanent inactive dormancy.

---

## 7. Production Patterns

### 7.1 Search Autocomplete Pipeline (Debounced Query + SWR Retained)

```dart
import 'package:what/what.dart';

// 1. Source producer (Raw user keystroke input)
final searchQuery = WhatController<String>('');

// 2. State-domain debounce (Intermediate LPDAG relay node)
//    Suppresses Push-Dirty pulses for 300ms to eliminate redundant network queries
final debouncedQuery = searchQuery.what.debounced(
  const Duration(milliseconds: 300),
);

// 3. Asynchronous query pipeline with SWR retained buffering
final searchResults = computed.future((via) async {
  final query = via(debouncedQuery);
  if (query.trim().isEmpty) return <String>[];
  return apiService.fetchResults(query);
}).retained();
```

### 7.2 Sensor & Scroll Offset Rate-Limiting (Throttled Stream)

```dart
final scrollPosition = WhatController<double>(0.0);

// Throttles scroll position updates to at most once every 50ms:
final throttledScroll = scrollPosition.what.throttled(
  const Duration(milliseconds: 50),
  leading: true,
  trailing: true,
);

final scrollProgress = computed((via) => via(throttledScroll) / maxScrollExtent);
```

### 7.3 Synchronous Burst Mutation Coalescing

```dart
final transactionLog = WhatController<int>(0, distinct: false);

// Collapses 100 consecutive synchronous increments into 1 trailing notification:
final coalescedLog = transactionLog.what.coalesced();

final renderTerminal = RawWhatTerminal(coalescedLog, onInvalidated: () {
  print('Render frame with latest balance: ${coalescedLog.data}');
})..activate();
```

### 7.4 Analytics Click Tracking (Standalone Throttle Effect)

```dart
import 'package:what/what.dart';
import 'package:what/effect.dart';

final buttonClickCount = WhatController<int>(0);

// Pure side-effect: Dispatches analytics at most once per second on leading edge
final clickTracker = buttonClickCount.what.effect.throttle(
  const Duration(seconds: 1),
  () => analyticsService.logEvent('button_tap', count: buttonClickCount.what.peek),
  leading: true,
  trailing: false,
).run();

// Clean up when service or controller is disposed:
void dispose() => clickTracker.deactivate();
```

---

## 8. Implementation & Verification Matrix

| Architectural Guarantee | Behavioral Specification | Engine Implementation Anchor | Test Suite Verification |
| :--- | :--- | :--- | :--- |
| **Read-Committed Cache Invariant** | Relay keeps `_dirtyState == clean` during delay window; `.data` reads return cached state. | [`_GatedRelayWhat`](../../lib/src/what/_internal/_what.dart) | [`temporal_pipeline_test.dart` (1.1)](../../test/unit/engine/temporal_pipeline_test.dart) |
| **Microtask Burst Coalescing** | Compresses synchronous bursts within the same turn into 1 trailing microtask notification. | [`_CoalescedWhat`](../../lib/src/what/_internal/_what.dart), [`_Scheduler`](../../lib/src/engine/_internal/_scheduler.dart) | [`coalesced_test.dart` (test 1)](../../test/unit/what/coalesced_test.dart) |
| **Silence Period Debouncing** | Resets timer upon successive mutations; dispatches trailing pulse after duration silence. | [`_DebouncedWhat`](../../lib/src/what/_internal/_what.dart) | [`temporal_pipeline_test.dart` (1.1, 1.2)](../../test/unit/engine/temporal_pipeline_test.dart) |
| **Interval Rate-Limiting Throttle** | Limits downstream notifications to at most one pulse per time interval window. | [`_ThrottledWhat`](../../lib/src/what/_internal/_what.dart) | [`temporal_pipeline_test.dart` (3.1, 3.2)](../../test/unit/engine/temporal_pipeline_test.dart) |
| **Upstream Priming (0 Mount Runs)** | Manifest effects prime upstream versions on activation; 0 action callbacks on mount. | [`_UnaryEffectPrimeMixin`](../../lib/src/effect/_internal/_base.dart) | [`debounce_test.dart` (test 1)](../../test/unit/effect/debounce_test.dart) |
| **Zero-Leak Inactive Dormancy** | Deactivation cancels running `Timer`s and microtask schedules synchronously. | [`_TemporalRelayWhat._deactivate`](../../lib/src/what/_internal/_what.dart) | [`temporal_pipeline_test.dart` (4.1)](../../test/unit/engine/temporal_pipeline_test.dart) |
| **Finite Execution Early Teardown** | Effects with `take` limit sever edges immediately upon exhausting execution quota. | [`_ManifestEffectTerminal`](../../lib/src/effect/_internal/_base.dart) | [`debounce_test.dart` (test 3)](../../test/unit/effect/debounce_test.dart) |
| **Fluent Extension Zero-Cost DSL** | Monomorphic `UnaryWhatEffectScope` compiles to direct terminal dispatch without allocations. | [`UnaryWhatEffectScope`](../../lib/src/effect/extensions.dart) | [`tether_temporal_test.dart`](../../test/unit/what/tether_temporal_test.dart) |

---

## 9. Engineering Conclusions

The **Two-Tier Temporal Architecture** resolves the long-standing tension between asynchronous rate-limiting and synchronous reactive consistency:

1. **State Domain Immunity**: By embedding pulse attenuation into intermediate relay nodes (`_GatedRelayWhat<T>`), state pipelines preserve the single-source-of-truth cache invariant and guarantee that uncommitted mutations never contaminate downstream computations.
2. **Effect Domain Clarity**: Terminal sinks (`DebounceEffect`, `ThrottleEffect`) operate strictly on explicit targets with upstream priming, completely resolving the Initial Evaluation Dilemma and isolating side-effects cleanly from the reactive data graph.
3. **Unified Performance Excellence**: Microtask coalescing (`what.coalesced()`) and timer damping operate with zero heap overhead and zero GC pressure, upholding the What Framework's foundational LPDAG guarantees.
