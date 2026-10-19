// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use

import 'dart:math' show Random;
import 'package:collection/collection.dart';
import 'package:collection/collection.dart' as col;
import 'package:what/what.dart';

// =============================================================================
// Reactive General Iterable Extensions
// =============================================================================

/// Reactive extensions on [WhatIterableElements] providing collection utilities.
///
/// **Design Philosophy (Immutable Return Values & Defensive Isolation):**
/// All transformation methods (such as [sorted], [shuffled], [whereNot], [slices], [groupListsBy])
/// compute lazily and return immutable [List.unmodifiable] collections to prevent
/// unexpected side-effects and preserve reactive state isolation.
///
/// **Data Propagation Flow:**
/// ```text
/// [Source What<Iterable<E>>]
///        │ (Push-Dirty)
///        ▼
/// [Grouping & Slicing Operator Pipeline]
///        ├─► .slices(3)         ──► Chunked What<List<List<E>>>
///        ├─► .groupListsBy(key) ──► Grouped What<Map<K, List<E>>>
///        ├─► .sample(n)         ──► Randomized What<List<E>>
///        └─► .sortedBy(key)     ──► Sorted What<List<E>>
/// ```
///
/// **Example:**
/// ```dart
/// final numbers = what([1, 2, 3, 4, 5, 6, 7]);
/// final chunks = numbers.elements.slices(3);
/// final evenOdd = numbers.elements.groupListsBy((n) => n % 2 == 0 ? 'even' : 'odd');
///
/// print(chunks.data);  // [[1, 2, 3], [4, 5, 6], [7]]
/// print(evenOdd.data); // {'odd': [1, 3, 5, 7], 'even': [2, 4, 6]}
/// ```
extension GeneralWhatElementsExtension<E> on WhatIterableElements<E> {
  /// Selects [count] elements at random from this collection reactively.
  What<List<E>> sample(int count, [Random? random]) =>
      computed((via) => List.unmodifiable(via(what).sample(count, random)));

  /// Returns a list of elements that do not satisfy [test] reactively.
  What<List<E>> whereNot(bool Function(E element) test) =>
      computed((via) => List.unmodifiable(via(what).whereNot(test)));

  /// Returns a list containing the elements of this collection sorted by [compare] reactively.
  What<List<E>> sorted(int Function(E a, E b) compare) =>
      computed((via) => List.unmodifiable(via(what).sorted(compare)));

  /// Returns a list containing the elements of this collection shuffled reactively.
  What<List<E>> shuffled([Random? random]) =>
      computed((via) => List.unmodifiable(via(what).shuffled(random)));

  /// Returns a list containing the elements of this collection sorted by [keyOf] reactively.
  What<List<E>> sortedBy<K extends Comparable<dynamic>>(
          K Function(E element) keyOf) =>
      computed((via) => List.unmodifiable(
          via(what).sortedByCompare<K>(keyOf, (a, b) => a.compareTo(b))));

  /// Returns a list containing the elements of this collection sorted by [compare] of [keyOf] reactively.
  What<List<E>> sortedByCompare<K>(
          K Function(E element) keyOf, int Function(K a, K b) compare) =>
      computed((via) =>
          List.unmodifiable(via(what).sortedByCompare<K>(keyOf, compare)));

  /// Returns `true` if this collection is sorted by [compare] reactively.
  What<bool> isSorted(int Function(E a, E b) compare) =>
      computed((via) => via(what).isSorted(compare));

  /// Returns `true` if this collection is sorted by the natural order of [keyOf] reactively.
  What<bool> isSortedBy<K extends Comparable<dynamic>>(
          K Function(E element) keyOf) =>
      computed((via) =>
          via(what).isSortedByCompare<K>(keyOf, (a, b) => a.compareTo(b)));

  /// Returns `true` if this collection is sorted by [compare] of [keyOf] reactively.
  What<bool> isSortedByCompare<K>(
          K Function(E element) keyOf, int Function(K a, K b) compare) =>
      computed((via) => via(what).isSortedByCompare<K>(keyOf, compare));

  /// Maps each element of this collection along with its index reactively.
  What<List<T>> mapIndexed<T>(T Function(int index, E element) convert) =>
      computed((via) => List.unmodifiable(via(what).mapIndexed(convert)));

