// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../../framework.dart';

// =============================================================================
// Concrete Durable Animation Controller Engines
// =============================================================================

final class _CatchUpAnimationController extends DurableAnimationController
    with _DurableAnimationControllerMixin {
  _CatchUpAnimationController({
    double? value,
    Duration? duration,
    Duration? reverseDuration,
    this.debugLabel,
    this.lowerBound = 0.0,
    this.upperBound = 1.0,
    this.animationBehavior = AnimationBehavior.normal,
    this.clock = DateTime.now,
  })  : assert(upperBound >= lowerBound),
        super._() {
    _delegate = _CatchUpDormantControlDelegate(
      value: value ?? lowerBound,
      duration: duration,
      reverseDuration: reverseDuration,
      lowerBound: lowerBound,
      upperBound: upperBound,
      onNotifyListeners: _notifyListeners,
      onNotifyStatusListeners: _notifyStatusListeners,
      clock: clock,
    );
  }

  _CatchUpAnimationController.unbounded({
    double value = 0.0,
    Duration? duration,
    Duration? reverseDuration,
    this.debugLabel,
    this.clock = DateTime.now,
    this.animationBehavior = AnimationBehavior.preserve,
  })  : lowerBound = double.negativeInfinity,
        upperBound = double.infinity,
        super._() {
    _delegate = _CatchUpDormantControlDelegate(
      value: value,
      duration: duration,
      reverseDuration: reverseDuration,
      lowerBound: lowerBound,
      upperBound: upperBound,
      onNotifyListeners: _notifyListeners,
      onNotifyStatusListeners: _notifyStatusListeners,
      clock: clock,
    );
  }

  @override
  DurabilityPolicy get policy => DurabilityPolicy.catchUp;

  @override
  final double lowerBound;

  @override
  final double upperBound;

  @override
  final String? debugLabel;

  @override
  final AnimationBehavior animationBehavior;

  final DateTime Function() clock;

  @override
  late _AnimationControlDelegate _delegate;

  @override
  bool _activateEngine(TickerProvider vsync) {
    final dormant = _delegate;
    if (dormant is _CatchUpDormantControlDelegate) {
      try {
        _delegate = dormant.activate(
          vsync,
          debugLabel: debugLabel,
          animationBehavior: animationBehavior,
        );
        return true;
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'what_flutter',
            context: ErrorDescription(
              'while activating CatchUpAnimationController with $vsync',
            ),
          ),
        );
        return false;
      }
    }
    return false;
  }

  @override
  void _deactivateEngine() {
    final oldDelegate = _delegate;
    if (oldDelegate is _ActiveAnimationControlDelegate) {
      final staged = oldDelegate.stagedMotion;
      final wasAnim = staged.mode != _StagedMotionMode.idle;

      final preservedValue = oldDelegate.value;
      final preservedDuration = oldDelegate.duration;
      final preservedReverseDuration = oldDelegate.reverseDuration;

      _delegate = _CatchUpDormantControlDelegate(
        value: preservedValue,
        duration: preservedDuration,
        reverseDuration: preservedReverseDuration,
        lowerBound: lowerBound,
        upperBound: upperBound,
        onNotifyListeners: _notifyListeners,
        onNotifyStatusListeners: _notifyStatusListeners,
        clock: clock,
        deactivatedAt: wasAnim ? clock() : null,
        stagedMotion: staged,
      );

      try {
        oldDelegate.dispose();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'what_flutter',
            context: ErrorDescription(
              'while disposing active delegate during CatchUpAnimationController deactivation',
            ),
          ),
        );
      }

      _scavengeScopedViews();
    }
  }
}

