// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// What Immutable Point-In-Time Snapshot
// =============================================================================

/// An immutable, atomic container that encapsulates the precise state and data of a
/// [What] node at a specific point in time.
///
/// In the What framework, data never flows as raw values; it is always strictly packaged
/// inside a [WhatSnapshot]. This guarantees absolute state determinism across the
/// topological graph. A snapshot exists in exactly one of three mutually exclusive states:
/// - **Valid ([hasData])**: Contains safely resolvable data (even if that data is `null`).
/// - **Empty ([isEmpty])**: Represents a state where data has not yet been provided or has been cleared.
/// - **Error ([hasError])**: Contains an error and an optional stack trace resulting from a failed computation.
///
/// ## State Transition Flow
/// ```text
/// ┌───────────────────────────────────────────────────────────┐
/// │                      WhatSnapshot<T>                      │
/// ├───────────────────┬───────────────────┬───────────────────┤
/// │  Valid (hasData)  │  Empty (isEmpty)  │ Error (hasError)  │
/// ├───────────────────┬───────────────────┬───────────────────┤
/// │ • Holds T payload │ • No data yet     │ • Holds error &   │
/// │ • .data is safe   │ • .data throws    │   stackTrace      │
/// │ • null is valid   │ • .dataOrNull -> Ø│ • .data throws    │
/// └───────────────────────────────────────────────────────────┘
/// ```
///
/// ## Pipeline-Level Null Safety
/// This class elevates **Dart's Sound Null Safety philosophy** to the pipeline level.
/// In a [WhatSnapshot], **`null` is NEVER treated as a missing state.** Instead, `null`
/// is respected as a perfectly valid, explicit data payload (e.g., `WhatSnapshot<String?>(null)`).
/// The concept of "no data" is completely segregated into its own dedicated type ([WhatSnapshot.empty]).
///
/// **Warning (Anti-Pattern Prevention):**
/// - **DO NOT** directly read `.data` when [hasData] is `false`. Accessing `.data` on
///   an empty or error snapshot triggers a **Fail-Fast** [WhatSnapshotExtractionException].
/// - Always inspect state using pattern matching or defensively extract via [dataOrNull] / [dataOrElse].
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Directly accessing .data on snapshot without state check
/// final name = snapshot.data; // Throws WhatSnapshotExtractionException if empty or error!
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Safe extraction with fallback or pattern matching
/// final name = snapshot.dataOrNull ?? 'Guest';
/// // Or exhaustive pattern matching:
/// final message = switch (snapshot) {
///   WhatSnapshot(hasData: true, data: final val) => 'Value: $val',
///   WhatSnapshot(isEmpty: true) => 'No data available',
///   WhatSnapshot(hasError: true, error: final err) => 'Failed: $err',
/// };
/// ```
@immutable
sealed class WhatSnapshot<T> implements WhatState<T> {
  /// Creates an immutable valid snapshot carrying the given [data] payload.
  ///
  /// Note that `null` is a valid payload for nullable types (`T?`) and does not
  /// indicate an empty state.
  ///
  /// * [data]: The valid payload value of type [T].
  ///
  /// **Ensures:**
  /// * Returns a [WhatSnapshot] where [hasData] is `true`, [isEmpty] is `false`, and [hasError] is `false`.
  ///
  /// ## Examples
  /// ```dart
  /// const snapshot = WhatSnapshot<int>(42);
  /// print(snapshot.data); // 42
  /// ```
  const factory WhatSnapshot(T data) = _ValidWhatSnapshot;

  /// Creates an immutable error snapshot storing [error] and optional [stackTrace].
  ///
  /// * [error]: The caught failure or exception object.
  /// * [stackTrace]: Optional stack trace associated with the failure.
  ///
  /// **Ensures:**
  /// * Returns a [WhatSnapshot] where [hasError] is `true`, [hasData] is `false`, and [isEmpty] is `false`.
  ///
  /// ## Examples
  /// ```dart
  /// final errorSnapshot = WhatSnapshot<int>.error(FormatException('Invalid number'));
  /// print(errorSnapshot.hasError); // true
  /// ```
  const factory WhatSnapshot.error(Object error, [StackTrace? stackTrace]) = _ErrorWhatSnapshot<T>;

