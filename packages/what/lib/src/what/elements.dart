// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

/// Extension on [What<Iterable<E>>] providing reactive element-wise operations via `.elements`.
///
/// Encapsulates collection operations behind a dedicated `.elements` proxy namespace to avoid
/// polluting the root [What] API while providing clean, defensive, and immutable transformations.
///
/// ## Sub-Functor & Invocation Pathways
/// ```text
/// iterableWhat.elements
///  ├── .map((e) => ...)                  --> What<List<T>>
///  ├── .where((e) => ...)                --> What<List<E>>
///  ├── .expand((e) => ...)               --> What<List<T>>
///  ├── .take(count)                      --> What<List<E>>
///  ├── .skip(count)                      --> What<List<E>>
///  ├── .first / .last / .length          --> What<E> / What<int>
///  └── .contains(element)                --> What<bool>
/// ```
///
/// ## System Architectural Flow
/// ```text
/// [Source What<Iterable<E>>]
///        │ (Push-Dirty Invalidation)
///        ▼
/// [iterableWhat.elements.map(...)]
///        │ (Pull-Data on Read)
///        ▼
/// [Immutable What<List<T>>] (List.unmodifiable)
/// ```
///
/// ## Examples
/// ```dart
/// final numbersController = WhatController([1, 2, 3, 4, 5]);
/// final evenNumbersWhat = numbersController.what.elements.where((n) => n.isEven);
/// ```
extension WhatIterableElementsExtension<E> on What<Iterable<E>> {
  /// Opens a dedicated namespace for operating on the individual elements of this [Iterable] reactively.
  ///
  /// **Ensures:**
  /// * Returns a [WhatIterableElements] proxy wrapping this [What].
  WhatIterableElements<E> get elements => WhatIterableElements<E>._(this);
}

/// Extension on [What<Iterable<E>>] providing keyed element-wise transformations via `.keyed`.
///
/// Keyed operations preserve downstream value/node cache across source collection updates,
/// eliminating expensive re-evaluations by caching results based on stable unique keys.
///
/// ## Sub-Functor & Invocation Pathways
/// ```text
/// iterableWhat.keyed
///  └── .map(key: (e) => ..., convert: (e) => ...)  --> What<List<R>>
/// ```
///
/// ## System Architectural Flow
/// ```text
/// [Source Collection] ──(Updates)──> [Keyed Cache Diffing (key: e.id)]
///                                           │
///                                           ├── [Existing Key: Reuses Cached Node]
///                                           └── [New Key: Evaluates & Caches]
/// ```
///
/// ## Examples
/// ```dart
/// final users = WhatController([User(id: '1', name: 'Alice')]);
/// final names = users.what.keyed.map(
///   key: (user) => user.id,
///   convert: (user) => user.name.toUpperCase(),
/// );
/// ```
extension WhatKeyedIterableElementsExtension<E> on What<Iterable<E>> {
  /// Opens a dedicated namespace for operating on keyed elements of this [Iterable] reactively.
  ///
  /// **Ensures:**
  /// * Returns a [WhatKeyedIterableElements] proxy wrapping this [What].
  WhatKeyedIterableElements<E> get keyed => WhatKeyedIterableElements<E>._(this);
}

/// Extension on [What<List<E>>] providing reactive list-specific index and slicing operations via `.elements`.
///
/// ## Sub-Functor & Invocation Pathways
/// ```text
/// listWhat.elements
///  ├── [index]                           --> What<E> (Reactive element lookup)
///  ├── .sublist(start, [end])            --> What<List<E>>
///  └── .reversed                         --> What<List<E>>
/// ```
///
/// ## Examples
/// ```dart
/// final itemsController = WhatController(['A', 'B', 'C']);
/// final firstItemWhat = itemsController.what.elements[0]; // What<String> holding 'A'
/// ```
extension WhatListElementsExtension<E> on What<List<E>> {
  /// Opens a dedicated namespace for operating on the individual elements of this [List] reactively.
  ///
  /// **Ensures:**
  /// * Returns a [WhatListElements] proxy wrapping this [What].
  WhatListElements<E> get elements => WhatListElements<E>._(this);
}

