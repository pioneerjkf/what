// Canonical lint cases for `avoid_via_state_when_value_suffices`.
// Grammar: see what_lints/test/harness/lint_harness.dart

import 'package:what_flutter/what_flutter.dart';

final counter = WhatController(0);
final count = counter.what;

// =============================================================================
// BAD
// =============================================================================

// #case avoid_via_state_when_value_suffices/bad/via-state-data
final badViaStateData = computed((via) =>
    // expect_lint: avoid_via_state_when_value_suffices
    via.state(count).data * 2);

// =============================================================================
// GOOD
// =============================================================================

// #case avoid_via_state_when_value_suffices/good/direct-via
final goodDirectVia = computed((via) => via(count) * 2);

// #case avoid_via_state_when_value_suffices/good/via-state-metadata
final goodViaStateMetadata = computed((via) {
  final state = via.state(count);
  if (state.hasData) return state.data;
  return 0;
});
