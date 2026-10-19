// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Internal plumbing mixin that directly bridges [WhatState] inspection getters to the
/// underlying physical 3-State FSM container ([_read()]).
///
/// ---
/// ### [CRITICAL ARCHITECTURAL & COMPILER INVARIANTS] (DO NOT MODIFY)
///
/// 1. **DO NOT Expose as Public (`_WhatStateMixin` MUST Remain Private)**:
///    * This mixin is strictly internal engine plumbing designed to eliminate repetitive
///      boilerplate across internal reactive entities (concrete nodes like `_Entry`,
///      `_ConstantWhat`, `_ComputedWhatBase`, `_DeltaWhat`, `_CoupledWhat`, `_ManagedWhat`,
///      `_ElementsWhat`, plus `WhatController`, `RawWhatTerminal`, `WhatCoupler`, etc.).
///    * Note: [What] itself does NOT mix in `_WhatStateMixin` on its static public surface,
///      keeping the untracked raw read surface strictly confined to `.peek` and `.peekState`.
///    * It requires direct access to the private sealed container [_WhatState<T>]. Exposing
///      this mixin publicly would leak engine memory layout details across the library boundary.
///
/// 2. **`_read()` MUST Return Sealed `_WhatState<T>`, NOT `WhatState<T>`**:
///    * **Sealed Hierarchy & Fast Dispatch Guarantee**: [_WhatState<T>] is a strictly library-private
///      `sealed class` whose hierarchy is 100% closed to exactly three leaves:
///      `_ValidWhatState<T>`, `_EmptyWhatState<T>`, and `_ErrorWhatState<T>`.
///    * In the 99.999% hot path (`_ValidWhatState`), `data` is a concrete memory field.
///      Keeping `_read()` returning the closed sealed hierarchy allows Dart AOT Type Flow Analysis (TFA)
///      to specialize inspection paths with minimal class-ID checks and inline getters.
///    * **Scope of Application**: `_read()` and the `via(x)` hot path require zero extra indirection.
///      On the other hand, `via.state(x)` and `x.peekState` return the live node itself (`WhatState<T>`),
///      incurring a single node-level interface dispatch (+~0.8 ns) which eliminates aliasing inconsistency
///      while maintaining 0 heap allocations (see roadmap/ai_readiness/A5_peek_raw_read_rename.md §2.4).
base mixin _WhatStateMixin<T> implements WhatState<T> {
  _WhatState<T> _read();

  /// The immutable snapshot representation of the current state of this [WhatState] entity.
  @override
  @pragma('vm:prefer-inline')
  WhatSnapshot<T> get snapshot => _read().snapshot;

  @override
  @pragma('vm:prefer-inline')
  T get data => _read().data;

  @override
  @pragma('vm:prefer-inline')
  T? get dataOrNull => _read().dataOrNull;

  @override
  @pragma('vm:prefer-inline')
  T dataOrElse(T Function() fallback) => _read().dataOrElse(fallback);

  @override
  @pragma('vm:prefer-inline')
  bool get hasData => _read().hasData;

  @override
  @pragma('vm:prefer-inline')
  bool get isEmpty => _read().isEmpty;

  @override
  @pragma('vm:prefer-inline')
  Object? get emptyReason => _read().emptyReason;

  @override
  @pragma('vm:prefer-inline')
  bool get hasError => _read().hasError;

  @override
  @pragma('vm:prefer-inline')
  Object get error => _read().error;

  @override
  @pragma('vm:prefer-inline')
  StackTrace get stackTrace => _read().stackTrace;

  @override
  @pragma('vm:prefer-inline')
  bool equals(covariant WhatState<T> other, [bool Function(T previous, T next)? equals]) =>
      _read().equals(other, equals);
}