  /// Filters elements of this collection based on an indexed predicate [test] reactively.
  What<List<E>> whereIndexed(bool Function(int index, E element) test) =>
      computed((via) => List.unmodifiable(via(what).whereIndexed(test)));

  /// Filters elements of this collection based on an indexed predicate [test] reactively, returning those that do not satisfy it.
  What<List<E>> whereNotIndexed(bool Function(int index, E element) test) =>
      computed((via) => List.unmodifiable(via(what).whereNotIndexed(test)));

  /// Flattens this collection along with element indices reactively.
  What<List<T>> expandIndexed<T>(
          Iterable<T> Function(int index, E element) toElements) =>
      computed((via) => List.unmodifiable(via(what).expandIndexed(toElements)));

  /// Reduces this collection to a single value by iteratively combining elements along with their index reactively.
  What<E> reduceIndexed(E Function(int index, E previous, E element) combine) =>
      computed((via) => via(what).reduceIndexed(combine));

  /// Reduces this collection to a single value by iteratively combining elements along with their index and an initial value reactively.
  What<T> foldIndexed<T>(T initialValue,
          T Function(int index, T previous, E element) combine) =>
      computed((via) => via(what).foldIndexed<T>(initialValue, combine));

  /// Returns the first element that satisfies [test] reactively, or `null` if none.
  What<E?> firstWhereOrNull(bool Function(E element) test) =>
      computed((via) => via(what).firstWhereOrNull(test));

  /// Returns the first element that satisfies an indexed predicate [test] reactively, or `null` if none.
  What<E?> firstWhereIndexedOrNull(bool Function(int index, E element) test) =>
      computed((via) => via(what).firstWhereIndexedOrNull(test));

  /// Returns the last element that satisfies [test] reactively, or `null` if none.
  What<E?> lastWhereOrNull(bool Function(E element) test) =>
      computed((via) => via(what).lastWhereOrNull(test));

  /// Returns the last element that satisfies an indexed predicate [test] reactively, or `null` if none.
  What<E?> lastWhereIndexedOrNull(bool Function(int index, E element) test) =>
      computed((via) => via(what).lastWhereIndexedOrNull(test));

  /// Returns the single element that satisfies [test] reactively, or `null` if none.
  What<E?> singleWhereOrNull(bool Function(E element) test) =>
      computed((via) => via(what).singleWhereOrNull(test));

  /// Returns the single element that satisfies an indexed predicate [test] reactively, or `null` if none.
  What<E?> singleWhereIndexedOrNull(bool Function(int index, E element) test) =>
      computed((via) => via(what).singleWhereIndexedOrNull(test));

  /// Returns the [index]th element reactively, or `null` if out of range.
  What<E?> elementAtOrNull(int index) =>
      computed((via) => via(what).elementAtOrNull(index));

  /// Groups elements by [key] reactively, keeping only the last element for each key.
  What<Map<K, E>> lastBy<K>(K Function(E element) key) =>
      computed((via) => Map<K, E>.unmodifiable(via(what).lastBy<K>(key)));

  /// Groups and folds elements by a key computed from each element reactively.
  What<Map<K, G>> groupFoldBy<K, G>({
    required K Function(E element) key,
    required G Function(G? previous, E element) fold,
  }) =>
      computed((via) =>
          Map<K, G>.unmodifiable(via(what).groupFoldBy<K, G>(key, fold)));

  /// Groups elements into sets by [keyOf] reactively.
  What<Map<K, Set<E>>> groupSetsBy<K>(K Function(E element) keyOf) =>
      computed((via) => Map<K, Set<E>>.unmodifiable(
            via(what)
                .groupSetsBy<K>(keyOf)
                .map((k, v) => MapEntry<K, Set<E>>(k, Set<E>.unmodifiable(v))),
          ));

  /// Groups elements into lists by [keyOf] reactively.
  What<Map<K, List<E>>> groupListsBy<K>(K Function(E element) keyOf) =>
      computed((via) => Map<K, List<E>>.unmodifiable(
            via(what).groupListsBy<K>(keyOf).map(
                (k, v) => MapEntry<K, List<E>>(k, List<E>.unmodifiable(v))),
          ));

