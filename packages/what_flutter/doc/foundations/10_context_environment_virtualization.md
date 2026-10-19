# Context Environment Integration and Scoped State Observation Technical Whitepaper
## Scoped State Dependency Resolution: WhatProvider & `via.of<T>(context)`

> "Triggering full subtree rebuild cascades simply because an ancestor state mutated is the primary source of UI jank in Flutter applications. `what_flutter` virtualizes and encapsulates hierarchical state provisioning via `WhatProvider` and `WhatViaContextExtension` (`via.of<T>(context)`), strictly suppressing unneeded rebuilds while retaining surgical push-dirty lazy-pull reactivity."  
> — *What Framework Core Systems Group*

---

## 1. Executive Summary & Problem Statement: Monolithic Invalidation in `InheritedWidget`

Flutter's standard `InheritedWidget` propagates rebuilds indiscriminately across the widget subtree:

1. **Subtree Rebuild Cascades**:
   - In traditional Flutter, whenever an ancestor `InheritedWidget` rebuilds and reports `updateShouldNotify(...) == true`, all descendant elements that registered dependencies are forcibly scheduled for layout and rebuild, even if their specific slice of data never changed.
2. **Coarse Coupling vs Fine-Grained Reactive Graphs**:
   - Monolithic state models force all descendants to observe the entire state carrier, breaking the single responsibility principle and triggering redundant paint/layout passes.
3. **Producer/Consumer Encapsulation Break**:
   - Directly providing mutable controllers down the tree tempts descendant widgets to execute uncontrolled mutations, destroying architectural boundaries.

`package:what_flutter` resolves these issues through **`WhatProvider<T>`** and **`WhatViaContextExtension` (`via.of<T>(context)`)**.

---

## 2. Scoped Provision Architecture

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Scoped State DI & Observation Architecture           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Ancestor Widget Tree ]                                             │
│   WhatProvider<UserProfile>(what: userController.what, child: ...)     │
│        │                                                               │
│        ├─► updateShouldNotify: !identical(old.what, new.what)          │
│        │   (Node reference unchanged? ──► Rebuild Propagation: ZERO!)  │
│        │                                                               │
│        ▼ (Descendants observe surgically via via.of<T>(context))       │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │ Consumer 1: UserAvatar     (Reads via.of<UserProfile>(context))│   │
│   │ Consumer 2: UserNameLabel  (Reads via.of<UserProfile>(context))│   │
│   │ Consumer 3: StaticCardBody (Static subtree - zero observation) │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    │                                   │
│   [ Event: userController.data = newUser ]                             │
│        │                                                               │
│        ▼                                                               │
│   Topological 2-Phase LPDAG Dirty Pulse                                │
│        │                                                               │
│        ├─► StaticCardBody   : Rebuild Count: 0 (No reactive edge)      │
│        └─► UserAvatar/Label : Rebuild Count: 1 (Surgical Update!)      │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Core Architectural Mechanisms

### 3.1 `updateShouldNotify` Identity Invariant
```dart
// packages/what_flutter/lib/src/widgets/provider.dart
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
- **Invariant**: *Subtree rebuild cascades at the Flutter `InheritedWidget` layer are 100% suppressed.*

### 3.2 Fluent Scoped Observation via `WhatViaContextExtension`
Inside a `WhatWidget` or `composed` builder scope, descendants access provided state using `via.of<T>(context)`:

```dart
// packages/what_flutter/lib/src/widgets/provider.dart
extension WhatViaContextExtension on WhatVia {
  @pragma('vm:prefer-inline')
  What<T> of<T>(BuildContext context) => this(context.whatOf<T>());

  @pragma('vm:prefer-inline')
  What<T?> maybeOf<T>(BuildContext context) => this(context.maybeWhatOf<T>());
}
```
- **Zero Heap Allocation**: Method calls resolve statically via inlined extensions.
- **Topological Invariant**: `via.of` automatically registers the ancestor [What] with `WhatVia`, establishing a dynamic dependency edge for glitch-free updates.

---

## 4. Production Implementation Patterns

### 4.1 Providing Scoped State via Extension DSL
```dart
class StorePage extends StatelessWidget {
  const StorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final counterController = WhatController<int>(0);

    return counterController.what.provide(
      child: const SizedBox(),
    );
  }
}
```

### 4.2 Consuming Scoped State in `WhatWidget`
```dart
base class CounterDisplay extends WhatWidget {
  const CounterDisplay({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    // Surgically observe provided What<int> node
    final count = via.of<int>(context);

    return Text('Count: $count');
  }
}
```

### 4.3 Safe Optional Lookup via `via.maybeOf<T>(context)`
```dart
base class OptionalUserBadge extends WhatWidget {
  const OptionalUserBadge({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final user = via.maybeOf<User>(context);
    if (user == null) {
      return const Text('Guest');
    }

    return Text('Welcome, ${user.name}');
  }
}
```

---

## 5. Verification and Invariant Summary

1. **Rebuild Suppression Invariant**: `WhatProvider.updateShouldNotify` returns `false` on identical node references, mathematically eliminating framework-level rebuild cascades.
2. **Referential Integrity**: Scoped dependency extraction relies exclusively on static, type-safe Dart APIs (`via.of<T>(context)` and `context.whatOf<T>()`) with zero mock dependencies and zero runtime proxy overhead.
3. **Glitch-Free Scoped Propagation**: Subtree consumers participate fully in the What 2-Phase LPDAG topological execution model, ensuring surgical 1-hop updates.
