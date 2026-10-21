// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// LPDAG Reactive Ecosystem Debug Extensions & Utilities
// =============================================================================

/// An immutable structured diagnostic snapshot of a reactive [What] node,
/// capturing its topology, lifecycle, and reactive state payload.
final class WhatDebugSnapshot {
  /// Creates an immutable diagnostic snapshot of a reactive [node].
  const WhatDebugSnapshot({
    required this.node,
    this.debugLabel,
    required this.nodeType,
    required this.version,
    this.isActive = false,
    this.targetCount = 0,
    this.customProperties = const {},
    this.phase = WhatPhase.empty,
    this.data,
    this.error,
    this.emptyReason,
  });

  /// The underlying [What] reactive node instance.
  final What node;

  /// The developer-assigned debug label, if any.
  final String? debugLabel;

  /// The runtime implementation class of the observed node.
  final Type nodeType;

  /// The runtime type of the observed node, matching [nodeType].
  @override
  Type get runtimeType => nodeType;

  /// The internal version of the observed node.
  final int version;

  // --- Topology & Lifecycle ---

  /// Whether this node is currently active in the LPDAG reactive graph.
  final bool isActive;

  /// The number of active downstream target edges connected to this node.
  final int targetCount;

  /// Whether this node currently has at least one active downstream target.
  bool get hasTargets => targetCount > 0;

  /// Node-specific diagnostic properties (e.g. active branch source for switched nodes,
  /// or resource allocation status for managed nodes).
  final Map<String, dynamic> customProperties;

  // --- Reactive State Payload ---

  /// The operational phase of the observed reactive node.
  final WhatPhase phase;

  /// Whether the node currently holds a valid data payload.
  bool get hasData => phase == WhatPhase.valid;

  /// Whether the node is currently in an error state.
  bool get hasError => phase == WhatPhase.error;

  /// Whether the node is currently in an uninitialized or empty state.
  bool get isEmpty => phase == WhatPhase.empty;

  /// The current data payload if [hasData] is true; otherwise null.
  final Object? data;

  /// The current error payload if [hasError] is true; otherwise null.
  final Object? error;

  /// The empty reason payload if [isEmpty] is true; otherwise null.
  final Object? emptyReason;

  /// The display name for this node, preferring [debugLabel] or falling back to [nodeType].
  String get name => debugLabel ?? nodeType.toString();

  /// A formatted description of the dependency state.
  String get description => switch (phase) {
        WhatPhase.valid => '${_formatDebugPayload(data)} (v$version)',
        WhatPhase.error => 'Error: $error (v$version)',
        WhatPhase.empty =>
          '<empty${emptyReason != null ? ' ($emptyReason)' : ''}> (v$version)',
      };

  static String _formatDebugPayload(Object? payload) {
    if (payload == null) return 'null';
    if (payload is num || payload is bool || payload is String || payload is Enum) {
      return '$payload';
    }
    final typeStr = payload.runtimeType.toString();
    if (typeStr.endsWith('Element') || typeStr.endsWith('Context') || typeStr.endsWith('Widget')) {
      return '$typeStr#${identityHashCode(payload).toRadixString(16)}';
    }
    return '$payload';
  }

  @override
  String toString() {
    final label = debugLabel != null ? '$debugLabel ($nodeType)' : nodeType.toString();
    final custom = customProperties.isNotEmpty ? ', custom: $customProperties' : '';
    final stateStr = switch (phase) {
      WhatPhase.valid => ', data: ${_formatDebugPayload(data)}',
      WhatPhase.error => ', error: $error',
      WhatPhase.empty => ', empty',
    };
    return '[$label] active: $isActive, targets: $targetCount, version: $version$stateStr$custom';
  }
}

/// Zero-cost extension type wrapping [What] for read-only inspection.
///
/// Enables developers to inspect node properties, subscriber counts, versions, and
/// diagnostic snapshots with zero heap allocations and zero runtime penalty in Release builds.
///
/// ## Examples
/// ```dart
/// final counter = WhatController(0).withDebugLabel('counter');
///
/// print(counter.what.debug.debugLabel);   // 'counter'
/// print(counter.what.debug.targetCount);  // 0
/// print(counter.what.debug.describe());    // '[WhatController<int>#counter] active: false...'
/// ```
extension type const WhatDebug(What _target) {
  /// The developer-defined debug label assigned to this node, if any.
  String? get debugLabel => _debugLabels[_target];

