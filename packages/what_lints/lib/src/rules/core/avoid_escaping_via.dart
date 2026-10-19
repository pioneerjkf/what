// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule prohibiting calling `WhatVia` across asynchronous gaps (after `await`),
/// inside asynchronous dispatchers, or deferred within UI event callbacks.
///
/// ### Rationale:
/// `WhatVia` (`via(node)`) represents an explicit, ephemeral dependency tracking token valid
/// exclusively during the synchronous evaluation pass of a reactive scope (`computed`, `WhatWidget`, etc.).
///
/// Calling `via(...)` after an `await` statement, inside async dispatchers (`Timer.run`, `scheduleMicrotask`),
/// or deferred inside event callbacks (`onPressed`) causes:
/// 1. **Temporal Inconsistency (Tearing)**: Reading newer state mixed with stale pre-await data.
/// 2. **Broken Epoch Sweeping**: Attempting to inject dependencies into an already-closed evaluation epoch.
/// 3. **Memory Leaks and Race Conditions**: Conflicting edges between overlapping async evaluations.
///
/// **BAD:**
/// ```dart
/// final userProfile = computed.future((via) async {
///   final id = via(userIdWhat);
///   final profile = await http.get('/user/$id');
///   final token = via(authTokenWhat); // [Anti-Pattern] Called across async gap!
///   return filter(profile, token);
/// });
///
/// class MyWidget extends WhatWidget {
///   Widget build(BuildContext context, WhatVia via) {
///     return ElevatedButton(
///       onPressed: () => print(via(counterWhat)), // [Anti-Pattern] Escaped into event callback!
///       child: const Text('Tap'),
///     );
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Approach 1: Extract all dependencies synchronously before the async gap
/// final userProfile = computed.future((via) async {
///   final id = via(userIdWhat);
///   final token = via(authTokenWhat); // [Recommended] Synchronously tracked before await
///   final profile = await http.get('/user/$id');
///   return filter(profile, token);
/// });
///
/// // Approach 2: Use zero-overhead raw reads (.peek) inside event callbacks
/// class MyWidget extends WhatWidget {
///   Widget build(BuildContext context, WhatVia via) {
///     return ElevatedButton(
///       onPressed: () => print(counterWhat.peek), // [Recommended] Safe raw read without tracking
///       child: const Text('Tap'),
///     );
///   }
/// }
/// ```
class AvoidEscapingVia extends DartLintRule {
  AvoidEscapingVia() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_escaping_via',
    problemMessage:
        'Avoid calling via() across asynchronous gaps (after await) or deferred inside event/async callbacks.',
    correctionMessage:
        'Extract all reactive dependencies via(node) synchronously before await, or use raw .peek reads inside event callbacks.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (!WhatTypeChecker.isWhatViaInvocation(node)) return;

      if (isEscapingViaInvocation(node)) {
        reporter.atNode(node, _code);
      }
    });

    context.registry.addFunctionExpressionInvocation((node) {
      if (!WhatTypeChecker.isWhatViaInvocation(node)) return;

      if (isEscapingViaInvocation(node)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// Checks if [node] is called across an asynchronous gap, inside an async timer/dispatcher,
  /// or deferred inside an event handler.
  static bool isEscapingViaInvocation(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      // 1. Check if inside event handler parameter (e.g. onPressed, onTap)
      if (current is NamedExpression) {
        final paramName = current.name.label.name;
        if (WhatTypeChecker.isEventCallbackParameter(paramName)) {
          return true;
        }
      }

      // 2. Check if inside async dispatchers (e.g. Timer.run, scheduleMicrotask)
      if (current is MethodInvocation) {
        if (WhatTypeChecker.isAsyncOrTimerInvocation(current)) {
          return true;
        }
      }

      // 3. Check if inside an asynchronous function body, after an await expression
      if (current is FunctionBody) {
        if (current.isAsynchronous) {
          if (_isPrecededByAwait(current, node)) {
            return true;
          }
        }
      }

      // Stop once we escape beyond the method declaration or top-level function
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }

      current = current.parent;
    }

    return false;
  }

  /// Checks if there is any [AwaitExpression] preceding [node] within [body].
  static bool _isPrecededByAwait(FunctionBody body, AstNode node) {
    final nodeOffset = node.offset;
    var foundPrecedingAwait = false;

    body.visitChildren(_AwaitFinder((awaitNode) {
      if (awaitNode.offset < nodeOffset) {
        foundPrecedingAwait = true;
      }
    }));

    return foundPrecedingAwait;
  }
}

class _AwaitFinder extends RecursiveAstVisitor<void> {
  _AwaitFinder(this.onFound);
  final void Function(AwaitExpression) onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound(node);
    super.visitAwaitExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Do not recurse into nested closures or local functions; awaits inside them
    // do not suspend the enclosing asynchronous function body.
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Do not recurse into nested local function declarations.
  }
}