/// Extension on [What<Set<E>>] providing reactive set operations (union, intersection, difference) via `.elements`.
///
/// ## Sub-Functor & Invocation Pathways
/// ```text
/// setWhat.elements
///  ├── .union(other)                     --> What<Set<E>>
///  ├── .intersection(other)              --> What<Set<E>>
///  └── .difference(other)                --> What<Set<E>>
/// ```
///
/// ## Examples
/// ```dart
/// final setAController = WhatController({'a', 'b'});
/// final unionWhat = setAController.what.elements.union({'c', 'd'});
/// ```
extension WhatSetElementsExtension<E> on What<Set<E>> {
  /// Opens a dedicated namespace for operating on the individual elements of this [Set] reactively.
  ///
  /// **Ensures:**
  /// * Returns a [WhatSetElements] proxy wrapping this [What].
  WhatSetElements<E> get elements => WhatSetElements<E>._(this);
}

/// Extension on [What<Map<K, V>>] providing reactive map entry transformations and key/value accessors via `.elements`.
///
/// ## Sub-Functor & Invocation Pathways
/// ```text
/// mapWhat.elements
///  ├── [key]                             --> What<V?> (Reactive value lookup)
///  ├── .keys                             --> What<List<K>>
///  ├── .values                           --> What<List<V>>
///  ├── .length                           --> What<int>
///  └── .isEmpty / .isNotEmpty            --> What<bool>
/// ```
///
/// ## Examples
/// ```dart
/// final scoresController = WhatController({'Alice': 100, 'Bob': 85});
/// final aliceScoreWhat = scoresController.what.elements['Alice']; // What<int?> holding 100
/// ```
extension WhatMapElementsExtension<K, V> on What<Map<K, V>> {
  /// Opens a dedicated namespace for operating on the individual elements of this [Map] reactively.
  ///
  /// **Ensures:**
  /// * Returns a [WhatMapElements] proxy wrapping this [What].
  WhatMapElements<K, V> get elements => WhatMapElements<K, V>._(this);
}

/// A dedicated proxy wrapper for [What<Iterable<E>>] to perform element-wise transformations safely and defensively.
///
/// Under the hood, all collection-returning operations immediately compute and package
/// results into an immutable list ([List.unmodifiable]) to prevent lazy computation exceptions
/// outside the reactive boundary and to enforce state immutability.
///
/// **Data Propagation Flow:**
/// ```text
/// [Source What<Iterable<E>>]
///        │ (Push-Dirty)
///        ▼
/// [WhatIterableElements<E> Proxy]
///        │ (Pull-Data on evaluate: maps/filters elements defensively)
///        ▼
/// Returns immutable [What<List<T>>] or scalar aggregation in O(1)
/// ```
extension type WhatIterableElements<E>._(What<Iterable<E>> _what) {
  /// Exposes the underlying [What] node of this elements proxy.
  What<Iterable<E>> get what => _what;

  /// Maps each element of this collection to another object [T].
  ///
  /// * [convert]: The mapping transformation callback applied to each element.
  ///
  /// **Ensures:**
  /// * Returns a [What<List<T>>] holding an unmodifiable list of mapped items.
  What<List<T>> map<T>(T Function(E element) convert) => computed((via) => List.unmodifiable(via(_what).map(convert)));

  /// Filters elements of this collection based on [test].
  ///
  /// * [test]: The predicate used to filter elements.
  ///
  /// **Ensures:**
  /// * Returns a [What<List<E>>] containing only elements that satisfy [test].
  What<List<E>> where(bool Function(E element) test) => computed((via) => List.unmodifiable(via(_what).where(test)));

  /// Returns a list of elements that have type [T] reactively.
  ///
  /// **Ensures:**
  /// * Returns a [What<List<T>>] containing unmodifiable filtered items of type [T].
  What<List<T>> whereType<T>() => computed((via) => List.unmodifiable(via(_what).whereType<T>()));

  /// Returns a list of (index, element) pairs reactively.
  ///
  /// **Ensures:**
  /// * Returns a [What<List<(int, E)>>] holding paired indices and elements.
  What<List<(int, E)>> get indexed => computed((via) => List.unmodifiable(via(_what).indexed));

