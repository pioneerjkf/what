# Declarative Routing & Navigation Sync Specification
## (Declarative Routing & Navigation Sync)

> **"Routing is inherently stateful. When URL paths drift from the actual internal application state (e.g. Auth, Theme, Permissions), the application breaks. The reactive graph must bridge seamlessly to the Router's refresh listenables to guarantee 100% synchronization."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Routing Disconnect

Modern Flutter development heavily utilizes declarative routers like `GoRouter` or Navigator 2.0 to sync deep links, web URLs, and UI states. However, connecting a router's `refreshListenable` to a reactive state manager is historically a major friction point:
1. **Memory Leaks**: Subscribing routers to reactive states without proper `dispose()` logic causes listeners to outlive the router itself.
2. **Duplicate Renders**: Firing route rebuilds aggressively when state values haven't meaningfully changed (no distinct filtering) destroys 60fps scrolling and layout performance.
3. **Impedance Mismatch**: Flutter Routers expect `Listenable` (ChangeNotifier/ValueNotifier), while modern declarative state management uses directed acyclic graphs (DAGs).

`package:what_flutter` bridges this gap safely through **`.toListenable()`** and **`WhatSignal`**.

---

## 2. Bridging `What` to `Listenable` (`.toListenable()`)

To synchronize a `What` node (e.g., Auth State) with `GoRouter`, you convert the reactive node into a Flutter `Listenable`. 

### System Architectural Flow
```text
[ Reactive What<T> ] ──> .toListenable() ──> [ ValueListenable ]
                                                  │
                                                  ▼
[ GoRouter.refreshListenable ] <── Listens to ValueListenable
```

### Production Example: GoRouter Authentication
```dart
class AuthRouter {
  AuthRouter(this.authStore);
  final AuthStore authStore;

  late final GoRouter router = GoRouter(
    // 1. Convert the What<User?> node into a Listenable for the router
    refreshListenable: authStore.currentUserWhat.toListenable(),
    
    // 2. Redirect logic evaluates synchronously based on the pure state
    redirect: (context, state) {
      final isLoggedIn = authStore.currentUserWhat.peekState.dataOrNull != null;
      final isLoggingIn = state.uri.path == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ],
  );
}
```

### Architectural Benefits
1. **Zero-Leak Guarantee**: The `ValueListenable` returned by `.toListenable()` automatically hooks into the LPDAG. If the router is destroyed, the listenable naturally un-moors, maintaining dormant memory safety.
2. **Built-in Distinct Filtering**: `.toListenable()` respects the `distinct` flags of the underlying `What` node, preventing duplicate navigation rebuilds if the `User` object mutates with equivalent property values.

---

## 3. Transient Navigation Events (Push/Pop via `WhatSignal`)

While URL-driven routing is bound to persistent state (`.toListenable()`), imperative navigation (e.g., popping a modal, pushing a transient success dialog) belongs to **Transient Events**.

Attempting to model "Show Dialog" as a boolean state (`What<bool>`) leads to zombie payloads where the dialog reappears on remount.

### Production Example: Navigation Dialog via Signal
```dart
class FormStore {
  final showSuccessDialogSignal = WhatSignalController();

  Future<void> submit() async {
    await api.submit();
    // Fire exactly once; leaves no zombie state behind
    showSuccessDialogSignal.emit();
  }
}

base class FormView extends WhatWidget {
  const FormView({super.key, required this.store});
  final FormStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    return WhatListener(
      [store.showSuccessDialogSignal.what],
      (context) {
        // 2. Execute imperative navigation
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(title: Text('Success')),
        );
      },
      child: const Placeholder(),
    );
  }
}
```

---

## 4. Architectural Conclusions

By providing `.toListenable()` for persistent route-sync and `WhatSignal` for transient imperative pops/pushes, `what_flutter` covers the entire spectrum of declarative routing constraints while maintaining 100% memory dormancy and avoiding zombie navigation bugs.
