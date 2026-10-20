// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../../framework.dart';

const Tolerance _kFlingTolerance =
    Tolerance(velocity: double.infinity, distance: 0.01);
final SpringDescription _kFlingSpringDescription =
    SpringDescription.withDampingRatio(
  mass: 1.0,
  stiffness: 500.0,
);

// =============================================================================
// Animation Control Delegate Contract
// =============================================================================

abstract base class _AnimationControlDelegate {
  Animation<double>? get view;
  TickerProvider? get vsync;

  Duration? get duration;
  set duration(Duration? newValue);

  Duration? get reverseDuration;
  set reverseDuration(Duration? newValue);

  double get value;
  set value(double newValue);

  double get velocity;
  Duration? get lastElapsedDuration;
  bool get isAnimating;
  AnimationStatus get status;

  void _handoverVsync(TickerProvider vsync);
  void reset();
  void dispose();

  TickerFuture forward({double? from});
  TickerFuture reverse({double? from});
  TickerFuture toggle({double? from});
  TickerFuture animateTo(double target,
      {Duration? duration, Curve curve = Curves.linear});
  TickerFuture animateBack(double target,
      {Duration? duration, Curve curve = Curves.linear});
  TickerFuture repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  });
  TickerFuture fling({
    double velocity = 1.0,
    SpringDescription? springDescription,
    AnimationBehavior? animationBehavior,
  });
  TickerFuture animateWith(Simulation simulation);
  TickerFuture animateBackWith(Simulation simulation);
  void stop({bool canceled = true});

  String toStringDetails();
}

// =============================================================================
// Dormant State Delegates
// =============================================================================

