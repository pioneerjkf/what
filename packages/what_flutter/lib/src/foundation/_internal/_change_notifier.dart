// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../framework.dart';

// =============================================================================
// Internal ValueListenable <-> What Pipes & Listenables
// =============================================================================

final class _ValueListenableWhatPipe<T> {
  /// Creates a demand-driven bridge pipe wrapping [listenable].
  _ValueListenableWhatPipe(
    ValueListenable<T> listenable, {
    bool distinct = true,
    bool Function(T previous, T next)? equals,
    Graceful? graceful,
  }) : _listenable = listenable {
    _controller = WhatController<T>(
      listenable.value,
      distinct: distinct,
      equals: equals,
      graceful: graceful,
      onActivated: _onActivate,
      onDeactivated: _onDeactivate,
    );
  }

  final ValueListenable<T> _listenable;
  late final WhatController<T> _controller;

  /// Activates the bridge, synchronizing the current value and registering the listener.
  void _onActivate() {
    _controller.setGuarded(() => _listenable.value);
    _listenable.addListener(_listen);
  }

  /// Deactivates the bridge, removing the listener from the source listenable.
  void _onDeactivate() {
    _listenable.removeListener(_listen);
  }

  /// Handles incoming notifications from the source listenable.
  void _listen() {
    _controller.setGuarded(() => _listenable.value);
  }

  /// The read-only [What<T>] consumer view of this bridge.
  What<T> get what => _controller.what;
}

/// An internal demand-driven selector pipe extracting a derived reactive slice [R] from a [Listenable] [N].
///
/// Evaluates `select` upon construction with fault containment: exceptions thrown during initial
/// slice evaluation initialize the underlying [WhatController] into an Error state rather than aborting
/// element inflation. When active, subsequent notifications re-evaluate `select` via `setGuarded`.
final class _ListenableSelectorWhatPipe<N extends Listenable, R> {
  /// Creates a demand-driven selector pipe extracting [R] from [listenable] via [select].
  _ListenableSelectorWhatPipe(
    N listenable, {
    required R Function(N target) select,
    bool distinct = true,
    bool Function(R previous, R next)? equals,
    Graceful? graceful,
  })  : _listenable = listenable,
        _select = select {
    try {
      _controller = WhatController<R>(
        select(listenable),
        distinct: distinct,
        equals: equals,
        graceful: graceful,
        onActivated: _onActivate,
        onDeactivated: _onDeactivate,
      );
    } catch (error, stackTrace) {
      _controller = WhatController<R>.error(
        error,
        stackTrace: stackTrace,
        distinct: distinct,
        equals: equals,
        graceful: graceful,
        onActivated: _onActivate,
        onDeactivated: _onDeactivate,
      );
    }
  }

  final N _listenable;
  final R Function(N target) _select;
  late final WhatController<R> _controller;

  /// Activates the selector pipe, pulling the latest value and registering the listener.
  void _onActivate() {
    _controller.setGuarded(() => _select(_listenable));
    _listenable.addListener(_listen);
  }

  /// Deactivates the selector pipe, removing the listener from the source listenable.
  void _onDeactivate() {
    _listenable.removeListener(_listen);
  }

  /// Handles incoming notifications by re-evaluating `select` within `setGuarded`.
  void _listen() {
    _controller.setGuarded(() => _select(_listenable));
  }

  /// The read-only [What<R>] consumer view of this selector pipe.
  What<R> get what => _controller.what;
}

/// An internal [ValueListenable] adapter exposing a reactive [What] node to Flutter consumers.
///
/// Manages a demand-driven [RawWhatTerminal] that is moored to the reactive DAG if and only if
/// one or more Flutter listeners are registered. Dispatches listener callbacks with individual
/// exception containment via [FlutterError.reportError].
final class _WhatValueListenable<T> implements ValueListenable<T> {
  /// Creates a [ValueListenable] adapter backed by [_what].
  _WhatValueListenable(this._what, {this.sync = true});

  final What<T> _what;

  /// Whether mutations dispatch notifications synchronously (`true`) or coalesce into microtasks (`false`).
  final bool sync;

  final List<VoidCallback> _listeners = [];
  RawWhatTerminal<T>? _terminal;

  @override
  T get value => _what.peek;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    if (_listeners.length == 1) {
      if (_terminal case final terminal?) {
        terminal.activate();
      } else {
        final effectiveSource = sync ? _what : _what.coalesced();
        _terminal = RawWhatTerminal<T>(
          effectiveSource,
          onInvalidated: _notify,
        )..activate();
      }
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _terminal?.deactivate();
    }
  }

  /// Notifies all registered listeners safely, catching and reporting any callback errors.
  void _notify() {
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'what_flutter',
            context: ErrorDescription(
              'while notifying listener in _WhatValueListenable',
            ),
          ),
        );
      }
    }
  }
}
