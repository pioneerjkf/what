// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/effect.dart';
import 'package:what/what.dart';

/// Showcase 3: Fluent Pipeline Operators
///
/// Demonstrates What's fluent rate-limiting and cache operators:
/// 1. [.distinct]: Filters duplicate values and suppresses redundant invalidations
/// 2. [.debounced]: Rate-limits bursty mutations across quiet periods
/// 3. [.throttled]: Enforces maximum invocation frequency
/// 4. [.retained]: Implements Stale-While-Revalidate (SWR) cache pattern
/// 5. [.graceful]: Shields expensive upstream nodes with a deactivation grace period
void main() async {
  print('=== Fluent Pipeline Operators ===\n');

  // ---------------------------------------------------------------------------
  // 1. .distinct: Duplicate Filter
  // ---------------------------------------------------------------------------
  print('--- 1. .distinct() ---');
  final count = WhatController<int>(0);
  var distinctNotifications = 0;

  final distinctCount = count.what.distinct();
  final distinctRunner = distinctCount.effect(() {
    distinctNotifications++;
    print('  [Distinct Runner] Received: ${distinctCount.peek} (Total ticks: $distinctNotifications)');
  }).run();

  count.data = 1;
  await Future<void>.delayed(Duration.zero); // Fires tick 1

  count.data = 1; // Duplicate, dropped by distinct filter
  await Future<void>.delayed(Duration.zero); // Dropped, no fire

  count.data = 2; // Fresh value, fires tick 2
  await Future<void>.delayed(Duration.zero);

  distinctRunner.deactivate();
  print('Distinct finished: Expected 2 notifications, Got $distinctNotifications\n');

  // ---------------------------------------------------------------------------
  // 2. .debounced: Quiet-Period Rate Limiter
  // ---------------------------------------------------------------------------
  print('--- 2. .debounced() ---');
  final searchInput = WhatController<String>('');
  final debouncedInput = searchInput.what.debounced(const Duration(milliseconds: 30));

  final debounceRunner = debouncedInput.effect(() {
    print('  [Debounce Runner] Finalized Query: "${debouncedInput.peek}"');
  }).run();

  // Rapid typing burst
  searchInput.data = 'd';
  searchInput.data = 'da';
  searchInput.data = 'dar';
  searchInput.data = 'dart';

  await Future<void>.delayed(const Duration(milliseconds: 10)); // Silence not yet reached
  print('  Typing in progress... (no notification yet)');

  await Future<void>.delayed(const Duration(milliseconds: 40)); // Silence reached
  debounceRunner.deactivate();
  print('');

  // ---------------------------------------------------------------------------
  // 3. .throttled: Frequency Limiter
  // ---------------------------------------------------------------------------
  print('--- 3. .throttled() ---');
  final scrollOffset = WhatController<double>(0.0);
  final throttledScroll = scrollOffset.what.throttled(
    const Duration(milliseconds: 30),
    leading: true,
    trailing: true,
  );

  final throttleRunner = throttledScroll.effect(() {
    print('  [Throttle Runner] Offset: ${throttledScroll.peek}');
  }).run();

  scrollOffset.data = 10.0; // Leading edge fires immediately
  scrollOffset.data = 20.0;
  scrollOffset.data = 30.0; // Trailing edge buffered

  await Future<void>.delayed(const Duration(milliseconds: 40));
  throttleRunner.deactivate();
  print('');

  // ---------------------------------------------------------------------------
  // 4. .retained: Stale-While-Revalidate (SWR) Pattern
  // ---------------------------------------------------------------------------
  print('--- 4. .retained() (SWR Cache) ---');
  final liveSource = WhatController<String>('Initial Cached Data');
  final pendingCoupler = WhatCoupler<bool>.late();

  final swrFeed = liveSource.what.retained(pending: pendingCoupler);

  print('Current SWR Data: "${swrFeed.peek}"');
  print('Is Pending Refresh: ${pendingCoupler.what.peek}');

  // Simulating an asynchronous background invalidation
  liveSource.data = 'Fresh Remote Payload';
  print('Updated SWR Data: "${swrFeed.peek}"\n');

  // ---------------------------------------------------------------------------
  // 5. .graceful: Deactivation Buffer
  // ---------------------------------------------------------------------------
  print('--- 5. .graceful() (Mooring Period) ---');
  final rawResource = WhatController<String>('Hardware Connection');
  final resilientResource = rawResource.what.graceful(
    const Graceful.period(Duration(milliseconds: 30)),
  );

  final resRunner = resilientResource.effect(() {}).run();
  print('Connected to resilient resource');

  // Deactivate: Graceful mooring timer begins, preventing immediate tear-down
  resRunner.deactivate();
  print('Resilient resource gracefully moored against rapid re-subscription');
}
