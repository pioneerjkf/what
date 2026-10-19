// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Interface for nodes or edges that can be inserted into a Target (downstream) subscriber list.
abstract interface class _TargetEdge {
  _TargetEdge? _prevTarget;

  _TargetEdge? _nextTarget;

  /// Returns the actual subscriber (target) node associated with this link.
  _DirtyListener get _target;
}

final class _Edge implements _TargetEdge {
  _Edge({required _Node source, required _DirtyListener target})
      : _source = source,
        _target = target,
        _pulledVersion = source._version;

  int _pulledVersion;

  int _seenEpoch = 0;

  final _Node _source;

  _Edge? _prevSource;

  _Edge? _nextSource;

  @override
  final _DirtyListener _target;

  @override
  _TargetEdge? _prevTarget;

  @override
  _TargetEdge? _nextTarget;
}

/// Mixin granting a [_DirtyListener] node lifecycle management for a single upstream [_Node] source.
base mixin _UnaryEdgeMixin<N extends _Node> on _Lifecycle implements _TargetEdge, _DirtyListener, _DirtySyncable {
  @override
  _TargetEdge? _prevTarget;

  @override
  _TargetEdge? _nextTarget;

  @override
  _DirtyListener get _target => this;

  /// Upstream source node.
  N get _source;

  int _pulledVersion = 0;

  @mustCallSuper
  @override
  void _activate() {
    _source._attachTargetEdgeOptimistically(this);
    super._activate();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    _pulledVersion = _source._version;
    super._deactivate();
    _source._detachTargetEdgeOptimistically(this);
  }

  /// Whether the upstream source has mutated since the last evaluation while in an inactive state.
  @override
  @pragma('vm:prefer-inline')
  bool get _isSourceDirty => _source._isNewerThan(_pulledVersion);

  @override
  @pragma('vm:prefer-inline')
  bool _resolveDirty() {
    _source._resolve();
    return _isSourceDirty;
  }

  /// Pulls and synchronizes [_pulledVersion] with the current upstream source version.
  @override
  @pragma('vm:prefer-inline')
  void _pullVersion() {
    _pulledVersion = _source._version;
  }
}

