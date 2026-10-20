// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:what/reflector.dart';
import 'package:test/test.dart';

void main() {
  group('LpdagReflector & WhatReflector Diagnostic Suite', () {
    test('1. WhatController exposes WhatReflector with source kind and state payload', () {
      final counter = WhatController(42)..withDebugLabel('Counter');
      final reflector = counter.what.debugReflector;

      expect(reflector, isNotNull);
      expect(reflector, isA<WhatReflector>());
      expect(reflector!.kind, 'source');
      expect(reflector.debugLabel, 'Counter');
      expect(reflector.hasData, isTrue);
      expect(reflector.data, 42);
      expect(reflector.sources, isEmpty);
      expect(reflector.id, isNotEmpty);
    });

    test('2. computed exposes WhatReflector with derivation kind and upstream sources', () {
      final a = WhatController(10)..withDebugLabel('A');
      final b = WhatController(20)..withDebugLabel('B');
      final sum = computed((via) => via(a.what) + via(b.what))..withDebugLabel('Sum');
      final terminal = RawWhatTerminal(sum, onInvalidated: () {})..activate();

      expect(untracked(sum), 30);

      final sumReflector = sum.debugReflector;
      expect(sumReflector, isNotNull);
      expect(sumReflector!.kind, 'derivation');
      expect(sumReflector.hasData, isTrue);
      expect(sumReflector.data, 30);
      expect(sumReflector.isActive, isTrue);

      final sourceLabels = sumReflector.sources.map((s) => s.debugLabel).toList();
      expect(sourceLabels, containsAll(['A', 'B']));

      final aReflector = a.what.debugReflector!;
      final aTargetLabels = aReflector.targets.map((t) => t.debugLabel).toList();
      expect(aTargetLabels, contains('Sum'));

      terminal.deactivate();
    });

    test('3. switched reflector dynamically updates sources across branch transitions', () {
      final toggle = WhatController(true)..withDebugLabel('Toggle');
      final branchA = WhatController('Hello')..withDebugLabel('BranchA');
      final branchB = WhatController('World')..withDebugLabel('BranchB');

      final current = switched(
        (via) => via(toggle.what) ? branchA.what : branchB.what,
      )..withDebugLabel('BranchSwitch');

      final terminal = RawWhatTerminal(current, onInvalidated: () {})..activate();
      expect(untracked(current), 'Hello');

      final switchReflector = current.debugReflector!;
      expect(switchReflector.sources.map((s) => s.debugLabel), contains('BranchA'));
      expect(switchReflector.sources.map((s) => s.debugLabel), isNot(contains('BranchB')));

      // Transition branch
      toggle.data = false;
      expect(untracked(current), 'World');

      expect(switchReflector.sources.map((s) => s.debugLabel), contains('BranchB'));
      expect(switchReflector.sources.map((s) => s.debugLabel), isNot(contains('BranchA')));

      terminal.deactivate();
    });

    test('4. RawTerminal exposes LpdagReflector with sink kind and active sources', () {
      final source = WhatController(100)..withDebugLabel('SourceNum');
      final terminal = RawWhatTerminal(source.what, onInvalidated: () {})..withDebugLabel('TestTerminal');
      terminal.activate();

      final termReflector = terminal.debugReflector;
      expect(termReflector, isNotNull);
      expect(termReflector!.kind, 'sink');
      expect(termReflector.debugLabel, 'TestTerminal');
      expect(termReflector.isActive, isTrue);
      expect(termReflector.sources.map((s) => s.debugLabel), contains('SourceNum'));

      terminal.deactivate();
      expect(termReflector.isActive, isFalse);
    });

    test('5. WhatReflector observes live state updates cleanly in read-only mode', () {
      final counter = WhatController(1)..withDebugLabel('ObsCounter');
      final doubled = computed((via) => via(counter.what) * 2);
      final terminal = RawWhatTerminal(doubled, onInvalidated: () {})..activate();

      final reflector = counter.what.debugReflector as WhatReflector;
      expect(reflector.data, 1);
      expect(untracked(doubled), 2);

      counter.data = 50;

      expect(reflector.data, 50);
      expect(untracked(doubled), 100);

      terminal.deactivate();
    });

    test('6. LpdagReflector.toJson serializes all mandatory DevTools DTO fields', () {
      final node = (WhatController('test')..withDebugLabel('JsonTest')).what;
      final reflector = node.debugReflector!;
      final json = reflector.toJson();

      expect(json['id'], isA<String>());
      expect(json['debugLabel'], 'JsonTest');
      expect(json['kind'], 'source');
      expect(json['isActive'], isFalse);
      expect(json['hasData'], isTrue);
      expect(json['data'], 'test');
      expect(json['version'], isA<int>());
    });
  });
}
