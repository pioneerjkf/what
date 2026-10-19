// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Batch Scope
// =============================================================================

/// Internal scope manager for coalesced batch transactions.
abstract final class _BatchScope {
  static bool _batchLock = false;

  /// Whether a batch transaction scope is currently active.
  @pragma('vm:prefer-inline')
  static bool get isBatching => _batchLock;

  /// Executes [action] within a coalesced batch scope.
  @pragma('vm:prefer-inline')
  static R run<R>(R Function() action) {
    if (_batchLock) {
      return action();
    }
    _batchLock = true;
    try {
      return action();
    } finally {
      _batchLock = false;
      if (!_PushScope._drainLock) {
        _PushScope._drain();
      }
    }
  }
}
