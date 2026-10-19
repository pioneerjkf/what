// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

final class _KeyedMapWhat<E, K, T> extends _StaticUnaryRelay<What<Iterable<E>>>
    with _WhatStateMixin<List<T>>, _WhatPeekMixin<List<T>>, _PullResolver<List<T>>, _PullRelay<List<T>>
    implements What<List<T>> {
  _KeyedMapWhat(
    super.inbound, {
    required K Function(E data) key,
    required T Function(E data) convert,
  })  : _keySelector = key,
        _convert = convert;

  final K Function(E data) _keySelector;

  final T Function(E data) _convert;

  /// Internal map caching converted values [T] indexed by key [K].
  ///
  /// ### Cache Retention & Lifecycle:
  /// - **Do NOT clear on dirty marking or when source has error**:
  ///   When [_source] emits dirty notifications, node state is invalidated.
  ///   Clearing `_internalCache` on invalidation would defeat the caching purpose of
  ///   `keyed.map`, causing re-evaluation of `_convert` for existing keys.
  /// - **Explicit Reset**: Cleared when [_source] is empty (`_source.isEmpty`) or when
  ///   an unhandled computation exception occurs inside [_compute].
  /// - **Garbage Sweeping**: Inactive keys are removed via [Map.removeWhere] when cache
  ///   length exceeds active keys (Pigeonhole Principle).
  final Map<K, T> _internalCache = {};

  @override
  @pragma('vm:prefer-inline')
  _WhatState<List<T>> _pull() {
    _version++;
    return _state = _compute();
  }

  _WhatState<List<T>> _compute() {
    try {
      final source = _source._read();
      if (source.isEmpty) {
        _internalCache.clear();
        return const _EmptyWhatState();
      } else if (source.hasError) {
        return _ErrorWhatState(source.error, source.stackTrace);
      } else {
        final newResult = <T>[];
        final activeKeys = <K>{};

        try {
          for (final data in source.data) {
            final key = _keySelector(data);
            activeKeys.add(key);
            var cached = _internalCache[key];
            // Architectural Invariant (Null Value Caching & Short-Circuit Performance):
            // 1. Hot Path (cached != null): 99.9% non-null values immediately short-circuit with 0 extra lookup.
            // 2. Cold Path (cached == null): When T is nullable and _convert() returned null,
            //    containsKey(key) distinguishes an explicitly cached null value from a true cache miss,
            //    preventing redundant re-execution of _convert(). DO NOT remove containsKey(key).
            if (cached != null || _internalCache.containsKey(key)) {
              newResult.add(cached as T);
            } else {
              final converted = _convert(data);
              _internalCache[key] = converted;
              newResult.add(converted);
            }
          }
        } catch (error, stackTrace) {
          _internalCache.clear();
          return _ErrorWhatState(error, stackTrace);
        }

        // Optimization: Sweeping the internal cache via removeWhere is an O(N) operation.
        // By checking if the cache size exceeds activeKeys.length (Pigeonhole Principle),
        // we skip the full map traversal in O(1) when no keys have been removed.
        if (_internalCache.length > activeKeys.length) {
          _internalCache.removeWhere((key, _) => !activeKeys.contains(key));
        }

        final unmodifiable = List<T>.unmodifiable(newResult);
        final current = _state;
        if (current case final _ValidWhatState<List<T>> s) {
          s.update(unmodifiable);
          return s;
        }
        return _ValidWhatState<List<T>>(unmodifiable);
      }
    } catch (error, stackTrace) {
      return _ErrorWhatState(error, stackTrace);
    }
  }
}