  /// The exact code location where this object was instantiated in debug mode.
  String? get creationLocation => _debugLocations[_target];

  /// The number of active downstream targets currently attached to this node.
  int get targetCount => _countTargets(_target);

  /// The number of active upstream source edges connected to this node.
  int get sourceCount => _countSources(_target);

  /// Whether this node currently has at least one active downstream target edge.
  bool get hasTargets => _target._hasTargets;

  /// Captures an immutable structured diagnostic snapshot of this reactive node.
  WhatDebugSnapshot snapshot() => _createDebugSnapshot(_target);

  /// Formats a concise one-line diagnostic summary for this node.
  String describe() => _formatDebugSummary(_target);

  /// Captures the creation stack trace and assigns an optional debug label to this node.
  ///
  /// * [label]: An optional identifier for this node.
  /// * [traceCount]: The number of call stack frames to retain (default: 5).
  ///
  /// **Ensures:**
  /// * In debug mode, tags this node and stores its creation stack trace externally.
  /// * In release mode, executes as a no-op with zero runtime overhead.
  void trace([String? label, int traceCount = 5]) => _captureDebugTrace(_target, label, traceCount);
}

/// Extension providing zero-overhead debugging capabilities to [RawTerminal] sinks.
extension RawTerminalDebugExtension on RawTerminal {
  /// The developer-defined label to identify this terminal in debug mode.
  String? get debugLabel => _debugLabels[this];

  set debugLabel(String? label) {
    assert(() {
      if (label != null) _debugLabels[this] = label;
      return true;
    }());
  }

  /// Assigns a developer-defined debug label and returns this terminal.
  T withDebugLabel<T extends RawTerminal>(String label) {
    debugLabel = label;
    return this as T;
  }

  /// The exact code location where this terminal was instantiated in debug mode.
  String? get debugCreationLocation => _debugLocations[this];

  /// Captures the current stack trace and assigns an optional label to this terminal.
  ///
  /// * [label]: An optional identifier for this terminal.
  /// * [traceCount]: The number of call stack frames to retain (default: 5).
  ///
  /// **Ensures:**
  /// * In debug mode, the terminal is tagged and its creation stack trace is captured.
  /// * In release mode, does nothing with zero runtime overhead.
  void debugTrace([String? label, int traceCount = 5]) => _captureDebugTrace(this, label, traceCount);

  /// Debug-only list of active upstream dependencies currently subscribed by this terminal.
  ///
  /// In release builds, this returns an empty list with zero heap overhead.
  List<WhatDebugSnapshot> get debugDependencies {
    var result = const <WhatDebugSnapshot>[];
    assert(() {
      if (this case final _Terminal term) {
        result = _collectTerminalDebugDependencies(term);
      }
      return true;
    }());
    return result;
  }

  /// Debug-only list of active declarative [Tether] instances tethered to this terminal's lifecycle.
  ///
  /// In release builds, this returns an empty list with zero heap overhead.
  List<Tether> get debugTethers {
    var result = const <Tether>[];
    assert(() {
      if (this case final _Terminal term) {
        result = _collectTerminalDebugTethers(term);
      }
      return true;
    }());
    return result;
  }
}

/// Extension providing zero-overhead debugging capabilities to declarative [Tether] nodes.
extension TetherDebugExtension<T extends Tether> on T {
  /// A developer-defined label to identify this tether in debug mode.
  String? get debugLabel => _debugLabels[this];

  set debugLabel(String? label) {
    assert(() {
      if (label != null) _debugLabels[this] = label;
      return true;
    }());
  }

  /// Assigns a developer-defined debug label and returns this tether.
  T withDebugLabel(String label) {
    debugLabel = label;
    return this;
  }

  /// The exact code location where this tether was instantiated in debug mode.
  String? get debugCreationLocation => _debugLocations[this];

