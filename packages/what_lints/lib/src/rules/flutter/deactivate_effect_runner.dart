// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule ensuring `EffectRunner` instances held in `State` classes are explicitly deactivated in `dispose()`.
///
/// ### Rationale:
/// `EffectRunner` subscriptions hold strong listener references in upstream `Effect` and `What` nodes.
/// Failing to call `runner.deactivate()` inside `State.dispose()` retains the unmounted `State` instance
/// and its associated BuildContext in memory, causing severe memory leaks.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   EffectRunner? _runner; // [Anti-Pattern] Never deactivated in dispose!
///
///   @override
///   void initState() {
///     super.initState();
///     _runner = counterWhat.effect(() => print(untracked(counterWhat))).run();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   EffectRunner? _runner;
///
///   @override
///   void initState() {
///     super.initState();
///     _runner = counterWhat.effect(() => print(untracked(counterWhat))).run();
///   }
///
///   @override
///   void dispose() {
///     _runner?.deactivate(); // [Recommended] Explicitly deactivated
///     super.dispose();
///   }
/// }
/// ```
class DeactivateEffectRunner extends DartLintRule {
  DeactivateEffectRunner() : super(code: _code);

  static const _code = LintCode(
    name: 'deactivate_effect_runner',
    problemMessage:
        'The EffectRunner \'{0}\' must be deactivated in State.dispose() to prevent memory leaks.',
    correctionMessage:
        'Call \'{0}?.deactivate();\' inside the dispose() method of this State class.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      if (!FlutterAstUtils.isStateClass(node)) return;

      final uncancelledRunners = findUncancelledRunners(node);
      for (final entry in uncancelledRunners) {
        reporter.atNode(entry.node, _code, arguments: [entry.name]);
      }
    });
  }

  /// Returns a list of field variable declarations holding an `EffectRunner` that are not deactivated in `dispose()`.
  static List<({String name, VariableDeclaration node})> findUncancelledRunners(
      ClassDeclaration clazz) {
    final runnerFields = <String, VariableDeclaration>{};

    for (final member in clazz.members) {
      if (member is FieldDeclaration) {
        final typeStr = member.fields.type?.toSource() ?? '';
        final isRunner = typeStr.startsWith('EffectRunner');

        if (isRunner) {
          for (final variable in member.fields.variables) {
            runnerFields[variable.name.lexeme] = variable;
          }
        }
      }
    }

    if (runnerFields.isEmpty) return const [];

    // Find dispose() method
    MethodDeclaration? disposeMethod;
    for (final member in clazz.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        disposeMethod = member;
        break;
      }
    }

    // Collect all deactivated field names in dispose
    final deactivatedFields = <String>{};
    if (disposeMethod != null) {
      disposeMethod.visitChildren(_DeactivateInvocationVisitor((targetName) {
        deactivatedFields.add(targetName);
      }));
    }

    final uncancelled = <({String name, VariableDeclaration node})>[];
    for (final entry in runnerFields.entries) {
      if (!deactivatedFields.contains(entry.key)) {
        uncancelled.add((name: entry.key, node: entry.value));
      }
    }

    return uncancelled;
  }
}

class _DeactivateInvocationVisitor extends RecursiveAstVisitor<void> {
  _DeactivateInvocationVisitor(this.onFound);
  final void Function(String fieldName) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'deactivate' ||
        node.methodName.name == 'cancel') {
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
