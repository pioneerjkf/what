// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// EffectHandle Internal Implementation
// =============================================================================

/// Internal implementation of [EffectHandle].
final class _EffectHandleImpl implements EffectHandle {
  _EffectHandleImpl(this._handleUncaughtError);

  final void Function(Object error, StackTrace stackTrace) _handleUncaughtError;
  bool _isCancelled = false;
  void Function()? _cleanup;

  @override
  @pragma('vm:prefer-inline')
  bool get isActive => !_isCancelled;

  @override
  @pragma('vm:prefer-inline')
  bool get isCancelled => _isCancelled;

  @override
  void onCleanup(void Function() cleanup) {
    if (_isCancelled) {
      try {
        cleanup();
      } catch (error, stackTrace) {
        _handleUncaughtError(error, stackTrace);
      }
      return;
    }
    // Zero-Alloc Fast-Path & Closure-Chained Multi-Registration:
    // 90%+ of effects register exactly 1 cleanup (e.g. CancelToken or Timer).
    // Storing a direct callback in `_cleanup` avoids allocating a heap `List` per effect turn.
    // When multiple cleanups are registered (e.g. across independent helper functions),
    // we recursively chain them via a synthesized closure with `try-finally` to guarantee that
    // subsequent cleanups execute even if an earlier teardown throws.
    final previous = _cleanup;
    if (previous == null) {
      _cleanup = cleanup;
    } else {
      _cleanup = () {
        try {
          previous();
        } finally {
          cleanup();
        }
      };
    }
  }

  @pragma('vm:prefer-inline')
  void _dispose() {
    if (_isCancelled) return;
    _isCancelled = true;
    final cleanup = _cleanup;
    _cleanup = null;
    if (cleanup != null) {
      try {
        cleanup();
      } catch (error, stackTrace) {
        _handleUncaughtError(error, stackTrace);
      }
    }
  }
}

// =============================================================================
// Foundational Base Terminals
// =============================================================================

/// Abstract base terminal for manifest (explicit dependency) effects.
abstract base class _ManifestEffectTerminal extends _Terminal with _ScheduledTerminalMixin {
  _ManifestEffectTerminal(
    this._action, {
    bool Function()? guard,
    int? take,
    super.onUncaughtError,
  })  : _takeLimit = take,
        _remaining = take ?? 0,
        _guard = guard {
    if (take != null) {
      RangeError.checkNotNegative(take, 'take');
    }
  }

  final void Function() _action;
  final int? _takeLimit;
  final bool Function()? _guard;
  int _remaining;

  @override
  void activate() {
    // Reactivation Guard: Once the ticket count is exhausted,
    // subsequent activations (e.g. from parent scope revival) are strictly rejected.
    if (_takeLimit != null && _remaining <= 0) return;
    super.activate();
  }

  @override
  @pragma('vm:prefer-inline')
  void _performScheduled() {
    if (_lifecycle.isActive) {
      if (this case final _DirtySyncable e) {
        if (!e._resolveDirty()) return; // Drop/Abort if upstream didn't actually mutate
        e._pullVersion();
      }

      if (_takeLimit != null && _remaining <= 0) return;
      var executed = false;
      try {
        if (_guard?.call() == false) return;
        executed = true;
        _action();
      } catch (error, stackTrace) {
        _handleUncaughtError(error, stackTrace);
      } finally {
        if (executed && _takeLimit != null && --_remaining <= 0) {
          deactivate(); // Early Teardown
        }
      }
    }
  }
}

// =============================================================================
// Manifest Effect Upstream Priming Mixins
// =============================================================================

/// Unary edge mixin for manifest effect terminals that primes upstream reactive nodes upon activation.
base mixin _UnaryEffectPrimeMixin on _Terminal, _UnaryEdgeMixin<What> {
  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _source._resolve();
    _pullVersion();
  }
}

/// N-ary edge mixin for manifest effect terminals that primes upstream reactive nodes upon activation.
base mixin _NaryEffectPrimeMixin on _Terminal, _NaryEdgeMixin<What> {
  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    for (var curr = _sourceHead; curr != null; curr = curr._nextSource) {
      curr._source._resolve();
    }
    _pullVersion();
  }
}

