// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule prohibiting instantiating What controllers, signals, effects, or reactive pipelines
/// directly inside Flutter `build()` methods.
///
/// ### Rationale:
/// Flutter `build()` methods are called repeatedly during animations, parent updates, and state mutations.
/// Instantiating controllers (`WhatController`), reactive pipelines (`computed`, `managed`, `switched`),
/// or side-effect terminals (`Effect`) directly inside `build()` causes:
/// 1. State reset on every single rebuild tick (loss of previous state).
/// 2. Severe memory leaks through dangling controllers and uncollected DAG nodes.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final counter = WhatController(0); // [Anti-Pattern] Recreated on every frame!
///   final doubled = computed((via) => via(counter.what) * 2); // [Anti-Pattern] Orphan pipeline node!
///   return Text('${untracked(doubled)}');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   const MyWidget({super.key});
///
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends State<MyWidget> {
///   late final WhatController<int> _counter;
///   late final What<int> _doubled;
///
///   @override
///   void initState() {
///     super.initState();
///     _counter = WhatController(0);
///     _doubled = computed((via) => via(_counter.what) * 2);
///   }
///
///   // Note: Pure WhatController instances are subscriber-driven and automatically
///   // collected by GC upon deactivation; manual disposal is not required.
///
///   @override
///   Widget build(BuildContext context) {
///     return composed((context, via) => Text('Count: ${via(_doubled)}'));
///   }
/// }
/// ```
class AvoidWhatCreationInBuild extends DartLintRule {
  AvoidWhatCreationInBuild() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_what_creation_in_build',
    problemMessage:
        'Avoid instantiating What controllers, signals, or reactive pipelines inside Flutter build() methods.',
    correctionMessage:
        'Move controller and pipeline instantiation to State.initState, top-level/static declarations, or DI scopes.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const _controllerAndTerminalConstructors = {
    'WhatController',
    'RawWhatController',
    'WhatListController',
    'WhatSetController',
    'WhatMapController',
    'WhatCoupler',
    'WhatSignal',
    'WhatSignalController',
    'Effect',
    'EffectRunner',
  };

  static const _forbiddenPipelineFunctors = {
    'computed',
    'switched',
    'managed',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // 1. Detect forbidden constructor invocations inside build()
    context.registry.addInstanceCreationExpression((node) {
      if (!isForbiddenCreation(node)) return;

      if (!FlutterAstUtils.isInsideBuildMethod(node)) return;
      if (AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(node)) {
        return;
      }

      reporter.atNode(node, _code);
    });

    // 2. Detect forbidden functor calls inside build() (e.g. computed, switched, managed, WhatController)
    context.registry.addMethodInvocation((node) {
      if (!isForbiddenMethodInvocation(node)) return;

      if (!FlutterAstUtils.isInsideBuildMethod(node)) return;
      if (AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(node)) {
        return;
      }

      reporter.atNode(node, _code);
    });

    // 3. Detect forbidden functor calls as FunctionExpressionInvocation (e.g. computed(), switched(), managed())
    context.registry.addFunctionExpressionInvocation((node) {
      final function = node.function;
      final name =
          function is SimpleIdentifier ? function.name : function.toSource();
      if (_forbiddenPipelineFunctors.contains(name) ||
          _controllerAndTerminalConstructors.contains(name) ||
          name.startsWith('computed.')) {
        if (!FlutterAstUtils.isInsideBuildMethod(node)) return;
        if (AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(node)) {
          return;
        }

        reporter.atNode(node, _code);
      }
    });
  }

  /// Returns `true` if [node] creates a forbidden controller, coupler, signal, or terminal.
  static bool isForbiddenCreation(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    return _controllerAndTerminalConstructors.contains(typeName);
  }

  /// Returns `true` if [node] calls a forbidden pipeline functor or factory constructor inside build.
  static bool isForbiddenMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (_forbiddenPipelineFunctors.contains(name) ||
        _controllerAndTerminalConstructors.contains(name)) {
      final target = node.target;
      if (target == null) return true;
      if (target is SimpleIdentifier && target.name == 'What') return true;
    }
    final target = node.target;
    if (target is SimpleIdentifier && target.name == 'computed') {
      if (name == 'future' || name == 'stream' || name == 'async') {
        return true;
      }
    }
    return false;
  }
}
