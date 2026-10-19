// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Concrete implementation of [EffectRunner] operating as an intrusive edge terminal.
final class _EffectRunnerImpl extends _Terminal with _UnaryEdgeMixin<Effect> implements EffectRunner {
  _EffectRunnerImpl(
    Effect effect, {
    bool autoStart = true,
  }) : super() {
    _source = effect;
    _pulledVersion = effect._version;
    if (autoStart) {
      activate();
    }
  }

  @override
  late final Effect _source;

  @override
  Effect get effect => _source;

  @override
  bool get isActive => _lifecycle.isActive && _source._terminal.isActive;

  @override
  @pragma('vm:prefer-inline')
  void _invalidate() {
    // EffectRunner is a terminal edge holder. No downstream dirty propagation required.
  }
}