  /// Flattens this collection by mapping each element to an [Iterable] and concatenating.
  ///
  /// * [toElements]: A function that transforms each element into an iterable of [T].
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<List<T>>] containing the concatenated results.
  What<List<T>> expand<T>(Iterable<T> Function(E element) toElements) =>
      computed((via) => List.unmodifiable(via(_what).expand(toElements)));

  /// Checks whether the collection contains an element equal to [element] reactively.
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] yielding `true` if [element] is present, `false` otherwise.
  What<bool> contains(Object? element) => computed((via) => via(_what).contains(element));

  /// Reduces a collection to a single value by iteratively combining elements reactively.
  ///
  /// * [combine]: The reducer function combining accumulator and current element.
  ///
  /// **Requires:**
  /// * The collection must not be empty when evaluated.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] holding the reduced scalar result.
  What<E> reduce(E Function(E value, E element) combine) => computed((via) => via(_what).reduce(combine));

  /// Reduces a collection to a single value by iteratively combining elements with an initial value reactively.
  ///
  /// * [initialValue]: The initial accumulator value.
  /// * [combine]: The folder function combining accumulator and current element.
  ///
  /// **Ensures:**
  /// * Returns a [What<T>] holding the folded result.
  What<T> fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      computed((via) => via(_what).fold(initialValue, combine));

  /// Checks if all elements satisfy [test].
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] that evaluates to `true` if every element satisfies [test].
  What<bool> every(bool Function(E element) test) => computed((via) => via(_what).every(test));

  /// Converts each element to a [String] and concatenates the results reactively.
  ///
  /// * [separator]: The delimiter string placed between elements. Defaults to empty string.
  ///
  /// **Ensures:**
  /// * Returns a [What<String>] with the joined representation.
  What<String> join([String separator = '']) => computed((via) => via(_what).join(separator));

  /// Checks if any element satisfies [test].
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] yielding `true` if at least one element satisfies [test].
  What<bool> any(bool Function(E element) test) => computed((via) => via(_what).any(test));

  /// Returns a list containing the elements of this iterable reactively.
  ///
  /// * [growable]: Whether the resulting list should be growable. Defaults to `false`.
  ///
  /// **Ensures:**
  /// * Returns a [What<List<E>>] with the collection contents.
  What<List<E>> toList({bool growable = false}) =>
      computed((via) => growable ? List.of(via(_what), growable: true) : List.unmodifiable(via(_what)));

  /// Returns a set containing the elements of this iterable reactively.
  ///
  /// * [unmodifiable]: Whether the resulting set is immutable. Defaults to `true`.
  ///
  /// **Ensures:**
  /// * Returns a [What<Set<E>>] containing unique elements from this iterable.
  What<Set<E>> toSet({bool unmodifiable = true}) =>
      computed((via) => unmodifiable ? Set.unmodifiable(via(_what).toSet()) : via(_what).toSet());

  /// Returns the number of elements reactively.
  ///
  /// **Ensures:**
  /// * Returns a [What<int>] reflecting the current collection length.
  What<int> get length => computed((via) => via(_what).length);

  /// Checks if this collection is empty.
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] that is `true` if the collection contains no elements.
  What<bool> get isEmpty => computed((via) => via(_what).isEmpty);

  /// Checks if this collection is not empty.
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] that is `true` if the collection contains at least one element.
  What<bool> get isNotEmpty => computed((via) => via(_what).isNotEmpty);

  /// Takes the first [count] elements of this collection.
  ///
  /// * [count]: The number of initial elements to include.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<List<E>>] holding up to [count] elements.
  What<List<E>> take(int count) => computed((via) => List.unmodifiable(via(_what).take(count)));

  /// Skips the first [count] elements of this collection.
  ///
  /// * [count]: The number of initial elements to discard.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<List<E>>] without the first [count] elements.
  What<List<E>> skip(int count) => computed((via) => List.unmodifiable(via(_what).skip(count)));

  /// Returns the first element of this collection reactively.
  ///
  /// **Requires:**
  /// * The source collection must not be empty when evaluated.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] yielding the first element.
  What<E> get first => computed((via) => via(_what).first);

  /// Returns the first element of this collection reactively, or null if empty.
  ///
  /// **Ensures:**
  /// * Returns a [What<E?>] yielding the first element or `null` if empty.
  What<E?> get firstOrNull => computed((via) => via(_what).firstOrNull);

  /// Returns the last element of this collection reactively.
  ///
  /// **Requires:**
  /// * The source collection must not be empty when evaluated.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] yielding the last element.
  What<E> get last => computed((via) => via(_what).last);

  /// Returns the last element of this collection reactively, or null if empty.
  ///
  /// **Ensures:**
  /// * Returns a [What<E?>] yielding the last element or `null` if empty.
  What<E?> get lastOrNull => computed((via) => via(_what).lastOrNull);

  /// Checks that this collection has only one element, and returns that element reactively.
  ///
  /// **Requires:**
  /// * The collection must have exactly one element when evaluated.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] yielding the single element.
  What<E> get single => computed((via) => via(_what).single);

  /// Checks that this collection has only one element, and returns that element reactively, or null if empty/multiple.
  ///
  /// **Ensures:**
  /// * Returns a [What<E?>] yielding the single element or `null` otherwise.
  What<E?> get singleOrNull => computed((via) => via(_what).singleOrNull);

  /// Returns the first element that satisfies the given predicate [test] reactively.
  ///
  /// * [test]: Predicate callback to test elements against.
  /// * [orElse]: Optional fallback generator if no matching element is found.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] yielding the first matching element.
  What<E> firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      computed((via) => via(_what).firstWhere(test, orElse: orElse));

  /// Returns the last element that satisfies the given predicate [test] reactively.
  ///
  /// * [test]: Predicate callback to test elements against.
  /// * [orElse]: Optional fallback generator if no matching element is found.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] yielding the last matching element.
  What<E> lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      computed((via) => via(_what).lastWhere(test, orElse: orElse));

  /// Returns the single element that satisfies [test] reactively.
  ///
  /// * [test]: Predicate callback to test elements against.
  /// * [orElse]: Optional fallback generator if no matching element is found.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] yielding the matching single element.
  What<E> singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      computed((via) => via(_what).singleWhere(test, orElse: orElse));

  /// Returns the [index]th element reactively.
  ///
  /// * [index]: The zero-based index of the element to retrieve.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] holding the element at [index].
  What<E> elementAt(int index) => computed((via) => via(_what).elementAt(index));
}