abstract base class _DormantAnimationControlDelegate
    implements _AnimationControlDelegate {
  double _value;
  Duration? _duration;
  Duration? _reverseDuration;

  final double lowerBound;
  final double upperBound;
  final VoidCallback onNotifyListeners;
  final ValueChanged<AnimationStatus> onNotifyStatusListeners;

  _StagedMotion _stagedMotion;

  _DormantAnimationControlDelegate({
    required double value,
    required Duration? duration,
    required Duration? reverseDuration,
    required this.lowerBound,
    required this.upperBound,
    required this.onNotifyListeners,
    required this.onNotifyStatusListeners,
    _StagedMotion? stagedMotion,
  })  : _value = value,
        _duration = duration,
        _reverseDuration = reverseDuration,
        _stagedMotion = stagedMotion ?? const _StagedMotion.idle();

  void _onMotionStaged() {}
  void _onMotionCanceled() {}

  @override
  Animation<double>? get view => null;

  @override
  TickerProvider? get vsync => null;

  @override
  Duration? get duration => _duration;

  @override
  set duration(Duration? newValue) {
    _duration = newValue;
  }

  @override
  Duration? get reverseDuration => _reverseDuration;

  @override
  set reverseDuration(Duration? newValue) {
    _reverseDuration = newValue;
  }

  @override
  double get value => _value;

  @override
  set value(double newValue) {
    _stagedMotion = const _StagedMotion.idle();
    _value = newValue;
    _onMotionCanceled();
  }

  @override
  double get velocity => 0.0;

  @override
  Duration? get lastElapsedDuration => null;

  @override
  bool get isAnimating => _stagedMotion.mode != _StagedMotionMode.idle;

  @override
  AnimationStatus get status {
    if (_stagedMotion.mode == _StagedMotionMode.idle) {
      return (_value == upperBound)
          ? AnimationStatus.completed
          : AnimationStatus.dismissed;
    }
    return switch (_stagedMotion.mode) {
      _StagedMotionMode.forward => AnimationStatus.forward,
      _StagedMotionMode.reverse => AnimationStatus.reverse,
      _StagedMotionMode.repeat => _stagedMotion.wasReversePhase
          ? AnimationStatus.reverse
          : AnimationStatus.forward,
      _StagedMotionMode.animateTo => AnimationStatus.forward,
      _StagedMotionMode.animateBack => AnimationStatus.reverse,
      _StagedMotionMode.fling => _stagedMotion.wasReversePhase
          ? AnimationStatus.reverse
          : AnimationStatus.forward,
      _StagedMotionMode.simulation => AnimationStatus.forward,
      _StagedMotionMode.simulationBack => AnimationStatus.reverse,
      _StagedMotionMode.idle => AnimationStatus.dismissed,
    };
  }

  bool get isForwardOrCompleted => status.isForwardOrCompleted;

  @override
  void _handoverVsync(TickerProvider vsync) {}

  @override
  void reset() {
    _stagedMotion = const _StagedMotion.idle();
    _value = lowerBound;
    _onMotionCanceled();
  }

  void _prepareStageMotion({required bool hasFrom}) {}

  void _stageMotion(
    _StagedMotion motion, {
    double? from,
    required AnimationStatus notifyStatus,
  }) {
    if (from != null) {
      _value = from;
    }
    _prepareStageMotion(hasFrom: from != null);
    _stagedMotion = motion;
    _onMotionStaged();
    onNotifyStatusListeners(notifyStatus);
  }

  @override
  TickerFuture forward({double? from}) {
    _stageMotion(
      const _StagedMotion(
        mode: _StagedMotionMode.forward,
        wasReversePhase: false,
      ),
      from: from,
      notifyStatus: AnimationStatus.forward,
    );
    return TickerFuture.complete();
  }

  @override
  TickerFuture reverse({double? from}) {
    _stageMotion(
      const _StagedMotion(
        mode: _StagedMotionMode.reverse,
        wasReversePhase: true,
      ),
      from: from,
      notifyStatus: AnimationStatus.reverse,
    );
    return TickerFuture.complete();
  }

  @override
  TickerFuture toggle({double? from}) {
    final forwardAim = !isForwardOrCompleted;
    _stageMotion(
      _StagedMotion(
        mode:
            forwardAim ? _StagedMotionMode.forward : _StagedMotionMode.reverse,
        wasReversePhase: !forwardAim,
      ),
      from: from,
      notifyStatus:
          forwardAim ? AnimationStatus.forward : AnimationStatus.reverse,
    );
    return TickerFuture.complete();
  }

  @override
  TickerFuture animateTo(double target,
      {Duration? duration, Curve curve = Curves.linear}) {
    final range = upperBound - lowerBound;
    final effectiveDuration = duration ??
        (_duration != null
            ? (range.isFinite
                ? _duration! * ((target - _value).abs() / range)
                : _duration!)
            : const Duration(milliseconds: 300));
    final sim = _CurvedInterpolationSimulation(
      begin: _value,
      end: target,
      duration: effectiveDuration,
      curve: curve,
    );
    _stageMotion(
      _StagedMotion(
        mode: _StagedMotionMode.animateTo,
        targetFromValue: _value,
        targetValue: target,
        targetDuration: effectiveDuration,
        targetCurve: curve,
        simulation: sim,
        elapsedDuration: Duration.zero,
        wasReversePhase: false,
      ),
      notifyStatus: AnimationStatus.forward,
    );
    return TickerFuture.complete();
  }

  @override
  TickerFuture animateBack(double target,
      {Duration? duration, Curve curve = Curves.linear}) {
    final range = upperBound - lowerBound;
    final effectiveDuration = duration ??
        ((_reverseDuration ?? _duration) != null
            ? (range.isFinite
                ? (_reverseDuration ?? _duration)! *
                    ((_value - target).abs() / range)
                : (_reverseDuration ?? _duration)!)
            : const Duration(milliseconds: 300));
    final sim = _CurvedInterpolationSimulation(
      begin: _value,
      end: target,
      duration: effectiveDuration,
      curve: curve,
    );
    _stageMotion(
      _StagedMotion(
        mode: _StagedMotionMode.animateBack,
        targetFromValue: _value,
        targetValue: target,
        targetDuration: effectiveDuration,
        targetCurve: curve,
        simulation: sim,
        elapsedDuration: Duration.zero,
        wasReversePhase: true,
      ),
      notifyStatus: AnimationStatus.reverse,
    );
    return TickerFuture.complete();
  }

  @override
  TickerFuture repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  }) {
    _stageMotion(
      _StagedMotion(
        mode: _StagedMotionMode.repeat,
        repeatMin: min,
        repeatMax: max,
        repeatReverse: reverse,
        repeatPeriod: period,
        repeatCount: count,
        wasReversePhase: false,
      ),
      notifyStatus: AnimationStatus.forward,
    );
    return TickerFuture.complete();
  }

  @override
  TickerFuture fling({
    double velocity = 1.0,
    SpringDescription? springDescription,
    AnimationBehavior? animationBehavior,
  }) {
    final isRev = velocity < 0.0;
    final target = isRev
        ? lowerBound - _kFlingTolerance.distance
        : upperBound + _kFlingTolerance.distance;
    final spring = springDescription ?? _kFlingSpringDescription;
    final sim = SpringSimulation(spring, _value, target, velocity)
      ..tolerance = _kFlingTolerance;
    _stageMotion(
      _StagedMotion(
        mode: _StagedMotionMode.fling,
        flingVelocity: velocity,
        springDescription: springDescription,
        animationBehavior: animationBehavior,
        simulation: sim,
        wasReversePhase: isRev,
      ),
      notifyStatus: isRev ? AnimationStatus.reverse : AnimationStatus.forward,
    );
    return TickerFuture.complete();
  }

  @override
  TickerFuture animateWith(Simulation simulation) {
    _stageMotion(
      _StagedMotion(
        mode: _StagedMotionMode.simulation,
        simulation: simulation,
        wasReversePhase: false,
      ),
      notifyStatus: AnimationStatus.forward,
    );
    return TickerFuture.complete();
  }

  @override
  TickerFuture animateBackWith(Simulation simulation) {
    _stageMotion(
      _StagedMotion(
        mode: _StagedMotionMode.simulationBack,
        simulation: simulation,
        wasReversePhase: true,
      ),
      notifyStatus: AnimationStatus.reverse,
    );
    return TickerFuture.complete();
  }

  @override
  void stop({bool canceled = true}) {
    _stagedMotion = const _StagedMotion.idle();
    _onMotionCanceled();
  }

  @override
  void dispose() {}

  @override
  String toStringDetails() {
    final String statusName = status.name;
    final String valueString = _value.toStringAsFixed(3);
    return '$statusName $valueString; dormant';
  }

  // ---------------------------------------------------------------------------
  // Motion Resumption Dispatcher
  // ---------------------------------------------------------------------------

  void resumeMotion(
    AnimationController engine, {
    _ActiveAnimationControlDelegate? activeDelegate,
  }) {
    switch (_stagedMotion.mode) {
      case _StagedMotionMode.forward:
        if (engine.value < upperBound) {
          engine.forward();
        }
        break;
      case _StagedMotionMode.reverse:
        if (engine.value > lowerBound) {
          engine.reverse();
        }
        break;
      case _StagedMotionMode.repeat:
        final min = _stagedMotion.repeatMin ?? lowerBound;
        final max = _stagedMotion.repeatMax ?? upperBound;
        if (_stagedMotion.repeatReverse &&
            _stagedMotion.wasReversePhase &&
            (engine.value - min) > 0.0001) {
          final period = _stagedMotion.repeatPeriod ?? duration;
          final range = max - min;
          final remainingDistance = (engine.value - min).clamp(0.0, range);
          final tripDuration = (period != null && range > 0)
              ? period * (remainingDistance / range)
              : null;

          final expectedMotion = _stagedMotion;
          engine
              .animateBack(
            min,
            duration: tripDuration,
          )
              .then((_) {
            if (activeDelegate != null) {
              if (activeDelegate.isDisposed ||
                  activeDelegate.lastDispatchedMotion != expectedMotion) {
                return;
              }
              if (tripDuration != null) {
                activeDelegate._accumulateBaseElapsed(tripDuration);
              }
            }
            if (_stagedMotion.mode == _StagedMotionMode.repeat) {
              engine.repeat(
                min: _stagedMotion.repeatMin,
                max: _stagedMotion.repeatMax,
                reverse: _stagedMotion.repeatReverse,
                period: _stagedMotion.repeatPeriod,
              );
            }
          });
        } else {
          engine.repeat(
            min: _stagedMotion.repeatMin,
            max: _stagedMotion.repeatMax,
            reverse: _stagedMotion.repeatReverse,
            period: _stagedMotion.repeatPeriod,
          );
        }
        break;
      case _StagedMotionMode.animateTo:
        if (_stagedMotion.targetValue != null &&
            (engine.value - _stagedMotion.targetValue!).abs() > 0.0001) {
          final range = upperBound - lowerBound;
          final effectiveDuration = _stagedMotion.targetDuration ??
              (_duration != null
                  ? (range.isFinite
                      ? _duration! *
                          ((_stagedMotion.targetValue! - engine.value).abs() /
                              range)
                      : _duration!)
                  : const Duration(milliseconds: 300));
          final sim = _stagedMotion.simulation ??
              _CurvedInterpolationSimulation(
                begin: _stagedMotion.targetFromValue ?? engine.value,
                end: _stagedMotion.targetValue!,
                duration: effectiveDuration,
                curve: _stagedMotion.targetCurve,
              );
          final elapsed = _stagedMotion.elapsedDuration;
          if (elapsed != null && elapsed > Duration.zero) {
            final offsetSeconds =
                elapsed.inMicroseconds / Duration.microsecondsPerSecond;
            if (sim.isDone(offsetSeconds)) {
              final targetValue = _stagedMotion.targetValue ?? upperBound;
              _stagedMotion = const _StagedMotion.idle();
              engine.value = targetValue;
              onNotifyStatusListeners(AnimationStatus.completed);
            } else {
              engine.animateWith(_TimeOffsetSimulation(sim, offsetSeconds));
            }
          } else {
            engine.animateWith(sim);
          }
        }
        break;
      case _StagedMotionMode.animateBack:
        if (_stagedMotion.targetValue != null &&
            (engine.value - _stagedMotion.targetValue!).abs() > 0.0001) {
          final range = upperBound - lowerBound;
          final effectiveDuration = _stagedMotion.targetDuration ??
              ((_reverseDuration ?? _duration) != null
                  ? (range.isFinite
                      ? (_reverseDuration ?? _duration)! *
                          ((engine.value - _stagedMotion.targetValue!).abs() /
                              range)
                      : (_reverseDuration ?? _duration)!)
                  : const Duration(milliseconds: 300));
          final sim = _stagedMotion.simulation ??
              _CurvedInterpolationSimulation(
                begin: _stagedMotion.targetFromValue ?? engine.value,
                end: _stagedMotion.targetValue!,
                duration: effectiveDuration,
                curve: _stagedMotion.targetCurve,
              );
          final elapsed = _stagedMotion.elapsedDuration;
          if (elapsed != null && elapsed > Duration.zero) {
            final offsetSeconds =
                elapsed.inMicroseconds / Duration.microsecondsPerSecond;
            if (sim.isDone(offsetSeconds)) {
              final targetValue = _stagedMotion.targetValue ?? lowerBound;
              _stagedMotion = const _StagedMotion.idle();
              engine.value = targetValue;
              onNotifyStatusListeners(AnimationStatus.dismissed);
            } else {
              engine.animateBackWith(_TimeOffsetSimulation(sim, offsetSeconds));
            }
          } else {
            engine.animateBackWith(sim);
          }
        }
        break;
      case _StagedMotionMode.fling:
        if (_stagedMotion.simulation != null) {
          final sim = _stagedMotion.simulation!;
          final isRev = _stagedMotion.wasReversePhase;
          final elapsed = _stagedMotion.elapsedDuration;
          if (elapsed != null && elapsed > Duration.zero) {
            final offsetSeconds =
                elapsed.inMicroseconds / Duration.microsecondsPerSecond;
            if (sim.isDone(offsetSeconds)) {
              _stagedMotion = const _StagedMotion.idle();
              engine.value = sim.x(offsetSeconds).clamp(lowerBound, upperBound);
              onNotifyStatusListeners(
                isRev ? AnimationStatus.dismissed : AnimationStatus.completed,
              );
            } else {
              final offsetSim = _TimeOffsetSimulation(sim, offsetSeconds);
              if (isRev) {
                engine.animateBackWith(offsetSim);
              } else {
                engine.animateWith(offsetSim);
              }
            }
          } else {
            engine.fling(
              velocity: _stagedMotion.flingVelocity,
              springDescription: _stagedMotion.springDescription,
              animationBehavior: _stagedMotion.animationBehavior,
            );
          }
        } else {
          engine.fling(
            velocity: _stagedMotion.flingVelocity,
            springDescription: _stagedMotion.springDescription,
            animationBehavior: _stagedMotion.animationBehavior,
          );
        }
        break;
      case _StagedMotionMode.simulation:
        if (_stagedMotion.simulation != null) {
          final sim = _stagedMotion.simulation!;
          final elapsed = _stagedMotion.elapsedDuration;
          if (elapsed != null && elapsed > Duration.zero) {
            final offsetSeconds =
                elapsed.inMicroseconds / Duration.microsecondsPerSecond;
            if (sim.isDone(offsetSeconds)) {
              _stagedMotion = const _StagedMotion.idle();
              engine.value = sim.x(offsetSeconds).clamp(lowerBound, upperBound);
              onNotifyStatusListeners(AnimationStatus.completed);
            } else {
              engine.animateWith(_TimeOffsetSimulation(sim, offsetSeconds));
            }
          } else {
            engine.animateWith(sim);
          }
        }
        break;
      case _StagedMotionMode.simulationBack:
        if (_stagedMotion.simulation != null) {
          final sim = _stagedMotion.simulation!;
          final elapsed = _stagedMotion.elapsedDuration;
          if (elapsed != null && elapsed > Duration.zero) {
            final offsetSeconds =
                elapsed.inMicroseconds / Duration.microsecondsPerSecond;
            if (sim.isDone(offsetSeconds)) {
              _stagedMotion = const _StagedMotion.idle();
              engine.value = sim.x(offsetSeconds).clamp(lowerBound, upperBound);
              onNotifyStatusListeners(AnimationStatus.dismissed);
            } else {
              engine.animateBackWith(_TimeOffsetSimulation(sim, offsetSeconds));
            }
          } else {
            engine.animateBackWith(sim);
          }
        }
        break;
      case _StagedMotionMode.idle:
        break;
    }
  }
}

