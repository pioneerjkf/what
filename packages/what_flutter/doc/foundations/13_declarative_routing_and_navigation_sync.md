# Declarative Routing & Navigation Sync Specification
## (Declarative Routing & Navigation Sync)

> **"Routing is inherently stateful. When URL paths drift from the actual internal application state (e.g. Auth, Theme, Permissions), the application breaks. The reactive graph must bridge seamlessly to the Router's refresh listenables to guarantee deterministic routing synchronization."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Routing Disconnect

Modern Flutter development heavily utilizes declarative routers like `GoRouter` or Navigator 2.0 to sync deep links, web URLs, and UI states. However, connecting a router's `refreshListenable` to a reactive state manager is historically a major friction point:
1. **Memory Leaks**: Subscribing routers to reactive states without proper `dispose()` logic causes listeners to outlive the router itself.
2. **Duplicate Renders**: Firing route rebuilds aggressively when state values haven't meaningfully changed (no distinct filtering) destroys 60fps scrolling and layout performance.
3. **Impedance Mismatch**: Flutter Routers expect `Listenable` (ChangeNotifier/ValueNotifier), while modern declarative state management uses directed acyclic graphs (DAGs).

`package:what_flutter` bridges this gap safely through **`.toListenable()`** (from `package:what_flutter`) and discrete transient event pulses via **[`WhatSignal`](https://github.com/pioneerjkf/what/blob/main/packages/what/doc/foundations/17_imperative_signals_and_transient_events.md)** (from core [`package:what`](https://pub.dev/packages/what), re-exported by `what_flutter`).

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
      // .dataOrNull: safe snapshot payload extraction from package:what (WhatSnapshot/WhatState)
      final isLoggedIn = untracked.state(authStore.currentUserWhat).dataOrNull != null;
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

## 3. Transient Navigation Events (Push/Pop via [`WhatSignal`](https://github.com/pioneerjkf/what/blob/main/packages/what/doc/foundations/17_imperative_signals_and_transient_events.md))

While URL-driven routing is bound to persistent state (`.toListenable()`), imperative navigation (e.g., popping a modal, pushing a transient success dialog) belongs to **Transient Events**.

Modeling one-off UI side-effects (such as dialog popups or route transitions) as persistent boolean state (`What<bool>`) creates zombie dialog bugs where navigating back or remounting the view re-executes the dialog. Transient events are resolved via [`WhatSignal`](https://github.com/pioneerjkf/what/blob/main/packages/what/doc/foundations/17_imperative_signals_and_transient_events.md) / [`WhatSignalController`](https://github.com/pioneerjkf/what/blob/main/packages/what/doc/foundations/17_imperative_signals_and_transient_events.md) (from core [`package:what`](https://pub.dev/packages/what), re-exported by `what_flutter`) or one-shot bounded listeners (`take: 1`).

**BAD:**
```dart
// [Anti-Pattern] Persistent boolean state triggers zombie dialogs upon remount
class BadFormStore {
  final showSuccessDialogState = WhatController<bool>(false);

  Future<void> submit() async {
    await api.submit();
    showSuccessDialogState.set(true); // Persists across screen navigation!
  }
}
```

**GOOD:**
```dart
// [Recommended] Pure transient signal or one-shot bounded listener (take: 1)
class FormStore {
  // WhatSignalController is from package:what (re-exported by what_flutter)
  final showSuccessDialogSignal = WhatSignalController();

  Future<void> submit() async {
    await api.submit();
    // Emits transient pulse; leaves zero standing zombie state
    showSuccessDialogSignal.emit();
  }
}

base class FormView extends WhatWidget {
  const FormView({super.key, required this.store});
  final FormStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    return WhatListener(
      store.showSuccessDialogSignal.what,
      (context, _) {
        // Execute imperative navigation outside Flutter's build pass
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

By providing `.toListenable()` for persistent route-sync and [`WhatSignal`](https://github.com/pioneerjkf/what/blob/main/packages/what/doc/foundations/17_imperative_signals_and_transient_events.md) (from `package:what`) for transient imperative pops/pushes, `what_flutter` covers the entire spectrum of declarative routing constraints while maintaining 100% memory dormancy and avoiding zombie navigation bugs.
