// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// ignore_for_file: must_call_super

abstract base class _ManagedWhat<T> extends _NaryRelay<_Node>
    with _WhatViaEpochMixin, _WhatStateMixin<T>, _WhatPeekMixin<T>, _PullResolver<T>, _PullRelay<T>
    implements What<T> {
  _ManagedWhat({
    WhatGuard Function(WhatVia via)? guard,
    required T Function(WhatVia via) create,
    T Function(WhatVia via, T current)? update,
    required void Function(T resource) dispose,
  })  : _guard = guard,
        _createResource = create,
        _updateResource = update,
        _disposeResource = dispose;

  final WhatGuard Function(WhatVia via)? _guard;
  final T Function(WhatVia via) _createResource;
  final T Function(WhatVia via, T current)? _updateResource;
  final void Function(T resource) _disposeResource;

  void _disposeCurrent() {
    final oldState = _state;
    _state = null;
    _dirtyState = _DirtyState.dirty;
    if (oldState != null && oldState.hasData) {
      try {
        _disposeResource.call(oldState.data);
      } catch (error, stackTrace) {
        _handleUncaughtError(error, stackTrace);
      }
    }
  }

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _pull() {
    final currentEpoch = _beginEpoch();
    var succeeded = true;
    try {
      final guard = _guard;
      if (guard != null) {
        final decision = guard(_via);
        if (!decision.isPass) {
          final hadData = _state?.hasData ?? false;
          _disposeCurrent();
          if (hadData) {
            _version++;
          }
          return _state = _EmptyWhatState<T>(decision.reason);
        }
      }

      final currentState = _state;
      if (currentState != null && currentState.hasData && _updateResource != null) {
        final current = currentState.data;
        final next = _updateResource.call(_via, current);
        if (!identical(current, next)) {
          _version++;
          try {
            _disposeResource.call(current);
          } catch (error, stackTrace) {
            _handleUncaughtError(error, stackTrace);
          }
        }
        if (currentState case final _ValidWhatState<T> s) {
          s.update(next);
          return _state = s;
        } else {
          return _state = _ValidWhatState(next);
        }
      } else {
        _disposeCurrent();
        _version++;
        final res = _createResource.call(_via);
        final current = _state;
        if (current case final _ValidWhatState<T> s) {
          s.update(res);
          return _state = s;
        } else {
          return _state = _ValidWhatState(res);
        }
      }
    } catch (error, stackTrace) {
      succeeded = error is _ViaShortCircuit;
      _disposeCurrent();
      _version++;
      return _state = _WhatState.fromCaught(error, stackTrace);
    } finally {
      _endEpoch(currentEpoch, succeeded: succeeded, commitVersions: false);
    }
  }

  @override
  @pragma('vm:prefer-inline')
  void _resolve() {
    if (_isResolving) {
      throw LpdagCycleError(
        'Cyclic evaluation loop detected in $runtimeType while resolving state.',
      );
    }
    if (!_lifecycle.isActive) {
      _state ??= _EmptyWhatState<T>();
      return;
    }
    super._resolve();
  }

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _read() {
    _resolve();
    return _state ??= _EmptyWhatState<T>();
  }

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    if (_state != null && !_state!.hasData) {
      _state = null;
      _dirtyState = _DirtyState.dirty;
    }
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _disposeCurrent();
    super._deactivate();
  }

  @mustCallSuper
  @override
  void _debugInvalidateSelf() {
    _disposeCurrent();
    super._debugInvalidateSelf();
  }
}

/// Lifecycle-managed resource node with on-demand Lazy allocation and updates.
base class _LazyManagedWhat<T> extends _ManagedWhat<T> {
  _LazyManagedWhat({
    super.guard,
    required super.create,
    super.update,
    required super.dispose,
  });
}

/// Eager variant of [_ManagedWhat] that pre-emptively allocates and updates in microtask.
base class _EagerManagedWhat<T> extends _ManagedWhat<T> implements _EagerSchedulable {
  _EagerManagedWhat({
    super.guard,
    required super.create,
    super.update,
    required super.dispose,
  });

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    if (_dirtyState != _DirtyState.clean || _state == null || !_state!.hasData) {
      _resolve();
    }
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _Scheduler.instance._cancelEager(this);
    super._deactivate();
  }

  @override
  void _invalidate() {
    super._invalidate();
    if (_lifecycle.isActive) {
      _Scheduler.instance._scheduleEager(this);
    }
  }

  @override
  void _performScheduledEager() {
    if (!_lifecycle.isActive || _dirtyState == _DirtyState.clean) return;
    _resolve();
  }
}

/// Lifecycle-managed resource node with graceful deactivation (Lazy).
final class _LazyGracefulManagedWhat<T> extends _LazyManagedWhat<T> with _GracefulNodeMixin {
  _LazyGracefulManagedWhat({
    super.guard,
    required super.create,
    super.update,
    required super.dispose,
    required Graceful graceful,
  }) : _graceful = graceful;

  @override
  final Graceful _graceful;
}

/// Lifecycle-managed resource node with graceful deactivation (Eager).
final class _EagerGracefulManagedWhat<T> extends _EagerManagedWhat<T> with _GracefulNodeMixin {
  _EagerGracefulManagedWhat({
    super.guard,
    required super.create,
    super.update,
    required super.dispose,
    required Graceful graceful,
  }) : _graceful = graceful;

  @override
  final Graceful _graceful;
}