  /// Captures the current stack trace and assigns an optional label to this tether.
  ///
  /// * [label]: An optional identifier for this tether.
  /// * [traceCount]: The number of call stack frames to retain (default: 5).
  ///
  /// **Ensures:**
  /// * In debug mode, tags this tether and captures its creation call stack.
  /// * In release mode, executes as a no-op with zero runtime overhead.
  void debugTrace([String? label, int traceCount = 5]) => _captureDebugTrace(this, label, traceCount);
}

/// Extension providing zero-overhead debugging capabilities specific to declarative [Effect] nodes.
extension EffectDebugExtension on Effect {
  /// Debug-only list of active upstream dependencies currently monitored by this effect's terminal.
  List<WhatDebugSnapshot> get debugDependencies => _terminal.debugDependencies;
}

/// Extension providing zero-overhead debugging capabilities to [Computation] nodes.
extension ComputationDebugExtension on Computation {
  /// Access point for zero-overhead node inspection and diagnostics.
  WhatDebug get debug => WhatDebug(what);

  /// A developer-defined label to identify this computation in debug mode.
  String? get debugLabel => _debugLabels[this];

  set debugLabel(String? label) {
    assert(() {
      if (label != null) {
        _debugLabels[this] = label;
        _debugLabels[what] = label;
      }
      return true;
    }());
  }

  /// Assigns a developer-defined debug label and returns this computation.
  T withDebugLabel<T extends Computation>(String label) {
    debugLabel = label;
    return this as T;
  }

  /// The exact code location where this computation was instantiated in debug mode.
  String? get debugCreationLocation => _debugLocations[this];

  /// Captures the current stack trace and assigns an optional label to this computation.
  ///
  /// * [label]: An optional identifier for this computation node.
  /// * [traceCount]: The number of call stack frames to retain (default: 5).
  ///
  /// **Ensures:**
  /// * In debug mode, tags this computation node and captures creation call stack.
  /// * In release mode, executes as a no-op with zero runtime overhead.
  void debugTrace([String? label, int traceCount = 5]) {
    _captureDebugTrace(this, label, traceCount);
    assert(() {
      if (label != null) _debugLabels[what] = label;
      return true;
    }());
  }
}

// =============================================================================
// What Reactive Ecosystem Debug Extensions (What, Controller, Coupler)
// =============================================================================

/// Extension providing zero-overhead debugging capabilities to [What] reactive nodes.
///
/// Allows developers to tag nodes and capture their creation stack traces to hunt down memory
/// leaks or trace data pipelines. Crucially, it guarantees absolutely zero memory overhead
/// in Release builds by storing debug state externally using an [Expando] and wrapping the
/// capture logic in `assert`.
extension WhatDebugExtension<T> on What<T> {
  /// Access point for zero-overhead node inspection and diagnostics.
  WhatDebug get debug => WhatDebug(this);

  /// A developer-defined label to identify this specific object in debug mode.
  String? get debugLabel => _debugLabels[this];

  set debugLabel(String? label) {
    assert(() {
      if (label != null) _debugLabels[this] = label;
      return true;
    }());
  }

  /// Assigns a developer-defined debug label and returns this [What].
  W withDebugLabel<W extends What<T>>(String label) {
    debugLabel = label;
    return this as W;
  }

  /// The exact code location where this object was created in debug mode.
  String? get debugCreationLocation => _debugLocations[this];

  /// Captures the current stack trace and assigns an optional label to this [What].
  ///
  /// * [label]: An optional identifier for this node.
  /// * [traceCount]: The number of call stack frames to keep (default: 5).
  ///
  /// **Ensures:**
  /// * In debug mode, the node is tagged and its creation stack trace is captured and stored externally.
  /// * In release mode, executes as a no-op with zero runtime overhead.
  void debugTrace([String? label, int traceCount = 5]) => _captureDebugTrace(this, label, traceCount);

  /// The internal version of this [What] for verification and debugging.
  @visibleForTesting
  int get debugVersion => _version;

  /// The number of active upstream source edges connected to this node for verification and testing.
  @visibleForTesting
  int get debugSourceCount => _countSources(this);
}

