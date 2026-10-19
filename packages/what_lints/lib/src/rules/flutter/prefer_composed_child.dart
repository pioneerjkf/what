// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../what_lints.dart';

/// A lint rule recommending isolating static, non-reactive widget subtrees from `composed`.
///
/// ### Rationale:
/// `composed` creates an inline surgical micro-rebuild boundary. When static, non-reactive
/// widgets (e.g. `const Icon(...)`, heavy background decorations, static layouts) are placed
/// directly inside the closure, they are unnecessarily re-evaluated on every reactive state change.
///
/// Developers and AI agents can resolve this using one of three architectural patterns depending
/// on the widget tree hierarchy:
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Static icon and text subtree re-evaluated on every count change!
/// composed((context, via) => Row(children: [
///   Text('${via(countWhat)}'),
///   const Icon(Icons.star),
///   const Text('Favorite'),
/// ]));
/// ```
///
/// **GOOD (Pattern 1: Surgical Micro-Rebuild - Recommended for static parent layouts):**
/// ```dart
/// // Keep the static layout outside, wrapping only the dynamic widget with composed
/// Row(children: [
///   composed((context, via) => Text('${via(countWhat)}')),
///   const Icon(Icons.star),
/// ]);
/// ```
///
/// **GOOD (Pattern 2: Subtree Caching via composed.child - Recommended when parent is dynamic):**
/// ```dart
/// // When the parent itself is dynamic (e.g. Transform, AnimatedContainer), pass the static child
/// composed.child(
///   (context, via, child) => Transform.scale(
///     scale: via(scaleWhat),
///     child: child,
///   ),
///   child: const Icon(Icons.star), // Cached across rebuilds
/// );
/// ```
///
/// **GOOD (Pattern 3: Extract Standalone Const Widget):**
/// ```dart
/// // Extract complex static subtrees into a standalone const StatelessWidget
/// composed((context, via) => Column(children: [
///   const HeavyStaticHeader(),
///   Text('${via(countWhat)}'),
/// ]));
/// ```
class PreferComposedChild extends DartLintRule {
  PreferComposedChild() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_composed_child',
    problemMessage:
        'Consider isolating non-reactive static subtrees from composed.',
    correctionMessage:
        'To minimize rebuild overhead, try one of these recommended alternatives depending on your widget tree: '
        '1) Narrow composed scope to dynamic widgets only (Surgical Rebuild), '
        '2) pass static subtrees via composed.child / composed.children, or '
        '3) extract them into separate const widgets.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void checkInvocation(
      AstNode node,
      ArgumentList argumentList,
      String functorName,
    ) {
      final args = argumentList.arguments;
      if (args.isEmpty) return;

      // Extract builder closure
      FunctionExpression? builderFunc;
      for (final arg in args) {
        if (arg is FunctionExpression) {
          builderFunc = arg;
          break;
        }
      }

      if (builderFunc == null) return;

      final visitor = _SubtreeComplexityVisitor();
      builderFunc.body.visitChildren(visitor);

      final isHighFrequency = functorName.contains('Drive') ||
          functorName.contains('Animate') ||
          visitor.hasHighFrequencySource;

      // High-frequency frame animation requires strict isolation (threshold 1).
      // Standard reactive event cascades allow trivial spacers and single labels (threshold 2).
      final threshold = isHighFrequency ? 1 : 2;

      if (visitor.complexityScore >= threshold) {
        reporter.atNode(node, _code);
      }
    }

    context.registry.addFunctionExpressionInvocation((node) {
      final name = WhatTypeChecker.resolveFunctorName(node);
      if (name != null &&
          name.startsWith('Composed') &&
          !name.contains('Child')) {
        checkInvocation(node, node.argumentList, name);
      }
    });

    context.registry.addMethodInvocation((node) {
      final name = WhatTypeChecker.resolveFunctorName(node);
      if (name != null &&
          name.startsWith('Composed') &&
          !name.contains('Child')) {
        checkInvocation(node, node.argumentList, name);
      }
    });
  }

  /// Calculates the static widget subtree complexity score inside [body].
  static int calculateComplexity(FunctionBody body) {
    final visitor = _SubtreeComplexityVisitor();
    body.visitChildren(visitor);
    return visitor.complexityScore;
  }

  /// Checks if the [body] contains static `const` widget instances or lists that could be cached via `composed.child` or `composed.children`.
  static bool containsHeavyStaticWidget(FunctionBody body,
      {bool isHighFrequency = false}) {
    final visitor = _SubtreeComplexityVisitor();
    body.visitChildren(visitor);
    final effectiveHighFreq = isHighFrequency || visitor.hasHighFrequencySource;
    final threshold = effectiveHighFreq ? 1 : 2;
    return visitor.complexityScore >= threshold;
  }
}

