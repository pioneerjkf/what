// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// ============================================================================
// Dynamic Cascade (Switched What)
// ============================================================================

/// Common functional selection mixin for dynamically switched implementations.
base mixin _SwitchedSelectionMixin<T> on _DeltaWhat<T> implements What<T> {
  WhatGuard Function(WhatVia via)? get _guard;
  What<T> Function(WhatVia via) get _select;

  @override
  bool get _isGuarded => _guard != null;

  @override
  What<T> _evaluateDelta(WhatVia via) {
    final guard = _guard;
    if (guard != null) {
      final decision = guard.call(via);
      if (!decision.isPass) {
        return What.empty(decision.reason);
      }
    }

    return _select(via);
  }
}

base class _LazySwitchedWhat<T> extends _LazyDeltaWhat<T> with _SwitchedSelectionMixin<T> {
  _LazySwitchedWhat({
    WhatGuard Function(WhatVia via)? guard,
    required What<T> Function(WhatVia via) select,
  })  : _guard = guard,
        _select = select;

  @override
  final WhatGuard Function(WhatVia via)? _guard;
  @override
  final What<T> Function(WhatVia via) _select;
}

base class _EagerSwitchedWhat<T> extends _EagerDeltaWhat<T> with _SwitchedSelectionMixin<T> {
  _EagerSwitchedWhat({
    WhatGuard Function(WhatVia via)? guard,
    required What<T> Function(WhatVia via) select,
  })  : _guard = guard,
        _select = select;

  @override
  final WhatGuard Function(WhatVia via)? _guard;
  @override
  final What<T> Function(WhatVia via) _select;
}