/// Extension providing zero-overhead debugging capabilities to [WhatController] producers.
extension WhatControllerDebugExtension<T> on WhatController<T> {
  /// A developer-defined label to identify this specific controller in debug mode.
  String? get debugLabel => _debugLabels[this];

  set debugLabel(String? label) {
    assert(() {
      if (label != null) {
        _debugLabels[this] = label;
        _debugLabels[what] = label;
      }
      return true;
    }());
  }

  /// Assigns a developer-defined debug label and returns this controller.
  C withDebugLabel<C extends WhatController<T>>(String label) {
    debugLabel = label;
    return this as C;
  }

  /// The exact code location where this controller was instantiated in debug mode.
  String? get debugCreationLocation => _debugLocations[this];

  /// Captures the current stack trace and assigns an optional label to this controller.
  ///
  /// * [label]: An optional identifier for this controller.
  /// * [traceCount]: The number of call stack frames to retain (default: 5).
  ///
  /// **Ensures:**
  /// * In debug mode, tags this controller and captures creation call stack.
  /// * In release mode, executes as a no-op with zero runtime overhead.
  void debugTrace([String? label, int traceCount = 5]) {
    _captureDebugTrace(this, label, traceCount);
    assert(() {
      if (label != null) _debugLabels[what] = label;
      return true;
    }());
  }
}

/// Extension providing zero-overhead debugging capabilities to [WhatSignalController] emitters.
extension WhatSignalControllerDebugExtension on WhatSignalController {
  /// A developer-defined label to identify this signal controller in debug mode.
  String? get debugLabel => _debugLabels[this];

  set debugLabel(String? label) {
    assert(() {
      if (label != null) {
        _debugLabels[this] = label;
        _debugLabels[what] = label;
      }
      return true;
    }());
  }

  /// Assigns a developer-defined debug label and returns this controller.
  WhatSignalController withDebugLabel(String label) {
    debugLabel = label;
    return this;
  }

  /// The exact code location where this signal controller was instantiated in debug mode.
  String? get debugCreationLocation => _debugLocations[this];

  /// Captures the current stack trace and assigns an optional label to this signal controller.
  ///
  /// * [label]: An optional identifier for this signal controller.
  /// * [traceCount]: The number of call stack frames to retain (default: 5).
  ///
  /// **Ensures:**
  /// * In debug mode, tags this signal controller and captures creation call stack.
  /// * In release mode, executes as a no-op with zero runtime overhead.
  void debugTrace([String? label, int traceCount = 5]) {
    _captureDebugTrace(this, label, traceCount);
    assert(() {
      if (label != null) _debugLabels[what] = label;
      return true;
    }());
  }
}

/// Extension providing zero-overhead debugging capabilities to [WhatCoupler] dynamic sockets.
extension WhatCouplerDebugExtension on WhatCoupler {
  /// Access point for zero-overhead node inspection and diagnostics.
  WhatDebug get debug => WhatDebug(_proxy);

  /// A developer-defined label to identify this coupler socket in debug mode.
  String? get debugLabel => _debugLabels[this];

  set debugLabel(String? label) {
    assert(() {
      if (label != null) _debugLabels[this] = label;
      return true;
    }());
  }

  /// Assigns a developer-defined debug label and returns this coupler socket.
  WhatCoupler withDebugLabel(String label) {
    debugLabel = label;
    return this;
  }

  /// The exact code location where this coupler was instantiated in debug mode.
  String? get debugCreationLocation => _debugLocations[this];

  /// Captures the current stack trace and assigns an optional label to this coupler socket.
  ///
  /// * [label]: An optional identifier for this coupler socket.
  /// * [traceCount]: The number of call stack frames to retain (default: 5).
  ///
  /// **Ensures:**
  /// * In debug mode, tags this coupler socket and captures creation call stack.
  /// * In release mode, executes as a no-op with zero runtime overhead.
  void debugTrace([String? label, int traceCount = 5]) => _captureDebugTrace(this, label, traceCount);

  /// The internal version of this [WhatCoupler] for testing and verification.
  @visibleForTesting
  int get debugVersion => _proxy._version;
}
