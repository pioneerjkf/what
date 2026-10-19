// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../framework.dart';

// =============================================================================
// Reactive Ticker Driver (100% Internal)
// =============================================================================

/// An internal driver that manages a [Ticker] and updates a reactive [What] node.
///
/// Traps exceptions during ticks to halt the ticker and transition to an error state,
/// preventing infinite frame error loops.
final class _TickerDriver<T> {
  _TickerDriver(
    TickerProvider vsync, {
    required this.onTick,
    required bool distinct,
    required bool Function(T previous, T next)? equals,
    T? initialValue,
  }) : _vsync = vsync {
    bool hasInitError = false;
    if (initialValue != null) {
      _controller = WhatController<T>(
        initialValue,
        distinct: distinct,
        equals: equals,
      );
    } else {
      try {
        _controller = WhatController<T>(
          onTick(Duration.zero),
          distinct: distinct,
          equals: equals,
        );
      } catch (error, stackTrace) {
        hasInitError = true;
        _controller = WhatController<T>.error(
          error,
          stackTrace: stackTrace,
          distinct: distinct,
          equals: equals,
        );
      }
    }
    _ticker = vsync.createTicker((elapsed) {
      try {
        _controller.set(onTick(elapsed));
      } catch (error, stackTrace) {
        _ticker.stop();
        _controller.setError(error, stackTrace);
      }
    });
    if (!hasInitError) {
      _ticker.start();
    }
  }

  TickerProvider? _vsync;

  /// The active [TickerProvider], or `null` when dormant.
  TickerProvider? get vsync => _vsync;

  final T Function(Duration elapsed) onTick;

  late final WhatController<T> _controller;

  late Ticker _ticker;

  /// The underlying reactive [What] outputting the latest tick value.
  What<T> get what => _controller.what;

  /// Recreates the underlying ticker with [newVsync] if different from current [vsync].
  void resync(TickerProvider newVsync) {
    if (_vsync == newVsync) return;
    _ticker.stop();
    _ticker.dispose();
    _vsync = newVsync;
    _ticker = newVsync.createTicker((elapsed) {
      try {
        _controller.set(onTick(elapsed));
      } catch (error, stackTrace) {
        _ticker.stop();
        _controller.setError(error, stackTrace);
      }
    })
      ..start();
  }

  /// Hibernates the ticker into a dormant state without clearing controller state.
  void hibernate() {
    _ticker.stop();
    _ticker.dispose();
    _vsync = null;
  }

  /// Hibernates the ticker if the bound provider matches [vsync].
  bool tryHibernate(TickerProvider vsync) {
    if (_vsync == vsync) {
      hibernate();
      return true;
    }
    return false;
  }

  /// Disposes of resources if the bound provider matches [vsync].
  bool tryDispose(TickerProvider vsync) {
    if (_vsync == vsync) {
      dispose();
      return true;
    }
    return false;
  }

  /// Releases all resources, stopping the ticker and emptying the controller.
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    _vsync = null;
    _controller.empty();
  }
}

// =============================================================================
// Element Ticker Provider Mixin (100% Internal)
// =============================================================================

/// A [Ticker] that automatically deregisters from its host element upon [dispose].
final class _VsyncElementTicker extends Ticker {
  _VsyncElementTicker(super.onTick, this._element, {super.debugLabel});

  final _TickerProviderElementMixin _element;

  @override
  void dispose() {
    _element._removeTicker(this);
    super.dispose();
  }
}

/// A mixin providing [TickerProvider] capabilities directly to an [Element].
///
/// Synchronizes tickers with [TickerMode] and safely disposes active tickers on [unmount].
mixin _TickerProviderElementMixin on Element implements TickerProvider {
  Set<_VsyncElementTicker>? _tickers;

  void _removeTicker(_VsyncElementTicker ticker) {
    _tickers?.remove(ticker);
  }

  /// Creates a [Ticker] driven by this element's VSYNC provider.
  @override
  Ticker createTicker(TickerCallback onTick) {
    final bool muted = !TickerMode.valuesOf(this).enabled;
    final ticker = _VsyncElementTicker(
      onTick,
      this,
      debugLabel: kDebugMode ? 'created by $this' : null,
    )..muted = muted;
    (_tickers ??= <_VsyncElementTicker>{}).add(ticker);
    return ticker;
  }

  @mustCallSuper
  @override
  void didChangeDependencies() {
    final bool muted = !TickerMode.valuesOf(this).enabled;
    if (_tickers != null) {
      for (final ticker in _tickers!) {
        ticker.muted = muted;
      }
    }
    super.didChangeDependencies();
  }

  @mustCallSuper
  @override
  void activate() {
    super.activate();
    final bool muted = !TickerMode.valuesOf(this).enabled;
    if (_tickers != null) {
      for (final ticker in _tickers!) {
        ticker.muted = muted;
      }
    }
  }

  @mustCallSuper
  @override
  void deactivate() {
    if (_tickers != null) {
      for (final ticker in _tickers!) {
        ticker.muted = true;
      }
    }
    super.deactivate();
  }

  @mustCallSuper
  @override
  void unmount() {
    if (_tickers != null) {
      final tickersToDispose = List<_VsyncElementTicker>.of(_tickers!);
      for (final ticker in tickersToDispose) {
        ticker.dispose();
      }
      _tickers = null;
    }
    super.unmount();
  }
}
