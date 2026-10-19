// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Internal WhatGuard Concrete Implementations
// =============================================================================

final class _PassWhatGuard extends WhatGuard {
  const _PassWhatGuard() : super._();

  @override
  bool get isPass => true;

  @override
  Object? get reason => null;

  @override
  String toString() => 'WhatGuard.pass';
}

final class _BlockWhatGuard extends WhatGuard {
  const _BlockWhatGuard([this.reason = 'PrerequisiteNotMet']) : super._();

  @override
  bool get isPass => false;

  @override
  final Object reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _BlockWhatGuard && other.reason == reason) || other == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'WhatGuard.block($reason)';
}
