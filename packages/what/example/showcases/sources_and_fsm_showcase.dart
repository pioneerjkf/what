// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:what/what.dart';

/// Showcase 1: Reactive Nodes - Source Handles & 3-State FSM Snapshot
///
/// Demonstrates:
/// 1. [WhatController] & [RawWhatController] (Producer vs Consumer encapsulation)
/// 2. [WhatSignalController] (Discrete event signals)
/// 3. [WhatSnapshot] & 3-State FSM Pattern Matching (`data`, `empty`, `error`)
void main() {
  print('--- 1. Producer / Consumer Encapsulation ---');
  // Controller is the mutable Producer handle; .what is the read-only Consumer view
  final counterController = WhatController<int>(0);
  final What<int> counterView = counterController.what;

  print('Initial Counter: ${untracked(counterView)}');
  counterController.data = 42;
  print('Updated Counter: ${untracked(counterView)}\n');

  print('--- 2. Discrete Event Signals ---');
  // Signals model stateless pulses (e.g. button clicks, refresh events)
  final refreshSignalController = WhatSignalController();
  final WhatSignal refreshSignal = refreshSignalController.what;

  // Pattern A: Discrete invalidation pulse via WhatVia
  final autoRefreshed = computed((via) {
    via(refreshSignal);
    return 'AutoRefreshed -> counter: ${via(counterView)}';
  });

  // Pattern B: Dynamic tracking via WhatVia (when tick sequence number is needed)
  final syncCount = computed((via) {
    final signalTick = via(refreshSignal);
    final value = via(counterView);
    return 'Synced #$signalTick -> value: $value';
  });

  print(untracked(autoRefreshed));
  print(untracked(syncCount)); // Initial tick 0
  refreshSignalController.emit(); // Emits next version tick
  print(untracked(autoRefreshed));
  print(untracked(syncCount)); // Synced #1 -> value: 42\n

  print('--- 3. 3-State FSM Snapshot ([WhatSnapshot]) ---');
  // State 1: Valid Data
  final validNode = What<String>.constant('Active Session');
  print('State: hasData=${untracked.state(validNode).hasData}, data="${untracked(validNode)}"');

  // State 2: Explicit Empty (null is a valid data, empty is a distinct FSM state)
  final emptyNode = What<String>.empty('WaitingForNetwork');
  print('State: isEmpty=${untracked.state(emptyNode).isEmpty}, reason="${untracked.state(emptyNode).emptyReason}"');

  // State 3: Failure Boundary
  final errorNode = What<String>.error(Exception('Connection timeout'));
  print('State: hasError=${untracked.state(errorNode).hasError}, error="${untracked.state(errorNode).error}"\n');

  print('--- 4. Safe Pattern Matching via snapshot.match ---');
  void printStatus(What<String> node) {
    untracked.state(node).snapshot.match(
      data: (value) => print('  -> [DATA]: $value'),
      empty: () => print('  -> [EMPTY]: Unready (${untracked.state(node).emptyReason})'),
      error: (err, _) => print('  -> [ERROR]: Failed with $err'),
    );
  }

  printStatus(validNode);
  printStatus(emptyNode);
  printStatus(errorNode);
}
