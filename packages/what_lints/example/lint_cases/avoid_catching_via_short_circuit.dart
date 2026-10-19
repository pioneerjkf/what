// Canonical lint cases for `avoid_catching_via_short_circuit`.
// Grammar: see what_lints/test/harness/lint_harness.dart
// ignore_for_file: avoid_print, unused_catch_clause

import 'package:what_flutter/what_flutter.dart';

final counter = WhatController(0);
final count = counter.what;

// =============================================================================
// BAD
// =============================================================================

// #case avoid_catching_via_short_circuit/bad/broad-catch-in-computed
final badComputedCatch = computed((via) {
  try {
    return via(count) * 2;
    // expect_lint: avoid_catching_via_short_circuit
  } catch (e) {
    return 0;
  }
});

// #case avoid_catching_via_short_circuit/bad/on-object-in-computed
final badOnObjectCatch = computed((via) {
  try {
    return via(count) + 1;
    // expect_lint: avoid_catching_via_short_circuit
  } on Object catch (e) {
    return -1;
  }
});

// =============================================================================
// GOOD
// =============================================================================

// #case avoid_catching_via_short_circuit/good/via-outside-try
final goodViaOutsideTry = computed((via) {
  final value = via(count);
  try {
    return int.parse(value.toString());
  } on FormatException {
    return 0;
  }
});

// #case avoid_catching_via_short_circuit/good/rethrow-in-catch
final goodRethrow = computed((via) {
  try {
    return via(count) + 10;
  } catch (e) {
    print('logging');
    rethrow;
  }
});