/// Concrete unary manifest terminal.
base class _UnaryManifestEffectTerminal extends _ManifestEffectTerminal
    with _UnaryEdgeMixin<What>, _UnaryEffectPrimeMixin {
  _UnaryManifestEffectTerminal(
    this._source,
    super.action, {
    super.guard,
    super.take,
    super.onUncaughtError,
  }) {
    _pulledVersion = _source._version;
  }

  @override
  final What _source;
}

/// Concrete n-ary manifest terminal.
base class _NaryManifestEffectTerminal extends _ManifestEffectTerminal
    with _NaryEdgeMixin<What>, _NaryEffectPrimeMixin {
  _NaryManifestEffectTerminal(
    Iterable<What> targets,
    super.action, {
    super.guard,
    super.take,
    super.onUncaughtError,
  }) {
    _addSourceEdges(
      targets is List<What> ? targets : targets.toList(growable: false),
    );
  }
}

/// Abstract base terminal for manifest handled effects providing [EffectHandle].
abstract base class _HandledManifestEffectTerminal extends _Terminal with _ScheduledTerminalMixin {
  _HandledManifestEffectTerminal(
    this._action, {
    bool Function()? guard,
    int? take,
    super.onUncaughtError,
  })  : _takeLimit = take,
        _remaining = take ?? 0,
        _guard = guard {
    if (take != null) {
      RangeError.checkNotNegative(take, 'take');
    }
  }

  final void Function(EffectHandle handle) _action;
  final int? _takeLimit;
  final bool Function()? _guard;
  int _remaining;
  _EffectHandleImpl? _currentHandle;

  @override
  void activate() {
    if (_takeLimit != null && _remaining <= 0) return;
    super.activate();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _currentHandle?._dispose();
    _currentHandle = null;
    super._deactivate();
  }

  @override
  @pragma('vm:prefer-inline')
  void _performScheduled() {
    if (_lifecycle.isActive) {
      if (this case final _DirtySyncable e) {
        if (!e._resolveDirty()) return; // Drop/Abort if upstream didn't actually mutate
        e._pullVersion();
      }

      if (_takeLimit != null && _remaining <= 0) return;
      if (_guard?.call() == false) return;

      _currentHandle?._dispose();
      final handle = _EffectHandleImpl(_handleUncaughtError);
      _currentHandle = handle;

      var executed = false;
      try {
        executed = true;
        _action(handle);
      } catch (error, stackTrace) {
        _handleUncaughtError(error, stackTrace);
      } finally {
        if (executed && _takeLimit != null && --_remaining <= 0) {
          deactivate(); // Early Teardown triggers _deactivate -> disposes _currentHandle
        }
      }
    }
  }
}

/// Concrete unary manifest handled terminal.
base class _HandledUnaryManifestEffectTerminal extends _HandledManifestEffectTerminal
    with _UnaryEdgeMixin<What>, _UnaryEffectPrimeMixin {
  _HandledUnaryManifestEffectTerminal(
    this._source,
    super.action, {
    super.guard,
    super.take,
    super.onUncaughtError,
  }) {
    _pulledVersion = _source._version;
  }

  @override
  final What _source;
}

/// Concrete n-ary manifest handled terminal.
base class _HandledNaryManifestEffectTerminal extends _HandledManifestEffectTerminal
    with _NaryEdgeMixin<What>, _NaryEffectPrimeMixin {
  _HandledNaryManifestEffectTerminal(
    Iterable<What> targets,
    super.action, {
    super.guard,
    super.take,
    super.onUncaughtError,
  }) {
    _addSourceEdges(
      targets is List<What> ? targets : targets.toList(growable: false),
    );
  }
}

/// Internal terminal for composite [EffectGroup] orchestration.
final class _EffectGroupTerminal extends _Terminal with _NaryEdgeMixin<_Node> {
  _EffectGroupTerminal(Iterable<Effect> effects) {
    for (final effect in effects) {
      _addSourceEdge(effect);
    }
  }

  /// Upstream sources are strictly [Effect] nodes which never emit dirty pulses.
  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {}
}

// =============================================================================
// WhatVia Dynamic Terminals
// =============================================================================

