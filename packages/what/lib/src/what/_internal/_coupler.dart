// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Coupled What Node
// =============================================================================

/// Internal reactive relay node for [WhatCoupler].
///
/// Implements [What<T>] as a 1-tier relay node in the DAG, delegating its state
/// and edge connections dynamically to the currently coupled upstream source.
base class _CoupledWhat<T> extends _CoupledUnaryRelay<What<T>> with _WhatStateMixin<T> implements What<T>, LpdagStatus {
  _CoupledWhat(super.inbound);

  _CoupledWhat.late() : super.late();

  _CoupledWhat.error(Object error, [StackTrace? stackTrace]) : super(What.error(error, stackTrace));

  bool _isResolving = false;

  @override
  @pragma('vm:prefer-inline')
  void _resolve() {
    if (_isResolving) {
      throw LpdagCycleError(
        'Cyclic coupling loop detected in $runtimeType while resolving upstream source.',
      );
    }
    _isResolving = true;
    try {
      _source._resolve();
      if (_source._version != _pulledVersion) {
        _version++;
        _pullVersion();
      }
    } finally {
      _isResolving = false;
    }
  }

  @override
  @pragma('vm:prefer-inline')
  _WhatState<T> _read() {
    _resolve();
    return _source._read();
  }

  @override
  What<T> _catchEmpty() => What.empty();

  @override
  What<T> _catchError(Object error, StackTrace? stackTrace) => What.error(error, stackTrace);
}