class _SubtreeComplexityVisitor extends RecursiveAstVisitor<void> {
  _SubtreeComplexityVisitor();

  _SubtreeComplexityVisitor._withContext(this._inConstContext);

  int complexityScore = 0;
  bool _inConstContext = false;
  bool hasHighFrequencySource = false;

  /// Layout spacers, dividers, and zero-overhead structural primitives
  /// that do not constitute heavy subtrees.
  static const _trivialLayoutWidgets = {
    'SizedBox',
    'Spacer',
    'Divider',
    'VerticalDivider',
  };

  /// Common non-widget const value types and styling objects.
  static const _nonWidgetConstTypes = {
    'EdgeInsets',
    'EdgeInsetsDirectional',
    'Duration',
    'Key',
    'ValueKey',
    'GlobalKey',
    'Color',
    'TextStyle',
    'StrutStyle',
    'BoxDecoration',
    'ShapeDecoration',
    'Border',
    'BorderSide',
    'BorderRadius',
    'Radius',
    'Offset',
    'Size',
    'Rect',
    'Matrix4',
    'BoxConstraints',
    'Alignment',
    'AlignmentDirectional',
    'FractionalOffset',
    'Locale',
    'FontWeight',
    'FontStyle',
    'TextAlign',
    'TextDirection',
    'Curve',
    'LinearGradient',
    'RadialGradient',
    'SweepGradient',
    'BoxShadow',
    'Shadow',
    'RoundedRectangleBorder',
    'CircleBorder',
    'StadiumBorder',
    'UnderlineInputBorder',
    'OutlineInputBorder',
  };

  @override
  void visitBlock(Block node) {
    _visitStatements(node.statements);
  }

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    _visitStatements(node.block.statements);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    node.expression.accept(this);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    node.condition.accept(this);

    final thenVisitor = _SubtreeComplexityVisitor._withContext(_inConstContext);
    node.thenExpression.accept(thenVisitor);

    final elseVisitor = _SubtreeComplexityVisitor._withContext(_inConstContext);
    node.elseExpression.accept(elseVisitor);

    hasHighFrequencySource |=
        thenVisitor.hasHighFrequencySource | elseVisitor.hasHighFrequencySource;
    complexityScore +=
        math.max(thenVisitor.complexityScore, elseVisitor.complexityScore);
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    node.expression.accept(this);

    var maxCaseScore = 0;
    for (final c in node.cases) {
      final caseVisitor =
          _SubtreeComplexityVisitor._withContext(_inConstContext);
      c.expression.accept(caseVisitor);
      c.guardedPattern.accept(caseVisitor);
      hasHighFrequencySource |= caseVisitor.hasHighFrequencySource;

      if (caseVisitor.complexityScore > maxCaseScore) {
        maxCaseScore = caseVisitor.complexityScore;
      }
    }
    complexityScore += maxCaseScore;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final staticType = node.staticType;
    if (staticType != null) {
      if (!FlutterAstUtils.isWidgetType(staticType)) {
        // Non-widget type (e.g. ButtonSegment, EdgeInsets, TextStyle, Color, etc.)
        // It is not a widget and its arguments are not an isolatable widget subtree.
        return;
      }
    } else {
      final baseTypeName = node.constructorName.type.name.lexeme;
      if (_nonWidgetConstTypes.contains(baseTypeName)) {
        return;
      }
    }

    final wasInConstContext = _inConstContext;
    if (node.isConst) {
      _inConstContext = true;
    }

    if (_inConstContext) {
      final baseTypeName = node.constructorName.type.name.lexeme;
      if (!_trivialLayoutWidgets.contains(baseTypeName)) {
        // Weight static non-trivial const widgets.
        complexityScore += 1;
      }
    }

