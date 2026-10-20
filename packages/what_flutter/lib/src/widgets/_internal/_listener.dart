// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../framework.dart';

// =============================================================================
// WhatListener Internal Element & Rate-Limiting Subclasses
// =============================================================================

/// Specialized internal Flutter element for [WhatListener] hosting a unary [EffectRunner].
base class _WhatListenerElement<T> extends ComponentElement
    with _ReactiveTerminalElementMixin<EffectRunner> {
  _WhatListenerElement(WhatListener<T> super.widget);

  late EffectRunner _runner;

  @override
  WhatListener<T> get widget => super.widget as WhatListener<T>;

  @override
  EffectRunner get terminal => _runner;

  /// Constructs and returns the appropriate [EffectRunner] instance.
  EffectRunner _createRunner() {
    final Effect effect = Effect.unary(
      widget.target,
      _handleAction,
      guard: _handleGuard,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }

  /// Evaluates whether the internal [EffectRunner] must be deactivated and rebound to [newWidget].
  ///
  /// Subclasses override this method to detect configuration changes (e.g. duration, leading, trailing).
  bool _needsRebind(
    covariant WhatListener<T> oldWidget,
    covariant WhatListener<T> newWidget,
  ) {
    // If target node or take quota explicitly changed, instantiate a fresh EffectRunner.
    return !identical(oldWidget.target, newWidget.target) ||
        oldWidget.take != newWidget.take;
  }

  void _handleAction() {
    if (!mounted) return;
    widget.action(this, untracked(widget.target));
  }

  bool _handleGuard() {
    final guard = widget.guard;
    return guard == null || guard(untracked(widget.target));
  }

  void _handleError(Object error, StackTrace stackTrace) {
    final onError = widget.onUncaughtError;
    if (onError != null) {
      onError(this, error, stackTrace);
      return;
    }
    _handleTerminalUncaughtError(error, stackTrace);
  }

  @mustCallSuper
  @override
  void mount(Element? parent, Object? newSlot) {
    _runner = _createRunner();
    super.mount(parent, newSlot);
  }

  @mustCallSuper
  @override
  void update(covariant WhatListener<T> newWidget) {
    final oldWidget = widget;
    super.update(newWidget);
    if (_needsRebind(oldWidget, newWidget)) {
      _runner.deactivate();
      _runner = _createRunner();
      _runner.activate();
    }
  }

  @override
  Widget build() => widget.child ?? const SizedBox.shrink();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('isActive', _runner.isActive));
    properties.add(DiagnosticsProperty<bool>('hasChild', widget.child != null));
  }
}

/// A private dedicated debounced reactive side-effect listener widget.
final class _WhatDebounceListener<T> extends WhatListener<T> {
  /// Creates a [_WhatDebounceListener] delaying [action] until [target] settles for [duration].
  const _WhatDebounceListener(
    super.target,
    super.action, {
    super.key,
    required this.duration,
    this.leading = false,
    this.trailing = true,
    super.guard,
    super.take,
    super.onUncaughtError,
    super.child,
  });

  /// The silence window duration required before executing [action].
  final Duration duration;

  /// Whether leading edge execution is enabled.
  final bool leading;

  /// Whether trailing edge execution is enabled.
  final bool trailing;

  @override
  ComponentElement createElement() => _WhatDebounceListenerElement<T>(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration>('duration', duration));
    properties.add(FlagProperty('leading', value: leading, ifTrue: 'leading'));
    properties
        .add(FlagProperty('trailing', value: trailing, ifTrue: 'trailing'));
  }
}

/// Specialized internal Flutter element for [_WhatDebounceListener].
final class _WhatDebounceListenerElement<T> extends _WhatListenerElement<T> {
  _WhatDebounceListenerElement(_WhatDebounceListener<T> super.widget);

  @override
  _WhatDebounceListener<T> get widget =>
      super.widget as _WhatDebounceListener<T>;

  @override
  EffectRunner _createRunner() {
    final Effect effect = DebounceEffect.unary(
      widget.target,
      widget.duration,
      _handleAction,
      guard: _handleGuard,
      leading: widget.leading,
      trailing: widget.trailing,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }

  @override
  bool _needsRebind(
    covariant _WhatDebounceListener<T> oldWidget,
    covariant _WhatDebounceListener<T> newWidget,
  ) {
    // 1. If target or take changed, rebind fresh runner; if exhausted, do not resurrect.
    if (super._needsRebind(oldWidget, newWidget)) return true;
    if (oldWidget.take != null && !_runner.isActive) return false;

    // 2. Check debounce silence window and edge mode updates.
    return oldWidget.duration != newWidget.duration ||
        oldWidget.leading != newWidget.leading ||
        oldWidget.trailing != newWidget.trailing;
  }
}

/// A private dedicated throttled reactive side-effect listener widget.
final class _WhatThrottleListener<T> extends WhatListener<T> {
  /// Creates a [_WhatThrottleListener] limiting [action] execution to at most once per [duration].
  const _WhatThrottleListener(
    super.target,
    super.action, {
    super.key,
    required this.duration,
    this.leading = true,
    this.trailing = true,
    super.guard,
    super.take,
    super.onUncaughtError,
    super.child,
  });

  /// The minimum time interval between consecutive executions.
  final Duration duration;

  /// Whether leading edge execution is enabled.
  final bool leading;

  /// Whether trailing edge execution is enabled.
  final bool trailing;

  @override
  ComponentElement createElement() => _WhatThrottleListenerElement<T>(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration>('duration', duration));
    properties.add(FlagProperty('leading', value: leading, ifTrue: 'leading'));
    properties
        .add(FlagProperty('trailing', value: trailing, ifTrue: 'trailing'));
  }
}

/// Specialized internal Flutter element for [_WhatThrottleListener].
final class _WhatThrottleListenerElement<T> extends _WhatListenerElement<T> {
  _WhatThrottleListenerElement(_WhatThrottleListener<T> super.widget);

  @override
  _WhatThrottleListener<T> get widget =>
      super.widget as _WhatThrottleListener<T>;

  @override
  EffectRunner _createRunner() {
    final Effect effect = ThrottleEffect.unary(
      widget.target,
      widget.duration,
      _handleAction,
      guard: _handleGuard,
      leading: widget.leading,
      trailing: widget.trailing,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }

  @override
  bool _needsRebind(
    covariant _WhatThrottleListener<T> oldWidget,
    covariant _WhatThrottleListener<T> newWidget,
  ) {
    // 1. If target or take changed, rebind fresh runner; if exhausted, do not resurrect.
    if (super._needsRebind(oldWidget, newWidget)) return true;
    if (oldWidget.take != null && !_runner.isActive) return false;

    // 2. Check throttle interval window and edge mode updates.
    return oldWidget.duration != newWidget.duration ||
        oldWidget.leading != newWidget.leading ||
        oldWidget.trailing != newWidget.trailing;
  }
}
