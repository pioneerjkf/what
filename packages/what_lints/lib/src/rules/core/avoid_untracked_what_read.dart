// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule prohibiting direct, untracked reactive payload extraction (`untracked(what)`, `untracked.state(what)`, `.data`, `.snapshot`, etc.)
/// inside explicit `WhatVia` scopes without establishing dependency registration via `via()`.
///
/// ### Rationale:
/// What uses explicit `WhatVia` dependency manifests (`computed((via) => ...)`, `composed((context, via) => ...)`,
/// `switched((via) => ...)`, `Effect((via) => ...)`, `WhatWidget.build(context, via)`) to achieve
/// zero-overhead raw reads with zero implicit tracking scope.
///
/// Reading a reactive node's payload directly via `untracked(node)`, `untracked.state(node)`, or controller `.data` inside a `WhatVia`
/// scope without wrapping it with `via(node)` or `via.state(node)` bypasses LPDAG edge creation. Consequently, when the
/// upstream state mutates, the downstream derivation or widget **fails to invalidate and recalculate**
/// (the fatal "silent unreactivity" bug).
///
/// **BAD:**
/// ```dart
/// final doubled = computed((via) {
///   return untracked(counterWhat) * 2; // [Anti-Pattern] Unregistered dependency (silent bug: never recomputes!)
/// });
///
/// class CounterWidget extends WhatWidget {
///   Widget build(BuildContext context, WhatVia via) {
///     return Text('${untracked(counterWhat)}'); // [Anti-Pattern] Never rebuilds on count updates!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final doubled = computed((via) {
///   return via(counterWhat) * 2; // [Recommended] Explicit LPDAG edge registered
/// });
///
/// class CounterWidget extends WhatWidget {
///   Widget build(BuildContext context, WhatVia via) {
///     return Text('${via(counterWhat)}'); // [Recommended] Dynamic dependency tracked
///   }
/// }
/// ```
class AvoidUntrackedWhatRead extends DartLintRule {
  AvoidUntrackedWhatRead() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_untracked_what_read',
    problemMessage:
        'Avoid reading reactive payload directly (\'{0}\') inside WhatVia scopes without calling via().',
    correctionMessage:
        'Wrap the reactive node with via(node) or via.state(node) to establish dynamic dependency tracking.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const _castCode = LintCode(
    name: 'avoid_untracked_what_read',
    problemMessage:
        'Avoid casting What node to WhatState inside WhatVia scopes to bypass reactive tracking.',
    correctionMessage:
        'Use via(node) or via.state(node) instead of manual casting to establish dynamic dependency tracking.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const _untrackedCode = LintCode(
    name: 'avoid_untracked_what_read',
    problemMessage:
        'Avoid calling untracked(...) inside WhatVia scopes without establishing dependency tracking.',
    correctionMessage:
        'Use via(node) or via.state(node) instead of untracked(...) to establish dynamic dependency tracking.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  List<Fix> getFixes() => [WrapWithViaFix()];

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // 1. PropertyAccess (e.g. this.counter.data, state.what.snapshot)
    context.registry.addPropertyAccess((node) {
      final propName = node.propertyName.name;
      if (WhatTypeChecker.isPipelineReadProperty(propName)) {
        if (WhatTypeChecker.isTrackableWhatTarget(node.target)) {
          if (isUntrackedInWhatViaScope(node)) {
            reporter.atNode(node, _code, arguments: [propName]);
          }
        }
      }
    });

    // 2. PrefixedIdentifier (e.g. counter.data, userWhat.snapshot)
    context.registry.addPrefixedIdentifier((node) {
      final propName = node.identifier.name;
      if (WhatTypeChecker.isPipelineReadProperty(propName)) {
        if (WhatTypeChecker.isTrackableWhatTarget(node.prefix)) {
          if (isUntrackedInWhatViaScope(node)) {
            reporter.atNode(node, _code, arguments: [propName]);
          }
        }
      }
    });

