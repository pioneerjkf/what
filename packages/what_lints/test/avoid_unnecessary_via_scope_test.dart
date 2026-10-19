// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

void main() {
  group('AvoidUnnecessaryViaScope AST detection', () {
    test('detects unused via parameter in computed()', () {
      final unit = parseString(content: '''
void setup() {
  final constant = computed((via) {
    return 10 + 20;
  });
}
''').unit;

      FunctionExpression? closure;
      unit.visitChildren(_FunctionExpressionVisitor((node) => closure = node));

      expect(closure, isNotNull);
      expect(
          AvoidUnnecessaryViaScope.isUnnecessaryViaClosure(closure!), isTrue);
    });

    test('permits active via usage in computed()', () {
      final unit = parseString(content: '''
void setup() {
  final sum = computed((via) {
    return via(a) + via(b);
  });
}
''').unit;

      FunctionExpression? closure;
      unit.visitChildren(_FunctionExpressionVisitor((node) => closure = node));

      expect(closure, isNotNull);
      expect(
          AvoidUnnecessaryViaScope.isUnnecessaryViaClosure(closure!), isFalse);
    });
  });
}

class _FunctionExpressionVisitor extends RecursiveAstVisitor<void> {
  _FunctionExpressionVisitor(this.onFound);
  final void Function(FunctionExpression) onFound;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    onFound(node);
    super.visitFunctionExpression(node);
  }
}
