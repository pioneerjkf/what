// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Concrete Implementation Classes
// =============================================================================

base class _WhatControllerImpl<T> with _WhatStateMixin<T> implements WhatController<T> {
  _WhatControllerImpl(
    T data, {
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) : _target = _Entry<T>.create(
          data,
          distinct: distinct,
          equals: equals,
          onActivated: onActivated,
          onDeactivated: onDeactivated,
          graceful: graceful,
        );

  _WhatControllerImpl.late({
    Object? reason,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) : _target = _Entry<T>.late(
          reason: reason,
          distinct: distinct,
          equals: equals,
          onActivated: onActivated,
          onDeactivated: onDeactivated,
          graceful: graceful,
        );

  _WhatControllerImpl.error(
    Object error, {
    StackTrace? stackTrace,
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) : _target = _Entry<T>.error(
          error,
          stackTrace: stackTrace,
          distinct: distinct,
          equals: equals,
          onActivated: onActivated,
          onDeactivated: onDeactivated,
          graceful: graceful,
        );

  _WhatControllerImpl._(this._target);

  final _Entry<T> _target;

  @override
  @pragma('vm:prefer-inline')
  What<T> get what => _target;

  @override
  @pragma('vm:prefer-inline')
  set data(T data) => _target.set(data);

  @override
  @pragma('vm:prefer-inline')
  void set(T data) => _target.set(data);

  @override
  @pragma('vm:prefer-inline')
  void setGuarded(T Function() test) => _target.setGuarded(test);

  @override
  @pragma('vm:prefer-inline')
  void setError(Object error, [StackTrace? stackTrace]) => _target.setError(error, stackTrace);

  @override
  @pragma('vm:prefer-inline')
  void empty([Object? reason]) => _target.empty(reason);

  @override
  @pragma('vm:prefer-inline')
  bool get isActive => _target.isActive;

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _read() => _target._read();
}

final class _RawWhatControllerImpl<T> extends _WhatControllerImpl<T> implements RawWhatController<T> {
  _RawWhatControllerImpl(
    T data, {
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) : super._(_Entry<T>.create(
          data,
          distinct: false,
          onActivated: onActivated,
          onDeactivated: onDeactivated,
          graceful: graceful,
        ));

  _RawWhatControllerImpl.late({
    Object? reason,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) : super._(_Entry<T>.late(
          reason: reason,
          distinct: false,
          onActivated: onActivated,
          onDeactivated: onDeactivated,
          graceful: graceful,
        ));

  _RawWhatControllerImpl.error(
    Object error, {
    StackTrace? stackTrace,
    void Function()? onActivated,
    void Function()? onDeactivated,
    Graceful? graceful,
  }) : super._(_Entry<T>.error(
          error,
          stackTrace: stackTrace,
          distinct: false,
          onActivated: onActivated,
          onDeactivated: onDeactivated,
          graceful: graceful,
        ));

  @override
  @pragma('vm:prefer-inline')
  void markDirty() => _target._markDirty();
}
