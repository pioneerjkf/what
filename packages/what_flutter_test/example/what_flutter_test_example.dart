// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import 'package:what_flutter_test/what_flutter_test.dart';

// =============================================================================
// 1. Production UI Widgets
// =============================================================================

class User {
  const User({required this.name, required this.email});
  final String name;
  final String email;
}

base class UserHeaderWidget extends WhatWidget {
  const UserHeaderWidget({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final userWhat = context.whatOf<User>();
    final userState = via.state(userWhat);

    return userState.match(
      data: (user) => Text('Welcome, ${user.name} (${user.email})'),
      empty: () => const Text('Loading user profile...'),
      error: (error, stack) => Text('Failed to load user: $error'),
    );
  }
}

base class CounterScreen extends WhatWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final count = via.of<int>(context);
    return Scaffold(
      body: Center(
        child: Text('Current Count: $count'),
      ),
    );
  }
}

// =============================================================================
// 2. Complete Executable Widget Test Suite with what_flutter_test
// =============================================================================

void main() {
  group('what_flutter_test Real-World Widget Testing Showcase', () {
    // ---------------------------------------------------------------------------
    // Scenario 1: Mocking Tree-Level Dependencies with WhatTestScope
    // ---------------------------------------------------------------------------
    testWidgets('WhatTestScope injects mock User into descendant widgets',
        (tester) async {
      const mockUser = User(name: 'Alice', email: 'alice@example.com');

      await tester.pumpWidget(
        MaterialApp(
          home: WhatTestScope(
            overrides: [
              What.constant(mockUser).asOverride(),
            ],
            child: const UserHeaderWidget(),
          ),
        ),
      );

      expect(find.text('Welcome, Alice (alice@example.com)'), findsOneWidget);
    });

    testWidgets('WhatTestScope overrides with simulated network error',
        (tester) async {
      final userWhat = WhatController<User>.late().what;

      await tester.pumpWidget(
        MaterialApp(
          home: WhatTestScope(
            overrides: [
              userWhat.overrideWithError('HTTP 500: Internal Server Error'),
            ],
            child: const UserHeaderWidget(),
          ),
        ),
      );

      expect(find.text('Failed to load user: HTTP 500: Internal Server Error'),
          findsOneWidget);
    });

    // ---------------------------------------------------------------------------
    // Scenario 2: Declarative whatWidgetTest Runner + pumpScopedWidget
    // ---------------------------------------------------------------------------
    whatWidgetTest(
      'whatWidgetTest automatically configures overrides for pumpScopedWidget',
      overrides: [
        What.constant(777).asOverride(),
      ],
      test: (tester) async {
        await tester.pumpScopedWidget(
          const MaterialApp(
            home: CounterScreen(),
          ),
        );

        expect(find.text('Current Count: 777'), findsOneWidget);
      },
    );

    // ---------------------------------------------------------------------------
    // Scenario 3: Reactive Widget Rebuilding on Upstream Mutation
    // ---------------------------------------------------------------------------
    whatWidgetTest(
      'Widget rebuilds dynamically when WhatController mutates in test',
      test: (tester) async {
        final counter = WhatController(0);

        await tester.pumpScopedWidget(
          MaterialApp(
            home: WhatProvider<int>(
              what: counter.what,
              child: const CounterScreen(),
            ),
          ),
        );

        expect(find.text('Current Count: 0'), findsOneWidget);

        // Mutate controller state
        counter.data = 42;
        await tester.pump();

        expect(find.text('Current Count: 42'), findsOneWidget);
      },
    );
  });
}
