// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scope.dart';

// =============================================================================
// whatWidgetTest Declarative Widget Test Runner
// =============================================================================

final List<List<WhatOverride>> _activeOverridesStack = [];

/// Extension providing scoped widget pumping helpers on [WidgetTester].
extension WhatTesterScopeExtension on WidgetTester {
  /// Pumps [widget] wrapped inside a [WhatTestScope] with the given [overrides].
  ///
  /// If [overrides] is omitted, automatically inherits the active overrides defined
  /// on the enclosing [whatWidgetTest] runner.
  ///
  /// ## Examples
  /// ```dart
  /// whatWidgetTest(
  ///   'renders offline banner on error',
  ///   overrides: [userListWhat.overrideWithError(SocketException('Offline'))],
  ///   test: (tester) async {
  ///     await tester.pumpScopedWidget(const MaterialApp(home: UserScreen()));
  ///     expect(find.text('Offline'), findsOneWidget);
  ///   },
  /// );
  /// ```
  Future<void> pumpScopedWidget(
    Widget widget, {
    List<WhatOverride>? overrides,
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  }) {
    final effectiveOverrides = overrides ??
        (_activeOverridesStack.isNotEmpty
            ? _activeOverridesStack.last
            : const <WhatOverride>[]);
    return pumpWidget(
      WhatTestScope(
        overrides: effectiveOverrides,
        child: widget,
      ),
      duration: duration,
      phase: phase,
    );
  }
}

/// A declarative, atomic Flutter widget test runner tailored for the What reactive framework.
///
/// Wraps Flutter's native [testWidgets] runner and supports declarative [overrides]
/// that are automatically supplied when using [WhatTesterScopeExtension.pumpScopedWidget], or can be explicitly
/// wrapped via [WhatTestScope].
///
/// If [autoFlushLpdag] is `true`, automatically flushes pending LPDAG 2-Phase microtask ticks
/// and UI frames at the end of the test turn.
///
/// ## Examples
/// ```dart
/// whatWidgetTest(
///   'renders counter value',
///   overrides: [
///     counterWhat.overrideWithValue(42),
///   ],
///   test: (tester) async {
///     await tester.pumpScopedWidget(const CounterDisplay());
///     expect(find.text('42'), findsOneWidget);
///   },
/// );
/// ```
void whatWidgetTest(
  String description, {
  List<WhatOverride> overrides = const [],
  required WidgetTesterCallback test,
  bool autoFlushLpdag = true,
  bool? skip,
  Timeout? timeout,
  dynamic tags,
}) {
  testWidgets(
    description,
    (tester) async {
      _activeOverridesStack.add(overrides);
      try {
        await test(tester);
        if (autoFlushLpdag) {
          await tester.pump();
        }
      } finally {
        _activeOverridesStack.removeLast();
      }
    },
    skip: skip,
    timeout: timeout,
    tags: tags,
  );
}
