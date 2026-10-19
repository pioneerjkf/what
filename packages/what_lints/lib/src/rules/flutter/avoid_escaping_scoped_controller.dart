// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule prohibiting escaping `ScopedAnimationController` or its `view`
/// outside the widget builder scope.
///
/// ### Rationale:
/// `ScopedAnimationController` (and its `.view` property) is an ephemeral handle tied
/// strictly to a mounted widget element's builder lifecycle.
///
/// Storing `ScopedAnimationController` or its `.view` in class fields, top-level variables,
/// outer closures, or long-lived collections causes:
/// 1. **Dangling / Stale Listeners**: Retaining references to unmounted proxy views.
/// 2. **Runtime Lifecycle Assertion Errors**: Calling mutating methods or attaching listeners to
///    a disposed proxy throws `AssertionError`.
/// 3. **Memory Leaks**: Preventing garbage collection of element-coupled animation states.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   Animation<double>? _cachedView; // [Anti-Pattern] Escaping field
///
///   @override
///   Widget build(BuildContext context) {
///     return controller.animate((via, ctrl) {
///       _cachedView = ctrl.view; // [Anti-Pattern] Escaping into outer field!
///       return FadeTransition(opacity: ctrl.view, child: const SizedBox());
///     });
///   }
/// }
///
/// class MyStore {
///   ScopedAnimationController? controller; // [Anti-Pattern] Holding scoped controller in store!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   @override
///   Widget build(BuildContext context) {
///     return controller.animate((via, ctrl) {
///       return FadeTransition(opacity: ctrl.view, child: const SizedBox());
///     });
///   }
/// }
///
/// class MyStore {
///   // [Recommended] Hold durable root controller in stores/states
///   final controller = DurableAnimationController(duration: const Duration(seconds: 1));
/// }
/// ```
class AvoidEscapingScopedController extends DartLintRule {
  AvoidEscapingScopedController() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_escaping_scoped_controller',
    problemMessage:
        'Avoid escaping ScopedAnimationController or its view outside the widget builder scope.',
    correctionMessage:
        'Use ScopedAnimationController and its view strictly within the mounted widget builder, or hold DurableAnimationController in your state/store instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // 1. Detect field declarations of type ScopedAnimationController
    context.registry.addFieldDeclaration((node) {
      if (isScopedControllerType(node.fields.type)) {
        reporter.atNode(node, _code);
      }
    });

    // 2. Detect top-level variable declarations of type ScopedAnimationController
    context.registry.addTopLevelVariableDeclaration((node) {
      if (isScopedControllerType(node.variables.type)) {
        reporter.atNode(node, _code);
      }
    });

    // 3. Detect method/function declarations with return type ScopedAnimationController
    context.registry.addMethodDeclaration((node) {
      if (isScopedControllerType(node.returnType)) {
        reporter.atNode(node.returnType ?? node, _code);
      }
    });

    context.registry.addFunctionDeclaration((node) {
      if (isScopedControllerType(node.returnType)) {
        reporter.atNode(node.returnType ?? node, _code);
      }
    });

    // 4. Detect assignments escaping ScopedAnimationController or ctrl.view / ctrl.drive(...)
    context.registry.addAssignmentExpression((node) {
      if (!isScopedControllerOrViewExpr(node.rightHandSide)) return;

      if (isEscapingTarget(node.leftHandSide, node)) {
        reporter.atNode(node, _code);
      }
    });

