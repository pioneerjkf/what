// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule ensuring Flutter-bound What controllers (`WhatTextEditingController`, etc.) instantiated in `State` classes are explicitly disposed in `dispose()`.
///
/// ### Rationale:
/// Controllers extending Flutter's `ChangeNotifier` / `TextEditingController` maintain internal listeners
/// and bridge terminals. Failing to call `controller.dispose()` inside `State.dispose()` causes retained
/// controller instances and memory leaks.
///
/// Note: Pure reactive producers (`WhatController`, `RawWhatController`, `WhatCoupler`, etc.) do not
/// require manual disposal as their lifecycle is subscriber-driven (Inactive Dormancy) and collected by GC.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late final WhatTextEditingController _controller; // [Anti-Pattern] Never disposed!
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = WhatTextEditingController(targetController);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late final WhatTextEditingController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = WhatTextEditingController(targetController);
///   }
///
///   @override
///   void dispose() {
///     _controller.dispose(); // [Recommended] Explicitly disposed
///     super.dispose();
///   }
/// }
/// ```
class DisposeWhatFlutterController extends DartLintRule {
  DisposeWhatFlutterController() : super(code: _code);

  static const _code = LintCode(
    name: 'dispose_what_flutter_controller',
    problemMessage:
        'The What Flutter controller \'{0}\' must be disposed in State.dispose() to prevent memory leaks.',
    correctionMessage:
        'Call \'{0}.dispose();\' inside the dispose() method of this State class.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _targetControllerTypes = {
    'WhatTextEditingController',
    'BoundTextController',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      if (!FlutterAstUtils.isStateClass(node)) return;

      final undisposedControllers = findUndisposedControllers(node);
      for (final entry in undisposedControllers) {
        reporter.atNode(entry.node, _code, arguments: [entry.name]);
      }
    });
  }

  /// Returns a list of field variable declarations holding a Flutter-bound What controller that are not disposed in `dispose()`.
  static List<({String name, VariableDeclaration node})>
      findUndisposedControllers(ClassDeclaration clazz) {
    final controllerFields = <String, VariableDeclaration>{};

    for (final member in clazz.members) {
      if (member is FieldDeclaration) {
        final typeStr = member.fields.type?.toSource() ?? '';
        final isController =
            _targetControllerTypes.any((t) => typeStr.startsWith(t));

        if (isController) {
          for (final variable in member.fields.variables) {
            controllerFields[variable.name.lexeme] = variable;
          }
        }
      }
    }

    if (controllerFields.isEmpty) return const [];

    // Find dispose() method
    MethodDeclaration? disposeMethod;
    for (final member in clazz.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        disposeMethod = member;
        break;
      }
    }

    // Collect all disposed field names in dispose
    final disposedFields = <String>{};
    if (disposeMethod != null) {
      disposeMethod.visitChildren(_DisposeInvocationVisitor((targetName) {
        disposedFields.add(targetName);
      }));
    }

    final undisposed = <({String name, VariableDeclaration node})>[];
    for (final entry in controllerFields.entries) {
      if (!disposedFields.contains(entry.key)) {
        undisposed.add((name: entry.key, node: entry.value));
      }
    }

    return undisposed;
  }
}

class _DisposeInvocationVisitor extends RecursiveAstVisitor<void> {
  _DisposeInvocationVisitor(this.onFound);
  final void Function(String fieldName) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'dispose') {
      final target = node.target;
      if (target is SimpleIdentifier) {
        onFound(target.name);
      } else if (target is PropertyAccess) {
        onFound(target.propertyName.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}