/// A dedicated proxy wrapper for [What<Iterable<E>>] to perform keyed element-wise transformations safely and lazily.
///
/// ## System Architectural Flow (Keyed Dynamic Divergence)
/// ```text
/// [Source What<Iterable<E>>]
///        │ (Push-Dirty on list mutation)
///        ▼
/// [Keyed Divergence Engine]
///        ├─► Matches existing Key ──► Reuses existing mapped instance (preserves state)
///        ├─► New Key Detected      ──► Invokes convert() & caches mapped instance
///        └─► Removed Key           ──► Releases obsolete cached instance
///        │
///        ▼
/// [Output What<List<T>>] (Composite list of cached and newly mapped instances)
/// ```
extension type WhatKeyedIterableElements<E>._(What<Iterable<E>> _what) {
  /// Exposes the underlying [What] node.
  What<Iterable<E>> get what => _what;

  /// Maps an `Iterable` to a `List` of objects while safely caching the mapped objects by unique keys.
  ///
  /// This operator is highly optimized for maintaining expensive custom Dart objects
  /// (such as widgets, controllers, or ViewModels) across iterable state changes.
  /// By reusing instances whose keys haven't changed, this method minimizes object
  /// instantiation overhead and preserves local state within the mapped objects
  /// across frequent updates of the source iterable.
  ///
  /// * [key]: A function that extracts a unique identifier from a source element.
  /// * [convert]: A function that constructs a new mapped object `T` from a source element.
  ///
  /// **Requires:**
  /// * The [key] function must return a stable, unique identifier for each logically
  ///   distinct element.
  ///
  /// **Ensures:**
  /// * Returns a `What<List<T>>` containing the newly mapped or cached objects.
  /// * If a source element's key matches a cached object, the cached object is reused
  ///   instead of calling [convert] again.
  ///
  /// **Warning (Anti-Pattern Prevention):**
  /// - Non-stable or random keys (e.g. `DateTime.now()` or `Object()`) defeat the keyed caching mechanism.
  ///   Always use persistent, immutable entity IDs.
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Using unstable keys recreates mapped objects every frame
  /// final cardsWhat = usersWhat.keyed.map(
  ///   key: (user) => Object(), // New key each evaluation!
  ///   convert: (user) => UserCard(user),
  /// );
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Use stable unique entity IDs for keyed instance reuse
  /// final cardsWhat = usersWhat.keyed.map(
  ///   key: (user) => user.id,
  ///   convert: (user) => UserCard(user),
  /// );
  /// ```
  What<List<T>> map<K, T>({
    required K Function(E data) key,
    required T Function(E data) convert,
  }) =>
      _KeyedMapWhat<E, K, T>(_what, key: key, convert: convert);
}

