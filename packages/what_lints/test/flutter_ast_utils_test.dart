// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:what_lints/what_lints.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterAstUtils.isWidgetBuildMethod', () {
    test('returns true for Widget build(BuildContext context)', () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    return Container();
  }
}
''').unit;

      final classDecl = unit.declarations.first as ClassDeclaration;
      final method = classDecl.members.first as MethodDeclaration;

      expect(FlutterAstUtils.isWidgetBuildMethod(method), isTrue);
    });

    test(
        'returns true for build(BuildContext context) without explicit return type',
        () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  build(BuildContext context) {
    return Container();
  }
}
''').unit;

      final classDecl = unit.declarations.first as ClassDeclaration;
      final method = classDecl.members.first as MethodDeclaration;

      expect(FlutterAstUtils.isWidgetBuildMethod(method), isTrue);
    });

    test('returns true for Widget build(BuildContext? context)', () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext? context) {
    return Container();
  }
}
''').unit;

      final classDecl = unit.declarations.first as ClassDeclaration;
      final method = classDecl.members.first as MethodDeclaration;

      expect(FlutterAstUtils.isWidgetBuildMethod(method), isTrue);
    });

    test('returns false for regular build() without BuildContext', () {
      final unit = parseString(content: '''
class CustomBuilder {
  String build() => 'result';
}
''').unit;

      final classDecl = unit.declarations.first as ClassDeclaration;
      final method = classDecl.members.first as MethodDeclaration;

      expect(FlutterAstUtils.isWidgetBuildMethod(method), isFalse);
    });

    test('returns false for other methods taking BuildContext', () {
      final unit = parseString(content: '''
class MyWidget {
  void performAction(BuildContext context) {}
}
''').unit;

      final classDecl = unit.declarations.first as ClassDeclaration;
      final method = classDecl.members.first as MethodDeclaration;

      expect(FlutterAstUtils.isWidgetBuildMethod(method), isFalse);
    });
  });

  group(
      'FlutterAstUtils.isInsidePipelineOrBuild and isInsideEventOrDeferredClosure',
      () {
    test('detects build context and differentiates event callbacks', () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    directCall();
    return ElevatedButton(
      onPressed: () {
        eventCall();
      },
      child: Text('Click'),
    );
  }
}
''').unit;

      MethodInvocation? directCall;
      MethodInvocation? eventCall;

      unit.accept(_TestInvocationCollector((node) {
        if (node.methodName.name == 'directCall') directCall = node;
        if (node.methodName.name == 'eventCall') eventCall = node;
      }));

      expect(directCall, isNotNull);
      expect(eventCall, isNotNull);

      expect(FlutterAstUtils.isInsidePipelineOrBuild(directCall!), isTrue);
      expect(
          FlutterAstUtils.isInsideEventOrDeferredClosure(directCall!), isFalse);

      expect(FlutterAstUtils.isInsidePipelineOrBuild(eventCall!), isTrue);
      expect(
          FlutterAstUtils.isInsideEventOrDeferredClosure(eventCall!), isTrue);
    });
  });
}

class _TestInvocationCollector extends RecursiveAstVisitor<void> {
  final void Function(MethodInvocation) onInvocation;
  _TestInvocationCollector(this.onInvocation);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onInvocation(node);
    super.visitMethodInvocation(node);
  }
}