  /// Creates an immutable uninitialized (empty) snapshot with an optional [emptyReason].
  ///
  /// * [emptyReason]: Optional descriptive explanation of why the state is currently dormant or awaiting prerequisites.
  ///
  /// **Ensures:**
  /// * Returns a [WhatSnapshot] where [isEmpty] is `true`, [hasData] is `false`, and [hasError] is `false`.
  ///
  /// ## Examples
  /// ```dart
  /// const emptySnapshot = WhatSnapshot<String>.empty('AwaitingNetworkResponse');
  /// print(emptySnapshot.emptyReason); // 'AwaitingNetworkResponse'
  /// ```
  const factory WhatSnapshot.empty([Object? emptyReason]) = _EmptyWhatSnapshot<T>;

  /// Extracts the underlying data synchronously from this snapshot.
  ///
  /// **Requires:**
  /// * The snapshot must be in a [hasData] state.
  ///
  /// **Ensures:**
  /// * Returns the data payload of type [T].
  ///
  /// **Throws:**
  /// * [WhatSnapshotExtractionException] if [hasData] is `false` (i.e. [isEmpty] or [hasError] is `true`).
  ///
  /// **BAD:**
  /// ```dart
  /// // [Anti-Pattern] Calling .data unconditionally on an unverified snapshot
  /// final val = snapshot.data; // Throws if empty or error
  /// ```
  ///
  /// **GOOD:**
  /// ```dart
  /// // [Recommended] Guard with hasData or use dataOrNull / dataOrElse
  /// if (snapshot.hasData) {
  ///   final val = snapshot.data;
  ///   print('Data: $val');
  /// }
  /// ```
  @override
  T get data;

  /// Safely extracts the underlying data, returning `null` if the snapshot is not in a valid state.
  ///
  /// **Ensures:**
  /// * Returns `null` if [hasData] is `false`.
  /// * Otherwise, returns the data payload of type [T].
  ///
  /// ## Examples
  /// ```dart
  /// final value = snapshot.dataOrNull;
  /// if (value != null) {
  ///   print('Received value: $value');
  /// }
  /// ```
  @override
  T? get dataOrNull;

  /// Safely extracts the underlying data, returning the result of [fallback] if not in a valid state.
  ///
  /// * [fallback]: Callback producing a fallback value when the snapshot is empty or holds an error.
  ///
  /// **Ensures:**
  /// * Returns the underlying data if [hasData] is `true`.
  /// * Otherwise, invokes and returns the result of [fallback].
  ///
  /// ## Examples
  /// ```dart
  /// final value = snapshot.dataOrElse(() => 100);
  /// ```
  @override
  T dataOrElse(T Function() fallback);

  /// Whether this snapshot contains a valid, extractable data payload.
  ///
  /// **Ensures:**
  /// * Returns `true` if the snapshot holds a valid data payload (including `null` for nullable types).
  /// * Returns `false` if uninitialized ([isEmpty]) or corrupted ([hasError]).
  @override
  bool get hasData;

  /// Whether this snapshot is in an uninitialized or dormant state.
  ///
  /// **Ensures:**
  /// * Returns `true` if this snapshot was created via [WhatSnapshot.empty].
  /// * Returns `false` otherwise.
  @override
  bool get isEmpty;

  /// The optional reason explaining why this snapshot is empty, or `null` if unspecified or not empty.
  @override
  Object? get emptyReason;

  /// Whether this snapshot is in a corrupted state containing an error or exception.
  ///
  /// **Ensures:**
  /// * Returns `true` if this snapshot was created via [WhatSnapshot.error].
  /// * Returns `false` otherwise.
  @override
  bool get hasError;

  /// Extracts the underlying exception or failure object from an error snapshot.
  ///
  /// **Requires:**
  /// * Must only be called when [hasError] is `true`.
  ///
  /// **Throws:**
  /// * [WhatSnapshotStateException] if [hasError] is `false`.
  @override
  Object get error;

  /// Extracts the call stack trace at the point of failure from an error snapshot.
  ///
  /// **Requires:**
  /// * Must only be called when [hasError] is `true`.
  ///
  /// **Throws:**
  /// * [WhatSnapshotStateException] if [hasError] is `false`.
  @override
  StackTrace get stackTrace;

  /// Determines if this snapshot is equivalent to [other] by comparing their validity
  /// and underlying payloads using an optional custom [equals] comparator.
  ///
  /// * [other]: The secondary state entity to compare against.
  /// * [equals]: Optional custom equality comparator for comparing payload values.
  ///
  /// **Ensures:**
  /// * Returns `true` if both snapshots hold equivalent state validity and matching payloads.
  @override
  bool equals(covariant WhatState<T> other, [bool Function(T previous, T next)? equals]);
}
