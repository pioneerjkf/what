// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule recommending `via(x)` over `via.state(x).data` when only the payload value is needed.
///
/// ### Rationale:
/// `via(x)` returns `T` directly and automatically short-circuits downstream evaluation if
/// upstream is Empty or Error, ensuring 0-alloc propagation and concise syntax.
///
/// Calling `via.state(x).data` redundantly queries the live `WhatState<T>` view only to extract
/// its `.data` payload, bypassing the concise value API.
///
/// **BAD:**
/// ```dart
/// final total = computed((via) => via.state(priceWhat).data * via.state(quantityWhat).data);
/// ```
///
/// **GOOD:**
/// ```dart
/// final total = computed((via) => via(priceWhat) * via(quantityWhat));
/// ```
class AvoidViaStateWhenValueSuffices extends DartLintRule {
  AvoidViaStateWhenValueSuffices() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_via_state_when_value_suffices',
    problemMessage:
        'Use via(x) directly instead of via.state(x).data when only the value is needed.',
    correctionMessage:
        'Replace \'via.state(x).data\' with \'via(x)\' for zero-allocation and concise derivation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  List<Fix> getFixes() => [ReplaceViaStateDataFix()];

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((node) {
      if (node.propertyName.name != 'data') return;
      final target = node.target;
      if (target is MethodInvocation && isViaStateInvocation(target)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// Returns `true` if the method invocation [node] represents a `via.state(...)` call.
  static bool isViaStateInvocation(MethodInvocation node) {
    if (node.methodName.name != 'state') return false;
    final target = node.target;
    return target != null && WhatTypeChecker.isWhatViaTarget(target);
  }
}
