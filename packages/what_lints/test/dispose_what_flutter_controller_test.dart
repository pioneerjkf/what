// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

void main() {
  group('DisposeWhatFlutterController AST detection', () {
    test('detects undisposed BoundTextController field in State class', () {
      final unit = parseString(content: '''
class _MyWidgetState extends State<MyWidget> {
  late final BoundTextController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BoundTextController(target);
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
      final undisposed =
          DisposeWhatFlutterController.findUndisposedControllers(clazz!);
      expect(undisposed.length, equals(1));
      expect(undisposed.first.name, equals('_controller'));
    });

    test('detects undisposed WhatTextEditingController field in State class',
        () {
      final unit = parseString(content: '''
class _MyWidgetState extends State<MyWidget> {
  late final WhatTextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WhatTextEditingController(target);
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
      final undisposed =
          DisposeWhatFlutterController.findUndisposedControllers(clazz!);
      expect(undisposed.length, equals(1));
      expect(undisposed.first.name, equals('_controller'));
    });

    test('permits properly disposed WhatTextEditingController in dispose()',
        () {
      final unit = parseString(content: '''
class _MyWidgetState extends State<MyWidget> {
  late final WhatTextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WhatTextEditingController(target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''').unit;

      ClassDeclaration? clazz;
      unit.visitChildren(_ClassVisitor((node) => clazz = node));

      expect(clazz, isNotNull);
      final undisposed =
          DisposeWhatFlutterController.findUndisposedControllers(clazz!);
      expect(undisposed, isEmpty);
    });

    test('does not flag WhatController as it uses subscriber-driven dormancy',
        () {
      final unit = parseString(content: '''
class _MyWidgetState extends State<MyWidget> {
  late final WhatController<int> _controller;

  @override
  void initState() {
    super.initState();
    _controller = WhatController(0);
  }

  @override
  Widget build(BuildContext context) {
    return Text('\${_controller.what.data}');
  }
}
''').unit;

      ClassDeclaration? clazz;
      unit.visitChildren(_ClassVisitor((node) => clazz = node));

      expect(clazz, isNotNull);
      final undisposed =
          DisposeWhatFlutterController.findUndisposedControllers(clazz!);
      expect(undisposed, isEmpty);
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
