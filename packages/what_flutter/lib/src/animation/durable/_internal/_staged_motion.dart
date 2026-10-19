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

  _StagedMotion copyWith({
    _StagedMotionMode? mode,
    double? targetFromValue,
    double? targetValue,
    Duration? targetDuration,
    Curve? targetCurve,
    double? repeatMin,
    double? repeatMax,
    bool? repeatReverse,
    Duration? repeatPeriod,
    int? repeatCount,
    bool? wasReversePhase,
    double? flingVelocity,
    SpringDescription? springDescription,
    AnimationBehavior? animationBehavior,
    Simulation? simulation,
    Duration? elapsedDuration,
  }) {
    return _StagedMotion(
      mode: mode ?? this.mode,
      targetFromValue: targetFromValue ?? this.targetFromValue,
      targetValue: targetValue ?? this.targetValue,
      targetDuration: targetDuration ?? this.targetDuration,
      targetCurve: targetCurve ?? this.targetCurve,
      repeatMin: repeatMin ?? this.repeatMin,
      repeatMax: repeatMax ?? this.repeatMax,
      repeatReverse: repeatReverse ?? this.repeatReverse,
      repeatPeriod: repeatPeriod ?? this.repeatPeriod,
      repeatCount: repeatCount ?? this.repeatCount,
      wasReversePhase: wasReversePhase ?? this.wasReversePhase,
      flingVelocity: flingVelocity ?? this.flingVelocity,
      springDescription: springDescription ?? this.springDescription,
      animationBehavior: animationBehavior ?? this.animationBehavior,
      simulation: simulation ?? this.simulation,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
    );
  }
}
