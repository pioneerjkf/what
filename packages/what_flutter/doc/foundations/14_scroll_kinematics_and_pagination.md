# Scroll Kinematics & High-Frequency Composition
## (Scroll Kinematics & High-Frequency Slivers)

> **"A device screen refreshes at 60 to 120 frames per second. When a user scrolls, the `ScrollController`'s offset mutates at that exact frequency. Piping high-frequency mutations into generic state trees destroys frames. True surgical precision requires isolating kinematics from business logic."**
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Scrolling Bottleneck

In Flutter, interacting with `ScrollController.offset` to create dynamic UI (e.g., hiding an AppBar as the user scrolls, fading in a Floating Action Button, or triggering infinite pagination) is notoriously difficult to optimize. 

If a developer binds `ScrollController` directly to a high-level `StatefulWidget` using `setState` or typical state-management `watch` patterns, **the entire widget tree (including complex list items) rebuilds 120 times per second**. This inevitably leads to dropped frames ("jank") and extreme GC pressure.

`package:what_flutter` solves this by introducing zero-allocation bridging (`observe`) and surgical micro-rebuilds via `composed.child`.

---

## 2. Zero-Allocation Bridging (`observe`)

To react to `ScrollController` changes without rebuilding the entire UI, the `ScrollPosition`'s underlying `ValueListenable` is bridged into the LPDAG using `.observe()`. 

Because `what` nodes are intrinsically lazy, bridging a scroll offset does NOT push downstream calculations unless a specific UI element is actively demanding it.

### Production Example: Surgical AppBar Opacity
```dart
base class FeedScreen extends WhatWidget {
  FeedScreen({super.key});

  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context, WhatVia via) {
    // 1. Bridge the scroll offset into the reactive graph
    final scrollOffset = scrollController.toWhatBy(
      (ctrl) => ctrl.hasClients ? ctrl.offset : 0.0,
    );

    // 2. Compute a normalized opacity (0.0 to 1.0) based on scroll depth
    final appBarOpacity = computed((via) {
      final offset = via(scrollOffset);
      return (offset / 150.0).clamp(0.0, 1.0);
    }).distinct(); // distinct() prevents rebuilds if value doesn't change

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        // 3. SURGICAL REBUILD: Only this specific widget rebuilds 120fps!
        child: composed((context, via) {
          final opacity = via(appBarOpacity);
          return Opacity(
            opacity: opacity,
            child: AppBar(title: const Text('Feed')),
          );
        }),
      ),
      body: ListView.builder(
        controller: scrollController, // Drives the scrollOffset bridge
        itemCount: 1000,
        itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
      ),
    );
  }
}
```

### Architectural Benefits
- **Surgical Isolation**: Only the `Opacity` widget rebuilds during the scroll. The heavy `ListView` remains completely untouched.
- **`distinct()` Optimization**: Even if the scroll offset continues to increase beyond `150.0`, `clamp()` evaluates to `1.0`. The `distinct()` filter recognizes that the output hasn't changed from the previous `1.0` and **halts downstream propagation entirely**, saving thousands of redundant micro-rebuilds.

---

## 3. Infinite Pagination (Debounced Kinematics)

When implementing infinite pagination (loading more items when the user scrolls near the bottom), reacting directly to every pixel change is dangerous.

The LPDAG allows us to declaratively express the "load more" threshold without imperative spaghetti code.

### Production Example: Declarative Pagination
```dart
final scrollController = ScrollController();

final scrollOffset = scrollController.toWhatBy(
  (ctrl) => ctrl.hasClients ? ctrl.offset : 0.0,
);

final maxScroll = scrollController.toWhatBy(
  (ctrl) => ctrl.hasClients ? ctrl.position.maxScrollExtent : 0.0,
);

// Declarative boolean representing if the user is within 200px of the bottom
final isNearBottom = computed((via) {
  final current = via(scrollOffset);
  final max = via(maxScroll);
  return max > 0 && current >= (max - 200);
}).distinct(); // ONLY emits when boolean flips from false to true

// Using effect to trigger the side-effect (API Call)
final paginationEffect = isNearBottom.effect(() {
  final nearBottom = untracked(isNearBottom);
  if (nearBottom && !untracked(store.isLoading)) {
    store.fetchNextPage();
  }
}).run();
```

---

## 4. Architectural Conclusions

By integrating `observe` with `computed` and `.distinct()`, complex 120fps scroll kinematics are mathematically reduced into clean, surgical state updates. The separation of the high-frequency scroll input from the isolated `composed` builder ensures that Flutter's Render Tree is protected from extraneous work.
