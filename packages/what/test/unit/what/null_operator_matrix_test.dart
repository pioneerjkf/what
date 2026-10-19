// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('What Sound Null-Safety, 3-State Exclusivity & Safe Extraction Matrix', () {
    group('1. Sound Null Safety (Valid Null vs Empty vs Error)', () {
      test('1.1 Valid What holding explicit null is not empty and not in error', () {
        final nullableWhat = WhatController<String?>(null);

        expect(nullableWhat.hasData, isTrue);
        expect(nullableWhat.isEmpty, isFalse);
        expect(nullableWhat.hasError, isFalse);
        expect(nullableWhat.data, isNull);
        expect(nullableWhat.dataOrNull, isNull);
        expect(nullableWhat.dataOrElse(() => 'fallback'), isNull);
        expect(nullableWhat.snapshot.hasData, isTrue);
      });

      test('1.2 What.late is strictly empty and fails fast on .data access', () {
        final lateWhat = WhatController<String?>.late();

        expect(lateWhat.hasData, isFalse);
        expect(lateWhat.isEmpty, isTrue);
        expect(lateWhat.hasError, isFalse);
        expect(lateWhat.snapshot.isEmpty, isTrue);

        // Fail-fast on .data
        expect(
          () => lateWhat.data,
          throwsA(isA<WhatSnapshotExtractionException>()),
        );

        // Safe accessors
        expect(lateWhat.dataOrNull, isNull);
        expect(lateWhat.dataOrElse(() => 'safe-default'), 'safe-default');

        // Populate late what
        lateWhat.data = null;
        expect(lateWhat.hasData, isTrue);
        expect(lateWhat.isEmpty, isFalse);
        expect(lateWhat.data, isNull);
      });

      test('1.3 What.error is strictly error and fails fast on .data access', () {
        final errorWhat = What<int>.error(
          FormatException('Invalid payload format'),
        );

        expect(errorWhat.peekState.hasData, isFalse);
        expect(errorWhat.peekState.isEmpty, isFalse);
        expect(errorWhat.peekState.hasError, isTrue);
        expect(errorWhat.peekState.snapshot.hasError, isTrue);

        // Fail-fast on .data
        expect(
          () => errorWhat.peek,
          throwsA(isA<WhatSnapshotExtractionException>()),
        );

        // Safe accessors
        expect(errorWhat.peekState.dataOrNull, isNull);
        expect(errorWhat.peekState.dataOrElse(() => 999), 999);
      });
    });

    group('2. Nullable Combinators & Transformations on What', () {
      test('2.1 computed with nullable data flows', () {
        final source = WhatController<String?>('apple');

        final uppercaseWhat = computed((via) => via(source.what)?.toUpperCase());
        final lengthWhat = computed((via) => via(source.what)?.length ?? 0);

        expect(uppercaseWhat.peek, 'APPLE');
        expect(lengthWhat.peek, 5);

        // Mutate to null
        source.data = null;
        expect(uppercaseWhat.peek, isNull);
        expect(lengthWhat.peek, 0);

        // Mutate back to non-null
        source.data = 'banana';
        expect(uppercaseWhat.peek, 'BANANA');
        expect(lengthWhat.peek, 6);
      });

      test('2.2 fallback recovery on nullable What', () {
        final lateWhat = WhatController<String?>.late();

        final fallbackToNull = computed<String?>((via) => via.state(lateWhat.what).hasData ? via(lateWhat.what) : null);
        expect(fallbackToNull.peekState.hasData, isTrue);
        expect(fallbackToNull.peek, isNull);

        final safeFallback = computed((via) => via.state(lateWhat.what).dataOrElse(() => 'default-val'));
        expect(safeFallback.peek, 'default-val');

        // Populate with null
        lateWhat.data = null;
        expect(fallbackToNull.peek, isNull);
        expect(safeFallback.peek, isNull); // valid payload is preserved
      });

      test('2.3 guard conditionally gates computed', () {
        final count = WhatController<int>(10);
        final canProceed = WhatController(true);

        final guarded = computed(
          (via) => via(count.what),
          guard: (via) => via(canProceed.what).guarded('Blocked by security guard'),
        );

        expect(guarded.peekState.hasData, isTrue);
        expect(guarded.peek, 10);

        // Block
        canProceed.data = false;
        count.data = 20;

        expect(guarded.peekState.isEmpty, isTrue);
        expect(guarded.peekState.hasData, isFalse);
        expect(guarded.peekState.snapshot.emptyReason, 'Blocked by security guard');
        expect(
          () => guarded.peek,
          throwsA(isA<WhatSnapshotExtractionException>()),
        );

        // Restore
        canProceed.data = true;
        count.data = 30;
        expect(guarded.peekState.hasData, isTrue);
        expect(guarded.peek, 30);
      });
    });
  });
}