base class _FrozenDormantControlDelegate
    extends _DormantAnimationControlDelegate {
  final bool frozen;
  final double? initialValue;
  final Duration? initialDuration;
  final Duration? initialReverseDuration;

  _FrozenDormantControlDelegate({
    required super.value,
    required super.duration,
    required super.reverseDuration,
    required super.lowerBound,
    required super.upperBound,
    required super.onNotifyListeners,
    required super.onNotifyStatusListeners,
    this.frozen = true,
    this.initialValue,
    this.initialDuration,
    this.initialReverseDuration,
    super.stagedMotion,
  });

  _ActiveAnimationControlDelegate activate(
    TickerProvider vsync, {
    required String? debugLabel,
    required AnimationBehavior animationBehavior,
  }) {
    final startValue = frozen ? _value : (initialValue ?? lowerBound);
    final startDuration = frozen ? _duration : initialDuration;
    final startReverseDuration =
        frozen ? _reverseDuration : initialReverseDuration;

    final engine = AnimationController(
      value: startValue,
      duration: startDuration,
      reverseDuration: startReverseDuration,
      debugLabel: debugLabel,
      lowerBound: lowerBound,
      upperBound: upperBound,
      animationBehavior: animationBehavior,
      vsync: vsync,
    );

    final activeDelegate = _ActiveAnimationControlDelegate(
      engine,
      vsync: vsync,
      onNotifyListeners: onNotifyListeners,
      onNotifyStatusListeners: onNotifyStatusListeners,
      initialMotion: isAnimating ? _stagedMotion : null,
    );

    if (isAnimating) {
      resumeMotion(engine, activeDelegate: activeDelegate);
    }

    return activeDelegate;
  }
}