    // 3. MethodInvocation (e.g. counter.dataOrElse(...), untracked.state(...))
    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name;
      if (WhatTypeChecker.isPipelineReadMethod(methodName)) {
        if (WhatTypeChecker.isTrackableWhatTarget(node.target)) {
          if (isUntrackedInWhatViaScope(node)) {
            reporter.atNode(node, _code, arguments: [methodName]);
          }
        }
      } else if (WhatTypeChecker.isWhatUntrackedInvocation(node)) {
        if (isUntrackedInWhatViaScope(node)) {
          reporter.atNode(node, _untrackedCode);
        }
      }
    });

    // 4. FunctionExpressionInvocation (e.g. untracked(node))
    context.registry.addFunctionExpressionInvocation((node) {
      if (WhatTypeChecker.isWhatUntrackedInvocation(node)) {
        if (isUntrackedInWhatViaScope(node)) {
          reporter.atNode(node, _untrackedCode);
        }
      }
    });

    // 5. AsExpression (e.g. count as WhatState)
    context.registry.addAsExpression((node) {
      if (isUntrackedInWhatViaScope(node)) {
        final targetType = node.type.type;
        if (targetType != null &&
            WhatTypeChecker.isWhatStateClass(targetType)) {
          final exprType = node.expression.unParenthesized.staticType;
          if (exprType != null && WhatTypeChecker.isWhatClass(exprType)) {
            reporter.atNode(node, _castCode);
          }
        }
      }
    });
  }

  /// Checks if the AST [node] is inside an active `WhatVia` scope and NOT deferred inside an event handler or via() call.
  static bool isUntrackedInWhatViaScope(AstNode node) {
    if (!isInsideWhatViaScope(node)) return false;
    if (isInsideDeferredEventOrAsyncCallback(node)) return false;
    if (isAlreadyTrackedByVia(node)) return false;
    return true;
  }

  /// Checks if the [node] is deferred inside an event handler parameter (e.g. onPressed) or async timer closure.
  static bool isInsideDeferredEventOrAsyncCallback(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      // 1. If inside an event callback parameter (e.g. onPressed: () => ..., onTap: () => ...)
      if (current is NamedExpression) {
        final paramName = current.name.label.name;
        if (WhatTypeChecker.isEventCallbackParameter(paramName)) {
          return true;
        }
      }

      // 2. If inside async dispatchers (e.g. Timer.run, scheduleMicrotask)
      if (current is MethodInvocation) {
        if (WhatTypeChecker.isAsyncOrTimerInvocation(current)) {
          return true;
        }
      }

      // 3. If inside a terminal side-effect action or listener callback
      if (WhatTypeChecker.isTerminalOrEffectInvocation(current)) {
        return true;
      }

      // Stop once we reach the enclosing WhatVia scope boundary
      if (current is MethodDeclaration &&
          WhatTypeChecker.isWhatWidgetBuildMethod(current)) {
        break;
      }
      if (current is FunctionExpression) {
        final params = current.parameters?.parameters;
        if (params != null && params.any(WhatTypeChecker.isWhatViaParameter)) {
          break;
        }
      }

      current = current.parent;
    }
    return false;
  }

  /// Returns `true` if the [node] is physically enclosed inside a `WhatVia` manifest scope
  /// (`WhatWidget.build`, `computed`, `composed`, `switched`, `Effect`, or closure with `via` parameter).
  static bool isInsideWhatViaScope(AstNode node) =>
      WhatTypeChecker.isInsideWhatViaScope(node);

  /// Returns `true` if the [node] is already tracked via `via(node).prop` or inside `via(...)`.
  static bool isAlreadyTrackedByVia(AstNode node) {
    // 1. If target is directly a via() invocation, via.state(), or alias thereof
    if (node is PropertyAccess) {
      if (_isExpressionTrackedByVia(node.target)) {
        return true;
      }
    }

    if (node is PrefixedIdentifier) {
      if (_isExpressionTrackedByVia(node.prefix)) {
        return true;
      }
    }

    if (node is MethodInvocation) {
      if (_isExpressionTrackedByVia(node.target)) {
        return true;
      }
    }

    // 2. If node is an argument to via(...) (e.g. via(node))
    AstNode? current = node.parent;
    while (current != null) {
      if (WhatTypeChecker.isWhatViaInvocation(current)) {
        return true;
      }
      // via(...) is an expression invocation, so searching beyond a statement
      // or declaration boundary is unnecessary and wasteful.
      if (current is Statement || current is Declaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }

  static bool _isExpressionTrackedByVia(Expression? expr) {
    if (expr == null) return false;
    final unwrapped = expr.unParenthesized;
    if (WhatTypeChecker.isWhatViaInvocation(unwrapped)) return true;
    if (_isAliasOfViaInvocation(unwrapped)) return true;
    if (unwrapped is PropertyAccess) {
      return _isExpressionTrackedByVia(unwrapped.target);
    }
    if (unwrapped is PrefixedIdentifier) {
      return _isExpressionTrackedByVia(unwrapped.prefix);
    }
    if (unwrapped is MethodInvocation) {
      return _isExpressionTrackedByVia(unwrapped.target);
    }
    return false;
  }

  static bool _isAliasOfViaInvocation(Expression? expr) {
    if (expr is! SimpleIdentifier) return false;
    final element = expr.element;

    // Search the enclosing root FunctionBody to support local variable lookups across closures
    final body = _findEnclosingRootFunctionBody(expr);
    if (body == null) return false;

    bool isTracked = false;
    if (element != null) {
      body.accept(_VariableFinder(element, (decl) {
        if (decl.initializer != null &&
            _isExpressionTrackedByVia(decl.initializer)) {
          isTracked = true;
        }
      }));
    } else {
      final targetName = expr.name;
      body.accept(_UnresolvedVariableFinder(targetName, (decl) {
        if (decl.initializer != null &&
            _isExpressionTrackedByVia(decl.initializer)) {
          isTracked = true;
        }
      }));
    }
    return isTracked;
  }

  /// Finds the outermost enclosing [FunctionBody] within the lexical method or function scope.
  static FunctionBody? _findEnclosingRootFunctionBody(Expression expr) {
    FunctionBody? rootBody;
    AstNode? current = expr.parent;
    while (current != null) {
      if (current is FunctionBody) {
        rootBody = current;
      }
      if (current is MethodDeclaration ||
          current is FunctionDeclaration ||
          current is ConstructorDeclaration) {
        break;
      }
      current = current.parent;
    }
    return rootBody;
  }
}

class _VariableFinder extends RecursiveAstVisitor<void> {
  final Element targetElement;
  final void Function(VariableDeclaration) onFound;

  _VariableFinder(this.targetElement, this.onFound);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.declaredFragment?.element == targetElement) {
      onFound(node);
    }
    super.visitVariableDeclaration(node);
  }
}

class _UnresolvedVariableFinder extends RecursiveAstVisitor<void> {
  final String targetName;
  final void Function(VariableDeclaration) onFound;

  _UnresolvedVariableFinder(this.targetName, this.onFound);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.lexeme == targetName) {
      onFound(node);
    }
    super.visitVariableDeclaration(node);
  }
}
