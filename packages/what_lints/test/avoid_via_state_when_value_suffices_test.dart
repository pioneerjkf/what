// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

class _ViaStateDataVisitor extends RecursiveAstVisitor<void> {
  final List<PropertyAccess> matchedNodes = [];

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'data') {
      final target = node.target;
      if (target is MethodInvocation &&
          AvoidViaStateWhenValueSuffices.isViaStateInvocation(target)) {
        matchedNodes.add(node);
      }
    }
    super.visitPropertyAccess(node);
  }
}

void main() {
  group('AvoidViaStateWhenValueSuffices AST detection', () {
    test('detects via.state(x).data inside computed', () {
      final unit = parseString(content: '''
void test() {
  final total = computed((via) => via.state(price).data * 2);
}
''').unit;

      final visitor = _ViaStateDataVisitor();
      unit.accept(visitor);
      expect(visitor.matchedNodes.length, equals(1));
    });

    test('permits direct via(x) inside computed', () {
      final unit = parseString(content: '''
void test() {
  final total = computed((via) => via(price) * 2);
}
''').unit;

      final visitor = _ViaStateDataVisitor();
      unit.accept(visitor);
      expect(visitor.matchedNodes.length, equals(0));
    });

    test('permits other WhatState property reads on via.state(x)', () {
      final unit = parseString(content: '''
void test() {
  final total = computed((via) {
    final state = via.state(price);
    return state.hasData ? 1 : 0;
  });
}
''').unit;

      final visitor = _ViaStateDataVisitor();
      unit.accept(visitor);
      expect(visitor.matchedNodes.length, equals(0));
    });
  });
}
