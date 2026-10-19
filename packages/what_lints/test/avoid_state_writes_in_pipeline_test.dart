// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:what_lints/what_lints.dart';
import 'package:test/test.dart';

class _MethodInvocationCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }
}

void main() {
  group('AvoidStateWritesInPipeline AST detection', () {
    test('detects synchronous state write directly in build()', () {
      final unit = parseString(content: '''
class BadWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    controller.set(100);
    return Container();
  }
}
''').unit;

      final collector = _MethodInvocationCollector();
      unit.accept(collector);

      final setCall =
          collector.invocations.firstWhere((i) => i.methodName.name == 'set');
      expect(
          AvoidStateWritesInPipeline.isInsidePipelineMethod(setCall), isTrue);
      expect(AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(setCall),
          isFalse);
    });

    test('permits state writes inside UI callback closures (e.g. onPressed)',
        () {
      final unit = parseString(content: '''
class GoodWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        controller.set(100);
      },
      child: Text('Submit'),
    );
  }
}
''').unit;

      final collector = _MethodInvocationCollector();
      unit.accept(collector);

      final setCall =
          collector.invocations.firstWhere((i) => i.methodName.name == 'set');
      expect(
          AvoidStateWritesInPipeline.isInsidePipelineMethod(setCall), isTrue);
      expect(AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(setCall),
          isTrue);
    });

    test('detects synchronous state write directly inside computed() closure',
        () {
      final unit = parseString(content: '''
void showcase() {
  final badDerivation = computed((via) {
    controller.set(100);
    return via(count.what) + 1;
  });
}
''').unit;

      final collector = _MethodInvocationCollector();
      unit.accept(collector);

      final setCall =
          collector.invocations.firstWhere((i) => i.methodName.name == 'set');
      expect(
          AvoidStateWritesInPipeline.isInsidePipelineMethod(setCall), isTrue);
      expect(AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(setCall),
          isFalse);
    });

    test('detects synchronous property setter assignment directly in build()',
        () {
      final unit = parseString(content: '''
class BadWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    controller.data = 100;
    return Container();
  }
}
''').unit;

      AssignmentExpression? assignment;
      unit.visitChildren(_AssignmentCollector((node) => assignment = node));

      expect(assignment, isNotNull);
      expect(AvoidStateWritesInPipeline.isInsidePipelineMethod(assignment!),
          isTrue);
      expect(
          AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(
              assignment!),
          isFalse);
    });

    test('does not permit state writes inside arbitrary .run() invocations',
        () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    customRunner.run(() {
      counter.data = 10;
    });
    return Container();
  }
}
''').unit;

      AssignmentExpression? assignment;
      unit.visitChildren(_AssignmentCollector((node) => assignment = node));

      expect(assignment, isNotNull);
      expect(
          AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(
              assignment!),
          isFalse);
    });

    test('permits state writes inside Timer.run() invocations', () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    Timer.run(() {
      counter.data = 10;
    });
    return Container();
  }
}
''').unit;

      AssignmentExpression? assignment;
      unit.visitChildren(_AssignmentCollector((node) => assignment = node));

      expect(assignment, isNotNull);
      expect(
          AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(
              assignment!),
          isTrue);
    });

    test('permits state writes inside prefixed async.Timer.run() invocations',
        () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    async.Timer.run(() {
      counter.data = 10;
    });
    return Container();
  }
}
''').unit;

      AssignmentExpression? assignment;
      unit.visitChildren(_AssignmentCollector((node) => assignment = node));

      expect(assignment, isNotNull);
      expect(
          AvoidStateWritesInPipeline.isInsideEventOrDeferredClosure(
              assignment!),
          isTrue);
    });
  });
}

class _AssignmentCollector extends RecursiveAstVisitor<void> {
  _AssignmentCollector(this.onFound);
  final void Function(AssignmentExpression) onFound;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    onFound(node);
    super.visitAssignmentExpression(node);
  }
}
