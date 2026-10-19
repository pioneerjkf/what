// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:what/effect.dart';

/// Test utility for testing reactive tracking in unit tests.
void Function() effect(Function callback) {
  final term = RawViaTerminal((via) {
    via.tether(
      Effect.via(
        callback is void Function(WhatVia) ? callback : (v) => (callback as dynamic)(),
      ),
    );
  }, onInvalidated: () {})
    ..activate()
    ..evaluate();
  return term.deactivate;
}
