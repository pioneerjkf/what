// Canonical lint cases for `avoid_bridging_in_build`.
// Grammar: see what_lints/test/harness/lint_harness.dart

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

final notifier = ValueNotifier<int>(0);

// =============================================================================
// BAD
// =============================================================================

// #case avoid_bridging_in_build/bad/to-what-in-build
class BadBridgeInBuild extends StatelessWidget {
  const BadBridgeInBuild({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_bridging_in_build
    final bridged = notifier.toWhat();
    return composed((context, via) => Text('${via(bridged)}'));
  }
}

// #case avoid_bridging_in_build/bad/to-listenable-in-computed
final source = WhatController(0).what;
final badInComputed = computed((via) {
  // expect_lint: avoid_bridging_in_build
  final listenable = source.toListenable();
  return via(source) + listenable.value;
});

// =============================================================================
// GOOD
// =============================================================================

// #case avoid_bridging_in_build/good/bridge-cached-outside-build
final cachedBridge = notifier.toWhat();

class GoodCachedBridge extends StatelessWidget {
  const GoodCachedBridge({super.key});

  @override
  Widget build(BuildContext context) =>
      composed((context, via) => Text('${via(cachedBridge)}'));
}
