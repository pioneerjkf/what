# Scoped State Provision & Rebuild Suppression Specification
## (Scoped State Provision & Rebuild Suppression: WhatProvider)

> **"Traditional `InheritedWidget`s indiscriminately rebuild all dependent subtrees whenever state mutates. `WhatProvider` leverages InheritedWidget solely for tree-based discovery while suppressing rebuild cascades, routing surgical micro-updates strictly through the LPDAG."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Subtree Invalidation Problem in Flutter `InheritedWidget`

Flutter's standard dependency injection mechanism, `InheritedWidget`, passes state down widget hierarchies but introduces a major architectural bottleneck:

1. **Broad Subtree Invalidation**:
   When data within an `InheritedWidget` changes, every descendant that invoked `dependOnInheritedWidgetOfExactType` is scheduled for `markNeedsBuild()`. Mutating a single localized field forces the entire consuming view to re-execute `build()`.
2. **O(N) Search and Allocation Overhead in Deeply Nested Providers**:
   Wrapping widgets in dozens of nested provider layers inflates widget tree depth, creating redundant Element wrappers on every render pass.

`package:what_flutter` resolves these issues via **Rebuild-Suppressed `WhatProvider<T>`** and **`switched`-backed dynamic unwrapping pipelines**.

---

## 2. `WhatProvider` Rebuild Suppression Architecture

`WhatProvider` does not inject mutable data directly; it injects the **immutable `What<T>` reactive node reference itself**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   WhatProvider Architecture & Flow                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Parent Widget Tree ]                                               │
│   WhatProvider<CounterState>(what: counterController.what)             │
│        │                                                               │
│        ├─► updateShouldNotify: !identical(old.what, new.what)          │
│        │   (Node reference unchanged? ──► Rebuild Propagation: ZERO!)  │
│        │                                                               │
│        ▼ (Descendants read via whatOf<T>() or via.of<T>(context))       │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │ Consumer 1: HeaderWidget (Reads state.title)                   │   │
│   │ Consumer 2: CounterDisplay (Reads state.count)                 │   │
│   │ Consumer 3: HeavyBackground (Does not read state)              │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    │                                   │
│   [ Event: counterController.data.count++ ]                            │
│        │                                                               │
│        ▼                                                               │
│   Topological 2-Phase LPDAG Dirty Pulse                                │
│        │                                                               │
│        ├─► HeavyBackground  : Rebuild Count: 0 (No edge)               │
│        ├─► HeaderWidget     : Rebuild Count: 0 (count ignored)         │
│        └─► CounterDisplay   : Rebuild Count: 1 (Surgical Update!)      │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Foundational Architecture Invariants

### Invariant 1: Reference Identity Invariant in `updateShouldNotify`
```dart
// lib/src/widgets/provider.dart
class WhatProvider<T> extends InheritedWidget {
  const WhatProvider({
    super.key,
    required this.what,
    required super.child,
  });

  final What<T> what;

  @override
  bool updateShouldNotify(covariant WhatProvider<T> oldWidget) {
    return !identical(oldWidget.what, what);
  }
}
```
- Regardless of how frequently the underlying data inside `what` mutates, as long as the `what` object reference remains unchanged, `updateShouldNotify` returns `false`.
- **Invariant**: *Indiscriminate subtree rebuild cascades at the Flutter `InheritedWidget` layer are 100% suppressed.*

### Invariant 2: Scoped Dependency Observation via `WhatViaContextExtension`
When descendants call `via.of<T>(context)`, What activates a scoped provider lookup internally:

```dart
// lib/src/widgets/provider.dart
extension WhatViaContextExtension on WhatVia {
  @pragma('vm:prefer-inline')
  What<T> of<T>(BuildContext context) {
    return context.whatOf<T>();
  }
}
```
- If the widget tree reparents and `WhatProvider` binds to a different node, `switched` severs the prior edge via 1-Pass Epoch Sweeping and transitions to the new node seamlessly.
- This prevents memory leaks and orphan references to obsolete ancestor scopes.

---

## 4. Production Code Patterns

### 1. Scoped State Provision (`provide` Extension Syntax)
```dart
class StorePage extends StatelessWidget {
  StorePage({super.key});

  final cartController = WhatController(CartState());

  @override
  Widget build(BuildContext context) {
    // Declarative provisioning via what.provide
    return cartController.what.provide(
      child: Scaffold(
        appBar: AppBar(title: const Text('Store')),
        body: const ProductListView(),
        bottomNavigationBar: const CartSummaryBar(),
      ),
    );
  }
}
```

### 2. Declarative Injected Consumption in `WhatWidget` (`whatOf<T>` & `via.of<T>`)
```dart
base class CartSummaryBar extends WhatWidget {
  const CartSummaryBar({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    // Declarative ancestor state lookup & reactive observation via via.of<T>(context)
    final cart = via.of<CartState>(context);
    // Or traditional nested: via(context.whatOf<CartState>())
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text('Total: \$${cart.totalPrice} (${cart.itemCount} items)'),
    );
  }
}
```

### 3. Inline Consumption in Micro-Widgets (`via.of<T>(context)`)
```dart
class CartItemCounter extends StatelessWidget {
  const CartItemCounter({super.key});

  @override
  Widget build(BuildContext context) {
    return composed((context, via) {
      final cart = via.of<CartState>(context);
      return Badge(label: Text('${cart.itemCount}'));
    });
  }
}
```

---

## 5. Architectural Conclusions

`WhatProvider` retains the discovery capabilities of `InheritedWidget` while eliminating subtree rebuild cascades through 2-Phase LPDAG topological routing.

Enterprise applications achieve structured dependency injection without sacrificing surgical micro-rendering performance.
