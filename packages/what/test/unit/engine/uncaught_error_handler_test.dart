// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:test/test.dart';
import 'package:what/what.dart';

final class _TestErrorHandler implements LpdagUncaughtErrorHandler {
  final List<(Object error, StackTrace stackTrace, Object? context)> captured = [];

  @override
  void onUncaughtError(Object error, StackTrace stackTrace, {Object? context}) {
    captured.add((error, stackTrace, context));
  }
}

final class _ThrowingErrorHandler implements LpdagUncaughtErrorHandler {
  @override
  void onUncaughtError(Object error, StackTrace stackTrace, {Object? context}) {
    throw StateError('Handler internal failure');
  }
}

void main() {
  tearDown(() {
    LpdagUncaughtErrorHandler.instance = null;
  });

  group('LpdagUncaughtErrorHandler Suite', () {
    test('1. Captures orphan node uncaught error with context', () {
      final handler = _TestErrorHandler();
      LpdagUncaughtErrorHandler.instance = handler;

      final comp = What.managed<int>(
        create: (via) => 42,
        dispose: (value) {
          throw Exception('Dispose Exception in Orphan Node');
        },
      );

      final zoneErrors = <Object>[];
      runZonedGuarded(() {
        final t = RawWhatTerminal<int>(comp, onInvalidated: () {});
        t.activate();
        expect(untracked(comp), 42);
        // Deactivate removes all terminals; comp becomes an orphan node on dispose.
        t.deactivate();
      }, (e, s) {
        zoneErrors.add(e);
      });

      expect(handler.captured, hasLength(1));
      final (error, _, context) = handler.captured.first;
      expect(error.toString(), contains('Dispose Exception in Orphan Node'));
      expect(context, isNotNull);
      expect(zoneErrors, isEmpty, reason: 'Early return prevents double reporting to Zone');
    });

    test('2. Captures terminal unhandled error without double reporting to Zone', () {
      final handler = _TestErrorHandler();
      LpdagUncaughtErrorHandler.instance = handler;

      final ctrl = WhatController(0);
      final terminal = RawWhatTerminal<int>(
        ctrl.what,
        onInvalidated: () {
          throw StateError('Terminal Invalidation Error');
        },
      );
      terminal.activate();

      final zoneErrors = <Object>[];
      runZonedGuarded(() {
        ctrl.set(1);
      }, (e, s) {
        zoneErrors.add(e);
      });

      expect(handler.captured, hasLength(1));
      final (error, _, context) = handler.captured.first;
      expect(error, isA<StateError>());
      expect(context, same(terminal));
      expect(zoneErrors, isEmpty, reason: 'Early return prevents double reporting to Zone');

      terminal.deactivate();
    });

    test('3. Captures fatal secondary error when terminal onUncaughtError throws', () {
      final handler = _TestErrorHandler();
      LpdagUncaughtErrorHandler.instance = handler;

      final ctrl = WhatController(0);
      final terminal = RawWhatTerminal<int>(
        ctrl.what,
        onInvalidated: () {
          throw StateError('Primary Error');
        },
        onUncaughtError: (e, s) {
          throw StateError('Secondary Fatal Error');
        },
      );
      terminal.activate();

      final zoneErrors = <Object>[];
      runZonedGuarded(() {
        ctrl.set(1);
      }, (e, s) {
        zoneErrors.add(e);
      });

      // Both primary and secondary fatal errors must be dispatched
      expect(handler.captured, hasLength(2));
      expect((handler.captured[0].$1 as StateError).message, 'Primary Error');
      expect((handler.captured[1].$1 as StateError).message, 'Secondary Fatal Error');
      expect(zoneErrors, isEmpty, reason: 'Handled errors are not forwarded to Zone');

      terminal.deactivate();
    });

    test('4. Gracefully handles throwing LpdagUncaughtErrorHandler without crashing execution', () {
      LpdagUncaughtErrorHandler.instance = _ThrowingErrorHandler();

      final ctrl = WhatController(0);
      final terminal = RawWhatTerminal<int>(
        ctrl.what,
        onInvalidated: () {
          throw StateError('Original Error');
        },
      );
      terminal.activate();

      final zoneErrors = <Object>[];
      runZonedGuarded(() {
        ctrl.set(1);
      }, (e, s) {
        zoneErrors.add(e);
      });

      // Both handler error and original error reach the Zone safely
      expect(zoneErrors.any((e) => e.toString().contains('Handler internal failure')), isTrue);
      expect(zoneErrors.any((e) => e.toString().contains('Original Error')), isTrue);

      terminal.deactivate();
    });

    test('5. Dispatches directly to Zone when handler is not registered', () {
      LpdagUncaughtErrorHandler.instance = null;

      final ctrl = WhatController(0);
      final terminal = RawWhatTerminal<int>(
        ctrl.what,
        onInvalidated: () {
          throw StateError('Direct Zone Error');
        },
      );
      terminal.activate();

      final zoneErrors = <Object>[];
      runZonedGuarded(() {
        ctrl.set(1);
      }, (e, s) {
        zoneErrors.add(e);
      });

      expect(zoneErrors, hasLength(1));
      expect((zoneErrors.first as StateError).message, 'Direct Zone Error');

      terminal.deactivate();
    });
  });
}
