// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:what/effect.dart';
import 'package:test/test.dart';

void main() {
  group('Tether Declarative Lifecycle Contract Suite', () {
    test('1. Effect inherits from Tether and preserves generic typing in via.tether()', () {
      final source = WhatController(1);
      final effect = Effect([source.what], () {});

      // Verify inheritance
      expect(effect, isA<Tether>());

      // Verify via.tether typing
      final terminal = RawViaTerminal<int>((via) {
        final tethered = via.tether(effect);
        // Statically and dynamically verifies identical reference and Effect type
        expect(identical(tethered, effect), isTrue);
        expect(tethered, isA<Effect>());
        return via(source.what);
      }, onInvalidated: () {})
        ..activate();

      expect(terminal.evaluate(), equals(1));
      expect(terminal.debugTethers.length, equals(1));
      expect(terminal.debugTethers.first, isA<Tether>());
      expect(identical(terminal.debugTethers.first, effect), isTrue);

      terminal.deactivate();
    });

    test('2. TetherDebugExtension provides label, location, and chaining with exact type preservation', () {
      final trigger = WhatController(0);
      final effect = Effect([trigger.what], () {}).withDebugLabel('analyticsTether');

      // Static typing check: withDebugLabel preserves Effect
      expect(effect.debugLabel, equals('analyticsTether'));

      effect.debugTrace('traceLabel');
      expect(effect.debugLabel, equals('traceLabel'));
      expect(effect.debugCreationLocation, isNotNull);
    });

    test('3. Dynamic epoch sweeping detaches and deactivates swept tethers', () async {
      final branchSwitch = WhatController(true);
      final trigger = WhatController(0);

      var effectARuns = 0;
      var effectBRuns = 0;

      final effectA = Effect([trigger.what], () => effectARuns++).withDebugLabel('tetherA');
      final effectB = Effect([trigger.what], () => effectBRuns++).withDebugLabel('tetherB');

      final terminal = RawViaTerminal<int>((via) {
        if (via(branchSwitch.what)) {
          via.tether(effectA);
        } else {
          via.tether(effectB);
        }
        return 42;
      }, onInvalidated: () {})
        ..activate();

      // Branch 1: effectA is active
      expect(terminal.evaluate(), equals(42));
      expect(terminal.debugTethers.length, equals(1));
      expect(terminal.debugTethers.first.debugLabel, equals('tetherA'));

      trigger.data++;
      await Future<void>.delayed(Duration.zero);
      expect(effectARuns, equals(1));
      expect(effectBRuns, equals(0));

      // Branch 2: switch to effectB -> effectA swept and deactivated
      branchSwitch.data = false;
      expect(terminal.evaluate(), equals(42));
      expect(terminal.debugTethers.length, equals(1));
      expect(terminal.debugTethers.first.debugLabel, equals('tetherB'));

      trigger.data++;
      await Future<void>.delayed(Duration.zero);
      expect(effectARuns, equals(1)); // Dormant
      expect(effectBRuns, equals(1)); // Active

      terminal.deactivate();
    });

    test('4. Tethers do not emit dirty invalidation pulses downstream to parent watch scopes', () async {
      final trigger = WhatController(0);
      var effectRuns = 0;
      var terminalEvaluations = 0;

      final effect = Effect([trigger.what], () => effectRuns++);

      final terminal = RawViaTerminal<int>((via) {
        terminalEvaluations++;
        via.tether(effect);
        return 100;
      }, onInvalidated: () {
        fail('Terminal must NOT be invalidated when tether triggers independently');
      })
        ..activate();

      expect(terminal.evaluate(), equals(100));
      expect(terminalEvaluations, equals(1));

      // Mutate trigger observed ONLY by the effect, not by the terminal directly
      trigger.data = 1;
      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, equals(1));
      expect(terminalEvaluations, equals(1)); // Terminal did not re-evaluate

      terminal.deactivate();
    });

    test('5. Tether reports _isNewerThan as false during source dirty resolution', () {
      final effect = Effect([], () {});
      final comp = What.computed<int>((via) {
        via.tether(effect);
        return 42;
      });

      // 1. Activate terminal and evaluate comp once to bind tether to source edge
      final terminal = RawWhatTerminal<int>(comp, onInvalidated: () {})..activate();
      expect(comp.peek, equals(42));

      // 2. Deactivate terminal to make comp inactive
      terminal.deactivate();

      // 3. Dormant raw read on inactive node triggers _resolve() -> _isSourceDirty -> Tether._isNewerThan
      expect(comp.peek, equals(42));
    });
  });
}
