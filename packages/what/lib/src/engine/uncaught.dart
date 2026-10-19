// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../framework.dart';

/// Global handler interface for capturing unhandled LPDAG engine exceptions.
///
/// Implement this interface and attach it to [LpdagUncaughtErrorHandler.instance]
/// to receive telemetry on engine-level uncaught exceptions without hot-path overhead.
///
/// In the LPDAG reactive engine, when an unhandled exception escapes a reactive node,
/// terminal callback, or lifecycle hook, the engine dispatches it through this handler
/// before delegating to the ambient [Zone].
///
/// ## System Architectural Flow
/// ```text
/// [Unhandled Exception in Node / Terminal]
///                    │
///                    ▼
///          _dispatchUncaughtError()
///                    │
///        ┌───────────┴───────────────────────────┐
///        ▼                                       ▼
/// [LpdagUncaughtErrorHandler]         [Zone.current.handleUncaughtError]
/// (instance.onUncaughtError)          (Root zone fallback dispatch)
/// ```
///
/// ## Architectural Benefits
/// 1. **Zero Hot-Path Overhead**: Handlers are queried only when an actual error escapes.
/// 2. **Context-Aware Diagnostics**: Supplies the originating node or terminal instance via `context`.
/// 3. **Fail-Safe Fallback**: Always delegates to [Zone.handleUncaughtError] so errors
///    are never silently suppressed.
///
/// ## Examples
/// ```dart
/// class MyTelemetryHandler implements LpdagUncaughtErrorHandler {
///   @override
///   void onUncaughtError(Object error, StackTrace stackTrace, {Object? context}) {
///     print('Engine error from $context: $error');
///     // Forward to Crashlytics / Sentry / telemetry logger
///   }
/// }
///
/// void main() {
///   LpdagUncaughtErrorHandler.instance = MyTelemetryHandler();
///   // Run application...
/// }
/// ```
abstract interface class LpdagUncaughtErrorHandler {
  /// Global active error handler instance. Set to `null` to disable observation.
  ///
  /// **Ensures:**
  /// * When non-null, receives all engine-level uncaught exception dispatches.
  static LpdagUncaughtErrorHandler? instance;

  /// Invoked when an uncaught error escapes a reactive node or terminal boundary.
  ///
  /// * [error]: The uncaught error or exception object.
  /// * [stackTrace]: Associated stack trace of the failure.
  /// * [context]: The originating reactive node or terminal instance, if available.
  ///
  /// **Requires:**
  /// * Implementation should avoid throwing new exceptions. Any exception thrown inside
  ///   this callback is caught and forwarded to [Zone.handleUncaughtError].
  void onUncaughtError(Object error, StackTrace stackTrace, {Object? context});
}
