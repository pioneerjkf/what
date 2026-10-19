// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:what_lints/what_lints.dart';

void main() {
  group('AvoidEscapingVia AST detection', () {
    test('detects via() called after await in async closure', () {
      final unit = parseString(content: '''
void setup() {
  final userProfile = computed.future((via) async {
    final id = via(userId);
    final profile = await http.get('/user/\$id');
    final token = via(authToken);
    return filter(profile, token);
  });
}
''').unit;

      final viaCalls = <MethodInvocation>[];
      unit.visitChildren(_SimpleInvocationVisitor('via', (node) {
        viaCalls.add(node);
      }));

      expect(viaCalls.length, equals(2));
      // First via(userId) is before await -> safe
      expect(AvoidEscapingVia.isEscapingViaInvocation(viaCalls[0]), isFalse);
      // Second via(authToken) is after await -> escaping!
      expect(AvoidEscapingVia.isEscapingViaInvocation(viaCalls[1]), isTrue);
    });

    test('detects via() inside event callback parameter', () {
      final unit = parseString(content: '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context, WhatVia via) {
    return ElevatedButton(
      onPressed: () => print(via(counter)),
      child: Text('Click'),
    );
  }
}
''').unit;

      MethodInvocation? viaCall;
      unit.visitChildren(_SimpleInvocationVisitor('via', (node) {
        viaCall = node;
      }));

      expect(viaCall, isNotNull);
      expect(AvoidEscapingVia.isEscapingViaInvocation(viaCall!), isTrue);
    });

    test('detects via() inside async timer/dispatcher callback', () {
      final unit = parseString(content: '''
void setup() {
  final task = computed((via) {
    scheduleMicrotask(() {
      print(via(counter));
    });
    return 42;
  });
}
''').unit;

      MethodInvocation? viaCall;
      unit.visitChildren(_SimpleInvocationVisitor('via', (node) {
        viaCall = node;
      }));

      expect(viaCall, isNotNull);
      expect(AvoidEscapingVia.isEscapingViaInvocation(viaCall!), isTrue);
    });

    test('permits standard synchronous via() calls inside computed', () {
      final unit = parseString(content: '''
void setup() {
  final sum = computed((via) {
    return via(a) + via(b);
  });
}
''').unit;

      final viaCalls = <MethodInvocation>[];
      unit.visitChildren(_SimpleInvocationVisitor('via', (node) {
        viaCalls.add(node);
      }));

      expect(viaCalls.length, equals(2));
      expect(AvoidEscapingVia.isEscapingViaInvocation(viaCalls[0]), isFalse);
      expect(AvoidEscapingVia.isEscapingViaInvocation(viaCalls[1]), isFalse);
    });

    test('does not treat await inside nested local function as preceding await',
        () {
      final unit = parseString(content: '''
void setup() {
  final result = computed.future((via) async {
    void nestedHelper() async {
      await Future.delayed(Duration(seconds: 1));
    }
    final count = via(counter);
    return count * 2;
  });
}
''').unit;

      MethodInvocation? viaCall;
      unit.visitChildren(_SimpleInvocationVisitor('via', (node) {
        viaCall = node;
      }));

      expect(viaCall, isNotNull);
      expect(AvoidEscapingVia.isEscapingViaInvocation(viaCall!), isFalse);
    });
  });
}

class _SimpleInvocationVisitor extends RecursiveAstVisitor<void> {
  _SimpleInvocationVisitor(this.methodName, this.onFound);

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
