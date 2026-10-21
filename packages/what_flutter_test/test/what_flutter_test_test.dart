// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import 'package:what_flutter_test/what_flutter_test.dart';

// Sample Models & Widgets for Testing
class UserProfile {
  const UserProfile(this.name);
  final String name;
}

base class UserProfileWidget extends WhatWidget {
  const UserProfileWidget({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final userWhat = context.whatOf<UserProfile>();
    final userState = via.state(userWhat);

    return switch (userState.phase) {
      WhatPhase.valid => Text('User: ${userState.data.name}'),
      WhatPhase.empty => Text('No profile (${userState.emptyReason})'),
      WhatPhase.error => Text('Failed: ${userState.error}'),
    };
  }
}

base class CounterDisplay extends WhatWidget {
  const CounterDisplay({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final count = via.of<int>(context);
    return Text('Count: $count');
  }
}

void main() {
  group('what_flutter_test Unified Test Suite', () {
    // 1. Re-exported whatTest from what_test works seamlessly
    whatTest<WhatController<int>>(
      '1. Re-exported whatTest executes pure unit test logic',
      build: () => WhatController(10),
      target: (ctrl) => ctrl.what,
      act: (ctrl) => ctrl.data = 20,
      expect: () => [10, 20],
      verify: (ctrl) {
        expect(ctrl.data, 20);
      },
    );

    // 2. WhatTestScope and WhatOverride with WhatWidget
    testWidgets('2. WhatTestScope overrides value for descendant WhatWidget',
        (tester) async {
      final mockNode = What.constant(const UserProfile('Alice'));

      await tester.pumpWidget(
        MaterialApp(
          home: WhatTestScope(
            overrides: [
              mockNode.asOverride(),
            ],
            child: const UserProfileWidget(),
          ),
        ),
      );

      expect(find.text('User: Alice'), findsOneWidget);
    });

    testWidgets('3. WhatOverride with error renders error fallback UI',
        (tester) async {
      final userWhat =
          WhatController<UserProfile>(const UserProfile('Default')).what;

      await tester.pumpWidget(
        MaterialApp(
          home: WhatTestScope(
            overrides: [
              userWhat.overrideWithError(const SocketException('Offline')),
            ],
            child: const UserProfileWidget(),
          ),
        ),
      );

      expect(find.text('Failed: SocketException: Offline'), findsOneWidget);
    });

    testWidgets('4. WhatOverride with empty renders placeholder UI',
        (tester) async {
      final userWhat =
          WhatController<UserProfile>(const UserProfile('Default')).what;

      await tester.pumpWidget(
        MaterialApp(
          home: WhatTestScope(
            overrides: [
              userWhat.overrideWithEmpty('pending-sync'),
            ],
            child: const UserProfileWidget(),
          ),
        ),
      );

      expect(find.text('No profile (pending-sync)'), findsOneWidget);
    });

    // 5. whatWidgetTest declarative runner with pumpScopedWidget
    whatWidgetTest(
      '5. whatWidgetTest declarative runner automatically injects active overrides',
      overrides: [
        What.constant(99).asOverride(),
      ],
      test: (tester) async {
        await tester.pumpScopedWidget(
          const MaterialApp(
            home: CounterDisplay(),
          ),
        );

        expect(find.text('Count: 99'), findsOneWidget);
      },
    );

    // 6. Dynamic mutations inside test trigger UI updates through LPDAG 2-Phase
    whatWidgetTest(
      '6. Dynamic mutations trigger reactive widget rebuilds in test',
      test: (tester) async {
        final counter = WhatController(0);

        await tester.pumpScopedWidget(
          MaterialApp(
            home: WhatProvider<int>(
              what: counter.what,
              child: const CounterDisplay(),
            ),
          ),
        );

        expect(find.text('Count: 0'), findsOneWidget);

        // Mutate state
        counter.data = 1;
        await tester.pump();

        expect(find.text('Count: 1'), findsOneWidget);
      },
    );
  });
}
