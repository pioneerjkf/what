// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Collection Shallow Equality Utilities
// =============================================================================

@pragma('vm:prefer-inline')
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final ai = a[i];
    final bi = b[i];
    if (!identical(ai, bi) && ai != bi) return false;
  }
  return true;
}

@pragma('vm:prefer-inline')
bool _setEquals<E>(Set<E> a, Set<E> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final element in a) {
    if (!b.contains(element)) return false;
  }
  return true;
}

@pragma('vm:prefer-inline')
bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final key = entry.key;
    if (!b.containsKey(key)) return false;
    final aVal = entry.value;
    final bVal = b[key];
    if (!identical(aVal, bVal) && aVal != bVal) return false;
  }
  return true;
}

// =============================================================================
// Collection Entry Nodes (List, Set, Map)
// =============================================================================

final class _ListEntry<T> extends _DistinctEntry<List<T>> {
  _ListEntry(
    Iterable<T> data, {
    bool Function(List<T> previous, List<T> next)? equals,
  }) : super(List<T>.unmodifiable(data), equals: equals ?? _listEquals);

  _ListEntry.late({bool Function(List<T> previous, List<T> next)? equals}) : super.late(equals: equals ?? _listEquals);

  _ListEntry.error(
    super.error, {
    super.stackTrace,
    bool Function(List<T> previous, List<T> next)? equals,
  }) : super.error(equals: equals ?? _listEquals);

  @override
  @pragma('vm:prefer-inline')
  void set(List<T> data) {
    super.set(List<T>.unmodifiable(data));
  }
}

final class _SetEntry<E> extends _DistinctEntry<Set<E>> {
  _SetEntry(
    Iterable<E> data, {
    bool Function(Set<E> previous, Set<E> next)? equals,
  }) : super(Set<E>.unmodifiable(data), equals: equals ?? _setEquals);

  _SetEntry.late({bool Function(Set<E> previous, Set<E> next)? equals}) : super.late(equals: equals ?? _setEquals);

  _SetEntry.error(
    super.error, {
    super.stackTrace,
    bool Function(Set<E> previous, Set<E> next)? equals,
  }) : super.error(equals: equals ?? _setEquals);

  @override
  @pragma('vm:prefer-inline')
  void set(Set<E> data) {
    super.set(Set<E>.unmodifiable(data));
  }
}

final class _MapEntry<K, V> extends _DistinctEntry<Map<K, V>> {
  _MapEntry(
    Map<K, V> data, {
    bool Function(Map<K, V> previous, Map<K, V> next)? equals,
  }) : super(Map<K, V>.unmodifiable(data), equals: equals ?? _mapEquals);

  _MapEntry.late({bool Function(Map<K, V> previous, Map<K, V> next)? equals})
      : super.late(equals: equals ?? _mapEquals);

  _MapEntry.error(
    super.error, {
    super.stackTrace,
    bool Function(Map<K, V> previous, Map<K, V> next)? equals,
  }) : super.error(equals: equals ?? _mapEquals);

  @override
  @pragma('vm:prefer-inline')
  void set(Map<K, V> data) {
    super.set(Map<K, V>.unmodifiable(data));
  }
}

// =============================================================================
// Collection Controller Implementations (List, Set, Map)
// =============================================================================

final class _WhatListControllerImpl<T> extends _WhatControllerImpl<List<T>> implements WhatListController<T> {
  _WhatListControllerImpl(
    Iterable<T> data, {
    bool Function(List<T> previous, List<T> next)? equals,
  }) : super._(_ListEntry<T>(data, equals: equals));

  _WhatListControllerImpl.late({
    bool Function(List<T> previous, List<T> next)? equals,
  }) : super._(_ListEntry<T>.late(equals: equals));

  _WhatListControllerImpl.error(
    Object error, {
    StackTrace? stackTrace,
    bool Function(List<T> previous, List<T> next)? equals,
  }) : super._(_ListEntry<T>.error(error, stackTrace: stackTrace, equals: equals));

  @override
  @pragma('vm:prefer-inline')
  void edit(void Function(List<T> draft) recipe) {
    final draft = hasData ? List<T>.of(data) : <T>[];
    recipe(draft);
    set(draft);
  }

  @override
  @pragma('vm:prefer-inline')
  void editGuarded(void Function(List<T> draft) recipe) {
    try {
      edit(recipe);
    } catch (error, stackTrace) {
      setError(error, stackTrace);
    }
  }

  @override
  What<List<T>> get what => _target;
}

final class _WhatSetControllerImpl<E> extends _WhatControllerImpl<Set<E>> implements WhatSetController<E> {
  _WhatSetControllerImpl(
    Iterable<E> data, {
    bool Function(Set<E> previous, Set<E> next)? equals,
  }) : super._(_SetEntry<E>(data, equals: equals));

  _WhatSetControllerImpl.late({
    bool Function(Set<E> previous, Set<E> next)? equals,
  }) : super._(_SetEntry<E>.late(equals: equals));

  _WhatSetControllerImpl.error(
    Object error, {
    StackTrace? stackTrace,
    bool Function(Set<E> previous, Set<E> next)? equals,
  }) : super._(_SetEntry<E>.error(error, stackTrace: stackTrace, equals: equals));

  @override
  @pragma('vm:prefer-inline')
  void edit(void Function(Set<E> draft) recipe) {
    final draft = hasData ? Set<E>.of(data) : <E>{};
    recipe(draft);
    set(draft);
  }

  @override
  @pragma('vm:prefer-inline')
  void editGuarded(void Function(Set<E> draft) recipe) {
    try {
      edit(recipe);
    } catch (error, stackTrace) {
      setError(error, stackTrace);
    }
  }

  @override
  What<Set<E>> get what => _target;
}

final class _WhatMapControllerImpl<K, V> extends _WhatControllerImpl<Map<K, V>> implements WhatMapController<K, V> {
  _WhatMapControllerImpl(
    Map<K, V> data, {
    bool Function(Map<K, V> previous, Map<K, V> next)? equals,
  }) : super._(_MapEntry<K, V>(data, equals: equals));

  _WhatMapControllerImpl.late({
    bool Function(Map<K, V> previous, Map<K, V> next)? equals,
  }) : super._(_MapEntry<K, V>.late(equals: equals));

  _WhatMapControllerImpl.error(
    Object error, {
    StackTrace? stackTrace,
    bool Function(Map<K, V> previous, Map<K, V> next)? equals,
  }) : super._(_MapEntry<K, V>.error(error, stackTrace: stackTrace, equals: equals));

  @override
  @pragma('vm:prefer-inline')
  void edit(void Function(Map<K, V> draft) recipe) {
    final draft = hasData ? Map<K, V>.of(data) : <K, V>{};
    recipe(draft);
    set(draft);
  }

  @override
  @pragma('vm:prefer-inline')
  void editGuarded(void Function(Map<K, V> draft) recipe) {
    try {
      edit(recipe);
    } catch (error, stackTrace) {
      setError(error, stackTrace);
    }
  }

  @override
  What<Map<K, V>> get what => _target;
}
