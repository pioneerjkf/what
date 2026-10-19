// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// Complete, unified testing harness for Flutter apps using the What reactive framework.
///
/// Re-exports pure Dart `what_test` completely, allowing developers and AI agents to import
/// a single package for all unit tests and widget tests.
///
/// Provides:
/// * [whatWidgetTest] declarative widget test runner
/// * [WhatTestScope] & [WhatOverride] declarative node mocking system
/// * [WhatTesterScopeExtension.pumpScopedWidget]
/// * Full `what_test` re-export ([whatTest], [FakeAsync], [isDormant], [isActive], [hasGlitchFreedom], etc.)
/// * Full `flutter_test` re-export ([testWidgets], [find], [expect], [WidgetTester], etc.)
library what_flutter_test;

// Re-export pure Dart what_test (hiding flutter_test conflicts)
export 'package:what_test/what_test.dart'
    hide
        test,
        group,
        expect,
        expectLater,
        isInstanceOf,
        setUp,
        setUpAll,
        tearDown,
        tearDownAll;

// Re-export Flutter official test framework
export 'package:flutter_test/flutter_test.dart';

// Export Flutter-specific What test features
export 'src/runner.dart';
export 'src/scope.dart';
