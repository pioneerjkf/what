// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';

void main() {
  group('Inactive Node Multi-Read Edge Deduplication & Reuse Tests', () {
    test('Inactive computed node must not create duplicate edges when reading same source multiple times', () {
      final source = WhatController<int>(10);

      // Inactive computed reading the same dependency multiple times
      final doubleCount = computed((via) => via(source.what) + via(source.what));

      // 1. Initial evaluation while inactive
      expect(doubleCount.peek, 20);

      // 2. Verification: Despite multiple reads in the computation body,
      // the unique upstream dependency count must strictly be 1.
      expect(
        doubleCount.debug.sourceCount,
        1,
        reason:
            'Evaluating an inactive computed node with multiple reads of the same source must not create duplicate edges.',
      );

      // 3. Re-evaluation on source mutation while still inactive
      source.set(25);
      expect(doubleCount.peek, 50);
      expect(
        doubleCount.debug.sourceCount,
        1,
        reason: 'Re-evaluating must reuse existing source edge without leaking duplicates.',
      );
    });

    test('Inactive computed node with 5 reads of the same source maintains exactly 1 edge', () {
      final source = WhatController<int>(2);

      final quintuple = computed((via) {
        var sum = 0;
        for (var i = 0; i < 5; i++) {
          sum += via(source.what);
        }
        return sum;
      });

      expect(quintuple.peek, 10);
      expect(
        quintuple.debug.sourceCount,
        1,
        reason: 'Looping 5 times over the same source in inactive mode must only register 1 edge.',
      );
    });
  });
}
