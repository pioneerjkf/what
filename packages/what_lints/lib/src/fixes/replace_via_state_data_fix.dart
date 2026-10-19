// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use

part of '../../what_lints.dart';

/// A quick fix that simplifies `via.state(x).data` to `via(x)`.
class ReplaceViaStateDataFix extends DartFix {
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
      if (node.propertyName.name != 'data') return;

      final target = node.target;
      if (target is MethodInvocation && target.methodName.name == 'state') {
        final args = target.argumentList.arguments;
        if (args.isNotEmpty) {
          final argSource = args.first.toSource();
          final changeBuilder = reporter.createChangeBuilder(
            message: 'Simplify to via($argSource)',
            priority: 50,
          );
          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleReplacement(node.sourceRange, 'via($argSource)');
          });
        }
      }
    });
  }
}