/// Internal plumbing mixin that implements untracked raw read members ([peek], [peekState])
/// on [What] nodes without exposing them on [WhatController], [RawWhatTerminal], etc.
base mixin _WhatPeekMixin<T> on _Node, WhatState<T> implements What<T> {
  @override
  _WhatState<T> _read();

  @override
  @pragma('vm:prefer-inline')
  T get peek => _read().data;

  @override
  @pragma('vm:prefer-inline')
  WhatState<T> get peekState => this;
}

// =============================================================================
// Physical State Container Hierarchy (_WhatState & 3-State FSM)
// =============================================================================

/// The internal, high-throughput state container protocol for the What reactive DAG engine.
///
/// Unlike public immutable [WhatSnapshot]s, [_WhatState] instances are owned by their
/// respective nodes and support in-place mutation on hot paths, achieving zero heap
/// allocations during high-frequency tick processing.
sealed class _WhatState<T> implements WhatState<T> {
  const _WhatState();

  /// Central factory translating caught derivation exceptions or short-circuits
  /// into the proper [_WhatState<T>] representation.
  @pragma('vm:prefer-inline')
  factory _WhatState.fromCaught(Object error, StackTrace stackTrace) {
    if (error is _ViaShortCircuit) {
      return error.state._retype<T>();
    }
    return _ErrorWhatState<T>(error, stackTrace);
  }

  /// Retypes this non-data state container to an alternate type [R].
  ///
  /// Used during short-circuit propagation to forward Empty/Error states
  /// without reallocating error payloads or losing diagnostic empty reasons.
  _WhatState<R> _retype<R>();
}

/// The 99.999% hot-path state container representing valid data.
///
/// Supports zero-allocation in-place data mutation via [update].
///
/// ---
/// ### [HOT-PATH PERFORMANCE CRITICAL GUIDELINES]
/// When testing or matching on this container inside engine nodes:
///
/// 1. **DO NOT** use generic type testing on raw states:
///    * **AVOID:** `if (state is _ValidWhatState<T>)`
///    * **Reason**: Forces Dart VM `SubtypeTestCache` runtime lookup (10x-20x slower).
///
/// 2. **DO NOT** use object pattern destructuring:
///    * **AVOID:** `if (state case _ValidWhatState(:final data))`
///    * **AVOID:** `if (state case _ValidWhatState())`
///    * **Reason**: Dart type inference silently injects `<T>`, re-triggering `SubtypeTestCache` (10x-20x slower).
///
/// 3. **PREFERRED ZERO-OVERHEAD PATTERNS**:
///    * **When reading `data` only**: Use `if (state is _ValidWhatState)` followed by `state.data`.
///      (Single CPU Class ID `cmp` instruction, 0 SubtypeTestCache lookups, and `state.data`
///      statically resolves to `T` without dynamic downcasts).
///    * **When mutating in-place (`update`)**: Use `if (state case final _ValidWhatState<T> s) { s.update(next); }`.
///      (Ensures strict static typing on `update(T next)` while retaining in-place mutation).
final class _ValidWhatState<T> extends _WhatState<T> {
  _ValidWhatState(this.data);

  @override
  T data;

  @pragma('vm:prefer-inline')
  void update(T nextData) {
    data = nextData;
  }

  @override
  @pragma('vm:prefer-inline')
  bool get hasData => true;

  @override
  @pragma('vm:prefer-inline')
  bool get isEmpty => false;

  @override
  @pragma('vm:prefer-inline')
  bool get hasError => false;

  @override
  @pragma('vm:prefer-inline')
  Object? get emptyReason => null;

  @override
  @pragma('vm:prefer-inline')
  T? get dataOrNull => data;

  @override
  @pragma('vm:prefer-inline')
  T dataOrElse(T Function() fallback) => data;

  @override
  @pragma('vm:prefer-inline')
  Object get error => throw WhatSnapshotStateException('Valid', 'No error was found in this valid state.');

  @override
  @pragma('vm:prefer-inline')
  StackTrace get stackTrace =>
      throw WhatSnapshotStateException('Valid', 'No stackTrace was found in this valid state.');

