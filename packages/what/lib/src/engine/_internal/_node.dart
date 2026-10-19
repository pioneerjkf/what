// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Internal Topological LPDAG Node Core
// =============================================================================

/// The foundational abstract base class for all reactive nodes participating in the
/// **LPDAG (Lazy Pull Directed Acyclic Graph)** topology.
///
/// [_Node] serves as the internal common root for all reactive state carriers ([What])
/// and internal lifecycle anchors.
///
/// ## Architecture: Separating State Carriers from Pipelines
/// What establishes a strict architectural boundary between topological LPDAG state carriers and
/// execution pipeline controllers:
///
/// * **Topological State Carriers ([_Node], [What])**:
///   These are the actual nodes within the directed acyclic graph (DAG). They hold snapshots,
///   maintain edge connections, manage reactive lifecycles, and propagate dirty invalidation pulses.
///
/// * **Pipeline Controllers & Terminals ([RawTerminal], [RawWhatTerminal], [RawViaTerminal])**:
///   These represent external mutation entry points, consumer subscription boundaries, and
///   dynamic pipeline couplers that interact with the graph from outside.
///
/// ## System Architectural Flow
/// ```text
/// [Upstream _Node]
///        │
///        ├─► _attachTargetEdgeOptimistically (Downstream subscriber attached)
///        │         │
///        │         └─► 0 -> 1 Subscribers: _activateOptimistically()
///        │
///        ├─► _propagateDirty() (State mutated: push dirty pulse downstream)
///        │
///        └─► _detachTargetEdgeOptimistically (Downstream subscriber detached)
///                  │
///                  └─► 1 -> 0 Subscribers: _deactivateOptimistically()
/// ```
///
/// ## Lifecycle & Resource Management
/// A [_Node] automatically tracks its downstream subscriber count using an intrusive
/// linked list (`_targetHead`). When the first subscriber attaches, the node activates lazily.
/// When the last subscriber detaches, it deactivates and enters a dormant state to prevent memory leaks.
sealed class _Node extends _Lifecycle implements LpdagStatus {
  int _version = 0;

  /// Whether this node has mutated since the given [version].
  @pragma('vm:prefer-inline')
  bool _isNewerThan(int version) => _version != version;

  /// Resolves any pending lazy computations or branch couplings for this node.
  ///
  /// Defaults to a no-op for leaf or terminal nodes with no upstream dependencies.
  @pragma('vm:prefer-inline')
  void _resolve() {}

  _TargetEdge? _targetHead;
  _TargetEdge? _propagatingTarget;

  /// Returns whether this node has any active downstream subscribers.
  bool get _hasTargets => _targetHead != null;

  /// Attaches a target edge to this parent node.
  @mustCallSuper
  @pragma('vm:prefer-inline')
  void _attachTargetEdgeOptimistically(_TargetEdge target) {
    assert(
      identical(_targetHead, target) || (target._prevTarget == null && target._nextTarget == null),
      'Attempted to attach a target edge that is already linked to a target list.',
    );

    if (identical(_targetHead, target)) return;

    target._nextTarget = _targetHead;
    target._prevTarget = null;

    if (_targetHead != null) {
      _targetHead!._prevTarget = target;
    }
    _targetHead = target;

    if (!_lifecycle.isActive) {
      _activateOptimistically();
    }
  }

  /// Detaches a target edge from this parent node.
  @mustCallSuper
  @pragma('vm:prefer-inline')
  void _detachTargetEdgeOptimistically(_TargetEdge target) {
    if (_targetHead == null) return;
    if (!identical(_targetHead, target) && target._prevTarget == null) {
      return;
    }

    if (identical(_propagatingTarget, target)) {
      _propagatingTarget = target._nextTarget;
    }

    final prev = target._prevTarget;
    final next = target._nextTarget;

    if (prev != null) {
      prev._nextTarget = next;
    }
    if (next != null) {
      next._prevTarget = prev;
    }

    if (identical(target, _targetHead)) {
      _targetHead = next;
    }

    target._prevTarget = null;
    target._nextTarget = null;

    // Topological Lifecycle Deactivation: 0 subscribers remain
    if (!_hasTargets && _lifecycle.isActive) {
      _deactivateOptimistically();
    }
  }

  /// Propagates dirty signal downstream to all active target subscribers.
  @pragma('vm:prefer-inline')
  void _propagateDirty() {
    final prevPropagating = _propagatingTarget;
    _propagatingTarget = _targetHead;
    try {
      while (_propagatingTarget != null) {
        final curr = _propagatingTarget!;
        _propagatingTarget = curr._nextTarget;
        try {
          curr._target._invalidate();
        } catch (error, stackTrace) {
          curr._target._handleUncaughtError(error, stackTrace);
        }
      }
    } finally {
      _propagatingTarget = prevPropagating;
    }
  }

  @override
  void _handleUncaughtError(Object error, StackTrace stackTrace) {
    final terminals = <_Terminal>{};
    _collectDownstreamTerminals(terminals);

    if (terminals.isEmpty) {
      _dispatchUncaughtError(error, stackTrace, context: this);
      return;
    }

    for (final terminal in terminals) {
      try {
        terminal._handleUncaughtError(error, stackTrace);
      } catch (fatalError, fatalStack) {
        _dispatchUncaughtError(error, stackTrace, context: this);
        _dispatchUncaughtError(fatalError, fatalStack, context: this);
      }
    }
  }

  /// Traverses downstream targets to collect unique active [_Terminal] instances.
  void _collectDownstreamTerminals(Set<_Terminal> terminals) {
    final visitedNodes = <_Node>{this};
    final stack = <_Node>[this];

    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      for (var curr = node._targetHead; curr != null; curr = curr._nextTarget) {
        switch (curr._target) {
          case final _Terminal terminal:
            terminals.add(terminal);
          case final _Node childNode:
            if (visitedNodes.add(childNode)) {
              stack.add(childNode);
            }
        }
      }
    }
  }

  /// Recursively walks up the topological DAG to invalidate intermediate caches
  /// and bump entry dirty versions during hot-reload reassembly.
  void _debugForceInvalidate(Set<_Node> visited) {
    if (!visited.add(this)) return;

    if (this case final _UnaryEdgeMixin unary) {
      unary._source._debugForceInvalidate(visited);
    } else if (this case final _NaryEdgeMixin nary) {
      for (var curr = nary._sourceHead; curr != null; curr = curr._nextSource) {
        curr._source._debugForceInvalidate(visited);
      }
    }

    if (this case final _DeltaWhat delta) {
      for (var curr = delta._deltaTerminal._sourceHead; curr != null; curr = curr._nextSource) {
        curr._source._debugForceInvalidate(visited);
      }
    }

    _debugInvalidateSelf();
  }

  /// Invalidates local intermediate caches or bumps entry dirty versions for this node.
  ///
  /// Subclasses and mixins override this method to perform node-specific cache clearance
  /// or dirty version increments during hot-reload reassembly.
  @mustCallSuper
  void _debugInvalidateSelf() {}
}
