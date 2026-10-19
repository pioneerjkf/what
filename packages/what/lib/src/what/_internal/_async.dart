// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// [Easter Egg Base] Named after the DeLorean time machine from *Back to the Future*.
/// Provides time-traveling async value injection into the What topology upon arrival.
base class _DeLorean<T> {
  _DeLorean(
    Future<T> future, {
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
  })  : _future = future,
        _onError = onError {
    if (initialFactory != null) {
      try {
        final early = initialFactory();
        _controller = WhatController<T>(early, onActivated: _backToTheFuture);
      } catch (e, s) {
        _controller = WhatController<T>.error(e, stackTrace: s, onActivated: _backToTheFuture);
      }
    } else {
      _controller = WhatController<T>.late(onActivated: _backToTheFuture);
    }
  }

  final Future<T> _future;
  final T Function(Object error, [StackTrace? stackTrace])? _onError;

  late final WhatController<T> _controller;

  bool _isStarted = false;

  /// Completes when the underlying future settles (either with a value or an error).
  Future<void> get settled => _future.then((_) => null, onError: (_, __) => null);

  void _backToTheFuture() {
    if (_isStarted) return;
    _isStarted = true;

    try {
      _future.then(
        _controller.set,
        onError: (Object error, StackTrace stackTrace) {
          if (_onError != null) {
            try {
              _controller.set(_onError.call(error, stackTrace));
              return;
            } catch (e, s) {
              _controller.setError(e, s);
              return;
            }
          }
          _controller.setError(error, stackTrace);
        },
      );
    } catch (error, stackTrace) {
      if (_onError != null) {
        try {
          _controller.set(_onError.call(error, stackTrace));
          return;
        } catch (e, s) {
          _controller.setError(e, s);
          return;
        }
      }
      _controller.setError(error, stackTrace);
    }
  }

  What<T> get what => _controller.what;
}

/// Formal reactive bridge connecting a native Dart [Future] to the [What] topology.
final class _FutureWhatBridge<T> extends _DeLorean<T> {
  _FutureWhatBridge(
    super.future, {
    super.initialFactory,
    super.onError,
  });
}

/// [Easter Egg Base] Named after Smetana's symphonic poem *Vltava* flowing through Prague.
/// Represents a majestic, continuous asynchronous stream river flowing into the What topology.
base class _PragueVltava<T> {
  _PragueVltava(
    Stream<T> stream, {
    T Function()? initialFactory,
    this.onError,
    this.cancelOnError,
    required bool distinct,
    required bool Function(T previous, T next)? equals,
    Graceful? graceful,
  }) : _stream = stream {
    if (initialFactory != null) {
      try {
        _controller = WhatController<T>(
          initialFactory(),
          distinct: distinct,
          equals: equals,
          graceful: graceful,
          onActivated: _subscribe,
          onDeactivated: _unsubscribe,
        );
      } catch (e, s) {
        _controller = WhatController<T>.error(
          e,
          stackTrace: s,
          distinct: distinct,
          equals: equals,
          graceful: graceful,
          onActivated: _subscribe,
          onDeactivated: _unsubscribe,
        );
      }
    } else {
      _controller = WhatController<T>.late(
        distinct: distinct,
        equals: equals,
        graceful: graceful,
        onActivated: _subscribe,
        onDeactivated: _unsubscribe,
      );
    }
  }

  final Stream<T> _stream;
  final T Function(Object error, [StackTrace? stackTrace])? onError;
  final bool? cancelOnError;

  late final WhatController<T> _controller;

  StreamSubscription<T>? _subscription;

  bool _isDone = false;

  void _subscribe() {
    if (_isDone) return;

    if (_subscription != null) {
      throw StateError('Already subscribed to Stream(-> $_stream).');
    }

    try {
      _subscription = _stream.listen(
        _controller.set,
        onError: (Object error, StackTrace stackTrace) {
          if (onError != null) {
            try {
              _controller.set(onError!.call(error, stackTrace));
            } catch (e, s) {
              _controller.setError(e, s);
            }
          } else {
            _controller.setError(error, stackTrace);
          }
          if (cancelOnError == true) _unsubscribe();
        },
        onDone: () {
          _isDone = true;
          _unsubscribe();
        },
        cancelOnError: cancelOnError,
      );
    } catch (error, stackTrace) {
      if (onError != null) {
        try {
          _controller.set(onError!.call(error, stackTrace));
          return;
        } catch (e, s) {
          _controller.setError(e, s);
          return;
        }
      }
      _controller.setError(error, stackTrace);
    }
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  What<T> get what => _controller.what;
}

/// Formal reactive bridge connecting a native Dart [Stream] to the [What] topology.
final class _StreamWhatBridge<T> extends _PragueVltava<T> {
  _StreamWhatBridge(
    super.stream, {
    super.initialFactory,
    super.onError,
    super.cancelOnError,
    required super.distinct,
    required super.equals,
    super.graceful,
  });

  /// Factory creating the reactive stream bridge.
  static _StreamWhatBridge<T> create<T>(
    Stream<T> stream, {
    T Function()? initialFactory,
    T Function(Object error, [StackTrace? stackTrace])? onError,
    bool? cancelOnError,
    required bool distinct,
    required bool Function(T previous, T next)? equals,
    Graceful? graceful,
  }) {
    return _StreamWhatBridge<T>(
      stream,
      initialFactory: initialFactory,
      onError: onError,
      cancelOnError: cancelOnError,
      distinct: distinct,
      equals: equals,
      graceful: graceful,
    );
  }
}
