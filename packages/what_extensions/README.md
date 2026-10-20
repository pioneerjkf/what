# What Extensions

Official reactive collection operators and functional pipeline extensions for [What](https://pub.dev/packages/what).

---

## Overview

`what_extensions` extends `What<Iterable<E>>`, `What<List<E>>`, and `What<Set<E>>` with high-performance, lazy reactive collection operators.

All operators integrate seamlessly into the What 2-Phase LPDAG engine:
- **Push-Dirty / Lazy-Pull**: Mutations in source collections trigger lightweight invalidation pulses; derivations evaluate lazily on-demand.
- **Immutable & Pure**: All list-producing derivations return `List.unmodifiable` views to ensure deterministic unidirectional data flow.
- **Glitch-Free**: Aggregations and filtered projections resolve consistently across complex dependency graphs without intermediate tearing.

---

## Features

- **Reactive Projections**: `.elements.map(...)`, `.elements.where(...)`, `.elements.take(...)`, `.elements.skip(...)`, `.elements.expand(...)`
- **Numeric Aggregations**: `.elements.sum`, `.elements.average`
- **Comparable Computations**: `.elements.min`, `.elements.max`, `.elements.minOrNull`, `.elements.maxOrNull`, `.elements.sorted(...)`, `.elements.sortedDescending(...)`
- **Search & Grouping**: `.elements.firstWhereOrNull(...)`, `.elements.lastWhereOrNull(...)`, `.elements.singleWhereOrNull(...)`, `.elements.groupBy(...)`, `.elements.slices(...)`
- **Index-Aware Operators**: `.elements.foldIndexed(...)`, `.elements.reduceIndexed(...)`, `.elements.none(...)`, `.elements.flattenedToList()`, `.elements.flattenedToSet()`
- **List Indexing**: `.elements.binarySearch(...)`, `.elements.lowerBound(...)`

---

## Getting Started

Add `what` and `what_extensions` to your `pubspec.yaml`:

```yaml
dependencies:
  what: ^0.2.0
  what_extensions: ^0.2.0
```

### Example Usage

```dart
import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:what_extensions/what_extensions.dart';

void main() async {
  final numbersController = WhatController<List<double>>([10.0, 20.0, 30.0]);

  // Derived reactive aggregation nodes
  final sumWhat = numbersController.what.elements.sum;
  final avgWhat = numbersController.what.elements.average;

  // Reactively observe aggregations
  final runner = sumWhat.effect(() {
    print('Sum updated: ${untracked(sumWhat)}');
  }).run();

  // Mutating the upstream collection triggers lightweight on-demand evaluation
  numbersController.set([5.0, 15.0, 25.0, 35.0]);

  await Future<void>.delayed(Duration.zero);
  runner.deactivate();
}
```

---

## License

Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
