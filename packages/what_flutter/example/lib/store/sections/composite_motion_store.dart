// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/composite_motion_section.dart';

/// Sub-store for Tier 4: Composite Motion & Multi-Tween Choreography
///
/// Demonstrates orchestrating a single master [DurableAnimationController]
/// across multiple staggered [CurvedAnimation] intervals, chained curves,
/// [TweenSequence] keyframes, and diverse multi-property tweens ([ColorTween],
/// [BorderRadiusTween], [Tween<Offset>], [Tween<double>]).
class CompositeMotionStore {
  CompositeMotionStore({DateTime Function()? clock})
      : _clock = clock,
        _policy = WhatController<DurabilityPolicy>(DurabilityPolicy.resume),
        _activeTab = WhatController<int>(0),
        _durationMs = WhatController<int>(2400),
        _isMounted = WhatController<bool>(true),
        _isPingPong = WhatController<bool>(true),
        _isPlaying = WhatController<bool>(true),
        _enableSlideElevation = WhatController<bool>(true),
        _enable3DRotation = WhatController<bool>(true),
        _enableBorderRadius = WhatController<bool>(true),
        _enableColorGradient = WhatController<bool>(true),
        _enableElasticBadge = WhatController<bool>(true),
        _enableStaggeredCascade = WhatController<bool>(true),
        _masterCtrl = WhatController<DurableAnimationController>(
          DurableAnimationController(
            policy: DurabilityPolicy.resume,
            duration: const Duration(milliseconds: 2400),
            clock: clock ?? DateTime.now,
          ),
        ) {
    _masterCtrl.data.repeat(reverse: true);
  }

  final DateTime Function()? _clock;
  final WhatController<DurabilityPolicy> _policy;

  /// Current timeline durability policy across dormant deactivations.
  What<DurabilityPolicy> get policy => _policy.what;

  /// Master timeline controller driving all sub-animations under a single VSYNC authority.
  final WhatController<DurableAnimationController> _masterCtrl;
  What<DurableAnimationController> get masterCtrl => _masterCtrl.what;

  DurableAnimationController get _ctrl => _masterCtrl.data;

  // View & Presentation State
  final WhatController<int> _activeTab;
  What<int> get activeTab => _activeTab.what;

  final WhatController<int> _durationMs;
  What<int> get durationMs => _durationMs.what;

  final WhatController<bool> _isMounted;
  What<bool> get isMounted => _isMounted.what;

  final WhatController<bool> _isPingPong;
  What<bool> get isPingPong => _isPingPong.what;

  final WhatController<bool> _isPlaying;
  What<bool> get isPlaying => _isPlaying.what;

  // Sub-Animation Isolation Toggles
  final WhatController<bool> _enableSlideElevation;
  What<bool> get enableSlideElevation => _enableSlideElevation.what;

  final WhatController<bool> _enable3DRotation;
  What<bool> get enable3DRotation => _enable3DRotation.what;

  final WhatController<bool> _enableBorderRadius;
  What<bool> get enableBorderRadius => _enableBorderRadius.what;

  final WhatController<bool> _enableColorGradient;
  What<bool> get enableColorGradient => _enableColorGradient.what;

  final WhatController<bool> _enableElasticBadge;
  What<bool> get enableElasticBadge => _enableElasticBadge.what;

  final WhatController<bool> _enableStaggeredCascade;
  What<bool> get enableStaggeredCascade => _enableStaggeredCascade.what;

  /// Passive reactive bridge observing the master controller's normalized progress (0.0 to 1.0),
  /// seamlessly hot-swapping whenever [masterCtrl] updates.
  late final What<double> masterProgress = switched(
    (via) {
      final ctrl = via(masterCtrl);
      return ctrl.observe();
    },
    eager: true,
  );

