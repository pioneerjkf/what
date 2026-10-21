// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

// =============================================================================
// What State Exceptions & Diagnostic Errors
// =============================================================================

/// The base class for all recoverable runtime exceptions in the What state domain.
///
/// What establishes a clear boundary between recoverable runtime failures
/// and structural programming bugs:
///
/// * **Recoverable Failures ([WhatException])**:
///   These represent dynamic operational issues (e.g. extracting data from an error
///   or empty snapshot). These are designed to be inspected and handled gracefully,
///   with action-oriented diagnostic suggestions.
///
/// * **Structural Programmatic Bugs ([StateError])**:
///   (e.g. [LpdagReentrancyError]). These represent violations of graph construction
///   or synchronous cyclic update loops that must fail fast during development.
@pragma('flutter:keep-to-string-in-subtypes')
abstract class WhatException implements Exception {
  /// Base constant constructor for all [WhatException] instances.
  const WhatException();
}

/// Thrown when an attempt is made to extract data from an invalid snapshot state.
///
/// Reading `.data` on an empty or error snapshot throws this exception
/// to immediately pinpoint missing data or unhandled upstream errors (Fail-Fast).
///
/// ## Actionable Resolution
/// 1. Use `.dataOrNull` or `.dataOrElse(() => fallback)` to handle dormant or failed states gracefully.
/// 2. Check `.hasData` before extracting `.data`.
/// 3. Use exhaustive pattern matching via `switch (snapshot.phase)` or `switch (snapshot)`.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Unconditionally reading .data on an unverified snapshot
/// final user = userSnapshot.data; // Throws WhatSnapshotExtractionException if empty or error!
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Safe extraction with fallback or pattern matching
/// final user = userSnapshot.dataOrNull ?? User.guest();
/// ```
class WhatSnapshotExtractionException extends WhatException {
  /// Creates a [WhatSnapshotExtractionException] with diagnostic state details.
  ///
  /// * [state]: The string descriptor of the invalid state (e.g. 'Empty', 'Error').
  /// * [details]: Diagnostic description of the context where extraction failed.
  /// * [error]: Optional original error object if the snapshot was in an error state.
  /// * [stackTrace]: Optional original stack trace if the snapshot was in an error state.
  ///
  /// **Ensures:**
  /// * Returns a [WhatSnapshotExtractionException] instance.
  const WhatSnapshotExtractionException(
    this.state,
    this.details, {
    this.error,
    this.stackTrace,
  });

  /// The string descriptor of the invalid snapshot state (e.g. 'Empty', 'Error').
  final String state;

  /// Diagnostic description of where and why extraction failed.
  final String details;

  /// The original upstream error object if snapshot was in an error state.
  final Object? error;

  /// The original stack trace if snapshot was in an error state.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln(''
          '[What] Snapshot Extraction Failure: '
          'Attempted to extract payload from an invalid snapshot state ($state).')
      ..writeln(''
          'Extracting data from an Empty or Error state throws a Fail-Fast '
          'exception.')
      ..writeln(''
          'Context: $details');

    if (error != null) {
      buffer.writeln('\n======================================');
      buffer.writeln('ORIGINAL PIPELINE ERROR CAUSE:');
      buffer.writeln('$error');
      if (stackTrace != null && stackTrace != StackTrace.empty) {
        buffer.writeln('\nORIGINAL STACK TRACE:');
        buffer.writeln('$stackTrace');
      }
      buffer.writeln('======================================\n');
    }

    buffer.writeln('To resolve:');
    buffer.writeln("1. Safely handle the state using '.dataOrNull' or '.dataOrElse(() => fallback)'.");
    buffer.writeln("2. Verify the snapshot validity with '.hasData' or check '.error' if '.hasError' is true.");

    return buffer.toString();
  }
}

/// Thrown when attempting to query error or stack trace metadata from a non-error snapshot.
///
/// ## Actionable Resolution
/// Always verify `snapshot.hasError == true` before querying `.error` or `.stackTrace`.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Reading .error on a valid or empty snapshot
/// final err = snapshot.error; // Throws WhatSnapshotStateException if not in error!
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Guard before inspecting error metadata
/// if (snapshot.hasError) {
///   print('Failure: ${snapshot.error}');
/// }
/// ```
class WhatSnapshotStateException extends WhatException {
  /// Creates a [WhatSnapshotStateException] with invalid access context.
  ///
  /// * [state]: The current state of the snapshot.
  /// * [details]: Diagnostic description of the invalid access attempt.
  ///
  /// **Ensures:**
  /// * Returns a [WhatSnapshotStateException] instance.
  const WhatSnapshotStateException(this.state, this.details);

  /// The current state of the snapshot.
  final String state;

  /// Diagnostic description of the invalid access attempt.
  final String details;

  @override
  String toString() => ''
      '[What/API] Invalid State Access: Querying state metadata '
      '(error/stackTrace) from an incompatible state ($state).\n'
      'Under What type-safe snapshot contracts, error and stackTrace '
      'metadata are only guaranteed to exist on an Error state.\n'
      'Context: $details\n'
      "Ensure '.hasError' is true before inspecting error metadata.";
}
