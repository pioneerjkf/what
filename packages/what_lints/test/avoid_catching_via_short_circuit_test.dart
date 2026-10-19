// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

class _CatchClauseVisitor extends RecursiveAstVisitor<void> {
  final List<CatchClause> caughtNodes = [];

  @override
  void visitTryStatement(TryStatement node) {
    if (WhatTypeChecker.isInsideWhatViaScope(node)) {
      final finder = _ViaInvocationFinder();
      node.body.accept(finder);
      if (finder.hasViaInvocation) {
        for (final catchClause in node.catchClauses) {
          if (!AvoidCatchingViaShortCircuit.isCatchClauseRethrowing(
              catchClause)) {
            final typeName = catchClause.exceptionType?.toSource();
            if (typeName == null ||
                AvoidCatchingViaShortCircuit.broadExceptionTypes
                    .contains(typeName)) {
              caughtNodes.add(catchClause);
            }
          }
        }
      }
    }
    super.visitTryStatement(node);
  }
}

class _ViaInvocationFinder extends RecursiveAstVisitor<void> {
  bool hasViaInvocation = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (WhatTypeChecker.isWhatViaInvocation(node)) {
      hasViaInvocation = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (WhatTypeChecker.isWhatViaInvocation(node)) {
      hasViaInvocation = true;
      return;
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

void main() {
  group('AvoidCatchingViaShortCircuit AST detection', () {
    test('detects broad catch around via() call inside computed', () {
      final unit = parseString(content: '''
void test() {
  final d = computed((via) {
    try {
      return via(count) + 1;
    } catch (e) {
      return 0;
    }
  });
}
''').unit;

      final visitor = _CatchClauseVisitor();
      unit.accept(visitor);
      expect(visitor.caughtNodes.length, equals(1));
    });

    test('detects on Object catch around via() call inside computed', () {
      final unit = parseString(content: '''
void test() {
  final d = computed((via) {
    try {
      return via(count) + 1;
    } on Object catch (e) {
      return 0;
    }
  });
}
''').unit;

      final visitor = _CatchClauseVisitor();
      unit.accept(visitor);
      expect(visitor.caughtNodes.length, equals(1));
    });

    test('permits rethrow inside catch clause', () {
      final unit = parseString(content: '''
void test() {
  final d = computed((via) {
    try {
      return via(count) + 1;
    } catch (e) {
      print('log');
      rethrow;
    }
  });
}
''').unit;

      final visitor = _CatchClauseVisitor();
      unit.accept(visitor);
      expect(visitor.caughtNodes.length, equals(0));
    });

    test('permits specific domain exception catch', () {
      final unit = parseString(content: '''
void test() {
  final d = computed((via) {
    try {
      return via(count) + 1;
    } on FormatException catch (e) {
      return 0;
    }
  });
}
''').unit;

      final visitor = _CatchClauseVisitor();
      unit.accept(visitor);
      expect(visitor.caughtNodes.length, equals(0));
    });
  });
}
