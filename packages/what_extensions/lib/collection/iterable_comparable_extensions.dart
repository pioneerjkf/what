// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';

// =============================================================================
// Reactive Comparable Collection Extensions
// =============================================================================

/// Reactive [Comparable] collection reductions and sorting extensions on [WhatIterableElements].
///
/// **Design Philosophy (Safe Comparable Reductions):**
/// Extends [WhatIterableElements] with reactive sorting and extremum discovery.
/// All list-returning methods yield frozen immutable lists via [List.unmodifiable]
/// to safeguard state across reactive boundaries.
///
/// **Data Propagation Flow:**
/// ```text
/// [Source What<Iterable<Comparable>>]
///        │ (Push-Dirty)
///        ▼
/// [Comparable Reduction / Sorting Pipeline]
///        ├─► .min / .minOrNull           ──► Reductive scalar What<E?>
///        ├─► .max / .maxOrNull           ──► Reductive scalar What<E?>
///        └─► .sorted / .sortedDescending ──► Immutable sorted What<List<E>>
/// ```
///
/// **Example:**
/// ```dart
/// final names = what(['Charlie', 'Alice', 'Bob']);
/// final sortedNames = names.elements.sorted;
/// final firstName = names.elements.minOrNull;
///
/// print(sortedNames.data); // ['Alice', 'Bob', 'Charlie']
/// print(firstName.data);   // 'Alice'
/// ```
extension ComparableWhatElementsExtension<E extends Comparable<dynamic>>
    on WhatIterableElements<E> {
  /// Returns the minimum element in this collection, or `null` if empty.
  ///
  /// **Ensures:**
  /// * Evaluates to `null` when the source collection is empty.
  /// * Returns the smallest element according to [Comparable.compareTo].
  What<E?> get minOrNull => computed((via) {
        final source = via(what);
        if (source.isEmpty) return null;
        return source.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
      });

  /// Returns the minimum element in this collection, or throws [StateError] if empty.
  ///
  /// **Requires:**
  /// * The source collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<E> get min => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
      });

  /// Returns the maximum element in this collection, or `null` if empty.
  ///
  /// **Ensures:**
  /// * Evaluates to `null` when the source collection is empty.
  /// * Returns the largest element according to [Comparable.compareTo].
  What<E?> get maxOrNull => computed((via) {
        final source = via(what);
        if (source.isEmpty) return null;
        return source.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      });

  /// Returns the maximum element in this collection, or throws [StateError] if empty.
  ///
  /// **Requires:**
  /// * The source collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<E> get max => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      });

  /// Returns `true` if this collection is sorted in ascending order reactively.
  ///
  /// **Ensures:**
  /// * Returns `true` if collection length is less than 2.
  /// * Uses [compare] comparator if provided, falling back to [Comparable.compareTo].
  What<bool> isSorted([int Function(E a, E b)? compare]) => computed((via) {
        final source = via(what);
        if (source.length < 2) return true;
        final comp = compare ?? (a, b) => a.compareTo(b);
        var iterator = source.iterator;
        iterator.moveNext();
        var previous = iterator.current;
        while (iterator.moveNext()) {
          if (comp(previous, iterator.current) > 0) return false;
          previous = iterator.current;
        }
        return true;
      });

  /// Returns a new unmodifiable list containing elements sorted in ascending order reactively.
  ///
  /// **Ensures:**
  /// * Yields a new immutable [List.unmodifiable] containing elements in natural ascending order.
  What<List<E>> get sorted => computed((via) {
        return List<E>.unmodifiable(via(what).toList()..sort());
      });

  /// Returns a new unmodifiable list containing elements sorted in descending order reactively.
  ///
  /// **Ensures:**
  /// * Yields a new immutable [List.unmodifiable] containing elements in natural descending order.
  What<List<E>> get sortedDescending => computed((via) {
        return List<E>.unmodifiable(
            via(what).toList()..sort((a, b) => b.compareTo(a)));
      });
}