typedef _MotionProjection = ({
  double value,
  AnimationStatus status,
  bool isDone,
  _StagedMotion stagedMotion,
});

/// A dormant state delegate for [_CatchUpAnimationController].
///
/// Calculates the wall-clock duration elapsed while dormant and advances its progress accordingly
/// before instantiating the active engine.
///
/// ### Comprehensive Kinematics & Wall-Clock Compensation:
/// When dormant, the host widget is not receiving frame ticks. Upon querying [value] or [activate],
/// the elapsed dormancy interval $\Delta t = \text{clock}() - t_{\text{deactivated}}$ is computed and
/// compensated according to the staged motion mode:
///
/// 1. **Linear Bounded Motion ([_StagedMotionMode.forward] / [_StagedMotionMode.reverse]):**
///    $$\Delta p = \frac{\Delta t}{T} \cdot (x_{\text{upper}} - x_{\text{lower}})$$
///    $$x_{\text{forward}} = \min(x_{\text{upper}}, x_0 + \Delta p)$$
///    $$x_{\text{reverse}} = \max(x_{\text{lower}}, x_0 - \Delta p)$$
///
/// 2. **Physics Simulations ([_StagedMotionMode.simulation] / [_StagedMotionMode.fling]):**
///    $$t_{\text{total}} = t_{\text{accumulated}} + \Delta t$$
///    $$x_{\text{sim}} = \text{clamp}(S.x(t_{\text{total}}), x_{\text{lower}}, x_{\text{upper}})$$
///    If $S.\text{isDone}(t_{\text{total}})$, the motion transitions to [AnimationStatus.completed].
///
/// 3. **Repeating Oscillations ([_StagedMotionMode.repeat]):**
///    * **Standard Looping Mode:**
///      $$\text{loops} = \frac{\Delta t}{T_{\text{period}}}, \quad \phi = (\text{loops} - \lfloor\text{loops}\rfloor) \cdot \Delta x$$
///      $$x_{\text{loop}} = x_{\text{min}} + ((x_0 - x_{\text{min}} + \phi) \pmod{\Delta x})$$
///    * **Ping-Pong Alternating Mode ($T_{\text{cycle}} = 2 T_{\text{period}}$):**
///      Evaluates phase in the bidirectional coordinate space $[0, 2\Delta x]$ and correctly tracks
///      whether the current flight is in forward or reverse phase.
base class _CatchUpDormantControlDelegate
    extends _DormantAnimationControlDelegate {
  final DateTime Function() clock;
  DateTime? deactivatedAt;

  _CatchUpDormantControlDelegate({
    required super.value,
    required super.duration,
    required super.reverseDuration,
    required super.lowerBound,
    required super.upperBound,
    required super.onNotifyListeners,
    required super.onNotifyStatusListeners,
    this.clock = DateTime.now,
    this.deactivatedAt,
    super.stagedMotion,
  });

  @override
  bool get isAnimating {
    if (super.isAnimating && deactivatedAt != null) {
      final elapsed = clock().difference(deactivatedAt!);
      if (elapsed > Duration.zero) {
        return !_projectMotion(elapsed).isDone;
      }
    }
    return super.isAnimating;
  }

  @override
  double get value {
    if (super.isAnimating && deactivatedAt != null) {
      final elapsed = clock().difference(deactivatedAt!);
      if (elapsed > Duration.zero) {
        return _projectMotion(elapsed).value;
      }
    }
    return _value;
  }

  @override
  AnimationStatus get status {
    if (super.isAnimating && deactivatedAt != null) {
      final elapsed = clock().difference(deactivatedAt!);
      if (elapsed > Duration.zero) {
        return _projectMotion(elapsed).status;
      }
    }
    return super.status;
  }

  _MotionProjection _projectMotion(Duration elapsed) {
    final elapsedMicros = elapsed.inMicroseconds;
    if (elapsedMicros <= 0) {
      return (
        value: _value,
        status: super.status,
        isDone: false,
        stagedMotion: _stagedMotion,
      );
    }

    final range = upperBound - lowerBound;

    switch (_stagedMotion.mode) {
      case _StagedMotionMode.forward:
        final totalMicros = _duration?.inMicroseconds ?? 0;
        if (totalMicros > 0 && range.isFinite) {
          final deltaProgress = (elapsedMicros / totalMicros) * range;
          final newVal = math.min(upperBound, _value + deltaProgress);
          final isDone = newVal >= upperBound;
          return (
            value: newVal,
            status:
                isDone ? AnimationStatus.completed : AnimationStatus.forward,
            isDone: isDone,
            stagedMotion: isDone ? const _StagedMotion.idle() : _stagedMotion,
          );
        }
        return (
          value: _value,
          status: AnimationStatus.forward,
          isDone: false,
          stagedMotion: _stagedMotion,
        );

      case _StagedMotionMode.reverse:
        final totalMicros =
            (_reverseDuration ?? _duration)?.inMicroseconds ?? 0;
        if (totalMicros > 0 && range.isFinite) {
          final deltaProgress = (elapsedMicros / totalMicros) * range;
          final newVal = math.max(lowerBound, _value - deltaProgress);
          final isDone = newVal <= lowerBound;
          return (
            value: newVal,
            status:
                isDone ? AnimationStatus.dismissed : AnimationStatus.reverse,
            isDone: isDone,
            stagedMotion: isDone ? const _StagedMotion.idle() : _stagedMotion,
          );
        }
        return (
          value: _value,
          status: AnimationStatus.reverse,
          isDone: false,
          stagedMotion: _stagedMotion,
        );

      case _StagedMotionMode.simulation:
        if (_stagedMotion.simulation != null) {
          final sim = _stagedMotion.simulation!;
          final prevElapsed = _stagedMotion.elapsedDuration ?? Duration.zero;
          final totalElapsed = prevElapsed + elapsed;
          final totalSeconds =
              totalElapsed.inMicroseconds / Duration.microsecondsPerSecond;
          final isDone = sim.isDone(totalSeconds);
          final newVal = sim.x(totalSeconds).clamp(lowerBound, upperBound);
          return (
            value: newVal,
            status:
                isDone ? AnimationStatus.completed : AnimationStatus.forward,
            isDone: isDone,
            stagedMotion: isDone
                ? const _StagedMotion.idle()
                : _stagedMotion.copyWith(elapsedDuration: totalElapsed),
          );
        } else {
          final totalMicros = _duration?.inMicroseconds ?? 0;
          if (totalMicros > 0 && range.isFinite) {
            final deltaProgress = (elapsedMicros / totalMicros) * range;
            final newVal = math.min(upperBound, _value + deltaProgress);
            final isDone = newVal >= upperBound;
            return (
              value: newVal,
              status:
                  isDone ? AnimationStatus.completed : AnimationStatus.forward,
              isDone: isDone,
              stagedMotion: isDone ? const _StagedMotion.idle() : _stagedMotion,
            );
          }
        }
        return (
          value: _value,
          status: AnimationStatus.forward,
          isDone: false,
          stagedMotion: _stagedMotion,
        );

      case _StagedMotionMode.simulationBack:
        if (_stagedMotion.simulation != null) {
          final sim = _stagedMotion.simulation!;
          final prevElapsed = _stagedMotion.elapsedDuration ?? Duration.zero;
          final totalElapsed = prevElapsed + elapsed;
          final totalSeconds =
              totalElapsed.inMicroseconds / Duration.microsecondsPerSecond;
          final isDone = sim.isDone(totalSeconds);
          final newVal = sim.x(totalSeconds).clamp(lowerBound, upperBound);
          return (
            value: newVal,
            status:
                isDone ? AnimationStatus.dismissed : AnimationStatus.reverse,
            isDone: isDone,
            stagedMotion: isDone
                ? const _StagedMotion.idle()
                : _stagedMotion.copyWith(elapsedDuration: totalElapsed),
          );
        } else {
          final totalMicros =
              (_reverseDuration ?? _duration)?.inMicroseconds ?? 0;
          if (totalMicros > 0 && range.isFinite) {
            final deltaProgress = (elapsedMicros / totalMicros) * range;
            final newVal = math.max(lowerBound, _value - deltaProgress);
            final isDone = newVal <= lowerBound;
            return (
              value: newVal,
              status:
                  isDone ? AnimationStatus.dismissed : AnimationStatus.reverse,
              isDone: isDone,
              stagedMotion: isDone ? const _StagedMotion.idle() : _stagedMotion,
            );
          }
        }
        return (
          value: _value,
          status: AnimationStatus.reverse,
          isDone: false,
          stagedMotion: _stagedMotion,
        );

      case _StagedMotionMode.fling:
        final isRev = _stagedMotion.wasReversePhase;
        if (_stagedMotion.simulation != null) {
          final sim = _stagedMotion.simulation!;
          final prevElapsed = _stagedMotion.elapsedDuration ?? Duration.zero;
          final totalElapsed = prevElapsed + elapsed;
          final totalSeconds =
              totalElapsed.inMicroseconds / Duration.microsecondsPerSecond;
          final isDone = sim.isDone(totalSeconds);
          final newVal = sim.x(totalSeconds).clamp(lowerBound, upperBound);
          return (
            value: newVal,
            status: isDone
                ? (isRev
                    ? AnimationStatus.dismissed
                    : AnimationStatus.completed)
                : (isRev ? AnimationStatus.reverse : AnimationStatus.forward),
            isDone: isDone,
            stagedMotion: isDone
                ? const _StagedMotion.idle()
                : _stagedMotion.copyWith(elapsedDuration: totalElapsed),
          );
        } else if (isRev) {
          final totalMicros =
              (_reverseDuration ?? _duration)?.inMicroseconds ?? 0;
          if (totalMicros > 0 && range.isFinite) {
            final deltaProgress = (elapsedMicros / totalMicros) * range;
            final newVal = math.max(lowerBound, _value - deltaProgress);
            final isDone = newVal <= lowerBound;
            return (
              value: newVal,
              status:
                  isDone ? AnimationStatus.dismissed : AnimationStatus.reverse,
              isDone: isDone,
              stagedMotion: isDone ? const _StagedMotion.idle() : _stagedMotion,
            );
          }
          return (
            value: _value,
            status: AnimationStatus.reverse,
            isDone: false,
            stagedMotion: _stagedMotion,
          );
        } else {
          final totalMicros = _duration?.inMicroseconds ?? 0;
          if (totalMicros > 0 && range.isFinite) {
            final deltaProgress = (elapsedMicros / totalMicros) * range;
            final newVal = math.min(upperBound, _value + deltaProgress);
            final isDone = newVal >= upperBound;
            return (
              value: newVal,
              status:
                  isDone ? AnimationStatus.completed : AnimationStatus.forward,
              isDone: isDone,
              stagedMotion: isDone ? const _StagedMotion.idle() : _stagedMotion,
            );
          }
          return (
            value: _value,
            status: AnimationStatus.forward,
            isDone: false,
            stagedMotion: _stagedMotion,
          );
        }

      case _StagedMotionMode.repeat:
        final min =
            _stagedMotion.repeatMin ?? (lowerBound.isFinite ? lowerBound : 0.0);
        final max =
            _stagedMotion.repeatMax ?? (upperBound.isFinite ? upperBound : 1.0);
        final loopRange = max - min;
        final period = _stagedMotion.repeatPeriod ?? _duration;
        final periodMicros = period?.inMicroseconds ?? 0;
        if (loopRange > 0.0 && periodMicros > 0) {
          final prevElapsed = _stagedMotion.elapsedDuration ?? Duration.zero;
          final totalElapsed = prevElapsed + elapsed;
          final totalElapsedMicros = totalElapsed.inMicroseconds;
          final totalLoops = totalElapsedMicros / periodMicros;

          if (_stagedMotion.repeatCount != null &&
              totalLoops >= _stagedMotion.repeatCount!) {
            final repeatReverse = _stagedMotion.repeatReverse;
            final repeatCount = _stagedMotion.repeatCount!;
            final finalVal =
                !repeatReverse ? max : ((repeatCount % 2 == 1) ? max : min);
            final finalStatus = !repeatReverse
                ? AnimationStatus.completed
                : ((repeatCount % 2 == 1)
                    ? AnimationStatus.completed
                    : AnimationStatus.dismissed);
            return (
              value: finalVal,
              status: finalStatus,
              isDone: true,
              stagedMotion: const _StagedMotion.idle(),
            );
          }

          final loops = elapsedMicros / periodMicros;
          if (!_stagedMotion.repeatReverse) {
            final offset = (loops - loops.floor()) * loopRange;
            final currentOffset = (_value - min).clamp(0.0, loopRange);
            final newVal = min + ((currentOffset + offset) % loopRange);
            return (
              value: newVal,
              status: AnimationStatus.forward,
              isDone: false,
              stagedMotion: _stagedMotion.copyWith(
                elapsedDuration: totalElapsed,
              ),
            );
          } else {
            // Ping-pong repeat (cycle = 2 * period)
            final cycleMicros = 2 * periodMicros;
            final totalElapsedCycleMicros = elapsedMicros % cycleMicros;
            final currentOffset = (_value - min).clamp(0.0, loopRange);
            final currentPhase = _stagedMotion.wasReversePhase
                ? (2.0 * loopRange - currentOffset)
                : currentOffset;
            final newPhase = (currentPhase +
                    (totalElapsedCycleMicros / periodMicros) * loopRange) %
                (2.0 * loopRange);
            final isRevPhase = newPhase >= loopRange;
            final newVal =
                !isRevPhase ? (min + newPhase) : (max - (newPhase - loopRange));
            return (
              value: newVal,
              status: !isRevPhase
                  ? AnimationStatus.forward
                  : AnimationStatus.reverse,
              isDone: false,
              stagedMotion: _stagedMotion.copyWith(
                wasReversePhase: isRevPhase,
                elapsedDuration: totalElapsed,
              ),
            );
          }
        }
        return (
          value: _value,
          status: super.status,
          isDone: false,
          stagedMotion: _stagedMotion,
        );

      case _StagedMotionMode.animateTo:
        final target = _stagedMotion.targetValue ?? upperBound;
        final range = upperBound - lowerBound;
        final effectiveDuration = _stagedMotion.targetDuration ??
            (_duration != null
                ? (range.isFinite
                    ? _duration! * ((target - _value).abs() / range)
                    : _duration!)
                : const Duration(milliseconds: 300));
        final sim = _stagedMotion.simulation ??
            _CurvedInterpolationSimulation(
              begin: _stagedMotion.targetFromValue ?? _value,
              end: target,
              duration: effectiveDuration,
              curve: _stagedMotion.targetCurve,
            );
        final prevElapsed = _stagedMotion.elapsedDuration ?? Duration.zero;
        final totalElapsed = prevElapsed + elapsed;
        final totalSeconds =
            totalElapsed.inMicroseconds / Duration.microsecondsPerSecond;
        final isDone = sim.isDone(totalSeconds);
        return (
          value: isDone
              ? target
              : sim.x(totalSeconds).clamp(lowerBound, upperBound),
          status: isDone ? AnimationStatus.completed : AnimationStatus.forward,
          isDone: isDone,
          stagedMotion: isDone
              ? const _StagedMotion.idle()
              : _stagedMotion.copyWith(
                  simulation: sim, elapsedDuration: totalElapsed),
        );

      case _StagedMotionMode.animateBack:
        final target = _stagedMotion.targetValue ?? lowerBound;
        final effectiveDuration = _stagedMotion.targetDuration ??
            ((_reverseDuration ?? _duration) != null
                ? (range.isFinite
                    ? (_reverseDuration ?? _duration)! *
                        ((_value - target).abs() / range)
                    : (_reverseDuration ?? _duration)!)
                : const Duration(milliseconds: 300));
        final sim = _stagedMotion.simulation ??
            _CurvedInterpolationSimulation(
              begin: _stagedMotion.targetFromValue ?? _value,
              end: target,
              duration: effectiveDuration,
              curve: _stagedMotion.targetCurve,
            );
        final prevElapsed = _stagedMotion.elapsedDuration ?? Duration.zero;
        final totalElapsed = prevElapsed + elapsed;
        final totalSeconds =
            totalElapsed.inMicroseconds / Duration.microsecondsPerSecond;
        final isDone = sim.isDone(totalSeconds);
        return (
          value: isDone
              ? target
              : sim.x(totalSeconds).clamp(lowerBound, upperBound),
          status: isDone ? AnimationStatus.dismissed : AnimationStatus.reverse,
          isDone: isDone,
          stagedMotion: isDone
              ? const _StagedMotion.idle()
              : _stagedMotion.copyWith(
                  simulation: sim, elapsedDuration: totalElapsed),
        );

      case _StagedMotionMode.idle:
        return (
          value: _value,
          status: super.status,
          isDone: false,
          stagedMotion: _stagedMotion,
        );
    }
  }

  @override
  void _prepareStageMotion({required bool hasFrom}) {
    if (!hasFrom && isAnimating && deactivatedAt != null) {
      final elapsed = clock().difference(deactivatedAt!);
      if (elapsed > Duration.zero) {
        applyElapsedCompensation(elapsed);
      }
    }
    deactivatedAt = clock();
  }

  @override
  void _onMotionStaged() {
    deactivatedAt ??= clock();
  }

  @override
  void _onMotionCanceled() {
    deactivatedAt = null;
  }

  void applyElapsedCompensation(Duration elapsed) {
    if (elapsed <= Duration.zero) return;
    final projection = _projectMotion(elapsed);
    _value = projection.value;
    _stagedMotion = projection.stagedMotion;
    if (projection.isDone) {
      onNotifyStatusListeners(projection.status);
    }
  }

  _ActiveAnimationControlDelegate activate(
    TickerProvider vsync, {
    required String? debugLabel,
    required AnimationBehavior animationBehavior,
  }) {
    if (_stagedMotion.mode != _StagedMotionMode.idle && deactivatedAt != null) {
      final elapsed = clock().difference(deactivatedAt!);
      applyElapsedCompensation(elapsed);
      deactivatedAt = null;
    }

    final engine = AnimationController(
      value: _value,
      duration: _duration,
      reverseDuration: _reverseDuration,
      debugLabel: debugLabel,
      lowerBound: lowerBound,
      upperBound: upperBound,
      animationBehavior: animationBehavior,
      vsync: vsync,
    );

    final activeDelegate = _ActiveAnimationControlDelegate(
      engine,
      vsync: vsync,
      onNotifyListeners: onNotifyListeners,
      onNotifyStatusListeners: onNotifyStatusListeners,
      initialMotion: isAnimating ? _stagedMotion : null,
    );

    if (isAnimating) {
      resumeMotion(engine, activeDelegate: activeDelegate);
    }

    return activeDelegate;
  }
}

