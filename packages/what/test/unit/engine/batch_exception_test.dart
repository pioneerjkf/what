// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:test/test.dart';

class _ThrowingErrorHandler implements LpdagUncaughtErrorHandler {
  @override
  void onUncaughtError(Object error, StackTrace stackTrace, {Object? context}) {
    throw error;
  }
}

void main() {
  group('PushScope & Drain Exception Safety Tests', () {
    tearDown(() {
      LpdagUncaughtErrorHandler.instance = null;
    });

    test('1. Normal batch completes and flushes mutated state even after user action exception', () {
      final count = WhatController<int>(0);
      int invalidationCalls = 0;

      final terminal = RawWhatTerminal(count.what, onInvalidated: () {
        invalidationCalls++;
      });
      terminal.activate();

      expect(invalidationCalls, 0);

      // In What design, if an action mutates state but throws,
      // the mutation is preserved and terminal flushes to prevent desynchronization
      expect(() {
        batch(() {
          count.data = 42;
          throw StateError('Action failed');
        });
      }, throwsA(isA<StateError>()));

      expect(count.data, 42);
      expect(invalidationCalls, 1);

      terminal.deactivate();
    });

    test('2. Uncaught error escaping _drain during batch purges remaining queues and prevents zombie nodes', () {
      final b = WhatController<int>(0);

      int bInvalidations = 0;
      final terminalB = RawWhatTerminal(b.what, onInvalidated: () {
        bInvalidations++;
      });
      terminalB.activate();

      // Configure handler to throw synchronously so unhandled error escapes _drain
      LpdagUncaughtErrorHandler.instance = _ThrowingErrorHandler();

      // Simulate an unhandled exception escaping _drain during a batch
      expect(() {
        runZoned(
          () {
            batch(() {
              b.data = 1; // terminalB queued
              // Force an uncaught exception
              LpdagUncaughtErrorHandler.instance?.onUncaughtError(
                StateError('Uncaught error escaping drain'),
                StackTrace.current,
              );
            });
          },
          zoneSpecification: ZoneSpecification(
            handleUncaughtError: (self, parent, zone, error, stackTrace) => throw error,
          ),
        );
      }, throwsA(isA<StateError>()));

      // Prior to the fix, b._isPushQueued would be leaked as true because
      // !_BatchScope._batchLock was false in _drain's finally block.
      // After the fix, !completed purges queues unconditionally.
      b.data = 2;
      expect(bInvalidations, 2);

      terminalB.deactivate();
    });
  });
}
