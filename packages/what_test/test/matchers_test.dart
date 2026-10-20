// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what_test/what_test.dart';

void main() {
  group('LPDAG Custom Matchers Suite', () {
    group('isDormant & isActive', () {
      test('node with 0 subscribers is dormant and not active', () {
        final counter = WhatController(0);
        expect(counter, isDormant);
        expect(counter.what, isDormant);
        expect(counter, isNot(isActive));
      });

      test('node with active terminal becomes active and not dormant', () {
        final counter = WhatController(0);
        final terminal = RawWhatTerminal(counter.what, onInvalidated: () {});
        terminal.activate();

        expect(counter, isActive);
        expect(counter.what, isActive);
        expect(counter, isNot(isDormant));

        terminal.deactivate();
        expect(counter, isDormant);
        expect(counter, isNot(isActive));
      });
    });

    group('hasSubscribers', () {
      test('accurately counts downstream active subscription edges', () {
        final counter = WhatController(0);
        expect(counter, hasSubscribers(0));

        final terminal1 = RawWhatTerminal(counter.what, onInvalidated: () {});
        terminal1.activate();
        expect(counter, hasSubscribers(1));

        final terminal2 = RawWhatTerminal(counter.what, onInvalidated: () {});
        terminal2.activate();
        expect(counter, hasSubscribers(2));

        terminal1.deactivate();
        expect(counter, hasSubscribers(1));

        terminal2.deactivate();
        expect(counter, hasSubscribers(0));
      });
    });

    group('hasGlitchFreedom', () {
      test(
          'verifies diamond dependency evaluation sequence without intermediate tearing',
          () {
        // Diamond graph:
        //      a
        //     / \
        //    b   c
        //     \ /
        //      d
        final a = WhatController(1);
        final b = computed((via) => via(a.what) * 2);
        final c = computed((via) => via(a.what) + 10);
        final d = computed<int>((via) => via(b) + via(c));

        final evaluations = <int>[];
        final terminal = RawWhatTerminal(d, onInvalidated: () {
          evaluations.add(untracked(d));
        });
        terminal.activate();

        // Initial evaluation
        expect(untracked(d), 13);
        evaluations.add(untracked(d));

        // Mutate upstream source a to 2
        // If glitch-free, d evaluates b=4, c=12 -> 16 in one consolidated step
        a.data = 2;

        expect(evaluations, hasGlitchFreedom);
        expect(evaluations, [13, 16]);

        terminal.deactivate();
      });
    });

    group('isData', () {
      test('matches valid Data snapshots and payloads', () {
        const snap = WhatSnapshot<int>(42);
        expect(snap, isData(42));
        expect(snap, isData(isPositive));
        expect(snap, isNot(isData(100)));

        const emptySnap = WhatSnapshot<int>.empty('no-data');
        expect(emptySnap, isNot(isData(42)));

        final errorSnap = WhatSnapshot<int>.error(Exception('fail'));
        expect(errorSnap, isNot(isData(42)));
      });

      test('matches What nodes and controllers in Data state', () {
        final ctrl = WhatController('active');
        expect(ctrl, isData('active'));
        expect(ctrl.what, isData('active'));
      });
    });

    group('isEmptyState', () {
      test('matches Empty snapshots and empty reasons', () {
        const emptyWithReason = WhatSnapshot<String>.empty('loading');
        expect(emptyWithReason, isEmptyState());
        expect(emptyWithReason, isEmptyState('loading'));
        expect(emptyWithReason, isNot(isEmptyState('other')));

        const snap = WhatSnapshot<String>('valid');
        expect(snap, isNot(isEmptyState()));
      });
    });

    group('isErrorState', () {
      test('matches Error snapshots and exception objects', () {
        final err = FormatException('bad format');
        final errSnap = WhatSnapshot<int>.error(err);

        expect(errSnap, isErrorState());
        expect(errSnap, isErrorState(isA<FormatException>()));
        expect(errSnap, isErrorState(err));

        const snap = WhatSnapshot<int>(10);
        expect(snap, isNot(isErrorState()));
      });
    });
  });
}
