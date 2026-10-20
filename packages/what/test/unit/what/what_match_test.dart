// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';
import '../../test_utils.dart';

void main() {
  group('What.match / matchOrElse / matchOrNull Tests', () {
    test('1. Valid, Late, Error WhatController branching with match', () {
      final validWhat = WhatController('Lotus');
      final lateWhat = WhatController<String>.late();
      final errorWhat = What<String>.error('error payload');

      expect(
        validWhat.match(
          data: (val) => 'Data: $val',
          empty: () => 'Empty',
          error: (e, s) => 'Error: $e',
        ),
        'Data: Lotus',
      );

      expect(
        lateWhat.match(
          data: (val) => 'Data: $val',
          empty: () => 'Empty',
          error: (e, s) => 'Error: $e',
        ),
        'Empty',
      );

      expect(
        untracked.state(errorWhat).match(
          data: (val) => 'Data: $val',
          empty: () => 'Empty',
          error: (e, s) => 'Error: $e',
        ),
        'Error: error payload',
      );
    });

    test('2. WhatController branching with matchOrElse', () {
      final validWhat = WhatController('Lotus');
      final lateWhat = WhatController<String>.late();

      expect(
        validWhat.matchOrElse(
          data: (val) => 'Value: $val',
          orElse: () => 'Fallback',
        ),
        'Value: Lotus',
      );

      expect(
        lateWhat.matchOrElse(
          data: (val) => 'Value: $val',
          orElse: () => 'Fallback',
        ),
        'Fallback',
      );
    });

    test('3. WhatController branching with matchOrNull', () {
      final validWhat = WhatController('Lotus');
      final lateWhat = WhatController<String>.late();
      final errorWhat = What<String>.error('error payload');

      expect(validWhat.matchOrNull(data: (val) => val.length), 5);
      expect(lateWhat.matchOrNull(data: (val) => val.length), isNull);
      expect(untracked.state(errorWhat).matchOrNull(error: (e, s) => e), 'error payload');
    });

    test('4. Auto-tracking inside computed() when calling .match()', () {
      final count = WhatController(10);

      final statusMessage = computed((via) {
        return via.state(count.what).match(
              data: (val) => 'Count is $val',
              empty: () => 'No count',
              error: (e, s) => 'Count error',
            );
      });

      expect(untracked(statusMessage), 'Count is 10');

      count.data = 20;
      expect(untracked(statusMessage), 'Count is 20');
    });

    test('5. Auto-tracking inside effect() when calling .matchOrElse()', () async {
      final text = WhatController('Initial');
      final logs = <String>[];

      final dispose = effect((WhatVia via) {
        logs.add(
          via.state(text.what).matchOrElse(
                data: (val) => 'Logged: $val',
                orElse: () => 'Logged: None',
              ),
        );
      });

      // Initial execution happened synchronously or microtask
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(logs, contains('Logged: Initial'));

      text.data = 'Updated';
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(logs, contains('Logged: Updated'));

      dispose();
    });

    test('6. What list match, matchOrElse, matchOrNull', () {
      final r1 = WhatController(10);
      final r2 = WhatController(20);
      final group = What.constant([r1.what, r2.what]);

      final result = untracked.state(group).match(
        data: (whats) => whats.length,
        empty: () => 0,
        error: (e, s) => -1,
      );
      expect(result, 2);

      expect(untracked.state(group).matchOrElse(data: (g) => g.length, orElse: () => 0), 2);
      expect(untracked.state(group).matchOrNull(data: (g) => g.length), 2);
    });
  });
}
