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

`package:what_flutter` resolves these challenges through dedicated zero-rebuild side-effect sinks: `WhatListener` and `UnaryWhatListener`.

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
│                                  ▼ (Phase 1: Invalidation)             │
│                      [ RawWhatListenerTerminal ]                       │
│                                  │                                     │
│                    Guard Check: guard() == true?                       │
│                        │                       │                       │
│                   (No) │                  (Yes)│                       │
│                        ▼                       ▼                       │
│                   [ Dropped ]           [ Schedule Action ]            │
│                                                │                       │
│                                                ▼                       │
│                                    [ Microtask Queue Flush ]           │
│                                                │                       │
│                                                ▼                       │
│                                    action(context) Execution           │
│                                    • ScaffoldMessenger.showSnackBar    │
│                                    • Navigator.pushNamed               │
│                                                │                       │
│                                                ▼                       │
│                                    Take Ticket Decrement               │
│                                    (take == 0? -> Early Teardown)      │
│                                                                        │
│ ══════════════════════════════════════════════════════════════════════ │
│   [ Flutter Element Tree Rebuild Count: 0 ]                            │
│   Widget Element.markNeedsBuild() is NEVER called!                     │
│└───────────────────────────────────────────────────────────────────────┘
```

---

## 3. The 4 Foundational Invariants

### Invariant 1: Guaranteed Rebuild Count of 0
- The underlying elements of `WhatListener` and `UnaryWhatListener` contain no execution paths invoking `markNeedsBuild()`.
- Even if observed nodes mutate 1,000 times per second, the descendant `child` subtree builds once on mount and **never rebuilds thereafter**.

### Invariant 2: Zero-Run on Mount Invariant
- A common flaw in reactive listeners is mistaking the initial state as an incoming mutation.
- `WhatListener` captures initial versions of all targets at mount time without executing the action callback.
- **Invariant**: *Callbacks never execute on mount; they fire strictly in response to subsequent runtime state mutations.*

### Invariant 3: Microtask Deferral
- To maintain safety even if state changes occur during Flutter's layout or render passes, actions dispatch via `scheduleMicrotask`.
- This separates `Navigator` pushes and modal dialogs from active render tree traversals, eliminating `setState() during build` exceptions.

### Invariant 4: Autonomous Teardown via `guard` and `take`
- `guard`: Skipping execution when `guard()` returns `false` leaves the remaining `take` quota intact.
- `take: 1`: Automatically severs dependency edges after executing its single allotted run, enabling prompt garbage collection.

---

## 4. Production Code Patterns

### 1. Granular Single-Target Listener (`UnaryWhatListener` / `WhatListener.unary`)
```dart
UnaryWhatListener<String?>(
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
```dart
WhatListener(
  [authStateWhat, profileCompletedWhat],
  (context) {
    Navigator.of(context).pushReplacementNamed('/dashboard');
  },
  guard: () => authStateWhat.peek == AuthState.authenticated && profileCompletedWhat.peek == true,
  take: 1, // Automatically tears down after single navigation dispatch
  child: const SplashLoadingScreen(),
);
```

### 3. Declarative Composition (`WhatListener`)
```dart
class OrderCheckoutButton extends StatelessWidget {
  const OrderCheckoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Declarative side-effect boundary inside widget tree
        WhatListener(
          [checkoutErrorWhat],
          (context) => showDialog(
            context: context,
            builder: (_) => AlertDialog(title: Text(checkoutErrorWhat.peek ?? '')),
          ),
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

---

## 5. Architectural Conclusions

`WhatListener` decouples **rendering (visual structure)** from **side-effect actions (system/UI feedback)**.

This guarantees 100% adherence to Flutter's single-pass rendering rules while providing bug-free imperative feedback across reactive applications.
