// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../framework.dart';

// =============================================================================
// EffectRunner Element Mixin (Rebuild Count: 0 Side-Effect Terminal)
// =============================================================================

/// Internal element mixin managing the lifecycle and error handling of an [EffectRunner]-backed widget.
mixin _EffectRunnerElementMixin on ComponentElement
    implements _ReactiveTerminalElementMixin<EffectRunner> {
  late EffectRunner _runner;

  @override
  EffectRunner get terminal => _runner;

  /// Subclasses construct and return their specific [EffectRunner] instance.
  EffectRunner _createRunner();

  /// Child widget to preserve across side-effect evaluations.
  Widget? get _childWidget;

  /// Custom error callback provided by the widget for uncaught exceptions.
  WhatListenerUncaughtErrorCallback? get _uncaughtErrorCallback;

  void _bindRunner() {
    _runner = _createRunner();
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (_uncaughtErrorCallback != null) {
      _uncaughtErrorCallback!(this, error, stackTrace);
      return;
    }
    _handleTerminalUncaughtError(error, stackTrace);
  }

  @mustCallSuper
  @override
  void mount(Element? parent, Object? newSlot) {
    _bindRunner();
    super.mount(parent, newSlot);
  }

  @mustCallSuper
  @override
  void reassemble() {
    assert(() {
      _runner.debugForceInvalidate();
      return true;
    }());
    super.reassemble();
  }

  @mustCallSuper
  @override
  void update(covariant Widget newWidget) {
    super.update(newWidget);
    _runner.deactivate();
    _bindRunner();
    _runner.activate();
  }

  @override
  Widget build() => _childWidget ?? const SizedBox.shrink();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('isActive', _runner.isActive));
    properties.add(DiagnosticsProperty<bool>('hasChild', _childWidget != null));
  }
}

// =============================================================================
// Internal WhatListener Elements (EffectRunner Backed)
// =============================================================================