/// A dedicated proxy wrapper for [What<List<E>>] to perform list-specific lookup and slicing computations.
extension type WhatListElements<E>._(What<List<E>> _what) implements WhatIterableElements<E> {
  /// Look up the element at [index] reactively.
  ///
  /// * [index]: The zero-based position in the list.
  ///
  /// **Ensures:**
  /// * Returns a [What<E>] holding the element at [index].
  What<E> operator [](int index) => computed((via) => via(_what)[index]);

  /// Returns a reversed view of this list reactively.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<List<E>>] with elements in reverse order.
  What<List<E>> get reversed => computed((via) => List.unmodifiable(via(_what).reversed));

  /// Returns the first index of [element] reactively.
  ///
  /// * [element]: The target element to search for.
  /// * [start]: The starting position for the search. Defaults to 0.
  ///
  /// **Ensures:**
  /// * Returns a [What<int>] with the index of [element] or `-1` if not found.
  What<int> indexOf(E element, [int start = 0]) => computed((via) => via(_what).indexOf(element, start));

  /// Returns the first index in the list that satisfies [test] reactively.
  ///
  /// * [test]: Predicate callback to evaluate list elements.
  /// * [start]: The starting position for the search. Defaults to 0.
  ///
  /// **Ensures:**
  /// * Returns a [What<int>] with the first matching index or `-1` if none match.
  What<int> indexWhere(bool Function(E element) test, [int start = 0]) =>
      computed((via) => via(_what).indexWhere(test, start));

  /// Returns the last index in the list that satisfies [test] reactively.
  ///
  /// * [test]: Predicate callback to evaluate list elements.
  /// * [start]: Optional starting position searching backward.
  ///
  /// **Ensures:**
  /// * Returns a [What<int>] with the last matching index or `-1` if none match.
  What<int> lastIndexWhere(bool Function(E element) test, [int? start]) =>
      computed((via) => via(_what).lastIndexWhere(test, start));

  /// Returns the last index of [element] reactively.
  ///
  /// * [element]: The target element to locate.
  /// * [start]: Optional starting position searching backward.
  ///
  /// **Ensures:**
  /// * Returns a [What<int>] with the last occurrence index or `-1` if not found.
  What<int> lastIndexOf(E element, [int? start]) => computed((via) => via(_what).lastIndexOf(element, start));

  /// Returns a sublist of this list reactively.
  ///
  /// * [start]: The beginning index (inclusive).
  /// * [end]: Optional ending index (exclusive).
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<List<E>>] with the sliced subrange.
  What<List<E>> sublist(int start, [int? end]) => computed((via) => List.unmodifiable(via(_what).sublist(start, end)));

  /// Returns an unmodifiable [Map] view of this list reactively.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<Map<int, E>>] mapping indices to values.
  What<Map<int, E>> asMap() => computed((via) => Map.unmodifiable(via(_what).asMap()));

  /// Adapts this list to be a `What<List<T>>` reactively.
  ///
  /// **Ensures:**
  /// * Returns a type-cast [What<List<T>>].
  What<List<T>> cast<T>() => computed((via) => List.castFrom<E, T>(via(_what)));

  /// Returns an unmodifiable list containing all elements of this list reactively.
  ///
  /// **Ensures:**
  /// * Returns an immutable [What<List<E>>].
  What<List<E>> toUnmodifiable() => computed((via) => List.unmodifiable(via(_what)));
}

/// A dedicated proxy wrapper for [What<Set<E>>] to perform set-specific operations while preserving set immutability.
extension type WhatSetElements<E>._(What<Set<E>> _what) implements WhatIterableElements<E> {
  /// Looks up [object] in the set reactively.
  ///
  /// * [object]: The target object to lookup.
  ///
  /// **Ensures:**
  /// * Returns a [What<E?>] yielding the matched object or `null` if absent.
  What<E?> lookup(Object? object) => computed((via) => via(_what).lookup(object));

  /// Computes the intersection of this set and [other] reactively.
  ///
  /// * [other]: The secondary set to intersect with.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<Set<E>>] containing common elements.
  What<Set<E>> intersection(Set<E> other) => computed((via) => Set.unmodifiable(via(_what).intersection(other)));

  /// Computes the union of this set and [other] reactively.
  ///
  /// * [other]: The secondary set to unite with.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<Set<E>>] containing elements from both sets.
  What<Set<E>> union(Set<E> other) => computed((via) => Set.unmodifiable(via(_what).union(other)));

