// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule that discourages calling reactive bridging methods (`.toWhat()`, `.toWhatBy()`, etc.)
/// directly inside Flutter `build()` methods or reactive derivation scopes (`computed`, `composed`).
///
/// ### Rationale:
/// In Flutter's rendering pipeline and What's reactive graph, `build()` methods and derivation
/// scopes can execute up to 120 times per second during active animations or updates.
/// Calling bridging methods like `.toWhat()` inside these scopes creates new reactive
/// pipelines on every single tick, causing GC thrashing and broken subscription caching.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final countWhat = valueNotifier.toWhat(); // [Anti-Pattern] New bridge allocation on every frame!
///   return Text('${untracked(countWhat)}');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Approach 1: Convert notifier/stream to What once in a State class
/// class _MyWidgetState extends State<MyWidget> {
///   late final What<int> _countWhat = widget.valueNotifier.toWhat();
///
///   Widget build(BuildContext context) =>
///       composed((context, via) => Text('${via(_countWhat)}'));
/// }
///
/// // Approach 2: Convert notifier/stream to What once at the state/controller layer
/// class StockController {
///   late final stockWhat = stockStream.toWhat(initialData: 0.0);
/// }
/// ```
class AvoidBridgingInBuild extends DartLintRule {
  AvoidBridgingInBuild() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_bridging_in_build',
    problemMessage:
        'Avoid calling reactive bridging methods or adapters (\'{0}\') inside build methods or reactive scopes.',
    correctionMessage:
        'Cache the bridged reactive node in a `late final` field on the Widget or outside the evaluation scope to avoid allocations.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // 1. Check bridging method invocations
    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name;
      if (WhatTypeChecker.isReactiveBridgingMethod(methodName)) {
        if (isInsideBuildOrReactiveScope(node)) {
          reporter.atNode(node, _code, arguments: [methodName]);
        }
      }
    });

    // 2. Check property adapter accesses
    context.registry.addPropertyAccess((node) {
      final propName = node.propertyName.name;
      if (WhatTypeChecker.isReactiveBridgingProperty(propName)) {
        if (isInsideBuildOrReactiveScope(node)) {
          reporter.atNode(node, _code, arguments: [propName]);
        }
      }
    });

    // 3. Check prefixed property adapter accesses
    context.registry.addPrefixedIdentifier((node) {
      final propName = node.identifier.name;
      if (WhatTypeChecker.isReactiveBridgingProperty(propName)) {
        if (isInsideBuildOrReactiveScope(node)) {
          reporter.atNode(node, _code, arguments: [propName]);
        }
      }
    });
  }

  /// Checks if the AST [node] is located within a Flutter `build()` method or a reactive derivation scope.
  static bool isInsideBuildOrReactiveScope(AstNode node) {
    if (FlutterAstUtils.isInsideBuildMethod(node)) return true;
    if (WhatTypeChecker.isInsideWhatViaScope(node)) return true;
    return false;
  }
}
