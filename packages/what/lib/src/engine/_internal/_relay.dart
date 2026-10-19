// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Internal Relay Hierarchy
// =============================================================================

abstract base class _Relay extends _Node with _DirtyPusher implements _DirtyListener, _DirtySyncable {
  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    _markDirty();
  }

  bool _isCheckingDirty = false;

  @override
  @pragma('vm:prefer-inline')
  bool _isNewerThan(int version) {
    if (_isCheckingDirty) {
      return true;
    }
    if (_version != version) {
      return true;
    }
    _isCheckingDirty = true;
    try {
      return _isSourceDirty;
    } finally {
      _isCheckingDirty = false;
    }
  }
}

abstract base class _UnaryRelay<N extends _Node> extends _Relay with _UnaryEdgeMixin<N> {}

abstract base class _NaryRelay<N extends _Node> extends _Relay with _NaryEdgeMixin<N> {}

abstract base class _StaticUnaryRelay<N extends _Node> extends _UnaryRelay<N> {
  _StaticUnaryRelay(N source) : _source = source {
    _pulledVersion = source._version;
  }

  @override
  final N _source;
}

abstract base class _CoupledUnaryRelay<N extends _Node> extends _UnaryRelay<N> with _PushOriginMixin {
  _CoupledUnaryRelay(N source) {
    _source = source;
    _pulledVersion = source._version;
  }

  _CoupledUnaryRelay.late() {
    try {
      _source = _catchEmpty();
    } catch (error, stackTrace) {
      _source = _catchError(error, stackTrace);
    }
    _pulledVersion = _source._version;
  }

  @override
  late N _source;

  N _catchEmpty();

  N _catchError(Object error, StackTrace? stackTrace);

  @pragma('vm:prefer-inline')
  void _didUpdateSource(N? oldSource, N? newSource) {
    if (identical(oldSource, newSource) || !_lifecycle.isActive) return;

    if (oldSource != null) {
      oldSource._detachTargetEdgeOptimistically(this);
    }
    if (newSource != null) {
      newSource._attachTargetEdgeOptimistically(this);
    }
  }

  @mustCallSuper
  @pragma('vm:prefer-inline')
  N? _performCouple(N newSource, [bool queuePush = true]) {
    final oldSource = _source;
    if (identical(oldSource, newSource)) return null;
    _version++;
    _source = newSource;
    _pulledVersion = newSource._version;
    _didUpdateSource(oldSource, newSource);
    if (_lifecycle.isActive && queuePush) {
      _PushScope.queueOrigin(this);
    }
    return oldSource;
  }

  @mustCallSuper
  @pragma('vm:prefer-inline')
  N _performDecouple([bool queuePush = true]) {
    final oldSource = _source;
    final emptySource = _catchEmpty();
    _version++;
    _source = emptySource;
    _pulledVersion = emptySource._version;
    _didUpdateSource(oldSource, emptySource);
    if (_lifecycle.isActive && queuePush) {
      _PushScope.queueOrigin(this);
    }
    return oldSource;
  }

  @mustCallSuper
  @pragma('vm:prefer-inline')
  N _setError(Object error, [StackTrace? stackTrace, bool queuePush = true]) {
    final oldSource = _source;
    final errorSource = _catchError(error, stackTrace);
    _version++;
    _source = errorSource;
    _pulledVersion = errorSource._version;
    _didUpdateSource(oldSource, errorSource);
    if (_lifecycle.isActive && queuePush) {
      _PushScope.queueOrigin(this);
    }
    return oldSource;
  }
}

/// Unified state pull and cache management mixin for any relay node with upstream source(s).
base mixin _PullRelay<T> on _Relay, _PullResolver<T> {
  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  void _markDirty() {
    if (_dirtyState != _DirtyState.clean) return;
    _dirtyState = _DirtyState.check;
    super._markDirty();
  }

  @mustCallSuper
  @override
  void _debugInvalidateSelf() {
    super._debugInvalidateSelf();
    _dirtyState = _DirtyState.dirty;
    _state = null;
  }
}
