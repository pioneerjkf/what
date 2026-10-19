// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

void main() {
  group('PreferWhatOverController AST detection', () {
    test('detects WhatController parameter in StatelessWidget constructor', () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  const MyWidget({super.key, required this.controller});
  final WhatController<int> controller;

  @override
  Widget build(BuildContext context) => Container();
}
''').unit;

      ClassDeclaration? clazz;
      unit.visitChildren(_ClassVisitor((node) => clazz = node));

      expect(clazz, isNotNull);
      final constructor =
          clazz!.members.whereType<ConstructorDeclaration>().first;
      final param = constructor.parameters.parameters.last;
      final typeStr =
          PreferWhatOverController.getParameterTypeString(param, clazz!);
      expect(typeStr, startsWith('WhatController'));
    });

    test('permits read-only What<T> parameter in StatelessWidget', () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  const MyWidget({super.key, required this.count});
  final What<int> count;

  @override
  Widget build(BuildContext context) => Container();
}
''').unit;

      ClassDeclaration? clazz;
      unit.visitChildren(_ClassVisitor((node) => clazz = node));

      expect(clazz, isNotNull);
      final constructor =
          clazz!.members.whereType<ConstructorDeclaration>().first;
      final param = constructor.parameters.parameters.last;
      final typeStr =
          PreferWhatOverController.getParameterTypeString(param, clazz!);
      expect(typeStr, startsWith('What<int>'));
    });
  });
}

class _ClassVisitor extends RecursiveAstVisitor<void> {
  _ClassVisitor(this.onFound);
  final void Function(ClassDeclaration) onFound;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    onFound(node);
    super.visitClassDeclaration(node);
  }
}
