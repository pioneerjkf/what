// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// Top-Level Lifecycle-Managed External State Functor
// =============================================================================

/// Core declarative lifecycle supervision functor for external synchronous resources.
///
/// Instantiates external objects (such as HTTP clients, WebSocket channels, local animation
/// controllers, or hardware handles) only when actively observed by downstream consumers,
/// and automatically invokes the `dispose` callback when all downstream subscribers deactivate.
///
/// ## System Architectural Flow
/// ```text
/// [Active Subscriber Connects]
///            │
///            ▼
///   [guard.isPass?]
///    ├── No (block) ──> Emits Empty(guard.reason) [create() NOT called]
///    └── Yes (pass) ──> Invokes create() ──> Valid(resource)
///            │
///            ▼
///   [Upstream Dependencies Mutate]
///    ├── guard becomes block ──> Calls dispose() ──> Empty(guard.reason)
///    └── guard remains pass  ──> Calls update() (or dispose() + create())
///            │
///            ▼
/// [All Subscribers Disconnect] ──> Invokes dispose() ──> Dormant
/// ```
///
/// ## Architectural Benefits & Lifecycle Invariants
/// 1. **Zero-Leak Inactive Dormancy**: When no downstream subscribers are connected (inactive state),
///    the node is unconditionally dormant (0 CPU, 0 allocations, 0 open handles).
/// 2. **Lazy On-Demand Activation**: Resource allocation occurs only upon active downstream connection.
/// 3. **Microtask Thrashing Protection**: Supports [graceful] disposal to coalesce rapid unmount/remount cycles.
///
/// See [ManagedFunctor.call] for complete parameter specifications, in-place reuse (`update`),
/// and transient mooring (`graceful`).
///
/// ## Examples
/// ```dart
/// final timer = managed<Timer>(
///   create: (via) => Timer.periodic(const Duration(seconds: 1), (t) => tick()),
///   dispose: (t) => t.cancel(),
/// );
/// ```
const managed = ManagedFunctor._();

/// Callable functor managing synchronous lifecycle-supervised [What] resources.
final class ManagedFunctor {
  const ManagedFunctor._();

  /// Fast-path synchronous resource lifecycle management with explicit [WhatVia].
  ///
  /// Instantiates external objects only when actively observed by downstream consumers,
  /// and automatically invokes [dispose] when all downstream subscribers deactivate.
  ///
  /// * [create]: Factory callback creating the resource when downstream subscribers activate.
  /// * [update]: Optional update callback invoked when tracked dependencies change, allowing instance reuse.
  /// * [guard]: Optional precondition check returning [WhatGuard] gating resource creation and providing diagnostic reasons.
  /// * [graceful]: Optional [Graceful] policy to buffer deallocation during rapid remounts.
  /// * [eager]: If `true`, pre-emptively resolves the resource in microtask when active.
  ///   Defaults to `false` (on-demand Lazy evaluation).
  ///
  /// **Ensures:**
  /// * Returns a reactive [What<T>] managing the synchronous lifecycle of the underlying resource.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Do NOT instantiate `managed(...)` inside `computed()` or widget build methods,
  ///   as creating new resource nodes on each render loop will continuously allocate and orphan lifecycle instances.
  /// - Do NOT manually call `dispose()` on the managed instance directly; let the reactive graph automatically trigger [dispose].
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Instantiating managed resource inside build method
  /// Widget build(BuildContext context) {
  ///   final client = managed<HttpClient>( // Allocates new managed node every frame!
  ///     create: (via) => HttpClient(),
  ///     dispose: (c) => c.close(),
  ///   );
  ///   return Text('${client.peekState.dataOrNull}');
  /// }
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Define managed resource once at controller/service scope
  /// class NetworkService {
  ///   late final client = managed<HttpClient>(
  ///     create: (via) => HttpClient(),
  ///     dispose: (c) => c.close(),
  ///   );
  /// }
  /// ```
  ///
  /// ## Examples
  ///
  /// ### 1. Simple Local Resource (e.g. Timer):
  /// ```dart
  /// final timer = managed<Timer>(
  ///   create: (via) => Timer.periodic(const Duration(seconds: 1), (t) => tick()),
  ///   dispose: (t) => t.cancel(),
  /// );
  /// ```
  ///
  /// ### 2. Manual Reset / Reconnection Trigger via WhatSignal:
  /// ```dart
  /// final resetTrigger = WhatSignalController();
  ///
  /// final socket = managed<WebSocketChannel>(
  ///   create: (via) {
  ///     via(resetTrigger.what); // Declaratively disposes & re-creates on pulse
  ///     return WebSocketChannel.connect(via(serverUrl.what));
  ///   },
  ///   dispose: (ch) => ch.sink.close(),
  /// );
  ///
  /// // Trigger manual reset/reconnection:
  /// resetTrigger.emit();
  /// ```
  ///
  /// ### 3. In-Place Resource Reuse via update:
  /// ```dart
  /// final serverPort = WhatController(8080);
  ///
  /// final client = managed<ApiClient>(
  ///   create: (via) => ApiClient(port: via(serverPort.what)),
  ///   update: (via, current) {
  ///     current.updatePort(via(serverPort.what));
  ///     return current; // Returning same instance skips dispose()!
  ///   },
  ///   dispose: (c) => c.close(),
  /// );
  /// ```
  @pragma('vm:prefer-inline')
  What<T> call<T>({
    WhatGuard Function(WhatVia via)? guard,
    required T Function(WhatVia via) create,
    T Function(WhatVia via, T current)? update,
    required void Function(T resource) dispose,
    bool eager = false,
    Graceful? graceful,
  }) {
    if (eager) {
      return graceful != null
          ? _EagerGracefulManagedWhat<T>(
              guard: guard,
              create: create,
              update: update,
              dispose: dispose,
              graceful: graceful,
            )
          : _EagerManagedWhat<T>(
              guard: guard,
              create: create,
              update: update,
              dispose: dispose,
            );
    }
    return graceful != null
        ? _LazyGracefulManagedWhat<T>(
            guard: guard,
            create: create,
            update: update,
            dispose: dispose,
            graceful: graceful,
          )
        : _LazyManagedWhat<T>(
            guard: guard,
            create: create,
            update: update,
            dispose: dispose,
          );
  }
}
