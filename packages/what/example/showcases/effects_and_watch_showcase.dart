// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/effect.dart';
import 'package:what/what.dart';

/// Showcase 4: Execution & Side-Effects (1-Tick Compressed)
///
/// Demonstrates What's terminal side-effects architecture:
/// 1. `what.effect().run()`: Standalone active runner dedicated to executing a 1:1 single node side-effect
/// 2. [Effect.via] with [EffectRunner]: Dynamic [WhatVia] dependency tracking with standalone execution
/// 3. [Effect.handled]: Declarative effect providing [EffectHandle] for teardown / cleanup callbacks
/// 4. `what.effect().debounce()` & `what.effect().throttle()`: Time-domain rate limiters
void main() async {
  print('=== Execution & Side-Effects ===\n');

  // ---------------------------------------------------------------------------
  // 1. what.effect().run(): 1:1 State Side-Effect
  // ---------------------------------------------------------------------------
  print('--- 1. what.effect().run() ---');
  final score = WhatController<int>(0);

  final scoreRunner = score.what.effect(() {
    print('  [Runner] Score updated to: ${untracked(score.what)}');
  }).run();

  score.data = 10;
  await Future<void>.delayed(Duration.zero); // Microtask batch flush
  scoreRunner.deactivate();
  print('');

  // ---------------------------------------------------------------------------
  // 2. Effect.via + run(): Dynamic WhatVia Terminal Sink
  // ---------------------------------------------------------------------------
  print('--- 2. Effect.via().run() ---');
  final user = WhatController<String>('Alice');
  final role = WhatController<String>('Member');

  // Executes automatically when any dependency read via [via] mutates
  final auditRunner = Effect.via((via) {
    final currentName = via(user.what);
    final currentRole = via(role.what);
    print('  [Audit Runner] 📝 Logging: User $currentName has role $currentRole');
  }).run();

  await Future<void>.delayed(Duration.zero); // Initial run

  role.data = 'SuperAdmin';
  await Future<void>.delayed(Duration.zero); // Reacts to role change

  auditRunner.deactivate();
  print('');

  // ---------------------------------------------------------------------------
  // 3. Effect.handled: Cleanup & Teardown Handlers
  // ---------------------------------------------------------------------------
  print('--- 3. Effect.handled with Cleanup ---');
  final channel = WhatController<String>('general');

  // Runs on mutations and cleans up resources from previous turn
  final channelRunner = channel.what.effect.handled((handle) {
    final currentChannel = channel.data;
    print('  [Channel Runner] 📡 Subscribing to #$currentChannel');

    handle.onCleanup(() {
      print('  [Channel Cleanup] 🛑 Leaving channel #$currentChannel');
    });
  }).run();

  channel.data = 'announcements';
  await Future<void>.delayed(Duration.zero);

  channel.data = 'random';
  await Future<void>.delayed(Duration.zero);

  channelRunner.deactivate();
  print('');

  // ---------------------------------------------------------------------------
  // 4. what.effect.debounce & throttle
  // ---------------------------------------------------------------------------
  print('--- 4. what.effect.debounce & throttle ---');
  final searchInput = WhatController<String>('');

  final debouncedLogger = searchInput.what.effect.debounce(
    const Duration(milliseconds: 30),
    () {
      print('  [Debounced Effect] 🚀 Search API Request: "${searchInput.data}"');
    },
  ).run();

  // Bursty input
  searchInput.data = 'fl';
  searchInput.data = 'flu';
  searchInput.data = 'flutt';
  searchInput.data = 'flutter';

  // Wait for debounce silence window
  await Future<void>.delayed(const Duration(milliseconds: 50));
  debouncedLogger.deactivate();
  print('\n=== End Showcase ===');
}
