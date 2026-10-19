// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Core 2-Phase LPDAG Lazy-Pull Resolvers
// =============================================================================

/// Core Lazy-Pull and state cache resolution mixin for any node with upstream source(s).
///
/// Encapsulates the 2-Phase LPDAG Lazy-Pull invariant:
/// * Zero computation during push-dirty phase.
/// * Cycle detection ([LpdagCycleError]).
/// * Dynamic upstream dirty checking via [_DirtySyncable].
/// * Lazy state resolution and version synchronization.
base mixin _PullResolver<T> on _Lifecycle, _DirtySyncable, _WhatStateMixin<T> {
  _WhatState<T>? _state;
  _DirtyState _dirtyState = _DirtyState.clean;
  bool _isResolving = false;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    if (_dirtyState == _DirtyState.clean && _isSourceDirty) {
      _dirtyState = _DirtyState.check;
    }
  }

  /// Computes and returns the fresh state.
  ///
  /// **CRITICAL ARCHITECTURAL INVARIANT (Exception Isolation Guarantee):**
  /// Implementations of this method MUST NEVER allow unhandled exceptions to escape.
  /// All user computations, projections, selectors, and upstream state extractions
  /// must be enclosed in `try-catch` blocks and converted into a [_ErrorWhatState<T>]
  /// (or appropriately handled snapshot state).
  ///
  /// Throwing an uncaught exception from [_pull] will interrupt the state resolution
  /// pipeline in [_resolve], leaving [_state] uninitialized and causing subsequent
  /// state reads to fail.
  _WhatState<T> _pull();

  /// Resolves the node's internal state and computes the fresh state if needed.
  @pragma('vm:prefer-inline')
  void _resolve() {
    if (_isResolving) {
      throw LpdagCycleError(
        'Cyclic evaluation loop detected in $runtimeType while resolving state.',
      );
    }
    _isResolving = true;
    try {
      if (!_lifecycle.isActive && _isSourceDirty) {
        _dirtyState = _DirtyState.dirty;
      }
      if (_dirtyState == _DirtyState.check) {
        if (!_resolveDirty() && _state != null) {
          _dirtyState = _DirtyState.clean;
          _pullVersion();
          return;
        }
        _dirtyState = _DirtyState.dirty;
      }
      if (_dirtyState == _DirtyState.dirty || _state == null) {
        _state = _pull();
        _dirtyState = _DirtyState.clean;
        _pullVersion();
      }
    } finally {
      _isResolving = false;
    }
  }

  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _read() {
    _resolve();
    return _state!;
  }
}
