// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  Object unwrapRootError(Object error) {
    var curr = error;
    while (curr is WhatSnapshotExtractionException && curr.error != null) {
      curr = curr.error!;
    }
    return curr;
  }

  final isCycleErrorOrWrapped = predicate<Object>((e) {
    return unwrapRootError(e) is LpdagCycleError;
  }, 'contains LpdagCycleError as root cause');

  final throwsCycleError = throwsA(
    anyOf(
      isA<LpdagCycleError>(),
      isA<WhatSnapshotExtractionException>().having(
        (e) => e.error,
        'error',
        isCycleErrorOrWrapped,
      ),
    ),
  );

  group('LPDAG Cyclic Dependency & Reentrancy Defense Suite', () {
    group('1. Computed Synchronous Cycle Defense', () {
      test('1.1 Direct self-referencing computed node triggers LpdagCycleError without StackOverflow', () {
        late final What<int> circular;
        circular = computed((via) {
          return via(circular) + 1;
        });

        // Reading hasError and error directly from What
        expect(circular.peekState.hasError, isTrue);
        expect(circular.peekState.error, isCycleErrorOrWrapped);

        // Reading .data should throw extraction exception with LpdagCycleError as cause
        expect(
          () => circular.peek,
          throwsA(
            isA<WhatSnapshotExtractionException>().having(
              (e) => e.error,
              'error',
              isCycleErrorOrWrapped,
            ),
          ),
        );
      });

      test('1.2 Mutual cyclic dependency (A -> B -> A) triggers LpdagCycleError', () {
        late final What<int> a;
        late final What<int> b;

        a = computed((via) => via(b) + 1);
        b = computed((via) => via(a) + 1);

        expect(a.peekState.hasError, isTrue);
        expect(a.peekState.error, isCycleErrorOrWrapped);

        expect(
          () => a.peek,
          throwsA(
            isA<WhatSnapshotExtractionException>().having(
              (e) => e.error,
              'error',
              isCycleErrorOrWrapped,
            ),
          ),
        );
      });

      test('1.3 Terminal connected to self-referencing computed detects LpdagCycleError', () {
        late final What<int> circular;
        circular = computed((via) => via(circular) + 1);

        final terminal = RawWhatTerminal(circular, onInvalidated: () {});
        terminal.activate();

        expect(
          () => terminal.data,
          throwsA(
            isA<WhatSnapshotExtractionException>().having(
              (e) => e.error,
              'error',
              isCycleErrorOrWrapped,
            ),
          ),
        );

        terminal.deactivate();
      });
    });

    group('2. Managed Resource Synchronous Cycle Defense', () {
      test('2.1 Managed resource reading itself inside create triggers LpdagCycleError', () {
        late final What<int> managedNode;
        managedNode = managed(
          create: (via) => via(managedNode) + 10,
          dispose: (_) {},
        );

        final terminal = RawWhatTerminal(managedNode, onInvalidated: () {});
        terminal.activate();

        expect(managedNode.peekState.hasError, isTrue);
        expect(managedNode.peekState.error, isCycleErrorOrWrapped);

        expect(
          () => managedNode.peek,
          throwsA(
            isA<WhatSnapshotExtractionException>().having(
              (e) => e.error,
              'error',
              isCycleErrorOrWrapped,
            ),
          ),
        );

        terminal.deactivate();
      });

      test('2.2 Mutual cycle between Managed and Computed triggers LpdagCycleError', () {
        late final What<int> managedNode;
        late final What<int> computedNode;

        managedNode = managed(
          create: (via) => via(computedNode) + 1,
          dispose: (_) {},
        );
        computedNode = computed((via) => via(managedNode) + 1);

        final terminal = RawWhatTerminal(managedNode, onInvalidated: () {});
        terminal.activate();

        expect(managedNode.peekState.hasError, isTrue);
        expect(managedNode.peekState.error, isCycleErrorOrWrapped);

        terminal.deactivate();
      });
    });

    group('3. RawViaTerminal Reentrancy Defense', () {
      test('3.1 RawViaTerminal reentrant evaluate() synchronously triggers LpdagCycleError', () {
        late final RawViaTerminal<int> terminal;
        terminal = RawViaTerminal(
          (via) {
            return terminal.evaluate();
          },
          onInvalidated: () {},
        );

        terminal.activate();

        expect(
          () => terminal.evaluate(),
          throwsA(isA<LpdagCycleError>()),
        );

        terminal.deactivate();
      });
    });

    group('4. Switched Cascade Cycle Defense', () {
      test('4.1 Direct self-referencing switched node triggers LpdagCycleError', () {
        late final What<int> circular;
        circular = switched((via) {
          return circular;
        });

        expect(
          () => circular.peek,
          throwsCycleError,
        );
      });

      test('4.2 Mutual cyclic dependency via switched triggers LpdagCycleError', () {
        late final What<int> a;
        late final What<int> b;

        a = switched((via) => b);
        b = switched((via) => a);

        expect(
          () => a.peek,
          throwsCycleError,
        );
      });
    });

    group('5. WhatCoupler Cyclic Coupling Defense', () {
      test('5.1 Coupler directly coupled to its own what triggers LpdagCycleError', () {
        final coupler = WhatCoupler<int>.late();
        coupler.couple(coupler.what);

        expect(
          () => coupler.data,
          throwsCycleError,
        );
      });

      test('5.2 Mutual circular coupling (A -> B -> A) triggers LpdagCycleError', () {
        final couplerA = WhatCoupler<int>.late();
        final couplerB = WhatCoupler<int>.late();

        couplerA.couple(couplerB.what);
        couplerB.couple(couplerA.what);

        expect(
          () => couplerA.data,
          throwsCycleError,
        );
      });
    });
  });
}
