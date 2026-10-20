// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart' as test_pkg;
import 'package:what/what.dart';

import 'matchers.dart';

// =============================================================================
// whatTest Declarative Reactive Test Runner
// =============================================================================

/// A declarative, atomic unit test runner tailored specifically for the What reactive framework.
///
/// Encapsulates the entire testing lifecycle of reactive state pipelines:
/// 1. Instantiates the state container or store via [build].
/// 2. If [target] is provided, automatically establishes an active observation subscription
///    ([RawWhatTerminal]), recording an immutable snapshot ring buffer.
/// 3. Executes state mutations via [act].
/// 4. If [wait] is specified, controls virtual time via [FakeAsync] and flushes microtasks.
/// 5. Validates expected state transitions via [expect] (matching [WhatSnapshot] sequences or raw values).
/// 6. Verifies invocations and mocks via [verify].
/// 7. Automatically detaches all subscriptions and executes [tearDown] with 0% state pollution.
///
/// ## Examples
/// ```dart
/// whatTest<CounterStore>(
///   'increments counter value and records snapshots',
///   build: () => CounterStore(),
///   target: (store) => store.count.what,
///   act: (store) => store.increment(),
///   expect: () => [
///     WhatSnapshot(0),
///     WhatSnapshot(1),
///   ],
/// );
/// ```
void whatTest<T>(
  String description, {
  required T Function() build,
  void Function(T target)? seed,
  What Function(T target)? target,
  FutureOr<void> Function(T target)? act,
  Duration? wait,
  dynamic Function()? expect,
  dynamic Function()? errors,
  void Function(T target)? verify,
  void Function(T target)? tearDown,
  dynamic tags,
  int? retry,
  dynamic testOn,
  test_pkg.Timeout? timeout,
  bool skip = false,
}) {
  test_pkg.test(
    description,
    () async {
      if (wait != null) {
        fakeAsync((async) {
          final instance = build();
          seed?.call(instance);
          RawWhatTerminal? terminal;
          final snapshots = <WhatSnapshot>[];
          final caughtErrors = <Object>[];

          try {
            if (target != null) {
              final node = target(instance);
              snapshots.add(untracked.state(node).snapshot);
              terminal = RawWhatTerminal(
                node,
                onInvalidated: () {
                  snapshots.add(untracked.state(node).snapshot);
                },
              );
              terminal.activate();
            }

            Object? asyncActError;
            StackTrace? asyncActStackTrace;
            try {
              final actResult = act?.call(instance);
              if (actResult is Future) {
                actResult.catchError((Object error, StackTrace stackTrace) {
                  asyncActError = error;
                  asyncActStackTrace = stackTrace;
                });
              }
              async.elapse(wait);
              async.flushMicrotasks();

              if (asyncActError != null) {
                if (errors == null) {
                  Error.throwWithStackTrace(
                    asyncActError!,
                    asyncActStackTrace ?? StackTrace.current,
                  );
                }
                caughtErrors.add(asyncActError!);
              }
            } catch (error) {
              if (errors == null) rethrow;
              caughtErrors.add(error);
            }

            if (expect != null) {
              _assertExpect(snapshots, expect());
            }

            if (errors != null) {
              test_pkg.expect(caughtErrors, errors());
            }

            verify?.call(instance);
          } finally {
            terminal?.deactivate();
            tearDown?.call(instance);
          }
        });
      } else {
        final instance = build();
        seed?.call(instance);
        RawWhatTerminal? terminal;
        final snapshots = <WhatSnapshot>[];
        final caughtErrors = <Object>[];

        try {
          if (target != null) {
            final node = target(instance);
            snapshots.add(untracked.state(node).snapshot);
            terminal = RawWhatTerminal(
              node,
              onInvalidated: () {
                snapshots.add(untracked.state(node).snapshot);
              },
            );
            terminal.activate();
          }

          try {
            final actResult = act?.call(instance);
            if (actResult is Future) {
              await actResult;
            }
            await Future<void>.delayed(Duration.zero);
          } catch (error) {
            if (errors == null) rethrow;
            caughtErrors.add(error);
          }

          if (expect != null) {
            _assertExpect(snapshots, expect());
          }

          if (errors != null) {
            test_pkg.expect(caughtErrors, errors());
          }

          verify?.call(instance);
        } finally {
          terminal?.deactivate();
          tearDown?.call(instance);
        }
      }
    },
    tags: tags,
    retry: retry,
    testOn: testOn,
    timeout: timeout,
    skip: skip,
  );
}

void _assertExpect(List<WhatSnapshot> snapshots, dynamic expected) {
  if (expected is test_pkg.Matcher) {
    test_pkg.expect(snapshots, expected);
    return;
  }
  if (expected is List) {
    if (expected.isEmpty) {
      test_pkg.expect(snapshots, test_pkg.isEmpty);
      return;
    }
    // Check if expected items are WhatSnapshots or Matchers
    final isSnapshotOrMatcherList = expected.every(
      (e) => e is WhatSnapshot || e is test_pkg.Matcher,
    );
    if (isSnapshotOrMatcherList) {
      final matchers = expected.map((e) {
        if (e is test_pkg.Matcher) return e;
        if (e is WhatSnapshot) {
          if (e.hasData) return isData(e.data);
          if (e.isEmpty) return isEmptyState(e.emptyReason);
          if (e.hasError) return isErrorState(e.error);
        }
        return test_pkg.equals(e);
      }).toList();
      test_pkg.expect(snapshots, matchers);
      return;
    }
    // Otherwise compare with raw values
    final rawValues = snapshots.map((s) => s.hasData ? s.data : s).toList();
    test_pkg.expect(rawValues, expected);
    return;
  }
  test_pkg.expect(snapshots, expected);
}
