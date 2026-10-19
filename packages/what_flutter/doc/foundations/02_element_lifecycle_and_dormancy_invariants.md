# Widget Tree Lifecycle Invariants & Subscriber-Driven Dormancy Specification
## (Widget Tree Lifecycle Invariants & Subscriber-Driven Dormancy)

> **"If an unmounted widget continues receiving state mutations after disappearing from the viewport, it represents a memory leak and battery drain. What synchronizes directly with Flutter Element lifecycles, entering dormancy the instant an element detaches."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: Widget Detachment and Reactive Leaks in Flutter

In Flutter applications, route pushes, tab switches, and list view scrolls continuously trigger element lifecycle transitions: mounting (`mount`), deactivating (`deactivate`), reactivating (`activate`), and unmounting (`unmount`).

Traditional state management packages (`ChangeNotifier`, `Rx`, `Stream`, `StateNotifier`) share common lifecycle vulnerabilities:
1. **Zombie Subscriptions**: When widgets navigate off-screen or sit deep within the route stack, singleton state nodes continue holding listeners, preventing garbage collection.
2. **Wasted Calculations in Inactive States**: Off-screen widgets trigger redundant `markNeedsBuild()` passes and intermediate derivations in response to background data mutations.
3. **Reparenting Collisions**: When reparenting widgets using a `GlobalKey`, rapid `deactivate` and `activate` sequences cause stream closures or re-entrancy exceptions.

`package:what_flutter` tethers What's **Subscriber-Driven Inactive Dormancy** invariant directly to Flutter's `ComponentElement` lifecycle to eliminate these failure modes.

---

## 2. Element Lifecycle Synchronization Architecture

Every reactive element in `what_flutter` binds to low-level Element lifecycle hooks via `_ReactiveTerminalElementMixin`:

```text
┌────────────────────────────────────────────────────────────────────────┐
│             Flutter Element Lifecycle & Reactive Dormancy Sync         │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Widget Tree State ]                 [ What Terminal Action ]       │
│                                                                        │
│   mount(parent, newSlot)       ──►      terminal.activate()            │
│   (Element added to tree)               (Registers target edge in DAG) │
│              │                                     │                   │
│              ▼                                     ▼                   │
│   ACTIVE RUNNING STATE         ──►      Listens to dirty pulses        │
│   (Visible & Rendered)                  Evaluates on buildScope        │
│              │                                     │                   │
│              ▼                                     ▼                   │
│   deactivate()                 ──►      terminal.deactivate()          │
│   (Navigated away / Offstage)           (DORMANCY: Cuts all DAG edges) │
│              │                                     │                   │
│       ┌──────┴──────────────────────────┐          │                   │
│       ▼                                 ▼          ▼                   │
│   activate()                       unmount()                           │
│   (Reparented / Popped back)       (Permanently destroyed)             │
│       │                                 │                              │
│       ▼                                 ▼                              │
│   terminal.activate()              terminal.deactivate()               │
│   (Re-syncs edges & evaluations)   (Complete cleanup)                  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Foundational Lifecycle Invariants

### Invariant 1: Complete LPDAG Edge Detachment on Deactivation (Immediate Dormancy)
- When Flutter detaches a widget from the element tree, `Element.deactivate()` fires.
- `_ReactiveTerminalElementMixin` immediately triggers `terminal.deactivate()`.
- **Invariant**: *Deactivated widgets are immediately unlinked from upstream `What` subscriber lists.*
- **Outcome**: Even if upstream nodes mutate 1,000 times, zero dirty pulses reach the deactivated widget, locking background CPU cycles to zero.

### Invariant 2: 1-Pass Epoch Sweeping and Dynamic Branch Pruning
- When dependency paths shift across conditional statements inside `build(context, via)`:
```dart
composed((context, via) {
  if (via(isLoggedIn)) {
    return UserCard(user: via(userData));
  } else {
    return const LoginPrompt();
  }
});
```
- When a user logs out and `isLoggedIn` flips to `false`, What's **1-Pass Epoch Sweeping** algorithm severs the edge to `userData` in a single linear pass with zero heap allocations.
- Inactive branches never trigger spurious rebuilds.

### Invariant 3: Reparenting and Graceful Policies
- During `GlobalKey` reparenting, elements deactivate and reactivate within the same frame.
- To prevent tearing down and recreating expensive external resources (sockets, native handles, tickers) within 1ms, `Graceful` microtask buffering can be declared on the pipeline.
- Single-tick transitions preserve resource continuity seamlessly.

### Invariant 4: Hot Reload Integrity (`reassemble` -> `debugForceInvalidate`)
- When Flutter Hot Reload triggers `Element.reassemble()`, What executes `terminal.debugForceInvalidate()` within an `assert`-only block.
- Intermediate caches flush immediately, ensuring all reactive widgets re-evaluate updated layout code on the subsequent frame.

---

## 4. Internal Implementation Analysis (`_ReactiveTerminalElementMixin`)

```dart
// lib/src/widgets/_internal/_framework.dart
mixin _ReactiveTerminalElementMixin<T extends RawTerminal> on ComponentElement {
  /// The reactive terminal sink hosted by this element.
  T get terminal;

  @mustCallSuper
  @override
  void mount(Element? parent, Object? newSlot) {
    terminal.activate(); // Activates upon insertion into the render tree
    super.mount(parent, newSlot);
  }

  @mustCallSuper
  @override
  void activate() {
    super.activate();
    terminal.activate(); // Re-establishes edges upon reactivation
  }

  @mustCallSuper
  @override
  void deactivate() {
    terminal.deactivate(); // Immediate edge severance into dormancy
    super.deactivate();
  }

  @mustCallSuper
  @override
  void reassemble() {
    assert(() {
      terminal.debugForceInvalidate(); // Forces cache invalidation on Hot Reload
      return true;
    }());
    super.reassemble();
  }

  @mustCallSuper
  @override
  void unmount() {
    try {
      terminal.deactivate();
    } catch (error, stackTrace) {
      FlutterError.reportError(...);
    }
    super.unmount();
  }
}
```

---

## 5. Architectural Comparison: `WhatWidget` vs. `composed` vs. `what.build`

| Evaluation Dimension | `WhatWidget` | `composed` Functor | `what.build` Extension |
| :--- | :--- | :--- | :--- |
| **Host Element** | `WhatElement` | `_ComposedElement` | `_InlineSingleWhatElement` |
| **Terminal Sink Type** | `RawViaTerminal<Widget>` | `RawViaTerminal<Widget>` | `RawWhatTerminal<T>` |
| **Dependency Scope** | Multi-source (`via(a)`, `via(b)`) | Multi-source (`via(a)`, `via(b)`) | 1:1 Direct Single Source |
| **Memory Allocation** | Widget subclass instance | Anonymous closure capture | `extension type const` 0-Alloc |
| **Primary Use Case** | Self-contained domain widgets | Inline reactive boundaries in trees | Fine-grained text/icon bindings |
| **Dormancy Invariant** | Severed on `deactivate()` | Severed on `deactivate()` | Severed on `deactivate()` |

---

## 6. Architectural Conclusions

What's widget lifecycle architecture guarantees that **unobserved widgets consume zero computing cycles**.

Developers never wire manual `StreamSubscription.cancel()` or `controller.dispose()` routines across views; reactive memory management synchronizes autonomously with Flutter's element tree.
