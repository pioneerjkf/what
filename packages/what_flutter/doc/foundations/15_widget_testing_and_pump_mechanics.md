# Widget Testing & Pump Mechanics
## (Widget Testing & Frame Pumping)

> **"Testing reactive UIs requires temporal precision. If an asynchronous state takes a microtask to resolve, the widget tree will not reflect it until the next frame. Relying on arbitrary `Future.delayed` in tests leads to flaky validation. True deterministic UI testing hinges on precise control of the frame pump."**
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Temporal Disconnect

Testing Flutter UI (`flutter_test`) involves controlling the widget tree via a simulated `WidgetTester`. 

The `what_flutter` framework operates via highly optimized 2-Phase DAGs and asynchronous state resolutions (SWR). A common mistake in widget tests is to mutate a reactive node and immediately call `expect(find.text(...))` without allowing the framework to advance the internal Dart event loop and the Flutter frame scheduler.

This document outlines the precise temporal mechanics required to deterministically test `WhatWidget` and `WhatAsyncBuilder`.

---

## 2. Synchronous Mutation Pumping

For standard synchronous mutations (e.g., updating a simple `WhatController<int>`), the propagation to the UI is deferred to the next frame to prevent render thrashing. Therefore, a single `tester.pump()` is required.

```dart
testWidgets('Synchronous mutation updates UI after pump', (tester) async {
  final counter = WhatController<int>(0);
  
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: composed((context, via) => Text('Count: ${via(counter.what)}')),
    ),
  );
  
  // Initial frame
  expect(find.text('Count: 0'), findsOneWidget);
  
  // Mutate source (Dirty phase propagation)
  counter.set(1);
  
  // The UI has NOT updated yet! The widget is just marked as dirty.
  // We MUST schedule a new frame.
  await tester.pump();
  
  // Validated!
  expect(find.text('Count: 1'), findsOneWidget);
});
```

---

## 3. Asynchronous Resolution (SWR) and `pumpAndSettle()`

When testing widgets that rely on asynchronous SWR patterns (e.g., `computed.future`, `WhatAsyncBuilder`), the state progresses through multiple temporal phases:
1. `isEmpty` (Loading)
2. Microtask Resolution (Data available)
3. UI Rebuild Frame (Success Data displayed)

If a Future takes actual time to resolve (e.g. `Future.delayed`), you must use `tester.pumpAndSettle()` or advance time artificially.

### Production Example: SWR Widget Test
```dart
testWidgets('SWR transition from loading to success', (tester) async {
  final completer = Completer<String>();
  final asyncState = computed.future((via) => completer.future);
  
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: WhatAsyncBuilder<String>(
        what: asyncState,
        loading: (context) => const Text('Loading...'),
        error: (context, error, stack) => const Text('Error'),
        data: (context, data) => Text('Data: $data'),
      ),
    ),
  );
  
  // Phase 1: Loading
  expect(find.text('Loading...'), findsOneWidget);
  
  // Mutate the Future
  completer.complete('Test Data');
  
  // Phase 2: Microtask Flush + Frame Pump
  // pumpAndSettle waits until all microtasks and animations finish
  await tester.pumpAndSettle();
  
  // Phase 3: Success
  expect(find.text('Data: Test Data'), findsOneWidget);
});
```

---

## 4. Animation Frame Tickers (`composed.animate` & `DurableAnimationController`)

When testing widgets that use `composed.animate` with `DurableAnimationController`, the tester's clock must advance to simulate the passage of time.

If an animation is meant to run for 300ms, a single `tester.pump()` will not complete it.

```dart
testWidgets('Durable animation progression', (tester) async {
  final anim = DurableAnimationController(
    duration: const Duration(milliseconds: 300),
  );
  
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: composed.animate(
        anim,
        (context, via, ctrl) => Text('Value: ${ctrl.view.value.toStringAsFixed(1)}'),
      ),
    ),
  );
  
  // Start animation
  anim.forward(from: 0);
  await tester.pump(); // Starts the ticker
  
  // Advance exactly 150ms (Halfway)
  await tester.pump(const Duration(milliseconds: 150));
  expect(find.text('Value: 0.5'), findsOneWidget);
  
  // Advance remaining 150ms (Completion)
  await tester.pump(const Duration(milliseconds: 150));
  expect(find.text('Value: 1.0'), findsOneWidget);
});
```

---

## 5. Architectural Conclusions

Flutter UI testing with `what_flutter` perfectly mirrors standard Flutter temporal semantics. Because the framework leverages the core Flutter pipeline (using `Element.markNeedsBuild` and standard Microtasks), developers can rely entirely on standard `flutter_test` utilities (`pump`, `pumpAndSettle`, `pump(Duration)`) without needing artificial framework-specific testing wrappers.
