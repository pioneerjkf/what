// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

abstract base class _Terminal extends _Lifecycle implements _DirtyListener, RawTerminal {
  _Terminal({
    void Function(Object error, StackTrace stackTrace)? onUncaughtError,
  }) : _onUncaughtError = onUncaughtError;

  final void Function(Object error, StackTrace stackTrace)? _onUncaughtError;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
  }

  @override
  void _handleUncaughtError(Object error, StackTrace stackTrace) {
    if (_onUncaughtError != null) {
      try {
        _onUncaughtError(error, stackTrace);
        return;
      } catch (fatalError, fatalStack) {
        _dispatchUncaughtError(error, stackTrace, context: this);
        _dispatchUncaughtError(fatalError, fatalStack, context: this);
        return;
      }
    }
    _dispatchUncaughtError(error, stackTrace, context: this);
  }

  /// Activates the terminal, signaling upstream nodes to track and allocate resources.
  @override
  void activate() {
    if (_lifecycle.isActive) return;
    _activateOptimistically();
  }

  /// Deactivates the terminal, detaching from upstream sources and releasing resources.
  @mustCallSuper
  @override
  void deactivate() {
    if (!_lifecycle.isActive) return;
    _deactivateOptimistically();
  }

  @override
  void debugForceInvalidate() {
    assert(() {
      _debugForceInvalidateInternal(<_Node>{});
      return true;
    }());
  }

  /// Recursively force-invalidates upstream edges sharing the [visited] set.
  void _debugForceInvalidateInternal(Set<_Node> visited) {
    if (this case final _UnaryEdgeMixin unary) {
      unary._source._debugForceInvalidate(visited);
    } else if (this case final _NaryEdgeMixin nary) {
      for (var curr = nary._sourceHead; curr != null; curr = curr._nextSource) {
        curr._source._debugForceInvalidate(visited);
      }
    }
  }
}

/// Synchronous callback terminal executing [_onInvalidated] immediately upon DAG invalidation pulses.
abstract base class _RawTerminal extends _Terminal {
  _RawTerminal({
    required void Function() onInvalidated,
    super.onUncaughtError,
  }) : _onInvalidated = onInvalidated;

  final void Function() _onInvalidated;

  _RawTerminal? _nextFlushTerminal;

  bool _isPushQueued = false;

  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    if (!_lifecycle.isActive) return;
    _PushScope.queueTerminal(this);
  }

  void _invalidateInScope() {
    if (!_lifecycle.isActive) return;
    try {
      _onInvalidated.call();
    } catch (error, stackTrace) {
      _handleUncaughtError(error, stackTrace);
    }
  }
}

/// Foundational base mixin for all What effect and scheduled terminals.
///
/// Implements self-scheduling behavior upon invalidation pulses, bypassing manual
/// callback invocations and synchronous push batch queues.
base mixin _ScheduledTerminalMixin on _Terminal implements _TerminalSchedulable {
  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    if (!_lifecycle.isActive) return;
    _Scheduler.instance._scheduleTerminal(this);
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _Scheduler.instance._cancelTerminal(this);
    super._deactivate();
  }
}

/// Shared reactive pipeline core for n-ary [WhatVia] dynamic evaluators.
base mixin _ViaTerminalMixin<T> on _Terminal, _NaryEdgeMixin<_Node>, _WhatViaEpochMixin {
  late final T Function(WhatVia via) _evaluator;
  bool _isEvaluating = false;

  /// Evaluates the compute closure with an injected [WhatVia] dependency tracker.
  ///
  /// Increments the internal epoch counter, executes the evaluator closure with [WhatVia],
  /// explicitly registers all observed dependencies via `via(node)`, and sweeps obsolete
  /// edges in a single pass at the end of the evaluation turn.
  ///
  /// **Ensures:**
  /// * Returns the computed payload of type [T].
  /// * Commits observed dependency versions and purges unused conditional branches.
  ///
  /// **Throws:**
  /// * Throws [LpdagCycleError] if a cyclic dependency loop is detected during evaluation.
  @pragma('vm:prefer-inline')
  T evaluate() {
    if (_isEvaluating) {
      throw LpdagCycleError(
        'Cyclic evaluation loop detected in RawViaTerminal while evaluating evaluator closure.',
      );
    }
    _isEvaluating = true;
    final currentEpoch = _beginEpoch();
    var succeeded = true;
    try {
      return _evaluator(_via);
    } catch (e) {
      succeeded = e is _ViaShortCircuit;
      rethrow;
    } finally {
      _endEpoch(currentEpoch, succeeded: succeeded, commitVersions: true);
      _isEvaluating = false;
    }
  }
}

/// Shared reactive pipeline core for 1:1 [What] terminals ([RawWhatTerminal]).
base mixin _WhatTerminalMixin<T> on _Terminal, _UnaryEdgeMixin<What<T>>, _WhatStateMixin<T> {
  @override
  late What<T> _source;

  @override
  _WhatState<T> _read() {
    final state = _source._read();
    _pullVersion();
    return state;
  }

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _pullVersion();
  }
}
