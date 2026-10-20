# Imperative Signals & Transient Events Specification
## (Imperative Signals & Transient Events)

> **"State represents persistence; Events represent transition. Forcing transient, one-off events (like a Toast notification or a Navigation pop) into persistent state graphs creates zombie payloads. True reactivity must cleanly decouple the permanent from the transient."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The State vs. Event Dichotomy

In modern reactive architectures (such as Flutter and Dart), a prevalent anti-pattern is treating one-off imperative events as persistent domain state. For example, to display a transient error Snackbar, developers often declare a `WhatController<String?>(null)` and assign `"Network Connection Lost"`.

This creates three critical architectural defects:

1. **Zombie Payloads**: The `"Network Connection Lost"` string lingers inside the reactive node's cache indefinitely unless explicitly cleared via an imperative `set(null)`.
2. **Re-triggering on Remount (The Zombie Dialog Bug)**: If a widget unmounts and remounts (e.g. during tab switching, list recycling, or route pop/push), the reactive subscriber re-evaluates upon mounting. Because the cached payload is still `"Network Connection Lost"`, the Snackbar or Dialog fires a second time unexpectedly, causing severe UX glitches.
3. **Manual Nullification Boilerplate & Race Hazards**: Developers are forced to author defensive `onDismissed` or `onComplete` callbacks purely to nullify state (`set(null)`). If a second event occurs before nullification completes, the second event can be lost or overwritten by race conditions.

The What Framework resolves this fundamental dichotomy by introducing **`WhatSignal`** and **`WhatSignalController`** ([WhatSignal](../../lib/src/what/signal.dart), [WhatSignalController](../../lib/src/what/signal.dart))—specialized primitives dedicated strictly to discrete, stateless event pulses.

---

## 2. WhatSignal Architecture & Monotonic Tick Mechanics

`WhatSignal` and its producer, `WhatSignalController`, implement the identical topological LPDAG tracking as standard [`What<T>`](../../lib/src/what/what.dart) nodes, but with one critical distinction: **they do not cache domain payloads**.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Signal Routing Architecture                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Producer Layer (Encapsulated Controller) ]                        │
│   final _refreshSignal = WhatSignalController();                       │
│   WhatSignal get refreshSignal => _refreshSignal.what;                │
│          │                                                             │
│          ▼ emit()                                                      │
│   [ Monotonic Tick Sequence: 0 -> 1 -> 2 ... ]                         │
│          │                                                             │
│          ├──────────────────────────────────┐                          │
│          ▼ (Push-Dirty Pulse)               ▼ (Push-Dirty Pulse)       │
│   [ Manifest Listener / Side-Effect ]    [ Declarative Pipeline ]      │
│   Effect([refreshSignal], () {           computed.future((via) async { │
│     // 0-run on mount!                     via(refreshSignal);         │
│     // Runs STRICTLY on emit()             return fetchUserFeed();     │
│     showToast("Refreshed!");             });                           │
│   });                                                                  │
│                                                                        │
│   [ Remount / Re-evaluation Guarantee ]                                │
│   No lingering domain payload! Signals carry only discrete sequence    │
│   ticks, eliminating zombie dialogs and duplicate executions on remount│
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 The Monotonic Integer Sequence Engine

Under the hood, [WhatSignal](../../lib/src/what/signal.dart) implements [`What<int>`](../../lib/src/what/what.dart). Internally, `_SignalEntry` is a specialized root node initialized to `0`. Each invocation of `WhatSignalController.emit()` executes:

```dart
// packages/what/lib/src/what/_internal/_signal.dart
@override
void emit() {
  final entry = _target as _RawEntry<int>;
  entry.set(entry.data + 1);
}
```

This design achieves three fundamental guarantees:

