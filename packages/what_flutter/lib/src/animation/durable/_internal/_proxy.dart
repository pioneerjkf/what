// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../../framework.dart';

// =============================================================================
// Internal Durable Animation Controller Proxy
// =============================================================================

final class _ScopedDurableAnimationControllerProxy
    extends DurableAnimationController implements ScopedAnimationController {
  _ScopedDurableAnimationControllerProxy(this._target) : super._();

  final DurableAnimationController _target;

  _ScopedProxyAnimationView? _scopedView;

  bool _isDisposed = false;

  @pragma('vm:prefer-inline')
  void _assertNotDisposed() {
    assert(!_isDisposed,
        'Cannot perform animation operations on a disposed ScopedAnimationController.');
  }

  bool isSameTarget(_ScopedDurableAnimationControllerProxy other) =>
      identical(_target, other._target);

  @override
  void _hibernate() => _target._hibernate();

  @override
  void _attachVsync(TickerProvider vsync) => _target._attachVsync(vsync);

  @override
  bool _detachVsync(TickerProvider vsync) => _target._detachVsync(vsync);

  @override
  void _attachScopedView(_ScopedProxyAnimationView view) =>
      _target._attachScopedView(view);

  @override
  void _detachScopedView(_ScopedProxyAnimationView view) =>
      _target._detachScopedView(view);

  @override
  Animation<double> get _view => _target._view;

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _scopedView?._dispose();
    _scopedView = null;
  }

  @override
  double get lowerBound => _target.lowerBound;

  @override
  double get upperBound => _target.upperBound;

  @override
  String? get debugLabel => _target.debugLabel;

  @override
  AnimationBehavior get animationBehavior => _target.animationBehavior;

  @override
  DurabilityPolicy get policy => _target.policy;

  @override
  Animation<double> get view {
    _assertNotDisposed();
    return _scopedView ??= _ScopedProxyAnimationView(_target);
  }

  @override
  Duration? get duration => _target.duration;
  @override
  set duration(Duration? value) {
    _assertNotDisposed();
    _target.duration = value;
  }

  @override
  Duration? get reverseDuration => _target.reverseDuration;
  @override
  set reverseDuration(Duration? value) {
    _assertNotDisposed();
    _target.reverseDuration = value;
  }

  @override
  bool get isActive => _target.isActive;

  @override
  bool get isDormant => _target.isDormant;

  @override
  double get value => _target.value;
  @override
  set value(double newValue) {
    _assertNotDisposed();
    _target.value = newValue;
  }

  @override
  void reset() {
    _assertNotDisposed();
    _target.reset();
  }

  @override
  double get velocity => _target.velocity;

  @override
  Duration? get lastElapsedDuration => _target.lastElapsedDuration;

  @override
  AnimationStatus get status => _target.status;

  @override
  bool get isAnimating => _target.isAnimating;

  @override
  TickerFuture forward({double? from}) {
    _assertNotDisposed();
    return _target.forward(from: from);
  }

  @override
  TickerFuture reverse({double? from}) {
    _assertNotDisposed();
    return _target.reverse(from: from);
  }

  @override
  TickerFuture toggle({double? from}) {
    _assertNotDisposed();
    return _target.toggle(from: from);
  }

  @override
  TickerFuture animateTo(
    double targetValue, {
    Duration? duration,
    Curve curve = Curves.linear,
  }) {
    _assertNotDisposed();
    return _target.animateTo(targetValue, duration: duration, curve: curve);
  }

  @override
  TickerFuture animateBack(
    double targetValue, {
    Duration? duration,
    Curve curve = Curves.linear,
  }) {
    _assertNotDisposed();
    return _target.animateBack(targetValue, duration: duration, curve: curve);
  }

  @override
  TickerFuture repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  }) {
    _assertNotDisposed();
    return _target.repeat(
      min: min,
      max: max,
      reverse: reverse,
      period: period,
      count: count,
    );
  }

  @override
  TickerFuture fling({
    double velocity = 1.0,
    SpringDescription? springDescription,
    AnimationBehavior? animationBehavior,
  }) {
    _assertNotDisposed();
    return _target.fling(
      velocity: velocity,
      springDescription: springDescription,
      animationBehavior: animationBehavior,
    );
  }

  @override
  TickerFuture animateWith(Simulation simulation) {
    _assertNotDisposed();
    return _target.animateWith(simulation);
  }

  @override
  TickerFuture animateBackWith(Simulation simulation) {
    _assertNotDisposed();
    return _target.animateBackWith(simulation);
  }

  @override
  void stop({bool canceled = true}) {
    _assertNotDisposed();
    _target.stop(canceled: canceled);
  }

  @override
  Animation<U> drive<U>(Animatable<U> child) {
    _assertNotDisposed();
    return child.animate(view);
  }

  @override
  String toStringDetails() => _target.toStringDetails();
}

// =============================================================================
// Internal Scoped Proxy Animation View
// =============================================================================

