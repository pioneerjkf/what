// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

void main() {
  group('DeactivateEffectRunner AST detection', () {
    test('detects undeactivated EffectRunner field in State class', () {
      final unit = parseString(content: '''
class _MyWidgetState extends State<MyWidget> {
  EffectRunner? _runner;

  @override
  void initState() {
    super.initState();
    _runner = counterWhat.effect(() => print(counterWhat.data)).run();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
''').unit;

      ClassDeclaration? clazz;
      unit.visitChildren(_ClassVisitor((node) => clazz = node));

      expect(clazz, isNotNull);
      final uncancelled = DeactivateEffectRunner.findUncancelledRunners(clazz!);
      expect(uncancelled.length, equals(1));
      expect(uncancelled.first.name, equals('_runner'));
    });

    test('permits properly deactivated EffectRunner in dispose()', () {
      final unit = parseString(content: '''
class _MyWidgetState extends State<MyWidget> {
  EffectRunner? _runner;

  @override
  void initState() {
    super.initState();
    _runner = counterWhat.effect(() => print(counterWhat.data)).run();
  }

  @override
  void dispose() {
    _runner?.deactivate();
    super.dispose();
  }
}
''').unit;

      ClassDeclaration? clazz;
      unit.visitChildren(_ClassVisitor((node) => clazz = node));

      expect(clazz, isNotNull);
      final uncancelled = DeactivateEffectRunner.findUncancelledRunners(clazz!);
      expect(uncancelled, isEmpty);
    });

    test('also permits .cancel() invocation for backward compatibility', () {
      final unit = parseString(content: '''
class _MyWidgetState extends State<MyWidget> {
  EffectRunner? _runner;

  @override
  void initState() {
    super.initState();
    _runner = counterWhat.effect(() => print(counterWhat.data)).run();
  }

  @override
  void dispose() {
    _runner?.cancel();
    super.dispose();
  }
}
''').unit;

      ClassDeclaration? clazz;
      unit.visitChildren(_ClassVisitor((node) => clazz = node));

      expect(clazz, isNotNull);
      final uncancelled = DeactivateEffectRunner.findUncancelledRunners(clazz!);
      expect(uncancelled, isEmpty);
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
