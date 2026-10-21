// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';
import 'package:test/test.dart';
import '../../test_utils.dart';

void main() {
  group('What State & Node switch (phase) Pattern Matching Tests', () {
    test('1. Valid, Late, Error WhatController branching with switch (phase)', () {
      final validWhat = WhatController('Lotus');
      final lateWhat = WhatController<String>.late();
      final errorWhat = What<String>.error('error payload');

      final validLabel = switch (validWhat.phase) {
        WhatPhase.valid => 'Data: ${validWhat.data}',
        WhatPhase.empty => 'Empty',
        WhatPhase.error => 'Error: ${validWhat.error}',
      };
      expect(validLabel, 'Data: Lotus');

      final lateLabel = switch (lateWhat.phase) {
        WhatPhase.valid => 'Data: ${lateWhat.data}',
        WhatPhase.empty => 'Empty',
        WhatPhase.error => 'Error: ${lateWhat.error}',
      };
      expect(lateLabel, 'Empty');

      final errorState = untracked.state(errorWhat);
      final errorLabel = switch (errorState.phase) {
        WhatPhase.valid => 'Data: ${errorState.data}',
        WhatPhase.empty => 'Empty',
        WhatPhase.error => 'Error: ${errorState.error}',
      };
      expect(errorLabel, 'Error: error payload');
    });

    test('2. Fallback branching with hasData ternary', () {
      final validWhat = WhatController('Lotus');
      final lateWhat = WhatController<String>.late();

      final validResult = validWhat.hasData ? 'Value: ${validWhat.data}' : 'Fallback';
      expect(validResult, 'Value: Lotus');

      final lateResult = lateWhat.hasData ? 'Value: ${lateWhat.data}' : 'Fallback';
      expect(lateResult, 'Fallback');
    });

    test('3. Conditional null-coalescing extraction with hasData / hasError / dataOrNull', () {
      final validWhat = WhatController('Lotus');
      final lateWhat = WhatController<String>.late();
      final errorWhat = What<String>.error('error payload');

      // Idiomatic ternary extraction via hasData / hasError
      final validLen = validWhat.hasData ? validWhat.data.length : null;
      expect(validLen, 5);

      final lateLen = lateWhat.hasData ? lateWhat.data.length : null;
      expect(lateLen, isNull);

      final errorState = untracked.state(errorWhat);
      final errVal = errorState.hasError ? errorState.error : null;
      expect(errVal, 'error payload');

      // Direct optional null-safe access via dataOrNull
      expect(validWhat.dataOrNull?.length, 5);
      expect(lateWhat.dataOrNull?.length, isNull);
    });

    test('4. Auto-tracking inside computed() when branching on switch (via.state.phase)', () {
      final count = WhatController(10);

      final statusMessage = computed((via) {
        final state = via.state(count.what);
        return switch (state.phase) {
          WhatPhase.valid => 'Count is ${state.data}',
          WhatPhase.empty => 'No count',
          WhatPhase.error => 'Count error',
        };
      });

      expect(untracked(statusMessage), 'Count is 10');

      count.data = 20;
      expect(untracked(statusMessage), 'Count is 20');
    });

    test('5. Auto-tracking inside effect() when reading via.state with hasData ternary', () async {
      final text = WhatController('Initial');
      final logs = <String>[];

      final dispose = effect((WhatVia via) {
        final state = via.state(text.what);
        logs.add(state.hasData ? 'Logged: ${state.data}' : 'Logged: None');
      });

      // Initial execution happened synchronously or microtask
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(logs, contains('Logged: Initial'));

      text.data = 'Updated';
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(logs, contains('Logged: Updated'));

      dispose();
    });

    test('6. What list untracked.state branching with switch (phase)', () {
      final r1 = WhatController(10);
      final r2 = WhatController(20);
      final group = What.constant([r1.what, r2.what]);

      final state = untracked.state(group);
      final result = switch (state.phase) {
        WhatPhase.valid => state.data.length,
        WhatPhase.empty => 0,
        WhatPhase.error => -1,
      };
      expect(result, 2);
    });
  });
}
