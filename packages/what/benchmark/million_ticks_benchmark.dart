// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:what/what.dart';

/// Scenario 1: Direct 1:1 Pipeline (Controller -> RawWhatTerminal)
final class DirectPipelineBenchmark extends BenchmarkBase {
  DirectPipelineBenchmark() : super('Direct 1:1 Pipeline');

  late WhatController<int> controller;
  late RawWhatTerminal<int> terminal;
  int tick = 0;
  int sink = 0;

  @override
  void setup() {
    controller = WhatController<int>(0);
    terminal = RawWhatTerminal<int>(controller.what, onInvalidated: () {});
    terminal.activate();
    tick = 0;
    sink = 0;
  }

  @override
  void run() {
    controller.set(++tick);
    sink = terminal.data;
  }

  @override
  void teardown() {
    terminal.deactivate();
  }
}

/// Scenario 2: Deep 5-Stage Transformation Pipeline (Map -> Map -> Select -> Distinct -> Terminal)
final class DeepPipelineBenchmark extends BenchmarkBase {
  DeepPipelineBenchmark() : super('Deep 5-Stage Pipeline');

  late WhatController<int> controller;
  late RawWhatTerminal<int> terminal;
  int tick = 0;
  int sink = 0;

  @override
  void setup() {
    controller = WhatController<int>(0);
    final stage1 = computed((via) => via(controller.what) + 1);
    final stage2 = computed((via) => via(stage1) * 2);
    final stage3 = computed((via) => via(stage2) + 10);
    final pipeline = stage3.distinct();

    terminal = RawWhatTerminal<int>(pipeline, onInvalidated: () {});
    terminal.activate();
    tick = 0;
    sink = 0;
  }

  @override
  void run() {
    controller.set(++tick);
    sink = terminal.data;
  }

  @override
  void teardown() {
    terminal.deactivate();
  }
}

/// Scenario 3: Reactive Computed Diamond DAG (2 Sources -> 2 Maps -> Computed -> Terminal)
final class DiamondPipelineBenchmark extends BenchmarkBase {
  DiamondPipelineBenchmark() : super('Diamond Computed DAG');

  late WhatController<int> controllerA;
  late WhatController<int> controllerB;
  late RawWhatTerminal<int> terminal;
  int tick = 0;
  int sink = 0;

  @override
  void setup() {
    controllerA = WhatController<int>(0);
    controllerB = WhatController<int>(0);

    final branchA = computed((via) => via(controllerA.what) * 2);
    final branchB = computed((via) => via(controllerB.what) + 5);

    final diamond = computed((via) {
      final a = via(branchA);
      final b = via(branchB);
      return a + b;
    });

    terminal = RawWhatTerminal<int>(diamond, onInvalidated: () {});
    terminal.activate();
    tick = 0;
    sink = 0;
  }

  @override
  void run() {
    controllerA.set(++tick);
    sink = terminal.data;
  }

  @override
  void teardown() {
    terminal.deactivate();
  }
}

/// Formats a large number with thousands separators (commas).
String _formatNumber(num value) {
  final parts = value.toString().split('.');
  final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
  parts[0] = parts[0].replaceAll(regex, ',');
  return parts.join('.');
}

void _runAndReport(BenchmarkBase benchmark) {
  // 1. Standard BenchmarkBase report
  benchmark.report();

  // 2. Measure detailed metrics
  final usPerOp = benchmark.measure();
  final nsPerOp = usPerOp * 1000.0;
  final opsPerSec = (1000000.0 / usPerOp).round();

  print('  ↳ Latency    : ${nsPerOp.toStringAsFixed(2)} ns/op (${usPerOp.toStringAsFixed(4)} µs/op)');
  print('  ↳ Throughput : ${_formatNumber(opsPerSec)} ops/sec\n');
}

void main() {
  print('===============================================================');
  print('  What Reactive Pipeline Benchmark (benchmark_harness)');
  print('===============================================================');

  print('\n[1/3] Scenario 1: Direct 1:1 Pipeline');
  _runAndReport(DirectPipelineBenchmark());

  print('[2/3] Scenario 2: Deep 5-Stage Transformation Pipeline');
  _runAndReport(DeepPipelineBenchmark());

  print('[3/3] Scenario 3: Reactive Diamond Computation DAG');
  _runAndReport(DiamondPipelineBenchmark());

  print('===============================================================');
  print('  Benchmark Suite Completed');
  print('===============================================================');
}