  @override
  @pragma('vm:prefer-inline')
  bool equals(covariant WhatState<T> other, [bool Function(T previous, T next)? equals]) {
    if (identical(this, other)) return true;
    if (!other.hasData) return false;
    final otherData = other.data;
    if (identical(data, otherData)) return true;
    return null != equals ? equals(data, otherData) : otherData == data;
  }

  @override
  @pragma('vm:prefer-inline')
  WhatSnapshot<T> get snapshot => _ValidWhatSnapshot<T>(data);

  @override
  _WhatState<R> _retype<R>() => throw StateError('Cannot retype valid state in short-circuit.');
}

/// Cold-path state container representing an uninitialized/dormant state.
final class _EmptyWhatState<T> extends _WhatState<T> {
  const _EmptyWhatState([this.emptyReason]);

  @override
  final Object? emptyReason;

  @override
  @pragma('vm:prefer-inline')
  bool get hasData => false;

  @override
  @pragma('vm:prefer-inline')
  bool get isEmpty => true;

  @override
  @pragma('vm:prefer-inline')
  bool get hasError => false;

  @override
  @pragma('vm:prefer-inline')
  T get data => throw WhatSnapshotExtractionException('Empty', 'No data available in this empty state.');

  @override
  @pragma('vm:prefer-inline')
  T? get dataOrNull => null;

  @override
  @pragma('vm:prefer-inline')
  T dataOrElse(T Function() fallback) => fallback.call();

  @override
  @pragma('vm:prefer-inline')
  Object get error => throw WhatSnapshotStateException('Empty', 'No error was found in this empty state.');

  @override
  @pragma('vm:prefer-inline')
  StackTrace get stackTrace =>
      throw WhatSnapshotStateException('Empty', 'No stackTrace was found in this empty state.');

  @override
  @pragma('vm:prefer-inline')
  bool equals(covariant WhatState<T> other, [bool Function(T previous, T next)? equals]) {
    if (identical(this, other)) return true;
    return other.isEmpty && other.emptyReason == emptyReason;
  }

  @override
  @pragma('vm:prefer-inline')
  WhatSnapshot<T> get snapshot => _EmptyWhatSnapshot<T>(emptyReason);

  @override
  @pragma('vm:prefer-inline')
  _WhatState<R> _retype<R>() => _EmptyWhatState<R>(emptyReason);
}

/// Cold-path state container representing a failed computation.
final class _ErrorWhatState<T> extends _WhatState<T> {
  const _ErrorWhatState(this.error, [StackTrace? stackTrace]) : stackTrace = stackTrace ?? StackTrace.empty;

  @override
  final Object error;

  @override
  final StackTrace stackTrace;

  @override
  @pragma('vm:prefer-inline')
  bool get hasData => false;

  @override
  @pragma('vm:prefer-inline')
  bool get isEmpty => false;

  @override
  @pragma('vm:prefer-inline')
  bool get hasError => true;

  @override
  @pragma('vm:prefer-inline')
  T get data => throw WhatSnapshotExtractionException(
        'Error',
        'This state contains an error instead of data.',
        error: error,
        stackTrace: stackTrace,
      );

  @override
  @pragma('vm:prefer-inline')
  Object? get emptyReason => null;

  @override
  @pragma('vm:prefer-inline')
  T? get dataOrNull => null;

  @override
  @pragma('vm:prefer-inline')
  T dataOrElse(T Function() fallback) => fallback.call();

  @override
  @pragma('vm:prefer-inline')
  bool equals(covariant WhatState<T> other, [bool Function(T previous, T next)? equals]) {
    if (identical(this, other)) return true;
    return other.hasError && other.error == error && other.stackTrace == stackTrace;
  }

  @override
  @pragma('vm:prefer-inline')
  WhatSnapshot<T> get snapshot => _ErrorWhatSnapshot<T>(error, stackTrace);

  @override
  @pragma('vm:prefer-inline')
  _WhatState<R> _retype<R>() => _ErrorWhatState<R>(error, stackTrace);
}
