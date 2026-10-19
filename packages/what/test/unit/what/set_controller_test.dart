// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

void main() {
  group('WhatSetController & Reactive Set Evolution Tests', () {
    // =========================================================================
    // 1. Instantiation & Factory Constructors
    // =========================================================================
    group('1. Instantiation & Factory Constructors', () {
      test('1.1 WhatSetController default factory creates unmodifiable set', () {
        final controller = WhatSetController<int>({1, 2, 3});

        expect(controller.hasData, isTrue);
        expect(controller.data, equals({1, 2, 3}));
        expect(controller.what.peek, equals({1, 2, 3}));

        // Immutability check: data must be unmodifiable
        expect(() => controller.data.add(4), throwsUnsupportedError);
      });

      test('1.2 WhatSetController empty explicit initialization', () {
        final controller = WhatSetController<String>({});

        expect(controller.hasData, isTrue);
        expect(controller.data, isEmpty);
      });

      test('1.3 WhatSetController.late initialization', () {
        final controller = WhatSetController<int>.late();

        expect(controller.isEmpty, isTrue);
        expect(controller.hasData, isFalse);
        expect(() => controller.data, throwsA(isA<WhatSnapshotExtractionException>()));

        controller.set({10, 20});
        expect(controller.hasData, isTrue);
        expect(controller.data, equals({10, 20}));
      });

      test('1.4 WhatSetController.error initialization', () {
        final controller = WhatSetController<int>.error('Failed to load set');

        expect(controller.hasError, isTrue);
        expect(controller.hasData, isFalse);
        expect(controller.error, equals('Failed to load set'));
      });
    });

    // =========================================================================
    // 2. Immutable Whole Replacement (.set, .data =)
    // =========================================================================
    group('2. Immutable Whole Replacement (.set, .data =)', () {
      test('2.1 Whole replacement updates payload and notifies downstream', () {
        final controller = WhatSetController<int>({1, 2});
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        expect(notifyCount, equals(0));

        controller.set({3, 4, 5});
        expect(notifyCount, equals(1));
        expect(controller.data, equals({3, 4, 5}));

        controller.data = {6};
        expect(notifyCount, equals(2));
        expect(controller.data, equals({6}));

        terminal.deactivate();
      });

      test('2.2 _setEquals suppresses redundant Push-Dirty pulses on identical elements', () {
        final controller = WhatSetController<int>({1, 2, 3});
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        // Assigning a new set instance with identical elements
        controller.set({1, 2, 3});
        expect(notifyCount, equals(0), reason: 'Identical elements must suppress dirty pulse');

        controller.data = {3, 2, 1};
        expect(notifyCount, equals(0), reason: 'Different order but same set elements must suppress dirty pulse');

        // Modifying one element must trigger notification
        controller.set({1, 2, 4});
        expect(notifyCount, equals(1));

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 3. Transactional Draft Edit (.edit((draft) => ...))
    // =========================================================================
    group('3. Transactional Draft Edit (.edit)', () {
      test('3.1 Single draft modification applies atomically and freezes result', () {
        final controller = WhatSetController<String>({'alpha'});
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        controller.edit((draft) {
          draft.add('beta');
        });

        expect(notifyCount, equals(1));
        expect(controller.data, equals({'alpha', 'beta'}));
        expect(() => controller.data.add('gamma'), throwsUnsupportedError);

        terminal.deactivate();
      });

      test('3.2 Multiple operations inside edit emit AT MOST 1 dirty pulse (Atomic Commit)', () {
        final controller = WhatSetController<int>({5, 3, 1});
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        controller.edit((draft) {
          draft.add(4);
          draft.add(2);
          draft.remove(5);
        });

        expect(notifyCount, equals(1));
        expect(controller.data, equals({3, 1, 4, 2}));

        terminal.deactivate();
      });

      test('3.3 No-op edit suppresses Push-Dirty pulse completely', () {
        final controller = WhatSetController<int>({10, 20});
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        controller.edit((draft) {
          // Adding already existing item
          draft.add(10);
        });

        expect(notifyCount, equals(0), reason: 'No-op edit must not emit dirty pulse');
        terminal.deactivate();
      });

      test('3.4 edit on late() controller starts with empty set', () {
        final controller = WhatSetController<int>.late();
        expect(controller.isEmpty, isTrue);

        controller.edit((draft) {
          draft.add(999);
        });

        expect(controller.hasData, isTrue);
        expect(controller.data, equals({999}));
      });

      test('3.5 edit on error controller transitions to valid data', () {
        final controller = WhatSetController<int>.error('Initial error');
        expect(controller.hasError, isTrue);

        controller.edit((draft) {
          draft.add(100);
        });

        expect(controller.hasData, isTrue);
        expect(controller.data, equals({100}));
      });

      test('3.6 edit failure preserves original state and rethrows (Atomicity / Rollback)', () {
        final controller = WhatSetController<int>({1, 2, 3});
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        expect(
          () => controller.edit((draft) {
            draft.add(4);
            throw StateError('Recipe transaction boom!');
          }),
          throwsA(isA<StateError>()),
        );

        // State must remain intact and no dirty pulses must be emitted
        expect(notifyCount, equals(0));
        expect(controller.data, equals({1, 2, 3}));

        terminal.deactivate();
      });

      test('3.7 editGuarded successfully updates payload and notifies', () {
        final controller = WhatSetController<String>({'a'});
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        controller.editGuarded((draft) {
          draft.add('b');
        });

        expect(notifyCount, equals(1));
        expect(controller.data, equals({'a', 'b'}));

        terminal.deactivate();
      });

      test('3.8 editGuarded catches exception and safely transitions to error state', () {
        final controller = WhatSetController<int>({10, 20});
        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () {
          notifyCount++;
        });
        terminal.activate();

        // Must not throw in caller stack
        controller.editGuarded((draft) {
          draft.add(30);
          throw FormatException('Malformed element');
        });

        expect(notifyCount, equals(1));
        expect(controller.hasError, isTrue);
        expect(controller.hasData, isFalse);
        expect(controller.error, isA<FormatException>());

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 4. Downstream Pipeline & ComputedWhat Integration
    // =========================================================================
    group('4. Downstream Pipeline & ComputedWhat Integration', () {
      test('4.1 ComputedWhat seamlessly tracks WhatSetController edits', () {
        final tags = WhatSetController<String>({'tag1'});
        final count = computed((via) => via(tags.what).length);
        final containsTag2 = computed((via) => via(tags.what).contains('tag2'));

        final terminal = RawWhatTerminal(count, onInvalidated: () {});
        terminal.activate();

        expect(count.peek, equals(1));
        expect(containsTag2.peek, isFalse);

        tags.edit((draft) {
          draft.add('tag2');
          draft.add('tag3');
        });

        expect(count.peek, equals(3));
        expect(containsTag2.peek, isTrue);

        terminal.deactivate();
      });
    });

    // =========================================================================
    // 5. Custom Equality for Nested Collections
    // =========================================================================
    group('5. Custom Equality for Nested Collections', () {
      bool deepSetEquals(Set<Set<int>> a, Set<Set<int>> b) {
        if (identical(a, b)) return true;
        if (a.length != b.length) return false;
        for (final setA in a) {
          final found = b.any((setB) => setA.length == setB.length && setA.every(setB.contains));
          if (!found) return false;
        }
        return true;
      }

      test('5.1 Custom equals suppresses dirty pulses when nested sets are equal', () {
        final controller = WhatSetController<Set<int>>(
          {
            {1, 2},
          },
          equals: deepSetEquals,
        );

        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () => notifyCount++);
        terminal.activate();

        controller.set({
          {1, 2},
        });
        expect(notifyCount, equals(0));

        controller.set({
          {1, 3},
        });
        expect(notifyCount, equals(1));

        terminal.deactivate();
      });

      test('5.2 WhatSetController.late propagates custom equals comparator', () {
        final controller = WhatSetController<Set<int>>.late(
          equals: deepSetEquals,
        );

        var notifyCount = 0;
        final terminal = RawWhatTerminal(controller.what, onInvalidated: () => notifyCount++);
        terminal.activate();

        controller.set({
          {10},
        });
        expect(notifyCount, equals(1));

        // Setting identical nested contents must not notify
        controller.set({
          {10},
        });
        expect(notifyCount, equals(1));

        // Setting different nested contents must notify
        controller.set({
          {20},
        });
        expect(notifyCount, equals(2));

        terminal.deactivate();
      });
    });
  });
}
