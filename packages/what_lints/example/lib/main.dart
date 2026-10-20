// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

// # what_lints: a guided tour
//
// One BAD / GOOD pair per rule, written against the real `what` and
// `what_flutter` APIs.
//
// An `expect_lint: <rule>` comment marks the line directly below it as the one that
// triggers <rule>. This file is analyzed and verified on every CI run by the
// what_lints test harness, so every annotation here reflects actual behavior.
//
// ## Setup
//
// ```yaml
// # pubspec.yaml
// dev_dependencies:
//   custom_lint: ^0.8.1
//   what_lints: ^0.2.0
//
// # analysis_options.yaml
// analyzer:
//   plugins:
//     - custom_lint
// ```
//
// Exhaustive edge cases and regression cases live in `example/lint_cases/`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

final counter = WhatController(0);
final count = counter.what;
final factor = WhatController(2).what;
final status = WhatController('idle');

// =============================================================================
// 1. Reactive derivations (`computed`, `switched`, `managed`, `Effect.via`)
// =============================================================================

// #case tour/avoid_untracked_what_read/bad
// Reading `.data` or `untracked()` without `via()` creates no dependency edge, so this node
// silently never recomputes when `count` changes.
final untrackedRead = computed((via) {
  final f = via(factor);
  // expect_lint: avoid_untracked_what_read
  return untracked(count) * f;
});

// #case tour/avoid_untracked_what_read/good
final tracked = computed((via) => via(count) * via(factor));

// #case tour/avoid_unnecessary_via_scope/bad
// A reactive node that tracks nothing is pure DAG overhead.
// expect_lint: avoid_unnecessary_via_scope
final constantNode = computed((via) => 6 * 7);

// #case tour/avoid_unnecessary_via_scope/good
const answer = 6 * 7;

// #case tour/avoid_escaping_via/bad
// `via` is only valid during the synchronous evaluation pass.
final escaped = computed.future((via) async {
  final id = via(count);
  await Future<void>.delayed(const Duration(milliseconds: 10));
  // expect_lint: avoid_escaping_via
  return id * via(factor);
});

// #case tour/avoid_escaping_via/good
final synchronous = computed.future((via) async {
  final id = via(count);
  final f = via(factor);
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return id * f;
});

// #case tour/avoid_state_writes_in_pipeline/bad
// Writing during evaluation causes reentrancy and render loops.
final impure = computed((via) {
  // expect_lint: avoid_state_writes_in_pipeline
  status.set('evaluating');
  return via(count) + 1;
});

// #case tour/avoid_state_writes_in_pipeline/good
void increment() => counter.set(counter.data + 1);

// #case tour/avoid_async_in_managed/bad
// An async `create` makes `managed` supervise a Future instead of the resource.
final asyncResource = managed<Object?>(
  // expect_lint: avoid_async_in_managed
  create: (via) async => Timer.periodic(const Duration(seconds: 1), (_) {}),
  dispose: (resource) {},
);

// #case tour/avoid_async_in_managed/good
final ticker = managed<Timer>(
  create: (via) => Timer.periodic(const Duration(seconds: 1), (_) {}),
  dispose: (timer) => timer.cancel(),
);

// #case tour/avoid_catching_via_short_circuit/bad
// Catching broad exceptions intercepts What's internal short-circuit sentinel.
final caughtSentinel = computed((via) {
  try {
    return via(count) + 1;
    // expect_lint: avoid_catching_via_short_circuit
  } catch (e) {
    return 0;
  }
});

// #case tour/avoid_catching_via_short_circuit/good
final safeDomainCatch = computed((via) {
  final raw = via(count);
  try {
    return int.parse(raw.toString());
  } on FormatException {
    return 0;
  }
});

// #case tour/avoid_via_state_when_value_suffices/bad
// Reading via.state(x).data redundantly allocates a live state view.
// expect_lint: avoid_via_state_when_value_suffices
final redundantStateAccess = computed((via) => via.state(count).data * 2);

// #case tour/avoid_via_state_when_value_suffices/good
final conciseValueAccess = computed((via) => via(count) * 2);

// =============================================================================
// 2. Flutter build passes
// =============================================================================

class ComposedCounter extends StatelessWidget {
  const ComposedCounter({super.key});

  @override
  Widget build(BuildContext context) =>
      composed((context, via) => Text('${via(count)}'));
}

