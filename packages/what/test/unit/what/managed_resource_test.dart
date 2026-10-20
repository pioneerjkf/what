import 'dart:async';
import 'package:what/what.dart';
import 'package:test/test.dart';

class _TestSocket {
  _TestSocket(this.host, this.port);
  String host;
  int port;
  bool isClosed = false;

  void close() {
    isClosed = true;
  }
}

final class _TestErrorHandler implements LpdagUncaughtErrorHandler {
  final List<(Object error, StackTrace stackTrace, Object? context)> captured = [];

  @override
  void onUncaughtError(Object error, StackTrace stackTrace, {Object? context}) {
    captured.add((error, stackTrace, context));
  }
}

void main() {
  group('What.managed / what.managed Unified Engine Tests', () {
    test('1. Multi-dependency reactive tracking across multiple upstreams', () {
      final host = WhatController('localhost');
      final port = WhatController(8080);
      final disposed = <_TestSocket>[];

      final socketRes = managed<_TestSocket>(
        create: (via) => _TestSocket(via(host.what), via(port.what)),
        dispose: (socket) {
          disposed.add(socket);
          socket.close();
        },
      );

      final terminal = RawWhatTerminal(socketRes, onInvalidated: () {});
      terminal.activate();

      expect(terminal.hasData, isTrue);
      final s1 = terminal.data;
      expect(s1.host, 'localhost');
      expect(s1.port, 8080);
      expect(disposed, isEmpty);

      // Mutate first dependency: under 2-Phase LPDAG, dirty push is non-destructive
      host.data = '127.0.0.1';
      expect(disposed, isEmpty);

      // Reading terminal.data triggers pull, disposing stale s1 and allocating s2
      final s2 = terminal.data;
      expect(disposed.length, 1);
      expect(disposed[0], same(s1));
      expect(s1.isClosed, isTrue);
      expect(s2.host, '127.0.0.1');
      expect(s2.port, 8080);

      // Mutate second dependency
      port.data = 9090;
      expect(disposed.length, 1);

      // Reading terminal.data pulls new state
      final s3 = terminal.data;
      expect(disposed.length, 2);
      expect(disposed[1], same(s2));
      expect(s2.isClosed, isTrue);
      expect(s3.host, '127.0.0.1');
      expect(s3.port, 9090);

      terminal.deactivate();
      expect(disposed.length, 3);
      expect(disposed[2], same(s3));
      expect(s3.isClosed, isTrue);
    });

    test('2. Dynamic edge pruning when branching dependencies change', () {
      final useBackup = WhatController(false);
      final primary = WhatController('primary.db');
      final backup = WhatController('backup.db');
      final log = <String>[];

      final dbResource = managed<String>(
        create: (via) {
          final url = via(useBackup.what) ? via(backup.what) : via(primary.what);
          log.add('create:$url');
          return 'DB($url)';
        },
        dispose: (db) {
          log.add('dispose:$db');
        },
      );

      final terminal = RawWhatTerminal(dbResource, onInvalidated: () {});
      terminal.activate();

      expect(terminal.data, 'DB(primary.db)');
      expect(log, ['create:primary.db']);

      // Mutating backup should NOT trigger invalidation because it was not read
      backup.data = 'new-backup.db';
      expect(log, ['create:primary.db']);

      // Switch branch to backup: non-destructive dirty push
      useBackup.data = true;
      expect(log, ['create:primary.db']);

      // Reading terminal.data pulls the new branch, disposing stale and creating new!
      expect(terminal.data, 'DB(new-backup.db)');
      expect(log, ['create:primary.db', 'dispose:DB(primary.db)', 'create:new-backup.db']);

      // Now mutating primary should NOT trigger invalidation because primary was swept!
      primary.data = 'ignore-primary.db';
      expect(log, ['create:primary.db', 'dispose:DB(primary.db)', 'create:new-backup.db']);

      terminal.deactivate();
      expect(log.last, 'dispose:DB(new-backup.db)');
    });

    test('3. Instance reuse via update callback', () {
      final port = WhatController(3000);
      int createCount = 0;
      int updateCount = 0;
      int disposeCount = 0;

      final socketRes = managed<_TestSocket>(
        create: (via) {
          createCount++;
          return _TestSocket('localhost', via(port.what));
        },
        update: (via, current) {
          updateCount++;
          current.port = via(port.what);
          // Return identical instance -> no disposal
          return current;
        },
        dispose: (socket) {
          disposeCount++;
          socket.close();
        },
      );

      final terminal = RawWhatTerminal(socketRes, onInvalidated: () {});
      terminal.activate();

      final socket = terminal.data;
      expect(createCount, 1);
      expect(updateCount, 0);
      expect(disposeCount, 0);
      expect(socket.port, 3000);

      // Mutate upstream -> update is deferred until read (glitch-free lazy pull)!
      port.data = 4000;
      expect(createCount, 1);
      expect(updateCount, 0); // Not updated yet!

      // Reading terminal.data performs update
      expect(terminal.data, same(socket));
      expect(updateCount, 1);
      expect(disposeCount, 0);
      expect(socket.port, 4000);
      expect(socket.isClosed, isFalse);

      // Deactivate -> cleans up socket
      terminal.deactivate();
      expect(disposeCount, 1);
      expect(socket.isClosed, isTrue);
    });

    test('4. Lazy allocation defers until read and avoids thrashing', () {
      final config = WhatController(1);
      int createCount = 0;
      int disposeCount = 0;

      final lazyRes = managed<String>(
        create: (via) {
          createCount++;
          return 'Config-${via(config.what)}';
        },
        dispose: (res) {
          disposeCount++;
        },
      );

      final terminal = RawWhatTerminal(lazyRes, onInvalidated: () {});

      // 1. Activate terminal: in pure lazy mode, does NOT allocate resource until read!
      terminal.activate();
      expect(createCount, 0);
      expect(disposeCount, 0);

      // 2. Rapid upstream updates before anyone reads data: no thrashing and zero allocations!
      for (int i = 2; i <= 10; i++) {
        config.data = i;
      }
      expect(createCount, 0);
      expect(disposeCount, 0);

      // 3. First read pulls only the latest state!
      expect(terminal.data, 'Config-10');
      expect(createCount, 1);
      expect(disposeCount, 0);

      // 4. Further mutations defer re-creation and disposal until read
      config.data = 20;
      expect(disposeCount, 0); // Deferred
      expect(createCount, 1); // Not recreated yet!

      // Rapid intermediate mutation
      config.data = 30;
      expect(createCount, 1); // Still not recreated!
      expect(disposeCount, 0);

      // Read pulls latest
      expect(terminal.data, 'Config-30');
      expect(createCount, 2);
      expect(disposeCount, 1);

      terminal.deactivate();
      expect(disposeCount, 2);
    });

    test('5. Diamond graph evaluates atomic consistent state without intermediate glitches', () {
      final root = WhatController(1);
      final host = computed((via) => 'server-${via(root.what)}');
      final port = computed((via) => 8000 + via(root.what));

      final connectionHistory = <String>[];

      final conn = managed<String>(
        create: (via) {
          final c = '${via(host)}:${via(port)}';
          connectionHistory.add(c);
          return c;
        },
        update: (via, current) {
          final c = '${via(host)}:${via(port)}';
          connectionHistory.add(c);
          return c;
        },
        dispose: (_) {},
      );

      final terminal = RawWhatTerminal(conn, onInvalidated: () {});
      terminal.activate();

      // Upon read, evaluates initial consistent state
      expect(terminal.data, 'server-1:8001');
      expect(connectionHistory, ['server-1:8001']);

      // Mutate root: pushes dirty through both host and port
      root.data = 2;

      // Until read, no intermediate glitch state ('server-2:8001' or 'server-1:8002') is ever evaluated!
      expect(connectionHistory, ['server-1:8001']);

      // Upon read, evaluates exactly once with fully synchronized host & port!
      expect(terminal.data, 'server-2:8002');
      expect(connectionHistory, ['server-1:8001', 'server-2:8002']);

      terminal.deactivate();
    });

    test('6. Graceful deactivation protects against microtask churn', () async {
      int createCount = 0;
      int disposeCount = 0;

      final gracefulRes = managed<String>(
        create: (_) {
          createCount++;
          return 'GracefulConnection';
        },
        dispose: (_) {
          disposeCount++;
        },
        graceful: const Graceful(),
      );

      final terminal = RawWhatTerminal(gracefulRes, onInvalidated: () {});
      terminal.activate();
      expect(terminal.data, 'GracefulConnection');
      expect(createCount, 1);
      expect(disposeCount, 0);

      // Simulate rapid unmount & remount (tab change, route swap)
      terminal.deactivate();
      expect(disposeCount, 0); // Not disposed synchronously!

      terminal.activate(); // Re-activate in same tick!
      expect(createCount, 1); // Not recreated!
      expect(disposeCount, 0);

      await Future.microtask(() {});
      expect(createCount, 1);
      expect(disposeCount, 0); // Still active!

      // Final deactivate
      terminal.deactivate();
      expect(disposeCount, 0);

      await Future.microtask(() {});
      expect(disposeCount, 1); // Disposed after microtask!
    });

    test('7. Disposing error triggers uncaught error handler', () {
      final handler = _TestErrorHandler();
      LpdagUncaughtErrorHandler.instance = handler;

      try {
        final res = managed<String>(
          create: (_) => 'ErrorDispose',
          dispose: (_) => throw Exception('DisposeFailed'),
        );

        runZonedGuarded(() {
          final terminal = RawWhatTerminal(res, onInvalidated: () {})..activate();
          expect(terminal.data, 'ErrorDispose');

          // Deactivating calls _disposeCurrent which catches and delegates to _handleUncaughtError
          terminal.deactivate();
        }, (e, s) {});

        expect(handler.captured.length, 1);
        expect(handler.captured.first.$1.toString(), contains('DisposeFailed'));
      } finally {
        LpdagUncaughtErrorHandler.instance = null;
      }
    });

    test('8. Update callback returning new instance disposes old; throws uncaught error if dispose throws', () {
      final port = WhatController(80);
      final handler = _TestErrorHandler();
      LpdagUncaughtErrorHandler.instance = handler;

      try {
        final res = managed<String>(
          create: (via) => 'Server-${via(port.what)}',
          update: (via, current) => 'Server-${via(port.what)}', // Returns new string
          dispose: (s) {
            if (s == 'Server-80') {
              throw Exception('OldServerDisposeFailed');
            }
          },
        );

        runZonedGuarded(() {
          final terminal = RawWhatTerminal(res, onInvalidated: () {})..activate();
          expect(terminal.data, 'Server-80');

          port.data = 8080;
          expect(terminal.data, 'Server-8080');

          terminal.deactivate();
        }, (e, s) {});

        expect(handler.captured.length, 1);
        expect(handler.captured.first.$1.toString(), contains('OldServerDisposeFailed'));
      } finally {
        LpdagUncaughtErrorHandler.instance = null;
      }
    });

    test('9. WhatSignal triggers re-evaluation of managed node via WhatVia', () {
      final sig = WhatSignalController();
      int count = 0;

      final res = managed<int>(
        create: (via) {
          via(sig.what);
          return ++count;
        },
        dispose: (_) {},
      );

      final terminal = RawWhatTerminal(res, onInvalidated: () {})..activate();
      expect(terminal.data, 1);

      sig.emit();
      expect(terminal.data, 2);

      terminal.deactivate();
    });

    test('10. guard and reason prevent allocation and dispose previous data with version bump', () {
      final enabled = WhatController(true);
      int disposed = 0;

      final res = managed<String>(
        guard: (via) => via(enabled.what).guarded('NotEnabled'),
        create: (_) => 'ActiveResource',
        dispose: (_) => disposed++,
      );

      final terminal = RawWhatTerminal(res, onInvalidated: () {})..activate();
      expect(terminal.data, 'ActiveResource');
      expect(disposed, 0);

      // Disable: guard fails, disposes previous resource and returns empty with reason
      enabled.data = false;
      expect(terminal.isEmpty, isTrue);
      expect(terminal.snapshot.emptyReason, 'NotEnabled');
      expect(disposed, 1);

      terminal.deactivate();
    });

    test('11. create and update error transitions to ErrorWhatState', () {
      final triggerError = WhatController(false);

      final res = managed<String>(
        create: (via) {
          if (via(triggerError.what)) {
            throw StateError('CreateFailed');
          }
          return 'Healthy';
        },
        update: (via, current) {
          if (via(triggerError.what)) {
            throw StateError('UpdateFailed');
          }
          return current;
        },
        dispose: (_) {},
      );

      final terminal = RawWhatTerminal(res, onInvalidated: () {})..activate();
      expect(terminal.data, 'Healthy');

      // Update throws
      triggerError.data = true;
      expect(terminal.hasError, isTrue);
      expect(terminal.snapshot.error, isA<StateError>());

      // Recover
      triggerError.data = false;
      expect(terminal.hasData, isTrue);
      expect(terminal.data, 'Healthy');

      terminal.deactivate();
    });

    test('12. Inactive read returns EmptyWhatState; activate resets empty state', () {
      final res = managed<String>(
        create: (_) => 'ResourceData',
        dispose: (_) {},
      );

      // Reading while inactive
      expect(untracked.state(res).snapshot.isEmpty, isTrue);

      // Activating now should reset _state and evaluate
      final terminal = RawWhatTerminal(res, onInvalidated: () {})..activate();
      expect(terminal.data, 'ResourceData');

      terminal.deactivate();
    });

    test('13. debugInvalidate disposes current resource', () {
      int disposed = 0;
      final res = managed<String>(
        create: (_) => 'DebugTarget',
        dispose: (_) => disposed++,
      );

      final terminal = RawWhatTerminal(res, onInvalidated: () {})..activate();
      expect(terminal.data, 'DebugTarget');
      expect(disposed, 0);

      terminal.debugForceInvalidate();
      expect(disposed, 1);

      terminal.deactivate();
    });

    test('14. Eager managed node evaluates on activate, updates in microtask, cancels on deactivate', () async {
      final counter = WhatController(1);
      int createCount = 0;
      int updateCount = 0;
      int disposeCount = 0;

      final eagerRes = managed<String>(
        eager: true,
        create: (via) {
          createCount++;
          return 'Value-${via(counter.what)}';
        },
        update: (via, current) {
          updateCount++;
          return 'Value-${via(counter.what)}';
        },
        dispose: (_) => disposeCount++,
      );

      final terminal = RawWhatTerminal(eagerRes, onInvalidated: () {});
      terminal.activate();

      // In eager mode, activate automatically resolves synchronously!
      expect(createCount, 1);
      expect(terminal.data, 'Value-1');

      // Update counter: eager schedules microtask
      counter.data = 2;
      expect(updateCount, 0); // Not resolved yet

      await Future.microtask(() {});
      expect(updateCount, 1);
      expect(terminal.data, 'Value-2');

      // Deactivate cancels eager
      counter.data = 3;
      terminal.deactivate();
      await Future.microtask(() {});
      expect(updateCount, 1); // Did not run scheduled eager because deactivated!
    });

    test('15. Eager graceful managed node works with keepAlive', () async {
      int createCount = 0;
      int disposeCount = 0;

      final eagerGracefulRes = managed<String>(
        eager: true,
        graceful: const Graceful(),
        create: (_) {
          createCount++;
          return 'EagerGraceful';
        },
        dispose: (_) => disposeCount++,
      );

      final terminal = RawWhatTerminal(eagerGracefulRes, onInvalidated: () {});
      terminal.activate();
      expect(createCount, 1);
      expect(terminal.data, 'EagerGraceful');

      terminal.deactivate();
      expect(disposeCount, 0); // Graceful delay

      await Future.microtask(() {});
      expect(disposeCount, 1);
    });

    test('16. Cyclic evaluation in managed node throws LpdagCycleError', () {
      late final What<int> cycleRes;
      cycleRes = managed<int>(
        create: (via) => via(cycleRes) + 1,
        dispose: (_) {},
      );

      final terminal = RawWhatTerminal(cycleRes, onInvalidated: () {});
      terminal.activate();
      expect(() => terminal.data, throwsA(isA<WhatSnapshotExtractionException>()));
      expect(terminal.snapshot.error, isA<LpdagCycleError>());
      terminal.deactivate();
    });
  });
}