    // 5. Detect adding ScopedAnimationController or ctrl.view to outer collections
    context.registry.addMethodInvocation((node) {
      final name = node.methodName.name;
      if (name == 'add' ||
          name == 'addAll' ||
          name == 'insert' ||
          name == 'insertAll') {
        for (final arg in node.argumentList.arguments) {
          final actualArg = arg is NamedExpression ? arg.expression : arg;
          if (isScopedControllerOrViewExpr(actualArg)) {
            final target = node.target;
            if (target == null || isEscapingTarget(target, node)) {
              reporter.atNode(arg, _code);
            }
          }
        }
      }
    });
  }

  /// Checks if [type] represents `ScopedAnimationController`.
  static bool isScopedControllerType(TypeAnnotation? type) {
    if (type == null) return false;
    final staticType = type.type;
    if (staticType != null &&
        staticType is! DynamicType &&
        staticType is! InvalidType) {
      if (WhatTypeChecker.isScopedAnimationController(staticType)) return true;
    }
    final source = type.toSource();
    return source.contains('ScopedAnimationController');
  }

  /// Checks if [expr] evaluates to `ScopedAnimationController`.
  static bool isScopedControllerExpr(Expression expr) {
    if (expr is ParenthesizedExpression) {
      return isScopedControllerExpr(expr.expression);
    }
    if (expr is AsExpression) {
      return isScopedControllerExpr(expr.expression);
    }

    final staticType = expr.staticType;
    if (staticType != null &&
        staticType is! DynamicType &&
        staticType is! InvalidType) {
      if (WhatTypeChecker.isScopedAnimationController(staticType)) {
        return true;
      }
    }

    if (expr is SimpleIdentifier) {
      if (_isScopedParameterIdentifier(expr)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if [expr] evaluates to `ScopedAnimationController`, its `.view`, or `.drive(...)`.
  static bool isScopedControllerOrViewExpr(Expression expr) {
    if (isScopedControllerExpr(expr)) return true;

    if (expr is ParenthesizedExpression) {
      return isScopedControllerOrViewExpr(expr.expression);
    }
    if (expr is AsExpression) {
      return isScopedControllerOrViewExpr(expr.expression);
    }

    // PropertyAccess: ctrl.view
    if (expr is PropertyAccess && expr.propertyName.name == 'view') {
      final target = expr.target;
      if (target != null && isScopedControllerExpr(target)) return true;
    }

    // PrefixedIdentifier: ctrl.view
    if (expr is PrefixedIdentifier && expr.identifier.name == 'view') {
      if (isScopedControllerExpr(expr.prefix)) return true;
    }

    // MethodInvocation: ctrl.drive(...)
    if (expr is MethodInvocation && expr.methodName.name == 'drive') {
      final target = expr.target;
      if (target != null && isScopedControllerExpr(target)) return true;
    }

    return false;
  }

  /// Checks if [target] represents an outer variable, class field, or property that escapes the builder closure.
  static bool isEscapingTarget(Expression target, AstNode contextNode) {
    if (target is PropertyAccess) {
      return true;
    }

    if (target is PrefixedIdentifier) {
      return true;
    }

    if (target is IndexExpression) {
      final subTarget = target.target;
      if (subTarget != null) {
        return isEscapingTarget(subTarget, contextNode);
      }
      return true;
    }

    if (target is SimpleIdentifier) {
      final enclosingClosure = _findEnclosingFunctionExpression(contextNode);
      if (enclosingClosure == null) {
        return true;
      }

      final element = target.element;
      return !_isDeclaredInClosure(target.name, element, enclosingClosure);
    }

    return false;
  }

  static FunctionExpression? _findEnclosingFunctionExpression(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        return current;
      }
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return null;
  }

  static bool _isScopedParameterIdentifier(SimpleIdentifier identifier) {
    final name = identifier.name;
    AstNode? current = identifier.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        final params = current.parameters?.parameters;
        if (params != null) {
          for (final p in params) {
            final actual = p is DefaultFormalParameter ? p.parameter : p;
            if (actual is SimpleFormalParameter &&
                actual.name?.lexeme == name) {
              final typeStr = actual.type?.toSource();
              if (typeStr != null &&
                  typeStr.contains('ScopedAnimationController')) {
                return true;
              }
              if (name == 'ctrl' || name == 'controller') {
                if (_isInsideScopedAnimationBuilder(current)) {
                  return true;
                }
              }
            }
          }
        }
      }
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }

  static bool _isInsideScopedAnimationBuilder(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final methodName = current.methodName.name;
        if (methodName == 'animate' ||
            methodName == 'builder' ||
            methodName == 'child' ||
            methodName == 'children' ||
            methodName == 'layout') {
          return true;
        }
      }
      if (current is FunctionExpressionInvocation) {
        final funcSource = current.function.toSource();
        if (funcSource.contains('animate')) {
          return true;
        }
      }
      if (current is NamedExpression) {
        final paramName = current.name.label.name;
        if (paramName == 'onActivate' || paramName == 'onDeactivate') {
          return true;
        }
      }
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }

  static bool _isDeclaredInClosure(
    String variableName,
    Element? targetElement,
    FunctionExpression closure,
  ) {
    var found = false;
    closure.body.visitChildren(_VariableDeclarationFinder(
      variableName,
      targetElement,
      () => found = true,
    ));
    return found;
  }
}

class _VariableDeclarationFinder extends RecursiveAstVisitor<void> {
  _VariableDeclarationFinder(this.name, this.targetElement, this.onFound);

  final String name;
  final Element? targetElement;
  final void Function() onFound;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (targetElement != null) {
      if (node.declaredFragment?.element == targetElement) {
        onFound();
        return;
      }
    }
    if (node.name.lexeme == name) {
      onFound();
      return;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Nested closures do not declare variables in the outer builder scope
  }
}