/// Mixin granting a [_DirtyListener] node ownership of an upstream (Source) edge list.
base mixin _NaryEdgeMixin<N extends _Node> on _Lifecycle implements _DirtyListener, _DirtySyncable {
  _Edge? _sourceHead;
  _Edge? _sourceTail;

  @mustCallSuper
  @override
  void _activate() {
    _attachSourceEdges();
    super._activate();
  }

  @mustCallSuper
  @override
  void _deactivate() {
    super._deactivate();
    _detachSourceEdges();
  }

  /// Whether any upstream source has mutated since the last evaluation while in an inactive state.
  @override
  @pragma('vm:prefer-inline')
  bool get _isSourceDirty {
    for (var curr = _sourceHead; curr != null; curr = curr._nextSource) {
      if (curr._source._isNewerThan(curr._pulledVersion)) {
        return true;
      }
    }
    return false;
  }

  @override
  @pragma('vm:prefer-inline')
  bool _resolveDirty() {
    for (var curr = _sourceHead; curr != null; curr = curr._nextSource) {
      curr._source._resolve();
    }
    return _isSourceDirty;
  }

  /// Pulls and synchronizes all upstream edge versions with their current source versions.
  @override
  @pragma('vm:prefer-inline')
  void _pullVersion() {
    for (var curr = _sourceHead; curr != null; curr = curr._nextSource) {
      curr._pulledVersion = curr._source._version;
    }
  }

  /// Finds an existing [_Edge] on [source]'s target list that points to this target.
  @pragma('vm:prefer-inline')
  _Edge? _findTargetEdge(_Node source) {
    final targetHead = source._targetHead;
    if (targetHead == null) return null;

    // Fast-path: Check the head target first (optimal for 1:1 bindings or recently prepended targets).
    if (identical(targetHead._target, this)) {
      return targetHead as _Edge;
    }

    // Traverse the remaining target edges in the list to find the matching edge.
    for (var curr = targetHead._nextTarget; curr != null; curr = curr._nextTarget) {
      if (identical(curr._target, this)) {
        return curr as _Edge;
      }
    }
    return null;
  }

  /// Finds an existing [_Edge] on this node's upstream source list that connects to [source].
  @pragma('vm:prefer-inline')
  _Edge? _findSourceEdge(_Node source) {
    for (var curr = _sourceHead; curr != null; curr = curr._nextSource) {
      if (identical(curr._source, source)) {
        return curr;
      }
    }
    return null;
  }

  /// Attaches all existing source edges to their respective upstream sources.
  @pragma('vm:prefer-inline')
  void _attachSourceEdges() {
    for (var curr = _sourceHead; curr != null; curr = curr._nextSource) {
      final existingEdge = _findTargetEdge(curr._source);
      if (existingEdge != null && !identical(existingEdge, curr)) {
        continue;
      }
      _attachSourceEdge(curr);
    }
  }

  /// Detaches all existing source edges from their respective upstream sources,
  /// preserving the edge links in [_sourceHead] for future re-activation without reallocations.
  @pragma('vm:prefer-inline')
  void _detachSourceEdges() {
    for (var curr = _sourceHead; curr != null; curr = curr._nextSource) {
      _detachSourceEdge(curr);
    }
  }

  /// Creates and links [_Edge]s for all [sources] to the upstream source list.
  @pragma('vm:prefer-inline')
  void _addSourceEdges(List<N> sources) {
    final length = sources.length;
    for (var i = 0; i < length; i++) {
      _addSourceEdge(sources[i]);
    }
  }

  /// Creates and links an [_Edge] for [source] to the upstream source list.
  @pragma('vm:prefer-inline')
  _Edge _addSourceEdge(_Node source) {
    final edge = _Edge(source: source, target: this);
    edge._prevSource = _sourceTail;
    edge._nextSource = null;
    if (_sourceTail != null) {
      _sourceTail!._nextSource = edge;
    } else {
      _sourceHead = edge;
    }
    _sourceTail = edge;
    return edge;
  }

  /// Attaches an upstream source [_Edge] to its source.
  @pragma('vm:prefer-inline')
  void _attachSourceEdge(_Edge edge) {
    edge._source._attachTargetEdgeOptimistically(edge);
  }

  /// Creates, links, and attaches an [_Edge] for [source] to the upstream source list.
  @pragma('vm:prefer-inline')
  _Edge _addAndAttachSourceEdge(_Node source) {
    final edge = _addSourceEdge(source);
    _attachSourceEdge(edge);
    return edge;
  }

  /// Unlinks an [_Edge] from the upstream source list.
  @pragma('vm:prefer-inline')
  void _removeSourceEdge(_Edge edge) {
    final prev = edge._prevSource;
    final next = edge._nextSource;

    if (prev != null) {
      prev._nextSource = next;
    }
    if (next != null) {
      next._prevSource = prev;
    }

    if (identical(edge, _sourceHead)) {
      _sourceHead = next;
    }
    if (identical(edge, _sourceTail)) {
      _sourceTail = prev;
    }

    edge._prevSource = null;
    edge._nextSource = null;
  }

  /// Detaches an upstream source [_Edge] from its source.
  @pragma('vm:prefer-inline')
  void _detachSourceEdge(_Edge edge) {
    edge._pulledVersion = edge._source._version;
    edge._source._detachTargetEdgeOptimistically(edge);
  }

  /// Detaches an upstream source [_Edge] from its source and unlinks it.
  @pragma('vm:prefer-inline')
  void _detachAndRemoveSourceEdge(_Edge edge) {
    _detachSourceEdge(edge);
    _removeSourceEdge(edge);
  }
}
