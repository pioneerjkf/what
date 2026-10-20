// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('WhatCoupler Comprehensive Unit Tests', () {
    // =========================================================================
    // 1. WhatCoupler Core API & Lifecycle
    // =========================================================================
    group('1. WhatCoupler Core API & Lifecycle', () {
      test('1.1 WhatCoupler proxies active downstream subscriber count and snapshot via .what', () {
        final source = WhatController<int>(10);
        final coupler = WhatCoupler<int>(source.what);

        expect(coupler, isA<WhatCoupler<int>>());
        expect(coupler.what, isA<What<int>>());
        expect(coupler.isActive, isFalse);
        expect(coupler.snapshot.data, 10);

        // Chain terminal on coupler.what
        final terminal = RawWhatTerminal(coupler.what, onInvalidated: () {});
        terminal.activate();

        expect(coupler.isActive, isTrue);
        expect(source.isActive, isTrue);

        source.set(20);
        expect(coupler.snapshot.data, 20);

        terminal.deactivate();
        expect(coupler.isActive, isFalse);
        expect(source.isActive, isFalse);
      });

      test('1.2 WhatCoupler couple, decouple, tryDecoupling, and coupleGuarded methods', () {
        final coupler = WhatCoupler<String>.late();
        expect(coupler.isEmpty, isTrue);

        final source1 = What.constant('source_1');
        coupler.couple(source1);
        expect(coupler.hasData, isTrue);
        expect(coupler.data, 'source_1');

        coupler.coupleGuarded(() => throw Exception('Guard Failed'));
        expect(coupler.hasError, isTrue);
        expect(coupler.error, isA<Exception>());

        coupler.coupleGuarded(() => What.constant('source_guarded'));
        expect(coupler.hasData, isTrue);
        expect(coupler.data, 'source_guarded');

        coupler.setError('Manual Error');
        expect(coupler.hasError, isTrue);
        expect(coupler.error, 'Manual Error');

        coupler.decouple();
        expect(coupler.isEmpty, isTrue);
      });

      test('1.3 WhatCoupler late and dynamic binding lifecycle', () {
        final source = What.constant(100);
        final coupler = WhatCoupler<int>(source);

        expect(coupler.hasData, isTrue);
        expect(coupler.data, 100);

        coupler.couple(What.constant(200));
        expect(coupler.data, 200);

        coupler.decouple();
        expect(coupler.isEmpty, isTrue);
      });

      test('1.4 WhatCoupler tryDecoupling method', () {
        final sourceA = What.constant('A');
        final sourceB = What.constant('B');
        final coupler = WhatCoupler<String>(sourceA);

        expect(coupler, isA<WhatCoupler<String>>());
        expect(coupler.what, isA<What<String>>());
        expect(coupler.data, 'A');
        expect(untracked(coupler.what), 'A');

        coupler.couple(sourceB);
        expect(coupler.data, 'B');

        final failedDecouple = coupler.tryDecoupling(sourceA);
        expect(failedDecouple, isFalse);
        expect(coupler.hasData, isTrue);

        final successDecouple = coupler.tryDecoupling(sourceB);
        expect(successDecouple, isTrue);
        expect(coupler.isEmpty, isTrue);

        coupler.coupleGuarded(() => What.constant('C'));
        expect(coupler.data, 'C');

        coupler.decouple();
        expect(coupler.isEmpty, isTrue);
      });
    });

    // =========================================================================
    // 2. WhatCoupler<List<T>> Core API & Lifecycle
    // =========================================================================
    group('2. WhatCoupler<List<T>> Core API & Lifecycle', () {
      test('2.1 WhatCoupler<List<T>> proxies active downstream subscriber count and snapshot', () {
        final source1 = WhatController<int>(1);
        final source2 = WhatController<int>(2);
        final group = What.constant([source1.what, source2.what]);

        final coupler = WhatCoupler<List<What<int>>>(group);
        expect(coupler.isActive, isFalse);
        expect(group.isActive, isFalse);

        final terminal = RawWhatTerminal(coupler.what, onInvalidated: () {});
        terminal.activate();

        expect(coupler.isActive, isTrue);
        expect(group.isActive, isTrue);

        final whatData = coupler.snapshot.data.map((c) => untracked(c)).toList();
        expect(whatData, [1, 2]);

        terminal.deactivate();
        expect(coupler.isActive, isFalse);
        expect(group.isActive, isFalse);
      });

      test('2.2 WhatCoupler<List<T>> couple, decouple, and coupleGuarded methods', () {
        final coupler = WhatCoupler<List<What<String>>>.late();
        expect(coupler.isEmpty, isTrue);

        final group1 = What.constant([What.constant('a'), What.constant('b')]);
        coupler.couple(group1);
        expect(coupler.hasData, isTrue);
        expect(coupler.data.map((c) => untracked(c)).toList(), ['a', 'b']);

        coupler.coupleGuarded(() => throw Exception('Guard Failed'));
        expect(coupler.hasError, isTrue);
        expect(coupler.error, isA<Exception>());

        final group2 = What.constant([What.constant('x')]);
        coupler.coupleGuarded(() => group2);
        expect(coupler.hasData, isTrue);
        expect(coupler.data.map((c) => untracked(c)).toList(), ['x']);

        coupler.setError('Manual Group Error');
        expect(coupler.hasError, isTrue);
        expect(coupler.error, 'Manual Group Error');

        coupler.decouple();
        expect(coupler.isEmpty, isTrue);
      });

      test('2.3 WhatCoupler<List<T>> type inference', () {
        final group = What.constant([What.constant(10), What.constant(20)]);
        final coupler = WhatCoupler(group); // Inferred as WhatCoupler<List<What<int>>>

        expect(coupler, isA<WhatCoupler<List<What<int>>>>());
        expect(untracked(coupler.what).length, 2);
        expect(coupler.data.length, 2);

        final lateCoupler = WhatCoupler<List<What<int>>>.late();
        expect(lateCoupler.isEmpty, isTrue);

        final errorCoupler = WhatCoupler<List<What<int>>>.error('TestError');
        expect(errorCoupler.hasError, isTrue);
      });
    });

    // =========================================================================
    // 3. Coupler Isolation & Non-Interference Invariants
    // =========================================================================
    group('3. Coupler Isolation & Non-Interference Invariants', () {
      test('3.1 Multiple couplers on same source operate independently without interference', () {
        final sourceA = WhatController('A_orig');
        final sourceB = WhatController('B_orig');

        final coupler1 = WhatCoupler<String>(sourceA.what);
        final coupler2 = WhatCoupler<String>(sourceA.what);

        int c1Notify = 0, c2Notify = 0;
        final t1 = RawWhatTerminal(coupler1.what, onInvalidated: () => c1Notify++);
        final t2 = RawWhatTerminal(coupler2.what, onInvalidated: () => c2Notify++);
        t1.activate();
        t2.activate();

        expect(coupler1.snapshot.data, 'A_orig');
        expect(coupler2.snapshot.data, 'A_orig');

        // Couple only coupler1 to sourceB
        coupler1.couple(sourceB.what);
        expect(c1Notify, 1);
        expect(t1.data, 'B_orig'); // Pull resets pending state under Q1: A
        expect(c2Notify, 0);

        // Update sourceA -> only coupler2 should react
        sourceA.set('A_new');
        expect(c1Notify, 1);
        expect(c2Notify, 1);
        expect(t2.data, 'A_new');

        // Update sourceB -> only coupler1 should react
        sourceB.set('B_new');
        expect(c1Notify, 2);
        expect(c2Notify, 1);

        t1.deactivate();
        t2.deactivate();
      });

      test('3.2 Coupler couple must NOT steal or disrupt independent subscribers of the old source', () {
        final sourceA = WhatController('A');
        final sourceB = WhatController('B');

        int sourceANotifyCount = 0;
        int couplerNotifyCount = 0;

        final terminalA = RawWhatTerminal(sourceA.what, onInvalidated: () => sourceANotifyCount++);
        terminalA.activate();

        final coupler = WhatCoupler<String>(sourceA.what);
        final terminalCoupler = RawWhatTerminal(coupler.what, onInvalidated: () => couplerNotifyCount++);
        terminalCoupler.activate();

        // Couple to sourceB
        coupler.couple(sourceB.what);
        expect(couplerNotifyCount, 1);
        expect(terminalCoupler.data, 'B'); // Pull resets pending state under Q1: A
        expect(sourceANotifyCount, 0);

        // Update old sourceA
        sourceA.set('A_updated');
        expect(sourceANotifyCount, 1);
        expect(terminalA.data, 'A_updated');
        expect(couplerNotifyCount, 1);

        // Update new sourceB
        sourceB.set('B_updated');
        expect(sourceANotifyCount, 1);
        expect(couplerNotifyCount, 2);

        terminalA.deactivate();
        terminalCoupler.deactivate();
      });

      test('3.3 Topological lifecycle transition on couple with resources', () {
        int createA = 0, disposeA = 0;
        int createB = 0, disposeB = 0;

        final resA = managed(
          create: (_) {
            createA++;
            return 'resA';
          },
          dispose: (_) => disposeA++,
        );

        final resB = managed(
          create: (_) {
            createB++;
            return 'resB';
          },
          dispose: (_) => disposeB++,
        );

        final coupler = WhatCoupler<String>(resA);
        final terminal = RawWhatTerminal(coupler.what, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 'resA');
        expect(createA, 1);
        expect(disposeA, 0);
        expect(createB, 0);

        coupler.couple(resB);

        expect(disposeA, 1);
        expect(createB, 0); // resB is pure lazy, not pulled yet!

        expect(terminal.data, 'resB');
        expect(createB, 1);
        expect(disposeB, 0);

        terminal.deactivate();
        expect(disposeB, 1);
      });

      test('3.4 setError and decouple do not notify independent source subscribers', () {
        final sharedSource = WhatController('shared');
        int sourceNotifyCount = 0;
        int couplerNotifyCount = 0;

        final terminalSource = RawWhatTerminal(sharedSource.what, onInvalidated: () => sourceNotifyCount++);
        terminalSource.activate();

        final coupler = WhatCoupler<String>(sharedSource.what);
        final terminalCoupler = RawWhatTerminal(coupler.what, onInvalidated: () => couplerNotifyCount++);
        terminalCoupler.activate();

        coupler.setError(StateError('Coupler Error'));
        expect(couplerNotifyCount, 1);
        expect(terminalCoupler.hasError, isTrue); // Pull resets pending state under Q1: A
        expect(sourceNotifyCount, 0);

        coupler.decouple();
        expect(couplerNotifyCount, 2);
        expect(terminalCoupler.isEmpty, isTrue);
        expect(sourceNotifyCount, 0);

        terminalSource.deactivate();
        terminalCoupler.deactivate();
      });

      test('3.5 WhatCoupler<List<T>> subscriber isolation on couple', () {
        final groupA = WhatListController([What.constant(1)]);
        final groupB = WhatListController([What.constant(2)]);

        int groupANotify = 0;
        int couplerNotify = 0;

        final tA = RawWhatTerminal(groupA.what, onInvalidated: () => groupANotify++);
        tA.activate();

        final coupler = WhatCoupler<List<What<int>>>(groupA.what);
        final tC = RawWhatTerminal(coupler.what, onInvalidated: () => couplerNotify++);
        tC.activate();

        coupler.couple(groupB.what);
        expect(couplerNotify, 1);
        expect(tC.data.length, 1); // Pull resets pending state under Q1: A
        expect(groupANotify, 0);

        groupA.set([What.constant(10)]);
        expect(groupANotify, 1);
        expect(tA.data.length, 1);
        expect(couplerNotify, 1);

        groupB.set([What.constant(20)]);
        expect(groupANotify, 1);
        expect(couplerNotify, 2);
        expect(tC.data.length, 1);

        tA.deactivate();
        tC.deactivate();
      });
    });

    // =========================================================================
    // 4. Daisy-Chained Couplers (3-Hop & Multi-Layer Chaining)
    // =========================================================================
    group('4. Daisy-Chained Couplers (Multi-Hop Propagation)', () {
      test('4.1 Daisy-chained 3-Hop Coupler propagates mutations cleanly', () {
        final rootController = WhatController<int>(1);
        final hop1 = WhatCoupler<int>(rootController.what);
        final hop2 = WhatCoupler<int>(hop1.what);
        final hop3 = WhatCoupler<int>(hop2.what);

        int hop3DirtyCount = 0;
        final terminal = RawWhatTerminal(hop3.what, onInvalidated: () {
          hop3DirtyCount++;
        });
        terminal.activate();

        expect(hop3.data, 1);
        expect(hop3DirtyCount, 0);

        rootController.set(10);
        expect(hop3DirtyCount, 1);
        expect(hop3.data, 10);

        terminal.deactivate();
      });

      test('4.2 Daisy-chained Coupler intermediate couple and isolation', () {
        final rootA = WhatController<String>('RootA');
        final rootB = WhatController<String>('RootB');

        final hop1 = WhatCoupler<String>(rootA.what);
        final hop2 = WhatCoupler<String>(hop1.what);
        final hop3 = WhatCoupler<String>(hop2.what);

        final terminal = RawWhatTerminal(hop3.what, onInvalidated: () {});
        terminal.activate();

        expect(hop3.data, 'RootA');

        // Couple intermediate hop1 to rootB
        hop1.couple(rootB.what);
        expect(hop3.data, 'RootB');

        // Mutate rootA -> hop3 should not receive it
        rootA.set('RootA_Modified');
        expect(hop3.data, 'RootB');

        // Mutate rootB -> hop3 receives it
        rootB.set('RootB_Modified');
        expect(hop3.data, 'RootB_Modified');

        terminal.deactivate();
      });
    });
  });
}
