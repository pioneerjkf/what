// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../../framework.dart';

// =============================================================================
// Physics & Curved Motion Simulations
// =============================================================================

/// A mathematical simulation representing an interpolated curved motion between [begin] and [end]
/// over [duration] using an easing [curve].
///
/// ### Mathematical Kinematics Formulation:
/// 1. **Normalized Time Parameter ($t_{\text{norm}}$):**
///    $$\tau = \text{clamp}\left(\frac{t}{T}, 0.0, 1.0\right)$$
///    where $T = \text{duration in seconds} = \frac{\text{duration.inMicroseconds}}{1\,000\,000.0}$.
///
/// 2. **Position Equation ($x(t)$):**
///    $$x(t) = x_{\text{begin}} + (x_{\text{end}} - x_{\text{begin}}) \cdot C(\tau)$$
///    where $C(\tau) : [0, 1] \to \mathbb{R}$ represents the easing transform function [Curve.transform].
///
/// 3. **Instantaneous Velocity via Numerical Central Finite Difference ($\dot{x}(t)$):**
///    $$\dot{x}(t) = \frac{d x}{d t} = (x_{\text{end}} - x_{\text{begin}}) \cdot \frac{C(\tau + \epsilon) - C(\tau - \epsilon)}{2 \epsilon \cdot T}$$
///    where $\epsilon = 0.001$ is the finite differentiation perturbation constant.
///
/// 4. **Termination Predicate ($\text{isDone}(t)$):**
///    $$\text{isDone}(t) \iff T \le 0.0 \;\lor\; t \ge T$$
final class _CurvedInterpolationSimulation extends Simulation {
  final double begin;
  final double end;
  final Duration duration;
  final Curve curve;
  final double _durationSeconds;

  _CurvedInterpolationSimulation({
    required this.begin,
    required this.end,
    required this.duration,
    this.curve = Curves.linear,
  }) : _durationSeconds = duration.inMicroseconds / 1000000.0;

  @override
  double x(double time) {
    if (_durationSeconds <= 0.0) return end;
    final t = (time / _durationSeconds).clamp(0.0, 1.0);
    if (t <= 0.0) return begin;
    if (t >= 1.0) return end;
    return begin + (end - begin) * curve.transform(t);
  }

  @override
  double dx(double time) {
    if (_durationSeconds <= 0.0) return 0.0;
    final t = (time / _durationSeconds).clamp(0.0, 1.0);
    const delta = 0.001;
    final p1 = curve.transform((t - delta).clamp(0.0, 1.0));
    final p2 = curve.transform((t + delta).clamp(0.0, 1.0));
    return (end - begin) * (p2 - p1) / (2 * delta * _durationSeconds);
  }

  @override
  bool isDone(double time) =>
      _durationSeconds <= 0.0 || time >= _durationSeconds;
}

/// A physics simulation wrapper that shifts the evaluation time domain by [_offsetSeconds].
///
/// ### Physics State Preservation & Coordinate Translation:
/// When a controller running a [Simulation] (such as [SpringSimulation], [GravitySimulation],
/// or [FrictionSimulation]) is detached, unmounted, or suspended in dormancy, its accumulated
/// run time $t_0 = \text{lastElapsedDuration}$ is preserved.
///
/// Upon waking with a new [TickerProvider], this wrapper transforms the incoming ticker
/// time $t \ge 0$ into the original simulation's continuous timeline:
/// $$t' = t + t_{\text{offset}}$$
///
/// 1. **Position Preservation ($x'(t)$):**
///    $$x'(t) = S.x(t + t_{\text{offset}})$$
///
/// 2. **Velocity & Phase Continuity ($\dot{x}'(t)$):**
///    $$\dot{x}'(t) = S.\dot{x}(t + t_{\text{offset}})$$
///
/// 3. **Termination ($\text{isDone}'(t)$):**
///    $$\text{isDone}'(t) = S.\text{isDone}(t + t_{\text{offset}})$$
///
/// This formulation guarantees $C^1$ continuity (continuous position and velocity) across
/// lifecycle boundaries without resetting to $t = 0.0$ or triggering `TickerCanceled` exceptions.
final class _TimeOffsetSimulation extends Simulation {
  final Simulation _simulation;
  final double _offsetSeconds;

  _TimeOffsetSimulation(this._simulation, this._offsetSeconds)
      : super(tolerance: _simulation.tolerance);

  @override
  double x(double time) => _simulation.x(time + _offsetSeconds);

  @override
  double dx(double time) => _simulation.dx(time + _offsetSeconds);

  @override
  bool isDone(double time) => _simulation.isDone(time + _offsetSeconds);
}