1. **100% LPDAG Engine Unification**: Signals do not require a separate event bus, stream controller, or bespoke dispatch pipeline. They participate natively in What's zero-allocation 2-Phase LPDAG Push-Dirty engine.
2. **Monotonic Distinct Immunity**: In reactive systems, attaching `.distinct()` filters to boolean flags (`true -> true`) drops duplicate emissions. Because `WhatSignal` monotonically increments its tick count (`0 -> 1 -> 2 ...`), consecutive signal emissions are **guaranteed never to be suppressed or dropped by `.distinct()`**.
3. **Decoupled Domain Payloads**: The signal node carries no domain data (no strings, models, or entities). Domain data is either passed directly as transient arguments to action handlers or extracted from authoritative stores at the moment of the pulse.

---

## 3. Core Engineering Invariants

1. **Monotonic Sequence & Distinct Immunity Invariant**:
   `WhatSignal` implements `What<int>`, advancing by `+1` on each `emit()`. This guarantees that consecutive pulses are never suppressed by downstream `.distinct()` equality filters.
2. **Producer-Consumer Decoupling Invariant**:
   Emitters hold `WhatSignalController` which exposes `void emit()`. Consumers receive only the read-only `WhatSignal` (`signal.what`) which implements `What<int>`, preventing consumers from imperatively firing events.
3. **Zero-Run on Mount Invariant for Manifest Listeners**:
   When observing via manifest `Effect([signal.what], action)` or Flutter's `WhatListener(signal.what, action)`, initial subscription establishes topological dependency edges with exactly 0 callback executions; `action` executes strictly upon subsequent `signal.emit()` pulses.
4. **Late-Bound Ignorance (Dormancy Safe Invariant)**:
   When `signal.emit()` is invoked while `signal.isActive == false` (no active downstream terminals or listeners attached), the pulse increments the internal sequence and is safely discarded without queuing or accumulating unhandled event backlogs in memory.
5. **Dynamic Epoch Diffing & Branch Rewiring Invariant**:
   When observed inside dynamic functors like `computed`, `switched`, or `managed` via `via(signal.what)`, signal dependencies participate in 1-Pass Epoch Sweeping, rewiring or pruning edges without memory leaks.

---

## 4. Production Code Patterns

### 4.1 Triggering Discrete Side-Effects in Pure Dart (`Effect`)

Manifest effects ([`Effect`](../../lib/src/effect/effect.dart)) monitor explicit target signals and execute side-effects (logging, analytics, socket transmissions) strictly upon mutation with **zero executions on mount**:

```dart
class AuthStore {
  final _loginSuccessSignal = WhatSignalController();
  WhatSignal get loginSuccessSignal => _loginSuccessSignal.what;

  final userProfile = WhatController<UserProfile?>(null);

  Future<void> login(String credentials) async {
    final profile = await api.authenticate(credentials);
    userProfile.set(profile);
    
    // Fires discrete event pulse
    _loginSuccessSignal.emit();
  }
}

// In background or service layer:
void setupAnalytics(AuthStore authStore) {
  // Manifest Effect skips initial execution (0 runs on mount)
  Effect([authStore.loginSuccessSignal], () {
    final user = untracked(authStore.userProfile.what);
    analytics.logEvent('user_logged_in', {'userId': user?.id});
  });
}
```

### 4.2 Flutter UI Side-Effects (`WhatListener`)

In Flutter applications, listening to signals via `WhatListener` eliminates the "Zombie Dialog" bug completely across widget rebuilds and route transitions:

```dart
class CheckoutView extends StatelessWidget {
  const CheckoutView({super.key, required this.store});
  final CheckoutStore store;

  @override
  Widget build(BuildContext context) {
    return WhatListener(
      store.paymentFailureSignal.what,
      (context, _) {
        // Runs STRICTLY when paymentFailureSignal.emit() is called.
        // Remounting this view or popping back to this screen NEVER re-triggers the dialog!
        showDialog(
          context: context,
          builder: (ctx) => const AlertDialog(
            title: Text('Payment Failed'),
            content: Text('Please verify your payment credentials and retry.'),
          ),
        );
      },
      child: CheckoutForm(store: store),
    );
  }
}
```

### 4.3 Declarative Invalidation & SWR Refetching (`computed.future`)

