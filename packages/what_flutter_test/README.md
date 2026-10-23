# what_flutter_test

[![Pub Version](https://img.shields.io/pub/v/what_flutter_test.svg?style=flat-square)](https://pub.dev/packages/what_flutter_test)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=flat-square)](https://github.com/pioneerjkf/what/blob/main/LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B.svg?style=flat-square&logo=flutter)](https://flutter.dev)

> [!WARNING]
> ### 🌸 Discontinued & Succeeded by [blooming_flutter_test](https://pub.dev/packages/blooming_flutter_test)
>
> **Notice of Package Migration & Rebranding**
>
> To eliminate long-term cognitive ambiguity caused by the interrogative naming convention (`What`) and provide a clearer, more expressive architectural identity, `package:what_flutter_test` has been **officially discontinued and succeeded by [`package:blooming_flutter_test`](https://pub.dev/packages/blooming_flutter_test)**.
>
> Active development and Flutter testing tools have fully transitioned to the **Blooming** repository.
>
> * 🔗 **New GitHub Repository**: [github.com/pioneerjkf/blooming](https://github.com/pioneerjkf/blooming)
> * 📦 **Replacement Package**: [`blooming_flutter_test`](https://pub.dev/packages/blooming_flutter_test)
>
> #### Migration Guide
> Update your `pubspec.yaml`:
> ```diff
>  dev_dependencies:
> -  what_flutter_test: ^0.3.0
> +  blooming_flutter_test: ^1.0.0
> ```
> Update your imports and test runners:
> ```diff
> - import 'package:what_flutter_test/what_flutter_test.dart';
> + import 'package:blooming_flutter_test/blooming_flutter_test.dart';
>
> - whatWidgetTest( ... );
> + bloomWidgetTest( ... );
> ```
> *We sincerely thank you for using and supporting What Flutter Test!*

Unified Flutter testing harness and hierarchical widget state mocking system for the [what_flutter](https://pub.dev/packages/what_flutter) reactive UI framework.

## Features

- **Full `what_test` Re-export**: Import `what_flutter_test` to access both pure Dart unit testing utilities (`whatTest`, `FakeAsync`, `isDormant`, `hasGlitchFreedom`) and Flutter widget testing APIs in a single package.
- **Hierarchical Widget Mocking (`WhatTestScope` & `WhatOverride`)**: Declaratively inject mock nodes, static constants, empty placeholders, or simulated errors into the widget hierarchy via `WhatProvider`.
- **Declarative Widget Runner (`whatWidgetTest`)**: Run widget tests with automatic scoped override injection and clean environment setup.
- **Convenient Scoped Pump (`pumpScopedWidget`)**: Direct extension on `WidgetTester` to pump any UI subtree pre-configured with active overrides.

---

## Installation

Add `what_flutter_test` to your `dev_dependencies` in `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  what_flutter_test: ^0.2.0
```

---

## Usage

### 1. Unified Imports

`package:what_flutter_test/what_flutter_test.dart` exposes everything you need:

```dart
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import 'package:what_flutter_test/what_flutter_test.dart';
```

### 2. Declarative Widget Testing with `whatWidgetTest`

```dart
void main() {
  whatWidgetTest(
    'renders counter with injected override value',
    overrides: [
      counterWhat.overrideWithValue(42),
    ],
    test: (tester) async {
      await tester.pumpScopedWidget(
        MaterialApp(
          home: composed((context, via) => Text('Count: ${via(counterWhat)}')),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);
    },
  );
}
```

### 3. Tree-Level State Overrides with `WhatTestScope`

Override dependencies with custom mock nodes, errors, or empty states without touching production business logic:

```dart
testWidgets('renders fallback when service emits error', (tester) async {
  final userWhat = WhatController<String>('Alice').what;

  await tester.pumpWidget(
    MaterialApp(
      home: WhatTestScope(
        overrides: [
          userWhat.overrideWithError(Exception('No Internet')),
        ],
        child: userWhat.build((context, user) => Text('User: $user')),
      ),
    ),
  );

  expect(find.byType(WhatTestScope), findsOneWidget);
});
```

### 4. Dynamic Reactive Mutations in Widget Tests

Verify 2-Phase LPDAG widget rebuild cycles on user interaction or state mutation:

```dart
whatWidgetTest(
  'increments display when controller mutates',
  test: (tester) async {
    final counter = WhatController(0);

    await tester.pumpScopedWidget(
      MaterialApp(
        home: WhatProvider<int>(
          what: counter.what,
          child: composed((context, via) => Text('Count: ${via(counter.what)}')),
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
```

### 5. Running Pure Unit Tests

Because `what_flutter_test` re-exports `what_test`, your unit tests and widget tests share the same toolset:

```dart
whatTest<WhatController<int>>(
  'pure business logic unit test',
  build: () => WhatController(10),
  target: (ctrl) => ctrl.what,
  act: (ctrl) => ctrl.data = 20,
  expect: () => [10, 20],
);
```

---

## Complete Executable Example

Check out the full, runnable widget showcase at [`example/what_flutter_test_example.dart`](example/what_flutter_test_example.dart). Run it directly via:

```bash
flutter test example/what_flutter_test_example.dart
```

---

## License

Apache License 2.0. Copyright 2023-2026 Youngjune Jeon.
