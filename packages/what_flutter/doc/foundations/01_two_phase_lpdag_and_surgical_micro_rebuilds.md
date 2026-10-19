# 2-Phase LPDAG Engine Integration & Surgical Micro-Rebuilds Specification
## (2-Phase LPDAG Engine Integration & Surgical Micro-Rebuilds)

> **"Traversing the entire widget tree upon state mutation squanders frame budgets and degrades reactive UI fidelity. What couples directly to Flutter's rendering pipeline via the 2-Phase LPDAG, surgically re-evaluating only the invalidated leaf Element."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: Inherent Constraints of Standard Flutter Rebuilds

In Flutter's declarative UI paradigm, state changes reflect onto the UI through three standard mechanisms:
1. **`StatefulWidget.setState()`**: Marks the owning State object dirty, re-executing its entire subtree.
2. **`InheritedWidget` / `Provider` / `Riverpod`**: Discovers dependent descendants in the context tree, scheduling them into the build pipeline.
3. **`AnimatedBuilder` / `ListenableBuilder`**: Evaluates nested builder closures via listener subscriptions.

However, these traditional approaches suffer from structural deficiencies:
- **Subtree Rebuild Pollution**: Mutating a single state variable invokes `build()` recursively across unchanged headers, layout wrappers, and static decorations.
- **Eager Evaluation Waste**: Rapid mutations trigger intermediate computations for off-screen widgets.
- **Visual Glitches in Diamond Dependencies**: Uncoordinated multi-state updates expose transient inconsistent states during frame renders.

`package:what_flutter` integrates What's **2-Phase LPDAG (Lazy-Pull Directed Acyclic Graph)** directly into Flutter's `ComponentElement` hierarchy to resolve these limitations.

---

## 2. 2-Phase LPDAG Render Pipeline Architecture

The integration between What and Flutter's render pipeline separates into **Phase 1: Push-Dirty** and **Phase 2: Lazy-Pull**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│             2-Phase LPDAG Flutter Pipeline Synchronization             │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Phase 1: Push-Dirty Invalidation ($O(1)$) ]                        │
│   WhatController.set() / .mutate()                                     │
│          │                                                             │
│          ▼                                                             │
│   Topological Dirty Pulse Propagation (No Value Computation!)          │
│          │                                                             │
│          ▼                                                             │
│   RawViaTerminal / RawWhatTerminal (In Element)                        │
│          │                                                             │
│          ▼                                                             │
│   Element.markNeedsBuild() ──► Flutter BuildOwner.scheduleBuildFor()   │
│                                (Registers to dirty elements list)      │
│                                                                        │
│ ══════════════════════════════════════════════════════════════════════ │
│                                                                        │
│   [ Phase 2: Lazy-Pull Evaluation (Flutter Frame Render Pass) ]        │
│   Flutter Engine VSYNC Frame Tick (60/120 FPS)                         │
│          │                                                             │
│          ▼                                                             │
│   BuildOwner.buildScope()                                              │
│          │                                                             │
│          ▼                                                             │
│   WhatElement / _ComposedElement.performRebuild()                      │
│          │                                                             │
│          ▼                                                             │
│   terminal.evaluate() (Dynamic 1-Pass Epoch Sweeping via WhatVia)      │
│          │                                                             │
│          ▼                                                             │
│   Exact Leaf Widget Produced ──► RenderObject Repaint (Isolated!)      │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Foundational Invariants

### Invariant 1: Pure Dirty Invalidation in Phase 1
- When an upstream `What<T>` mutates, a dirty pulse propagates downstream to the leaf element's `_ReactiveTerminalElementMixin`.
- The sole operation executed is **`Element.markNeedsBuild()`**.
- **Invariant**: *Phase 1 never instantiates widgets, never evaluates derived state, and never invokes computation closures.* Operational cost is strictly an $O(1)$ topological flag propagation.

