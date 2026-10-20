// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// LPDAG & What Reflector Implementations
// =============================================================================

_WhatState? _safeReadWhatState(Object? node) {
  if (node case final _ConstantWhat constant) {
    return constant._state;
  }
  if (node case final _Entry entry) {
    return entry._state;
  }
  if (node case final _PullResolver resolver) {
    return resolver._state;
  }
  if (node case final _DeltaWhat delta) {
    if (delta._isResolving || delta._needsSwitch) {
      return null;
    }
    return _safeReadWhatState(delta._source);
  }
  if (node case final _CoupledUnaryRelay coupled) {
    return _safeReadWhatState(coupled._source);
  }
  if (node case final _UnaryRelay unary) {
    return _safeReadWhatState(unary._source);
  }
  return null;
}

final _nodeIds = Expando<String>();
int _nodeIdCounter = 0;

String _getOrAssignNodeId(Object node) {
  var id = _nodeIds[node];
  if (id == null) {
    final label = _debugLabels[node];
    final seq = ++_nodeIdCounter;
    id = label != null ? '${label}_$seq' : 'node_$seq';
    _nodeIds[node] = id;
  }
  return id;
}

String _classifyNodeKind(Object node) {
  if (node is _ManagedWhat) return 'resource';
  if (node is RawTerminal || node is Effect) return 'sink';
  if (node is Tether) return 'tether';
  if (node is _Entry || node is WhatSignal || node is WhatController) return 'source';
  if (node is _Node && _countSources(node) > 0) return 'derivation';
  return 'source';
}

List<LpdagReflector> _collectReflectorSources(Object target) {
  final list = <LpdagReflector>[];
  if (target case final _DeltaWhat delta) {
    for (var curr = delta._deltaTerminal._sourceHead; curr != null; curr = curr._nextSource) {
      if (curr._source case final LpdagStatus lpdag) {
        if (lpdag.debugReflector case final r?) list.add(r);
      }
    }
    if (delta._source case final LpdagStatus lpdag) {
      if (lpdag.debugReflector case final r?) list.add(r);
    }
  } else if (target case final _NaryEdgeMixin nary) {
    for (var curr = nary._sourceHead; curr != null; curr = curr._nextSource) {
      if (curr._source case final LpdagStatus lpdag) {
        if (lpdag.debugReflector case final r?) list.add(r);
      }
    }
  } else if (target case final _UnaryEdgeMixin unary) {
    if (unary._source case final LpdagStatus lpdag) {
      if (lpdag.debugReflector case final r?) list.add(r);
    }
  } else if (target case final _Terminal term) {
    for (final snap in _collectTerminalDebugDependencies(term)) {
      if (snap.node case final LpdagStatus lpdag) {
        if (lpdag.debugReflector case final r?) list.add(r);
      }
    }
  }
  return list;
}

List<LpdagReflector> _collectReflectorTargets(Object node) {
  final list = <LpdagReflector>[];
  if (node case final _Node target) {
    for (var curr = target._targetHead; curr != null; curr = curr._nextTarget) {
      final t = curr._target;
      if (t case final LpdagStatus lpdag) {
        if (lpdag.debugReflector case final r?) list.add(r);
      }
    }
  }
  return list;
}

LpdagReflector _createLpdagReflector(LpdagStatus node) {
  if (node is WhatSignalController) {
    return _createLpdagReflector(node.what);
  }
  if (node is Computation) {
    return _createLpdagReflector(node.what);
  }
  if (node is WhatCoupler) {
    return _createLpdagReflector(node.what);
  }
  if (node is What) {
    return _WhatReflectorImpl(node);
  }
  return _LpdagReflectorImpl(node);
}

class _LpdagReflectorImpl implements LpdagReflector {
  _LpdagReflectorImpl(this._targetNode);

  final Object _targetNode;

  @override
  String get id => _getOrAssignNodeId(_targetNode);

  @override
  String? get debugLabel => _debugLabels[_targetNode];

  @override
  String? get creationLocation => _debugLocations[_targetNode];

  @override
  String get kind => _classifyNodeKind(_targetNode);

  @override
  Type get nodeType => _targetNode.runtimeType;

  @override
  int get version {
    if (_targetNode case final _Node node) {
      return node._version;
    }
    return 0;
  }

  @override
  bool get isActive {
    if (_targetNode case final LpdagStatus status) {
      return status.isActive;
    }
    return false;
  }

  @override
  int get targetCount {
    if (_targetNode case final _Node node) {
      return _countTargets(node);
    }
    return 0;
  }

  @override
  int get sourceCount {
    if (_targetNode case final _Node node) {
      return _countSources(node);
    }
    return 0;
  }

  @override
  List<LpdagReflector> get sources => _collectReflectorSources(_targetNode);

  @override
  List<LpdagReflector> get targets => _collectReflectorTargets(_targetNode);

  @override
  bool get hasData => false;

  @override
  bool get hasError => false;

  @override
  bool get isEmpty => false;

  @override
  Object? get data => null;

  @override
  Object? get error => null;

  @override
  Object? get emptyReason => null;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'debugLabel': debugLabel,
        'kind': kind,
        'nodeType': nodeType.toString(),
        'version': version,
        'isActive': isActive,
        'targetCount': targetCount,
        'sourceCount': sourceCount,
        'creationLocation': creationLocation,
      };

  @override
  void forceInvalidate() {
    if (_targetNode case final _Node node) {
      node._debugForceInvalidate(<_Node>{});
    } else if (_targetNode case final RawTerminal term) {
      term.debugForceInvalidate();
    }
  }

  @override
  String toString() => 'LpdagReflector($id, kind: $kind, label: $debugLabel)';
}

class _WhatReflectorImpl extends _LpdagReflectorImpl implements WhatReflector {
  _WhatReflectorImpl(this._what) : super(_what);

  final What _what;

  @override
  WhatState<dynamic> get state => untracked.state(_what);

  @override
  bool get hasData => state.hasData;

  @override
  bool get hasError => state.hasError;

  @override
  bool get isEmpty => state.isEmpty;

  @override
  Object? get data => state.hasData ? state.data : null;

  @override
  Object? get error => state.hasError ? state.error : null;

  @override
  Object? get emptyReason => state.isEmpty ? state.emptyReason : null;

  @override
  WhatDebugSnapshot get snapshot => _createDebugSnapshot(_what);

  @override
  Map<String, dynamic> toJson() {
    final base = super.toJson();
    base.addAll({
      'hasData': hasData,
      'hasError': hasError,
      'isEmpty': isEmpty,
      'data': data?.toString(),
      'error': error?.toString(),
      'emptyReason': emptyReason?.toString(),
    });
    return base;
  }

  @override
  String toString() => 'WhatReflector($id, kind: $kind, label: $debugLabel, data: $data)';
}
