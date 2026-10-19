// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.
import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('Raw & Suffix Raw Escape Hatches Comprehensive Unit Tests', () {
    // =========================================================================
    // 1. WhatController(distinct: false) vs WhatController default (distinct: true)
    // =========================================================================
    group('1. WhatController(distinct: false) vs WhatController default', () {
      test('1.1 WhatController(distinct: false) emits dirty pulses unconditionally on identical values', () {
        final raw = WhatController<int>(10, distinct: false);
        int dirtyCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 10);
        expect(dirtyCount, 0);

        raw.data = 10; // Same value
        expect(dirtyCount, 1);
        expect(terminal.data, 10); // Pull clears pending state under Q1: A

        raw.data = 10; // Same value again
        expect(dirtyCount, 2);
        expect(terminal.data, 10);

        terminal.deactivate();
      });

      test('1.2 WhatController default suppresses dirty pulse on identical value', () {
        final distinctWhat = WhatController<int>(10);
        int dirtyCount = 0;
        final terminal = RawWhatTerminal(distinctWhat.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 10);
        expect(dirtyCount, 0);

        distinctWhat.data = 10; // Same value ignored
        expect(dirtyCount, 0);

        distinctWhat.data = 20; // New value emitted
        expect(dirtyCount, 1);

        terminal.deactivate();
      });

      test('1.3 WhatController(distinct: false) enables in-place mutable buffer streaming', () {
        final buffer = <int>[];
        final stream = WhatController<List<int>>(buffer, distinct: false);
        int dirtyCount = 0;
        final terminal = RawWhatTerminal(stream.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, isEmpty);
        expect(dirtyCount, 0);

        buffer.add(1);
        stream.data = buffer; // Same object identity!
        expect(dirtyCount, 1);
        expect(terminal.data, equals([1]));

        buffer.add(2);
        stream.data = buffer;
        expect(dirtyCount, 2);
        expect(terminal.data, equals([1, 2]));

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 2. WhatController(distinct: false) vs what default
    // =========================================================================
    group('2. WhatController(distinct: false) Functor', () {
      test('2.1 WhatController(distinct: false) emits on duplicate value assignments', () {
        final raw = WhatController('alpha', distinct: false);
        int dirtyCount = 0;
        final terminal = RawWhatTerminal(raw.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 'alpha');

        raw.data = 'alpha';
        expect(dirtyCount, 1);
        expect(terminal.data, 'alpha'); // Pull clears pending state under Q1: A

        raw.data = 'alpha';
        expect(dirtyCount, 2);
        expect(terminal.data, 'alpha');

        terminal.deactivate();
      });

      test('2.2 what.late(distinct: false) starts empty and propagates duplicate assignments', () {
        final lateRaw = WhatController<int>.late(distinct: false);
        expect(lateRaw.isEmpty, isTrue);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(lateRaw.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.isEmpty, isTrue);

        lateRaw.set(100);
        expect(terminal.data, 100);
        expect(dirtyCount, 1);

        lateRaw.set(100); // Duplicate value propagates in raw mode
        expect(dirtyCount, 2);

        terminal.deactivate();
      });

      test('2.3 WhatController.error(distinct: false) starts in error and propagates duplicate error assignments', () {
        final errRaw = WhatController<int>.error('InitialError', distinct: false);
        expect(errRaw.hasError, isTrue);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(errRaw.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.hasError, isTrue);

        errRaw.setError('InitialError'); // Same error propagates in raw mode
        expect(dirtyCount, 1);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. WhatController.late and WhatController.error with distinct: false
    // =========================================================================
    group('3. WhatController with distinct: false', () {
      test('3.1 what.late(distinct: false) behaves as non-distinct late state', () {
        final wLateRaw = WhatController<String>.late(distinct: false);
        expect(wLateRaw.isEmpty, isTrue);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(wLateRaw.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        wLateRaw.data = 'first';
        expect(terminal.data, 'first');
        expect(dirtyCount, 1);

        wLateRaw.data = 'first';
        expect(dirtyCount, 2);

        terminal.deactivate();
      });

      test('3.2 WhatController.error(distinct: false) behaves as non-distinct error state', () {
        final wErrRaw = WhatController<int>.error('Err', distinct: false);
        expect(wErrRaw.hasError, isTrue);

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(wErrRaw.what, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.hasError, isTrue);

        wErrRaw.setError('Err');
        expect(dirtyCount, 1);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 4. computed and what.computed (Pure Lazy LPDAG)
    // =========================================================================
    group('4. computed and what.computed (Pure Lazy LPDAG)', () {
      test('4.1 computed creates valid computation node that evaluates lazily', () {
        final source = WhatController(10);
        int evalCount = 0;
        final c = computed((via) {
          evalCount++;
          return via(source.what) * 2;
        });

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(c, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(evalCount, 0); // Lazy: not yet read
        expect(terminal.data, 20);
        expect(evalCount, 1);
        expect(dirtyCount, 0);

        source.data = 20;
        expect(dirtyCount, 1);
        expect(terminal.data, 40);
        expect(evalCount, 2);

        terminal.deactivate();
      });

      test('4.2 what.computed works symmetrically with top-level computed', () {
        final a = WhatController(5, distinct: false);
        final b = WhatController(10, distinct: false);
        final sum = computed((via) => via(a.what) + via(b.what));

        int dirtyCount = 0;
        final terminal = RawWhatTerminal(sum, onInvalidated: () => dirtyCount++);
        terminal.activate();

        expect(terminal.data, 15);
        expect(dirtyCount, 0);

        a.data = 5; // Emits dirty because a is raw!
        expect(dirtyCount, 1);
        expect(terminal.data, 15);

        terminal.deactivate();
      });

      test('4.3 What.computed factory constructor works', () {
        final source = WhatController(1);
        final doubled = computed((via) => via(source.what) * 2);

        expect(doubled.peek, 2);
        source.data = 2;
        expect(doubled.peek, 4);
      });

      test('4.4 computed evaluates purely on pull and guarantees exactly 1 computation on diamond graph', () {
        final root = WhatController(10);
        final left = computed((via) => via(root.what) * 2);
        final right = computed((via) => via(root.what) * 3);

        int evalCount = 0;
        final diamond = computed((via) {
          evalCount++;
          return via(left) + via(right);
        });

        expect(evalCount, 0); // Lazy: not yet evaluated

        expect(diamond.peek, 50); // 20 + 30 = 50
        expect(evalCount, 1);

        // Mutating root pushes dirty flag to diamond via both branches
        root.data = 20;
        expect(evalCount, 1); // Zero computation during push!

        // Evaluates exactly once on pull with complete, glitch-free state (40 + 60 = 100)
        expect(diamond.peek, 100);
        expect(evalCount, 2);
      });
    });
  });
}
