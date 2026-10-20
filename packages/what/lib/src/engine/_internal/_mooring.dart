// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Mooring Terminal & Intrusive Edge Infrastructure
// =============================================================================

/// Internal edge representation connecting a [_MooringTerminal] to a moored [_Node].
final class _MooringEdge implements _TargetEdge {
  _MooringEdge({required this.terminal, this.source});

  _Node? source;
  final _MooringTerminal terminal;

  // Intrusive links inside _MooringTerminal's active mooring list
  _MooringEdge? _prevMooring;
  _MooringEdge? _nextMooring;

  @override
  _DirtyListener get _target => terminal;

  @override
  _TargetEdge? _prevTarget;

  @override
  _TargetEdge? _nextTarget;
}

/// The nominal mooring terminal anchoring nodes to the reactive dock.
///
/// Unlike ordinary consumer terminals that pull data and trigger UI rebuilds,
/// [_MooringTerminal] is a tranquil harbor: it holds topological edges purely
/// to prevent upstream lifecycles from sinking into dormant deactivation.
///
/// **Non-Pulling Invariant:**
/// [_invalidate] is strictly a no-op. It never eagerly evaluates or pulls data.
///
/// Implements pure LPDAG pointer-based dormancy: strictly inactive when [_mooringHead]
/// is null, dynamically activating only when 1+ nodes are actively moored.
final class _MooringTerminal extends _Terminal {
  _MooringTerminal._();
  static final _MooringTerminal instance = _MooringTerminal._();

  // Pure LPDAG head pointer tracking currently moored nodes
  _MooringEdge? _mooringHead;

  @override
  void _invalidate() {
    // Tranquil harbor: strictly drops all invalidation ripples without pulling data.
  }

  /// Moors [node] to this terminal, anchoring it in an active state and dispatching a [_PeriodGraceHandle].
  _PeriodGraceHandle moor(covariant _Node node, Duration duration) {
    final wasEmpty = _mooringHead == null;

    final edge = _MooringEdge(terminal: this, source: node);

    // 1. Prepend to _mooringHead in O(1)
    edge._nextMooring = _mooringHead;
    edge._prevMooring = null;
    if (_mooringHead != null) {
      _mooringHead!._prevMooring = edge;
    }
    _mooringHead = edge;

    // 2. Dynamic activation on first moored node (null -> non-null)
    if (wasEmpty) {
      _activateOptimistically();
    }

    // Attach target edge to node (Mooring: anchors node in active state!)
    node._attachTargetEdgeOptimistically(edge);

    final handle = _PeriodGraceHandle(
      terminal: this,
      node: node,
      edge: edge,
      duration: duration,
    );
    handle._start();
    return handle;
  }

  /// Unmoors the edge in O(1).
  void unmoor(_MooringEdge edge) {
    _removeMooringEdge(edge);
    edge.source = null;

    // Dynamic deactivation back to dormant state when head becomes null
    if (_mooringHead == null) {
      _deactivateOptimistically();
    }
  }

  void _removeMooringEdge(_MooringEdge edge) {
    final prev = edge._prevMooring;
    final next = edge._nextMooring;
    if (prev != null) prev._nextMooring = next;
    if (next != null) next._prevMooring = prev;
    if (identical(_mooringHead, edge)) _mooringHead = next;
    edge._prevMooring = null;
    edge._nextMooring = null;
  }
}

/// Period grace handle anchoring the node to [_MooringTerminal] with a virtual target edge and timer.
final class _PeriodGraceHandle extends _GraceHandle {
  _PeriodGraceHandle({
    required this.terminal,
    required super.node,
    required this.edge,
    required this.duration,
  });

  final _MooringTerminal terminal;
  final _MooringEdge edge;
  Duration duration;
  Timer? _timer;

  void _start() {
    _timer = Timer(duration, _onExpired);
  }

  @override
  void cancel() {
    if (_isDischarged) return;
    _isDischarged = true;
    _timer?.cancel();
    _timer = null;
    node._detachTargetEdgeOptimistically(edge);
    terminal.unmoor(edge);
  }

  void _onExpired() {
    if (_isDischarged) return;
    _isDischarged = true;
    _timer = null;
    if (node case final _GracefulNodeMixin gracefulNode) {
      gracefulNode._graceHandle = null;
    }
    node._detachTargetEdgeOptimistically(edge);
    terminal.unmoor(edge);
  }
}
