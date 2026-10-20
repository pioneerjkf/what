import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';

// Custom Listenable to test distinct behavior without ValueNotifier's built-in distinct logic
class CustomListenable<T> extends ChangeNotifier implements ValueListenable<T> {
  CustomListenable(this._value);

  T _value;

  @override
  T get value => _value;

  set value(T newValue) {
    _value = newValue;
    notifyListeners();
  }
}

// Custom multi-field ChangeNotifier to test Selector behavior via toWhatBy
class TestUserModel extends ChangeNotifier {
  TestUserModel({required this.name, required this.age});

  String name;
  int age;

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }

  void updateAge(int newAge) {
    age = newAge;
    notifyListeners();
  }

  void triggerNotification() {
    notifyListeners();
  }
}

void main() {
  group('change_notifier.dart - ValueListenableWhatExtension (toWhat)', () {
    test('Subscription lifecycle (Activate/Deactivate)', () {
      final notifier = ValueNotifier<int>(0);
      final node = notifier.toWhat();

      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, false);

      // Activate
      final terminal = RawWhatTerminal(node, onInvalidated: () {});
      terminal.activate();

      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, true);

      // Deactivate
      terminal.deactivate();
      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, false);
    });

    test('Value updates and state propagation', () {
      final notifier = ValueNotifier<String>('A');
      final node = notifier.toWhat();

      final emittedValues = <String>[];
      final terminal = RawWhatTerminal(node, onInvalidated: () {
        emittedValues.add(untracked(node));
      });
      terminal.activate();
      emittedValues.add(untracked(node));

      expect(emittedValues, ['A']);

      notifier.value = 'B';
      expect(emittedValues, ['A', 'B']);

      notifier.value = 'C';
      expect(emittedValues, ['A', 'B', 'C']);

      terminal.deactivate();
    });

    test('Distinct behavior (true by default)', () {
      final listenable = CustomListenable<int>(1);
      final node = listenable.toWhat(); // distinct: true

      final emittedValues = <int>[];
      final terminal = RawWhatTerminal(node, onInvalidated: () {
        emittedValues.add(untracked(node));
      });
      terminal.activate();
      emittedValues.add(untracked(node));

      expect(emittedValues, [1]);

      listenable.value = 1; // Notifies, but What should distinct it
      expect(emittedValues, [1]);

      listenable.value = 2;
      expect(emittedValues, [1, 2]);

      terminal.deactivate();
    });

    test('Distinct behavior (false)', () {
      final listenable = CustomListenable<int>(1);
      final node = listenable.toWhat(distinct: false);

      final emittedValues = <int>[];
      final terminal = RawWhatTerminal(node, onInvalidated: () {
        emittedValues.add(untracked(node));
      });
      terminal.activate();
      emittedValues.add(untracked(node));

      expect(emittedValues, [1]);

      listenable.value = 1; // Notifies, and What should NOT distinct it
      expect(emittedValues, [1, 1]);

      listenable.value = 2;
      expect(emittedValues, [1, 1, 2]);

      terminal.deactivate();
    });

    test('Distinct behavior with custom equals', () {
      final listenable = CustomListenable<int>(1);
      final node = listenable.toWhat(
        equals: (a, b) => a % 2 == b % 2,
      );

      final emittedValues = <int>[];
      final terminal = RawWhatTerminal(node, onInvalidated: () {
        emittedValues.add(untracked(node));
      });
      terminal.activate();
      emittedValues.add(untracked(node));

      expect(emittedValues, [1]);

      listenable.value = 3;
      expect(emittedValues, [1]);

      listenable.value = 2;
      expect(emittedValues, [1, 2]);

      listenable.value = 4;
      expect(emittedValues, [1, 2]);

      terminal.deactivate();
    });

    test('Nullable ValueNotifier handling (null -> value -> null)', () {
      final notifier = ValueNotifier<int?>(null);
      final node = notifier.toWhat();

      final emittedValues = <int?>[];
      final terminal = RawWhatTerminal(node, onInvalidated: () {
        emittedValues.add(untracked(node));
      });
      terminal.activate();
      emittedValues.add(untracked(node));

      expect(emittedValues, [null]);

      notifier.value = 42;
      expect(emittedValues, [null, 42]);

      notifier.value = null;
      expect(emittedValues, [null, 42, null]);

      terminal.deactivate();
    });

    test('Multiple activation and deactivation cycles', () {
      final notifier = ValueNotifier<String>('Initial');
      final node = notifier.toWhat();

      final terminal = RawWhatTerminal(node, onInvalidated: () {});

      terminal.activate();
      expect(untracked(node), 'Initial');
      terminal.deactivate();

      notifier.value = 'Updated While Dormant';

      terminal.activate();
      expect(untracked(node), 'Updated While Dormant');
      terminal.deactivate();
    });

    test('Graceful deactivation preserves listener during microtask transition',
        () async {
      final notifier = ValueNotifier<int>(10);
      final node = notifier.toWhat(graceful: Graceful.microtask);

      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, false);

      final terminal = RawWhatTerminal(node, onInvalidated: () {});
      terminal.activate();

      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, true);

      // Deactivate (e.g. unmount during route transition)
      terminal.deactivate();
      // Graceful = true: listener is NOT removed immediately
      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, true);

      // Reactivate in same tick
      terminal.activate();
      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, true);

      // Drain microtask
      await Future.microtask(() {});
      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, true);

      // Finally permanent deactivation
      terminal.deactivate();
      await Future.microtask(() {});
      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, false);
    });
  });

  group('change_notifier.dart - ListenableWhatExtension (toWhatBy)', () {
    test('toWhatBy extracts property and emits on activation', () {
      final user = TestUserModel(name: 'Alice', age: 25);
      final nameWhat = user.toWhatBy((u) => u.name);

      final emittedNames = <String>[];
      final terminal = RawWhatTerminal(nameWhat, onInvalidated: () {
        emittedNames.add(untracked(nameWhat));
      });
      terminal.activate();
      emittedNames.add(untracked(nameWhat));

      expect(emittedNames, ['Alice']);

      user.updateName('Bob');
      expect(emittedNames, ['Alice', 'Bob']);

      terminal.deactivate();
    });

    test(
        'toWhatBy distinct filtering prevents re-emission when unrelated fields change',
        () {
      final user = TestUserModel(name: 'Alice', age: 25);
      final nameWhat = user.toWhatBy((u) => u.name);

      final emittedNames = <String>[];
      final terminal = RawWhatTerminal(nameWhat, onInvalidated: () {
        emittedNames.add(untracked(nameWhat));
      });
      terminal.activate();
      emittedNames.add(untracked(nameWhat));

      expect(emittedNames, ['Alice']);

      // Updating age notifies listeners, but name hasn't changed -> distinct filters it out
      user.updateAge(26);
      user.updateAge(27);
      expect(emittedNames, ['Alice']);

      user.updateName('Bob');
      expect(emittedNames, ['Alice', 'Bob']);

      terminal.deactivate();
    });

    test(
        'toWhatBy distinct: false emits on every notification regardless of value',
        () {
      final user = TestUserModel(name: 'Alice', age: 25);
      final nameWhat = user.toWhatBy(
        (u) => u.name,
        distinct: false,
      );

      final emittedNames = <String>[];
      final terminal = RawWhatTerminal(nameWhat, onInvalidated: () {
        emittedNames.add(untracked(nameWhat));
      });
      terminal.activate();
      emittedNames.add(untracked(nameWhat));

      expect(emittedNames, ['Alice']);

      user.updateAge(26);
      expect(emittedNames, ['Alice', 'Alice']);

      terminal.deactivate();
    });

    test('toWhatBy distinct with custom equals', () {
      final user = TestUserModel(name: 'Alice', age: 20);
      final ageWhat = user.toWhatBy(
        (u) => u.age,
        equals: (prev, next) => (prev ~/ 10) == (next ~/ 10), // Same decade
      );

      final emittedAges = <int>[];
      final terminal = RawWhatTerminal(ageWhat, onInvalidated: () {
        emittedAges.add(untracked(ageWhat));
      });
      terminal.activate();
      emittedAges.add(untracked(ageWhat));

      expect(emittedAges, [20]);

      user.updateAge(25); // Same decade -> ignored
      expect(emittedAges, [20]);

      user.updateAge(30); // New decade -> emitted
      expect(emittedAges, [20, 30]);

      terminal.deactivate();
    });

    test('Multiple selectors on the same Listenable', () {
      final user = TestUserModel(name: 'Alice', age: 25);
      final nameWhat = user.toWhatBy((u) => u.name);
      final ageWhat = user.toWhatBy((u) => u.age);

      final emittedNames = <String>[];
      final emittedAges = <int>[];

      final terminalName = RawWhatTerminal(nameWhat, onInvalidated: () {
        emittedNames.add(untracked(nameWhat));
      });
      final terminalAge = RawWhatTerminal(ageWhat, onInvalidated: () {
        emittedAges.add(untracked(ageWhat));
      });

      terminalName.activate();
      terminalAge.activate();
      emittedNames.add(untracked(nameWhat));
      emittedAges.add(untracked(ageWhat));

      expect(emittedNames, ['Alice']);
      expect(emittedAges, [25]);

      user.updateName('David');
      expect(emittedNames, ['Alice', 'David']);
      expect(emittedAges, [25]); // age did not emit

      user.updateAge(30);
      expect(emittedNames, ['Alice', 'David']); // name did not emit
      expect(emittedAges, [25, 30]);

      terminalName.deactivate();
      terminalAge.deactivate();
    });

    test('toWhatBy lifecycle (activate / deactivate / graceful)', () async {
      final user = TestUserModel(name: 'Alice', age: 25);
      final ageWhat = user.toWhatBy(
        (u) => u.age,
        graceful: Graceful.microtask,
      );

      // ignore: invalid_use_of_protected_member
      expect(user.hasListeners, false);

      final terminal = RawWhatTerminal(ageWhat, onInvalidated: () {});
      terminal.activate();

      // ignore: invalid_use_of_protected_member
      expect(user.hasListeners, true);

      terminal.deactivate();
      // Graceful = true -> not removed immediately
      // ignore: invalid_use_of_protected_member
      expect(user.hasListeners, true);

      await Future.microtask(() {});
      // ignore: invalid_use_of_protected_member
      expect(user.hasListeners, false);
    });

    test('toWhatBy constructor isolates select exception into error state', () {
      final user = TestUserModel(name: 'Alice', age: 25);
      final errorWhat = user.toWhatBy<String>((u) {
        throw StateError('Constructor selector boom!');
      });

      expect(untracked.state(errorWhat).hasError, isTrue);
      expect(untracked.state(errorWhat).error, isA<StateError>());
      expect((untracked.state(errorWhat).error as StateError).message,
          'Constructor selector boom!');
    });
  });

  group('change_notifier.dart - WhatListenableExtension (toListenable)', () {
    test('basic ValueListenable bridge notifications', () {
      final controller = WhatController<int>(10);
      final listenable = controller.what.toListenable();

      expect(listenable.value, 10);

      final values = <int>[];
      void listener() {
        values.add(listenable.value);
      }

      listenable.addListener(listener);
      controller.set(20);
      controller.set(30);

      expect(values, [20, 30]);

      listenable.removeListener(listener);
      controller.set(40);
      expect(values, [20, 30]);
    });

    test('toListenable(sync: false) applies microtask batch coalescing',
        () async {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable(sync: false);

      final values = <int>[];
      void listener() => values.add(listenable.value);

      listenable.addListener(listener);

      controller.set(1);
      controller.set(2);
      controller.set(3);

      // Synchronously nothing emitted yet
      expect(values, isEmpty);

      await Future<void>.delayed(Duration.zero);
      expect(values, [3]);

      listenable.removeListener(listener);
    });

    test('isolates listener exception and prevents starvation', () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      final reportedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        reportedErrors.add(details);
      };

      try {
        final calls = <String>[];

        void faultyListener() {
          calls.add('faulty');
          throw StateError('Listener failure');
        }

        void healthyListener() {
          calls.add('healthy');
        }

        listenable.addListener(faultyListener);
        listenable.addListener(healthyListener);

        controller.set(1);

        // Both listeners were called despite faultyListener throwing
        expect(calls, ['faulty', 'healthy']);

        // FlutterError should report the error
        expect(reportedErrors.length, 1);
        expect(reportedErrors.first.exception, isA<StateError>());
        expect(reportedErrors.first.library, 'what_flutter');
        expect(
          reportedErrors.first.context.toString(),
          contains('while notifying listener in _WhatValueListenable'),
        );
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    test('skips listener if removed during notification traversal', () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      final calls = <String>[];
      late final VoidCallback listenerB;

      void listenerA() {
        calls.add('listenerA');
        // Remove listenerB during notification
        listenable.removeListener(listenerB);
      }

      listenerB = () {
        calls.add('listenerB');
      };

      listenable.addListener(listenerA);
      listenable.addListener(listenerB);

      controller.set(1);

      // listenerB was removed by listenerA before being visited, so it should not be called
      expect(calls, ['listenerA']);

      // Next notification only invokes remaining listeners
      controller.set(2);
      expect(calls, ['listenerA', 'listenerA']);

      listenable.removeListener(listenerA);
    });

    test(
        'linked list: listener removes itself during notification (self-removal)',
        () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      final calls = <String>[];
      late final VoidCallback selfRemovingListener;

      selfRemovingListener = () {
        calls.add('self');
        listenable.removeListener(selfRemovingListener);
      };

      void subsequentListener() {
        calls.add('subsequent');
      }

      listenable.addListener(selfRemovingListener);
      listenable.addListener(subsequentListener);

      controller.set(1);
      // Both called on first notify
      expect(calls, ['self', 'subsequent']);

      // Second notify only calls subsequentListener
      controller.set(2);
      expect(calls, ['self', 'subsequent', 'subsequent']);

      listenable.removeListener(subsequentListener);
    });

    test('linked list: listener removes preceding listener during notification',
        () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      final calls = <String>[];
      late final VoidCallback listenerA;
      late final VoidCallback listenerB;
      late final VoidCallback listenerC;

      listenerA = () => calls.add('A');
      listenerB = () {
        calls.add('B');
        // Remove predecessor A
        listenable.removeListener(listenerA);
      };
      listenerC = () => calls.add('C');

      listenable.addListener(listenerA);
      listenable.addListener(listenerB);
      listenable.addListener(listenerC);

      controller.set(1);
      expect(calls, ['A', 'B', 'C']);

      controller.set(2);
      expect(calls, ['A', 'B', 'C', 'B', 'C']);

      listenable.removeListener(listenerB);
      listenable.removeListener(listenerC);
    });

    test('linked list: listener adds new listener during notification', () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      final calls = <String>[];
      late final VoidCallback newListener;
      newListener = () => calls.add('new');

      bool added = false;
      void originalListener() {
        calls.add('original');
        if (!added) {
          added = true;
          listenable.addListener(newListener);
        }
      }

      listenable.addListener(originalListener);

      controller.set(1);
      // New listener added during dispatch is NOT called in the current notification pass
      expect(calls, ['original']);

      controller.set(2);
      // Both original and new listener called in subsequent notification
      expect(calls, ['original', 'original', 'new']);

      listenable.removeListener(originalListener);
      listenable.removeListener(newListener);
    });

    test('linked list: removes all remaining listeners during notification',
        () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      final calls = <String>[];
      late final VoidCallback l1;
      late final VoidCallback l2;
      late final VoidCallback l3;

      l1 = () {
        calls.add('l1');
        listenable.removeListener(l1);
        listenable.removeListener(l2);
        listenable.removeListener(l3);
      };
      l2 = () => calls.add('l2');
      l3 = () => calls.add('l3');

      listenable.addListener(l1);
      listenable.addListener(l2);
      listenable.addListener(l3);

      controller.set(1);
      // Only l1 executed; l2 and l3 were removed before being visited
      expect(calls, ['l1']);

      // All unlinked, further updates do not throw or notify
      controller.set(2);
      expect(calls, ['l1']);
    });

    test('linked list: handles duplicate registrations and partial removal',
        () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      int count = 0;
      void duplicateListener() {
        count++;
      }

      // Add same callback twice
      listenable.addListener(duplicateListener);
      listenable.addListener(duplicateListener);

      controller.set(1);
      expect(count, 2);

      // Remove one instance
      listenable.removeListener(duplicateListener);

      controller.set(2);
      // Only one instance called this time (2 + 1 = 3)
      expect(count, 3);

      // Remove the second instance
      listenable.removeListener(duplicateListener);

      controller.set(3);
      expect(count, 3);
    });

    test(
        'linked list: re-entrant notifications dispatch safely without loop corruption',
        () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      final history = <String>[];

      void recursiveListener() {
        final currentVal = listenable.value;
        history.add('rec:$currentVal');
        if (currentVal < 2) {
          controller.set(currentVal + 1);
        }
      }

      void secondaryListener() {
        history.add('sec:${listenable.value}');
      }

      listenable.addListener(recursiveListener);
      listenable.addListener(secondaryListener);

      controller.set(1);

      // Recursive cycle unwinds cleanly without stack or list corruption
      // rec:1 sets 2 (terminal dirty) -> outer pass finishes with sec:2 -> subsequent pass runs rec:2, sec:2
      expect(history, ['rec:1', 'sec:2', 'rec:2', 'sec:2']);

      listenable.removeListener(recursiveListener);
      listenable.removeListener(secondaryListener);
    });

    test(
        're-entrant notify: listener removed during re-entrant notification pass',
        () {
      final controller = WhatController<int>(0);
      final listenable = controller.what.toListenable();

      final calls = <String>[];
      late final VoidCallback listenerB;
      bool nestedTriggered = false;

      void listenerA() {
        calls.add('A:${listenable.value}');
        if (!nestedTriggered) {
          nestedTriggered = true;
          // Re-entrant mutation
          controller.set(2);
        }
      }

      listenerB = () {
        calls.add('B:${listenable.value}');
        // Remove B
        listenable.removeListener(listenerB);
      };

      void listenerC() {
        calls.add('C:${listenable.value}');
      }

      listenable.addListener(listenerA);
      listenable.addListener(listenerB);
      listenable.addListener(listenerC);

      controller.set(1);

      // Verify that removed listener B is never called after removal, and C is not starved
      expect(calls.where((c) => c.startsWith('B')).length, 1);
      expect(calls.contains('C:2'), true);

      listenable.removeListener(listenerA);
      listenable.removeListener(listenerC);
    });
  });
}
