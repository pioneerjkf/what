// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:what_lints/what_lints.dart';
import 'package:test/test.dart';

class _BridgingInvocationFinder extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> methodCalls = [];
  final List<PropertyAccess> propertyCalls = [];
  final List<PrefixedIdentifier> prefixedCalls = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (WhatTypeChecker.isReactiveBridgingMethod(node.methodName.name)) {
      methodCalls.add(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (WhatTypeChecker.isReactiveBridgingProperty(node.propertyName.name)) {
      propertyCalls.add(node);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (WhatTypeChecker.isReactiveBridgingProperty(node.identifier.name)) {
      prefixedCalls.add(node);
    }
    super.visitPrefixedIdentifier(node);
  }
}

void main() {
  group('AvoidBridgingInBuild AST detection', () {
    test(
        'detects toWhat, toWhatBy, toListenable inside Flutter Widget build() method',
        () {
      final unit = parseString(content: '''
class BadWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    final a = controller.toWhat();
    final b = notifier.toListenable();
    final selector = scrollController.toWhatBy((c) => c.offset);
    return Container();
  }
}
''').unit;

      final finder = _BridgingInvocationFinder();
      unit.accept(finder);

      expect(finder.methodCalls.length,
          equals(3)); // toWhat, toListenable, toWhatBy

      for (final call in finder.methodCalls) {
        expect(AvoidBridgingInBuild.isInsideBuildOrReactiveScope(call), isTrue);
      }
    });

    test('detects toWhat inside computed derivation scope', () {
      final unit = parseString(content: '''
void main() {
  final comp = computed((via) {
    final a = notifier.toWhat();
    return 10;
  });
}
''').unit;

      final finder = _BridgingInvocationFinder();
      unit.accept(finder);

      expect(finder.methodCalls.length, equals(1));
      expect(
          AvoidBridgingInBuild.isInsideBuildOrReactiveScope(
              finder.methodCalls.first),
          isTrue);
    });

    test('ignores bridging inside non-build methods or lifecycle initializers',
        () {
      final unit = parseString(content: '''
class GoodWidget extends StatelessWidget {
  late final a = controller.toWhat();
  late final b = notifier.toListenable();

  void initState() {
    final what = controller.toWhat();
  }

  Widget build(BuildContext context) {
    return Container();
  }
}
''').unit;

      final finder = _BridgingInvocationFinder();
      unit.accept(finder);

      expect(finder.methodCalls.length, equals(3));
      for (final call in finder.methodCalls) {
        expect(
            AvoidBridgingInBuild.isInsideBuildOrReactiveScope(call), isFalse);
      }
    });
  });
}
