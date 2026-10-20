// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// LPDAG Engine Diagnostic Errors
// =============================================================================

/// Thrown when a synchronous cyclic reentrancy loop is detected during dirty propagation.
///
/// A node cannot push invalidation signals again while it is actively dispatching to targets.
/// In the 2-Phase LPDAG engine, when state mutates, Phase 1 pushes dirty signals downstream
/// along active edges. If a downstream consumer (such as a synchronous [RawWhatTerminal]
/// `onInvalidated` callback) synchronously mutates an upstream state node, it re-enters the push phase
/// and triggers [LpdagReentrancyError] to prevent an infinite update loop.
///
/// ## System Architectural Flow
/// ```text
/// ┌──────────────────────────┐
/// │       _pushDirty()       │ (_isPushingDirty == true)
/// └─────────────┬────────────┘
///               │
///               ▼ (curr._target._invalidate())
/// ┌──────────────────────────┐
/// │   RawWhatTerminal        │ (Synchronous onInvalidated callback)
/// └─────────────┬────────────┘
///               │
///               ▼ (Synchronous mutation: counter.data++)
/// ┌──────────────────────────┐
/// │       _pushDirty()       │ ──► [LpdagReentrancyError: Reentrant call detected!]
/// └──────────────────────────┘
/// ```
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT synchronously mutate upstream reactive state nodes from inside synchronous
///   invalidation callbacks ([RawWhatTerminal] `onInvalidated`).
/// - For reactive side-effects that trigger follow-up state mutations, defer the mutation
///   to the next microtask or event-loop turn.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Synchronously mutating state inside a synchronous terminal invalidation callback
/// final counter = WhatController(0);
/// final terminal = RawWhatTerminal(
///   counter.what,
///   onInvalidated: () {
///     counter.data++; // Synchronously triggers _pushDirty while propagation is active!
///   },
/// )..activate();
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Defer follow-up mutations to the next microtask or tick
/// final counter = WhatController(0);
/// final terminal = RawWhatTerminal(
///   counter.what,
///   onInvalidated: () {
///     scheduleMicrotask(() => counter.data++);
///   },
/// )..activate();
/// ```
class LpdagReentrancyError extends StateError {
  /// Creates an [LpdagReentrancyError] with an optional descriptive [message].
  ///
  /// * [message]: Optional diagnostic details describing the reentrancy site.
  LpdagReentrancyError([String? message]) : super(message ?? 'Reentrant call to _pushDirty detected.');

  @override
  String toString() => ''
      '[Lpdag] Reentrancy Violation: $message\n'
      'A dirty point cannot push again while it is actively in its '
      'notification phase.\n'
      'This usually occurs when a downstream listener synchronously '
      'mutates an upstream node during event propagation, '
      'causing an infinite update cycle.\n'
      'To resolve:\n'
      '1. Avoid synchronous circular mutations.\n'
      '2. Defer mutations to the next microtask or event loop tick.';
}

/// Thrown when a synchronous cyclic evaluation loop is detected during state resolution or pull.
///
/// A node cannot pull or evaluate its value while it is already in the middle of resolving itself.
/// In Phase 2 (Lazy-Pull), when a derived node ([computed]) resolves its state, it marks itself
/// as actively resolving. If an upstream computation transitively depends on that same node
/// (e.g., A -> B -> A), pulling A triggers B, which attempts to pull A again, triggering
/// [LpdagCycleError] to prevent infinite recursion and stack overflow.
///
/// ## System Architectural Flow
/// ```text
/// ┌──────────────┐          via(b)          ┌──────────────┐
/// │  computed A  │ ───────────────────────> │  computed B  │
/// └──────────────┘                          └──────────────┘
///        ▲                                         │
///        │                 via(a)                  │
///        └─────────────────────────────────────────┘
///             (Cycle Detected: _isResolving == true)
///                             │
///                             ▼
///                    [LpdagCycleError]
/// ```
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT establish cyclic dependency loops between derived computations.
/// - Maintain unidirectional acyclic data flow across all reactive derivations.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Circular evaluation dependency (A -> B -> A)
/// late final What<int> a;
/// late final What<int> b;
///
/// a = computed((via) => via(b) + 1);
/// b = computed((via) => via(a) + 1);
///
/// // Pulling a triggers b, which attempts to pull a while already resolving:
/// untracked(a); // Throws LpdagCycleError
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Unidirectional acyclic data flow from a common upstream source
/// final base = WhatController(1);
/// final a = computed((via) => via(base.what) + 1);
/// final b = computed((via) => via(base.what) * 2);
///
/// print(untracked(a)); // 2
/// print(untracked(b)); // 2
/// ```
class LpdagCycleError extends StateError {
  /// Creates an [LpdagCycleError] with an optional descriptive [message].
  ///
  /// * [message]: Optional diagnostic details describing the cyclic dependency chain.
  LpdagCycleError([String? message]) : super(message ?? 'Cyclic evaluation loop detected.');

  @override
  String toString() => ''
      '[Lpdag] Cyclic Dependency Violation: $message\n'
      'A node cannot pull or evaluate while it is already resolving.\n'
      'This occurs when a computation transitively depends on itself '
      '(e.g., A -> B -> A), causing infinite pull recursion.\n'
      'To resolve:\n'
      '1. Remove the circular dependency between nodes.\n'
      '2. Decouple cyclic reads or break the loop using asynchronous scheduling.';
}
