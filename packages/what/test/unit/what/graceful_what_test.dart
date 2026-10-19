// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('GracefulWhat & WhatGracefulExtension Comprehensive Unit Tests', () {
    test('1. Passthrough data read and dirty notification', () {
      final controller = WhatController<int>(10);
      final gracefulWhat = controller.what.graceful();

      expect(gracefulWhat.peek, 10);
      expect(gracefulWhat.peekState.hasData, isTrue);
      expect(gracefulWhat, isA<What<int>>());

      int observed = 0;
      final terminal = RawWhatTerminal(
        gracefulWhat,
        onInvalidated: () {
          observed = gracefulWhat.peek;
        },
      );
      terminal.activate();

      expect(terminal.data, 10);

      controller.set(42);
      expect(observed, 42);
      expect(terminal.data, 42);

      terminal.deactivate();
    });

    test('2. Retains upstream active state during grace period when terminal deactivates', () async {
      int createCount = 0;
      int disposeCount = 0;

      // Upstream resource with strict zero-drop dormancy tracking
      final res = managed<String>(
        create: (_) {
          createCount++;
          return 'Managed-$createCount';
        },
        dispose: (_) {
          disposeCount++;
        },
      );

      // Wrap standard resource with GracefulWhat via graceful(duration) functor
      final gracefulWhat = res.graceful(graceful(const Duration(milliseconds: 80)));

      final t1 = RawWhatTerminal(gracefulWhat, onInvalidated: () {});
      final t2 = RawWhatTerminal(gracefulWhat, onInvalidated: () {});

      t1.activate();
      expect(createCount, 0);
      expect(t1.data, 'Managed-1');
      expect(createCount, 1);
      expect(disposeCount, 0);

      // t1 departs: GracefulWhat drops to 0 subscribers and enters mooring harbor
      t1.deactivate();
      expect(disposeCount, 0); // Upstream is NOT disposed!

      // Wait 30ms (< 80ms)
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(disposeCount, 0);

      // Early return: t2 attaches before grace period expires
      t2.activate();
      expect(createCount, 1); // Not recreated
      expect(disposeCount, 0);
      expect(t2.data, 'Managed-1');

      // Wait past original 80ms
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(disposeCount, 0); // Grace timer was cancelled upon early return

      // Now t2 deactivates
      t2.deactivate();
      expect(disposeCount, 0);

      // Wait past the new grace period expiration
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(disposeCount, 1); // Cleanly disposed after grace period elapsed!
    });

    test('3. Default graceful() uses 5-minute mooring period', () {
      final res = WhatController<int>(100);
      final defaultGraceful = res.what.graceful();

      expect(defaultGraceful, isA<What<int>>());
      expect(defaultGraceful.peek, 100);
    });

    test('4. graceful(graceful.microtask) microtask deferral policy', () async {
      int disposeCount = 0;
      final res = managed<int>(
        create: (_) => 999,
        dispose: (_) => disposeCount++,
      );

      final microtaskWhat = res.graceful(graceful.microtask);

      final t = RawWhatTerminal(microtaskWhat, onInvalidated: () {});
      t.activate();
      expect(t.data, 999);

      t.deactivate();
      expect(disposeCount, 0); // Microtask deferred

      // Flush microtasks
      await Future<void>.delayed(Duration.zero);
      expect(disposeCount, 1);
    });
  });
}
