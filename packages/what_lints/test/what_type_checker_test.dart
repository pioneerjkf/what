// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:what_lints/what_lints.dart';
import 'package:test/test.dart';

void main() {
  group('WhatTypeChecker', () {
    test('package URI identification for What ecosystem packages', () {
      expect(
          WhatTypeChecker.isWhatPackageUri('package:what/what.dart'), isTrue);
      expect(
          WhatTypeChecker.isWhatPackageUri(
              'package:what_flutter/what_flutter.dart'),
          isTrue);
      expect(
          WhatTypeChecker.isWhatPackageUri(
              'package:what_extensions/extensions.dart'),
          isTrue);
      expect(
          WhatTypeChecker.isWhatPackageUri(
              'package:what_lints/what_lints.dart'),
          isTrue);

      expect(WhatTypeChecker.isWhatPackageUri('package:flutter/material.dart'),
          isFalse);
      expect(WhatTypeChecker.isWhatPackageUri('package:riverpod/riverpod.dart'),
          isFalse);
      expect(WhatTypeChecker.isWhatPackageUri(null), isFalse);
    });

    test(
        'isControllerOrCouplerType identifies real producer controllers and couplers',
        () {
      expect(
          WhatTypeChecker.isControllerOrCouplerType('WhatController'), isTrue);
      expect(WhatTypeChecker.isControllerOrCouplerType('RawWhatController'),
          isTrue);
      expect(WhatTypeChecker.isControllerOrCouplerType('WhatListController'),
          isTrue);
      expect(WhatTypeChecker.isControllerOrCouplerType('WhatSetController'),
          isTrue);
      expect(WhatTypeChecker.isControllerOrCouplerType('WhatMapController'),
          isTrue);
      expect(WhatTypeChecker.isControllerOrCouplerType('WhatCoupler'), isTrue);
      expect(WhatTypeChecker.isControllerOrCouplerType('WhatSignalController'),
          isTrue);

      // Terminals and non-producers are exempt
      expect(WhatTypeChecker.isControllerOrCouplerType('RawWhatTerminal'),
          isFalse);
      expect(
          WhatTypeChecker.isControllerOrCouplerType('RawViaTerminal'), isFalse);
      expect(WhatTypeChecker.isControllerOrCouplerType('RawComputedTerminal'),
          isFalse);
      expect(WhatTypeChecker.isControllerOrCouplerType('What'), isFalse);
      expect(
          WhatTypeChecker.isControllerOrCouplerType(
              'FrozenAnimationController'),
          isFalse);
      expect(WhatTypeChecker.isControllerOrCouplerType('Container'), isFalse);
      expect(WhatTypeChecker.isControllerOrCouplerType(null), isFalse);
    });

    test(
        'isReactiveBridgingMethod identifies valid reactive bridging factory methods',
        () {
      expect(WhatTypeChecker.isReactiveBridgingMethod('toWhat'), isTrue);
      expect(WhatTypeChecker.isReactiveBridgingMethod('toWhatBy'), isTrue);
      expect(WhatTypeChecker.isReactiveBridgingMethod('toListenable'), isTrue);

      expect(WhatTypeChecker.isReactiveBridgingMethod('map'), isFalse);
      expect(WhatTypeChecker.isReactiveBridgingMethod('set'), isFalse);
      expect(WhatTypeChecker.isReactiveBridgingMethod(null), isFalse);
    });

    test(
        'isReactiveBridgingProperty is empty in modern What (all bridges are methods)',
        () {
      expect(WhatTypeChecker.isReactiveBridgingProperty('asStream'), isFalse);
      expect(WhatTypeChecker.isReactiveBridgingProperty('asTerminal'), isFalse);
      expect(
          WhatTypeChecker.isReactiveBridgingProperty('toListenable'), isFalse);
      expect(WhatTypeChecker.isReactiveBridgingProperty('data'), isFalse);
      expect(WhatTypeChecker.isReactiveBridgingProperty(null), isFalse);
    });

    test(
        'isPipelineReadProperty identifies valid reactive payload getters on WhatState',
        () {
      expect(WhatTypeChecker.isPipelineReadProperty('data'), isTrue);
      expect(WhatTypeChecker.isPipelineReadProperty('dataOrNull'), isTrue);
      expect(WhatTypeChecker.isPipelineReadProperty('snapshot'), isTrue);
      expect(WhatTypeChecker.isPipelineReadProperty('hasData'), isTrue);
      expect(WhatTypeChecker.isPipelineReadProperty('isEmpty'), isTrue);
      expect(WhatTypeChecker.isPipelineReadProperty('emptyReason'), isTrue);
      expect(WhatTypeChecker.isPipelineReadProperty('hasError'), isTrue);
      expect(WhatTypeChecker.isPipelineReadProperty('error'), isTrue);
      expect(WhatTypeChecker.isPipelineReadProperty('stackTrace'), isTrue);

      // Obsolete/Phantom properties
      expect(WhatTypeChecker.isPipelineReadProperty('nodes'), isFalse);
      expect(WhatTypeChecker.isPipelineReadProperty('nodesOrNull'), isFalse);
      expect(WhatTypeChecker.isPipelineReadProperty('nodesOrEmpty'), isFalse);
      expect(WhatTypeChecker.isPipelineReadProperty('value'), isFalse);
      expect(WhatTypeChecker.isPipelineReadProperty(null), isFalse);
    });

    test(
        'isPipelineReadMethod identifies valid reactive payload extraction methods on WhatState',
        () {
      expect(WhatTypeChecker.isPipelineReadMethod('dataOrElse'), isTrue);
      expect(WhatTypeChecker.isPipelineReadMethod('match'), isTrue);
      expect(WhatTypeChecker.isPipelineReadMethod('matchOrElse'), isTrue);
      expect(WhatTypeChecker.isPipelineReadMethod('matchOrNull'), isTrue);
      expect(WhatTypeChecker.isPipelineReadMethod('when'), isTrue);
      expect(WhatTypeChecker.isPipelineReadMethod('whenOrElse'), isTrue);
      expect(WhatTypeChecker.isPipelineReadMethod('whenOrNull'), isTrue);

      expect(WhatTypeChecker.isPipelineReadMethod('map'), isFalse);
      expect(WhatTypeChecker.isPipelineReadMethod('set'), isFalse);
      expect(WhatTypeChecker.isPipelineReadMethod(null), isFalse);
    });

    test(
        'isPipelineWriteMethod identifies verified real state-writing and coupling methods',
        () {
      // 1. Controller state writes
      expect(WhatTypeChecker.isPipelineWriteMethod('set'), isTrue);
      expect(WhatTypeChecker.isPipelineWriteMethod('setGuarded'), isTrue);
      expect(WhatTypeChecker.isPipelineWriteMethod('setError'), isTrue);
      expect(WhatTypeChecker.isPipelineWriteMethod('empty'), isTrue);
      expect(WhatTypeChecker.isPipelineWriteMethod('markDirty'), isTrue);

      // 2. Collection draft edits
      expect(WhatTypeChecker.isPipelineWriteMethod('edit'), isTrue);
      expect(WhatTypeChecker.isPipelineWriteMethod('editGuarded'), isTrue);

      // 3. Coupler dynamic coupling
      expect(WhatTypeChecker.isPipelineWriteMethod('couple'), isTrue);
      expect(WhatTypeChecker.isPipelineWriteMethod('coupleGuarded'), isTrue);
      expect(WhatTypeChecker.isPipelineWriteMethod('decouple'), isTrue);
      expect(WhatTypeChecker.isPipelineWriteMethod('tryDecoupling'), isTrue);

      // Non-writing / Phantom methods
      expect(WhatTypeChecker.isPipelineWriteMethod('swapSource'), isFalse);
      expect(WhatTypeChecker.isPipelineWriteMethod('swapSources'), isFalse);
      expect(WhatTypeChecker.isPipelineWriteMethod('dataOrElse'), isFalse);
      expect(WhatTypeChecker.isPipelineWriteMethod(null), isFalse);
    });

    test(
        'isPipelineWriteProperty identifies only verified real state-writing setters',
        () {
      expect(WhatTypeChecker.isPipelineWriteProperty('data'), isTrue);

      // Phantom properties
      expect(WhatTypeChecker.isPipelineWriteProperty('nodes'), isFalse);
      expect(WhatTypeChecker.isPipelineWriteProperty('sources'), isFalse);
      expect(WhatTypeChecker.isPipelineWriteProperty('snapshot'), isFalse);
      expect(WhatTypeChecker.isPipelineWriteProperty('dataOrNull'), isFalse);
      expect(WhatTypeChecker.isPipelineWriteProperty(null), isFalse);
    });

    test(
        'isPipelineEvaluationMethod identifies verified evaluation, derivation & UI render methods',
        () {
      // Core functors
      expect(WhatTypeChecker.isPipelineEvaluationMethod('computed'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('switched'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('managed'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('distinct'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('effect'), isTrue);

      // Flutter UI functors
      expect(WhatTypeChecker.isPipelineEvaluationMethod('build'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('drive'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('animate'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('match'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('when'), isTrue);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('listen'), isTrue);

      // Phantom / Obsolete methods
      expect(WhatTypeChecker.isPipelineEvaluationMethod('map'), isFalse);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('select'), isFalse);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('cascade'), isFalse);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('resource'), isFalse);
      expect(WhatTypeChecker.isPipelineEvaluationMethod('set'), isFalse);
      expect(WhatTypeChecker.isPipelineEvaluationMethod(null), isFalse);
    });

    test('What target and type checks handle null/unresolved safely', () {
      expect(WhatTypeChecker.isWhatTarget(null), isFalse);
      expect(WhatTypeChecker.isWhatType(null), isFalse);

      final unit = parseString(content: '''
void test() {
  counterWhat;
  signalWhat;
  what;
  whatSignal;
  whatScreen;
  whatever;
  showWhatToDoDialog();
}
''').unit;

      final identifiers = <SimpleIdentifier>[];
      unit.visitChildren(_IdentifierCollector((node) => identifiers.add(node)));

      final counterWhatId =
          identifiers.firstWhere((id) => id.name == 'counterWhat');
      final signalWhatId =
          identifiers.firstWhere((id) => id.name == 'signalWhat');
      final whatId = identifiers.firstWhere((id) => id.name == 'what');
      final whatSignalId =
          identifiers.firstWhere((id) => id.name == 'whatSignal');
      final whatScreenId =
          identifiers.firstWhere((id) => id.name == 'whatScreen');
      final whateverId = identifiers.firstWhere((id) => id.name == 'whatever');

      expect(WhatTypeChecker.isWhatTarget(counterWhatId), isTrue);
      expect(WhatTypeChecker.isWhatTarget(signalWhatId), isTrue);
      expect(WhatTypeChecker.isWhatTarget(whatId), isTrue);
      expect(WhatTypeChecker.isWhatTarget(whatSignalId), isFalse);
      expect(WhatTypeChecker.isWhatTarget(whatScreenId), isFalse);
      expect(WhatTypeChecker.isWhatTarget(whateverId), isFalse);
    });

    test(
        'isAsyncOrTimerInvocation strictly requires valid targets or top-level functions',
        () {
      final unit = parseString(content: '''
void test() {
  scheduleMicrotask(() {});
  Future.microtask(() {});
  Future.delayed(Duration.zero, () {});
  Timer.run(() {});
  future.then((v) {});
  future.catchError((e) {});
  future.whenComplete(() {});

  // Invalid / Untargeted invocations that must NOT match
  then(() {});
  catchError((e) {});
  whenComplete(() {});
  microtask(() {});
  delayed(() {});
  run(() {});
  foo.run(() {});
}
''').unit;

      final invocations = <MethodInvocation>[];
      unit.visitChildren(_InvocationCollector((node) => invocations.add(node)));

      MethodInvocation find(String name, {bool hasTarget = true}) =>
          invocations.firstWhere((i) =>
              i.methodName.name == name &&
              (hasTarget ? i.target != null : i.target == null));

      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('scheduleMicrotask', hasTarget: false)),
          isTrue);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('microtask', hasTarget: true)),
          isTrue);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('delayed', hasTarget: true)),
          isTrue);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('run', hasTarget: true)),
          isTrue);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('then', hasTarget: true)),
          isTrue);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('catchError', hasTarget: true)),
          isTrue);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('whenComplete', hasTarget: true)),
          isTrue);

      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('then', hasTarget: false)),
          isFalse);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('catchError', hasTarget: false)),
          isFalse);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('whenComplete', hasTarget: false)),
          isFalse);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('microtask', hasTarget: false)),
          isFalse);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('delayed', hasTarget: false)),
          isFalse);
      expect(
          WhatTypeChecker.isAsyncOrTimerInvocation(
              find('run', hasTarget: false)),
          isFalse);

      final fooRun = invocations.firstWhere(
          (i) => i.methodName.name == 'run' && i.target?.toSource() == 'foo');
      expect(WhatTypeChecker.isAsyncOrTimerInvocation(fooRun), isFalse);
    });

    test(
        'isInsideWhatViaScope identifies reactive scopes and does NOT treat isolated via call as scope',
        () {
      final unit = parseString(content: '''
void normalFunction() {
  via(counter);
  final a = counter.data;
}

void testComputed() {
  computed((via) {
    final b = counter.data;
  });
}
''').unit;

      final identifiers = <SimpleIdentifier>[];
      unit.visitChildren(_IdentifierCollector((node) => identifiers.add(node)));

      final normalViaCounter = identifiers.firstWhere((id) =>
          id.name == 'counter' &&
          id.parent?.parent?.toSource() == 'via(counter)');
      final normalDirectCounter = identifiers.firstWhere((id) =>
          id.name == 'counter' &&
          id.parent?.toSource() == 'counter.data' &&
          id.parent?.parent?.toSource() == 'a = counter.data');
      final computedCounter = identifiers.firstWhere((id) =>
          id.name == 'counter' &&
          id.parent?.toSource() == 'counter.data' &&
          id.parent?.parent?.toSource() == 'b = counter.data');

      expect(WhatTypeChecker.isInsideWhatViaScope(normalViaCounter), isFalse);
      expect(
          WhatTypeChecker.isInsideWhatViaScope(normalDirectCounter), isFalse);
      expect(WhatTypeChecker.isInsideWhatViaScope(computedCounter), isTrue);
    });
  });
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  final void Function(SimpleIdentifier) onIdentifier;
  _IdentifierCollector(this.onIdentifier);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    onIdentifier(node);
    super.visitSimpleIdentifier(node);
  }
}

class _InvocationCollector extends RecursiveAstVisitor<void> {
  final void Function(MethodInvocation) onInvocation;
  _InvocationCollector(this.onInvocation);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onInvocation(node);
    super.visitMethodInvocation(node);
  }
}
