// Canonical lint cases for `avoid_state_writes_in_pipeline`.
// Grammar: see what_lints/test/harness/lint_harness.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

final counter = WhatController(0);
final label = WhatController('');

// =============================================================================
// BAD
// =============================================================================

// #case avoid_state_writes_in_pipeline/bad/set-in-computed
final badComputed = computed((via) {
  // expect_lint: avoid_state_writes_in_pipeline
  label.set('mutated');
  return via(counter.what) + 1;
});

// #case avoid_state_writes_in_pipeline/bad/set-in-build
class BadSetInBuild extends StatelessWidget {
  const BadSetInBuild({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_state_writes_in_pipeline
    counter.set(10);
    return const SizedBox();
  }
}

// #case avoid_state_writes_in_pipeline/bad/data-setter-in-build
class BadDataSetterInBuild extends StatelessWidget {
  const BadDataSetterInBuild({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_state_writes_in_pipeline
    counter.data = 2;
    return const SizedBox();
  }
}

// =============================================================================
// GOOD
// =============================================================================

// #case avoid_state_writes_in_pipeline/good/set-in-event-callback
class GoodSetInCallback extends StatelessWidget {
  const GoodSetInCallback({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => counter.set(0),
      child: const Text('reset'),
    );
  }
}

// #case avoid_state_writes_in_pipeline/good/set-in-timer-run
class GoodSetInTimer extends StatelessWidget {
  const GoodSetInTimer({super.key});

  @override
  Widget build(BuildContext context) {
    Timer.run(() => counter.set(1));
    return const SizedBox();
  }
}

// #case avoid_state_writes_in_pipeline/good/set-outside-pipeline
void goodPlainWrite() => counter.set(5);

// #case avoid_state_writes_in_pipeline/good/regression-P6-non-what-set-receiver
class Cache {
  void set(String key, int value) {}
}

final cache = Cache();

class GoodNonWhatSet extends StatelessWidget {
  const GoodNonWhatSet({super.key});

  @override
  Widget build(BuildContext context) {
    cache.set('k', 1);
    return const SizedBox();
  }
}

// #case avoid_state_writes_in_pipeline/good/regression-P7-post-frame-callback
class GoodPostFrame extends StatelessWidget {
  const GoodPostFrame({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => counter.set(3));
    return const SizedBox();
  }
}

// #case avoid_state_writes_in_pipeline/good/regression-P8-local-function-handler
class GoodLocalHandler extends StatelessWidget {
  const GoodLocalHandler({super.key});

  @override
  Widget build(BuildContext context) {
    void reset() => counter.set(0);
    return TextButton(onPressed: reset, child: const Text('reset'));
  }
}