/// Internal terminal executing dynamic [WhatVia] tracking effects with `_Scheduler` batching.
base class _ViaEffectTerminal extends _Terminal
    with _NaryEdgeMixin<_Node>, _WhatViaEpochMixin, _ScheduledTerminalMixin {
  _ViaEffectTerminal(
    this._action, {
    bool Function(WhatVia via)? guard,
    super.onUncaughtError,
  }) : _guard = guard;

  final void Function(WhatVia via) _action;
  final bool Function(WhatVia via)? _guard;
  bool _needsInitialEvaluation = true;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _needsInitialEvaluation = true;
    _Scheduler.instance._scheduleTerminal(this);
  }

  @pragma('vm:prefer-inline')
  void _evaluate() {
    final currentEpoch = _beginEpoch();
    var succeeded = true;
    try {
      if (_guard case final guard?) {
        if (!guard(_via)) return;
      }
      _action(_via);
    } on _ViaShortCircuit {
      succeeded = true;
      return;
    } catch (error, stackTrace) {
      succeeded = false;
      _handleUncaughtError(error, stackTrace);
    } finally {
      _endEpoch(currentEpoch, succeeded: succeeded, commitVersions: true);
    }
  }

  @override
  @pragma('vm:prefer-inline')
  void _performScheduled() {
    if (isActive) {
      if (_needsInitialEvaluation) {
        _needsInitialEvaluation = false;
        _evaluate();
        return;
      }
      if (!_resolveDirty()) return;
      _evaluate();
    }
  }
}

/// Internal terminal executing dynamic [WhatVia] tracking handled effects providing [EffectHandle].
base class _HandledViaEffectTerminal extends _Terminal
    with _NaryEdgeMixin<_Node>, _WhatViaEpochMixin, _ScheduledTerminalMixin {
  _HandledViaEffectTerminal(
    this._action, {
    bool Function(WhatVia via)? guard,
    super.onUncaughtError,
  }) : _guard = guard;

  final void Function(WhatVia via, EffectHandle handle) _action;
  final bool Function(WhatVia via)? _guard;
  bool _needsInitialEvaluation = true;
  _EffectHandleImpl? _currentHandle;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _needsInitialEvaluation = true;
    _Scheduler.instance._scheduleTerminal(this);
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _currentHandle?._dispose();
    _currentHandle = null;
    super._deactivate();
  }

  @pragma('vm:prefer-inline')
  void _evaluate() {
    final currentEpoch = _beginEpoch();
    var succeeded = true;
    try {
      if (_guard case final guard?) {
        if (!guard(_via)) return;
      }
      _currentHandle?._dispose();
      final handle = _EffectHandleImpl(_handleUncaughtError);
      _currentHandle = handle;

      _action(_via, handle);
    } on _ViaShortCircuit {
      succeeded = true;
      return;
    } catch (error, stackTrace) {
      succeeded = false;
      _handleUncaughtError(error, stackTrace);
    } finally {
      _endEpoch(currentEpoch, succeeded: succeeded, commitVersions: true);
    }
  }

  @override
  @pragma('vm:prefer-inline')
  void _performScheduled() {
    if (isActive) {
      if (_needsInitialEvaluation) {
        _needsInitialEvaluation = false;
        _evaluate();
        return;
      }
      if (!_resolveDirty()) return;
      _evaluate();
    }
  }
}

// =============================================================================
// Temporal (Debounce & Throttle) Terminals
// =============================================================================

/// Foundational base terminal for debounce logic used by [DebounceEffect].
abstract base class _DebounceEffectTerminal extends _ManifestEffectTerminal {
  _DebounceEffectTerminal(
    super.action, {
    required this.duration,
    super.guard,
    this.leading = false,
    this.trailing = true,
    super.take,
    super.onUncaughtError,
  }) : assert(leading || trailing, 'At least one of leading or trailing must be true.');

  final Duration duration;
  final bool leading;
  final bool trailing;

  Timer? _debounceTimer;
  bool _isLeadingCooldown = false;
  bool _hasTrailingPending = false;

  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    if (!_lifecycle.isActive) return;
    if (_takeLimit != null && _remaining <= 0) return;

    if (leading && !_isLeadingCooldown) {
      _Scheduler.instance._scheduleTerminal(this);
      _isLeadingCooldown = true;
    } else {
      if (trailing) {
        _hasTrailingPending = true;
      }
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, _onDebounceTimerExpired);
  }

  void _onDebounceTimerExpired() {
    _debounceTimer = null;
    _isLeadingCooldown = false;
    if (!_lifecycle.isActive) return;
    if (_takeLimit != null && _remaining <= 0) return;

    if (_hasTrailingPending && trailing) {
      _hasTrailingPending = false;
      _Scheduler.instance._scheduleTerminal(this);
    }
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isLeadingCooldown = false;
    _hasTrailingPending = false;
    super._deactivate();
  }
}