/// Specialized internal Flutter element for [WhatListener] hosting a multi-target [EffectRunner].
base class _WhatListenerElement extends ComponentElement
    with
        _ReactiveTerminalElementMixin<EffectRunner>,
        _EffectRunnerElementMixin {
  _WhatListenerElement(WhatListener super.widget);

  @override
  WhatListener get widget => super.widget as WhatListener;

  @override
  Widget? get _childWidget => widget.child;

  @override
  WhatListenerUncaughtErrorCallback? get _uncaughtErrorCallback =>
      widget.onUncaughtError;

  @override
  EffectRunner _createRunner() {
    final Effect effect = Effect(
      widget.targets,
      _handleAction,
      guard: widget.guard,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }

  void _handleAction() {
    if (!mounted) return;
    widget.action(this);
  }
}

/// A private dedicated debounced multi-target reactive side-effect listener widget.
final class _WhatDebounceListener extends WhatListener {
  /// Creates a [_WhatDebounceListener] delaying [action] until [targets] settle for [duration].
  const _WhatDebounceListener(
    super.targets,
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
  ComponentElement createElement() => _WhatDebounceListenerElement(this);

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
final class _WhatDebounceListenerElement extends _WhatListenerElement {
  _WhatDebounceListenerElement(_WhatDebounceListener super.widget);

  @override
  _WhatDebounceListener get widget => super.widget as _WhatDebounceListener;

  @override
  EffectRunner _createRunner() {
    final Effect effect = DebounceEffect(
      widget.targets,
      widget.duration,
      _handleAction,
      guard: widget.guard,
      leading: widget.leading,
      trailing: widget.trailing,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }
}

/// A private dedicated throttled multi-target reactive side-effect listener widget.
final class _WhatThrottleListener extends WhatListener {
  /// Creates a [_WhatThrottleListener] limiting [action] execution to at most once per [duration].
  const _WhatThrottleListener(
    super.targets,
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
  ComponentElement createElement() => _WhatThrottleListenerElement(this);

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
final class _WhatThrottleListenerElement extends _WhatListenerElement {
  _WhatThrottleListenerElement(_WhatThrottleListener super.widget);

  @override
  _WhatThrottleListener get widget => super.widget as _WhatThrottleListener;

  @override
  EffectRunner _createRunner() {
    final Effect effect = ThrottleEffect(
      widget.targets,
      widget.duration,
      _handleAction,
      guard: widget.guard,
      leading: widget.leading,
      trailing: widget.trailing,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }
}

/// Specialized internal Flutter element for [UnaryWhatListener] hosting a unary [EffectRunner].
base class _UnaryWhatListenerElement<T> extends ComponentElement
    with
        _ReactiveTerminalElementMixin<EffectRunner>,
        _EffectRunnerElementMixin {
  _UnaryWhatListenerElement(UnaryWhatListener<T> super.widget);

  @override
  UnaryWhatListener<T> get widget => super.widget as UnaryWhatListener<T>;

  @override
  Widget? get _childWidget => widget.child;

  @override
  WhatListenerUncaughtErrorCallback? get _uncaughtErrorCallback =>
      widget.onUncaughtError;

  @override
  EffectRunner _createRunner() {
    final Effect effect = Effect.unary(
      widget.target,
      _handleAction,
      guard:
          widget.guard != null ? () => widget.guard!(widget.target.peek) : null,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }

  void _handleAction() {
    if (!mounted) return;
    widget.action(this, widget.target.peek);
  }
}

/// A private dedicated debounced unary reactive side-effect listener widget.
final class _UnaryWhatDebounceListener<T> extends UnaryWhatListener<T> {
  /// Creates a [_UnaryWhatDebounceListener] delaying [action] until [target] settles for [duration].
  const _UnaryWhatDebounceListener(
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
  ComponentElement createElement() =>
      _UnaryWhatDebounceListenerElement<T>(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration>('duration', duration));
    properties.add(FlagProperty('leading', value: leading, ifTrue: 'leading'));
    properties
        .add(FlagProperty('trailing', value: trailing, ifTrue: 'trailing'));
  }
}

/// Specialized internal Flutter element for [_UnaryWhatDebounceListener].
final class _UnaryWhatDebounceListenerElement<T>
    extends _UnaryWhatListenerElement<T> {
  _UnaryWhatDebounceListenerElement(_UnaryWhatDebounceListener<T> super.widget);

  @override
  _UnaryWhatDebounceListener<T> get widget =>
      super.widget as _UnaryWhatDebounceListener<T>;

  @override
  EffectRunner _createRunner() {
    final Effect effect = DebounceEffect.unary(
      widget.target,
      widget.duration,
      _handleAction,
      guard:
          widget.guard != null ? () => widget.guard!(widget.target.peek) : null,
      leading: widget.leading,
      trailing: widget.trailing,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }
}

/// A private dedicated throttled unary reactive side-effect listener widget.
final class _UnaryWhatThrottleListener<T> extends UnaryWhatListener<T> {
  /// Creates a [_UnaryWhatThrottleListener] limiting [action] execution to at most once per [duration].
  const _UnaryWhatThrottleListener(
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
  ComponentElement createElement() =>
      _UnaryWhatThrottleListenerElement<T>(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration>('duration', duration));
    properties.add(FlagProperty('leading', value: leading, ifTrue: 'leading'));
    properties
        .add(FlagProperty('trailing', value: trailing, ifTrue: 'trailing'));
  }
}

/// Specialized internal Flutter element for [_UnaryWhatThrottleListener].
final class _UnaryWhatThrottleListenerElement<T>
    extends _UnaryWhatListenerElement<T> {
  _UnaryWhatThrottleListenerElement(_UnaryWhatThrottleListener<T> super.widget);

  @override
  _UnaryWhatThrottleListener<T> get widget =>
      super.widget as _UnaryWhatThrottleListener<T>;

  @override
  EffectRunner _createRunner() {
    final Effect effect = ThrottleEffect.unary(
      widget.target,
      widget.duration,
      _handleAction,
      guard:
          widget.guard != null ? () => widget.guard!(widget.target.peek) : null,
      leading: widget.leading,
      trailing: widget.trailing,
      take: widget.take,
      onUncaughtError: _handleError,
    );
    return effect.run(autoStart: false);
  }
}