  /// Computes the difference between this set and [other] reactively.
  ///
  /// * [other]: The secondary set whose elements will be excluded.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<Set<E>>] containing elements not in [other].
  What<Set<E>> difference(Set<E> other) => computed((via) => Set.unmodifiable(via(_what).difference(other)));

  /// Adapts this set to be a `What<Set<T>>` reactively.
  ///
  /// **Ensures:**
  /// * Returns a type-cast [What<Set<T>>].
  What<Set<T>> cast<T>() => computed((via) => Set.castFrom<E, T>(via(_what)));

  /// Returns an unmodifiable set containing all elements of this set reactively.
  ///
  /// **Ensures:**
  /// * Returns an immutable [What<Set<E>>].
  What<Set<E>> toUnmodifiable() => computed((via) => Set.unmodifiable(via(_what)));
}

/// A dedicated proxy wrapper for [What<Map<K, V>>] to perform map lookup, mapping, and filtering operations.
extension type WhatMapElements<K, V>._(What<Map<K, V>> _what) {
  /// Exposes the underlying [What] node of this elements proxy.
  What<Map<K, V>> get what => _what;

  /// Look up the value associated with [key] reactively.
  ///
  /// * [key]: The key to locate in the map.
  ///
  /// **Ensures:**
  /// * Returns a [What<V?>] holding the mapped value or `null` if absent.
  What<V?> operator [](K key) => computed((via) => via(_what)[key]);

  /// Checks whether this map contains the given [key] reactively.
  ///
  /// * [key]: The key to check for presence.
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] that is `true` if [key] exists in the map.
  What<bool> containsKey(Object? key) => computed((via) => via(_what).containsKey(key));

  /// Checks whether this map contains the given [value] reactively.
  ///
  /// * [value]: The value to check for presence.
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] that is `true` if [value] exists in the map.
  What<bool> containsValue(Object? value) => computed((via) => via(_what).containsValue(value));

  /// Maps the entries of this map reactively to a new map.
  ///
  /// * [convert]: Mapping callback transforming key-value pairs into new [MapEntry] instances.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<Map<K2, V2>>] with the transformed entries.
  What<Map<K2, V2>> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) =>
      computed((via) => Map.unmodifiable(via(_what).map(convert)));

  /// Filters the entries of this map based on [test] reactively.
  ///
  /// * [test]: Predicate callback testing key-value pairs.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<Map<K, V>>] retaining only entries that satisfy [test].
  What<Map<K, V>> where(bool Function(K key, V value) test) {
    return computed((via) {
      final source = via(_what);
      final filtered = Map<K, V>.from(source)..removeWhere((k, v) => !test(k, v));
      return Map.unmodifiable(filtered);
    });
  }

  /// Returns the keys of this map reactively.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<List<K>>] containing all map keys.
  What<List<K>> get keys => computed((via) => List.unmodifiable(via(_what).keys));

  /// Returns the values of this map reactively.
  ///
  /// **Ensures:**
  /// * Returns an unmodifiable [What<List<V>>] containing all map values.
  What<List<V>> get values => computed((via) => List.unmodifiable(via(_what).values));

  /// Returns the number of key-value pairs reactively.
  ///
  /// **Ensures:**
  /// * Returns a [What<int>] reflecting the map entry count.
  What<int> get length => computed((via) => via(_what).length);

  /// Checks if this map is empty.
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] that is `true` if the map contains no entries.
  What<bool> get isEmpty => computed((via) => via(_what).isEmpty);

  /// Checks if this map is not empty.
  ///
  /// **Ensures:**
  /// * Returns a [What<bool>] that is `true` if the map contains at least one entry.
  What<bool> get isNotEmpty => computed((via) => via(_what).isNotEmpty);

  /// Adapts this map to be a `What<Map<K2, V2>>` reactively.
  ///
  /// **Ensures:**
  /// * Returns a type-cast [What<Map<K2, V2>>].
  What<Map<K2, V2>> cast<K2, V2>() => computed((via) => Map.castFrom<K, V, K2, V2>(via(_what)));

  /// Returns an unmodifiable map containing all entries of this map reactively.
  ///
  /// **Ensures:**
  /// * Returns an immutable [What<Map<K, V>>].
  What<Map<K, V>> toUnmodifiable() => computed((via) => Map.unmodifiable(via(_what)));
}
