// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

class _MutableKeyItem {
  _MutableKeyItem(this.id, this.val);

  String id;
  int val;
}

class _FixedHashItem {
  const _FixedHashItem(this.id, this.val);

  final String id;
  final int val;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FixedHashItem && runtimeType == other.runtimeType && id == other.id && val == other.val;

  @override
  int get hashCode => 42; // Force 100% hash collision
}

void main() {
  group('Collection Churn, Keyed Retention & Hash Stress Suite', () {
    // =========================================================================
    // 1. In-Place Mutation & High-Throughput Keyed Churn
    // =========================================================================
    group('1. In-Place Mutation & High-Throughput Churn', () {
      test('1.1 In-Place Mutation of Cached Items in keyed.map', () {
        final item1 = _MutableKeyItem('k1', 10);
        final item2 = _MutableKeyItem('k2', 20);

        final controller = WhatController<List<_MutableKeyItem>>([item1, item2]);
        final convertCounts = <String, int>{};

        final keyedMapped = controller.what.keyed.map(
          key: (item) => item.id,
          convert: (item) {
            convertCounts[item.id] = (convertCounts[item.id] ?? 0) + 1;
            return 'Converted_${item.id}_${item.val}';
          },
        );

        final terminal = RawWhatTerminal(keyedMapped, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data, ['Converted_k1_10', 'Converted_k2_20']);
        expect(convertCounts, {'k1': 1, 'k2': 1});

        // Mutate item1.val in place without changing key -> cached conversion is preserved
        item1.val = 999;
        controller.set([item1, item2]);
        expect(terminal.data, ['Converted_k1_10', 'Converted_k2_20']);
        expect(convertCounts['k1'], 1);

        // Mutate item1.id to a new key -> triggers conversion for new key
        item1.id = 'k1_mutated';
        controller.set([item1, item2]);
        expect(terminal.data, ['Converted_k1_mutated_999', 'Converted_k2_20']);
        expect(convertCounts['k1_mutated'], 1);

        terminal.deactivate();
      });

      test('1.2 High-Throughput Oscillating Churn (1,000 Key Oscillations)', () {
        final controller = WhatController<List<int>>([]);
        int totalConversions = 0;

        final keyed = controller.what.keyed.map(
          key: (i) => i,
          convert: (i) {
            totalConversions++;
            return 'Item_$i';
          },
        );

        final terminal = RawWhatTerminal(keyed, onInvalidated: () {});
        terminal.activate();

        for (var cycle = 0; cycle < 100; cycle++) {
          // Expand to 50 items (0..49)
          controller.set(List.generate(50, (i) => i));
          expect(terminal.data.length, 50);

          // Shrink to 5 items (0..4) -> triggers pigeonhole sweep for 5..49
          controller.set(List.generate(5, (i) => i));
          expect(terminal.data.length, 5);

          // Expand to 100 items (0..99)
          controller.set(List.generate(100, (i) => i));
          expect(terminal.data.length, 100);

          // Empty -> cache is wiped
          controller.set([]);
          expect(terminal.data, isEmpty);
        }

        expect(totalConversions, greaterThan(0));
        terminal.deactivate();
      });
    });

    // =========================================================================
    // 2. 100% Hash Collision Attack Resilience
    // =========================================================================
    group('2. 100% Hash Collision Resilience', () {
      test('2.1 Keyed map correctly differentiates colliding hash items', () {
        final items = List.generate(50, (i) => _FixedHashItem('id_$i', i * 10));
        final controller = WhatController<List<_FixedHashItem>>(items);

        final keyed = controller.what.keyed.map(
          key: (item) => item,
          convert: (item) => 'Rendered_${item.id}_${item.val}',
        );

        final terminal = RawWhatTerminal(keyed, onInvalidated: () {});
        terminal.activate();

        expect(terminal.data.length, 50);
        for (int i = 0; i < 50; i++) {
          expect(terminal.data[i], 'Rendered_id_${i}_${i * 10}');
        }

        // Shuffle items with 100% hash collision
        final shuffled = List<_FixedHashItem>.from(items.reversed);
        controller.set(shuffled);

        expect(terminal.data.length, 50);
        expect(terminal.data.first, 'Rendered_id_49_490');
        expect(terminal.data.last, 'Rendered_id_0_0');

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. 2D Reactive What Matrix
    // =========================================================================
    group('3. 2D Reactive What Matrix', () {
      test('3.1 Higher-Order What List of Lists with Localized Invalidation', () {
        const rows = 3;
        const cols = 3;

        final matrixControllers = List.generate(
          rows,
          (r) => List.generate(cols, (c) => WhatController<int>((r + 1) * 10 + (c + 1))),
        );

        final rowGroups = matrixControllers.map((row) => What.constant(row.map((ctrl) => ctrl.what))).toList();

        final matrixGroup = What.constant(rowGroups);

        final matrixSum = computed((via) {
          int total = 0;
          for (final row in via(matrixGroup)) {
            total += via(row).fold<int>(0, (sum, g) => sum + via(g));
          }
          return total;
        });

        final terminal = RawWhatTerminal(matrixSum, onInvalidated: () {});
        terminal.activate();

        // Initial sum of 3x3 matrix:
        // [11, 12, 13] = 36
        // [21, 22, 23] = 66
        // [31, 32, 33] = 96
        // Total = 198
        expect(terminal.data, 198);

        // Mutate single cell [1][1] from 22 -> 100 (diff +78)
        matrixControllers[1][1].set(100);

        expect(terminal.data, 276); // 198 + 78

        terminal.deactivate();
      });
    });
  });
}
