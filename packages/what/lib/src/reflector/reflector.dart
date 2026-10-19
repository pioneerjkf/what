// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// LPDAG Diagnostic Reflector Core (Status Extension, Reflector Interfaces)
// =============================================================================

/// Diagnostic reflection extensions for [LpdagStatus] reactive vertices.
extension LpdagStatusReflectorExtension on LpdagStatus {
  /// Zero-overhead diagnostic reflector for Flutter DevTools and LPDAG inspection.
  ///
  /// In debug mode, returns an [LpdagReflector] instance providing safe, read-only
  /// inspection of node metadata, local topology (sources and targets), and reactive payloads.
  ///
  /// In release builds, this getter returns `null` with zero runtime overhead.
  LpdagReflector? get debugReflector {
    LpdagReflector? reflector;
    assert(() {
      reflector = _createLpdagReflector(this);
      return true;
    }());
    return reflector;
  }
}

/// Public diagnostic reflector interface for any LPDAG reactive vertex.
///
/// Encapsulates the node's topological metadata, active dependency graph edges,
/// and DevTools RPC serialization without mutating the underlying reactive engine.
abstract interface class LpdagReflector {
  /// Unique deterministic identifier for this node in the DevTools session.
  String get id;

  /// The developer-defined debug label assigned to this node, if any.
  String? get debugLabel;

  /// The exact call stack frame where this node was instantiated in debug mode.
  String? get creationLocation;

  /// Functional classification of this node ('source', 'derivation', 'resource', 'sink', 'tether').
  String get kind;

  /// The runtime implementation class of the underlying node.
  Type get nodeType;

  /// The current monotonic version of this node.
  int get version;

  /// Whether this node is currently active in the reactive graph.
  bool get isActive;

  /// Number of active downstream subscribers connected to this node.
  int get targetCount;

  /// Number of active upstream dependency edges connected to this node.
  int get sourceCount;

  /// Active upstream dependency nodes subscribed by this node.
  List<LpdagReflector> get sources;

  /// Active downstream target subscribers observing this node.
  List<LpdagReflector> get targets;

  /// Whether this node currently holds a valid data payload.
  bool get hasData;

  /// Whether this node is currently in an error state.
  bool get hasError;

  /// Whether this node is currently in an uninitialized or empty state.
  bool get isEmpty;

  /// The current data payload if [hasData] is true; otherwise null.
  Object? get data;

  /// The current error payload if [hasError] is true; otherwise null.
  Object? get error;

  /// The empty reason payload if [isEmpty] is true; otherwise null.
  Object? get emptyReason;

  /// Serializes this node's diagnostic metadata into a JSON-compatible map.
  Map<String, dynamic> toJson();

  /// Forces local cache invalidation and dirty version increments during hot reload or debugging.
  void forceInvalidate();
}

/// Specialized diagnostic reflector interface for reactive state carriers ([What]).
///
/// Exposes the node's three-state FSM ([WhatState]), current data payload,
/// snapshot, and debugging mutation sandbox handles.
abstract interface class WhatReflector implements LpdagReflector {
  /// The live [WhatState] view of this node.
  WhatState<dynamic> get state;

  /// An immutable diagnostic snapshot of this reactive node.
  WhatDebugSnapshot get snapshot;
}
