# Declarative Side-Effect Isolation & Zero-Rebuild Terminals Specification
## (Declarative Side-Effect Isolation & Zero-Rebuild Terminals: WhatListener)

> **"Rebuilding a widget tree merely to display a snackbar or push a route is an architectural failure. What enforces a strict Rebuild Count of 0, safely isolating imperative UI side-effects from the reactive rendering graph."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Conflict Between Unidirectional State and Imperative UI Feedback

Flutter applications frequently require imperative UI feedback actions:
- Displaying transient snackbars via `ScaffoldMessenger.showSnackBar()`
- Triggering screen transitions via `Navigator.pushNamed()` or `pop()`
- Prompting alert modals via `showDialog()`
- Dispatching user analytics logging events

However, traditional approaches (`BlocListener`, `ref.listen`, `Consumer`) encounter systemic vulnerabilities:
1. **Mutation Collisions During Build (`setState() called during build`)**:
   Attempting to open dialogs directly inside `build()` violates Flutter's single-pass layout contract, throwing runtime assertion errors.
2. **Cascading Subtree Rebuilds from Side-Effect Listeners**:
   Listener widgets re-execute their `build()` methods or re-render descendant subtrees despite performing no visual transformations.
3. **Spurious Invocations on Mount**:
   Listeners often misinterpret initial cached values as fresh mutations upon insertion into the tree, firing premature dialogs immediately on mount.

`package:what_flutter` resolves these challenges through the dedicated zero-rebuild side-effect sink: `WhatListener`.

---

## 2. Side-Effect Isolation Architecture

While positioned inside the element tree, `WhatListener` completely bypasses the rebuild pipeline (`markNeedsBuild`), routing directly to an internal `EffectRunner` queue and microtask scheduler:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                    WhatListener System Architecture                    │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Upstream What Mutation (e.g. errorWhat.set('Network Timeout')) ]   │
│                                  │                                     │
│                                  ▼ (Phase 1: Invalidation Wave)        │
│                       [ WhatListenerElement ]                          │
│                                  │                                     │
│                                  ▼ (Microtask Scheduling)              │
│                       [ EffectRunner Microtask Flush ]                 │
│                                  │                                     │
│                     Guard Check: guard(state) == true?                 │
│                        │                       │                       │
│                   (No) │                  (Yes)│                       │
│                        ▼                       ▼                       │
│                   [ Dropped ]           action(context, state)         │
│                                         • ScaffoldMessenger.show...    │
│                                         • Navigator.pushNamed          │
│                                                │                       │
│                                                ▼                       │
│                                    Take Ticket Decrement               │
│                                    (take == 0? -> Early Teardown)      │
│                                                                        │
│ ══════════════════════════════════════════════════════════════════════ │
│   [ Flutter Element Tree Rebuild Count: 0 ]                            │
│   Widget Element.markNeedsBuild() is NEVER called!                     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. The Foundational Invariants

### Invariant 1: Guaranteed Rebuild Count of 0
- The underlying element of `WhatListener` contains no execution paths invoking `markNeedsBuild()`.
- Even if observed nodes mutate 1,000 times per second, the descendant `child` subtree builds once on mount and **never rebuilds thereafter**.

### Invariant 2: Zero-Run on Mount Invariant
- A common flaw in reactive listeners is mistaking the initial state as an incoming mutation.
- `WhatListener` captures the initial version of [target] at mount time without executing the action callback.
- **Invariant**: *Callbacks never execute on mount; they fire strictly in response to subsequent runtime state mutations.*

### Invariant 3: Microtask Deferral
- To maintain safety even if state changes occur during Flutter's layout or render passes, actions dispatch via `scheduleMicrotask`.
- This separates `Navigator` pushes and modal dialogs from active render tree traversals, eliminating `setState() during build` exceptions.

### Invariant 4: Autonomous Teardown & Execution Quotas via `guard` and `take`
- **Precondition Guarding (`guard`)**: When `guard(state)` returns `false`, action execution is cleanly dropped while preserving remaining `take` quotas.
- **Finite Execution Bounds (`take`)**: Automatically deactivates the internal `EffectRunner` and severs LP-DAG dependency edges once the quota is reached (e.g. `take: 1`), guaranteeing zero standing subscription overhead thereafter.

---

## 4. Production Code Patterns

### 1. Granular Single-Target Listener (`WhatListener`)
```dart
WhatListener<String?>(
  errorMessageWhat,
  (context, message) {
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  },
  child: const LoginForm(),
);
```

### 2. Multi-Target Observation and One-Shot Navigation (`take: 1`)
To observe multiple nodes simultaneously, compose them into a derived tuple or record via `computed`:
```dart
final authReadyState = computed((via) => (
  authenticated: via(authStateWhat) == AuthState.authenticated,
  profileCompleted: via(profileCompletedWhat) == true,
));

WhatListener(
  authReadyState,
  (context, state) {
    Navigator.of(context).pushReplacementNamed('/dashboard');
  },
  guard: (state) => state.authenticated && state.profileCompleted,
  take: 1, // Automatically severs dependency edges after executing the single navigation dispatch
  child: const SplashLoadingScreen(),
);
```

### 3. Declarative Side-Effect Boundary in Widget Tree
```dart
class OrderCheckoutButton extends StatelessWidget {
  const OrderCheckoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Declarative side-effect boundary inside widget tree
        WhatListener<String?>(
          checkoutErrorWhat,
          (context, error) => showDialog(
            context: context,
            builder: (_) => AlertDialog(title: Text(error ?? '')),
          ),
          guard: (error) => error != null,
        ),
        ElevatedButton(
          onPressed: () => orderController.submit(),
          child: const Text('Checkout'),
        ),
      ],
    );
  }
}
```

### 4. Time-Domain Rate Limiting (`debounce` / `throttle`)
```dart
WhatListener<String>.debounce(
  searchQueryWhat,
  (context, query) => fetchSearchResults(context, query),
  duration: const Duration(milliseconds: 300),
);

WhatListener<double>.throttle(
  scrollOffsetWhat,
  (context, offset) => syncHaptics(context, offset),
  duration: const Duration(milliseconds: 100),
);
```

### 5. Architectural Guide: Where Should One-Shot Actions Live?
Depending on whether the side effect is intrinsically tied to the UI element tree or the domain layer:

| Pattern | Execution Context | Example Use Case | Recommended Tool |
|---|---|---|---|
| **Widget-Level One-Shot** | UI Presentation Tree | Screen navigation, modal alerts, SnackBars | `WhatListener(target, action, take: 1)` |
| **Domain / Controller-Level One-Shot** | Background Business Logic | Analytics telemetry, initial handshake sync | `Effect.unary(target, action, take: 1)` |
| **Consumable Event in State** | Shared Cross-Screen Flow | Multi-step wizard results, global deep link | `state.event.consume()` / `state = state.copyWith(event: null)` |

---

## 5. Architectural Conclusions

`WhatListener` decouples **rendering (visual structure)** from **side-effect actions (system/UI feedback)**.

This guarantees 100% adherence to Flutter's single-pass rendering rules while providing bug-free imperative feedback across reactive applications.
