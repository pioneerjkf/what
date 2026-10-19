// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:test/test.dart';
import 'package:what/what.dart';
import '../../test_utils.dart';

void main() {
  group('What Switched & Dynamic What List Matrix Tests', () {
    test('1.1 what.switched switches target What dynamically and propagates updates', () {
      final isPrimary = WhatController(true);
      final primary = WhatController('Primary-Initial');
      final secondary = WhatController('Secondary-Initial');

      final switchedWhat = switched((via) {
        return via(isPrimary.what) ? primary.what : secondary.what;
      });

      expect(switchedWhat.peek, 'Primary-Initial');

      // Update primary
      primary.data = 'Primary-Updated';
      expect(switchedWhat.peek, 'Primary-Updated');

      // Switch to secondary
      isPrimary.data = false;
      expect(switchedWhat.peek, 'Secondary-Initial');

      // Update primary while secondary is active -> switched remains secondary
      primary.data = 'Primary-Ignored';
      expect(switchedWhat.peek, 'Secondary-Initial');

      // Update secondary
      secondary.data = 'Secondary-Updated';
      expect(switchedWhat.peek, 'Secondary-Updated');
    });

    test('1.2 what.switched switches underlying What nodes dynamically', () {
      final mode = WhatController(1);
      final node1 = What.constant(100);
      final node2 = What.constant(200);
      final node3 = What.constant(300);

      final switchedWhat = switched((via) {
        switch (via(mode.what)) {
          case 1:
            return node1;
          case 2:
            return node2;
          default:
            return node3;
        }
      });

      expect(switchedWhat.peek, 100);

      mode.data = 2;
      expect(switchedWhat.peek, 200);

      mode.data = 3;
      expect(switchedWhat.peek, 300);
    });

    test('1.3 What.computed dynamically expands and shrinks collection of Whats', () {
      final count = WhatController(2);
      final items = List.generate(5, (i) => WhatController((i + 1) * 10)); // [10, 20, 30, 40, 50]

      final dynamicGroup = computed((via) {
        return List.generate(via(count.what), (i) => items[i].what);
      });

      final sumWhat = dynamicGroup.sum();

      expect(sumWhat.peek, 30); // 10 + 20

      // Mutate item in active set
      items[0].data = 15;
      expect(sumWhat.peek, 35); // 15 + 20

      // Expand group to 4 items
      count.data = 4;
      expect(sumWhat.peek, 105); // 15 + 20 + 30 + 40

      // Mutate item outside current active count (item[4]) -> sum unchanged
      items[4].data = 999;
      expect(sumWhat.peek, 105);

      // Shrink group to 1 item
      count.data = 1;
      expect(sumWhat.peek, 15);
    });

    test('1.4 Deeply nested switches with effect tracking evaluate consistently', () async {
      final rootCondition = WhatController(true);
      final leafA = WhatController(10);
      final leafB = WhatController(20);

      final branchSwitched = switched((via) => via(rootCondition.what) ? leafA.what : leafB.what);
      final computedResult = computed((via) => via(branchSwitched) * 2);

      final loggedValues = <int>[];
      final dispose = effect((via) {
        loggedValues.add(via(computedResult));
      });

      await Future<void>.delayed(Duration.zero);
      expect(loggedValues, [20]); // 10 * 2

      leafA.data = 15;
      await Future<void>.delayed(Duration.zero);
      expect(loggedValues, [20, 30]); // 15 * 2

      // Switch branch to leafB
      rootCondition.data = false;
      await Future<void>.delayed(Duration.zero);
      expect(loggedValues, [20, 30, 40]); // 20 * 2

      leafB.data = 50;
      await Future<void>.delayed(Duration.zero);
      expect(loggedValues, [20, 30, 40, 100]); // 50 * 2

      dispose();
    });
  });
}
