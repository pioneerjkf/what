# What Extensions (Legacy)

Official reactive collection operators and functional pipeline extensions for [What](https://pub.dev/packages/what).

> [!WARNING]
> ### 🌸 Discontinued & Succeeded by [blooming_extensions](https://pub.dev/packages/blooming_extensions)
>
> **Notice of Package Migration & Rebranding**
>
> To eliminate long-term cognitive ambiguity caused by the interrogative naming convention (`What`) and provide a clearer, more expressive architectural identity, `package:what_extensions` has been **officially discontinued and succeeded by [`package:blooming_extensions`](https://pub.dev/packages/blooming_extensions)**.
>
> Active development and maintenance have fully transitioned to the **Blooming** repository.
>
> * 🔗 **New GitHub Repository**: [github.com/pioneerjkf/blooming](https://github.com/pioneerjkf/blooming)
> * 📦 **Replacement Package**: [`blooming_extensions`](https://pub.dev/packages/blooming_extensions)
>
> #### Migration Guide
> Update your `pubspec.yaml`:
> ```diff
>  dependencies:
> -  what_extensions: ^0.3.0
> +  blooming_extensions: ^1.0.0
> ```
> Update your imports and symbols:
> ```diff
> - import 'package:what_extensions/what_extensions.dart';
> + import 'package:blooming_extensions/blooming_extensions.dart';
>
> - final sum = numbersController.what.elements.sum;
> + final sum = numbersController.bloom.elements.sum;
> ```
> *We sincerely thank you for using and supporting What Extensions!*

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
