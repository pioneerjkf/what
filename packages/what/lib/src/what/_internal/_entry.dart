// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Internal Entry What Node Hierarchy (100% Encapsulated DAG Roots)
// =============================================================================

/// Foundational physical entry node where mutations enter the LPDAG:
/// `[Entry (_Entry)] -> [Relay] -> [Terminal]`
///
/// Completely private to the framework library to prevent rogue downcasting.
abstract base class _Entry<T> extends What<T> with _PushOriginMixin, _WhatStateMixin<T>, _WhatPeekMixin<T> {
  _Entry._(T data) : super._() {
    _state = _ValidWhatState<T>(data);
  }

  _Entry._late([Object? reason]) : super._() {
    _state = _EmptyWhatState<T>(reason);
  }

  _Entry._error(Object error, [StackTrace? stackTrace]) : super._() {
    _state = _ErrorWhatState<T>(error, stackTrace);
  }

  factory _Entry.create(
    T data, {
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) {
    assert(
      distinct || equals == null,
      'Cannot provide a custom [equals] when [distinct] is set to false.',
    );
    assert(
      graceful == null || onActivated != null || onDeactivated != null,
      'Cannot enable [graceful] when neither [onActivated] nor [onDeactivated] is provided.',
    );
    if (distinct) {
      if (onActivated == null && onDeactivated == null) {
        return _DistinctEntry<T>(data, equals: equals);
      }
      return graceful != null
          ? _GracefulLifecycleObservableDistinctEntry<T>(
              data,
              equals: equals,
              onActivated: onActivated,
              onDeactivated: onDeactivated,
              graceful: graceful,
            )
          : _LifecycleObservableDistinctEntry<T>(
              data,
              equals: equals,
              onActivated: onActivated,
              onDeactivated: onDeactivated,
            );
    }
    if (onActivated == null && onDeactivated == null) {
      return _RawEntry<T>(data);
    }
    return graceful != null
        ? _GracefulLifecycleObservableRawEntry<T>(
            data,
            onActivated: onActivated,
            onDeactivated: onDeactivated,
            graceful: graceful,
          )
        : _LifecycleObservableRawEntry<T>(
            data,
            onActivated: onActivated,
            onDeactivated: onDeactivated,
          );
  }

  factory _Entry.late({
    Object? reason,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) {
    assert(
      distinct || equals == null,
      'Cannot provide a custom [equals] when [distinct] is set to false.',
    );
    assert(
      graceful == null || onActivated != null || onDeactivated != null,
      'Cannot enable [graceful] when neither [onActivated] nor [onDeactivated] is provided.',
    );
    if (distinct) {
      if (onActivated == null && onDeactivated == null) {
        return _DistinctEntry<T>.late(reason: reason, equals: equals);
      }
      return graceful != null
          ? _GracefulLifecycleObservableDistinctEntry<T>.late(
              reason: reason,
              equals: equals,
              onActivated: onActivated,
              onDeactivated: onDeactivated,
              graceful: graceful,
            )
          : _LifecycleObservableDistinctEntry<T>.late(
              reason: reason,
              equals: equals,
              onActivated: onActivated,
              onDeactivated: onDeactivated,
            );
    }
    if (onActivated == null && onDeactivated == null) {
      return _RawEntry<T>.late(reason: reason);
    }
    return graceful != null
        ? _GracefulLifecycleObservableRawEntry<T>.late(
            reason: reason,
            onActivated: onActivated,
            onDeactivated: onDeactivated,
            graceful: graceful,
          )
        : _LifecycleObservableRawEntry<T>.late(
            reason: reason,
            onActivated: onActivated,
            onDeactivated: onDeactivated,
          );
  }

  factory _Entry.error(
    Object error, {
    StackTrace? stackTrace,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) {
    assert(
      distinct || equals == null,
      'Cannot provide a custom [equals] when [distinct] is set to false.',
    );
    assert(
      graceful == null || onActivated != null || onDeactivated != null,
      'Cannot enable [graceful] when neither [onActivated] nor [onDeactivated] is provided.',
    );
    if (distinct) {
      if (onActivated == null && onDeactivated == null) {
        return _DistinctEntry<T>.error(
          error,
          stackTrace: stackTrace,
          equals: equals,
        );
      }
      return graceful != null
          ? _GracefulLifecycleObservableDistinctEntry<T>.error(
              error,
              stackTrace: stackTrace,
              equals: equals,
              onActivated: onActivated,
              onDeactivated: onDeactivated,
              graceful: graceful,
            )
          : _LifecycleObservableDistinctEntry<T>.error(
              error,
              stackTrace: stackTrace,
              equals: equals,
              onActivated: onActivated,
              onDeactivated: onDeactivated,
            );
    }
    if (onActivated == null && onDeactivated == null) {
      return _RawEntry<T>.error(error, stackTrace: stackTrace);
    }
    return graceful != null
        ? _GracefulLifecycleObservableRawEntry<T>.error(
            error,
            stackTrace: stackTrace,
            onActivated: onActivated,
            onDeactivated: onDeactivated,
            graceful: graceful,
          )
        : _LifecycleObservableRawEntry<T>.error(
            error,
            stackTrace: stackTrace,
            onActivated: onActivated,
            onDeactivated: onDeactivated,
          );
  }

  @mustCallSuper
  @pragma('vm:prefer-inline')
  void _markDirty() {
    _version++;
    if (!_lifecycle.isActive) return;
    _PushScope.queueOrigin(this);
  }

  late _WhatState<T> _state;

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _read() => _state;

  @mustCallSuper
  @pragma('vm:prefer-inline')
  void _performForwarding(final _WhatState<T> state) {
    _state = state;
    _markDirty();
  }

  /// Injects a new data payload into the pipeline via property assignment.
  @pragma('vm:prefer-inline')
  set data(T data) => set(data);

  @pragma('vm:prefer-inline')
  void set(T data) {
    final current = _state;
    if (current case final _ValidWhatState<T> s) {
      s.update(data);
      _markDirty();
    } else {
      _performForwarding(_ValidWhatState<T>(data));
    }
  }

  @pragma('vm:prefer-inline')
  void setGuarded(T Function() test) {
    try {
      set(test.call());
    } catch (error, stackTrace) {
      setError(error, stackTrace);
    }
  }

  @pragma('vm:prefer-inline')
  void setError(Object error, [StackTrace? stackTrace]) {
    _performForwarding(_ErrorWhatState<T>(error, stackTrace));
  }

  @pragma('vm:prefer-inline')
  void empty([Object? reason]) {
    _performForwarding(_EmptyWhatState<T>(reason));
  }

  @mustCallSuper
  @override
  void _debugInvalidateSelf() {
    super._debugInvalidateSelf();
    _version++;
  }
}

// -----------------------------------------------------------------------------
// Raw (Non-distinct) Entry
// -----------------------------------------------------------------------------

base class _RawEntry<T> extends _Entry<T> {
  _RawEntry(super.data) : super._();

  _RawEntry.late({Object? reason}) : super._late(reason);

  _RawEntry.error(Object error, {StackTrace? stackTrace}) : super._error(error, stackTrace);
}

// -----------------------------------------------------------------------------
// Distinct-Filtering Entry
// -----------------------------------------------------------------------------

base class _DistinctEntry<T> extends _Entry<T> {
  _DistinctEntry(super.data, {bool Function(T previous, T next)? equals})
      : _equals = equals,
        super._();

  _DistinctEntry.late({bool Function(T previous, T next)? equals, Object? reason})
      : _equals = equals,
        super._late(reason);

  _DistinctEntry.error(
    Object error, {
    StackTrace? stackTrace,
    bool Function(T previous, T next)? equals,
  })  : _equals = equals,
        super._error(error, stackTrace);

  final bool Function(T previous, T next)? _equals;

  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  void set(T data) {
    if (_state case final _ValidWhatState<T> s) {
      final T prevData = s.data;
      if (identical(prevData, data)) return;
      try {
        if (null != _equals ? _equals(prevData, data) : prevData == data) return;
      } catch (error, stackTrace) {
        setError(error, stackTrace);
        return;
      }
    }
    super.set(data);
  }

  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  void _performForwarding(final _WhatState<T> state) {
    final prev = _state;
    if (identical(prev, state)) return;

    if (prev.hasData && state.hasData) {
      final prevData = prev.data;
      final nextData = state.data;
      if (identical(prevData, nextData)) return;
      try {
        if (null != _equals ? _equals(prevData, nextData) : prevData == nextData) return;
      } catch (error, stackTrace) {
        super._performForwarding(_ErrorWhatState<T>(error, stackTrace));
        return;
      }
    } else {
      try {
        if (prev.equals(state, _equals)) return;
      } catch (error, stackTrace) {
        super._performForwarding(_ErrorWhatState<T>(error, stackTrace));
        return;
      }
    }

    super._performForwarding(state);
  }
}

// -----------------------------------------------------------------------------
// Lifecycle Observable Entries
// -----------------------------------------------------------------------------

base class _LifecycleObservableRawEntry<T> extends _RawEntry<T> {
  _LifecycleObservableRawEntry(
    super.data, {
    void Function()? onActivated,
    void Function()? onDeactivated,
  })  : _onActivated = onActivated,
        _onDeactivated = onDeactivated;

  _LifecycleObservableRawEntry.late({
    super.reason,
    void Function()? onActivated,
    void Function()? onDeactivated,
  })  : _onActivated = onActivated,
        _onDeactivated = onDeactivated,
        super.late();

  _LifecycleObservableRawEntry.error(
    super.error, {
    super.stackTrace,
    void Function()? onActivated,
    void Function()? onDeactivated,
  })  : _onActivated = onActivated,
        _onDeactivated = onDeactivated,
        super.error();

  final void Function()? _onActivated;
  final void Function()? _onDeactivated;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _onActivated?.call();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    super._deactivate();
    _onDeactivated?.call();
  }
}

base class _LifecycleObservableDistinctEntry<T> extends _DistinctEntry<T> {
  _LifecycleObservableDistinctEntry(
    super.data, {
    super.equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
  })  : _onActivated = onActivated,
        _onDeactivated = onDeactivated;

  _LifecycleObservableDistinctEntry.late({
    super.reason,
    super.equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
  })  : _onActivated = onActivated,
        _onDeactivated = onDeactivated,
        super.late();

  _LifecycleObservableDistinctEntry.error(
    super.error, {
    super.stackTrace,
    super.equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
  })  : _onActivated = onActivated,
        _onDeactivated = onDeactivated,
        super.error();

  final void Function()? _onActivated;
  final void Function()? _onDeactivated;

  @mustCallSuper
  @override
  void _activate() {
    super._activate();
    _onActivated?.call();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    super._deactivate();
    _onDeactivated?.call();
  }
}

final class _GracefulLifecycleObservableRawEntry<T> extends _LifecycleObservableRawEntry<T> with _GracefulNodeMixin {
  _GracefulLifecycleObservableRawEntry(
    super.data, {
    super.onActivated,
    super.onDeactivated,
    required Graceful graceful,
  }) : _graceful = graceful;

  _GracefulLifecycleObservableRawEntry.late({
    super.reason,
    super.onActivated,
    super.onDeactivated,
    required Graceful graceful,
  })  : _graceful = graceful,
        super.late();

  _GracefulLifecycleObservableRawEntry.error(
    super.error, {
    super.stackTrace,
    super.onActivated,
    super.onDeactivated,
    required Graceful graceful,
  })  : _graceful = graceful,
        super.error();

  @override
  final Graceful _graceful;
}

final class _GracefulLifecycleObservableDistinctEntry<T> extends _LifecycleObservableDistinctEntry<T>
    with _GracefulNodeMixin {
  _GracefulLifecycleObservableDistinctEntry(
    super.data, {
    super.equals,
    super.onActivated,
    super.onDeactivated,
    required Graceful graceful,
  }) : _graceful = graceful;

  _GracefulLifecycleObservableDistinctEntry.late({
    super.reason,
    super.equals,
    super.onActivated,
    super.onDeactivated,
    required Graceful graceful,
  })  : _graceful = graceful,
        super.late();

  _GracefulLifecycleObservableDistinctEntry.error(
    super.error, {
    super.stackTrace,
    super.equals,
    super.onActivated,
    super.onDeactivated,
    required Graceful graceful,
  })  : _graceful = graceful,
        super.error();

  @override
  final Graceful _graceful;
}
