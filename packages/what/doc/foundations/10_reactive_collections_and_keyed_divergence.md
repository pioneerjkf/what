# Fine-Grained Reactive Collections: Keyed Divergence, Transactional State, and Element-Wise Projections
## (Fine-Grained Reactive Collections: Keyed Divergence, Transactional State, and Element-Wise Projections)

> **"Rebuilding an entire 1,000-item collection view because a single field mutated is evidence of architectural failure. Collection reactivity is achieved through atomic transactions, defensive element-wise projections, and keyed cache divergence."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Collection Reactivity Impedance Mismatch

Unlike scalar primitives (integers, strings, booleans), collection data structures (`List`, `Set`, `Map`) represent aggregated sets of mutable elements. Traditional reactive architectures encounter three critical pitfalls when handling collections:

1. **Coarse-Grained Subtree Rebuild Cascades**:
   Modifying a single item triggers rebuilds across all views observing the collection, leading to scroll-jank, focus loss, and GC pressure.
2. **Local Component State Loss Across Index Shifts**:
   When mapping items into UI components, sorting or filtering items causes local input state (text controller cursors, focus nodes, animation progress) to shift onto adjacent items or reset entirely.
3. **Notification Avalanches in Batch Mutations**:
   Sequences like `list.add()`, `list.removeAt()`, and `list[0] = ...` emit individual invalidation pulses, overloading downstream LPDAG graphs with redundant recomputations.

