// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

enum _DirtyState {
  clean,
  check,
  dirty;
}

base mixin _DirtyPusher on _Node {
  bool _isPushingDirty = false;

  @mustCallSuper
  @override
  @pragma('vm:prefer-inline')
  void _activate() {
    super._activate();
  }

  @mustCallSuper
  @pragma('vm:prefer-inline')
  void _markDirty() {
    if (!_lifecycle.isActive) {
      return;
    }
    _pushDirty();
  }

  @pragma('vm:prefer-inline')
  void _pushDirty() {
    if (_isPushingDirty) {
      throw LpdagReentrancyError(''
          'Reentrant call to _pushDirty detected. A dirty point cannot '
          'push again while it is currently in its push phase.');
    }

    try {
      _isPushingDirty = true;
      _propagateDirty();
    } finally {
      _isPushingDirty = false;
    }
  }
}

/// Hook for subclasses to perform actions (like clearing cache) when they become dirty.
abstract interface class _DirtyListener implements _ErrorSink {
  @pragma('vm:prefer-inline')
  void _invalidate();
}

/// Interface for nodes or mixins capable of tracking and synchronizing upstream source dirty states and versions.
abstract interface class _DirtySyncable {
  bool get _isSourceDirty;

  /// Pulls and synchronizes all upstream versions to this edge.
  void _pullVersion();

  /// Resolves upstream relay dependencies and returns whether any source is dirty.
  bool _resolveDirty();
}
