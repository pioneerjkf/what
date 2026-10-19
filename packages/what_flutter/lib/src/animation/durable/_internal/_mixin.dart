// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../../framework.dart';

mixin _DurableAnimationControllerMixin on DurableAnimationController {
  _AnimationControlDelegate get _delegate;

  final List<_ScopedProxyAnimationView> _scopedViews = [];

  _ScopedProxyAnimationView? _testView;

  bool _activateEngine(TickerProvider vsync);

  void _deactivateEngine();

  @override
  void _attachScopedView(_ScopedProxyAnimationView view) {
    _scopedViews.add(view);
  }

  @override
  void _detachScopedView(_ScopedProxyAnimationView view) {
    _scopedViews.remove(view);
  }

  @pragma('vm:prefer-inline')
  void _scavengeScopedViews() {
    assert(() {
      for (var i = 0; i < _scopedViews.length; i++) {
        assert(
          !_scopedViews[i]._isDisposed,
          'Zombie ScopedProxyAnimationView detected in _scopedViews during deactivation.',
        );
      }
      return true;
    }());
    _scopedViews.removeWhere((v) => v._isDisposed);
  }

  @pragma('vm:prefer-inline')
  void _notifyListeners() {
    for (var i = 0; i < _scopedViews.length; i++) {
      _scopedViews[i]._notify();
    }
  }

  @pragma('vm:prefer-inline')
  void _notifyStatusListeners(AnimationStatus status) {
    for (var i = 0; i < _scopedViews.length; i++) {
      _scopedViews[i]._notifyStatus(status);
    }
  }

  @override
  Animation<double> get _view => _testView ??= _ScopedProxyAnimationView(this);

  @override
  Duration? get duration => _delegate.duration;
  @override
  set duration(Duration? value) => _delegate.duration = value;

  @override
  Duration? get reverseDuration => _delegate.reverseDuration;
  @override
  set reverseDuration(Duration? value) => _delegate.reverseDuration = value;

  final List<TickerProvider> _activeVsyncs = [];

  @override
  void _hibernate() {
    _activeVsyncs.clear();
    _deactivateEngine();
  }

  @override
  void _attachVsync(TickerProvider vsync) {
    if (vsync is _DurableTickerProvider && !vsync.isDurableVsyncActive) {
      return;
    }
    if (!isActive) {
      if (!_activateEngine(vsync)) {
        return;
      }
    }
    if (!_activeVsyncs.contains(vsync)) {
      _activeVsyncs.add(vsync);
    }
  }

  @override
  bool _detachVsync(TickerProvider vsync) {
    final wasPresent = _activeVsyncs.remove(vsync);
    if (!wasPresent && !identical(_delegate.vsync, vsync)) {
      return false;
    }

    if (identical(_delegate.vsync, vsync)) {
      while (_activeVsyncs.isNotEmpty) {
        final candidate = _activeVsyncs.last;
        if (candidate is _DurableTickerProvider &&
            !candidate.isDurableVsyncActive) {
          _activeVsyncs.removeLast();
          continue;
        }
        try {
          _delegate._handoverVsync(candidate);
          return true;
        } catch (error, stackTrace) {
          _activeVsyncs.remove(candidate);
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'what_flutter',
              context: ErrorDescription(
                'while handing over vsync to $candidate in DurableAnimationController',
              ),
            ),
          );
        }
      }
      _deactivateEngine();
      return true;
    }
    return wasPresent;
  }

  @override
  bool get isActive => _delegate is _ActiveAnimationControlDelegate;

  @override
  double get value => _delegate.value;

  @override
  set value(double newValue) => _delegate.value = newValue;

  @override
  void reset() => _delegate.reset();

  @override
  double get velocity => _delegate.velocity;

  @override
  Duration? get lastElapsedDuration => _delegate.lastElapsedDuration;

  @override
  bool get isDormant => _delegate is _DormantAnimationControlDelegate;

  @override
  bool get isAnimating => _delegate.isAnimating;

  @override
  AnimationStatus get status => _delegate.status;

  @override
  TickerFuture forward({double? from}) => _delegate.forward(from: from);

  @override
  TickerFuture reverse({double? from}) => _delegate.reverse(from: from);

  @override
  TickerFuture toggle({double? from}) => _delegate.toggle(from: from);

  @override
  TickerFuture animateTo(double target,
          {Duration? duration, Curve curve = Curves.linear}) =>
      _delegate.animateTo(target, duration: duration, curve: curve);

  @override
  TickerFuture animateBack(double target,
          {Duration? duration, Curve curve = Curves.linear}) =>
      _delegate.animateBack(target, duration: duration, curve: curve);

  @override
  TickerFuture repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  }) =>
      _delegate.repeat(
          min: min, max: max, reverse: reverse, period: period, count: count);

  @override
  TickerFuture fling({
    double velocity = 1.0,
    SpringDescription? springDescription,
    AnimationBehavior? animationBehavior,
  }) =>
      _delegate.fling(
        velocity: velocity,
        springDescription: springDescription,
        animationBehavior: animationBehavior,
      );

  @override
  TickerFuture animateWith(Simulation simulation) =>
      _delegate.animateWith(simulation);

  @override
  TickerFuture animateBackWith(Simulation simulation) =>
      _delegate.animateBackWith(simulation);

  @override
  void stop({bool canceled = true}) => _delegate.stop(canceled: canceled);

  @override
  String toStringDetails() => _delegate.toStringDetails();
}
