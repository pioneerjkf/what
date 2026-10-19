// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:math' show Random;
import 'package:collection/collection.dart';
import 'package:collection/collection.dart' as col;
import 'package:what/what.dart';

// =============================================================================
// Reactive List Extensions
// =============================================================================

/// Reactive extensions on [WhatListElements] providing high-performance list operations.
///
/// **Design Philosophy (Defensive Immutability & Laziness):**
/// All transformations operating on [WhatListElements] return new reactive [What] nodes.
/// List-producing operations immediately wrap returned lists with [List.unmodifiable]
/// to guarantee state immutability across reactive cycles.
///
/// **Data Propagation Flow:**
/// ```text
/// [Source What<List<E>>]
///        │ (Push-Dirty)
///        ▼
/// [Reactive List Extension Operators]
///        ├─► .binarySearch(target) ──► Reactive Index What<int> (O(log N))
///        ├─► .sortedRange(0, 5)    ──► Immutable Sub-range Sorted What<List<E>>
///        ├─► .swapped(i, j)        ──► Immutable Swapped What<List<E>>
///        └─► .slices(pageSize)     ──► Paginated What<List<List<E>>>
/// ```
///
/// **Example:**
/// ```dart
/// final listController = what<List<int>>([10, 20, 30, 40, 50]);
/// final indexWhat = listController.elements.binarySearch(30, (a, b) => a.compareTo(b));
/// final swappedList = listController.elements.swapped(0, 4);
///
/// print(indexWhat.data);   // 2
/// ```
extension ListWhatElementsExtension<E> on WhatListElements<E> {
  What<List<E>> get _listWhat => what as What<List<E>>;

  /// Returns the index of [element] in this sorted list via binary search.
  ///
  /// * [element]: The target element to search for.
  /// * [compare]: Custom comparison function returning negative, zero, or positive.
  ///
  /// **Requires:**
  /// * The underlying list MUST be sorted according to [compare].
  ///
  /// **Ensures:**
  /// * Returns the zero-based index of [element] in O(log N), or negative value if not found.
  What<int> binarySearch(E element, int Function(E a, E b) compare) =>
      computed((via) =>
          col.ListExtensions(via(_listWhat)).binarySearch(element, compare));

  /// Returns the index of [element] in this sorted list by comparing key extracted via [keyOf].
  What<int> binarySearchByCompare<K>(E element, K Function(E element) keyOf,
          int Function(K a, K b) compare, [int start = 0, int? end]) =>
      computed((via) => col.ListExtensions(via(_listWhat))
          .binarySearchByCompare<K>(element, keyOf, compare, start, end));

  /// Returns the index of [element] in this sorted list by key natural order.
  What<int> binarySearchBy<K extends Comparable<dynamic>>(
          E element, K Function(E element) keyOf, [int start = 0, int? end]) =>
      computed((via) => col.ListExtensions(via(_listWhat))
          .binarySearchByCompare<K>(
              element, keyOf, (a, b) => a.compareTo(b), start, end));

  /// Returns the index where [element] should be inserted in this sorted list.
  What<int> lowerBound(E element, int Function(E a, E b) compare) => computed(
      (via) => col.ListExtensions(via(_listWhat)).lowerBound(element, compare));

  /// Returns the index where [element] should be inserted by comparing key extracted via [keyOf].
  What<int> lowerBoundByCompare<K>(E element, K Function(E element) keyOf,
          int Function(K a, K b) compare, [int start = 0, int? end]) =>
      computed((via) => col.ListExtensions(via(_listWhat))
          .lowerBoundByCompare<K>(element, keyOf, compare, start, end));

  /// Returns the index where [element] should be inserted by key natural order.
  What<int> lowerBoundBy<K extends Comparable<dynamic>>(
          E element, K Function(E element) keyOf, [int start = 0, int? end]) =>
      computed((via) => col.ListExtensions(via(_listWhat))
          .lowerBoundByCompare<K>(
              element, keyOf, (a, b) => a.compareTo(b), start, end));

  /// Returns a new unmodifiable list containing a sorted range of elements from this list.
  What<List<E>> sortedRange(
          int start, int end, int Function(E a, E b) compare) =>
      computed((via) {
        final copy = via(_listWhat).toList();
        col.ListExtensions(copy).sortRange(start, end, compare);
        return List<E>.unmodifiable(copy);
      });

