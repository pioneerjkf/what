// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:what/what.dart';

// =============================================================================
// Reactive Numeric Collection Extensions
// =============================================================================

/// Reactive numeric aggregations and reduction extensions on [WhatIterableElements].
///
/// **Design Philosophy (Type-Preserving Numeric Reductions):**
/// Extends numeric collections with high-efficiency arithmetic operations ([sum], [average], [min], [max]).
/// Calculations evaluate lazily on-demand when downstream consumers pull values.
///
/// **Data Propagation Flow:**
/// ```text
/// [Source What<Iterable<num>>]
///        │ (Push-Dirty)
///        ▼
/// [Numeric Aggregation Pipeline]
///        ├─► .sum     ──► Arithmetic Sum What<E>
///        ├─► .average ──► Arithmetic Mean What<double>
///        ├─► .min     ──► Smallest value What<E>
///        └─► .max     ──► Largest value What<E>
/// ```
///
/// **Example:**
/// ```dart
/// final scores = what<List<int>>([85, 92, 78]);
/// final totalScore = scores.elements.sum;
/// final avgScore = scores.elements.average;
///
/// print('Total: ${totalScore.data}'); // 255
/// print('Avg: ${avgScore.data}');     // 85.0
/// ```
extension NumericWhatElementsExtension<E extends num>
    on WhatIterableElements<E> {
  /// Returns the minimum element in this collection, or `null` if empty.
  ///
  /// **Ensures:**
  /// * Evaluates to `null` when the source collection is empty.
  What<E?> get minOrNull => computed((via) => via(what).minOrNull as E?);

  /// Returns the minimum element in this collection, or throws [StateError] if empty.
  ///
  /// **Requires:**
  /// * The collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<E> get min => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.min as E;
      });

  /// Returns the maximum element in this collection, or `null` if empty.
  ///
  /// **Ensures:**
  /// * Evaluates to `null` when the source collection is empty.
  What<E?> get maxOrNull => computed((via) => via(what).maxOrNull as E?);

  /// Returns the maximum element in this collection, or throws [StateError] if empty.
  ///
  /// **Requires:**
  /// * The collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<E> get max => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.max as E;
      });

  /// Returns the sum of all elements in this collection reactively.
  ///
  /// **Ensures:**
  /// * Returns `0` or `0.0` when the collection is empty.
  What<E> get sum => computed((via) {
        final val = via(what).sum;
        if (val is E) return val;
        if (E == double) return val.toDouble() as E;
        return val.toInt() as E;
      });

  /// Returns the arithmetic average of all elements in this collection reactively.
  ///
  /// **Requires:**
  /// * The collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<double> get average => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.average;
      });
}

/// Reactive integer collection aggregations and reductions.
extension IntegerWhatElementsExtension on WhatIterableElements<int> {
  /// Returns the minimum integer in this collection, or `null` if empty.
  ///
  /// **Ensures:**
  /// * Evaluates to `null` when the source collection is empty.
  What<int?> get minOrNull => computed((via) => via(what).minOrNull);

  /// Returns the minimum integer in this collection, or throws [StateError] if empty.
  ///
  /// **Requires:**
  /// * The collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<int> get min => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.min;
      });

  /// Returns the maximum integer in this collection, or `null` if empty.
  ///
  /// **Ensures:**
  /// * Evaluates to `null` when the source collection is empty.
  What<int?> get maxOrNull => computed((via) => via(what).maxOrNull);

  /// Returns the maximum integer in this collection, or throws [StateError] if empty.
  ///
  /// **Requires:**
  /// * The collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<int> get max => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.max;
      });

  /// Returns the sum of all integers in this collection reactively.
  ///
  /// **Ensures:**
  /// * Returns `0` when the collection is empty.
  What<int> get sum => computed((via) => via(what).sum);

  /// Returns the arithmetic average of all integers in this collection reactively.
  ///
  /// **Requires:**
  /// * The collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<double> get average => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.average;
      });
}

/// Reactive floating-point collection aggregations and reductions.
extension DoubleWhatElementsExtension on WhatIterableElements<double> {
  /// Returns the minimum double in this collection, or `null` if empty.
  ///
  /// **Ensures:**
  /// * Evaluates to `null` when the source collection is empty.
  What<double?> get minOrNull => computed((via) => via(what).minOrNull);

  /// Returns the minimum double in this collection, or throws [StateError] if empty.
  ///
  /// **Requires:**
  /// * The collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<double> get min => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.min;
      });

  /// Returns the maximum double in this collection, or `null` if empty.
  ///
  /// **Ensures:**
  /// * Evaluates to `null` when the source collection is empty.
  What<double?> get maxOrNull => computed((via) => via(what).maxOrNull);

  /// Returns the maximum double in this collection, or throws [StateError] if empty.
  ///
  /// **Requires:**
  /// * The collection MUST NOT be empty.
  ///
  /// **Throws:**
  /// * [StateError] if the collection is empty upon evaluation.
  What<double> get max => computed((via) {
        final source = via(what);
        if (source.isEmpty) throw StateError('No element');
        return source.max;
      });

  /// Returns the sum of all doubles in this collection reactively.
  ///
  /// **Ensures:**
  /// * Returns `0.0` when the collection is empty.
  What<double> get sum => computed((via) => via(what).sum);
}
