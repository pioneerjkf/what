// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';
import '../../test_utils.dart';

void main() {
  group('What.switched & what.switched Comprehensive Unit Tests', () {
    test('what.switched dynamically switches target What based on reactive state', () {
      final isDark = WhatController(false);
      final lightTheme = WhatController('Light Mode');
      final darkTheme = WhatController('Dark Mode');

      final activeTheme = switched((via) {
        return via(isDark.what) ? darkTheme.what : lightTheme.what;
      });

      expect(activeTheme.peek, equals('Light Mode'));

      // Switch to dark
      isDark.data = true;
      expect(activeTheme.peek, equals('Dark Mode'));

      // Mutate darkTheme inner data
      darkTheme.data = 'OLED Dark Mode';
      expect(activeTheme.peek, equals('OLED Dark Mode'));

      // Switch back to light
      isDark.data = false;
      expect(activeTheme.peek, equals('Light Mode'));
    });

    test('what.switched prunes obsolete dependencies on dynamic conditional branches', () {
      final branch = WhatController(true);
      final a = WhatController('Alpha');
      final b = WhatController('Beta');

      final targetA = WhatController(10);
      final targetB = WhatController(20);

      var evaluations = 0;
      final switchedWhat = switched((via) {
        evaluations++;
        if (via(branch.what)) {
          final _ = via(a.what);
          return targetA.what;
        } else {
          final _ = via(b.what);
          return targetB.what;
        }
      });

      expect(switchedWhat.peek, equals(10));
      expect(evaluations, equals(1));

      // Mutating 'a' re-evaluates because branch is true
      a.data = 'Alpha 2';
      expect(switchedWhat.peek, equals(10));
      expect(evaluations, equals(2));

      // Mutating 'b' should NOT re-evaluate because 'b' was never read
      b.data = 'Beta 2';
      expect(switchedWhat.peek, equals(10));
      expect(evaluations, equals(2));

      // Switch branch to false
      branch.data = false;
      expect(switchedWhat.peek, equals(20));
      expect(evaluations, equals(3));

      // Now mutating 'a' should NOT re-evaluate because it was pruned!
      a.data = 'Alpha 3';
      expect(switchedWhat.peek, equals(20));
      expect(evaluations, equals(3));

      // Mutating 'b' re-evaluates
      b.data = 'Beta 3';
      expect(switchedWhat.peek, equals(20));
      expect(evaluations, equals(4));
    });

    test('what.switched reacts inside effect and computed', () async {
      final selectedId = WhatController(1);
      final item1 = WhatController('Item 1: Alice');
      final item2 = WhatController('Item 2: Bob');

      final currentItem = switched((via) {
        return via(selectedId.what) == 1 ? item1.what : item2.what;
      });

      final summary = computed((via) => 'Summary: ${via(currentItem)}');
      expect(summary.peek, equals('Summary: Item 1: Alice'));

      final effectLogs = <String>[];
      final dispose = effect((via) {
        effectLogs.add(via(currentItem));
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectLogs, equals(['Item 1: Alice']));

      // Change inner item1 data
      item1.data = 'Item 1: Alice Updated';
      await Future<void>.delayed(Duration.zero);
      expect(summary.peek, equals('Summary: Item 1: Alice Updated'));
      expect(effectLogs, equals(['Item 1: Alice', 'Item 1: Alice Updated']));

      // Switch selectedId
      selectedId.data = 2;
      await Future<void>.delayed(Duration.zero);
      expect(summary.peek, equals('Summary: Item 2: Bob'));
      expect(effectLogs, equals(['Item 1: Alice', 'Item 1: Alice Updated', 'Item 2: Bob']));

      dispose();
    });

    test('what.switched dynamically switches target pure What based on reactive state', () {
      final isDark = WhatController(false);
      final lightThemeWhat = What.constant('Pure Light What');
      final darkThemeWhat = What.constant('Pure Dark What');

      final activeTheme = switched((via) {
        return via(isDark.what) ? darkThemeWhat : lightThemeWhat;
      });

      expect(activeTheme.peek, equals('Pure Light What'));

      isDark.data = true;
      expect(activeTheme.peek, equals('Pure Dark What'));

      isDark.data = false;
      expect(activeTheme.peek, equals('Pure Light What'));
    });

    test('what.switched handles errors safely and recovers', () {
      final shouldFail = WhatController(true);

      final switchedWhat = switched<int>((via) {
        if (via(shouldFail.what)) {
          throw Exception('Switch failed!');
        }
        return WhatController(100).what;
      });

      expect(switchedWhat.peekState.hasError, isTrue);
      expect(() => switchedWhat.peek, throwsA(isA<WhatSnapshotExtractionException>()));

      // Recovery
      shouldFail.data = false;
      expect(switchedWhat.peekState.hasError, isFalse);
      expect(switchedWhat.peek, equals(100));
    });

    test('what.switched dynamically synchronizes version when switched branch is lazy computed', () {
      final selector = WhatController('A');
      final rootA = WhatController(10);
      final rootB = WhatController(20);

      var computedRunsA = 0;
      final lazyA = computed((via) {
        computedRunsA++;
        return via(rootA.what) * 2;
      });

      var computedRunsB = 0;
      final lazyB = computed((via) {
        computedRunsB++;
        return via(rootB.what) * 3;
      });

      final switchedWhat = switched((via) {
        final key = via(selector.what);
        return key == 'A' ? lazyA : lazyB;
      });

      // Downstream computed watching switchedWhat
      var downstreamRuns = 0;
      final downstream = computed((via) {
        downstreamRuns++;
        return 'Value: ${via(switchedWhat)}';
      });

      // Initial read
      expect(downstream.peek, equals('Value: 20')); // 10 * 2
      expect(computedRunsA, equals(1));
      expect(computedRunsB, equals(0));
      expect(downstreamRuns, equals(1));

      // Mutate rootA -> downstream must update
      rootA.data = 15;
      expect(downstream.peek, equals('Value: 30')); // 15 * 2
      expect(computedRunsA, equals(2));
      expect(downstreamRuns, equals(2));

      // Switch to B (which is uncomputed lazy node)
      selector.data = 'B';
      expect(downstream.peek, equals('Value: 60')); // 20 * 3
      expect(computedRunsB, equals(1));
      expect(downstreamRuns, equals(3));

      // Mutate rootB -> downstream must update via updated version
      rootB.data = 30;
      expect(downstream.peek, equals('Value: 90')); // 30 * 3
      expect(computedRunsB, equals(2));
      expect(downstreamRuns, equals(4));
    });
  });

  group('Dynamic List What.computed Comprehensive Unit Tests', () {
    test('What.computed dynamically generates collection of Whats (e.g. Nasdaq items)', () {
      final count = WhatController(3);
      final codes = ['AAPL', 'GOOGL', 'MSFT', 'AMZN', 'NVDA'];
      final priceRubies = codes.map((code) => WhatController(100)).toList();

      final group = computed((via) {
        final currentCount = via(count.what);
        return List.generate(currentCount, (i) => priceRubies[i].what);
      });

      expect(group.peek.length, equals(3));
      expect(group.sum().peek, equals(300)); // 100 + 100 + 100

      // Mutate individual item price
      priceRubies[0].data = 150;
      expect(group.sum().peek, equals(350)); // 150 + 100 + 100

      // Increase count to 5
      count.data = 5;
      expect(group.peek.length, equals(5));
      expect(group.sum().peek, equals(550)); // 150 + 100 + 100 + 100 + 100

      // Decrease count to 2
      count.data = 2;
      expect(group.peek.length, equals(2));
      expect(group.sum().peek, equals(250)); // 150 + 100
    });

    test('What.computed on What list combines elements reactively', () {
      final count = WhatController(2);
      final items = [WhatController('A'), WhatController('B'), WhatController('C')];

      final group = computed((via) {
        return List.generate(via(count.what), (i) => items[i].what);
      });

      final combined = group.combine();
      expect(combined.peek, equals(['A', 'B']));

      // Mutate item
      items[0].data = 'Alpha';
      expect(combined.peek, equals(['Alpha', 'B']));

      // Increase count
      count.data = 3;
      expect(combined.peek, equals(['Alpha', 'B', 'C']));
    });

    test('What.computed works with generic What elements', () {
      final count = WhatController(2);
      final nodeA = What.constant(10);
      final nodeB = What.constant(20);
      final nodeC = What.constant(30);
      final allNodes = [nodeA, nodeB, nodeC];

      final group = computed((via) {
        return List.generate(via(count.what), (i) => allNodes[i]);
      });

      expect(group.peek.length, equals(2));
      expect(group.peek, equals([nodeA, nodeB]));

      count.data = 3;
      expect(group.peek.length, equals(3));
      expect(group.peek, equals([nodeA, nodeB, nodeC]));
    });

    test('What.computed on What list handles error states and recovers', () {
      final shouldFail = WhatController(true);

      final group = computed<List<What<int>>>((via) {
        if (via(shouldFail.what)) {
          throw Exception('Failed to generate group!');
        }
        return [WhatController(1).what, WhatController(2).what];
      });

      expect(group.peekState.hasError, isTrue);
      expect(() => group.peek, throwsA(isA<WhatSnapshotExtractionException>()));

      // Recovery
      shouldFail.data = false;
      expect(group.peekState.hasError, isFalse);
      expect(group.peek.length, equals(2));
      expect(group.sum().peek, equals(3));
    });
  });
}
