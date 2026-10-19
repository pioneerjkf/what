// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Internal Push Origin Hierarchy & Pushing Mixin
// =============================================================================

/// The foundational origin interface for nodes that initiate dirty pushes in the LPDAG.
///
/// Topologically serves as any origin point where state mutations or source transitions enter the graph:
/// `[PushOrigin] -> [Relay] -> [Terminal]`
abstract interface class _PushOrigin {
  abstract _PushOrigin? _nextPushOrigin;
  abstract bool _isPushQueued;

  void _propagateDirty();
  void _handleUncaughtError(Object error, StackTrace stackTrace);
}

/// A mixin providing intrusive linked-list pointers for [_PushOrigin] nodes in [_PushScope].
base mixin _PushOriginMixin on _Node implements _PushOrigin {
  @override
  _PushOrigin? _nextPushOrigin;

  @override
  bool _isPushQueued = false;
}