    super.visitInstanceCreationExpression(node);
    _inConstContext = wasInConstContext;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'observe' || name == 'observeValue') {
      hasHighFrequencySource = true;
    }
    if (_inConstContext) {
      // In unresolved AST (like tests), Icon(...) is parsed as MethodInvocation.
      // We check if it starts with an uppercase letter to guess if it's a widget/type.
      if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
        final staticType = node.staticType;
        if (staticType != null) {
          if (FlutterAstUtils.isWidgetType(staticType) &&
              !_trivialLayoutWidgets.contains(name)) {
            complexityScore += 1;
          }
        } else {
          if (!_nonWidgetConstTypes.contains(name) &&
              !_trivialLayoutWidgets.contains(name)) {
            complexityScore += 1;
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitListLiteral(ListLiteral node) {
    final wasInConstContext = _inConstContext;
    if (node.isConst) {
      final type = node.staticType;
      if (type is InterfaceType && type.typeArguments.isNotEmpty) {
        final elementType = type.typeArguments.first;
        if (FlutterAstUtils.isWidgetType(elementType) ||
            elementType is DynamicType) {
          _inConstContext = true;
        }
      } else {
        _inConstContext = true;
      }
    }
    super.visitListLiteral(node);
    _inConstContext = wasInConstContext;
  }

  void _visitStatements(List<Statement> statements) {
    for (var i = 0; i < statements.length; i++) {
      final stmt = statements[i];

      if (stmt is IfStatement) {
        stmt.expression.accept(this);

        final thenVisitor =
            _SubtreeComplexityVisitor._withContext(_inConstContext);
        _visitStatementOrBlock(stmt.thenStatement, thenVisitor);
        hasHighFrequencySource |= thenVisitor.hasHighFrequencySource;

        if (stmt.elseStatement != null) {
          final elseVisitor =
              _SubtreeComplexityVisitor._withContext(_inConstContext);
          _visitStatementOrBlock(stmt.elseStatement!, elseVisitor);
          hasHighFrequencySource |= elseVisitor.hasHighFrequencySource;

          complexityScore += math.max(
              thenVisitor.complexityScore, elseVisitor.complexityScore);

          if (_alwaysTerminates(stmt.thenStatement) &&
              _alwaysTerminates(stmt.elseStatement!)) {
            return;
          }
        } else {
          // If without else
          if (_alwaysTerminates(stmt.thenStatement)) {
            // Guard clause / Early exit pattern
            final remainingVisitor =
                _SubtreeComplexityVisitor._withContext(_inConstContext);
            remainingVisitor._visitStatements(statements.sublist(i + 1));
            hasHighFrequencySource |= remainingVisitor.hasHighFrequencySource;

            complexityScore += math.max(
                thenVisitor.complexityScore, remainingVisitor.complexityScore);
            return;
          } else {
            complexityScore += thenVisitor.complexityScore;
          }
        }
      } else if (stmt is SwitchStatement) {
        stmt.expression.accept(this);
        var maxMemberScore = 0;
        var allTerminate = true;

        for (final member in stmt.members) {
          final memberVisitor =
              _SubtreeComplexityVisitor._withContext(_inConstContext);
          memberVisitor._visitStatements(member.statements);
          hasHighFrequencySource |= memberVisitor.hasHighFrequencySource;

          if (memberVisitor.complexityScore > maxMemberScore) {
            maxMemberScore = memberVisitor.complexityScore;
          }
          if (!_statementsAlwaysTerminate(member.statements)) {
            allTerminate = false;
          }
        }

        complexityScore += maxMemberScore;

        final hasDefault = stmt.members.any((m) =>
            m is SwitchDefault ||
            (m is SwitchPatternCase &&
                m.guardedPattern.pattern is WildcardPattern &&
                m.guardedPattern.whenClause == null));
        if (allTerminate && hasDefault) {
          return;
        }
      } else {
        stmt.accept(this);
        if (_alwaysTerminates(stmt)) {
          return;
        }
      }
    }
  }

  static void _visitStatementOrBlock(
      Statement stmt, _SubtreeComplexityVisitor visitor) {
    if (stmt is Block) {
      visitor._visitStatements(stmt.statements);
    } else {
      visitor._visitStatements([stmt]);
    }
  }

  static bool _alwaysTerminates(Statement stmt) {
    if (stmt is ReturnStatement) return true;
    if (stmt is ExpressionStatement) {
      final expr = stmt.expression;
      if (expr is ThrowExpression || expr is RethrowExpression) return true;
    }
    if (stmt is Block) {
      return _statementsAlwaysTerminate(stmt.statements);
    }
    if (stmt is IfStatement) {
      if (stmt.elseStatement != null) {
        return _alwaysTerminates(stmt.thenStatement) &&
            _alwaysTerminates(stmt.elseStatement!);
      }
    }
    return false;
  }

  static bool _statementsAlwaysTerminate(List<Statement> statements) {
    for (final s in statements) {
      if (_alwaysTerminates(s)) return true;
    }
    return false;
  }
}
