// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';
import 'package:what/effect.dart';

void main() {
  group('WhatDebugSnapshot & Terminal debugDependencies Tests', () {
    test('WhatController and RawWhatController attach debugLabel', () {
      final a = WhatController(10)..debugLabel = 'counterA';
      final b = RawWhatController('hello').withDebugLabel('rawB');
      final c = WhatController<double>.late()..debugLabel = 'lateC';
      final d = WhatController<String>.error('initError').withDebugLabel('errorD');

      expect(a.debugLabel, equals('counterA'));
      expect(b.debugLabel, equals('rawB'));
      expect(c.debugLabel, equals('lateC'));
      expect(d.debugLabel, equals('errorD'));
    });

    test('computed attaches debugLabel and reflects in debugDependencies', () {
      final a = WhatController(1)..debugLabel = 'sourceA';
      final b = WhatController(2)..debugLabel = 'sourceB';
      final sum = computed<int>(
        (via) => via(a.what) + via(b.what),
      )..debugLabel = 'sumComputed';

      expect(sum.debugLabel, equals('sumComputed'));
      expect(untracked(sum), equals(3));

      final terminal = RawViaTerminal<int>(
        (via) => via(sum) * 2,
        onInvalidated: () {},
      )..activate();

      expect(terminal.evaluate(), equals(6));

      final deps = terminal.debugDependencies;
      expect(deps.length, equals(1));
      expect(deps.first.debugLabel, equals('sumComputed'));
      expect(deps.first.data, equals(3));
      expect(deps.first.hasData, isTrue);
      expect(deps.first.hasError, isFalse);
      expect(deps.first.name, equals('sumComputed'));
      expect(deps.first.description, contains('3'));
      expect(deps.first.isActive, isTrue);
      expect(deps.first.targetCount, equals(1));

      terminal.deactivate();
    });

    test('RawViaTerminal dynamic branching updates debugDependencies correctly', () {
      final flag = WhatController(true)..debugLabel = 'flag';
      final optionA = WhatController('A').withDebugLabel('optionA');
      final optionB = WhatController('B').withDebugLabel('optionB');

      final terminal = RawViaTerminal<String>(
        (via) {
          if (via(flag.what)) {
            return via(optionA.what);
          } else {
            return via(optionB.what);
          }
        },
        onInvalidated: () {},
      )..activate();

      // Branch 1: flag is true -> depends on flag and optionA
      expect(terminal.evaluate(), equals('A'));
      var deps = terminal.debugDependencies;
      var labels = deps.map((d) => d.debugLabel).toSet();
      expect(labels, equals({'flag', 'optionA'}));

      // Branch 2: flag is false -> depends on flag and optionB (optionA is swept!)
      flag.set(false);
      expect(terminal.evaluate(), equals('B'));
      deps = terminal.debugDependencies;
      labels = deps.map((d) => d.debugLabel).toSet();
      expect(labels, equals({'flag', 'optionB'}));

      terminal.deactivate();
    });

    test('RawWhatTerminal reflects single source in debugDependencies', () {
      final count = WhatController(42)..debugLabel = 'counter';
      final terminal = RawWhatTerminal<int>(
        count.what,
        onInvalidated: () {},
      )..activate();

      final deps = terminal.debugDependencies;
      expect(deps.length, equals(1));
      expect(deps.first.debugLabel, equals('counter'));
      expect(deps.first.data, equals(42));
      expect(deps.first.hasData, isTrue);
      expect(deps.first.isActive, isTrue);

      terminal.deactivate();
    });

    test('WhatDebugSnapshot describes empty and error states correctly', () {
      final validNode = WhatController<double>(3.14)..debugLabel = 'validNode';
      final lateNode = WhatController<String>.late()..debugLabel = 'lateNode';
      final errorNode = WhatController<int>.error('Failed').withDebugLabel('errorNode');

      final terminal = RawViaTerminal<void>(
        (via) {
          via.state(validNode.what);
          via.state(lateNode.what);
          via.state(errorNode.what);
        },
        onInvalidated: () {},
      )..activate();

      terminal.evaluate();
      final deps = terminal.debugDependencies;
      final validDep = deps.firstWhere((d) => d.debugLabel == 'validNode');
      final lateDep = deps.firstWhere((d) => d.debugLabel == 'lateNode');
      final errDep = deps.firstWhere((d) => d.debugLabel == 'errorNode');

      expect(validDep.phase, equals(WhatPhase.valid));
      expect(validDep.hasData, isTrue);
      expect(validDep.data, equals(3.14));

      expect(lateDep.phase, equals(WhatPhase.empty));
      expect(lateDep.isEmpty, isTrue);
      expect(lateDep.description, contains('<empty>'));

      expect(errDep.phase, equals(WhatPhase.error));
      expect(errDep.hasError, isTrue);
      expect(errDep.error, equals('Failed'));
      expect(errDep.description, contains('Error: Failed'));

      // Verify switch (snapshot.phase) exhaustiveness and jump table behavior
      final labels = deps.map((d) => switch (d.phase) {
        WhatPhase.valid => 'Data: ${d.data}',
        WhatPhase.empty => 'Empty',
        WhatPhase.error => 'Error: ${d.error}',
      }).toList();

      expect(labels, equals(['Data: 3.14', 'Empty', 'Error: Failed']));

      terminal.deactivate();
    });

    test('terminal.debugTethers tracks tethered effects and separates from debugDependencies', () {
      final trigger = WhatController(10)..debugLabel = 'trigger';
      var effectRuns = 0;

      final effectA = Effect([trigger.what], () => effectRuns++).withDebugLabel('syncEffectA');
      final effectB = Effect([trigger.what], () => effectRuns++).withDebugLabel('syncEffectB');

      expect(effectA.debugLabel, equals('syncEffectA'));
      expect(effectA.debugDependencies.length, equals(1));
      expect(effectA.debugDependencies.first.debugLabel, equals('trigger'));

      final flag = WhatController(true);

      final terminal = RawViaTerminal<int>(
        (via) {
          final val = via(trigger.what);
          if (via(flag.what)) {
            via.tether(effectA);
          } else {
            via.tether(effectB);
          }
          return val;
        },
        onInvalidated: () {},
      )..activate();

      // Branch 1: flag is true -> tethered to effectA
      expect(terminal.evaluate(), equals(10));
      expect(terminal.debugDependencies.length, equals(2)); // trigger, flag
      expect(terminal.debugDependencies.map((d) => d.debugLabel).toSet(), equals({'trigger', null}));

      expect(terminal.debugTethers.length, equals(1));
      expect(terminal.debugTethers.first.debugLabel, equals('syncEffectA'));

      // Branch 2: flag is false -> effectA is swept, effectB is tethered
      flag.set(false);
      expect(terminal.evaluate(), equals(10));
      expect(terminal.debugTethers.length, equals(1));
      expect(terminal.debugTethers.first.debugLabel, equals('syncEffectB'));

      terminal.deactivate();
    });
  });
}
