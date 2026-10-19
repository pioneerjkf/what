// Canonical lint cases for `avoid_what_creation_in_build`.
// Grammar: see what_lints/test/harness/lint_harness.dart

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

// =============================================================================
// BAD
// =============================================================================

// #case avoid_what_creation_in_build/bad/controller-in-build
class BadControllerInBuild extends StatelessWidget {
  const BadControllerInBuild({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_what_creation_in_build
    final local = WhatController(0);
    return composed((context, via) => Text('${via(local.what)}'));
  }
}

// #case avoid_what_creation_in_build/bad/computed-in-build
final shared = WhatController(0);

class BadComputedInBuild extends StatelessWidget {
  const BadComputedInBuild({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_what_creation_in_build
    final doubled = computed((via) => via(shared.what) * 2);
    return composed((context, via) => Text('${via(doubled)}'));
  }
}

// #case avoid_what_creation_in_build/bad/computed-future-in-build
class BadComputedFutureInBuild extends StatelessWidget {
  const BadComputedFutureInBuild({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_what_creation_in_build
    final asyncData = computed.future((via) async => via(shared.what) * 2);
    return composed((context, via) => Text('${via(asyncData)}'));
  }
}

// =============================================================================
// GOOD
// =============================================================================

// #case avoid_what_creation_in_build/good/created-in-init-state
class GoodCreation extends StatefulWidget {
  const GoodCreation({super.key});

  @override
  State<GoodCreation> createState() => GoodCreationState();
}

class GoodCreationState extends State<GoodCreation> {
  late final WhatController<int> _counter;
  late final What<int> _doubled;

  @override
  void initState() {
    super.initState();
    _counter = WhatController(0);
    _doubled = computed((via) => via(_counter.what) * 2);
  }

  @override
  Widget build(BuildContext context) =>
      composed((context, via) => Text('${via(_doubled)}'));
}