### Invariant 2: On-Demand Lazy-Pull Evaluation in Phase 2
- When Flutter's `BuildOwner` flushes dirty elements during the frame pipeline, `performRebuild()` executes.
- The element invokes `terminal.data` or `terminal.evaluate()`, pulling derived state on-demand.
- If upstream values did not effectively change (`distinct`) or are no longer read due to conditional branching (`if`/`switch`), downstream recomputations short-circuit immediately.

### Invariant 3: Surgical Micro-Rebuild Isolation
- `composed((via) => ...)` and `what.build((data) => ...)` insert lightweight proxy elements (`_ComposedElement`, `_InlineSingleWhatElement`) into the element tree.
- When state mutates, `markNeedsBuild()` targets only this micro-element.
- **Outcome**: Ancestor widgets (`StatelessWidget`, `Scaffold`, `Column`) bypass the build queue entirely; only the exact leaf `Text` or `Container` rebuilds.

---

## 4. Internal Implementation Mechanics (`_ReactiveTerminalElementMixin`)

Reactive elements in `what_flutter` bind to Flutter's `ComponentElement` via `_ReactiveTerminalElementMixin` and `_ViaTerminalElementMixin`:

```dart
// lib/src/widgets/_internal/_framework.dart
mixin _ViaTerminalElementMixin on ComponentElement
    implements _ReactiveTerminalElementMixin<RawComputedTerminal<Widget>> {
  @override
  late final RawComputedTerminal<Widget> terminal = RawComputedTerminal<Widget>(
    _buildVia,
    onInvalidated: markNeedsBuild, // Phase 1: Pure markNeedsBuild dispatch
    onUncaughtError: _handleTerminalUncaughtError,
  );

  /// Evaluates and builds the widget subtree reactively tracking dependencies through [via].
  Widget _buildVia(WhatVia via);

  @override
  Widget build() => terminal.data; // Phase 2: Lazy-pull on demand
}
```

```dart
// lib/src/widgets/_internal/_composed.dart
final class _ComposedElement extends ComponentElement
    with _ReactiveTerminalElementMixin<RawComputedTerminal<Widget>>, _ViaTerminalElementMixin {
  _ComposedElement(Composed super.widget);

  @override
  Widget _buildVia(WhatVia via) => (widget as Composed).builder(via);
}
```

---

## 5. Production Patterns and Performance Analysis

**Warning (Anti-Pattern Prevention):**
- Avoid observing fine-grained state at high-level ancestor widgets to prevent rebuilding entire subtrees.
- Isolate reactive boundaries directly to leaf widgets via `composed` or `what.build`.

**BAD:**
```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    // [Anti-Pattern] Rebuilding Scaffold, AppBar, and heavy charts on every count mutation
    return Scaffold(
      appBar: AppBar(title: const HeavyHeaderTitleWidget()),
      body: Column(
        children: [
          const ExpensiveDataVisualizerChart(),
          Text('Count: $_count'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
      ),
    );
  }
}
```

**GOOD:**
```dart
final counter = WhatController(0);

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // [Recommended] Scaffold, AppBar, and ExpensiveDataVisualizerChart build once and remain static
    return Scaffold(
      appBar: AppBar(title: const HeavyHeaderTitleWidget()),
      body: Column(
        children: [
          const ExpensiveDataVisualizerChart(),
          // [Recommended] Surgical leaf micro-rebuild isolated strictly to this Text element
          composed((context, via) => Text('Count: ${via(counter.what)}')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.data++,
      ),
    );
  }
}
```

---

## 6. Architectural Conclusions

1. **Rebuild Scope Reduction ($O(N) \to O(1)$)**: Replaces coarse subtree updates with leaf-level micro-rebuilds.
2. **Glitch-Free UI Rendering**: Phase 1 topological ordering and Phase 2 single-pass evaluation eliminate intermediate inconsistent frames.
3. **120 FPS Fidelity**: High-frequency updates (gestures, scroll offsets, sensors) incur zero redundant layout passes and zero GC pauses.
