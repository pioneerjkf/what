// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule prohibiting catching broad exceptions around `via()` calls inside reactive scopes.
///
/// ### Rationale:
/// What uses a lightweight internal short-circuit sentinel (`_ViaShortCircuit`) to instantly
/// drop downstream derivation evaluation and propagate `Empty` or `Error` states synchronously
/// with zero allocations.
///
/// Wrapping `via(...)` calls in a broad `try/catch` (`catch (_)`, `on Object`, `on Exception`,
/// `on Error`) inadvertently intercepts this sentinel, breaking What's 3-state propagation and
/// silently corrupting downstream reactive semantics.
///
/// **BAD:**
/// ```dart
/// final derived = computed((via) {
///   try {
///     return via(sourceWhat) + 1; // [Anti-Pattern] Intercepts short-circuit sentinel!
///   } catch (e) {
///     return 0;
///   }
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// final derived = computed((via) {
///   final value = via(sourceWhat); // [Recommended] Short-circuit escapes unhindered
///   try {
///     return parseValue(value);
///   } on FormatException catch (e) {
///     return 0; // Catches only specific business exception
///   }
/// });
/// ```
class AvoidCatchingViaShortCircuit extends DartLintRule {
  AvoidCatchingViaShortCircuit() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_catching_via_short_circuit',
    problemMessage:
        'Avoid catching broad exceptions around via() calls inside reactive scopes.',
    correctionMessage:
        'Move via() calls outside the try block or catch only specific domain exceptions to allow What\'s short-circuit sentinel to propagate.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const broadExceptionTypes = {
    'Object',
    'dynamic',
    'Exception',
    'Error',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((node) {
      if (!WhatTypeChecker.isInsideWhatViaScope(node)) return;
      if (AvoidUntrackedWhatRead.isInsideDeferredEventOrAsyncCallback(node)) {
        return;
      }

      // Check if node.body contains any via() or via.state() invocation
      final finder = _ViaInvocationFinder();
      node.body.accept(finder);
      if (!finder.hasViaInvocation) return;

      for (final catchClause in node.catchClauses) {
        if (isCatchClauseRethrowing(catchClause)) continue;

        final typeName = catchClause.exceptionType?.toSource();
        if (typeName == null || broadExceptionTypes.contains(typeName)) {
          reporter.atNode(catchClause, _code);
        }
      }
    });
  }

  /// Returns `true` if the given catch [clause] rethrows its exception.
  static bool isCatchClauseRethrowing(CatchClause clause) {
    final statements = clause.body.statements;
    if (statements.isNotEmpty) {
      final last = statements.last;
      if (last is ExpressionStatement && last.expression is RethrowExpression) {
        return true;
      }
    }
    return false;
  }
}

class _ViaInvocationFinder extends RecursiveAstVisitor<void> {
  bool hasViaInvocation = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (WhatTypeChecker.isWhatViaInvocation(node)) {
      hasViaInvocation = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (WhatTypeChecker.isWhatViaInvocation(node)) {
      hasViaInvocation = true;
      return;
    }
    super.visitFunctionExpressionInvocation(node);
  }
}