  /// Changes the durability policy and re-instantiates the controller fresh with clean resource disposal.
  void setPolicy(DurabilityPolicy newPolicy) {
    if (_policy.data == newPolicy) return;
    _policy.set(newPolicy);
    final prevCtrl = _masterCtrl.data;
    final prevValue = prevCtrl.value;
    final wasAnimating = prevCtrl.isAnimating;
    final shouldPlay = _isPlaying.data;

    prevCtrl.stop();
    final nextCtrl = DurableAnimationController(
      policy: newPolicy,
      duration: Duration(milliseconds: _durationMs.data),
      value: newPolicy == DurabilityPolicy.reset ? 0.0 : prevValue,
      clock: _clock ?? DateTime.now,
    );
    if (newPolicy == DurabilityPolicy.reset && prevValue > 0.0) {
      nextCtrl.value = prevValue;
    }

    if (wasAnimating || shouldPlay) {
      nextCtrl.repeat(reverse: _isPingPong.data);
      _isPlaying.set(true);
    } else {
      _isPlaying.set(false);
    }
    _masterCtrl.set(nextCtrl);
  }

  // Control Actions
  void setActiveTab(int tab) => _activeTab.set(tab);

  void toggleMount() => setMounted(!_isMounted.data);

  void setMounted(bool value) {
    if (_isMounted.data == value) return;
    _isMounted.set(value);
    if (value && _policy.data == DurabilityPolicy.reset && _isPlaying.data) {
      _ctrl.repeat(reverse: _isPingPong.data);
    }
  }

  void togglePlay() {
    if (_ctrl.isAnimating) {
      _ctrl.stop();
      _isPlaying.set(false);
    } else {
      if (_ctrl.value >= 1.0 && !_isPingPong.data) {
        playForward();
      } else {
        _ctrl.repeat(reverse: _isPingPong.data);
        _isPlaying.set(true);
      }
    }
  }

  void togglePingPong() {
    final next = !_isPingPong.data;
    _isPingPong.set(next);
    if (_ctrl.isAnimating) {
      _ctrl.repeat(reverse: next);
    }
  }

  void playForward() {
    _isPlaying.set(true);
    final future = _ctrl.forward(from: _ctrl.value >= 1.0 ? 0.0 : null);
    future.orCancel.then((_) {
      if (!_ctrl.isAnimating) {
        _isPlaying.set(false);
      }
    }, onError: (_) {});
  }

  void playReverse() {
    _isPlaying.set(true);
    final future = _ctrl.reverse(from: _ctrl.value <= 0.0 ? 1.0 : null);
    future.orCancel.then((_) {
      if (!_ctrl.isAnimating) {
        _isPlaying.set(false);
      }
    }, onError: (_) {});
  }

  void reset() {
    _ctrl.reset();
    _isPlaying.set(false);
  }

  void setDuration(int ms) {
    if (_durationMs.data == ms) return;
    _durationMs.set(ms);
    final wasAnimating = _ctrl.isAnimating;
    _ctrl.duration = Duration(milliseconds: ms);
    if (wasAnimating) {
      _ctrl.repeat(reverse: _isPingPong.data);
    }
  }

  // Toggle sub-features
  void toggleSlideElevation() =>
      _enableSlideElevation.set(!_enableSlideElevation.data);
  void toggle3DRotation() => _enable3DRotation.set(!_enable3DRotation.data);
  void toggleBorderRadius() =>
      _enableBorderRadius.set(!_enableBorderRadius.data);
  void toggleColorGradient() =>
      _enableColorGradient.set(!_enableColorGradient.data);
  void toggleElasticBadge() =>
      _enableElasticBadge.set(!_enableElasticBadge.data);
  void toggleStaggeredCascade() =>
      _enableStaggeredCascade.set(!_enableStaggeredCascade.data);