// #case tour/avoid_what_creation_in_build/bad
// State created in build() is discarded and recreated on every frame.
class CreationInBuild extends StatelessWidget {
  const CreationInBuild({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_what_creation_in_build
    final local = WhatController(0);
    return composed((context, via) => Text('${via(local.what)}'));
  }
}

// #case tour/avoid_what_creation_in_build/good
class CreationInState extends StatefulWidget {
  const CreationInState({super.key});

  @override
  State<CreationInState> createState() => _CreationInStateState();
}

class _CreationInStateState extends State<CreationInState> {
  late final WhatController<int> _local;
  late final What<int> _doubled;

  @override
  void initState() {
    super.initState();
    _local = WhatController(0);
    _doubled = computed((via) => via(_local.what) * 2);
  }

  @override
  Widget build(BuildContext context) =>
      composed((context, via) => Text('${via(_doubled)}'));
}

// #case tour/avoid_bridging_in_build/bad
// A new bridge pipeline is allocated on every rebuild.
class BridgingInBuild extends StatelessWidget {
  const BridgingInBuild({super.key, required this.stream});

  final Stream<int> stream;

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_bridging_in_build
    final bridged = stream.toWhat();
    return composed((context, via) => Text('${via.state(bridged).dataOrNull}'));
  }
}

// #case tour/avoid_bridging_in_build/good
class BridgingInState extends StatefulWidget {
  const BridgingInState({super.key, required this.stream});

  final Stream<int> stream;

  @override
  State<BridgingInState> createState() => _BridgingInStateState();
}

class _BridgingInStateState extends State<BridgingInState> {
  late final What<int> _bridged = widget.stream.toWhat();

  @override
  Widget build(BuildContext context) =>
      composed((context, via) => Text('${via.state(_bridged).dataOrNull}'));
}

// #case tour/prefer_composed_child/bad
// The const static subtree is rebuilt on every `count` tick.
// expect_lint: prefer_composed_child
Widget rebuildsStaticSubtree() => composed((context, via) => Row(
      children: [
        Text('${via(count)}'),
        const Icon(Icons.star),
        const Text('Stars'),
      ],
    ));

// #case tour/prefer_composed_child/good
Widget cachesStaticSubtree() => composed.child(
      (context, via, child) => Row(
        children: [Text('${via(count)}'), child],
      ),
      child: const Row(children: [Icon(Icons.star), Text('Stars')]),
    );

// =============================================================================
// 3. Lifecycles and widget APIs
// =============================================================================

// #case tour/deactivate_effect_runner/bad
class LeakyRunner extends StatefulWidget {
  const LeakyRunner({super.key});

  @override
  State<LeakyRunner> createState() => _LeakyRunnerState();
}

class _LeakyRunnerState extends State<LeakyRunner> {
  // expect_lint: deactivate_effect_runner
  late final EffectRunner _runner; // ignore: unused_field

  @override
  void initState() {
    super.initState();
    _runner = count.effect(() => debugPrint('${untracked(count)}')).run();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// #case tour/deactivate_effect_runner/good
class CleanRunner extends StatefulWidget {
  const CleanRunner({super.key});

  @override
  State<CleanRunner> createState() => _CleanRunnerState();
}

class _CleanRunnerState extends State<CleanRunner> {
  late final EffectRunner _runner;

  @override
  void initState() {
    super.initState();
    _runner = count.effect(() => debugPrint('${untracked(count)}')).run();
  }

  @override
  void dispose() {
    _runner.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// #case tour/prefer_what_over_controller/bad
// Consumers should not receive the producer handle.
class ControllerConsumer extends StatelessWidget {
  const ControllerConsumer({
    super.key,
    // expect_lint: prefer_what_over_controller
    required this.counter,
  });

  final WhatController<int> counter;

  @override
  Widget build(BuildContext context) =>
      composed((context, via) => Text('${via(counter.what)}'));
}

// #case tour/prefer_what_over_controller/good
class WhatConsumer extends StatelessWidget {
  const WhatConsumer({super.key, required this.count});

  final What<int> count;

  @override
  Widget build(BuildContext context) =>
      composed((context, via) => Text('${via(count)}'));
}

// #case tour/avoid_escaping_scoped_controller/bad
// ScopedAnimationController is tied to a mounted builder and should never be stored as a field.
class LeakyScopedStore {
  // expect_lint: avoid_escaping_scoped_controller
  ScopedAnimationController? controller;
}

// #case tour/avoid_escaping_scoped_controller/good
class SafeScopedStore {
  // Hold durable root controller in long-lived state or stores.
  final controller =
      DurableAnimationController(duration: const Duration(seconds: 1));
}
