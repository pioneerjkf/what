// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter_example/main.dart';
import 'package:what_flutter_example/store/showcase_store.dart';

void main() {
  testWidgets(
      'Switching tabs in Showcase preserves and advances CatchUp animation without resetting',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    DateTime mockNow = DateTime(2026, 1, 1, 12, 0, 0);
    final store = ShowcaseStore(
      initialIndex: 12, // Section: Dual Engine Battle
      clock: () => mockNow,
    );

    await tester.pumpWidget(WhatShowcaseApp(store: store));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Section 11 is visible and animating
    expect(find.text('CatchUp (Time-Compensated)'), findsOneWidget);
    final controller = store.sections.dualEngineBattle.catchUpCtrl;
    expect(controller.isAnimating, isTrue);

    // 1. Switch to Section 01 (WhatWidget)
    store.selectSection(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // CatchUp widget is unmounted -> controller is detached and dormant
    expect(find.text('CatchUp (Time-Compensated)'), findsNothing);

    // 2. Advance time by 2.0s (half of the 4s cycle)
    mockNow = mockNow.add(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 2000));

    // 3. Switch back to Section (Dual Engine Battle)
    store.selectSection(12);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Section 05 is remounted and animation continues seamlessly with advanced value
    expect(find.text('CatchUp (Time-Compensated)'), findsOneWidget);
    expect(controller.isAnimating, isTrue);
    expect(controller.value, greaterThan(0.3));

    store.sections.dualEngineBattle.frozenCtrl.stop();
    store.sections.dualEngineBattle.catchUpCtrl.stop();
    await tester.pumpWidget(const SizedBox());
  });
}
