// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// Official static analysis rules and automated lint checks for the What reactive state framework and What Flutter.
///
/// Enforces architectural invariants such as Producer/Consumer separation, zero-escaping
/// `WhatVia` scopes, proper controller lifecycle disposal, and rebuild isolation.
library what_lints;

import 'dart:math' as math;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

// Util parts
part 'src/util/flutter_ast_utils.dart';
part 'src/util/what_type_checker.dart';

// Core rule parts (Pure Dart LPDAG / Reactive Invariants)
part 'src/rules/core/avoid_async_in_managed.dart';
part 'src/rules/core/avoid_catching_via_short_circuit.dart';
part 'src/rules/core/avoid_escaping_via.dart';
part 'src/rules/core/avoid_state_writes_in_pipeline.dart';
part 'src/rules/core/avoid_unnecessary_via_scope.dart';
part 'src/rules/core/avoid_untracked_what_read.dart';
part 'src/rules/core/avoid_via_state_when_value_suffices.dart';

// Flutter rule parts (UI / Lifecycle / Widget Guards)
part 'src/rules/flutter/avoid_bridging_in_build.dart';
part 'src/rules/flutter/avoid_escaping_scoped_controller.dart';
part 'src/rules/flutter/avoid_what_creation_in_build.dart';
part 'src/rules/flutter/deactivate_effect_runner.dart';
part 'src/rules/flutter/prefer_composed_child.dart';
part 'src/rules/flutter/prefer_what_over_controller.dart';

// Self-Healing QuickFix parts
part 'src/fixes/wrap_with_via_fix.dart';
part 'src/fixes/replace_via_state_data_fix.dart';

/// Entrypoint for the `what_lints` custom_lint analyzer plugin.
PluginBase createPlugin() => _WhatLinter();

class _WhatLinter extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        // Core Reactive Invariant Rules (Pure Dart)
        AvoidAsyncInManaged(),
        AvoidCatchingViaShortCircuit(),
        AvoidEscapingVia(),
        AvoidStateWritesInPipeline(),
        AvoidUnnecessaryViaScope(),
        AvoidUntrackedWhatRead(),
        AvoidViaStateWhenValueSuffices(),

        // Flutter Integration Rules (UI & Lifecycle Guards)
        AvoidBridgingInBuild(),
        AvoidEscapingScopedController(),
        AvoidWhatCreationInBuild(),
        DeactivateEffectRunner(),
        PreferComposedChild(),
        PreferWhatOverController(),
      ];
}
