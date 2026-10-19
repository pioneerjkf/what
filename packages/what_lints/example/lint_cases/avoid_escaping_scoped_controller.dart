// Canonical lint cases for `avoid_escaping_scoped_controller`.
// Grammar: see what_lints/test/harness/lint_harness.dart

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

final durableCtrl =
    DurableAnimationController(duration: const Duration(seconds: 1));

// =============================================================================
// BAD
// =============================================================================

// #case avoid_escaping_scoped_controller/bad/field-declaration
class BadStoreWithScopedField {
  // expect_lint: avoid_escaping_scoped_controller
  ScopedAnimationController? controller;
}

// #case avoid_escaping_scoped_controller/bad/escape-view-to-field
class BadEscapeViewToField extends StatefulWidget {
  const BadEscapeViewToField({super.key});

  @override
  State<BadEscapeViewToField> createState() => _BadEscapeViewToFieldState();
}

class _BadEscapeViewToFieldState extends State<BadEscapeViewToField> {
  Animation<double>? _leakedView;

  @override
  Widget build(BuildContext context) {
    return composed.animate(durableCtrl, (context, via, ctrl) {
      // expect_lint: avoid_escaping_scoped_controller
      _leakedView = ctrl.view;
      return Text('$_leakedView');
    });
  }
}

// #case avoid_escaping_scoped_controller/bad/escape-view-to-outer-variable
Widget badEscapeViewToOuterVariable() {
  Animation<double>? outerView;
  return composed.animate(durableCtrl, (context, via, ctrl) {
    // expect_lint: avoid_escaping_scoped_controller
    outerView = ctrl.view;
    return Text('$outerView');
  });
}

// #case avoid_escaping_scoped_controller/bad/escape-to-outer-list
Widget badEscapeToOuterList() {
  final outerList = <Animation<double>>[];
  return composed.animate(durableCtrl, (context, via, ctrl) {
    // expect_lint: avoid_escaping_scoped_controller
    outerList.add(ctrl.view);
    return Text('${outerList.length}');
  });
}

// #case avoid_escaping_scoped_controller/bad/escape-in-children
Widget badEscapeInChildren() {
  Animation<double>? leaked;
  return composed.animate.children(
    durableCtrl,
    (context, via, ctrl, children) {
      // expect_lint: avoid_escaping_scoped_controller
      leaked = ctrl.view;
      return Column(children: [Text('$leaked'), ...children]);
    },
    children: const [Text('Item')],
  );
}

// =============================================================================
// GOOD
// =============================================================================

// #case avoid_escaping_scoped_controller/good/durable-controller-field
class GoodStoreWithDurableField {
  final controller =
      DurableAnimationController(duration: const Duration(seconds: 1));
}

// #case avoid_escaping_scoped_controller/good/local-view-in-transition
class GoodLocalViewUsage extends StatelessWidget {
  const GoodLocalViewUsage({super.key});

  @override
  Widget build(BuildContext context) {
    const label = Text('Good');
    return composed.animate(durableCtrl, (context, via, ctrl) {
      return FadeTransition(
        opacity: ctrl.view,
        child: label,
      );
    });
  }
}

// #case avoid_escaping_scoped_controller/good/local-variable-in-builder
Widget goodLocalVariableInBuilder() {
  const label = Text('Local');
  return composed.animate(durableCtrl, (context, via, ctrl) {
    final localView = ctrl.view;
    return FadeTransition(
      opacity: localView,
      child: label,
    );
  });
}