  /// Legacy alias of [groupListsBy].
  What<Map<K, List<E>>> groupBy<K>(K Function(E element) key) =>
      computed((via) => Map<K, List<E>>.unmodifiable(
            col.groupBy<E, K>(via(what), key).map(
                (k, v) => MapEntry<K, List<E>>(k, List<E>.unmodifiable(v))),
          ));

  /// Splits this collection into chunks before elements satisfying [test] reactively.
  What<List<List<E>>> splitBefore(bool Function(E element) test) =>
      computed((via) => List<List<E>>.unmodifiable(
            via(what).splitBefore(test).map((s) => List<E>.unmodifiable(s)),
          ));

  /// Splits this collection after elements satisfying [test] reactively.
  What<List<List<E>>> splitAfter(bool Function(E element) test) =>
      computed((via) => List<List<E>>.unmodifiable(
            via(what).splitAfter(test).map((s) => List<E>.unmodifiable(s)),
          ));

  /// Splits this collection into chunks between elements satisfying [test] reactively.
  What<List<List<E>>> splitBetween(bool Function(E first, E second) test) =>
      computed((via) => List<List<E>>.unmodifiable(
            via(what).splitBetween(test).map((s) => List<E>.unmodifiable(s)),
          ));

  /// Splits this collection into chunks before elements satisfying an indexed predicate [test] reactively.
  What<List<List<E>>> splitBeforeIndexed(
          bool Function(int index, E element) test) =>
      computed((via) => List<List<E>>.unmodifiable(
            via(what)
                .splitBeforeIndexed(test)
                .map((s) => List<E>.unmodifiable(s)),
          ));

  /// Splits this collection into chunks after elements satisfying an indexed predicate [test] reactively.
  What<List<List<E>>> splitAfterIndexed(
          bool Function(int index, E element) test) =>
      computed((via) => List<List<E>>.unmodifiable(
            via(what)
                .splitAfterIndexed(test)
                .map((s) => List<E>.unmodifiable(s)),
          ));

  /// Splits this collection into chunks between elements satisfying an indexed predicate [test] reactively.
  What<List<List<E>>> splitBetweenIndexed(
          bool Function(int index, E first, E second) test) =>
      computed((via) => List<List<E>>.unmodifiable(
            via(what)
                .splitBetweenIndexed(test)
                .map((s) => List<E>.unmodifiable(s)),
          ));

  /// Returns `true` if no elements satisfy [test] reactively.
  What<bool> none(bool Function(E element) test) =>
      computed((via) => via(what).none(test));

  /// Returns `true` if no elements satisfy an indexed predicate [test] reactively.
  What<bool> noneIndexed(bool Function(int index, E element) test) => computed(
      (via) => !via(what).indexed.any((pair) => test(pair.$1, pair.$2)));

  /// Returns `true` if any element satisfies an indexed predicate [test] reactively.
  What<bool> anyIndexed(bool Function(int index, E element) test) => computed(
      (via) => via(what).indexed.any((pair) => test(pair.$1, pair.$2)));

  /// Returns `true` if all elements satisfy an indexed predicate [test] reactively.
  What<bool> everyIndexed(bool Function(int index, E element) test) => computed(
      (via) => via(what).indexed.every((pair) => test(pair.$1, pair.$2)));

  /// Splits this collection into chunks of [size] elements reactively.
  What<List<List<E>>> slices(int size) =>
      computed((via) => List<List<E>>.unmodifiable(
            via(what).slices(size).map((s) => List<E>.unmodifiable(s)),
          ));
}

/// Reactive extensions for collections of nullable elements.
extension NullableWhatElementsExtension<E extends Object>
    on WhatIterableElements<E?> {
  /// Returns an unmodifiable list of all non-null elements of this collection reactively.
  What<List<E>> get whereNotNull =>
      computed((via) => List.unmodifiable(via(what).whereNotNull()));
}

/// Reactive extensions for nested collections of iterables.
extension IterableIterableWhatElementsExtension<T>
    on WhatIterableElements<Iterable<T>> {
  /// Flattens this collection of iterables into a single unmodifiable list reactively.
  What<List<T>> get flattenedToList =>
      computed((via) => List.unmodifiable(via(what).flattened));

  /// Flattens this collection of iterables into a single unmodifiable set reactively.
  What<Set<T>> get flattenedToSet =>
      computed((via) => Set.unmodifiable(via(what).flattened.toSet()));
}
