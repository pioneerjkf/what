// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:test/test.dart';
import 'package:what/what.dart';

class _ExplosiveObject {
  _ExplosiveObject(this.id, {this.explodeOnToString = false});

  final String id;
  final bool explodeOnToString;

  @override
  String toString() {
    if (explodeOnToString) {
      throw StateError('Explosion inside toString() of $id');
    }
    return 'ExplosiveObject($id)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is _ExplosiveObject && runtimeType == other.runtimeType && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

void main() {
  group('Fault Containment, Poison-Pill Isolation & Auto-Healing Integration Tests', () {
    // =========================================================================
    // 1. Runtime Error Isolation & Fallback Invariants
    // =========================================================================
    group('1. Error Isolation & Snapshot Protection', () {
      test('1.1 Runtime Lazy Computation Error yields Error Snapshot safely', () {
        final source = WhatController<int>(10);

        final cascaded = switched((via) {
          final data = via(source.what);
          if (data == 10) throw Exception('Intentional failure');
          return What.constant(data * 2);
        });

        final terminal = RawWhatTerminal(cascaded, onInvalidated: () {});
        terminal.activate();

        final snapshot = terminal.snapshot;
        expect(snapshot.hasError, isTrue);
        expect(snapshot.error, isNotNull);
        expect(snapshot.dataOrNull, isNull);
        expect(snapshot.dataOrElse(() => -1), -1);

        // Recover upstream
        source.set(5);
        expect(terminal.data, 10);

        terminal.deactivate();
      });

      test('1.2 WhatSnapshotExtractionException chains original error and stacktrace', () {
        final error = Exception('Original computation error');
        final errorWhat = What<int>.error(error, StackTrace.current);

        try {
          untracked(errorWhat);
          fail('Should throw WhatSnapshotExtractionException');
        } on WhatSnapshotExtractionException catch (e) {
          expect(e.error, error);
          expect(e.toString(), contains('ORIGINAL PIPELINE ERROR CAUSE:'));
          expect(e.toString(), contains('Original computation error'));
        }

        final errorGroup = What<List<What<int>>>.error(error, StackTrace.current);
        try {
          untracked(errorGroup);
          fail('Should throw WhatSnapshotExtractionException');
        } on WhatSnapshotExtractionException catch (e) {
          expect(e.error, error);
          expect(e.toString(), contains('ORIGINAL PIPELINE ERROR CAUSE:'));
          expect(e.toString(), contains('Original computation error'));
        }
      });
    });

    // =========================================================================
    // 2. Poison-Pill Isolation in Diamond Topologies
    // =========================================================================
    group('2. Poison-Pill Containment & Self-Healing', () {
      test('2.1 Poison-Pill in Asymmetric Diamond DAG with dataOrElse & Self-Healing', () {
        final source = WhatController<int>(10);

        // Left branch: Throws when value is even (Poison-Pill)
        final leftBranch = computed((via) {
          final v = via(source.what);
          if (v % 2 == 0) {
            throw const FormatException('Even numbers poison left branch');
          }
          return v * 10;
        });

        // Right branch: Always healthy
        final rightBranch = computed((via) => via(source.what) + 1);

        // Diamond Sink: Uses dataOrElse to heal if left branch is in error
        final sink = computed((via) {
          final leftVal = via.state(leftBranch).dataOrElse(() => 0);
          final rightVal = via(rightBranch);
          return leftVal + rightVal;
        });

        final terminal = RawWhatTerminal(sink, onInvalidated: () {});
        terminal.activate();

        // Source = 10 (even) -> Left is poisoned (0) -> sum = 0 + 11 = 11
        expect(terminal.data, 11);

        // Source = 11 (odd) -> Left is healthy (110) -> sum = 110 + 12 = 122
        source.set(11);
        expect(terminal.data, 122);

        terminal.deactivate();
      });

      test('2.2 Multi-Level Fault Cascades with Intermediate Fallbacks', () {
        final source = WhatController<int>(1);

        final fragileStage = computed((via) {
          final v = via(source.what);
          if (v == 2) throw StateError('Stage 1 failure');
          return v * 10;
        });

        final intermediateFallback = computed((via) => via.state(fragileStage).dataOrElse(() => 999));

        final downstreamStage = computed((via) => via(intermediateFallback) + 1);

        final terminal = RawWhatTerminal(downstreamStage, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, 11); // (1 * 10) + 1

        // Mutate to trigger failure in stage 1
        source.set(2);
        expect(terminal.data, 1000); // 999 + 1 (healed by intermediate fallback)

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. Explosive Object Injections & Hostile Object Sabotage
    // =========================================================================
    group('3. Explosive Object Injections & Hostile Object Sabotage', () {
      test('3.1 Explosive Error Object Injections with toString() Sabotage', () {
        final explosiveError = _ExplosiveObject('poison_error', explodeOnToString: true);
        final controller = WhatController<int>(0);

        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {});
        terminal.activate();

        controller.setError(explosiveError);

        expect(terminal.snapshot.hasError, isTrue);
        expect(identical(terminal.snapshot.error, explosiveError), isTrue);

        expect(terminal.dataOrElse(() => 999), 999);
        expect(terminal.dataOrNull, isNull);

        controller.set(1234);
        expect(terminal.snapshot.hasData, isTrue);
        expect(terminal.data, 1234);

        terminal.deactivate();
      });

      test('3.2 Explosive Object with operator == Sabotage inside distinct() and transform fault isolation', () {
        final obj1 = _ExplosiveObject('item_1');
        final obj1Dup = _ExplosiveObject('item_1');
        final obj2 = _ExplosiveObject('item_2');

        final controller = WhatController<_ExplosiveObject>(obj1, distinct: false);
        int distinctInvalidations = 0;

        final distinctWhat = controller.what.distinct(
          (prev, next) => prev.id == next.id,
        );

        final terminal = RawWhatTerminal(distinctWhat, onInvalidated: () {
          distinctInvalidations++;
        });
        terminal.activate();

        expect(terminal.snapshot.hasData, isTrue);
        expect(terminal.data.id, 'item_1');
        expect(distinctInvalidations, 0);

        // Under 2-Phase LPDAG: push invalidation reaches terminal without eager upstream pull;
        // semantic deduplication is verified upon pull.
        controller.set(obj1Dup);
        expect(distinctInvalidations, 1);
        expect(terminal.data.id, 'item_1');

        // Setting distinct object triggers invalidation
        controller.set(obj2);
        expect(distinctInvalidations, 2);
        expect(terminal.data.id, 'item_2');

        // Transformation node fault containment
        final throwingMap = computed<_ExplosiveObject>((via) {
          final item = via(distinctWhat);
          if (item.id == 'poison') {
            throw StateError('Adversarial sabotage inside map transform!');
          }
          return item;
        });

        final mapTerminal = RawWhatTerminal(throwingMap, onInvalidated: () {});
        mapTerminal.activate();

        expect(mapTerminal.snapshot.hasData, isTrue);
        expect(mapTerminal.data.id, 'item_2');

        // Inject poison item
        controller.set(_ExplosiveObject('poison'));
        expect(mapTerminal.snapshot.hasError, isTrue);
        expect(mapTerminal.snapshot.error, isA<StateError>());

        // Recovery with safe item
        controller.set(_ExplosiveObject('safe'));
        expect(mapTerminal.snapshot.hasData, isTrue);
        expect(mapTerminal.data.id, 'safe');

        mapTerminal.deactivate();
        terminal.deactivate();
      });

      test('2.3 Uncaught error in diamond DAG dispatches to downstream terminal exactly once', () {
        final source = WhatController<int>(1);
        final branchA = computed((via) => via(source.what) * 10);
        final branchB = computed((via) => via(source.what) * 100);

        var uncaughtErrors = 0;
        runZonedGuarded(() {
          final terminal = RawViaTerminal((via) {
            untracked(branchA);
            untracked(branchB);
          }, onInvalidated: () {});
          terminal.activate();
          terminal.evaluate();

          // Trigger uncaught error on the root what
          (source.what as dynamic)._handleUncaughtError(Exception('Diamond test error'), StackTrace.current);

          terminal.deactivate();
        }, (error, stackTrace) {
          uncaughtErrors++;
        });

        expect(uncaughtErrors, 1);
      });
    });
  });
}