  /// Returns a new unmodifiable list containing elements sorted by [compare] of key extracted via [keyOf].
  What<List<E>> sortedByCompare<K>(
          K Function(E element) keyOf, int Function(K a, K b) compare,
          [int start = 0, int? end]) =>
      computed((via) {
        final copy = via(_listWhat).toList();
        col.ListExtensions(copy).sortByCompare<K>(keyOf, compare, start, end);
        return List<E>.unmodifiable(copy);
      });

  /// Returns a new unmodifiable list containing elements sorted by key extracted via [keyOf].
  What<List<E>> sortedBy<K extends Comparable<dynamic>>(
          K Function(E element) keyOf,
          [int start = 0,
          int? end]) =>
      computed((via) {
        final copy = via(_listWhat).toList();
        col.ListExtensions(copy)
            .sortByCompare<K>(keyOf, (a, b) => a.compareTo(b), start, end);
        return List<E>.unmodifiable(copy);
      });

  /// Returns a new unmodifiable list with a range of elements shuffled reactively.
  What<List<E>> shuffledRange(int start, int end, [Random? random]) =>
      computed((via) {
        final copy = via(_listWhat).toList();
        col.ListExtensions(copy).shuffleRange(start, end, random);
        return List<E>.unmodifiable(copy);
      });

  /// Returns a new unmodifiable list with a range of elements reversed reactively.
  What<List<E>> reversedRange(int start, int end) => computed((via) {
        final copy = via(_listWhat).toList();
        col.ListExtensions(copy).reverseRange(start, end);
        return List<E>.unmodifiable(copy);
      });

  /// Returns a new unmodifiable list with two elements swapped reactively.
  What<List<E>> swapped(int index1, int index2) => computed((via) {
        final copy = via(_listWhat).toList();
        col.ListExtensions(copy).swap(index1, index2);
        return List<E>.unmodifiable(copy);
      });

  /// Returns a sublist of this list reactively.
  What<List<E>> slice(int start, [int? end]) => sublist(start, end);

  /// Whether [other] has the same elements as this list reactively.
  What<bool> equals(List<E> other,
          [Equality<E> equality = const DefaultEquality()]) =>
      computed(
          (via) => col.ListExtensions(via(_listWhat)).equals(other, equality));

  /// Returns the [index]th element reactively, or `null` if out of range.
  What<E?> elementAtOrNull(int index) => computed(
      (via) => col.ListExtensions(via(_listWhat)).elementAtOrNull(index));

  /// Contiguous slices of this list with the given [length] reactively.
  What<List<List<E>>> slices(int length) =>
      computed((via) => List<List<E>>.unmodifiable(
            col.ListExtensions(via(_listWhat))
                .slices(length)
                .map((s) => List<E>.unmodifiable(s)),
          ));
}

/// Reactive extensions on [WhatListElements] holding [Comparable] elements.
extension ListComparableWhatElementsExtension<E extends Comparable<dynamic>>
    on WhatListElements<E> {
  What<List<E>> get _listWhat => what as What<List<E>>;

  /// Returns the index of [element] in this sorted list.
  What<int> binarySearch(E element, [int Function(E a, E b)? compare]) =>
      computed((via) => col.ListExtensions(via(_listWhat))
          .binarySearch(element, compare ?? (a, b) => a.compareTo(b)));

  /// Returns the index where [element] should be in this sorted list.
  What<int> lowerBound(E element, [int Function(E a, E b)? compare]) =>
      computed((via) => col.ListExtensions(via(_listWhat))
          .lowerBound(element, compare ?? (a, b) => a.compareTo(b)));

  /// Returns a new unmodifiable list containing a sorted range of elements from this list.
  What<List<E>> sortedRange(int start, int end,
          [int Function(E a, E b)? compare]) =>
      computed((via) {
        final copy = via(_listWhat).toList();
        col.ListExtensions(copy)
            .sortRange(start, end, compare ?? (a, b) => a.compareTo(b));
        return List<E>.unmodifiable(copy);
      });
}
