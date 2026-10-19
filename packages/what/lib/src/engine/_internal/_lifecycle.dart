// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// An interface for handling exceptions that occur during internal framework operations.
/// This acts as a generic error sink for lifecycle transitions, topology changes,
/// reactivity propagation, and user callbacks to prevent the framework core from crashing.
abstract interface class _ErrorSink {
  void _handleUncaughtError(Object error, StackTrace stackTrace);
}

enum _LifecycleState {
  // Inactive state: The object cannot perform its function
  inactive,

  // Running state: Active and currently performing its function
  running;

  @pragma('vm:prefer-inline')
  bool get isActive => this != inactive;
}

abstract base class _Lifecycle implements _ErrorSink, LpdagStatus {
  _LifecycleState _lifecycle = _LifecycleState.inactive;

  @override
  @pragma('vm:prefer-inline')
  bool get isActive => _lifecycle.isActive;

  @mustCallSuper
  void _activate() {
    assert(!_lifecycle.isActive, 'Cannot activate from $_lifecycle');
    _lifecycle = _LifecycleState.running;
  }

  @mustCallSuper
  void _deactivate() {
    assert(_lifecycle.isActive, 'Cannot deactivate from $_lifecycle');
    _lifecycle = _LifecycleState.inactive;
  }

  @mustCallSuper
  void _activateOptimistically() {
    if (_lifecycle.isActive) return;
    try {
      _activate();
    } catch (error, stackTrace) {
      _handleUncaughtError(error, stackTrace);
    }
  }

  @mustCallSuper
  void _deactivateOptimistically() {
    if (!_lifecycle.isActive) return;
    try {
      _deactivate();
    } catch (error, stackTrace) {
      _handleUncaughtError(error, stackTrace);
    }
  }
}
