// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule warning when a `computed` or `switched` scope declares a `via` parameter but never uses it.
///
/// ### Rationale:
/// Reactive derivation nodes (`computed`, `switched`) exist to dynamically track upstream dependencies
/// via explicit `via(node)` observation calls.
/// Creating a reactive scope that never accesses `via` creates unnecessary DAG graph overhead, allocation pressure,
/// and re-evaluation churn for values that never change reactively.
///
/// **BAD:**
/// ```dart
/// final constantVal = computed((via) { // [Anti-Pattern] via is never used!
///   return 10 + 20;
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // Approach 1: Static node via What.constant or standard final variable
/// final staticConfig = What.constant(30);
/// final constantVal = 10 + 20;
///
/// // Approach 2: Actively tracking dependencies via via(node)
/// final sum = computed((via) {
///   return via(aWhat) + via(bWhat); // [Recommended] Explicit dynamic dependencies tracked
/// });
/// ```
class AvoidUnnecessaryViaScope extends DartLintRule {
  AvoidUnnecessaryViaScope() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_unnecessary_via_scope',
    problemMessage:
        'The reactive closure declares \'via\' but never tracks any upstream dependencies.',
    correctionMessage:
        'Call via(what) to track dependencies, or replace this reactive node with a standard final variable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void checkArguments(ArgumentList argumentList) {
      final args = argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;
      if (firstArg is FunctionExpression) {
        if (isUnnecessaryViaClosure(firstArg)) {
          reporter.atNode(firstArg, _code);
        }
      }
    }

    context.registry.addFunctionExpressionInvocation((node) {
      final name = WhatTypeChecker.resolveFunctorName(node);
      if (name == 'ComputedFunctor' ||
          name == 'SwitchedFunctor' ||
          name == 'ComputedStreamFunctor' ||
          name == 'ComputedFutureFunctor') {
        checkArguments(node.argumentList);
      }
    });

    context.registry.addMethodInvocation((node) {
      final name = WhatTypeChecker.resolveFunctorName(node);
      if (name == 'ComputedFunctor' ||
          name == 'SwitchedFunctor' ||
          name == 'ComputedStreamFunctor' ||
          name == 'ComputedFutureFunctor') {
        checkArguments(node.argumentList);
      }
    });
  }

  /// Returns `true` if [closure] accepts a `via` parameter but never calls `via(...)` or references `via`.
  static bool isUnnecessaryViaClosure(FunctionExpression closure) {
    final params = closure.parameters?.parameters;
    if (params == null || params.isEmpty) return false;

    FormalParameter? viaParam;
    for (final p in params) {
      if (WhatTypeChecker.isWhatViaParameter(p)) {
        viaParam = p;
        break;
      }
    }
    if (viaParam == null) return false;

    final viaName = viaParam.name?.lexeme ?? 'via';
    var usesVia = false;

    closure.body.visitChildren(_IdentifierVisitor((name) {
      if (name == viaName) {
        usesVia = true;
      }
    }));

    return !usesVia;
  }
}

class _IdentifierVisitor extends RecursiveAstVisitor<void> {
  _IdentifierVisitor(this.onFound);
  final void Function(String name) onFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    onFound(node.name);
    super.visitSimpleIdentifier(node);
  }
}
