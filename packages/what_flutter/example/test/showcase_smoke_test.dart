// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';
import 'package:what_flutter_example/main.dart';
import 'package:what_flutter_example/store/showcase_store.dart';

void main() {
  testWidgets(
      'WhatShowcaseApp renders and switches through all 18 sections without exceptions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = ShowcaseStore(textEditingGraceful: Graceful.none);
    await tester.pumpWidget(WhatShowcaseApp(store: store));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify initial render (Section 01)
    expect(find.text('What Flutter Showcase'), findsOneWidget);
    expect(find.text('WhatWidget & Dynamic Discovery'), findsWidgets);

    final app = tester.widget<WhatShowcaseApp>(find.byType(WhatShowcaseApp));
    final sections = store.sections.all;

    // Iterate through all sections
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      app.store.selectSection(i);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(section.title), findsWidgets);
    }
    // Test toggle sidebar
    app.store.toggleSidebar();
    await tester.pump(const Duration(milliseconds: 300));
    app.store.toggleSidebar();
    await tester.pump(const Duration(milliseconds: 300));

    // Flush any pending async timers
    await tester.pump(const Duration(seconds: 1));
  });
}
