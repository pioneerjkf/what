// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Foundation: Base Class & Pull Mixin
// =============================================================================

/// Abstract base class for reactive computed nodes that track dependencies via [_WhatViaEpochMixin].
abstract base class _ComputedWhatBase<T> extends _NaryRelay<_Node>
    with _WhatViaEpochMixin, _WhatStateMixin<T>, _WhatPeekMixin<T>, _PullResolver<T>, _PullRelay<T>
    implements What<T> {}

/// Dynamic dependency tracking and compute execution mixin via [WhatVia].
///
/// Encapsulates explicit dependency tracking, guard evaluations, exception
/// isolation, and 1-pass epoch sweeping for any node that evaluates a [WhatVia] closure.
base mixin _ComputedPullMixin<T> on _PullResolver<T>, _WhatViaEpochMixin {
  T Function(WhatVia via) get _compute;
  WhatGuard Function(WhatVia via)? get _guard;

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _pull() {
    if (this case final _Node node) {
      node._version++;
    }
    final currentEpoch = _beginEpoch();
    _WhatState<T> state;
    var succeeded = true;
    try {
      final guard = _guard;
      if (guard != null) {
        final decision = guard(_via);
        if (!decision.isPass) {
          state = _EmptyWhatState<T>(decision.reason);
          return state;
        }
      }
      final result = _compute(_via);
      final current = _state;
      if (current case final _ValidWhatState<T> s) {
        s.update(result);
        state = s;
      } else {
        state = _ValidWhatState<T>(result);
      }
    } catch (error, stackTrace) {
      succeeded = error is _ViaShortCircuit;
      state = _WhatState.fromCaught(error, stackTrace);
    } finally {
      _endEpoch(currentEpoch, succeeded: succeeded, commitVersions: false);
    }
    return state;
  }
}

// =============================================================================
// 1. Synchronous Computed Nodes
// =============================================================================

/// A reactive [What] node that computes its value dynamically with explicit [WhatVia] dependency tracking.
base class _ComputedWhat<T> extends _ComputedWhatBase<T> with _ComputedPullMixin<T> {
  _ComputedWhat(
    this._compute, {
    WhatGuard Function(WhatVia via)? guard,
  }) : _guard = guard;

  @override
  final T Function(WhatVia via) _compute;
  @override
  final WhatGuard Function(WhatVia via)? _guard;
}

/// Internal reactive node powering a [Computation] component.
base class _ComputationWhat<T> extends _ComputedWhatBase<T> {
  _ComputationWhat(this._computation);

  static What<T> create<T>(Computation<T> computation) {
    try {
      if (computation is WhatLifecycleAware) {
        return _LifecycleAwareComputationWhat<T>(computation);
      }
      return _ComputationWhat<T>(computation);
    } catch (error, stackTrace) {
      return What.error(error, stackTrace);
    }
  }

  final Computation<T> _computation;

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _pull() {
    _version++;
    final currentEpoch = _beginEpoch();

    _WhatState<T> state;
    var succeeded = true;
    try {
      final decision = _computation.guard(_via);
      if (!decision.isPass) {
        state = _EmptyWhatState<T>(decision.reason);
      } else {
        final result = _computation.compute(_via);
        final current = _state;
        if (current case final _ValidWhatState<T> s) {
          s.update(result);
          state = s;
        } else {
          state = _ValidWhatState<T>(result);
        }
      }
    } catch (error, stackTrace) {
      succeeded = error is _ViaShortCircuit;
      state = _WhatState.fromCaught(error, stackTrace);
    } finally {
      _endEpoch(currentEpoch, succeeded: succeeded, commitVersions: false);
    }

    return _state = state;
  }
}

/// Lifecycle-aware variant of [_ComputationWhat].
base class _LifecycleAwareComputationWhat<T> extends _ComputationWhat<T> {
  _LifecycleAwareComputationWhat(super.computation);

  WhatLifecycleAware get _lifecycleAware => _computation as WhatLifecycleAware;

  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  void _activate() {
    super._activate();
    try {
      _lifecycleAware.didActivate();
    } catch (error, stackTrace) {
      _handleUncaughtError(error, stackTrace);
    }
  }

  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  void _deactivate() {
    super._deactivate();
    try {
      _lifecycleAware.didDeactivate();
    } catch (error, stackTrace) {
      _handleUncaughtError(error, stackTrace);
    }
  }
}

// =============================================================================
// 2. Asynchronous Computed Nodes (Future & Stream)
// =============================================================================

/// Future-based asynchronous computation node backed by [_FutureWhatBridge] and dynamic delta.
final class _FutureComputedWhat<T> extends _EagerDeltaWhat<T> implements What<T> {
  _FutureComputedWhat(
    Future<T> Function(WhatVia via) compute, {
    WhatGuard Function(WhatVia via)? guard,
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
  })  : _computeFuture = compute,
        _guard = guard,
        _initialFactory = initialFactory,
        _onError = onError;

  final Future<T> Function(WhatVia via) _computeFuture;
  final WhatGuard Function(WhatVia via)? _guard;
  final T Function()? _initialFactory;
  final T Function(Object error, [StackTrace? stackTrace])? _onError;

  @override
  bool get _isGuarded => _guard != null;

  @override
  What<T> _evaluateDelta(WhatVia via) {
    final guard = _guard;
    if (guard != null) {
      final decision = guard.call(via);
      if (!decision.isPass) {
        return What.empty(decision.reason);
      }
    }
    final future = _computeFuture(via);
    return _FutureWhatBridge<T>(
      future,
      initialFactory: _initialFactory,
      onError: _onError,
    ).what;
  }
}

/// Stream-based asynchronous computation node backed by [_StreamWhatBridge] and dynamic delta.
final class _StreamComputedWhat<T> extends _EagerDeltaWhat<T> implements What<T> {
  _StreamComputedWhat(
    Stream<T> Function(WhatVia via) compute, {
    WhatGuard Function(WhatVia via)? guard,
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
    bool? cancelOnError,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    Graceful? graceful,
  })  : _computeStream = compute,
        _guard = guard,
        _initialFactory = initialFactory,
        _onError = onError,
        _cancelOnError = cancelOnError,
        _distinct = distinct,
        _equals = equals,
        _graceful = graceful;

  final Stream<T> Function(WhatVia via) _computeStream;
  final WhatGuard Function(WhatVia via)? _guard;
  final T Function()? _initialFactory;
  final T Function(Object error, [StackTrace? stackTrace])? _onError;
  final bool? _cancelOnError;
  final bool _distinct;
  final bool Function(T previous, T next)? _equals;
  final Graceful? _graceful;

  @override
  bool get _isGuarded => _guard != null;

  @override
  What<T> _evaluateDelta(WhatVia via) {
    final guard = _guard;
    if (guard != null) {
      final decision = guard.call(via);
      if (!decision.isPass) {
        return What.empty(decision.reason);
      }
    }
    final stream = _computeStream(via);
    return _StreamWhatBridge.create<T>(
      stream,
      initialFactory: _initialFactory,
      onError: _onError,
      cancelOnError: _cancelOnError,
      distinct: _distinct,
      equals: _equals,
      graceful: _graceful,
    ).what;
  }
}