Signals serve as declarative cache-invalidation triggers inside asynchronous pipelines ([computed.future](../../lib/src/what/computed.dart)), initiating immediate background refetches without imperative callback spaghettis:

```dart
final refreshSignal = WhatSignalController();

// Baseline snapshot loads on mount; subsequent [refreshSignal.emit()] pulses trigger fresh refetches:
final marketOverview = computed.future((via) async {
  via(refreshSignal.what); // Dynamically subscribes to the signal pulse
  return stockApi.fetchMarketSnapshot();
});

// User pull-to-refresh action:
void onPullToRefresh() {
  refreshSignal.emit();
}
```

### 4.4 Forcing Re-evaluation of Dynamic Branches (`switched`)

Signals can be observed inside conditional selectors ([switched](../../lib/src/what/switched.dart)) to force branch re-evaluation on demand, even when primary condition variables remain unchanged:

```dart
enum FeedTab { trending, personalized }

final selectedTab = WhatController(FeedTab.trending);
final reloadTabSignal = WhatSignalController();

final activeFeed = switched((via) {
  final tab = via(selectedTab.what);
  switch (tab) {
    case FeedTab.trending:
      via(reloadTabSignal.what); // Forces trending branch re-evaluation on emit()
      return trendingFeed.what;
    case FeedTab.personalized:
      return personalizedFeed.what;
  }
});
```

### 4.5 Resetting and Recycling Managed Resources (`managed`)

When coordinating managed lifecycle resources ([managed](../../lib/src/what/managed.dart)), observing a signal inside the `create` factory tears down the previous resource via `dispose` and cleanly allocates a fresh instance:

```dart
final reconnectSignal = WhatSignalController();

final activeSocket = managed<WebSocketChannel>(
  create: (via) {
    via(reconnectSignal.what); // Re-creates socket connection on signal pulse
    return WebSocketChannel.connect(serverUri);
  },
  dispose: (channel) {
    channel.sink.close();
  },
);

// Trigger reconnect:
void reconnect() {
  reconnectSignal.emit();
}
```

### 4.6 Subscriber-Driven Lifecycle Coordination (`onActivated` / `onDeactivated`)

`WhatSignalController` supports subscriber boundary callbacks, allowing emitters to coordinate upstream data sources (e.g., hardware sensors, polling intervals, SSE listeners) based on whether any downstream UI component is actively observing the signal:

```dart
final pushEventSignal = WhatSignalController(
  onActivated: () {
    // Connect to external push stream only when observed by active terminal/UI
    pushClient.subscribe();
  },
  onDeactivated: () {
    // Deterministically disconnect when all UI widgets unmount
    pushClient.unsubscribe();
  },
);
```

### 4.7 Zero-Overhead Debugging & Diagnostics

`WhatSignalController` integrates seamlessly into What's zero-cost diagnostic ecosystem via [WhatSignalControllerDebugExtension](../../lib/src/engine/debug.dart):

```dart
final refreshSignal = WhatSignalController().withDebugLabel('OrderRefreshSignal');

// Inspect live diagnostic state in debug mode
final snapshot = refreshSignal.what.debug.snapshot();
print(snapshot.name);        // "OrderRefreshSignal"
print(snapshot.version);     // 0 (Increments monotonically on each emit)
print(snapshot.isActive);    // true / false based on downstream connections

refreshSignal.emit();
print(refreshSignal.what.debugVersion); // 1
```

---

## 5. Architectural Conclusions

By decoupling **`WhatController<T>`** (persistent state representation) from **`WhatSignalController`** (transient event triggers) while unifying both under the core 2-Phase LPDAG engine ([`What<int>`](../../lib/src/what/what.dart)), the What Framework achieves:

1. **Complete Elimination of Zombie Payloads**: No stale event data is preserved across UI lifecycles or remounts.
2. **Zero-Overhead Monotonic Unification**: Reuses the core topological dependency engine with 0 extra event routing abstractions.
3. **Immunity to Distinct Filter Drops**: Monotonically advancing ticks ensure sequential event pulses are preserved with 100% fidelity.
