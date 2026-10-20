// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../../framework.dart';

// =============================================================================
// Staged Motion Domain Models
// =============================================================================

enum _StagedMotionMode {
  idle,
  forward,
  reverse,
  repeat,
  animateTo,
  animateBack,
  fling,
  simulation,
  simulationBack,
}

final class _StagedMotion {
  final _StagedMotionMode mode;

  final double? targetFromValue;
  final double? targetValue;
  final Duration? targetDuration;
  final Curve targetCurve;

  final double? repeatMin;
  final double? repeatMax;
  final bool repeatReverse;
  final Duration? repeatPeriod;
  final int? repeatCount;
  final bool wasReversePhase;

  final double flingVelocity;
  final SpringDescription? springDescription;
  final AnimationBehavior? animationBehavior;
  final Simulation? simulation;
  final Duration? elapsedDuration;

  const _StagedMotion.idle()
      : mode = _StagedMotionMode.idle,
        targetFromValue = null,
        targetValue = null,
        targetDuration = null,
        targetCurve = Curves.linear,
        repeatMin = null,
        repeatMax = null,
        repeatReverse = false,
        repeatPeriod = null,
        repeatCount = null,
        wasReversePhase = false,
        flingVelocity = 1.0,
        springDescription = null,
        animationBehavior = null,
        simulation = null,
        elapsedDuration = null;

  const _StagedMotion({
    required this.mode,
    this.targetFromValue,
    this.targetValue,
    this.targetDuration,
    this.targetCurve = Curves.linear,
    this.repeatMin,
    this.repeatMax,
    this.repeatReverse = false,
    this.repeatPeriod,
    this.repeatCount,
    this.wasReversePhase = false,
    this.flingVelocity = 1.0,
    this.springDescription,
    this.animationBehavior,
    this.simulation,
    this.elapsedDuration,
  });
  static const Object _motionSentinel = Object();

  _StagedMotion copyWith({
    _StagedMotionMode? mode,
    Object? targetFromValue = _motionSentinel,
    Object? targetValue = _motionSentinel,
    Object? targetDuration = _motionSentinel,
    Curve? targetCurve,
    Object? repeatMin = _motionSentinel,
    Object? repeatMax = _motionSentinel,
    bool? repeatReverse,
    Object? repeatPeriod = _motionSentinel,
    Object? repeatCount = _motionSentinel,
    bool? wasReversePhase,
    double? flingVelocity,
    Object? springDescription = _motionSentinel,
    Object? animationBehavior = _motionSentinel,
    Object? simulation = _motionSentinel,
    Object? elapsedDuration = _motionSentinel,
  }) {
    return _StagedMotion(
      mode: mode ?? this.mode,
      targetFromValue: identical(targetFromValue, _motionSentinel)
          ? this.targetFromValue
          : targetFromValue as double?,
      targetValue: identical(targetValue, _motionSentinel)
          ? this.targetValue
          : targetValue as double?,
      targetDuration: identical(targetDuration, _motionSentinel)
          ? this.targetDuration
          : targetDuration as Duration?,
      targetCurve: targetCurve ?? this.targetCurve,
      repeatMin: identical(repeatMin, _motionSentinel)
          ? this.repeatMin
          : repeatMin as double?,
      repeatMax: identical(repeatMax, _motionSentinel)
          ? this.repeatMax
          : repeatMax as double?,
      repeatReverse: repeatReverse ?? this.repeatReverse,
      repeatPeriod: identical(repeatPeriod, _motionSentinel)
          ? this.repeatPeriod
          : repeatPeriod as Duration?,
      repeatCount: identical(repeatCount, _motionSentinel)
          ? this.repeatCount
          : repeatCount as int?,
      wasReversePhase: wasReversePhase ?? this.wasReversePhase,
      flingVelocity: flingVelocity ?? this.flingVelocity,
      springDescription: identical(springDescription, _motionSentinel)
          ? this.springDescription
          : springDescription as SpringDescription?,
      animationBehavior: identical(animationBehavior, _motionSentinel)
          ? this.animationBehavior
          : animationBehavior as AnimationBehavior?,
      simulation: identical(simulation, _motionSentinel)
          ? this.simulation
          : simulation as Simulation?,
      elapsedDuration: identical(elapsedDuration, _motionSentinel)
          ? this.elapsedDuration
          : elapsedDuration as Duration?,
    );
  }
}
