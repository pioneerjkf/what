// Regression cases: user-defined symbols that merely share a name with What
// APIs must never be treated as What constructs.
// Grammar: see what_lints/test/harness/lint_harness.dart
// ignore_for_file: avoid_print

import 'package:what/what.dart';

final count = WhatController(0).what;

// #case regression/good/P9-user-defined-effect-class
class Effect {
  Effect(this.action);
  final void Function() action;
}

final userEffect = Effect(() => print(count.peek));

// #case regression/good/P11-user-defined-computed-function
int computedLocally(int Function(Object via) body) => body(Object());

final userComputed = computedLocally((via) => count.peek);