// =============================================================================
// Active Engine Delegate
// =============================================================================

base class _ActiveAnimationControlDelegate
    implements _AnimationControlDelegate {
  final AnimationController _engine;
  final VoidCallback _notifyListeners;
  final ValueChanged<AnimationStatus> _notifyStatusListeners;
  TickerProvider _vsync;
  bool _isDisposed = false;

  final _StagedMotion? _initialMotion;
  _StagedMotion _lastMotion = const _StagedMotion.idle();
  Duration _baseElapsedDuration = Duration.zero;
  AnimationStatus? _overrideStatus;

  _ActiveAnimationControlDelegate(
    this._engine, {
    required TickerProvider vsync,
    required VoidCallback onNotifyListeners,
    required ValueChanged<AnimationStatus> onNotifyStatusListeners,
    _StagedMotion? initialMotion,
  })  : _vsync = vsync,
        _notifyListeners = onNotifyListeners,
        _notifyStatusListeners = onNotifyStatusListeners,
        _initialMotion = initialMotion,
        _lastMotion = initialMotion ?? const _StagedMotion.idle(),
        _baseElapsedDuration = initialMotion?.elapsedDuration ?? Duration.zero {
    _engine.addListener(_handleEngineTick);
    _engine.addStatusListener(_handleStatusChanged);
  }

  Duration _lastKnownEngineElapsed = Duration.zero;

  void _handleEngineTick() {
    if (_engine.lastElapsedDuration != null) {
      _lastKnownEngineElapsed = _engine.lastElapsedDuration!;
    }
    _checkRepeatCompletion();
    _notifyListeners();
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (_overrideStatus != null) return;
    _notifyStatusListeners(status);
  }

  void _accumulateBaseElapsed(Duration elapsed) {
    _baseElapsedDuration += elapsed;
  }

  void _checkRepeatCompletion() {
    if (_lastMotion.mode == _StagedMotionMode.repeat &&
        _lastMotion.repeatCount != null) {
      final period = _lastMotion.repeatPeriod ?? _engine.duration;
      final periodMicros = period?.inMicroseconds ?? 0;
      if (periodMicros > 0) {
        final totalBudgetMicros = periodMicros * _lastMotion.repeatCount!;
        final engineElapsed =
            _engine.lastElapsedDuration ?? _lastKnownEngineElapsed;
        final totalElapsedMicros =
            _baseElapsedDuration.inMicroseconds + engineElapsed.inMicroseconds;

        if (totalElapsedMicros >= totalBudgetMicros) {
          final min = _lastMotion.repeatMin ?? _engine.lowerBound;
          final max = _lastMotion.repeatMax ?? _engine.upperBound;
          final repeatReverse = _lastMotion.repeatReverse;
          final repeatCount = _lastMotion.repeatCount!;
          final finalVal =
              !repeatReverse ? max : ((repeatCount % 2 == 1) ? max : min);
          final finalStatus = !repeatReverse
              ? AnimationStatus.completed
              : ((repeatCount % 2 == 1)
                  ? AnimationStatus.completed
                  : AnimationStatus.dismissed);

          _lastMotion = const _StagedMotion.idle();
          _baseElapsedDuration = Duration.zero;
          _overrideStatus = finalStatus;
          if (_engine.isAnimating) {
            _engine.stop();
          }
          _engine.value = finalVal;
          _notifyStatusListeners(finalStatus);
        }
      }
    }
  }

  _StagedMotion get stagedMotion {
    if (!_engine.isAnimating) {
      return const _StagedMotion.idle();
    }
    final isRev =
        _engine.status == AnimationStatus.reverse || _engine.velocity < 0.0;
    final engineElapsed = _engine.lastElapsedDuration ?? Duration.zero;

    // When the active motion is the continuation of an awakened motion,
    // accumulate the base elapsed time from before reactivation:
    final Duration totalElapsed;
    if (_lastMotion.mode == _StagedMotionMode.repeat ||
        (_initialMotion?.elapsedDuration != null &&
            _lastMotion.mode == _initialMotion?.mode &&
            _lastMotion.simulation == _initialMotion?.simulation)) {
      totalElapsed = _baseElapsedDuration + engineElapsed;
    } else {
      totalElapsed = engineElapsed;
    }

    if (_lastMotion.mode == _StagedMotionMode.idle) {
      return _StagedMotion(
        mode: isRev ? _StagedMotionMode.reverse : _StagedMotionMode.forward,
        wasReversePhase: isRev,
        elapsedDuration: totalElapsed,
      );
    }
    return _lastMotion.copyWith(
      wasReversePhase: isRev,
      elapsedDuration: totalElapsed,
    );
  }

  bool get isDisposed => _isDisposed;

  _StagedMotion get lastDispatchedMotion => _lastMotion;

  // ---------------------------------------------------------------------------
  // Getters & Setters
  // ---------------------------------------------------------------------------

  @override
  Animation<double>? get view => _engine.view;

  @override
  TickerProvider get vsync => _vsync;

  @override
  Duration? get duration => _engine.duration;

  @override
  set duration(Duration? newValue) => _engine.duration = newValue;

  @override
  Duration? get reverseDuration => _engine.reverseDuration;

  @override
  set reverseDuration(Duration? newValue) => _engine.reverseDuration = newValue;

  @override
  double get value => _engine.value;

  @override
  set value(double newValue) {
    _lastMotion = const _StagedMotion.idle();
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    _engine.value = newValue;
  }

  @override
  double get velocity => _engine.velocity;

  @override
  Duration? get lastElapsedDuration => _engine.lastElapsedDuration;

  @override
  bool get isAnimating => _engine.isAnimating;

  @override
  AnimationStatus get status => _overrideStatus ?? _engine.status;

  // ---------------------------------------------------------------------------
  // Lifecycle Management
  // ---------------------------------------------------------------------------

  @override
  void _handoverVsync(TickerProvider vsync) {
    _vsync = vsync;
    _engine.resync(vsync);
  }

  @override
  void reset() {
    _lastMotion = const _StagedMotion.idle();
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    _engine.reset();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _engine.removeListener(_handleEngineTick);
    _engine.removeStatusListener(_handleStatusChanged);
    _engine.dispose();
  }

  // ---------------------------------------------------------------------------
  // Driving Motion Directives
  // ---------------------------------------------------------------------------

  @override
  TickerFuture forward({double? from}) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    _lastMotion = const _StagedMotion(
      mode: _StagedMotionMode.forward,
      wasReversePhase: false,
    );
    return _engine.forward(from: from);
  }

  @override
  TickerFuture reverse({double? from}) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    _lastMotion = const _StagedMotion(
      mode: _StagedMotionMode.reverse,
      wasReversePhase: true,
    );
    return _engine.reverse(from: from);
  }

  @override
  TickerFuture toggle({double? from}) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    final forwardAim = !_engine.status.isForwardOrCompleted;
    _lastMotion = _StagedMotion(
      mode: forwardAim ? _StagedMotionMode.forward : _StagedMotionMode.reverse,
      wasReversePhase: !forwardAim,
    );
    return _engine.toggle(from: from);
  }

  @override
  TickerFuture animateTo(double target,
      {Duration? duration, Curve curve = Curves.linear}) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    final range = _engine.upperBound - _engine.lowerBound;
    final effectiveDuration = duration ??
        (_engine.duration != null
            ? (range.isFinite
                ? _engine.duration! * ((target - _engine.value).abs() / range)
                : _engine.duration!)
            : const Duration(milliseconds: 300));
    final sim = _CurvedInterpolationSimulation(
      begin: _engine.value,
      end: target,
      duration: effectiveDuration,
      curve: curve,
    );
    _lastMotion = _StagedMotion(
      mode: _StagedMotionMode.animateTo,
      targetFromValue: _engine.value,
      targetValue: target,
      targetDuration: effectiveDuration,
      targetCurve: curve,
      simulation: sim,
      wasReversePhase: false,
    );
    return _engine.animateWith(sim);
  }

  @override
  TickerFuture animateBack(double target,
      {Duration? duration, Curve curve = Curves.linear}) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    final range = _engine.upperBound - _engine.lowerBound;
    final effectiveDuration = duration ??
        ((_engine.reverseDuration ?? _engine.duration) != null
            ? (range.isFinite
                ? (_engine.reverseDuration ?? _engine.duration)! *
                    ((_engine.value - target).abs() / range)
                : (_engine.reverseDuration ?? _engine.duration)!)
            : const Duration(milliseconds: 300));
    final sim = _CurvedInterpolationSimulation(
      begin: _engine.value,
      end: target,
      duration: effectiveDuration,
      curve: curve,
    );
    _lastMotion = _StagedMotion(
      mode: _StagedMotionMode.animateBack,
      targetFromValue: _engine.value,
      targetValue: target,
      targetDuration: effectiveDuration,
      targetCurve: curve,
      simulation: sim,
      wasReversePhase: true,
    );
    return _engine.animateBackWith(sim);
  }

  @override
  TickerFuture repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  }) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    _lastMotion = _StagedMotion(
      mode: _StagedMotionMode.repeat,
      repeatMin: min,
      repeatMax: max,
      repeatReverse: reverse,
      repeatPeriod: period,
      repeatCount: count,
      wasReversePhase: false,
    );
    return _engine.repeat(
        min: min, max: max, reverse: reverse, period: period, count: count);
  }

  @override
  TickerFuture fling({
    double velocity = 1.0,
    SpringDescription? springDescription,
    AnimationBehavior? animationBehavior,
  }) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    final isRev = velocity < 0.0;
    final spring = springDescription ?? _kFlingSpringDescription;
    final target = isRev
        ? _engine.lowerBound - _kFlingTolerance.distance
        : _engine.upperBound + _kFlingTolerance.distance;
    final sim = SpringSimulation(spring, _engine.value, target, velocity)
      ..tolerance = _kFlingTolerance;
    _lastMotion = _StagedMotion(
      mode: _StagedMotionMode.fling,
      flingVelocity: velocity,
      springDescription: springDescription,
      animationBehavior: animationBehavior,
      simulation: sim,
      wasReversePhase: isRev,
    );
    return _engine.fling(
      velocity: velocity,
      springDescription: springDescription,
      animationBehavior: animationBehavior,
    );
  }

  @override
  TickerFuture animateWith(Simulation simulation) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    _lastMotion = _StagedMotion(
      mode: _StagedMotionMode.simulation,
      simulation: simulation,
      wasReversePhase: false,
    );
    return _engine.animateWith(simulation);
  }

  @override
  TickerFuture animateBackWith(Simulation simulation) {
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    _lastMotion = _StagedMotion(
      mode: _StagedMotionMode.simulationBack,
      simulation: simulation,
      wasReversePhase: true,
    );
    return _engine.animateBackWith(simulation);
  }

  @override
  void stop({bool canceled = true}) {
    _lastMotion = const _StagedMotion.idle();
    _baseElapsedDuration = Duration.zero;
    _overrideStatus = null;
    _engine.stop(canceled: canceled);
  }

  @override
  String toStringDetails() => _engine.toStringDetails();
}
