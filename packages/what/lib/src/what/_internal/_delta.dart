// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// ============================================================================
// Dynamic Delta Core (Topological Control-Plane Rerouting Engine)
// ============================================================================

/// Base reactive relay node that dynamically couples and reroutes its mainstream
/// upstream source based on lateral control-plane mutations evaluated through a [RawViaTerminal].
abstract base class _DeltaWhat<T> extends _CoupledUnaryRelay<What<T>>
    with _WhatStateMixin<T>
    implements What<T> {
  _DeltaWhat() : super.late() {
    _deltaTerminal = RawViaTerminal(_evaluateDelta, onInvalidated: _onDeltaDirty);
  }

  /// Control-plane terminal observing lateral upstream signals that steer and reroute the pipeline.
  ///
  /// The active [_source] constitutes the continuous mainstream data plane.
  /// Rather than using ambiguous "trigger" semantics—which often blur the distinction
  /// between the primary data pipeline and its topological routing conditions—the "delta"
  /// represents a structural control-plane mutation vector that dynamically reroutes
  /// and rebinds the mainstream pipeline to an alternate branch.
  late final RawViaTerminal<What<T>> _deltaTerminal;

  bool _needsSwitch = true;
  bool _isResolving = false;

  /// Subclasses with a guard condition override this to return whether a guard is configured.
  bool get _isGuarded => false;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _deltaTerminal.activate();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _needsSwitch = true;
    _deltaTerminal.deactivate();
    _performDecouple(false);
    super._deactivate();
  }

  @override
  @pragma('vm:prefer-inline')
  bool get _isSourceDirty => _deltaTerminal._isSourceDirty || super._isSourceDirty;

  @override
  @pragma('vm:prefer-inline')
  void _pullVersion() {
    _deltaTerminal._pullVersion();
    super._pullVersion();
  }

  @override
  @pragma('vm:prefer-inline')
  void _resolve() {
    if (_isResolving) {
      throw LpdagCycleError(
        'Cyclic evaluation loop detected in $runtimeType while resolving switched state.',
      );
    }
    _isResolving = true;
    try {
      if (!_lifecycle.isActive && _deltaTerminal._isSourceDirty) {
        _needsSwitch = true;
      }
      if (_needsSwitch) {
        _needsSwitch = false;
        _performSwitchGuarded(false);
        // If inactive and the guard failed (yielding What.empty), do not advance
        // `_deltaTerminal._pullVersion()`. Acknowledging upstream versions while
        // dormant would falsely clear `_isSourceDirty`, locking the node into an
        // empty state even after activation. Defer resolution by keeping `_needsSwitch = true`.
        if (!_lifecycle.isActive && _isGuarded && _source._read().isEmpty) {
          _needsSwitch = true;
          return;
        }
        _deltaTerminal._pullVersion();
      }
      _source._resolve();
      if (_source._version != _pulledVersion) {
        _version++;
        _pullVersion();
      }
    } finally {
      _isResolving = false;
    }
  }

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _read() {
    _resolve();
    return _source._read();
  }

  @mustCallSuper
  void _performSwitchGuarded([bool queuePush = true]) {
    try {
      final result = _deltaTerminal.evaluate();
      _performCouple(result, queuePush);
    } on _ViaShortCircuit catch (e) {
      final state = e.state;
      if (state is _EmptyWhatState) {
        _performCouple(What.empty(state.emptyReason), queuePush);
        return;
      }
      if (state is _ErrorWhatState) {
        _performCouple(What.error(state.error, state.stackTrace), queuePush);
        return;
      }
      _performCouple(_catchError(e, null), queuePush);
    } catch (error, stackTrace) {
      _performCouple(_catchError(error, stackTrace), queuePush);
    }
  }

  /// Evaluates the control-plane delta to determine the next source [What].
  What<T> _evaluateDelta(WhatVia via);

  void _onDeltaDirty();

  @override
  What<T> _catchEmpty() => What.empty();

  @override
  What<T> _catchError(Object error, StackTrace? stackTrace) => What.error(error, stackTrace);

  @mustCallSuper
  @override
  void _debugInvalidateSelf() {
    _deltaTerminal.deactivate();
    _deltaTerminal.activate();
    super._debugInvalidateSelf();
  }
}

/// Lazy scheduling policy for [_DeltaWhat]: marks dirty and defers switching until observed.
abstract base class _LazyDeltaWhat<T> extends _DeltaWhat<T> {
  _LazyDeltaWhat();

  @override
  void _onDeltaDirty() {
    _needsSwitch = true;
    _invalidate();
  }
}

/// Eager scheduling policy for [_DeltaWhat]: microtask-schedules switching on the next tick.
abstract base class _EagerDeltaWhat<T> extends _DeltaWhat<T> implements _EagerSchedulable {
  _EagerDeltaWhat();

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    if (_needsSwitch || _deltaTerminal._isSourceDirty) {
      _needsSwitch = false;
      _performSwitchGuarded(false);
      _deltaTerminal._pullVersion();
    }
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _Scheduler.instance._cancelEager(this);
    super._deactivate();
  }

  @override
  void _onDeltaDirty() {
    _needsSwitch = true;
    _invalidate();
    if (_lifecycle.isActive) {
      _Scheduler.instance._scheduleEager(this);
    }
  }

  @override
  void _performScheduledEager() {
    if (!_lifecycle.isActive || !_needsSwitch) return;
    _needsSwitch = false;
    _performSwitchGuarded(true);
  }
}