The What Framework resolves these challenges through three architectural pillars:
- **Transactional Collection Controllers ([`WhatListController`](../../lib/src/what/collection.dart), [`WhatSetController`](../../lib/src/what/collection.dart), [`WhatMapController`](../../lib/src/what/collection.dart))**: Collapses batch modifications into single atomic pulses while enforcing immutable snapshots.
- **Keyed Cache Divergence ([`WhatKeyedIterableElements.map`](../../lib/src/what/elements.dart#L455))**: Preserves ViewModel and widget state across list reordering, sorting, and pagination.
- **Defensive Element-Wise Projections ([`WhatIterableElements`](../../lib/src/what/elements.dart#L169)) & Higher-Order Aggregations ([`WhatIterableWhatExtension`](../../lib/src/what/collection.dart#L301))**: Exposes surgical element subscriptions and multi-node reactive folding.

---

## 2. Transactional Collection Controllers: The Controller Triad

What Framework provides specialized controllers for `List`, `Set`, and `Map`. Each controller is backed by an internal entry node ([`_ListEntry`](../../lib/src/what/_internal/_collection.dart#L51), [`_SetEntry`](../../lib/src/what/_internal/_collection.dart#L72), [`_MapEntry`](../../lib/src/what/_internal/_collection.dart#L93)) extending `_DistinctEntry<T>` with built-in shallow equality checking.

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│               What Collection Controller Transactional Pipeline                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   controller.edit((draft) {                                                     │
│     draft.add(Item('A'));                                                       │
│     draft.removeAt(2);          ──► [In-place Mutating Draft Buffer]            │
│     draft.sort(...);                                                            │
│   });                                                                           │
│            │                                                                    │
│            ▼ (Atomic Commit via .set(draft))                                    │
│   [Freezes into Unmodifiable Snapshot (e.g. List.unmodifiable)]                 │
│            │                                                                    │
│            ▼ (Equality Comparison with Previous Payload)                        │
│   [Modified? ── Yes ──► Emits Exactly 1 LPDAG Push-Dirty Pulse]                 │
│              └── No  ──► No-Op (Zero Downstream Recomputations)]                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 The Controller Triad

1. **[`WhatListController<T>`](../../lib/src/what/collection.dart#L57)**:
   - Manages ordered sequences of elements.
   - Enforces immutability by wrapping all committed data in [`List.unmodifiable`](../../lib/src/what/_internal/_collection.dart#L55).
   - Default equality comparator: `_listEquals<T>` (checks length and index-wise equality).
2. **[`WhatSetController<E>`](../../lib/src/what/collection.dart#L147)**:
   - Manages unique sets of elements.
   - Enforces immutability by wrapping all committed data in [`Set.unmodifiable`](../../lib/src/what/_internal/_collection.dart#L76).
   - Default equality comparator: `_setEquals<E>` (checks length and member containment).
3. **[`WhatMapController<K, V>`](../../lib/src/what/collection.dart#L237)**:
   - Manages key-value dictionaries.
   - Enforces immutability by wrapping all committed data in [`Map.unmodifiable`](../../lib/src/what/_internal/_collection.dart#L97).
   - Default equality comparator: `_mapEquals<K, V>` (checks length, key existence, and value equality).

### 2.2 Mutation Modalities

All collection controllers support three distinct mutation pathways:

#### Mode 1: Immutable Replacement (`.set(data)`, `.data = data`)
Assigning a new collection directly replaces the payload. If the new collection contains identical elements according to the comparator, the push-dirty pulse is suppressed:
```dart
final listCtrl = WhatListController<int>([1, 2, 3]);

listCtrl.set([1, 2, 3]); // Zero dirty pulses emitted (shallow equality short-circuit)!
listCtrl.data = [1, 2, 4]; // Exactly 1 dirty pulse emitted.
```

#### Mode 2: Transactional Draft (`.edit((draft) => ...)`)
The `edit()` method passes an isolated mutable copy of the current data to a recipe callback:
```dart
final todoList = WhatListController<TodoItem>([]);

todoList.edit((draft) {
  draft.add(TodoItem(id: '1', title: 'Author spec'));
  draft.add(TodoItem(id: '2', title: 'Verify invariants'));
  draft.sort((a, b) => a.title.compareTo(b.title));
}); // Emits AT MOST 1 dirty pulse upon exiting the closure!
```

- **Atomic Rollback**: If an exception occurs within the `recipe` closure, the draft is discarded, the controller's existing data state remains untouched, and the exception rethrows without emitting a dirty pulse.
- **Dormant/Empty Initialization**: Calling `edit()` on an uninitialized (`.late()`) or error controller initializes the draft as an empty collection (`<T>[]`, `<E>{}`, `<K, V>{}`).

#### Mode 3: Exception-Guarded Draft (`.editGuarded((draft) => ...)`)
Catches any unhandled exceptions thrown inside the recipe, rolling back draft changes and transitioning the controller cleanly into an Error state (`setError(error, stackTrace)`):
```dart
todoList.editGuarded((draft) {
  draft.add(parseUnsafeInput()); // If this throws, controller transitions to Error state
});
```

### 2.3 Custom Equality for High-Dimensional Collections
For nested collections or custom value types, pass an explicit `equals` comparator to the constructor:
```dart
bool deepMatrixEquals(List<List<int>> a, List<List<int>> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) return false;
    }
  }
  return true;
}

final matrix = WhatListController<List<int>>(
  [[1, 2], [3, 4]],
  equals: deepMatrixEquals,
);
```

> [!WARNING]
> **Anti-Pattern Warning: In-Place Mutation of `.data`**  
> Direct mutations such as `controller.data.add(...)` or `controller.data['key'] = value` throw [`UnsupportedError`](../../lib/src/what/collection.dart#L38) because `.data` returns an unmodifiable view. Always use `edit()` or assign via `.set()`.

---

## 3. Keyed Cache Divergence: `.keyed.map()`

When mapping collections of domain models into expensive presentation objects (e.g. ViewModels, animations, stateful UI controllers), simple `map()` operations recreate every object whenever the collection updates.

The What Framework provides **Keyed Cache Mapping** via [`WhatKeyedIterableElements.map`](../../lib/src/what/elements.dart#L455), implemented by [`_KeyedMapWhat<E, K, T>`](../../lib/src/what/_internal/_elements.dart#L7).

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      Keyed Map Architecture (_KeyedMapWhat)                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   [ Source Collection: What<List<User>> ]                                       │
│   [{id: 'u1', name: 'Alice'}, {id: 'u2', name: 'Bob'}]                         │
│                               │                                                 │
│                               ▼ users.what.keyed.map(key: (u) => u.id, ...)     │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                      Keyed Node Cache Pool (_internalCache)             │   │
│   │   Key 'u1' ──► Reuses Existing Instance (Preserves local ViewModel state)│   │
│   │   Key 'u2' ──► Reuses Existing Instance (Preserves local ViewModel state)│   │
│   │   Key 'u3' ──► Evaluates convert() & Caches New Instance                │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                               │                                                 │
│                               ▼                                                 │
│   [ Yields What<List<UserViewModel>>: Stable instances across sorts & filters ] │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Internal Engine Mechanics of `_KeyedMapWhat`

[`_KeyedMapWhat<E, K, T>`](../../lib/src/what/_internal/_elements.dart#L7) extends `_StaticUnaryRelay<What<Iterable<E>>>` and maintains an internal cache:
```dart
final Map<K, T> _internalCache = {};
```

1. **Unique Key Extraction (`key: (e) => e.id`)**:
   Extracts a domain identity key $K$ for each source element.
2. **Two-Tier Cache Lookup (Hot Path vs. Cold Path)**:
   ```dart
   var cached = _internalCache[key];
   if (cached != null || _internalCache.containsKey(key)) {
     newResult.add(cached as T);
   } else {
     final converted = _convert(data);
     _internalCache[key] = converted;
     newResult.add(converted);
   }
   ```
   - **Hot Path (`cached != null`)**: 99.9% of non-null objects short-circuit with zero secondary hash lookup.
   - **Cold Path (`cached == null`)**: When mapped type `T` is nullable and `_convert()` legitimately returned `null`, `containsKey(key)` distinguishes a cached `null` from a cache miss, preventing redundant re-evaluations.
3. **Pigeonhole Principle Sweeping**:
   ```dart
   if (_internalCache.length > activeKeys.length) {
     _internalCache.removeWhere((key, _) => !activeKeys.contains(key));
   }
   ```
   Sweeping the internal cache via `removeWhere` is an $O(N)$ traversal. By comparing cache length against `activeKeys.length`, sorting, reordering, additions, and updates skip the sweep traversal entirely in $O(1)$ time.
4. **Cache Retention Across Transient Invalidation**:
   `_internalCache` is **never** cleared during standard dirty invalidations (`_performClearance()`) or when upstream enters an `hasError` state. Cached instances are retained so that once errors resolve, existing ViewModels resume seamlessly without losing state.
   The cache is reset strictly when:
   - The upstream source is explicitly empty (`source.isEmpty`).
   - An unhandled exception occurs inside `_compute()`.

### 3.2 Production Usage Example

```dart
final users = WhatListController<User>([
  User(id: 'u1', name: 'Alice'),
  User(id: 'u2', name: 'Bob'),
]);

// Mapped into stable ViewModels keyed by unique id
final userCards = users.what.keyed.map(
  key: (user) => user.id,
  convert: (user) => UserCardViewModel(user),
);

// Reordering users preserves existing UserCardViewModel instances identically
users.edit((draft) => draft.sort((a, b) => b.name.compareTo(a.name)));
// userCards.data[0] is still the exact identical instance previously created for Bob!
```

> [!WARNING]
> **Anti-Pattern Warning: Unstable Keys**  
> Using non-deterministic keys (e.g. `DateTime.now()` or `Object()`) defeats the caching mechanism, causing mapped objects to be recreated on every frame. Always use immutable, unique entity IDs.

---

## 4. Fine-Grained Element Proxies: `.elements`

The `.elements` namespace provides declarative element-wise access and collection transformations without polluting the root [`What<T>`](../../lib/src/what/what.dart) class.

All transformations computed via `.elements` defensively wrap their output collections in immutable wrappers ([`List.unmodifiable`](../../lib/src/what/elements.dart#L180), [`Set.unmodifiable`](../../lib/src/what/elements.dart#L274), [`Map.unmodifiable`](../../lib/src/what/elements.dart#L628)) to prevent external mutation leaks.

### 4.1 Available Extensions and Operators

| Extension | Target | Key Operators | Return Type |
| :--- | :--- | :--- | :--- |
| [`WhatIterableElementsExtension<E>`](../../lib/src/what/elements.dart#L40) | `What<Iterable<E>>` | `.map()`, `.where()`, `.whereType()`, `.indexed`, `.expand()`, `.reduce()`, `.fold()`, `.every()`, `.any()`, `.join()`, `.take()`, `.skip()`, `.first`, `.last`, `.single`, `.firstOrNull`, `.lastOrNull`, `.singleOrNull`, `.firstWhere()`, `.lastWhere()`, `.singleWhere()`, `.elementAt()`, `.length`, `.isEmpty`, `.isNotEmpty` | `What<List<T>>`, `What<bool>`, `What<int>`, `What<E>` |
| [`WhatListElementsExtension<E>`](../../lib/src/what/elements.dart#L98) | `What<List<E>>` | `[index]`, `.sublist()`, `.reversed`, `.indexOf()`, `.indexWhere()`, `.lastIndexWhere()`, `.lastIndexOf()`, `.asMap()`, `.cast()`, `.toUnmodifiable()` | `What<E>`, `What<List<E>>`, `What<Map<int, E>>` |
| [`WhatSetElementsExtension<E>`](../../lib/src/what/elements.dart#L121) | `What<Set<E>>` | `.lookup()`, `.union()`, `.intersection()`, `.difference()`, `.cast()`, `.toUnmodifiable()` | `What<E?>`, `What<Set<E>>` |
| [`WhatMapElementsExtension<K, V>`](../../lib/src/what/elements.dart#L145) | `What<Map<K, V>>` | `[key]`, `.containsKey()`, `.containsValue()`, `.map()`, `.where()`, `.keys`, `.values`, `.length`, `.isEmpty`, `.isNotEmpty`, `.cast()`, `.toUnmodifiable()` | `What<V?>`, `What<bool>`, `What<List<K>>`, `What<Map<K2, V2>>` |

### 4.2 LPDAG Propagation and Deduplication via `.distinct()`

In the 2-Phase LPDAG, element projections such as `users.what.elements[0]` and `config.what.elements['timeout']` are implemented as reactive computed nodes:
```dart
What<E> operator [](int index) => computed((via) => via(_what)[index]);
What<V?> operator [](K key) => computed((via) => via(_what)[key]);
```

When the upstream collection mutates (e.g. index 2 changed), the upstream node pushes a dirty signal down all its topological edges, including `elements[0]`.

To short-circuit downstream recomputations when the specific element or slice value has not changed, chain with `.distinct()`:
```dart
// 1. Observe a specific index with deduplication:
// Even if the list grows or other indices mutate,
// downstream recomputations are short-circuited as long as index 0 equals 'Alice'.
final firstUser = users.what.elements[0].distinct();

// 2. Fine-grained map key observation:
// Downstream consumers of timeoutWhat ignore mutations to 'retries' or other keys.
final timeoutWhat = config.what.elements['timeout'].distinct();
```

---

## 5. Higher-Order Reactive Collection Composition: `What<Iterable<What<T>>>`

When working with dynamic collections where each item is itself an independent reactive node (`What<T>`), the framework provides higher-order folding and aggregation operators via [`WhatIterableWhatExtension<T>`](../../lib/src/what/collection.dart#L301).

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│               Higher-Order Reactive Collection Composition                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Node A: What<int> (10)  ──┐                                                   │
│   Node B: What<int> (20)  ──┼──► What<List<What<int>>>                          │
│   Node C: What<int> (30)  ──┘           │                                       │
│                                         ├──► .combine()  ──► What<List<int>>    │
│                                         │                    ([10, 20, 30])     │
│                                         └──► .sum()      ──► What<int>          │
│                                                              (60)               │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Operators on `What<Iterable<What<T>>>`

1. **`.combine()`**:
   Unifies the data payloads of all member nodes into a single reactive `What<List<T>>`:
   ```dart
   final c1 = WhatController(1);
   final c2 = WhatController(2);
   final group = WhatListController([c1.what, c2.what]);

   final combinedWhat = group.what.combine(); // What<List<int>> holding [1, 2]
   ```
2. **`.sum()`**:
   Aggregates numeric nodes into their mathematical sum:
   ```dart
   final prices = WhatListController<What<double>>([priceA.what, priceB.what]);
   final total = prices.what.sum(); // What<double> holding current sum
   ```
3. **`.fold()` / `.reduce()`**:
   Accumulates reactive member values into a single scalar result:
   ```dart
   final flags = WhatListController([flag1.what, flag2.what]);
   final anyActive = flags.what.any((active) => active);
   ```
4. **Convenience Payload Accessors ([`WhatStateCollectionPayloadExtension`](../../lib/src/what/collection.dart#L358))**:
   Extract raw data synchronously from collections of `WhatState`:
   ```dart
   final states = <What<int>>[c1.what, c2.what];
   final values = states.data; // Iterable<int>
   final safeValues = states.dataOrNull; // Iterable<int?>
   ```

---

## 6. Core Engineering Invariants

1. **Transactional Atomicity**:  
   Regardless of the number of insertions, deletions, or sorts inside an `edit()` block, the LPDAG engine commits at most one Push-Dirty invalidation pulse.
2. **Immutable Read-Only Payloads**:  
   Pay-load getters (`.data`) on collection controllers and element projections return unmodifiable collections (`List.unmodifiable`, `Set.unmodifiable`, `Map.unmodifiable`), making accidental in-place external mutations an immediate static or runtime failure.
3. **Identity Preservation & Two-Tier Keyed Caching**:  
   `_KeyedMapWhat` preserves object identity for matching keys across collection mutations. The two-tier lookup short-circuits in $O(1)$ on the non-null hot path while cleanly caching legitimate null values.
4. **$O(1)$ Pigeonhole Principle Sweeping**:  
   Cache sweep traversals (`removeWhere`) are skipped whenever cache length does not exceed active key count, eliminating GC pressure during pure reorderings, updates, or element additions.
5. **Transient Error Resilience**:  
   Keyed caches are retained across upstream error states, allowing ViewModels and widget controllers to resume without state loss once upstream data recovers.

---

## 7. Engineering Conclusions

1. **Elimination of Rebuild Cascades**:  
   Combining transactional draft buffers with `.distinct()` element proxies prevents coarse-grained UI re-renders in large collections.
2. **Deterministic UI State Preservation**:  
   Keyed mapping (`.keyed.map()`) anchors local component state (focus, text selection, animations) to invariant domain keys rather than shifting list indices.
3. **Zero Notification Avalanches**:  
   Batch modifications in `WhatListController`, `WhatSetController`, and `WhatMapController` execute inside an isolated draft buffer and commit in a single graph pulse.
4. **Defensive Immutability by Default**:  
   Every collection returned across the reactive boundary is frozen as an unmodifiable collection, preventing mutation leaks while preserving reference sharing.
5. **Orthogonal Compositional Scalability**:  
   Whether projecting sub-slices (`.elements.sublist`), transforming elements (`.elements.map`), or aggregating higher-order reactive node collections (`.combine()`, `.sum()`), operations compose cleanly within the 2-Phase LPDAG.
