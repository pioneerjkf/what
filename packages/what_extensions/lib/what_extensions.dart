// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// @docImport 'package:what/what.dart';
///
/// # What Extensions: Reactive Collection & Functional Pipeline Operators
///
/// `what_extensions` provides a rich suite of reactive collection operators, aggregations,
/// and functional algorithms on top of `What<Iterable<E>>`, `What<List<E>>`, and `What<Set<E>>`.
///
/// ---
///
/// ## Architectural Overview
///
/// Built directly on the What Push-Dirty / Pull-Data DAG, all operators provided by
/// `what_extensions` execute lazily and return immutable [List.unmodifiable] collections.
/// State mutations in upstream collections trigger lightweight dirty pulses, allowing
/// downstream widgets and terminals to pull newly computed lists or scalar aggregations on-demand.
///
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                     Upstream State Carrier ([What<List<T>>])          │
/// │                                                                        │
/// │   final users = WhatController<List<User>>([...]);                      │
/// └──────────────────────────────────┬─────────────────────────────────────┘
///                                    │ (Push-Dirty Invalidation)
///                                    ▼
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                     Reactive Pipeline Operator Extensions              │
/// │                                                                        │
/// │   • .elements.sortedBy((u) => u.age)   : Reactive sorting              │
/// │   • .elements.whereNot((u) => u.isBanned) : Reactive filtering        │
/// │   • .elements.slices(10)               : Reactive pagination/chunking  │
/// │   • .elements.sum / .elements.average  : Reactive numeric aggregation  │
/// └──────────────────────────────────┬─────────────────────────────────────┘
///                                    │ (Pull-Data on Evaluation)
///                                    ▼
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                     Immutable Output ([What<List<T>>] / [What<R>])    │
/// │                                                                        │
/// │   Evaluates lazily and freezes results via List.unmodifiable in O(N)   │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ---
///
/// ## Quick Start
///
/// ### 1. Reactive Sorting and Slicing
/// ```dart
/// import 'package:what/what.dart';
/// import 'what_extensions/what_extensions.dart';
///
/// final scores = WhatController([40, 10, 90, 20]);
///
/// // Create a derived sorted pipeline:
/// final sortedScores = scores.elements.sorted((a, b) => a.compareTo(b));
///
/// // Create a derived paginated chunk pipeline:
/// final pages = scores.elements.slices(2); // What<List<List<int>>>
///
/// print(sortedScores.data); // [10, 20, 40, 90]
/// ```
///
/// ### 2. Numeric Reductions and Aggregations
/// ```dart
/// final prices = WhatController<List<double>>([19.99, 9.99, 4.99]);
///
/// final total = prices.elements.sum; // What<double>
/// final avg = prices.elements.average; // What<double>
///
/// print('Total: ${total.data}, Avg: ${avg.data}');
/// ```
///
/// ---
///
/// **Warning (Anti-Pattern Prevention):**
/// - **DO NOT** mutate source collections in-place (e.g. `list.add(...)` without notifying
///   the controller). Always inject new immutable list snapshots into the [WhatController]
///   to trigger proper dirty pulse propagation.
library;

export 'collection.dart';
export 'package:what/what.dart';
