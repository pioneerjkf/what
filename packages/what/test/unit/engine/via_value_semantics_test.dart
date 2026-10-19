// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('WhatVia Value Semantics & Short-Circuit Propagation Suite (D1, D2, D7)', () {
    test('1. via(x) returns T and dynamically tracks dependency', () {
      final a = WhatController(10);
      final b = WhatController(20);

      final sum = computed((via) => via(a.what) + via(b.what));

      expect(sum.peek, 30);

      a.data = 15;
      expect(sum.peek, 35);

      b.data = 25;
      expect(sum.peek, 40);
    });

    test('2. Upstream Empty short-circuits and preserves emptyReason (D2)', () {
      final a = WhatController<int>.late(reason: 'WaitingForInput');
      final derived = computed((via) => via(a.what) * 2);

      expect(derived.peekState.isEmpty, isTrue);
      expect(derived.peekState.emptyReason, 'WaitingForInput');
      expect(derived.peekState.hasError, isFalse);
      expect(derived.peekState.hasData, isFalse);
    });

    test('3. Upstream Error short-circuits and preserves original error without double-wrapping (D2)', () {
      final err = StateError('OriginalError');
      final a = WhatController<int>.error(err);
      final derived = computed((via) => via(a.what) * 2);

      expect(derived.peekState.hasError, isTrue);
      expect(derived.peekState.error, same(err));
      expect(derived.peekState.isEmpty, isFalse);
      expect(derived.peekState.hasData, isFalse);
    });

    test('4. 2-step chain (a -> b -> c) preserves Empty reason across hops', () {
      final a = WhatController<int>.late(reason: 'Step1Reason');
      final b = computed((via) => via(a.what) + 1);
      final c = computed((via) => via(b) * 2);

      expect(c.peekState.isEmpty, isTrue);
      expect(c.peekState.emptyReason, 'Step1Reason');
    });

    test('5. Self-healing: When upstream changes from Empty to Data, downstream recovers', () {
      final a = WhatController<int>.late(reason: 'InitialEmpty');
      final derived = computed((via) => via(a.what) * 2);

      expect(derived.peekState.isEmpty, isTrue);

      a.data = 21;
      expect(derived.peekState.hasData, isTrue);
      expect(derived.peek, 42);
    });

    test('6. 1-Pass Epoch Sweeping on short-circuit: unreached branches are pruned', () {
      final cond = WhatController(true);
      final t = WhatController<int>.late(reason: 'EmptyTrueBranch');
      final f = WhatController(100);

      var fEvaluations = 0;
      final fDerived = computed((via) {
        fEvaluations++;
        return via(f.what);
      });

      final res = computed((via) => via(cond.what) ? via(t.what) : via(fDerived));

      // Initial evaluation: cond is true, t is empty -> short-circuits at t.
      // fDerived should NOT have been evaluated.
      expect(res.peekState.isEmpty, isTrue);
      expect(fEvaluations, 0);

      // Mutating f should not trigger res or fDerived because fDerived was never tracked or was pruned.
      f.data = 200;
      expect(fEvaluations, 0);
      expect(res.peekState.isEmpty, isTrue);

      // Switching cond to false activates the fDerived branch.
      cond.data = false;
      expect(res.peekState.hasData, isTrue);
      expect(res.peek, 200);
      expect(fEvaluations, 1);
    });

    test('7. via.state(x) returns WhatState<T> without short-circuiting', () {
      final a = WhatController<int>.late(reason: 'NoData');

      final status = computed((via) {
        final state = via.state(a.what);
        if (state.isEmpty) {
          return 'Empty: ${state.emptyReason}';
        }
        return 'Has: ${state.data}';
      });

      expect(status.peek, 'Empty: NoData');

      a.data = 10;
      expect(status.peek, 'Has: 10');
    });

    test('8. Guard condition evaluates and takes precedence over short-circuit', () {
      final a = WhatController<int>(5);

      final derived = computed(
        (via) => via(a.what) * 2,
        guard: (via) {
          final state = via.state(a.what);
          return (state.hasData && state.data > 10) ? WhatGuard.pass : WhatGuard.block('ValueTooLow');
        },
      );

      expect(derived.peekState.isEmpty, isTrue);
      expect(derived.peekState.emptyReason, 'ValueTooLow');

      a.data = 15;
      expect(derived.peekState.hasData, isTrue);
      expect(derived.peek, 30);
    });

    test('9. Effect.via short-circuits silently without calling action on Empty', () async {
      final a = WhatController<int>.late(reason: 'NotReady');
      var actionRuns = 0;

      final terminal = RawViaTerminal((via) {
        via.tether(
          Effect.via((v) {
            v(a.what);
            actionRuns++;
          }),
        );
      }, onInvalidated: () {})
        ..activate()
        ..evaluate();

      await Future<void>.delayed(Duration.zero);
      expect(actionRuns, 0);

      a.data = 42;
      await Future<void>.delayed(Duration.zero);
      expect(actionRuns, 1);

      terminal.deactivate();
    });

    test('10. User exceptions are caught and become Error(exception)', () {
      final customEx = FormatException('UserCustomException');
      final derived = computed<int>((via) {
        throw customEx;
      });

      expect(derived.peekState.hasError, isTrue);
      expect(derived.peekState.error, same(customEx));
    });
  });
}
