// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../what_lints.dart';

/// General-purpose AST utility helpers for analyzing Flutter framework patterns.
abstract final class FlutterAstUtils {
  /// Returns `true` if the [method] represents a Flutter widget build method
  /// (e.g. `Widget build(BuildContext context)`).
  static bool isWidgetBuildMethod(MethodDeclaration method) {
    if (method.name.lexeme != 'build') return false;

    // 1. Check if parameters include BuildContext
    final parameters = method.parameters?.parameters;
    if (parameters != null && parameters.isNotEmpty) {
      for (final param in parameters) {
        if (param is SimpleFormalParameter) {
          final typeStr = param.type?.toSource();
          if (typeStr == 'BuildContext' || typeStr == 'BuildContext?') {
            return true;
          }
          final paramElement = param.declaredFragment?.element;
          if (paramElement != null) {
            final paramType = paramElement.type.getDisplayString();
            if (paramType.startsWith('BuildContext')) {
              return true;
            }
          }
        }
      }
    }

    // 2. Check if return type is Widget
    final returnTypeStr = method.returnType?.toSource();
    if (returnTypeStr == 'Widget' || returnTypeStr == 'Widget?') {
      return true;
    }

    return false;
  }

  /// Returns `true` if the AST [node] is enclosed inside a Flutter widget `build` method.
  static bool isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration && isWidgetBuildMethod(current)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Returns `true` if the class declaration [node] extends Flutter's `State`.
  static bool isStateClass(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) return false;
    final supertype = extendsClause.superclass.name.lexeme;
    return supertype == 'State';
  }

  /// Returns `true` if the [node] represents a synchronous What pipeline invocation,
  /// an `Effect` instance creation, a closure receiving `WhatVia`, or a Flutter widget `build` method.
  static bool isPipelineOrBuildNode(AstNode node) {
    if ((node is MethodInvocation || node is FunctionExpressionInvocation) &&
        WhatTypeChecker.isWhatPipelineInvocation(node)) {
      return true;
    }
    if (node is InstanceCreationExpression) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'Effect') {
        return true;
      }
    }
    if (node is FunctionExpression) {
      final params = node.parameters?.parameters;
      if (params != null && params.any(WhatTypeChecker.isWhatViaParameter)) {
        return true;
      }
    }
    if (node is MethodDeclaration && isWidgetBuildMethod(node)) {
      return true;
    }
    return false;
  }

  /// Returns `true` if the AST [node] is enclosed inside a synchronous What pipeline invocation
  /// or a Flutter widget `build` method.
  static bool isInsidePipelineOrBuild(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (isPipelineOrBuildNode(current)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if the [node] is deferred inside an event handler, asynchronous closure,
  /// or frame callback (e.g. `addPostFrameCallback`, `Timer`, `Future`).
  /// Also treats local function declarations as deferred (unless synchronously invoked).
  static bool isInsideEventOrDeferredClosure(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      // 1. Event callback parameter (e.g. onPressed: () => ...)
      if (current is NamedExpression) {
        final paramName = current.name.label.name;
        if (WhatTypeChecker.isEventCallbackParameter(paramName)) {
          return true;
        }
      }

      // 2. Async dispatchers and frame callbacks
      if (current is MethodInvocation) {
        final name = current.methodName.name;
        if (WhatTypeChecker.isAsyncOrTimerInvocation(current) ||
            name == 'addPostFrameCallback' ||
            name == 'scheduleFrameCallback' ||
            name == 'addPersistentFrameCallback' ||
            name == 'listen') {
          return true;
        }
      }

      if (current is InstanceCreationExpression) {
        final typeName = current.constructorName.type.name.lexeme;
        if (typeName == 'Timer' || typeName == 'Future') {
          return true;
        }
      }

      // 3. Local function declarations
      if (current is FunctionDeclaration) {
        // If it's a local function, we treat it as deferred handler by default,
        // unless there's evidence it is called synchronously in the same block,
        // but for simplicity in AST walking, local functions are deferred.
        if (current.parent is FunctionDeclarationStatement) {
          return true;
        }
      }

      // 4. If inside synchronous What pipeline invocations or Flutter widget build, NOT SAFE!
      if (isPipelineOrBuildNode(current)) {
        return false;
      }

      current = current.parent;
    }

    return true;
  }

  /// Returns `true` if the given [type] implements or extends Flutter's `Widget`.
  static bool isWidgetType(DartType? type) {
    if (type == null || type is! InterfaceType) return false;
    final element = type.element;
    if (element.name == 'Widget' && _isFlutterWidgetsLibrary(element.library)) {
      return true;
    }
    for (final superType in type.allSupertypes) {
      if (superType.element.name == 'Widget' &&
          _isFlutterWidgetsLibrary(superType.element.library)) {
        return true;
      }
    }
    return false;
  }

  static bool _isFlutterWidgetsLibrary(LibraryElement? lib) {
    if (lib == null) return false;
    final id = lib.identifier;
    return id.startsWith('package:flutter/') || lib.name == 'flutter.widgets';
  }
}
