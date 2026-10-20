# Functor Ecosystem: composed & what.build Zero-Alloc Cascades Specification
## (Functor Ecosystem: composed & what.build Zero-Alloc Cascades)

> **"Syntactic elegance and runtime execution speed must not be mutually exclusive. What combines Dart's `extension type const` with polymorphic functors to deliver fluent cascading APIs with zero heap allocations."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: Syntactic Friction and Runtime Overhead in Declarative UI

When composing granular reactive UI in Flutter, developers confront three persistent dilemmas:

1. **Boilerplate Proliferation**:
   Making a simple Text widget reactive requires subclassing `StatefulWidget` or nesting verbose builder widgets (`StreamBuilder`, `ValueListenableBuilder`).
2. **GC Jitter from Anonymous Builder Allocation**:
   `AnimatedBuilder` and third-party builder widgets allocate new `Widget` and closure objects on the heap every frame, increasing pressure on the garbage collector.
3. **Redundant Reconstruction of Static Subtrees**:
   Instantiating static icons and layout containers inside builder closures discards and reallocates expensive static subtrees on every state update.

`package:what_flutter` resolves these challenges through two complementary architectures: the **`composed` functional functor hierarchy** and **`what.build` zero-allocation cascades**.

---

## 2. The `composed` Functor Architecture

`composed` serves as the unified top-level functor entry point for inline dynamic reactive widgets with multi-state dependencies:

```text
composed                             ((context, via) => ...)            // 1. Reactive State Composition
 ├── .child                          (child: ..., (context, via, child) => ...)
 └── .children                       (children: ..., (context, via, children) => ...)
 │
 ├── .vsync                          ((context, via, vsync) => ...)     // 2. Direct VSYNC Ticker Acquisition
 │
 ├── .animate                        (controller, (context, via, ctrl) => ...) // 3. 60/120fps Active Animation
 │    └── .child / .children         (...)
 │
 └── .drive                          ((elapsed) => ..., (context, via, value) => ...) // 4. Continuous Frame Driver
      └── .child / .children         (...)
```

### 4 Core Execution Modalities:
1. **Multi-State Composition (`composed(...)`)**: Dynamically tracks multiple nodes (`via(a)`, `via(b)`) via `RawViaTerminal`.
2. **Raw VSYNC Acquisition (`composed.vsync(...)`)**: Direct access to `TickerProvider` without `StatefulWidget` boilerplate.
3. **Animation Isolation (`composed.animate(...)`)**: Isolates high-frequency frame ticking from parent trees, rendering at 120fps.
4. **Continuous Frame Drivers (`composed.drive(...)`)**: Drives frame-autonomous widgets using display VSYNC ticks and elapsed durations.

*(For zero-rebuild declarative side-effects, use `WhatListener`.)*

---

## 3. `what.build` Zero-Allocation Cascades

When binding a single `What<T>` node 1:1 to a view, What uses Dart 3 `extension type const` definitions to eliminate runtime wrapper allocations:

```text
what.build           ((context, data) => ...)
 ├── .child          ((context, data, child) => ..., child: W)
 ├── .children       ((context, data, children) => ..., children: [...])
 └── .async          (data: (context, data) => ..., loading: (context) => ..., ...)
```

### Why Zero Runtime Allocation?

```dart
// lib/src/widgets/inline.dart
extension WhatFlutterExtension<T> on What<T> {
  /// Entry point with zero heap allocation!
  WhatBuildFunctor<T> get build => WhatBuildFunctor<T>(this);
  WhatListenFunctor<T> get listen => WhatListenFunctor<T>(this);
}

/// Dart extension type wraps What<T> with compile-time inline dispatch:
extension type const WhatBuildFunctor<T>(What<T> _what) {
  Widget call(Widget Function(BuildContext context, T data) builder) =>
      _InlineSingleWhatWidget<T>(what: _what, builder: builder);

  Widget child(
    Widget Function(BuildContext context, T data, Widget child) builder, {
    required Widget child,
  }) =>
      _InlineSingleWhatWithChildWidget<T>(
        what: _what,
        builder: builder,
        child: child,
      );

  Widget children(
    Widget Function(BuildContext context, T data, List<Widget> children)
        builder, {
    required List<Widget> children,
  }) =>
      _InlineSingleWhatWithChildrenWidget<T>(
        what: _what,
        builder: builder,
        children: children,
      );
}
```

- `WhatBuildFunctor` is declared as `extension type const`.
- At compile time, the compiler inlines it into direct static calls. **Zero wrapper objects are allocated on the heap at runtime**.

---

## 4. Static Subtree Memoization (`child:` / `children:`)

A foundational optimization rule in reactive UI is: **isolate static subtrees outside builder closures**.

**Warning (Anti-Pattern Prevention):**
- Never instantiate unchanged static widgets inside builder closures.
- Pass static subtrees via `child:` or `children:` parameters to prevent redundant allocations on state changes.

**BAD:**
```dart
// [Anti-Pattern] Heavy chart widget is re-instantiated on every count update
counterWhat.build((context, count) {
  return Row(
    children: [
      Text('Count: $count'),
      const VeryHeavyChartWidget(), // Allocates garbage on every tick!
    ],
  );
});
```

**GOOD:**
```dart
// [Recommended] Passes heavy chart as static child; 100% exempt from rebuilds
counterWhat.build.child(
  (context, count, child) => Row(
    children: [
      Text('Count: $count'),
      child, // Reuses single instance created once
    ],
  ),
  child: const VeryHeavyChartWidget(),
);
```

---

## 5. Architectural Decision Tree

How to select the appropriate reactive UI entry point:

```text
┌────────────────────────────────────────────────────────┐
│             Reactive UI Entrypoint Decision            │
└──────────────────────────┬─────────────────────────────┘
                           │
        [ How many state nodes are observed? ]
         │                               │
         ▼ (Single What<T> node)         ▼ (2+ nodes or conditional branching)
   what.build(...)                 composed(...) or WhatWidget
         │                               │
         │                               ├─► [ Inline leaf widget? ] ──► composed((context, via) => ...)
         │                               │
         │                               └─► [ Modular domain component? ] ──► class MyWidget extends WhatWidget
         │
         ├─► [ Direct leaf view? ] ──► what.build((context, data) => ...)
         ├─► [ Needs static child caching? ] ──► what.build.child(...)
         └─► [ 4-State asynchronous query? ] ──► what.build.async(...)
```

---

## 6. Architectural Conclusions

The functor ecosystem in `package:what_flutter` pairs ergonomic fluency with zero-heap-allocation guarantees. By exploiting Dart compiler inlining and extension types, **the easiest code to author is simultaneously the fastest to execute**.
