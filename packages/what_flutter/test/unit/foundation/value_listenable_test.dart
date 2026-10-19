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
        emittedValues.add(node.peek);
      });
      terminal.activate();
      emittedValues.add(node.peek);

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
        emittedValues.add(node.peek);
      });
      terminal.activate();
      emittedValues.add(node.peek);

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
        emittedValues.add(node.peek);
      });
      terminal.activate();
      emittedValues.add(node.peek);

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
        emittedValues.add(node.peek);
      });
      terminal.activate();
      emittedValues.add(node.peek);

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
        emittedValues.add(node.peek);
      });
      terminal.activate();
      emittedValues.add(node.peek);

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
      expect(node.peek, 'Initial');
      terminal.deactivate();

      notifier.value = 'Updated While Dormant';

      terminal.activate();
      expect(node.peek, 'Updated While Dormant');
      terminal.deactivate();
    });

    test('Graceful deactivation preserves listener during microtask transition',
        () async {
      final notifier = ValueNotifier<int>(10);
      final node = notifier.toWhat(graceful: graceful);

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
        emittedNames.add(nameWhat.peek);
      });
      terminal.activate();
      emittedNames.add(nameWhat.peek);

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
        emittedNames.add(nameWhat.peek);
      });
      terminal.activate();
      emittedNames.add(nameWhat.peek);

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
        emittedNames.add(nameWhat.peek);
      });
      terminal.activate();
      emittedNames.add(nameWhat.peek);

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
        emittedAges.add(ageWhat.peek);
      });
      terminal.activate();
      emittedAges.add(ageWhat.peek);

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
        emittedNames.add(nameWhat.peek);
      });
      final terminalAge = RawWhatTerminal(ageWhat, onInvalidated: () {
        emittedAges.add(ageWhat.peek);
      });

      terminalName.activate();
      terminalAge.activate();
      emittedNames.add(nameWhat.peek);
      emittedAges.add(ageWhat.peek);

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
        graceful: graceful,
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

      expect(errorWhat.peekState.hasError, isTrue);
      expect(errorWhat.peekState.error, isA<StateError>());
      expect((errorWhat.peekState.error as StateError).message,
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
  });
}
