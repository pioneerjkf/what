// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what_test/what_test.dart';

// =============================================================================
// 1. Real-World Business Logic: Search & Filter Store
// =============================================================================

class SearchStore {
  SearchStore() {
    debouncedQuery = query.what.debounced(const Duration(milliseconds: 300));

    results = computed((via) {
      final term = via(debouncedQuery).trim();
      if (term.isEmpty) return const <String>[];
      return [
        'Result 1 for "$term"',
        'Result 2 for "$term"',
      ];
    });
  }

  /// Upstream user input
  final query = WhatController('');

  /// Internal debounced pipeline node
  late final What<String> debouncedQuery;

  /// Derived synchronous search results
  late final What<List<String>> results;
}

// =============================================================================
// 2. Real-World Business Logic: Shopping Cart Store (Optimistic Mutations)
// =============================================================================

class CartStore {
  CartStore();

  final items = WhatController<List<String>>([]);

  late final What<int> itemCount = computed((via) => via(items.what).length);

  void addItem(String item) {
    items.data = [...items.data, item];
  }

  void removeItem(String item) {
    items.data = items.data.where((i) => i != item).toList();
  }

  void clear() {
    items.data = [];
  }
}

// =============================================================================
// 3. Complete Executable Test Suite with what_test
// =============================================================================

void main() {
  group('Shopping Cart Store Tests (Synchronous whatTest)', () {
    whatTest<CartStore>(
      'tracks cart item mutations and updates derived item count',
      build: () => CartStore(),
      target: (store) => store.itemCount,
      act: (store) {
        store.addItem('MacBook Pro');
        store.addItem('Magic Mouse');
        store.removeItem('Magic Mouse');
      },
      // Distinct states observed by itemCount: initial 0 -> 1 -> 2 -> 1
      expect: () => [0, 1, 2, 1],
      verify: (store) {
        expect(store.items.data, ['MacBook Pro']);
        expect(store.itemCount.peek, 1);
      },
    );
  });

  group('Search Pipeline Tests (Virtual Time & Debounce)', () {
    whatTest<SearchStore>(
      'debounces rapid typing and only queries API after 300ms of silence',
      build: () => SearchStore(),
      target: (store) => store.results,
      act: (store) {
        // User types rapidly: "d" -> "da" -> "dart"
        store.query.data = 'd';
        store.query.data = 'da';
        store.query.data = 'dart';
      },
      // Fast-forward 300ms virtual time using FakeAsync
      wait: const Duration(milliseconds: 300),
      // Intermediate "d" and "da" are suppressed by debounce
      expect: () => [
        const <String>[], // Initial empty list
        const ['Result 1 for "dart"', 'Result 2 for "dart"'],
      ],
      verify: (store) {
        expect(store.query.data, 'dart');
      },
    );
  });

  group('LPDAG Lifecycle & Invariant Assertions', () {
    test('verifies subscriber-driven dormancy invariant (zero memory leak)',
        () {
      final source = WhatController(100);
      final derived = computed((via) => via(source.what) * 2);

      // 1. Unobserved nodes remain dormant (0 active subscribers)
      expect(derived, isDormant);
      expect(source, isDormant);

      // 2. Observing wakes up the node via effect runner
      final runner = derived.effect(() {}).run();
      expect(derived, isActive);
      expect(derived, hasSubscribers(1));

      // 3. Deactivating runner synchronously drops subscribers back to 0 (dormant)
      runner.deactivate();
      expect(derived, isDormant);
    });

    test('asserts 3-State FSM transitions with snapshot matchers', () {
      final user = WhatController<String>.late(reason: 'Unauthenticated');

      // Check empty state directly on controller or node
      expect(user, isEmptyState('Unauthenticated'));

      // Transition to data
      user.data = 'Alice';
      expect(user, isData('Alice'));

      // Transition to error
      user.setError(Exception('Session expired'));
      expect(user, isErrorState());
    });
  });
}
