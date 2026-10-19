// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Internal handle managing the lifecycle, cancellation, and resource release of a grace period.
abstract base class _GraceHandle {
  _GraceHandle({required this.node});

  final _Node node;
  bool _isDischarged = false;

  /// Cancels the grace period immediately upon early reconnect.
  void cancel();
}

/// Lightweight microtask grace handle deferring deactivation via [_Scheduler] without allocating edges.
final class _MicrotaskGraceHandle extends _GraceHandle {
  _MicrotaskGraceHandle({required _GracefulNodeMixin super.node});

  @override
  _GracefulNodeMixin get node => super.node as _GracefulNodeMixin;

  void _start() {
    _Scheduler.instance._scheduleGraceHandle(this);
  }

  @override
  void cancel() {
    if (_isDischarged) return;
    _isDischarged = true;
    _Scheduler.instance._cancelGraceHandle(this);
  }

  void _onExpired() {
    if (_isDischarged) return;
    _isDischarged = true;
    node._graceHandle = null;
    if (!node._hasTargets && node._lifecycle.isActive) {
      node._deactivateOptimistically();
    }
  }
}

// =============================================================================
// Graceful Policy Implementations & Mixin
// =============================================================================

/// Functor and default microtask-deferred graceful policy instance.
base class _MicrotaskGraceful implements Graceful {
  const _MicrotaskGraceful();

  @override
  @pragma('vm:prefer-inline')
  _GraceHandle _enterGrace(_GracefulNodeMixin node) {
    final handle = _MicrotaskGraceHandle(node: node);
    handle._start();
    return handle;
  }
}

final class _PeriodGraceful implements Graceful {
  const _PeriodGraceful(this.duration);

  /// The duration to keep the node moored in the active state.
  final Duration duration;

  @override
  @pragma('vm:prefer-inline')
  _GraceHandle _enterGrace(_GracefulNodeMixin node) {
    return _MooringTerminal.instance.moor(node, duration);
  }
}

/// Core reusable topology mixin providing Pre-Detach Mooring and Early Return for graceful nodes.
base mixin _GracefulNodeMixin on _Node {
  Graceful get _graceful;
  _GraceHandle? _graceHandle;

  @mustCallSuper
  @override
  void _attachTargetEdgeOptimistically(_TargetEdge target) {
    super._attachTargetEdgeOptimistically(target);
    if (_graceHandle case final handle?) {
      _graceHandle = null;
      handle.cancel();
    }
  }

  @mustCallSuper
  @override
  void _detachTargetEdgeOptimistically(_TargetEdge target) {
    if (target is! _MooringEdge &&
        _graceHandle == null &&
        identical(_targetHead, target) &&
        target._nextTarget == null) {
      _graceHandle = _graceful._enterGrace(this);
    }
    super._detachTargetEdgeOptimistically(target);
  }

  @mustCallSuper
  @override
  void _deactivateOptimistically() {
    if (_graceHandle != null) return;
    super._deactivateOptimistically();
  }
}
