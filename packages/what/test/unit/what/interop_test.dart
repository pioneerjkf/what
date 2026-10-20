// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/what.dart';
import 'package:test/test.dart';
import '../../test_utils.dart';

void main() {
  group('What Interop & Proxy Delegation', () {
    test('WhatController.what wraps reactive node and tracks automatically', () async {
      final controller = WhatController<int>(100);
      final whatView = controller.what;

      expect(untracked(whatView), 100);

      var effectRuns = 0;
      var lastValue = 0;

      final dispose = effect((via) {
        effectRuns++;
        lastValue = via(whatView);
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(lastValue, 100);

      controller.data = 200;
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(lastValue, 200);

      dispose();
    });

    test('untracked function and member bypass reactive tracking', () async {
      final trigger = WhatController(0);
      final untrackedData = WhatController('Secret');

      var effectRuns = 0;
      String? observedSecret;

      final dispose = effect((via) {
        effectRuns++;
        via(trigger.what); // Only trigger is tracked

        // untrackedData is read via raw read WITHOUT registering tracking
        observedSecret = untrackedData.data;
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observedSecret, 'Secret');

      // Mutating untrackedData should NOT trigger the effect!
      untrackedData.data = 'NewSecret';
      await Future.microtask(() {});

      expect(effectRuns, 1); // Effect did not run!

      // Also verify direct raw read .data
      expect(untrackedData.data, 'NewSecret');

      // Mutating trigger DOES trigger the effect and picks up the latest untracked secret
      trigger.data = 1;
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(observedSecret, 'NewSecret');

      dispose();
    });

    test('works smoothly with WhatListController pipelines', () {
      final a = WhatController(10);
      final b = WhatController(20);

      final group = WhatListController([a.what, b.what]);
      expect(group.data.map((g) => untracked(g)).toList(), [10, 20]);

      a.data = 100;
      expect(group.data.map((g) => untracked(g)).toList(), [100, 20]);
    });

    test('WhatController implements WhatState directly', () {
      final r1 = WhatController(10);
      final r2 = WhatController<int>.late();

      expect(r1, isA<WhatState<int>>());
      expect(r1.hasData, isTrue);
      expect(r1.isEmpty, isFalse);
      expect(r1.snapshot.data, equals(10));

      expect(r2, isA<WhatState<int>>());
      expect(r2.isEmpty, isTrue);
      expect(r2.hasData, isFalse);

      r2.data = 20;
      expect(r2.hasData, isTrue);
      expect(r2.snapshot.data, equals(20));
    });

    test('WhatIterableExtension combines and folds multiple Whats reactively', () async {
      final a = WhatController('Hello');
      final b = WhatController('World');

      final combined = What.constant([a.what, b.what]).combine();
      final folded = What.constant([a.what, b.what]).fold('>>', (acc, item) => '$acc $item');
      final reduced = What.constant([a.what, b.what]).reduce((prev, item) => '$prev+$item');

      var combinedRuns = 0;
      List<String>? latestList;
      String? latestFolded;
      String? latestReduced;

      final dispose = effect((via) {
        combinedRuns++;
        latestList = via(combined);
        latestFolded = via(folded);
        latestReduced = via(reduced);
      });

      await Future<void>.delayed(Duration.zero);
      expect(combinedRuns, 1);
      expect(latestList, ['Hello', 'World']);
      expect(latestFolded, '>> Hello World');
      expect(latestReduced, 'Hello+World');

      a.data = 'Hi';
      await Future.microtask(() {});

      expect(combinedRuns, 2);
      expect(latestList, ['Hi', 'World']);
      expect(latestFolded, '>> Hi World');
      expect(latestReduced, 'Hi+World');

      dispose();
    });

    test('WhatIterableNumericExtension sum computes reactive sum via What.constant().sum()', () async {
      final p1 = WhatController(100);
      final p2 = WhatController(250);
      final p3 = WhatController(50);

      final total = What.constant([p1.what, p2.what, p3.what]).sum();

      var effectRuns = 0;
      var lastSum = 0;
      final dispose = effect((via) {
        effectRuns++;
        lastSum = via(total);
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(lastSum, 400);

      p2.data = 300;
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(lastSum, 450);

      dispose();
    });

    test('WhatIterableExtension evaluates logical AND (every) and OR (any)', () async {
      final isNameValid = WhatController(true);
      final isEmailValid = WhatController(true);
      final isAgreed = WhatController(false);

      final formReady = What.constant([isNameValid.what, isEmailValid.what, isAgreed.what]).every();
      final hasAnyValid = What.constant([isNameValid.what, isEmailValid.what, isAgreed.what]).any();

      var runs = 0;
      bool? isReady;
      bool? hasValid;

      final dispose = effect((via) {
        runs++;
        isReady = via(formReady);
        hasValid = via(hasAnyValid);
      });

      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      expect(isReady, isFalse);
      expect(hasValid, isTrue);

      isAgreed.data = true;
      await Future.microtask(() {});

      expect(runs, 2);
      expect(isReady, isTrue);
      expect(hasValid, isTrue);

      dispose();
    });

    test('What.computed with distinct projects slice and suppresses downstream effect runs when slice unchanged',
        () async {
      final user = WhatController((name: 'Alice', age: 20));

      final name = computed((via) => via(user.what).name).distinct();

      var effectRuns = 0;
      String? lastName;

      final dispose = effect((via) {
        effectRuns++;
        lastName = via(name);
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(lastName, 'Alice');

      // Age changes, name remains the same -> effect should NOT re-run!
      user.data = (name: 'Alice', age: 21);
      await Future.microtask(() {});

      expect(effectRuns, 1);
      expect(lastName, 'Alice');

      // Name changes -> effect runs!
      user.data = (name: 'Bob', age: 21);
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(lastName, 'Bob');

      // Custom comparator support
      final decade = computed((via) => via(user.what).age).distinct(
        (prev, next) => (prev ~/ 10) == (next ~/ 10),
      );

      var decadeRuns = 0;
      int? lastAge;
      final disposeDecade = effect((via) {
        decadeRuns++;
        lastAge = via(decade);
      });

      await Future<void>.delayed(Duration.zero);
      expect(decadeRuns, 1);
      expect(lastAge, 21);

      user.data = (name: 'Bob', age: 29); // same decade
      await Future.microtask(() {});
      expect(decadeRuns, 1);

      user.data = (name: 'Bob', age: 30); // new decade
      await Future.microtask(() {});
      expect(decadeRuns, 2);
      expect(lastAge, 30);

      dispose();
      disposeDecade();
    });

    test('What.error creates error what and handles errors safely', () {
      final r1 = What<int>.error('ErrorMsg');
      final r2 = What<int>.error('ConstructorError');

      expect(untracked.state(r1).hasError, isTrue);
      expect(untracked.state(r1).error, 'ErrorMsg');
      expect(() => untracked(r1), throwsA(isA<WhatSnapshotExtractionException>()));
      expect(untracked.state(r1).dataOrNull, isNull);
      expect(untracked.state(r1).dataOrElse(() => 999), 999);

      expect(untracked.state(r2).hasError, isTrue);
      expect(untracked.state(r2).error, 'ConstructorError');
    });

    test('What.resource creates topology-aware resource bound to subscriptions', () async {
      var createCalls = 0;
      var disposeCalls = 0;

      final resWhat = managed<String>(
        create: (_) {
          createCalls++;
          return 'DynamicResource';
        },
        dispose: (res) {
          disposeCalls++;
        },
      );

      // Inactive initially -> not created yet
      expect(createCalls, 0);
      expect(disposeCalls, 0);

      final dispose = effect((via) {
        via(resWhat);
      });

      await Future<void>.delayed(Duration.zero);
      expect(createCalls, 1);
      expect(untracked(resWhat), 'DynamicResource');

      dispose();
      expect(disposeCalls, 1);
    });

    test('What.computed and What.distinct transform and deduplicate reactively', () async {
      final count = WhatController(5);
      final multiplied = computed((via) => via(count.what) * 2);
      final isEven = computed((via) => via(multiplied) % 2 == 0).distinct();

      var isEvenRuns = 0;
      bool? lastIsEven;

      final dispose = effect((via) {
        isEvenRuns++;
        lastIsEven = via(isEven);
      });

      await Future<void>.delayed(Duration.zero);
      expect(isEvenRuns, 1);
      expect(lastIsEven, isTrue);

      // count 5 -> 7: multiplied 10 -> 14 (both even): isEven distinct prevents re-run
      count.data = 7;
      await Future.microtask(() {});

      expect(isEvenRuns, 1);
      expect(untracked(multiplied), 14);

      dispose();
    });

    test('What.computed with guard conditionally blocks computation and becomes empty state', () async {
      final secret = WhatController('TopSecret');
      var authorized = true;

      final guarded = computed(
        (via) => via(secret.what),
        guard: (via) => authorized.guarded('Access Denied'),
      );

      var effectRuns = 0;
      String? observed;
      Object? observedReason;

      final dispose = effect((via) {
        effectRuns++;
        final g = via.state(guarded);
        if (g.hasData) {
          observed = g.data;
        } else if (g.isEmpty) {
          observedReason = g.snapshot.emptyReason;
        }
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observed, 'TopSecret');

      authorized = false;
      secret.data = 'UpdatedSecret';
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(untracked.state(guarded).isEmpty, isTrue);
      expect(observedReason, 'Access Denied');

      dispose();
    });

    test('What dataOrElse and computed recover uninitialized and error states', () {
      final uninit = WhatController<String>.late();
      final failing = What<String>.error('NetworkError');

      final safeUninit = computed((via) => via.state(uninit.what).dataOrElse(() => 'DefaultUninit'));
      final safeFailing = computed((via) {
        final s = via.state(failing).snapshot;
        if (s.hasError) return 'Safe: ${s.error}';
        return s.data;
      });
      final nullView = computed<String?>((via) => via.state(uninit.what).hasData ? via(uninit.what) : null);

      expect(untracked(safeUninit), 'DefaultUninit');
      expect(untracked(safeFailing), 'Safe: NetworkError');
      expect(untracked(nullView), isNull);
      expect(untracked.state(nullView).hasData, isTrue);
    });

    test('what.resource auto-tracks upstream and creates lifecycle-bound resource', () async {
      final factor = WhatController(2);
      var disposedResource = '';

      final derivedRes = managed<String>(
        create: (via) => 'Resource_x${via(factor.what)}',
        update: (via, current) => 'Resource_x${via(factor.what)}',
        dispose: (res) => disposedResource = res,
      );

      final dispose = effect((via) {
        via(derivedRes);
      });

      await Future<void>.delayed(Duration.zero);
      expect(untracked(derivedRes), 'Resource_x2');

      dispose();
      expect(disposedResource, 'Resource_x2');
    });

    test('what.resource disposes previous and creates new resource on upstream change when update is omitted',
        () async {
      final config = WhatController('wss://server-1');
      final disposedList = <String>[];
      final createdList = <String>[];

      final sessionWhat = managed<String>(
        create: (via) {
          final session = 'Session(${via(config.what)})';
          createdList.add(session);
          return session;
        },
        dispose: (session) {
          disposedList.add(session);
        },
      );

      // Before activation, no resource created
      expect(untracked.state(sessionWhat).isEmpty, isTrue);
      expect(createdList, isEmpty);

      String? activeSession;
      final disposeEffect = effect((via) {
        activeSession = via(sessionWhat);
      });

      await Future<void>.delayed(Duration.zero);
      expect(activeSession, 'Session(wss://server-1)');
      expect(createdList, ['Session(wss://server-1)']);
      expect(disposedList, isEmpty);

      // Upstream changes -> old session is disposed, new session is created upon read
      config.data = 'wss://server-2';
      expect(untracked(sessionWhat), 'Session(wss://server-2)');
      expect(disposedList, ['Session(wss://server-1)']);
      expect(createdList, ['Session(wss://server-1)', 'Session(wss://server-2)']);

      // After effect microtask runs, activeSession in effect is updated
      await Future.microtask(() {});
      expect(activeSession, 'Session(wss://server-2)');

      // Downstream deactivates (e.g. unmount) -> active session is disposed
      disposeEffect();
      expect(disposedList, ['Session(wss://server-1)', 'Session(wss://server-2)']);
      expect(untracked.state(sessionWhat).isEmpty, isTrue);
    });

    test('WhatCollectionExtension extracts data and dataOrNull with fail-fast validation', () {
      final r1 = WhatController(10);
      final r2 = WhatController(20);
      final rEmpty = WhatController<int>.late();
      final rError = What<int>.error('Err');

      final validList = [r1, r2];
      expect(validList.data.toList(), [10, 20]);
      expect(validList.dataOrNull.toList(), [10, 20]);

      final mixedList = [r1, rEmpty, untracked.state(rError)];
      expect(mixedList.dataOrNull.toList(), [10, null, null]);
      expect(() => mixedList.data.toList(), throwsA(isA<WhatSnapshotExtractionException>()));
    });

    test('What.computed with distinct and custom comparator suppresses downstream effect executions', () async {
      final user = WhatController((name: 'Alice', score: 100));
      var effectRuns = 0;
      String? observedName;

      // Select name only; changes in score should not trigger effect
      final nameWhat = computed((via) => via(user.what).name).distinct();

      final dispose = effect((via) {
        effectRuns++;
        observedName = via(nameWhat);
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(observedName, 'Alice');

      // Mutate score only -> name remains 'Alice'
      user.data = (name: 'Alice', score: 200);
      await Future.microtask(() {});

      expect(effectRuns, 1); // No re-run!
      expect(observedName, 'Alice');

      // Mutate name -> triggers effect
      user.data = (name: 'Bob', score: 200);
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(observedName, 'Bob');

      dispose();
    });

    test('What.computed with guard dynamically blocks and restores downstream pipeline based on condition', () async {
      final allowed = WhatController(false);
      final query = WhatController('sensitive_data');
      final guarded = computed(
        (via) => via(query.what),
        guard: (via) => via(allowed.what).guarded('Access Denied'),
      );

      var effectRuns = 0;
      final dispose = effect((via) {
        effectRuns++;
        via.state(guarded).dataOrNull;
      });

      await Future<void>.delayed(Duration.zero);
      expect(effectRuns, 1);
      expect(untracked.state(guarded).isEmpty, isTrue);
      expect(untracked.state(guarded).snapshot.emptyReason, 'Access Denied');
      expect(untracked.state(guarded).dataOrNull, isNull);

      // Change permission & update query
      allowed.data = true;
      query.data = 'sensitive_data_v2';
      await Future.microtask(() {});

      expect(effectRuns, 2);
      expect(untracked.state(guarded).hasData, isTrue);
      expect(untracked(guarded), 'sensitive_data_v2');

      dispose();
    });

    test('what.resource with graceful=true defers disposal to microtask', () async {
      final source = WhatController('res_1');
      var disposedResource = '';

      final derivedRes = managed<String>(
        create: (via) => 'Managed(${via(source.what)})',
        dispose: (res) => disposedResource = res,
        graceful: const Graceful(),
      );

      final dispose = effect((via) {
        via(derivedRes);
      });

      await Future<void>.delayed(Duration.zero);
      expect(untracked(derivedRes), 'Managed(res_1)');

      // Unsubscribe (deactivate)
      dispose();

      // Graceful = true defers disposal; NOT synchronously disposed yet
      expect(disposedResource, '');

      // After microtask runs -> disposed!
      await Future.microtask(() {});
      expect(disposedResource, 'Managed(res_1)');
    });

    test('what.resource dispose cleans up resources on update or deactivation', () async {
      final source = WhatController('initial_endpoint');
      final disposals = <String>[];

      final derivedRes = managed<String>(
        create: (via) => 'Client(${via(source.what)})',
        update: (via, current) => 'Client(${via(source.what)})',
        dispose: (res) {
          disposals.add(res);
        },
      );

      final dispose = effect((via) {
        via(derivedRes);
      });

      await Future<void>.delayed(Duration.zero);
      expect(untracked(derivedRes), 'Client(initial_endpoint)');
      expect(disposals, isEmpty);

      source.set('new_endpoint');
      expect(untracked(derivedRes), 'Client(new_endpoint)');
      expect(disposals, equals(['Client(initial_endpoint)']));

      dispose();
      expect(
          disposals,
          equals([
            'Client(initial_endpoint)',
            'Client(new_endpoint)',
          ]));
    });

    test('What and WhatListController check physical node identity via identical', () {
      final what1 = What.constant(100);
      final what2 = What.constant(100);

      final r1 = what1;
      final r2 = what1;
      final r3 = what2;

      final writable = WhatController(100);
      final whatView = writable.what;

      expect(identical(r1, r2), isTrue);
      expect(identical(r1, r3), isFalse);
      expect(identical(writable, whatView), isFalse);
      expect(identical(writable, r1), isFalse);
      expect(() => (writable.what as dynamic) as WhatController, throwsA(isA<TypeError>()));

      final group1 = What.constant([what1]);
      final group2 = What.constant([what1]);

      final rs1 = group1;
      final rs2 = group1;
      final rs3 = group2;

      final writableGroup = WhatListController([what1]);
      final groupView = writableGroup.what;

      expect(identical(rs1, rs2), isTrue);
      expect(identical(rs1, rs3), isFalse);
      expect(identical(writableGroup, groupView), isFalse);
      expect(identical(writableGroup, rs1), isFalse);
      expect(() => (writableGroup.what as dynamic) as WhatListController, throwsA(isA<TypeError>()));
    });
  });
}
