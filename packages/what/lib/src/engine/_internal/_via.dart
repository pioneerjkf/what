// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Private implementation of [WhatVia] dedicated to a single [_WhatViaEpochMixin] node.
final class _WhatViaImpl implements WhatVia {
  _WhatViaImpl(this._node);

  final _WhatViaEpochMixin _node;

  @override
  @pragma('vm:prefer-inline')
  T call<T>(What<T> what) {
    _node._trackDependency(what);
    final s = what._read();
    if (s is _ValidWhatState) {
      return s.data;
    }
    throw _ViaShortCircuit(s);
  }

  @override
  @pragma('vm:prefer-inline')
  WhatState<T> state<T>(What<T> what) {
    _node._trackDependency(what);
    return what as WhatState<T>;
  }

  @override
  @pragma('vm:prefer-inline')
  T tether<T extends Tether>(T tether) {
    _node._trackDependency(tether);
    return tether;
  }
}

/// Internal short-circuit sentinel thrown when [WhatVia.call] encounters
/// a non-data state (empty or error).
///
/// Implements [Error] to avoid being accidentally intercepted by standard
/// `on Exception catch` blocks in application logic.
final class _ViaShortCircuit implements Error {
  const _ViaShortCircuit(this.state);

  final _WhatState<Object?> state;

  @override
  StackTrace? get stackTrace => null;
}

/// Mixin that provides dynamic epoch-based explicit dependency tracking and 1-pass pruning
/// for n-ary nodes and terminals via [WhatVia].
base mixin _WhatViaEpochMixin on _NaryEdgeMixin<_Node> {
  int _epoch = 0;
  _Edge? _cursor;

  /// [WhatVia] instance passed into compute and build callbacks.
  late final WhatVia _via = _WhatViaImpl(this);

  /// Prepares dependency tracking for a new evaluation cycle, returning the new monotonic epoch.
  @pragma('vm:prefer-inline')
  int _beginEpoch() {
    _cursor = _sourceHead;
    return ++_epoch;
  }

  /// Concludes dependency tracking for [currentEpoch].
  ///
  /// If [succeeded] is true, runs a single [_sweepObsoleteEdges] pass that detaches edges from
  /// previous branches and, when [commitVersions] is true, commits the observed versions of
  /// retained edges in the same traversal.
  ///
  /// * Terminals pass `commitVersions: true` — nothing else commits their versions.
  /// * [_PullResolver] relays pass `commitVersions: false` — [_PullResolver._resolve] commits
  ///   right after `_pull()` (including the error path, since errors are cached states).
  ///
  /// If [succeeded] is false, edges and pulled versions are left untouched so terminals stay
  /// dirty and re-evaluate on the next upstream pulse.
  @pragma('vm:prefer-inline')
  void _endEpoch(int currentEpoch, {required bool succeeded, required bool commitVersions}) {
    _cursor = null;
    if (succeeded) {
      _sweepObsoleteEdges(currentEpoch, commitVersions: commitVersions);
    }
  }

  /// Records [source] as an upstream dependency for the current evaluation epoch.
  @pragma('vm:prefer-inline')
  void _trackDependency(_Node source) {
    // 1. Fast-path: Check expected cursor position (O(1) sequential match).
    final cursor = _cursor;
    if (cursor != null && identical(cursor._source, source)) {
      cursor._seenEpoch = _epoch;
      _cursor = cursor._nextSource;
      return;
    }

    _trackDependencySlow(source, _epoch, cursor);
  }

  /// Cold-path fallback for branch changes, shifted ordering, or new dependencies.
  /// Marked never-inline to preserve inlining budget and instruction-cache locality
  /// for the hot sequential fast-path in [_trackDependency].
  @pragma('vm:never-inline')
  void _trackDependencySlow(_Node source, int currentEpoch, _Edge? cursor) {
    final matchedEdge = _findSourceEdge(source);
    if (matchedEdge != null) {
      if (matchedEdge._seenEpoch != currentEpoch) {
        // Re-align edge order to match the evaluation sequence so future evaluations
        // recover the O(1) sequential fast-path.
        if (cursor != null) {
          _moveSourceEdgeBefore(matchedEdge, cursor);
        }
        matchedEdge._seenEpoch = currentEpoch;
      }
    } else {
      // New dependency: insert before cursor (or at tail if cursor is null)
      // to preserve evaluation sequence in the edge list.
      final newEdge = _lifecycle.isActive
          ? (cursor != null
              ? _addAndAttachSourceEdgeBefore(source, cursor)
              : _addAndAttachSourceEdge(source))
          : (cursor != null
              ? _addSourceEdgeBefore(source, cursor)
              : _addSourceEdge(source));
      newEdge._seenEpoch = currentEpoch;
    }
  }

  /// 1-Pass Sweep over the source list for [currentEpoch]:
  /// * Edges not observed in [currentEpoch] are detached and unlinked.
  /// * If [commitVersions], observed edges commit the current upstream version in the same pass.
  ///
  /// Versions are committed only after the evaluator has finished, because lazy upstreams bump
  /// their version while being read.
  @pragma('vm:prefer-inline')
  void _sweepObsoleteEdges(int currentEpoch, {required bool commitVersions}) {
    final isActive = _lifecycle.isActive;
    var curr = _sourceHead;
    while (curr != null) {
      final next = curr._nextSource;
      if (curr._seenEpoch != currentEpoch) {
        if (isActive) {
          _detachAndRemoveSourceEdge(curr);
        } else {
          _removeSourceEdge(curr);
        }
      } else if (commitVersions) {
        curr._pulledVersion = curr._source._version;
      }
      curr = next;
    }
  }
}