  ShowcaseSection get section => ShowcaseSection(
        id: '15_composite_motion',
        number: '15',
        title: 'Composite Motion & Multi-Tween Choreography',
        subtitle:
            'Single master controller orchestrating Intervals, Curves, and multi-property Tweens',
        badge: 'Multi-Tween',
        icon: Icons.auto_awesome_motion_rounded,
        codeSnippet: '''
// =============================================================================
// [Single Master Controller with Coordinated Sub-Animation Choreography]
// =============================================================================
final masterCtrl = DurableAnimationController(
  duration: const Duration(milliseconds: 2400),
  policy: DurabilityPolicy.resume,
)..repeat(reverse: true);

// Self-Vsync reactive composition: 1 VSYNC authority, 6 coordinated sub-motions
masterCtrl.animate((via, ctrl) {
  // 1. Staggered Slide & Elevation (0.00 ~ 0.35, easeOutBack)
  final slide = Tween<Offset>(
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: ctrl.view,
    curve: const Interval(0.00, 0.35, curve: Curves.easeOutBack),
  ));

  // 2. 3D Perspective Rotation & Tilt (0.15 ~ 0.55, easeInOutCubic)
  final tilt = Tween<double>(begin: -0.2, end: 0.0).animate(CurvedAnimation(
    parent: ctrl.view,
    curve: const Interval(0.15, 0.55, curve: Curves.easeInOutCubic),
  ));

  // 3. Shape & Corner Radius Morph (0.30 ~ 0.70, easeInOutBack)
  final radius = BorderRadiusTween(
    begin: BorderRadius.circular(40),
    end: BorderRadius.circular(14),
  ).animate(CurvedAnimation(
    parent: ctrl.view,
    curve: const Interval(0.30, 0.70, curve: Curves.easeInOutBack),
  ));

  // 4. Color Spectrum Interpolation (0.20 ~ 0.80, linear)
  final color = ColorTween(
    begin: const Color(0xFF6366F1), // Indigo
    end: const Color(0xFF06B6D4),   // Cyan
  ).animate(CurvedAnimation(
    parent: ctrl.view,
    curve: const Interval(0.20, 0.80, curve: Curves.linear),
  ));

  // 5. Elastic Emblem Scale & Pulse (0.45 ~ 0.80, elasticOut)
  final scale = Tween<double>(begin: 0.5, end: 1.15).animate(CurvedAnimation(
    parent: ctrl.view,
    curve: const Interval(0.45, 0.80, curve: Curves.elasticOut),
  ));

  // 6. Staggered Cascade Chips (3 micro-interval offsets)
  final chip1 = CurvedAnimation(
    parent: ctrl.view,
    curve: const Interval(0.55, 0.75, curve: Curves.easeOutCubic),
  );
  final chip2 = CurvedAnimation(
    parent: ctrl.view,
    curve: const Interval(0.68, 0.88, curve: Curves.easeOutCubic),
  );
  final chip3 = CurvedAnimation(
    parent: ctrl.view,
    curve: const Interval(0.80, 1.00, curve: Curves.easeOutCubic),
  );

  return Transform(
    transform: Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateY(tilt.value),
    child: SlideTransition(
      position: slide,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius.value,
          color: color.value,
        ),
        child: ScaleTransition(scale: scale, child: const EmblemWidget()),
      ),
    ),
  );
});''',
        highlights: const [
          'Single VSYNC Authority: 1 master DurableAnimationController drives multiple sub-animations with 0 extra Tickers.',
          'Interval-Based Staggering: Precise timeline slicing via Interval(begin, end, curve: ...) without frame drift.',
          'Multi-Property Tweens: Coordinated ColorTween, BorderRadiusTween, Tween<Offset>, and Tween<double> in lockstep.',
          'Chained Tweens & TweenSequence: Demonstrates Tween.chain(CurveTween) and multi-step weighted keyframes.',
          'Zero Rebuild Leaks: Frame-level 60/120fps motion isolated within ScopedAnimationController builder.',
        ],
        roadmapTree: '''
[Master DurableAnimationController Timeline (t = 0.0 ~ 1.0)]
 ├── [0.00 — 0.35] Staggered Slide & Elevation        [Tween<Offset> & easeOutBack]
 ├── [0.15 — 0.55] 3D Perspective Rotation & Tilt     [Tween<double> & easeInOutCubic]
 ├── [0.30 — 0.70] Shape & Corner Radius Morph        [BorderRadiusTween & easeInOutBack]
 ├── [0.20 — 0.80] Dual Gradient Color Spectrum       [ColorTween & linear]
 ├── [0.45 — 0.80] Elastic Emblem Scale & Pulse       [Tween<double> & elasticOut]
 └── [0.55 — 1.00] Staggered Cascade Chips            [3 Micro-Intervals & easeOutCubic]
      ├── [0.55 — 0.75] Chip 1: Metric Throughput
      ├── [0.68 — 0.88] Chip 2: Latency Benchmark
      └── [0.80 — 1.00] Chip 3: Zero-GC Guarantee
''',
        builder: () => const CompositeMotionSectionDemo(),
      );
}
