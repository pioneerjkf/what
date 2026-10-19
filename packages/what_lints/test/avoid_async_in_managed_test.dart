// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

void main() {
  group('AvoidAsyncInManaged AST detection', () {
    test('detects async create closure in managed()', () {
      final unit = parseString(content: '''
void setup() {
  final res = managed(
    create: (via) async {
      return Resource();
    },
    dispose: (r) => r.dispose(),
  );
}
''').unit;

      MethodInvocation? managedCall;
      unit.visitChildren(
          _MethodInvocationVisitor('managed', (node) => managedCall = node));

      expect(managedCall, isNotNull);
      expect(AvoidAsyncInManaged.isAsyncClosureInManaged(managedCall!), isTrue);
    });

    test('detects async update closure in managed()', () {
      final unit = parseString(content: '''
void setup() {
  final res = managed(
    create: (via) => Resource(),
    update: (via, cur) async {
      return cur;
    },
    dispose: (r) => r.dispose(),
  );
}
''').unit;

      MethodInvocation? managedCall;
      unit.visitChildren(
          _MethodInvocationVisitor('managed', (node) => managedCall = node));

      expect(managedCall, isNotNull);
      expect(AvoidAsyncInManaged.isAsyncClosureInManaged(managedCall!), isTrue);
    });

    test('detects async dispose closure in managed()', () {
      final unit = parseString(content: '''
void setup() {
  final res = managed(
    create: (via) => Resource(),
    dispose: (r) async {
      await r.close();
    },
  );
}
''').unit;

      MethodInvocation? managedCall;
      unit.visitChildren(
          _MethodInvocationVisitor('managed', (node) => managedCall = node));

      expect(managedCall, isNotNull);
      expect(AvoidAsyncInManaged.isAsyncClosureInManaged(managedCall!), isTrue);
    });

    test('permits synchronous closures in managed()', () {
      final unit = parseString(content: '''
void setup() {
  final res = managed(
    create: (via) => Resource(),
    dispose: (r) => r.dispose(),
  );
}
''').unit;

      MethodInvocation? managedCall;
      unit.visitChildren(
          _MethodInvocationVisitor('managed', (node) => managedCall = node));

      expect(managedCall, isNotNull);
      expect(
          AvoidAsyncInManaged.isAsyncClosureInManaged(managedCall!), isFalse);
    });
  });
}

class _MethodInvocationVisitor extends RecursiveAstVisitor<void> {
  _MethodInvocationVisitor(this.methodName, this.onFound);
  final String methodName;
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == methodName) {
      onFound(node);
    }
    super.visitMethodInvocation(node);
  }
}
