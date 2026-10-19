// Canonical lint cases for State lifecycle rules:
// `deactivate_effect_runner` and `dispose_what_flutter_controller`.
// Grammar: see what_lints/test/harness/lint_harness.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

final count = WhatController(0).what;
final text = WhatController('');

// =============================================================================
// BAD
// =============================================================================

// #case deactivate_effect_runner/bad/runner-never-deactivated
class LeakyRunner extends StatefulWidget {
  const LeakyRunner({super.key});

  @override
  State<LeakyRunner> createState() => LeakyRunnerState();
}

class LeakyRunnerState extends State<LeakyRunner> {
  // expect_lint: deactivate_effect_runner
  EffectRunner? _runner; // ignore: unused_field

  @override
  void initState() {
    super.initState();
    _runner = count.effect(() => print(count.peek)).run();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// #case dispose_what_flutter_controller/bad/bound-text-controller-never-disposed
class LeakyTextField extends StatefulWidget {
  const LeakyTextField({super.key});

  @override
  State<LeakyTextField> createState() => LeakyTextFieldState();
}

class LeakyTextFieldState extends State<LeakyTextField> {
  // expect_lint: dispose_what_flutter_controller
  late final WhatTextEditingController _controller =
      WhatTextEditingController(text);

  @override
  Widget build(BuildContext context) => TextField(controller: _controller);
}

// =============================================================================
// GOOD
// =============================================================================

// #case deactivate_effect_runner/good/runner-deactivated
class CleanRunner extends StatefulWidget {
  const CleanRunner({super.key});

  @override
  State<CleanRunner> createState() => CleanRunnerState();
}

class CleanRunnerState extends State<CleanRunner> {
  EffectRunner? _runner;

  @override
  void initState() {
    super.initState();
    _runner = count.effect(() => print(count.peek)).run();
  }

  @override
  void dispose() {
    _runner?.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// #case dispose_what_flutter_controller/good/bound-text-controller-disposed
class CleanTextField extends StatefulWidget {
  const CleanTextField({super.key});

  @override
  State<CleanTextField> createState() => CleanTextFieldState();
}

class CleanTextFieldState extends State<CleanTextField> {
  late final WhatTextEditingController _controller =
      WhatTextEditingController(text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: _controller);
}
