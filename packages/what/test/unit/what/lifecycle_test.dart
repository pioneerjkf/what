// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:what/what.dart';

class _DisposableResource {
  _DisposableResource(this.id);
  final String id;
  bool isDisposed = false;
  int updateCount = 0;

  void dispose() {
    isDisposed = true;
  }
}

void main() {
  group('Lifecycle, Resource Management & Graceful Deactivation Unit Tests', () {
    // =========================================================================
    // 1. What.resource Synchronous vs Graceful Deactivation
    // =========================================================================
    group('1. What.resource Activation & Flapping', () {
      test('1.1 Non-graceful What.resource re-allocates and disposes on every rapid activation cycle', () {
        int createCount = 0;
        int disposeCount = 0;

        final resourceWhat = managed<_DisposableResource>(
          create: (_) {
            createCount++;
            return _DisposableResource('res-$createCount');
          },
          dispose: (r) {
            disposeCount++;
            r.dispose();
          },
          graceful: Graceful.none,
        );

        final t1 = RawWhatTerminal(resourceWhat, onInvalidated: () {});
        final t2 = RawWhatTerminal(resourceWhat, onInvalidated: () {});

        t1.activate();
        expect(t1.data.id, 'res-1');
        expect(createCount, 1);
        expect(disposeCount, 0);

        t1.deactivate();
        expect(disposeCount, 1);

        t2.activate();
        expect(t2.data.id, 'res-2');
        expect(createCount, 2);
        expect(disposeCount, 1);

        t2.deactivate();
        expect(createCount, 2);
        expect(disposeCount, 2);
      });

      test('1.2 Graceful What.resource preserves resource across synchronous flapping within microtask', () async {
        int createCount = 0;
        int disposeCount = 0;
        _DisposableResource? currentResource;

        final gracefulWhat = managed<_DisposableResource>(
          create: (_) {
            createCount++;
            return currentResource = _DisposableResource('graceful-$createCount');
          },
          dispose: (r) {
            disposeCount++;
            r.dispose();
          },
          graceful: const Graceful(),
        );

        final t1 = RawWhatTerminal(gracefulWhat, onInvalidated: () {});
        final t2 = RawWhatTerminal(gracefulWhat, onInvalidated: () {});

        t1.activate();
        expect(t1.data.id, 'graceful-1');
        expect(createCount, 1);
        expect(disposeCount, 0);

        // Flapping within same event turn
        t1.deactivate();
        t2.activate();

        expect(createCount, 1);
        expect(disposeCount, 0);
        expect(currentResource?.isDisposed, isFalse);

        await Future<void>.delayed(Duration.zero);

        expect(createCount, 1);
        expect(disposeCount, 0);
        expect(currentResource?.isDisposed, isFalse);

        t2.deactivate();
        expect(disposeCount, 0);

        await Future<void>.delayed(Duration.zero);
        expect(disposeCount, 1);
        expect(currentResource?.isDisposed, isTrue);
      });
    });

    // =========================================================================
    // 2. Resource Lifecycle State Machine with Auto-Tracking
    // =========================================================================
    group('2. Resource State Machine with Auto-Tracking', () {
      test('2.1 Upstream update reusing existing instance does not call dispose', () {
        final source = WhatController<int>(100);
        int createCount = 0;
        int updateCount = 0;
        int disposeCount = 0;

        final derived = managed<_DisposableResource>(
          create: (via) {
            createCount++;
            return _DisposableResource('val-${via(source.what)}');
          },
          update: (via, existing) {
            updateCount++;
            final _ = via(source.what);
            return existing;
          },
          dispose: (r) {
            disposeCount++;
            r.dispose();
          },
        );

        final terminal = RawWhatTerminal(derived, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data.id, 'val-100');
        expect(createCount, 1);
        expect(updateCount, 0);
        expect(disposeCount, 0);

        source.set(200);
        terminal.data;
        expect(updateCount, 1);
        expect(disposeCount, 0);
        expect(createCount, 1);

        source.set(300);
        terminal.data;
        expect(updateCount, 2);
        expect(disposeCount, 0);

        terminal.deactivate();
        expect(disposeCount, 1);
      });

      test('2.2 Upstream update returning newly allocated instance disposes the old instance', () {
        final source = WhatController<String>('A');
        final disposedList = <String>[];

        final derived = managed<_DisposableResource>(
          create: (via) => _DisposableResource(via(source.what)),
          update: (via, existing) => _DisposableResource(via(source.what)),
          dispose: (r) {
            disposedList.add(r.id);
            r.dispose();
          },
        );

        final terminal = RawWhatTerminal(derived, onInvalidated: () {});
        terminal.activate();

        expect(disposedList, isEmpty);
        expect(terminal.data.id, 'A');

        source.set('B');
        expect(terminal.data.id, 'B');
        expect(disposedList, ['A']);

        source.set('C');
        expect(terminal.data.id, 'C');
        expect(disposedList, ['A', 'B']);

        terminal.deactivate();
        expect(disposedList, ['A', 'B', 'C']);
      });

      test('2.3 Upstream error or empty state triggers disposal of active resource', () {
        final source = WhatController<int>(10);
        _DisposableResource? activeResource;
        int disposeCount = 0;

        final derived = managed<_DisposableResource>(
          create: (via) => activeResource = _DisposableResource('val-${via(source.what)}'),
          dispose: (r) {
            disposeCount++;
            r.dispose();
          },
        );

        final terminal = RawWhatTerminal(derived, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data.id, 'val-10');
        expect(activeResource?.isDisposed, isFalse);
        expect(disposeCount, 0);

        source.setError('Upstream failure');
        expect(terminal.hasError, isTrue); // Pull triggers lazy evaluation and disposal
        expect(disposeCount, 1);
        expect(activeResource?.isDisposed, isTrue);

        source.set(20);
        expect(terminal.data.id, 'val-20');
        expect(activeResource?.id, 'val-20');
        expect(activeResource?.isDisposed, isFalse);
        expect(terminal.hasData, isTrue);

        source.empty();
        expect(terminal.isEmpty, isTrue); // Native short-circuit empty propagation triggers disposal
        expect(disposeCount, 2);

        terminal.deactivate();
      });

      test('2.4 Resource disposal sequence on update and deactivation', () {
        final source = WhatController<String>('Alpha');
        final disposals = <String>[];

        final derived = managed<_DisposableResource>(
          create: (via) => _DisposableResource('res-${via(source.what)}'),
          update: (via, existing) => _DisposableResource('res-${via(source.what)}'),
          dispose: (r) {
            disposals.add(r.id);
            r.dispose();
          },
        );

        final terminal = RawWhatTerminal(derived, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data.id, 'res-Alpha');
        expect(disposals, isEmpty);

        // Update with new instance: old instance should be disposed upon read
        source.set('Beta');
        expect(terminal.data.id, equals('res-Beta'));
        expect(disposals, equals(['res-Alpha']));

        // Re-activate with 'Gamma'
        source.set('Gamma');
        expect(terminal.data.id, equals('res-Gamma'));

        // Deactivation: 'res-Gamma' should be disposed
        terminal.deactivate();
        expect(
            disposals,
            equals([
              'res-Alpha',
              'res-Beta',
              'res-Gamma',
            ]));
      });
    });

    // =========================================================================
    // 3. Exception Resilience in Resource Handlers
    // =========================================================================
    group('3. Exception Resilience in Resource Handlers', () {
      test('3.1 Exception in createResource transitions What to error without crashing isolate', () {
        final resourceWhat = managed<String>(
          create: (_) => throw FormatException('Failed resource initialization'),
          dispose: (_) {},
        );

        final terminal = RawWhatTerminal(resourceWhat, onInvalidated: () {});
        terminal.activate();

        expect(terminal.hasError, isTrue);
        expect(terminal.error, isA<FormatException>());

        terminal.deactivate();
      });

      test('3.2 Exception in updateResource disposes existing and transitions to error', () {
        final source = WhatController<int>(1);
        _DisposableResource? activeRes;
        int disposeCount = 0;

        final derived = managed<_DisposableResource>(
          create: (via) => activeRes = _DisposableResource('v-${via(source.what)}'),
          update: (via, existing) {
            if (via(source.what) == 999) throw StateError('Update crashed');
            return existing;
          },
          dispose: (r) {
            disposeCount++;
            r.dispose();
          },
        );

        final terminal = RawWhatTerminal(derived, onInvalidated: () {});
        terminal.activate();

        expect(terminal.hasData, isTrue);
        expect(disposeCount, 0);

        source.set(999);
        expect(terminal.hasError, isTrue);
        expect(terminal.error, isA<StateError>());
        expect(disposeCount, 1);
        expect(activeRes?.isDisposed, isTrue);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 4. WhatController Lifecycle Hooks & Graceful Buffering
    // =========================================================================
    group('4. WhatController Lifecycle Hooks & Graceful Buffering', () {
      test('4.1 Controller onActivated and onDeactivated with graceful buffering', () async {
        int activatedCount = 0;
        int deactivatedCount = 0;

        final controller = WhatController<int>(
          0,
          onActivated: () => activatedCount++,
          onDeactivated: () => deactivatedCount++,
          graceful: const Graceful(),
        );

        final t1 = RawWhatTerminal(controller.what, onInvalidated: () {});
        final t2 = RawWhatTerminal(controller.what, onInvalidated: () {});

        t1.activate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 0);

        t1.deactivate();
        t2.activate();

        await Future<void>.delayed(Duration.zero);
        expect(activatedCount, 1);
        expect(deactivatedCount, 0);

        t2.deactivate();
        expect(deactivatedCount, 0);

        await Future<void>.delayed(Duration.zero);
        expect(deactivatedCount, 1);
      });
    });
  });
}
