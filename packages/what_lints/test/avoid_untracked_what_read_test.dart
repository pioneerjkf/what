// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:what_lints/what_lints.dart';
import 'package:test/test.dart';

class _UntrackedPayloadVisitor extends RecursiveAstVisitor<void> {
  final List<AstNode> untrackedNodes = [];

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (WhatTypeChecker.isPipelineReadProperty(node.identifier.name)) {
      if (AvoidUntrackedWhatRead.isUntrackedInWhatViaScope(node)) {
        untrackedNodes.add(node);
      }
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (WhatTypeChecker.isPipelineReadProperty(node.propertyName.name)) {
      if (AvoidUntrackedWhatRead.isUntrackedInWhatViaScope(node)) {
        untrackedNodes.add(node);
      }
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (WhatTypeChecker.isPipelineReadMethod(methodName)) {
      if (AvoidUntrackedWhatRead.isUntrackedInWhatViaScope(node)) {
        untrackedNodes.add(node);
      }
    } else if (WhatTypeChecker.isWhatUntrackedInvocation(node)) {
      if (AvoidUntrackedWhatRead.isUntrackedInWhatViaScope(node)) {
        untrackedNodes.add(node);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (WhatTypeChecker.isWhatUntrackedInvocation(node)) {
      if (AvoidUntrackedWhatRead.isUntrackedInWhatViaScope(node)) {
        untrackedNodes.add(node);
      }
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    if (AvoidUntrackedWhatRead.isUntrackedInWhatViaScope(node)) {
      final typeName = node.type.toString();
      if (typeName.startsWith('WhatState')) {
        untrackedNodes.add(node);
      }
    }
    super.visitAsExpression(node);
  }
}

void main() {
  group('AvoidUntrackedWhatRead AST detection', () {
    test('detects untracked .data inside computed((via) => ...) closure', () {
      final unit = parseString(content: '''
void testComputed() {
  final doubled = computed((via) {
    final raw = counter.data; // [Anti-Pattern] Untracked direct read!
    return raw * 2;
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(1));
    });

    test('permits tracked via(counter) inside computed((via) => ...)', () {
      final unit = parseString(content: '''
void testComputed() {
  final doubled = computed((via) {
    final tracked = via(counter); // [Recommended] Valid explicit manifest
    return tracked * 2;
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(0));
    });

    test('detects untracked .data, .snapshot, .hasData inside WhatWidget.build',
        () {
      final unit = parseString(content: '''
class MyWhatWidget extends WhatWidget {
  final What<int> countWhat;
  MyWhatWidget(this.countWhat);

  @override
  Widget build(BuildContext context, WhatVia via) {
    final a = countWhat.data; // [Anti-Pattern] Untracked
    final b = countWhat.snapshot; // [Anti-Pattern] Untracked
    final c = countWhat.hasData; // [Anti-Pattern] Untracked
    return Text('\$a');
  }
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(3));
    });

    test('permits via(countWhat) inside WhatWidget.build', () {
      final unit = parseString(content: '''
class MyWhatWidget extends WhatWidget {
  final What<int> countWhat;
  MyWhatWidget(this.countWhat);

  @override
  Widget build(BuildContext context, WhatVia via) {
    final a = via(countWhat); // [Recommended] Tracked
    return Text('\$a');
  }
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(0));
    });

    test(
        'detects untracked .data in composed((via) => ...) micro-rebuild functor',
        () {
      final unit = parseString(content: '''
Widget testComposed() {
  return composed((via) => Text('\${counter.data}')); // [Anti-Pattern] Untracked
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(1));
    });

    test(
        'detects untracked .data in switched((via) => ...) dynamic branch functor',
        () {
      final unit = parseString(content: '''
void testSwitched() {
  final s = switched((via) {
    return via(isDark) ? darkWhat.data : lightWhat.data; // [Anti-Pattern] 2 untracked reads
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(2));
    });

    test('detects untracked .data in Effect((via) => ...)', () {
      final unit = parseString(content: '''
void testEffect() {
  Effect((via) {
    print(counter.data); // [Anti-Pattern] Untracked
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(1));
    });

    test('permits .data inside event handlers within WhatWidget.build', () {
      final unit = parseString(content: '''
class SafeEventWidget extends WhatWidget {
  final What<int> countWhat;
  SafeEventWidget(this.countWhat);

  @override
  Widget build(BuildContext context, WhatVia via) {
    final count = via(countWhat);
    return ElevatedButton(
      onPressed: () {
        final current = countWhat.data; // [Recommended] Safe in user event handler
        print(current);
      },
      child: Text('\$count'),
    );
  }
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(0));
    });

    test('permits via(node) inside inline builder with via parameter', () {
      final unit = parseString(content: '''
class SampleWidget extends StatelessWidget {
  final What<int> count;
  SampleWidget(this.count);

  @override
  Widget build(BuildContext context) {
    return composed.context(
      (context, via) => Text('Count: \${via(count)}'),
    );
  }
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(0));
    });

    test('detects untracked context.whatOf<T>().data inside WhatWidget.build',
        () {
      final unit = parseString(content: '''
class MyWhatWidget extends WhatWidget {
  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = context.whatOf<MyStore>().data; // [Anti-Pattern] Untracked
    return Text('\$store');
  }
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(1));
    });

    test('permits tracked via.of<T>(context).data inside WhatWidget.build', () {
      final unit = parseString(content: '''
class MyWhatWidget extends WhatWidget {
  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<MyStore>(context).data;
    final optional = via.maybeOf<MyStore>(context).data;
    return Text('\$store \$optional');
  }
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(0));
    });
    test('detects untracked(...) and untracked.state(...) inside computed', () {
      final unit = parseString(content: '''
void testComputed() {
  final result = computed((via) {
    final a = untracked(countWhat);
    final b = untracked.state(countWhat);
    return a;
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(2));
    });

    test('detects untracked .data on WhatController inside computed', () {
      final unit = parseString(content: '''
void testComputed() {
  final result = computed((via) {
    final val = countController.data;
    return val * 2;
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(1));
    });

    test('detects manual cast to WhatState inside WhatVia scope', () {
      final unit = parseString(content: '''
void testComputed() {
  final result = computed((via) {
    final state = countWhat as WhatState<int>;
    return state.data;
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      // Both the cast and the .data read are caught
      expect(visitor.untrackedNodes.length, greaterThanOrEqualTo(1));
    });

    test('detects untracked(...) inside computed', () {
      final unit = parseString(content: '''
void testComputed() {
  final result = computed((via) {
    final a = untracked(countWhat);
    return a * 2;
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(1));
    });

    test('detects untracked.state(...) inside computed', () {
      final unit = parseString(content: '''
void testComputed() {
  final result = computed((via) {
    final state = untracked.state(countWhat);
    return state.data;
  });
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, greaterThanOrEqualTo(1));
    });

    test('permits untracked(...) inside event handlers in WhatWidget', () {
      final unit = parseString(content: '''
class MyWidget extends WhatWidget {
  final What<int> countWhat;
  MyWidget(this.countWhat);

  @override
  Widget build(BuildContext context, WhatVia via) {
    return ElevatedButton(
      onPressed: () {
        final a = untracked(countWhat);
        print(a);
      },
      child: Text('Click'),
    );
  }
}
''').unit;

      final visitor = _UntrackedPayloadVisitor();
      unit.accept(visitor);

      expect(visitor.untrackedNodes.length, equals(0));
    });
  });
}
