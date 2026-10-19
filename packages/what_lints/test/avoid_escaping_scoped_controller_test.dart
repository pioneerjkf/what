// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

void main() {
  group('AvoidEscapingScopedController AST detection', () {
    test('detects field declaration of type ScopedAnimationController', () {
      final unit = parseString(content: '''
class MyStore {
  ScopedAnimationController? controller;
  DurableAnimationController safeCtrl;
}
''').unit;

      final fields = <FieldDeclaration>[];
      unit.visitChildren(_FieldFinder((node) => fields.add(node)));

      expect(fields.length, equals(2));
      // First is ScopedAnimationController -> forbidden!
      expect(
          AvoidEscapingScopedController.isScopedControllerType(
              fields[0].fields.type),
          isTrue);
      // Second is DurableAnimationController -> safe!
      expect(
          AvoidEscapingScopedController.isScopedControllerType(
              fields[1].fields.type),
          isFalse);
    });

    test('detects escaping ctrl.view assignment to outer variable', () {
      final unit = parseString(content: '''
void test() {
  Animation<double>? leaked;
  controller.animate((via, ctrl) {
    leaked = ctrl.view;
    return Container();
  });
}
''').unit;

      final assignments = <AssignmentExpression>[];
      unit.visitChildren(_AssignmentFinder((node) => assignments.add(node)));

      expect(assignments.length, equals(1));
      final assign = assignments[0];
      expect(
          AvoidEscapingScopedController.isScopedControllerOrViewExpr(
              assign.rightHandSide),
          isTrue);
      expect(
          AvoidEscapingScopedController.isEscapingTarget(
              assign.leftHandSide, assign),
          isTrue);
    });

    test('permits local variable assignment inside builder', () {
      final unit = parseString(content: '''
void test() {
  controller.animate((via, ctrl) {
    final localView = ctrl.view;
    Animation<double>? another;
    another = localView;
    return Container();
  });
}
''').unit;

      final assignments = <AssignmentExpression>[];
      unit.visitChildren(_AssignmentFinder((node) => assignments.add(node)));

      expect(assignments.length, equals(1));
      final assign = assignments[0];
      // Target 'another' is declared inside the builder closure, so it does not escape!
      expect(
          AvoidEscapingScopedController.isEscapingTarget(
              assign.leftHandSide, assign),
          isFalse);
    });

    test('detects adding ctrl.view to an outer list', () {
      final unit = parseString(content: '''
void test() {
  final outerList = <dynamic>[];
  controller.animate((via, ctrl) {
    outerList.add(ctrl.view);
  });
}
''').unit;

      final invocations = <MethodInvocation>[];
      unit.visitChildren(_InvocationFinder((node) => invocations.add(node)));

      final addCall = invocations.firstWhere((i) => i.methodName.name == 'add');
      final arg = addCall.argumentList.arguments[0];
      expect(AvoidEscapingScopedController.isScopedControllerOrViewExpr(arg),
          isTrue);
      expect(
          AvoidEscapingScopedController.isEscapingTarget(
              addCall.target!, addCall),
          isTrue);
    });

    test('permits adding ctrl.view to a list declared inside builder', () {
      final unit = parseString(content: '''
void test() {
  controller.animate((via, ctrl) {
    final localList = <dynamic>[];
    localList.add(ctrl.view);
  });
}
''').unit;

      final invocations = <MethodInvocation>[];
      unit.visitChildren(_InvocationFinder((node) => invocations.add(node)));

      final addCall = invocations.firstWhere((i) => i.methodName.name == 'add');
      expect(
          AvoidEscapingScopedController.isEscapingTarget(
              addCall.target!, addCall),
          isFalse);
    });
  });
}

class _FieldFinder extends RecursiveAstVisitor<void> {
  _FieldFinder(this.onFound);
  final void Function(FieldDeclaration) onFound;

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    onFound(node);
    super.visitFieldDeclaration(node);
  }
}

class _AssignmentFinder extends RecursiveAstVisitor<void> {
  _AssignmentFinder(this.onFound);
  final void Function(AssignmentExpression) onFound;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    onFound(node);
    super.visitAssignmentExpression(node);
  }
}

class _InvocationFinder extends RecursiveAstVisitor<void> {
  _InvocationFinder(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onFound(node);
    super.visitMethodInvocation(node);
  }
}
