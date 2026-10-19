// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule prohibiting asynchronous closures or Future/Stream return types in `managed(...)`.
///
/// ### Rationale:
/// `managed` strictly supervises pure synchronous external resource lifecycles (`create`, `update`, `dispose`).
/// Passing an `async` closure to `create` or `update` causes Dart to infer `managed<Future<T>>`, supervising
/// the `Future` object itself instead of the underlying resource, preventing timely disposal and causing
/// catastrophic resource leaks.
///
/// Asynchronous data querying must be cleanly separated into `computed.future` or `computed.stream`.
///
/// **BAD:**
/// ```dart
/// final client = managed(
///   create: (via) async { // [Anti-Pattern] Async closure in managed!
///     final c = HttpClient();
///     await c.init();
///     return c;
///   },
///   dispose: (c) => c.close(),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Approach 1: Synchronous resource lifecycle in managed
/// final timer = managed<Timer>(
///   create: (via) => Timer.periodic(const Duration(seconds: 1), (t) => tick()),
///   dispose: (t) => t.cancel(),
/// );
///
/// // Approach 2: Asynchronous querying in computed.future
/// final clientData = computed.future((via) async {
///   final targetUrl = via(urlWhat); // [Recommended] Tracked synchronously before await
///   final c = HttpClient();
///   return await c.fetch(targetUrl);
/// });
/// ```
class AvoidAsyncInManaged extends DartLintRule {
  AvoidAsyncInManaged() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_async_in_managed',
    problemMessage:
        'Avoid passing asynchronous closures or Future/Stream types to managed().',
    correctionMessage:
        'Use synchronous closures for managed resource lifecycles, or use computed.future/computed.stream for async queries.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void checkArgumentList(ArgumentList argumentList) {
      for (final expr in findAsyncClosures(argumentList)) {
        reporter.atNode(expr, _code);
      }
    }

    context.registry.addFunctionExpressionInvocation((node) {
      if (WhatTypeChecker.resolveFunctorName(node) == 'ManagedFunctor') {
        checkArgumentList(node.argumentList);
      }
    });

    context.registry.addMethodInvocation((node) {
      if (WhatTypeChecker.resolveFunctorName(node) == 'ManagedFunctor') {
        checkArgumentList(node.argumentList);
      }
    });
  }

  /// Returns all asynchronous create/update/dispose [FunctionExpression]s in the given [argumentList].
  static List<FunctionExpression> findAsyncClosures(ArgumentList argumentList) {
    final asyncClosures = <FunctionExpression>[];
    for (final arg in argumentList.arguments) {
      if (arg is NamedExpression) {
        final paramName = arg.name.label.name;
        if (paramName == 'create' ||
            paramName == 'update' ||
            paramName == 'dispose') {
          final expr = arg.expression;
          if (expr is FunctionExpression && expr.body.isAsynchronous) {
            asyncClosures.add(expr);
          }
        }
      }
    }
    return asyncClosures;
  }

  /// Checks if the [node] invocation is a `managed` call containing an asynchronous create/update closure.
  static bool isAsyncClosureInManaged(MethodInvocation node) {
    if (node.methodName.name != 'managed') return false;
    return findAsyncClosures(node.argumentList).isNotEmpty;
  }
}
