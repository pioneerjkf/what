// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule prohibiting synchronous state writes or topology modifications inside reactive pipelines and build passes.
///
/// ### Rationale:
/// In reactive DAG architectures, evaluation passes (`computed`, `switched`, `managed`, `composed`, Flutter `build`)
/// must remain side-effect-free.
///
/// Performing state writes (`controller.set()`, `controller.data = ...`) or topological mutations
/// synchronously inside evaluation passes causes immediate reentrancy errors or infinite render loops.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   counterController.set(10); // [Anti-Pattern] Synchronous state write during build!
///   return const SizedBox();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return ElevatedButton(
///     onPressed: () => counterController.set(10), // [Recommended] Safe asynchronous event handler
///     child: const Text('Reset'),
///   );
/// }
/// ```
class AvoidStateWritesInPipeline extends DartLintRule {
  AvoidStateWritesInPipeline() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_state_writes_in_pipeline',
    problemMessage:
        'Avoid writing state or modifying graph topology directly inside reactive pipeline evaluation or build scopes.',
    correctionMessage:
        'Perform state writes inside event handlers (e.g. onPressed), async dispatchers, or lifecycle hooks.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // 1. Direct registry hook for state write method invocations (controller.set, coupler.couple, terminal.swapSource, etc.)
    context.registry.addMethodInvocation((node) {
      if (WhatTypeChecker.isPipelineWriteMethod(node.methodName.name)) {
        if (!isFromWhatPackageOrTarget(node)) return;
        if (!isInsidePipelineMethod(node)) return;
        if (isInsideEventOrDeferredClosure(node)) return;

        reporter.atNode(node, _code);
      }
    });

    // 2. Direct registry hook for property setter assignments (what.data = ..., controller.data = ...)
    context.registry.addAssignmentExpression((node) {
      final propName = _extractPropertyName(node.leftHandSide);
      if (WhatTypeChecker.isPipelineWriteProperty(propName)) {
        if (!isAssignmentToWhatProperty(node)) return;
        if (!isInsidePipelineMethod(node)) return;
        if (isInsideEventOrDeferredClosure(node)) return;

        reporter.atNode(node, _code);
      }
    });
  }

  static String? _extractPropertyName(Expression leftHandSide) {
    if (leftHandSide is PropertyAccess) {
      return leftHandSide.propertyName.name;
    }
    if (leftHandSide is PrefixedIdentifier) {
      return leftHandSide.identifier.name;
    }
    return null;
  }

  /// Checks if the [node] is inside a pipeline method or a Flutter widget build method.
  static bool isInsidePipelineMethod(AstNode node) =>
      FlutterAstUtils.isInsidePipelineOrBuild(node);

  /// Checks if the [node] is deferred inside an event handler or asynchronous closure.
  static bool isInsideEventOrDeferredClosure(AstNode node) =>
      FlutterAstUtils.isInsideEventOrDeferredClosure(node);

  /// Returns `true` if the method invocation [node] targets a What package element or trackable What target.
  static bool isFromWhatPackageOrTarget(MethodInvocation node) {
    final element = node.methodName.element;
    if (element != null && WhatTypeChecker.isFromWhatPackage(element)) {
      return true;
    }
    final target = node.realTarget;
    if (target != null && WhatTypeChecker.isTrackableWhatTarget(target)) {
      return true;
    }
    // Unresolved fallback
    if (element == null && target?.staticType == null) {
      return true;
    }
    return false;
  }

  /// Returns `true` if the assignment [node] targets a What property.
  static bool isAssignmentToWhatProperty(AssignmentExpression node) {
    final lhs = node.leftHandSide;
    Element? element;
    Expression? target;
    if (lhs is PropertyAccess) {
      element = lhs.propertyName.element;
      target = lhs.target;
    } else if (lhs is PrefixedIdentifier) {
      element = lhs.identifier.element;
      target = lhs.prefix;
    }

    if (element != null && WhatTypeChecker.isFromWhatPackage(element)) {
      return true;
    }
    if (target != null && WhatTypeChecker.isTrackableWhatTarget(target)) {
      return true;
    }
    // Unresolved fallback
    if (element == null && target?.staticType == null) {
      return true;
    }
    return false;
  }
}