/// Concrete unary debounce terminal.
base class _UnaryDebounceEffectTerminal extends _DebounceEffectTerminal
    with _UnaryEdgeMixin<What>, _UnaryEffectPrimeMixin {
  _UnaryDebounceEffectTerminal(
    this._source,
    Duration duration,
    void Function() action, {
    super.guard,
    super.leading,
    super.trailing,
    super.take,
    super.onUncaughtError,
  }) : super(
          action,
          duration: duration,
        ) {
    _pulledVersion = _source._version;
  }

  @override
  final What _source;
}

/// Concrete n-ary debounce terminal.
base class _NaryDebounceEffectTerminal extends _DebounceEffectTerminal
    with _NaryEdgeMixin<What>, _NaryEffectPrimeMixin {
  _NaryDebounceEffectTerminal(
    Iterable<What> targets,
    Duration duration,
    void Function() action, {
    super.guard,
    super.leading,
    super.trailing,
    super.take,
    super.onUncaughtError,
  }) : super(
          action,
          duration: duration,
        ) {
    _addSourceEdges(
      targets is List<What> ? targets : targets.toList(growable: false),
    );
  }
}

/// Foundational base terminal for throttle logic used by [ThrottleEffect].
abstract base class _ThrottleEffectTerminal extends _ManifestEffectTerminal {
  _ThrottleEffectTerminal(
    super.action, {
    required this.duration,
    super.guard,
    this.leading = true,
    this.trailing = true,
    super.take,
    super.onUncaughtError,
  }) : assert(leading || trailing, 'At least one of leading or trailing must be true.');

  final Duration duration;
  final bool leading;
  final bool trailing;

  Timer? _throttleTimer;
  bool _hasTrailingPending = false;

  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    if (!_lifecycle.isActive) return;
    if (_takeLimit != null && _remaining <= 0) return;

    if (_throttleTimer == null) {
      if (leading) {
        _Scheduler.instance._scheduleTerminal(this);
      } else {
        _hasTrailingPending = true;
      }
      _throttleTimer = Timer(duration, _onThrottleTimerExpired);
    } else {
      if (trailing) {
        _hasTrailingPending = true;
      }
    }
  }

  void _onThrottleTimerExpired() {
    _throttleTimer = null;
    if (!_lifecycle.isActive) return;
    if (_takeLimit != null && _remaining <= 0) return;

    if (_hasTrailingPending && trailing) {
      _hasTrailingPending = false;
      _Scheduler.instance._scheduleTerminal(this);
      _throttleTimer = Timer(duration, _onThrottleTimerExpired);
    }
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _hasTrailingPending = false;
    super._deactivate();
  }
}

/// Concrete unary throttle terminal.
base class _UnaryThrottleEffectTerminal extends _ThrottleEffectTerminal
    with _UnaryEdgeMixin<What>, _UnaryEffectPrimeMixin {
  _UnaryThrottleEffectTerminal(
    this._source,
    Duration duration,
    void Function() action, {
    super.guard,
    super.leading,
    super.trailing,
    super.take,
    super.onUncaughtError,
  }) : super(
          action,
          duration: duration,
        ) {
    _pulledVersion = _source._version;
  }

  @override
  final What _source;
}

/// Concrete n-ary throttle terminal.
base class _NaryThrottleEffectTerminal extends _ThrottleEffectTerminal
    with _NaryEdgeMixin<What>, _NaryEffectPrimeMixin {
  _NaryThrottleEffectTerminal(
    Iterable<What> targets,
    Duration duration,
    void Function() action, {
    super.guard,
    super.leading,
    super.trailing,
    super.take,
    super.onUncaughtError,
  }) : super(
          action,
          duration: duration,
        ) {
    _addSourceEdges(
      targets is List<What> ? targets : targets.toList(growable: false),
    );
  }
}
