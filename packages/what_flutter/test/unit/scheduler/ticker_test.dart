// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';

void main() {
  group('WhatTickerProviderDriveExtension (vsync.drive) Tests', () {
    // =========================================================================
    // 1. Initial Values & Basic Frame Ticking
    // =========================================================================
    group('1. Initial Values & Frame Ticking', () {
      testWidgets(
          'evaluates onTick(Duration.zero) as default initial value upon activation',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        final driven = vsync.drive<int>(
          (elapsed) => elapsed.inMilliseconds + 100,
        );

        // Before activation, the managed node is dormant & empty
        expect(untracked.state(driven).isEmpty, isTrue);

        final values = <int>[];
        final terminal = RawWhatTerminal(driven, onInvalidated: () {
          if (untracked.state(driven).hasData) values.add(untracked(driven));
        });
        terminal.activate();

        // Activation evaluates onTick(Duration.zero) -> initial value 100
        expect(untracked.state(driven).hasData, isTrue);
        expect(untracked(driven), equals(100));

        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump(const Duration(milliseconds: 30));

        expect(values.length, greaterThan(1));
        expect(values.first, equals(100));
        expect(values.last, greaterThan(100));

        terminal.deactivate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('uses explicit initialValue when supplied',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        final driven = vsync.drive<int>(
          (elapsed) => elapsed.inMilliseconds,
          initialValue: -999,
        );

        // Before activation, the node is dormant & empty
        expect(untracked.state(driven).isEmpty, isTrue);

        final values = <int>[];
        final terminal = RawWhatTerminal(driven, onInvalidated: () {
          if (untracked.state(driven).hasData) values.add(untracked(driven));
        });
        terminal.activate();

        expect(untracked.state(driven).hasData, isTrue);
        expect(untracked(driven), equals(-999));

        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump(const Duration(milliseconds: 30));
        expect(values.length, greaterThan(1));
        expect(values.last, greaterThan(0));

        terminal.deactivate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'isolates onTick(Duration.zero) exception upon activation into error state without starting ticker',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        int callCount = 0;
        final driven = vsync.drive<int>(
          (elapsed) {
            callCount++;
            throw StateError('onTick init error');
          },
        );

        expect(untracked.state(driven).isEmpty, isTrue);

        final terminal = RawWhatTerminal(driven, onInvalidated: () {});
        terminal.activate();

        expect(untracked.state(driven).hasError, isTrue);
        expect(untracked.state(driven).error, isA<StateError>());
        expect((untracked.state(driven).error as StateError).message,
            'onTick init error');
        expect(callCount, equals(1));

        // Subsequent pumps do NOT invoke onTick anymore (ticker never started)
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump(const Duration(milliseconds: 30));
        expect(callCount, equals(1));

        terminal.deactivate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'trips circuit breaker and stops ticker when onTick throws on subsequent frame',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        int callCount = 0;
        final driven = vsync.drive<int>(
          (elapsed) {
            callCount++;
            if (callCount > 1) {
              throw StateError('frame tick error');
            }
            return elapsed.inMilliseconds;
          },
        );

        final terminal = RawWhatTerminal(driven, onInvalidated: () {});
        terminal.activate();

        expect(untracked.state(driven).hasData, isTrue);
        expect(callCount, equals(1));

        // Pump frame: throws StateError, trips circuit breaker
        await tester.pump(const Duration(milliseconds: 30));

        expect(callCount, equals(2));
        expect(untracked.state(driven).hasError, isTrue);
        expect((untracked.state(driven).error as StateError).message,
            equals('frame tick error'));

        // Subsequent pumps do NOT invoke onTick anymore (circuit breaker stopped ticker)
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump(const Duration(milliseconds: 30));

        expect(callCount, equals(2));

        terminal.deactivate();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // 2. Topological Lifecycle (On-Demand Activation, Deactivation, Reactivation)
    // =========================================================================
    group('2. Topological Lifecycle', () {
      testWidgets('does not run ticker when dormant (no active terminal)',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        int callCount = 0;
        final driven = vsync.drive<int>(
          (elapsed) {
            callCount++;
            return elapsed.inMilliseconds;
          },
        );

        // Pump frames while dormant
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        // When dormant, resource creation is deferred; onTick is never called
        expect(callCount, equals(0));
        expect(untracked.state(driven).isEmpty, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'stops ticking on deactivation and restarts cleanly on reactivation',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        final values = <int>[];
        late What<int> driven;

        final activeController = WhatController(true);

        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              driven = vsync.drive<int>((elapsed) => elapsed.inMilliseconds);
              return composed((context, via) {
                if (via(activeController.what)) {
                  final val = via.state(driven).dataOrNull;
                  if (val != null) values.add(val);
                  return Text('Tick: $val');
                }
                return const SizedBox.shrink();
              });
            }),
          ),
        );

        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump(const Duration(milliseconds: 30));

        final countActive1 = values.length;
        expect(countActive1, greaterThan(1));

        // 2. Deactivate (widget branch switches away from driven)
        activeController.data = false;
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        // No new values produced while deactivated
        expect(values.length, equals(countActive1));

        // 3. Reactivate
        activeController.data = true;
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump(const Duration(milliseconds: 30));

        expect(values.length, greaterThan(countActive1));

        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // 3. Distinct & Custom Equals Filtering
    // =========================================================================
    group('3. Deduplication & Equality', () {
      testWidgets('distinct: true suppresses consecutive identical values',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        final emitted = <int>[];

        // Maps elapsed time in ms to 100ms buckets (0, 0, 0, 1, 1, ...)
        final driven = vsync.drive<int>(
          (elapsed) => elapsed.inMilliseconds ~/ 100,
          distinct: true,
        );

        final terminal = RawWhatTerminal(driven, onInvalidated: () {
          if (untracked.state(driven).hasData) emitted.add(untracked(driven));
        });
        terminal.activate();
        if (untracked.state(driven).hasData) emitted.add(untracked(driven));

        // Pump 5 frames of 10ms each (all within same 100ms bucket -> 0)
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        // Only initial 0 emitted, duplicates suppressed
        expect(emitted, equals([0]));

        // Pump past 100ms
        await tester.pump(const Duration(milliseconds: 70));
        expect(emitted, equals([0, 1]));

        terminal.deactivate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('custom equals function is respected when distinct: true',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        final emitted = <double>[];

        // Custom equality: ignores changes smaller than 0.5
        final driven = vsync.drive<double>(
          (elapsed) => elapsed.inMilliseconds / 100.0,
          distinct: true,
          equals: (prev, next) => (prev - next).abs() < 0.5,
        );

        final terminal = RawWhatTerminal(driven, onInvalidated: () {
          if (untracked.state(driven).hasData) emitted.add(untracked(driven));
        });
        terminal.activate();
        if (untracked.state(driven).hasData) emitted.add(untracked(driven));

        // Frame ticks at small increments (< 0.5)
        await tester
            .pump(const Duration(milliseconds: 20)); // 0.2 -> suppressed
        await tester
            .pump(const Duration(milliseconds: 20)); // 0.4 -> suppressed
        expect(emitted, equals([0.0]));

        await tester.pump(
            const Duration(milliseconds: 30)); // difference >= 0.5 -> emitted
        expect(emitted.length, equals(2));
        expect(emitted.last, closeTo(0.5, 0.05));

        terminal.deactivate();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('asserts when equals is provided but distinct is false',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        expect(
          () => vsync.drive<int>(
            (elapsed) => elapsed.inMilliseconds,
            distinct: false,
            equals: (a, b) => a == b,
          ),
          throwsAssertionError,
        );
      });
    });

    // =========================================================================
    // 4. Exception Handling & setGuarded Protection
    // =========================================================================
    group('4. Guarded Exception Handling', () {
      testWidgets(
          'catches exceptions in onTick and safely transitions to error snapshot',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        bool shouldThrow = false;

        final driven = vsync.drive<int>(
          (elapsed) {
            if (shouldThrow) {
              throw StateError('Simulated calculation failure in onTick');
            }
            return elapsed.inMilliseconds;
          },
        );

        Object? capturedError;
        late final RawWhatTerminal<int> terminal;
        terminal = RawWhatTerminal(driven, onInvalidated: () {
          if (terminal.hasError) {
            capturedError = terminal.error;
          }
        });

        terminal.activate();

        await tester.pump(const Duration(milliseconds: 20));
        expect(untracked.state(driven).hasData, isTrue);
        expect(untracked.state(driven).hasError, isFalse);

        // Trigger exception inside onTick
        shouldThrow = true;
        await tester.pump(const Duration(milliseconds: 20));

        expect(untracked.state(driven).hasError, isTrue);
        expect(capturedError, isA<StateError>());
        expect((capturedError as StateError).message,
            contains('Simulated calculation failure'));

        terminal.deactivate();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    // =========================================================================
    // 5. Graceful Disposal Option
    // =========================================================================
    group('5. Graceful Option', () {
      testWidgets('graceful: true defers disposal across rapid re-mounts',
          (WidgetTester tester) async {
        late TickerProvider vsync;
        await tester.pumpWidget(
          MaterialApp(
            home: composed.vsync((context, via, v) {
              vsync = v;
              return const SizedBox.shrink();
            }),
          ),
        );

        final driven = vsync.drive<int>(
          (elapsed) => elapsed.inMilliseconds,
          graceful: Graceful.microtask,
        );

        final terminal = RawWhatTerminal(driven, onInvalidated: () {});
        terminal.activate();

        await tester.pump(const Duration(milliseconds: 20));
        expect(untracked.state(driven).hasData, isTrue);

        terminal.deactivate();
        // Immediately reactivate in same frame/turn
        terminal.activate();

        await tester.pump(const Duration(milliseconds: 20));
        expect(untracked.state(driven).hasData, isTrue);

        terminal.deactivate();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  });
}
