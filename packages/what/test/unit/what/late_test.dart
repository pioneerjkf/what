// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';
import '../../test_utils.dart';

void main() {
  group('What.late / what.late', () {
    test('starts in empty uninitialized state and fails fast on .data', () {
      final user = WhatController<String>.late();

      expect(user.isEmpty, isTrue);
      expect(user.hasData, isFalse);
      expect(user.dataOrNull, isNull);
      expect(() => user.data, throwsA(isA<WhatSnapshotExtractionException>()));
      expect(user.dataOrElse(() => 'fallback'), 'fallback');
    });

    test('populates value and transitions to available state', () {
      final user = WhatController<String>.late();

      user.data = 'Alice';

      expect(user.isEmpty, isFalse);
      expect(user.hasData, isTrue);
      expect(user.data, 'Alice');
      expect(user.dataOrNull, 'Alice');
    });

    test('respects distinct setting when populated', () async {
      final data = WhatController<int>.late();

      var effectRuns = 0;
      int? lastVal;

      final dispose = effect((via) {
        effectRuns++;
        lastVal = via.state(data.what).dataOrNull;
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(lastVal, isNull);

      // Populate value
      data.data = 100;
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(lastVal, 100);

      // Set same value -> distinct prevents effect re-execution
      data.data = 100;
      await Future.microtask(() {});

      expect(effectRuns, 2);

      dispose();
    });

    test('late with raw triggers effect on same value assignments', () async {
      final lateSignal = WhatController<int>.late(distinct: false);

      var effectRuns = 0;
      final dispose = effect((via) {
        effectRuns++;
        via.state(lateSignal.what).dataOrNull;
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);

      lateSignal.data = 1;
      await Future.microtask(() {});
      expect(effectRuns, 2);

      lateSignal.data = 1; // Same value with distinct=false
      await Future.microtask(() {});
      expect(effectRuns, 3); // Re-executed!

      dispose();
    });

    test('late works reactively inside computed before and after population', () {
      final lateSignal = WhatController<int>.late();
      final multiplied = computed((via) => (via.state(lateSignal.what).dataOrNull ?? 0) * 10);

      expect(untracked(multiplied), 0);

      lateSignal.data = 5;
      expect(untracked(multiplied), 50);

      lateSignal.data = 8;
      expect(untracked(multiplied), 80);
    });
  });
}
