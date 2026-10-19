// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Internal What Signal Node Implementation
// =============================================================================

final class _SignalEntry extends _RawEntry<int> implements WhatSignal {
  _SignalEntry() : super(0);
}

final class _LifecycleSignalEntry extends _LifecycleObservableRawEntry<int> implements WhatSignal {
  _LifecycleSignalEntry({
    super.onActivated,
    super.onDeactivated,
  }) : super(0);
}

WhatSignal _createSignalNode({
  void Function()? onActivated,
  void Function()? onDeactivated,
}) {
  if (onActivated == null && onDeactivated == null) {
    return _SignalEntry();
  }
  return _LifecycleSignalEntry(
    onActivated: onActivated,
    onDeactivated: onDeactivated,
  );
}

final class _WhatSignalControllerImpl implements WhatSignalController {
  _WhatSignalControllerImpl({
    void Function()? onActivated,
    void Function()? onDeactivated,
  }) : _target = _createSignalNode(
          onActivated: onActivated,
          onDeactivated: onDeactivated,
        );

  final WhatSignal _target;

  @override
  @pragma('vm:prefer-inline')
  WhatSignal get what => _target;

  @override
  @pragma('vm:prefer-inline')
  void emit() {
    final entry = _target as _RawEntry<int>;
    entry.set(entry.data + 1);
  }

  @override
  @pragma('vm:prefer-inline')
  bool get isActive => (_target as _Node).isActive;
}