final class _ScopedProxyAnimationView extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  _ScopedProxyAnimationView(this._target) {
    _target._attachScopedView(this);
  }

  final DurableAnimationController _target;
  bool _isDisposed = false;

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  void _notifyStatus(AnimationStatus status) {
    if (!_isDisposed) notifyStatusListeners(status);
  }

  void _dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _target._detachScopedView(this);
    clearListeners();
    clearStatusListeners();
  }

  @override
  double get value => _target.value;

  @override
  AnimationStatus get status => _target.status;

  @override
  void didRegisterListener() {
    assert(
        !_isDisposed,
        'Cannot attach listeners to a disposed ScopedProxyAnimationView. '
        'Ensure derived animations (e.g. CurvedAnimation) or listeners are created within an active widget lifecycle.');
  }

  @override
  void didUnregisterListener() {}
}

// =============================================================================
// Internal Durable Ticker Provider Contract & Mixins
// =============================================================================

abstract interface class _DurableTickerProvider implements TickerProvider {
  bool get isDurableVsyncActive;
}

// =============================================================================
// Internal Durable VSYNC Socket & Element Lifecycle Mixin
// =============================================================================

final class _DurableVsyncSocketTicker extends Ticker {
  _DurableVsyncSocketTicker(super.onTick, this._host, {super.debugLabel});

  final _DurableVsyncSocketElementMixin _host;

  @override
  void dispose() {
    _host._clearTicker(this);
    super.dispose();
  }
}

mixin _DurableVsyncSocketElementMixin on ComponentElement
    implements _DurableTickerProvider {
  _AnimatedControllerWidget get _controllerWidget =>
      widget as _AnimatedControllerWidget;

  _DurableVsyncSocketTicker? _ticker;
  bool _isDurableVsyncActive = false;

  _ScopedDurableAnimationControllerProxy? _proxy;
  bool _isListening = false;

  @override
  bool get isDurableVsyncActive => _isDurableVsyncActive;

  _ScopedDurableAnimationControllerProxy get proxy => _proxy!;

  void _clearTicker(_DurableVsyncSocketTicker ticker) {
    if (identical(_ticker, ticker)) {
      _ticker = null;
    }
  }

  @override
  Ticker createTicker(TickerCallback onTick) {
    _ticker?.dispose();
    final bool muted =
        !_isDurableVsyncActive || !TickerMode.valuesOf(this).enabled;
    final ticker = _DurableVsyncSocketTicker(
      onTick,
      this,
      debugLabel: kDebugMode
          ? (_isDurableVsyncActive
              ? 'created by $this'
              : 'created by $this (dormant)')
          : null,
    )..muted = muted;
    _ticker = ticker;
    return ticker;
  }

  @pragma('vm:prefer-inline')
  void _handleTick() {
    if (this is _ViaTerminalElementMixin) {
      (this as _ViaTerminalElementMixin).terminal.markDirty();
    }
    markNeedsBuild();
  }

  void _syncController() {
    final controller = _controllerWidget.controller;
    if (_proxy case final proxy? when identical(proxy._target, controller)) {
      return;
    }
    if (_proxy != null) {
      _safeCallDeactivate();
    }
    _bindProxy(controller);
    _safeCallActivate();
  }

  void _bindProxy(DurableAnimationController controller) {
    _unbindProxy();
    final proxy = _ScopedDurableAnimationControllerProxy(controller);
    _proxy = proxy;
    proxy._attachVsync(this);
    proxy.view.addListener(_handleTick);
    _isListening = true;
  }

  void _unbindProxy() {
    if (_proxy case final proxy?) {
      if (_isListening) {
        proxy.view.removeListener(_handleTick);
        _isListening = false;
      }
      proxy.dispose();
      proxy._detachVsync(this);
      _proxy = null;
    }
  }

  void _safeCallActivate() {
    final proxy = _proxy;
    if (proxy == null) return;
    try {
      _controllerWidget.onActivate?.call(proxy);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'what_flutter',
          context: ErrorDescription('while executing onActivate for $widget'),
        ),
      );
    }
  }

  void _safeCallDeactivate() {
    final proxy = _proxy;
    if (proxy == null) return;
    try {
      _controllerWidget.onDeactivate?.call(proxy);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'what_flutter',
          context: ErrorDescription('while executing onDeactivate for $widget'),
        ),
      );
    }
  }

  @mustCallSuper
  @override
  void mount(Element? parent, Object? newSlot) {
    _isDurableVsyncActive = true;
    super.mount(parent, newSlot);
  }

  @mustCallSuper
  @override
  void didChangeDependencies() {
    final bool muted =
        !_isDurableVsyncActive || !TickerMode.valuesOf(this).enabled;
    _ticker?.muted = muted;
    super.didChangeDependencies();
  }

  @mustCallSuper
  @override
  void performRebuild() {
    _syncController();
    super.performRebuild();
  }

  @mustCallSuper
  @override
  void activate() {
    _isDurableVsyncActive = true;
    super.activate();
    final bool muted = !TickerMode.valuesOf(this).enabled;
    _ticker?.muted = muted;
    _syncController();
  }

  @mustCallSuper
  @override
  void update(covariant Widget newWidget) {
    super.update(newWidget);
    _syncController();
  }

  @mustCallSuper
  @override
  void deactivate() {
    _safeCallDeactivate();
    _isDurableVsyncActive = false;
    _ticker?.muted = true;
    _unbindProxy();
    super.deactivate();
  }

  @mustCallSuper
  @override
  void unmount() {
    _safeCallDeactivate();
    _isDurableVsyncActive = false;
    _unbindProxy();
    _ticker?.dispose();
    _ticker = null;
    super.unmount();
  }
}
