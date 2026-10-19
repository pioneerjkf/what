// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use

part of '../../what_lints.dart';

/// A quick fix that wraps direct, untracked reactive reads with `via()` or `via.state()`.
class WrapWithViaFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addPropertyAccess((node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      _handleProperty(reporter, node.target, node.propertyName.name, node);
    });

    context.registry.addPrefixedIdentifier((node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      _handleProperty(reporter, node.prefix, node.identifier.name, node);
    });
  }

  void _handleProperty(
    ChangeReporter reporter,
    Expression? target,
    String propName,
    Expression fullNode,
  ) {
    if (target == null) return;

    final targetType = target.staticType;
    final isController =
        WhatTypeChecker.isControllerOrCouplerType(targetType?.element?.name);

    if (propName == 'peek' || propName == 'data') {
      final changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap with via(...)',
        priority: 50,
      );
      changeBuilder.addDartFileEdit((builder) {
        final targetSource = target.toSource();
        final replacement =
            isController ? 'via($targetSource.what)' : 'via($targetSource)';
        builder.addSimpleReplacement(fullNode.sourceRange, replacement);
      });
    } else if (propName == 'peekState') {
      final changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap with via.state(...)',
        priority: 50,
      );
      changeBuilder.addDartFileEdit((builder) {
        final targetSource = target.toSource();
        final replacement = isController
            ? 'via.state($targetSource.what)'
            : 'via.state($targetSource)';
        builder.addSimpleReplacement(fullNode.sourceRange, replacement);
      });
    } else if (WhatTypeChecker.isPipelineReadProperty(propName)) {
      final changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap target with via.state(...)',
        priority: 50,
      );
      changeBuilder.addDartFileEdit((builder) {
        final targetSource = target.toSource();
        final viaTarget = isController
            ? 'via.state($targetSource.what)'
            : 'via.state($targetSource)';
        final replacement = '$viaTarget.$propName';
        builder.addSimpleReplacement(fullNode.sourceRange, replacement);
      });
    }
  }
}
