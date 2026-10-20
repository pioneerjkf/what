// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';
import '../../test_utils.dart';

void main() {
  group('computed', () {
    test('computes derived values automatically and lazily', () {
      final a = WhatController(10);
      final b = WhatController(20);

      var computeCount = 0;
      final sum = computed((via) {
        computeCount++;
        return via(a.what) + via(b.what);
      });

      // Lazy: zero evaluations before pull
      expect(computeCount, 0);

      expect(untracked(sum), 30);
      expect(computeCount, 1);

      // Multiple reads without mutation do not re-evaluate
      expect(untracked(sum), 30);
      expect(computeCount, 1);

      // Mutating upstream marks dirty, next read re-evaluates
      a.data = 15;
      expect(computeCount, 1);

      expect(untracked(sum), 35);
      expect(computeCount, 2);
    });

    test('supports what.computed and What.computed syntax equivalently', () {
      final firstName = WhatController('John');
      final lastName = WhatController('Doe');

      final fullName1 = computed((via) => '${via(firstName.what)} ${via(lastName.what)}');
      final fullName2 = computed((via) => '${via(firstName.what)} ${via(lastName.what)}');

      expect(untracked(fullName1), 'John Doe');
      expect(untracked(fullName2), 'John Doe');

      firstName.data = 'Jane';
      expect(untracked(fullName1), 'Jane Doe');
      expect(untracked(fullName2), 'Jane Doe');
    });

    test('supports nested computeds', () {
      final base = WhatController(2);
      final doubled = computed((via) => via(base.what) * 2);
      final quadrupled = computed((via) => via(doubled) * 2);

      expect(untracked(quadrupled), 8);

      base.data = 5;
      expect(untracked(quadrupled), 20);
    });

    test('dynamically prunes obsolete edges via Epoch diffing in conditional branches', () {
      final flag = WhatController(true);
      final branchA = WhatController('A');
      final branchB = WhatController('B');

      var computeCount = 0;
      final result = computed((via) {
        computeCount++;
        return via(flag.what) ? via(branchA.what) : via(branchB.what);
      });

      expect(untracked(result), 'A');
      expect(computeCount, 1);

      // Mutating unread branchB should NOT invalidate result
      branchB.data = 'B_updated';
      expect(untracked(result), 'A');
      expect(computeCount, 1); // No re-evaluation!

      // Switch branch to false
      flag.data = false;
      expect(untracked(result), 'B_updated');
      expect(computeCount, 2);

      // Now branchA is obsolete: mutating branchA should NOT invalidate result
      branchA.data = 'A_updated';
      expect(untracked(result), 'B_updated');
      expect(computeCount, 2); // No re-evaluation!
    });

    test('handles diamond dependencies with zero glitches', () {
      //      source
      //      /    \
      //    left   right
      //      \    /
      //       sum
      final source = WhatController(1);
      final left = computed((via) => via(source.what) * 2);
      final right = computed((via) => via(source.what) * 3);

      var sumComputeCount = 0;
      final sum = computed((via) {
        sumComputeCount++;
        return via(left) + via(right);
      });

      expect(untracked(sum), 5); // 2 + 3
      expect(sumComputeCount, 1);

      source.data = 10;
      expect(untracked(sum), 50); // 20 + 30
      expect(sumComputeCount, 2);
    });

    test('handles errors during compute and encapsulates them into error state', () {
      final trigger = WhatController(false);
      final failing = computed((via) {
        if (via(trigger.what)) {
          throw FormatException('Something broke');
        }
        return 'All good';
      });

      expect(untracked(failing), 'All good');
      expect(untracked.state(failing).hasData, isTrue);

      trigger.data = true;
      expect(untracked.state(failing).hasData, isFalse);
      expect(untracked.state(failing).hasError, isTrue);
      expect(untracked.state(failing).dataOrNull, isNull);
      expect(() => untracked(failing), throwsA(isA<WhatSnapshotExtractionException>()));
    });

    test('safely reads dataOrNull and dataOrElse inside computed without throwing', () {
      final lateWhat = WhatController<int>.late();
      final fallbackWhat = computed((via) {
        final val = via.state(lateWhat.what).dataOrNull ?? 999;
        return 'Value is $val';
      });

      expect(untracked(fallbackWhat), 'Value is 999');

      lateWhat.data = 42;
      expect(untracked(fallbackWhat), 'Value is 42');
    });

    test('deep computed pipeline propagates dirty state with lazy evaluation', () {
      final a = WhatController(1);
      final b = computed((via) => via(a.what) + 1);
      final c = computed((via) => via(b) * 2);
      final d = computed((via) => via(c) + 10);
      final e = computed((via) => 'Result: ${via(d)}');

      expect(untracked(e), 'Result: 14'); // ((1 + 1) * 2) + 10 = 14

      a.data = 5;
      expect(untracked(e), 'Result: 22'); // ((5 + 1) * 2) + 10 = 22
    });

    test('computed dynamically tracks collection iteration', () {
      final item1 = WhatController(10);
      final item2 = WhatController(20);
      final item3 = WhatController(30);
      final list = [item1, item2, item3];

      final total = computed((via) => list.fold<int>(0, (sum, item) => sum + via(item.what)));

      expect(untracked(total), 60);

      item2.data = 50;
      expect(untracked(total), 90);
    });

    test('effect automatically tracks and reacts to computed nodes', () async {
      final first = WhatController('John');
      final last = WhatController('Doe');
      final fullName = computed((via) => '${via(first.what)} ${via(last.what)}');

      var effectRuns = 0;
      String? observedName;

      final dispose = effect((via) {
        effectRuns++;
        observedName = via(fullName);
      });

      await Future.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observedName, 'John Doe');

      first.data = 'Jane';
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(observedName, 'Jane Doe');

      dispose();
    });

    test('preserves unvisited edges on computation exception and wakes up on subsequent source mutation', () {
      final a = WhatController(10);
      final b = WhatController(20);

      final sum = computed((via) {
        final valA = via(a.what);
        if (valA < 0) {
          throw FormatException('Negative value not allowed');
        }
        final valB = via(b.what);
        return valA + valB;
      });

      // 1. Initial valid pull
      expect(untracked(sum), 30);

      // 2. Exception in 'a': encapsulated into Error state
      a.data = -1;
      expect(untracked.state(sum).hasError, isTrue);
      expect(untracked.state(sum).snapshot.error, isA<FormatException>());

      // 3. Mutating 'b' marks sum dirty and keeps edges alive
      b.data = 50;
      expect(untracked.state(sum).hasError, isTrue);

      // 4. Recover 'a' to positive: pulls 10 + 50 = 60
      a.data = 10;
      expect(untracked.state(sum).hasData, isTrue);
      expect(untracked(sum), 60);
    });
  });
}
