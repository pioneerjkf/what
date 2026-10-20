# what_test

[![Pub Version](https://img.shields.io/pub/v/what_test.svg?style=flat-square)](https://pub.dev/packages/what_test)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=flat-square)](https://github.com/pioneerjkf/what/blob/main/LICENSE)
[![Dart SDK](https://img.shields.io/badge/Dart-3.6+-0175C2.svg?style=flat-square&logo=dart)](https://dart.dev)

A comprehensive, declarative testing harness and LPDAG state matcher library for the [what](https://pub.dev/packages/what) reactive state framework.

## Features

- **Declarative Test Runner (`whatTest<T>`)**: Test reactive state transitions, mutations, and derived pipelines with a structured, step-by-step API (`build`, `target`, `act`, `wait`, `expect`, `verify`, `tearDown`).
- **Deterministic Virtual Time (`FakeAsync`)**: Effortlessly fast-forward debounce, throttle, interval, and time-based graceful mooring windows with zero wall-clock latency.
- **LPDAG Custom Matchers**:
  - `isDormant` / `isActive`: Verify zero-leak subscriber-driven dormant lifecycle states.
  - `hasSubscribers(n)`: Interrogate active subscriber count in the reactive graph.
  - `hasGlitchFreedom`: Prove absence of diamond-dependency intermediate glitch states.
  - `isData(expected)` / `isEmptyState(reason)` / `isErrorState(error)`: Deep-match 3-State `WhatSnapshot` containers.
- **Pure Dart**: Zero Flutter SDK dependency; runs seamlessly in Server, CLI, VM, and Web test environments.

---

## Installation

Add `what_test` to your `dev_dependencies` in `pubspec.yaml`:

```yaml
dev_dependencies:
  test: ^1.25.0
  what_test: ^0.2.0
```

Or run:

```bash
dart pub add dev:what_test
```

---

## Practical Examples & Usage

### Example 1: Testing a Business Logic Store (`whatTest`)

Test state mutations and derived computation pipelines using a declarative lifecycle:

```dart
import 'package:test/test.dart';
import 'package:what/what.dart';
import 'package:what_test/what_test.dart';

/// Shopping cart business logic store
class CartStore {
  final items = WhatController<List<String>>([]);

  /// Derived reactive count: auto-computed via WhatVia
  late final What<int> itemCount = computed((via) => via(items.what).length);

  void addItem(String item) {
    items.data = [...items.data, item];
  }

  void removeItem(String item) {
    items.data = items.data.where((i) => i != item).toList();
  }
}

void main() {
  group('CartStore Tests', () {
    whatTest<CartStore>(
      'tracks item additions, removals, and updates derived itemCount',
      build: () => CartStore(),
      target: (store) => store.itemCount,
      act: (store) {
        store.addItem('MacBook Pro');
        store.addItem('Magic Mouse');
        store.removeItem('Magic Mouse');
      },
      // Target emits distinct states: initial 0 -> 1 -> 2 -> 1
      expect: () => [0, 1, 2, 1],
      verify: (store) {
        expect(store.items.data, ['MacBook Pro']);
        expect(untracked(store.itemCount), 1);
      },
    );
  });
}
```

---

### Example 2: Testing Debounce & Temporal Pipelines with Virtual Time (`wait`)

When testing `query.what.debounced(...)`, you do not need real `Future.delayed` delays. Pass `wait: Duration(...)` to advance virtual time instantaneously with built-in `FakeAsync`:

```dart
class SearchStore {
  SearchStore() {
    debouncedQuery = query.what.debounced(const Duration(milliseconds: 300));
  }

  final query = WhatController('');
  late final What<String> debouncedQuery;
}

void main() {
  group('SearchStore Debounce Test', () {
    whatTest<SearchStore>(
      'suppresses rapid keystrokes and only emits the last value after 300ms',
      build: () => SearchStore(),
      target: (store) => store.debouncedQuery,
      act: (store) {
        // User types rapidly within 300ms
        store.query.data = 'd';
        store.query.data = 'da';
        store.query.data = 'dart';
      },
      // Fast-forward 300ms virtual clock instantly
      wait: const Duration(milliseconds: 300),
      // Intermediate 'd' and 'da' are collapsed; only initial '' and 'dart' are emitted
      expect: () => ['', 'dart'],
      verify: (store) {
        expect(store.query.data, 'dart');
      },
    );
  });
}
```

---

### Example 3: Verifying LPDAG Inactive Dormancy (`isDormant`, `isActive`)

Verify the zero-leak **Subscriber-Driven Inactive Dormancy** invariant. When an effect runner or UI disconnects, nodes must automatically return to dormancy:

```dart
test('proves derived node enters zero-leak dormancy when unobserved', () {
  final count = WhatController(10);
  final doubled = computed((via) => via(count.what) * 2);

  // 1. Initially dormant: 0 active subscribers
  expect(doubled, isDormant);
  expect(count, isDormant);

  // 2. Active observation wakes up the node
  final runner = doubled.effect(() {}).run();
  expect(doubled, isActive);
  expect(doubled, hasSubscribers(1));

  // 3. Deactivating the runner returns the graph to dormant state
  runner.deactivate();
  expect(doubled, isDormant);
});
```

---

### Example 4: Testing 3-State FSM Snapshots (`isData`, `isEmptyState`, `isErrorState`)

Assert that nodes or controllers transition cleanly between Data, Empty, and Error states:

```dart
test('verifies 3-State FSM transitions', () {
  // 1. Initial Empty state with descriptive reason
  final user = WhatController<String>.late(reason: 'AwaitingAuth');
  expect(user, isEmptyState('AwaitingAuth'));

  // 2. Transition to valid Data state
  user.data = 'Alice';
  expect(user, isData('Alice'));

  // 3. Transition to Error state
  user.setError(Exception('Session expired'));
  expect(user, isErrorState());
});
```

---

## Complete Executable Example

Check out the full, runnable showcase at [`example/what_test_example.dart`](example/what_test_example.dart). Run it directly via:

```bash
dart test example/what_test_example.dart
```

---

## License

Apache License 2.0. Copyright 2023-2026 Youngjune Jeon.
