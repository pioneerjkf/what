// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

/// Dispatches an uncaught error to the global [LpdagUncaughtErrorHandler] (if registered)
/// and delegates to [Zone.handleUncaughtError].
@pragma('vm:prefer-inline')
void _dispatchUncaughtError(Object error, StackTrace stackTrace, {Object? context}) {
  final handler = LpdagUncaughtErrorHandler.instance;
  if (handler != null) {
    try {
      handler.onUncaughtError(error, stackTrace, context: context);
    } catch (handlerError, handlerStack) {
      Zone.current.handleUncaughtError(handlerError, handlerStack);
    }
  }

  Zone.current.handleUncaughtError(error, stackTrace);
}