final class _FrozenAnimationController extends DurableAnimationController
    with _DurableAnimationControllerMixin {
  _FrozenAnimationController({
    double? value,
    Duration? duration,
    Duration? reverseDuration,
    this.debugLabel,
    this.lowerBound = 0.0,
    this.upperBound = 1.0,
    this.animationBehavior = AnimationBehavior.normal,
    this.frozen = true,
  })  : assert(upperBound >= lowerBound),
        _initialValue = value,
        _initialDuration = duration,
        _initialReverseDuration = reverseDuration,
        super._() {
    _delegate = _FrozenDormantControlDelegate(
      value: value ?? lowerBound,
      duration: duration,
      reverseDuration: reverseDuration,
      lowerBound: lowerBound,
      upperBound: upperBound,
      onNotifyListeners: _notifyListeners,
      onNotifyStatusListeners: _notifyStatusListeners,
      frozen: frozen,
      initialValue: _initialValue,
      initialDuration: _initialDuration,
      initialReverseDuration: _initialReverseDuration,
    );
  }

  _FrozenAnimationController.unbounded({
    double value = 0.0,
    Duration? duration,
    Duration? reverseDuration,
    this.debugLabel,
    this.frozen = true,
    this.animationBehavior = AnimationBehavior.preserve,
  })  : lowerBound = double.negativeInfinity,
        upperBound = double.infinity,
        _initialValue = value,
        _initialDuration = duration,
        _initialReverseDuration = reverseDuration,
        super._() {
    _delegate = _FrozenDormantControlDelegate(
      value: value,
      duration: duration,
      reverseDuration: reverseDuration,
      lowerBound: lowerBound,
      upperBound: upperBound,
      onNotifyListeners: _notifyListeners,
      onNotifyStatusListeners: _notifyStatusListeners,
      frozen: frozen,
      initialValue: _initialValue,
      initialDuration: _initialDuration,
      initialReverseDuration: _initialReverseDuration,
    );
  }

  @override
  DurabilityPolicy get policy =>
      frozen ? DurabilityPolicy.resume : DurabilityPolicy.reset;

  @override
  final double lowerBound;

  @override
  final double upperBound;

  @override
  final String? debugLabel;

  @override
  final AnimationBehavior animationBehavior;

  final bool frozen;

  final double? _initialValue;
  final Duration? _initialDuration;
  final Duration? _initialReverseDuration;

  @override
  late _AnimationControlDelegate _delegate;

  @override
  bool _activateEngine(TickerProvider vsync) {
    final dormant = _delegate;
    if (dormant is _FrozenDormantControlDelegate) {
      try {
        _delegate = dormant.activate(
          vsync,
          debugLabel: debugLabel,
          animationBehavior: animationBehavior,
        );
        return true;
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'what_flutter',
            context: ErrorDescription(
              'while activating FrozenAnimationController with $vsync',
            ),
          ),
        );
        return false;
      }
    }
    return false;
  }

  @override
  void _deactivateEngine() {
    final oldDelegate = _delegate;
    if (oldDelegate is _ActiveAnimationControlDelegate) {
      final staged = oldDelegate.stagedMotion;
      final wasAnim = frozen && (staged.mode != _StagedMotionMode.idle);

      final preservedValue =
          frozen ? oldDelegate.value : (_initialValue ?? lowerBound);
      final preservedDuration =
          frozen ? oldDelegate.duration : _initialDuration;
      final preservedReverseDuration =
          frozen ? oldDelegate.reverseDuration : _initialReverseDuration;

      _delegate = _FrozenDormantControlDelegate(
        value: preservedValue,
        duration: preservedDuration,
        reverseDuration: preservedReverseDuration,
        lowerBound: lowerBound,
        upperBound: upperBound,
        onNotifyListeners: _notifyListeners,
        onNotifyStatusListeners: _notifyStatusListeners,
        frozen: frozen,
        initialValue: _initialValue,
        initialDuration: _initialDuration,
        initialReverseDuration: _initialReverseDuration,
        stagedMotion: wasAnim ? staged : const _StagedMotion.idle(),
      );

      try {
        oldDelegate.dispose();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'what_flutter',
            context: ErrorDescription(
              'while disposing active delegate during FrozenAnimationController deactivation',
            ),
          ),
        );
      }

      _scavengeScopedViews();
    }
  }
}
