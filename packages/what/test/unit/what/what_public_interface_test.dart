// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('Dynamic Triad 1st-Class Public Interfaces & Constructors', () {
    test('1. computed functors (sync, future, stream, async) return pure What<T>', () async {
      final a = WhatController(10);

      // 1.1 sync
      final syncNode = computed((via) => via(a.what) * 2);
      expect(syncNode, isA<What<int>>());
      expect(syncNode.peek, 20);

      // 1.2 future
      final completer = Completer<String>();
      final futureNode = computed.future((via) => completer.future);
      expect(futureNode, isA<What<String>>());
      expect(futureNode.peekState.isEmpty, isTrue);

      final term = RawWhatTerminal(futureNode, onInvalidated: () {});
      term.activate();

      // 1.3 async alias
      final completer2 = Completer<int>();
      final asyncNode = computed.async((via) => completer2.future);
      expect(asyncNode, isA<What<int>>());

      // 1.4 stream
      final sc = StreamController<int>.broadcast();
      final streamNode = computed.stream((via) => sc.stream);
      expect(streamNode, isA<What<int>>());

      completer.complete('done');
      await Future<void>.delayed(Duration.zero);
      expect(futureNode.peek, 'done');

      term.deactivate();
      sc.close();
    });

    test('2. switched() functor (lazy, eager microtask scheduling & flicker-free)', () async {
      final cond = WhatController(true);
      final branchA = WhatController('A');
      final branchB = WhatController('B');

      // 2.1 default (lazy): does NOT decouple on dirty; keeps old source until pulled!
      final lazySwitched = switched((via) => via(cond.what) ? branchA.what : branchB.what);
      expect(lazySwitched, isA<What<String>>());
      expect(lazySwitched.peek, 'A');

      cond.data = false;
      // Before reading data, old source is still safely intact, not decoupled to empty!
      expect(lazySwitched.peekState.hasData, isTrue);
      // Reads new branch on demand
      expect(lazySwitched.peek, 'B');

      // 2.2 eager: schedules eager microtask switch upon trigger dirty!
      final eagerSwitched = switched(
        (via) => via(cond.what) ? branchA.what : branchB.what,
        eager: true,
      );
      expect(eagerSwitched, isA<What<String>>());
      expect(eagerSwitched.peek, 'B');

      final terminal = RawWhatTerminal(eagerSwitched, onInvalidated: () {});
      terminal.activate();

      // Trigger dirty
      cond.data = true;
      // Yield to microtask queue
      await Future<void>.delayed(Duration.zero);

      // Branch has pre-connected via microtask before downstream read!
      expect(eagerSwitched.peek, 'A');
      terminal.deactivate();
    });

    test('3. managed() functor and lifecycle returns pure What<T>', () {
      int disposed = 0;

      // 3.1 sync
      final syncManaged = managed<int>(
        create: (via) => 42,
        dispose: (_) => disposed++,
      );
      expect(syncManaged, isA<What<int>>());

      final terminal = RawWhatTerminal(syncManaged, onInvalidated: () {});
      terminal.activate();
      expect(syncManaged.peek, 42);
      terminal.deactivate();
      expect(disposed, 1);
    });

    test('4. retained extension on What<T> and pure What<T> interface with optional coupler', () {
      final source = WhatController<int>(1);
      final pendingCoupler = WhatCoupler<bool>.late();
      final retainedNode = source.what.retained(pending: pendingCoupler);

      expect(retainedNode, isA<What<int>>());
      expect(retainedNode.peek, 1);
      expect(pendingCoupler.what, isA<What<bool>>());
      expect(pendingCoupler.what.peek, isFalse);

      final fromExtension = source.what.retained();
      expect(fromExtension, isA<What<int>>());
      expect(fromExtension.peek, 1);
    });

    test('5. SwitchedFunctor and ManagedFunctor eager option verification', () {
      final cond = WhatController(true);
      final branchA = WhatController('A');
      final branchB = WhatController('B');

      final s1 = switched((via) => via(cond.what) ? branchA.what : branchB.what);
      expect(s1, isA<What<String>>());
      expect(s1.peek, 'A');

      final s2 = switched(
        (via) => via(cond.what) ? branchA.what : branchB.what,
        eager: true,
      );
      expect(s2, isA<What<String>>());
      expect(s2.peek, 'A');

      // Managed sync eager option
      final mEager = managed(
        create: (_) => 100,
        dispose: (_) {},
        eager: true,
      );
      expect(mEager, isA<What<int>>());

      // Managed sync lazy option (default)
      final mLazy = managed(
        create: (_) => 200,
        dispose: (_) {},
        eager: false,
      );
      expect(mLazy, isA<What<int>>());
    });
  });
}
