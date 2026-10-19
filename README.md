<p align="center">
  <img src="https://raw.githubusercontent.com/pioneerjkf/what/main/assets/what_ecosystem_banner_dark.svg" alt="What Ecosystem — High-Performance Dart &amp; Flutter Reactive State Engine Suite" width="100%" />
</p>

# What Ecosystem

[![what](https://img.shields.io/pub/v/what.svg?label=what)](https://pub.dev/packages/what)
[![what_flutter](https://img.shields.io/pub/v/what_flutter.svg?label=what_flutter)](https://pub.dev/packages/what_flutter)
[![what_extensions](https://img.shields.io/pub/v/what_extensions.svg?label=what_extensions)](https://pub.dev/packages/what_extensions)
[![what_lints](https://img.shields.io/pub/v/what_lints.svg?label=what_lints)](https://pub.dev/packages/what_lints)
[![what_test](https://img.shields.io/pub/v/what_test.svg?label=what_test)](https://pub.dev/packages/what_test)
[![what_flutter_test](https://img.shields.io/pub/v/what_flutter_test.svg?label=what_flutter_test)](https://pub.dev/packages/what_flutter_test)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Publisher: pioneerjkf.dev](https://img.shields.io/badge/Publisher-pioneerjkf.dev-0175C2.svg)](https://pub.dev/publishers/pioneerjkf.dev)
[![Flutter SDK](https://img.shields.io/badge/Flutter-3.10+-02569B.svg?logo=flutter)](https://flutter.dev)
[![Dart SDK](https://img.shields.io/badge/Dart-3.6+-0175C2.svg)](https://dart.dev)

> **"Zero boilerplate. Crystal-clear reactive pipelines with zero computational overhead."**  
> *Glitch-free reactive state powered by an ultra-fast Topological LPDAG Engine.*

**What** is a high-performance, zero-overhead Dart and Flutter reactive state management framework. Modeled after Flutter's `RenderObject` pipeline, What decouples invalidation signaling from computation execution through a two-phase architecture: **Push-Dirty ($O(1)$) + Lazy-Pull (On-Demand)**.

---

## Packages in this Repository

| Package | pub.dev | Description |
| :--- | :--- | :--- |
| [**`what`**](packages/what/) | [![pub package](https://img.shields.io/pub/v/what.svg)](https://pub.dev/packages/what) | Pure Dart core engine implementing the 2-Phase LPDAG architecture, dynamic triad (`computed`, `switched`, `managed`), SWR snapshots, and graceful lifecycle. |
| [**`what_flutter`**](packages/what_flutter/) | [![pub package](https://img.shields.io/pub/v/what_flutter.svg)](https://pub.dev/packages/what_flutter) | High-performance Flutter reactive binding layer with surgical inline micro-rebuilds (`composed`), declarative `WhatWidget`, and durable drift-compensated animations. |
| [**`what_extensions`**](packages/what_extensions/) | [![pub package](https://img.shields.io/pub/v/what_extensions.svg)](https://pub.dev/packages/what_extensions) | Reactive extensions for collections and iterables (`Iterable`, `List`), async pipelines, and diffing. |
| [**`what_lints`**](packages/what_lints/) | [![pub package](https://img.shields.io/pub/v/what_lints.svg)](https://pub.dev/packages/what_lints) | Official static analysis and architectural enforcement lint rules for What and Flutter applications. |
| [**`what_test`**](packages/what_test/) | [![pub package](https://img.shields.io/pub/v/what_test.svg)](https://pub.dev/packages/what_test) | Declarative testing harness and custom LPDAG matchers for pure Dart reactive state verification. |
| [**`what_flutter_test`**](packages/what_flutter_test/) | [![pub package](https://img.shields.io/pub/v/what_flutter_test.svg)](https://pub.dev/packages/what_flutter_test) | Declarative Flutter widget test harness and node mocking scope for the What reactive framework. |

---

## Why What?

### The Glitch Problem in Eager Push Systems

Traditional reactive frameworks (such as standard Streams, Rx, or primitive Signals) rely on an **Eager Push DAG** model. When any upstream state mutates, intermediate results are calculated and pushed immediately downstream.

In a canonical **Diamond Dependency** graph:

<p align="center">
  <img src="https://raw.githubusercontent.com/pioneerjkf/what/main/assets/what_diagram_diamond_glitch.svg" alt="Canonical Diamond Dependency and the Eager Push Glitch" width="100%" />
</p>

When `Root` changes from `1` to `2`:
1. `Root` eagerly pushes `2` to `Left (A)`.
2. `Left (A)` calculates `4` and immediately pushes to `Sum (C)`.
3. `Sum (C)` evaluates `4 + 11 (old B) = 15`. **[Glitch: Transient inconsistent state!]**
4. `Root` pushes `2` to `Right (B)`.
5. `Right (B)` calculates `12` and pushes to `Sum (C)`.
6. `Sum (C)` evaluates `4 + 12 = 16`.

**Consequences of Eager Push:**
- **Glitch & Redundant Rebuilds:** Downstream nodes or UI render passes observe temporary, inconsistent data, causing UI flickering, premature network calls, or logic errors.
- **Wasted CPU Cycles:** Intermediate computations execute multiple times per state mutation even if the final result is never read.

---

## The LPDAG Solution: Two-Phase Reactive Propagation

What solves this structural problem by decoupling state invalidation from data computation through the **LPDAG (Lazy Pull Directed Acyclic Graph)** engine:

### Phase 1: Push-Dirty (Downstream Invalidation)
When an upstream node (such as `WhatController`) updates:
- An internal dirty version counter increments.
- A lightweight invalidation pulse traverses downstream along intrusive edge pointers.
- Nodes already marked dirty are skipped immediately (Early Pruning).
- **Zero data computation and zero memory allocation occur.**

<p align="center">
  <img src="https://raw.githubusercontent.com/pioneerjkf/what/main/assets/what_diagram_phase1_push_dirty.svg" alt="LPDAG Phase 1: Push-Dirty Downstream Invalidation" width="100%" />
</p>

### Phase 2: Lazy-Pull (On-Demand Evaluation)
When a consumer (such as a Flutter widget during a frame render tick or a subscriber) reads `.data`:
- If the node is clean, it returns the cached `WhatSnapshot` in $O(1)$ time.
- If the node is dirty, it pulls upstream dependencies first in topological order.
- Both `Left` and `Right` are evaluated before `Sum` combines them.
- `Sum` executes **exactly once**, returning `16` with zero glitches and zero wasted cycles.

<p align="center">
  <img src="https://raw.githubusercontent.com/pioneerjkf/what/main/assets/what_diagram_phase2_lazy_pull.svg" alt="LPDAG Phase 2: Lazy-Pull On-Demand Evaluation" width="100%" />
</p>

---

## Key Pillars and Architectural Innovations

### 1. Glitch-Free 2-Phase LPDAG Core
Guarantees consistent topological evaluation order across arbitrary graph shapes. Diamond dependencies and deep dependency trees evaluate each node at most once per cycle.

### 2. Dynamic Reactive Triad
Provides three declarative state primitives to model all application requirements:
- **`computed`**: Pure synchronous derivation with explicit `WhatVia` dependency registration and 1-pass epoch sweeping.
- **`switched`**: Dynamic branch switching that automatically unsubscribes dormant dependency branches to prevent memory leaks.
- **`managed`**: Supervises synchronous external resource lifecycles (`create`, `update`, `dispose`) with zero-leak inactive dormancy.

### 3. SWR (Stale-While-Revalidate) Snapshot Semantics
`WhatSnapshot<T>` models data transitions through three explicit states (`Data`, `Empty`, `Error`). Revalidation displays cached stale data while refreshing in the background, eliminating blank screen flashes.

### 4. Graceful Node Lifecycle Management
Retain transient state and in-flight subscriptions across tab or route switches using `graceful.period()` and `graceful.bounded()`, disposing resources only when truly abandoned.

### 5. Surgical Micro-Rebuilds in Flutter (`composed` & `what.build`)
Rebuilds only the exact leaf widget subscribing to mutated state without triggering rebuilds of parent, sibling, or container widgets.

### 6. Durable Drift-Compensated Animations
`DurableAnimationController` pairs with `composed.animate` or `TickerProvider` to preserve state (`DurabilityPolicy.resume`), track wall-clock time (`DurabilityPolicy.catchUp`), or reset on deactivation (`DurabilityPolicy.reset`) across dormancy with zero boilerplate.

---

## Quick Start

### 1. Pure Dart

Add `what` to your `pubspec.yaml`:

```yaml
dependencies:
  what: ^0.1.0
```

```dart
import 'package:what/what.dart';

void main() {
  final count = WhatController(0);
  final doubled = computed((via) => via(count.what) * 2);

  print(doubled.peek); // 0

  count.set(5);
  print(doubled.peek); // 10
}
```

### 2. Flutter

Add `what_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  what: ^0.1.0
  what_flutter: ^0.1.0
```

```dart
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

final counter = WhatController(0);

void main() => runApp(const CounterApp());

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('What Counter Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Static Header (Never rebuilds)'),
              const SizedBox(height: 16),
              // Surgical Leaf Rebuild: Only this Text element rebuilds
              composed((context, via) => Text(
                    'Count: ${via(counter.what)}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  )),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => counter.set(counter.what.peek + 1),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

---

## Technical Documentation and Guides

- [**LPDAG Reactive Core Whitepaper**](packages/what/doc/LPDAG.md) — Comprehensive technical specification of the Push-Dirty and Lazy-Pull engine.
- [**Flutter Architecture & Foundation Guides**](packages/what_flutter/doc/foundations/README.md) — Architectural deep-dive into durable animations, composed functors, and reactive lifecycle.

---

## Maintainer & Publisher

Maintained and officially published by [**pioneerjkf.dev**](https://pub.dev/publishers/pioneerjkf.dev).  
For questions, security reports, or inquiries, reach out via [pioneer.jkf@gmail.com](mailto:pioneer.jkf@gmail.com) or submit an issue to the [issue tracker](https://github.com/pioneerjkf/what/issues).

---

## License

What ecosystem libraries are licensed under the [Apache License 2.0](LICENSE).
