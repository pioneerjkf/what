// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

class _TestResource {
  _TestResource(this.id, {this.label = ''});
  final int id;
  String label;
  bool isDisposed = false;

  void dispose() {
    isDisposed = true;
  }
}

void main() {
  group('ManagedWhat 2-Phase LPDAG Normalization & Distinct Short-Circuit', () {
    test('1. Upstream distinct short-circuit prevents resource disposal & recreation', () {
      final source = WhatController<int>(10);
      // Upstream distinct derivation: stays true for even numbers
      final isEven = computed<bool>((via) => via(source.what) % 2 == 0).distinct();

      int createCount = 0;
      int disposeCount = 0;
      final createdResources = <_TestResource>[];

      final managedNode = managed<_TestResource>(
        create: (via) {
          createCount++;
          final res = _TestResource(via(isEven) ? 1 : 0);
          createdResources.add(res);
          return res;
        },
        dispose: (res) {
          disposeCount++;
          res.dispose();
        },
      );

      final terminal = RawWhatTerminal(managedNode, onInvalidated: () {});
      terminal.activate();

      expect(createCount, 0, reason: 'Pure lazy: resource not allocated on activate');
      expect(terminal.data.id, 1);
      expect(createCount, 1);
      expect(disposeCount, 0);
      expect(createdResources[0].isDisposed, isFalse);

      // Mutate source: 10 -> 12 (isEven remains true)
      source.data = 12;

      // Access terminal data - should short-circuit because upstream distinct is unchanged
      expect(terminal.data.id, 1);
      expect(createCount, 1, reason: 'Resource MUST NOT be recreated when upstream distinct is unchanged');
      expect(disposeCount, 0, reason: 'Existing resource MUST NOT be disposed when upstream distinct is unchanged');
      expect(createdResources[0].isDisposed, isFalse);

      // Mutate source: 12 -> 13 (isEven changes to false)
      source.data = 13;

      expect(terminal.data.id, 0);
      expect(createCount, 2, reason: 'Resource MUST be recreated when upstream distinct actually changes');
      expect(disposeCount, 1, reason: 'Old resource MUST be disposed when upstream distinct changes');
      expect(createdResources[0].isDisposed, isTrue);
      expect(createdResources[1].isDisposed, isFalse);

      terminal.deactivate();
      expect(disposeCount, 2);
      expect(createdResources[1].isDisposed, isTrue);
    });

    test('2. updateResource returning identical instance suppresses _version++ and downstream cascade', () {
      final source = WhatController<int>(1);
      int updateCallCount = 0;
      int disposeCount = 0;

      final managedNode = managed<_TestResource>(
        create: (via) {
          final s = via(source.what);
          return _TestResource(s, label: 'initial');
        },
        update: (via, current) {
          updateCallCount++;
          final s = via(source.what);
          // In-place mutation returning identical instance
          current.label = 'updated_$s';
          return current;
        },
        dispose: (res) {
          disposeCount++;
          res.dispose();
        },
      );

      // Downstream computed observing managed
      int downstreamComputeCount = 0;
      final downstream = computed<int>((via) {
        downstreamComputeCount++;
        via(managedNode);
        return downstreamComputeCount;
      });

      final terminal = RawWhatTerminal(downstream, onInvalidated: () {});
      terminal.activate();

      expect(terminal.data, 1);
      expect(downstreamComputeCount, 1);
      expect(updateCallCount, 0);
      expect(disposeCount, 0);

      // Mutate source -> updateResource is called and returns identical instance
      source.data = 2;

      expect(terminal.data, 1, reason: 'Downstream MUST NOT recompute when managed returns identical instance');
      expect(downstreamComputeCount, 1, reason: 'downstreamComputeCount must remain 1');
      expect(updateCallCount, 1);
      expect(disposeCount, 0);

      terminal.deactivate();
      expect(disposeCount, 1);
    });

    test('3. Guarded managed node honors distinct short-circuit without recreating resources', () {
      final source = WhatController<int>(10);
      final flag = WhatController<bool>(true);
      final isEven = computed<bool>((via) => via(source.what) % 2 == 0).distinct();

      int createCount = 0;
      int disposeCount = 0;

      final managedNode = managed<_TestResource>(
        guard: (via) => via(flag.what).guarded(),
        create: (via) {
          createCount++;
          return _TestResource(via(isEven) ? 100 : 0);
        },
        dispose: (res) {
          disposeCount++;
          res.dispose();
        },
      );

      final terminal = RawWhatTerminal(managedNode, onInvalidated: () {});
      terminal.activate();

      expect(createCount, 0, reason: 'Pure lazy: resource not allocated on activate');
      expect(terminal.data.id, 100);
      expect(createCount, 1);
      expect(disposeCount, 0);

      // Mutate source: 10 -> 20 (isEven remains true)
      source.data = 20;

      expect(terminal.data.id, 100);
      expect(createCount, 1, reason: 'Guarded managed resource must not recreate on distinct short-circuit');
      expect(disposeCount, 0);

      // Block guard: flag -> false
      flag.data = false;
      expect(terminal.hasData, isFalse);
      expect(disposeCount, 1, reason: 'Guarded managed resource must dispose when guard blocks');

      terminal.deactivate();
    });
  });
}
