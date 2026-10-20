// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:what/effect.dart';
import 'package:what/what.dart';

/// Showcase 2: The Dynamic Triad (Unified Functors)
///
/// Demonstrates What's core topological triad:
/// 1. [computed]: Pure functional derived computations with reactive guards
/// 2. [ComputedFunctor.future] & [ComputedFunctor.stream]: Asynchronous data querying
/// 3. [switched]: Dynamic topological branch morphing at runtime
/// 4. [managed]: Synchronous external resource lifecycle supervision (Subscriber-driven dormancy)
void main() async {
  print('=== The Dynamic Triad ===\n');

  // ---------------------------------------------------------------------------
  // 1. computed: Pure Functional Derivations
  // ---------------------------------------------------------------------------
  print('--- 1. computed (Synchronous Derivation) ---');
  final firstName = WhatController('John');
  final lastName = WhatController('Doe');

  final fullName = computed((via) {
    return '${via(firstName.what)} ${via(lastName.what)}';
  });

  print('Full Name: ${untracked(fullName)}');
  firstName.data = 'Jane';
  print('Updated Full Name: ${untracked(fullName)}\n');

  // ---------------------------------------------------------------------------
  // 2. computed.future: Async Parameter-Tracking Queries
  // ---------------------------------------------------------------------------
  print('--- 2. computed.future (Asynchronous Query) ---');
  final userId = WhatController('user_42');

  final userProfile = computed.future(
    (via) async {
      final id = via(userId.what);
      // Simulating network latency
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return {'id': id, 'name': 'Member $id', 'role': 'Admin'};
    },
    initialFactory: () => {'id': 'pending', 'name': 'Loading...', 'role': 'None'},
  );

  // Inactive Dormancy: Future is lazily initiated only when an active consumer connects
  final profileRunner = userProfile.effect(() {
    print('  [Profile Runner] Fresh Profile received: ${untracked(userProfile)}');
  }).run();

  print('Initial Synchronous Cache: ${untracked(userProfile)}');
  await Future<void>.delayed(const Duration(milliseconds: 40));
  print('Fetched Profile on demand: ${untracked(userProfile)}\n');

  profileRunner.deactivate();

  // ---------------------------------------------------------------------------
  // 3. switched: Dynamic Topology Branch Morphing
  // ---------------------------------------------------------------------------
  print('--- 3. switched (Dynamic Branch Morphing) ---');
  final isPremium = WhatController(false);
  final freeFeed = WhatController('Free Feed: Standard Content');
  final premiumFeed = WhatController('Premium Feed: Exclusive 4K Content');

  // Dynamically flattens into an active subtree based on isPremium state
  final activeFeed = switched((via) {
    return via(isPremium.what) ? premiumFeed.what : freeFeed.what;
  });

  final feedRunner = activeFeed.effect(() {
    print('  [Feed Runner] Received: "${untracked(activeFeed)}"');
  }).run();

  print('Active Feed: ${untracked(activeFeed)}'); // Free Feed: Standard Content

  print('Upgrading user to Premium...');
  isPremium.data = true; // Automatically swaps reactive upstream edge!

  await Future<void>.delayed(Duration.zero);
  print('Active Feed: ${untracked(activeFeed)}\n'); // Premium Feed: Exclusive 4K Content

  feedRunner.deactivate();

  // ---------------------------------------------------------------------------
  // 4. managed: External Resource Lifecycle Supervision
  // ---------------------------------------------------------------------------
  print('--- 4. managed (Subscriber-Driven Inactive Dormancy) ---');

  // Simulating an external resource (e.g. WebSocket, native hardware handle)
  var allocatedHandles = 0;

  final socketResource = managed<String>(
    create: (via) {
      allocatedHandles++;
      print('  [Managed] 🔌 Socket allocated! Active handles: $allocatedHandles');
      return 'SocketConnection#$allocatedHandles';
    },
    dispose: (socket) {
      allocatedHandles--;
      print('  [Managed] 🛑 Socket closed! Active handles: $allocatedHandles');
    },
  );

  print('Before subscriber: allocatedHandles = $allocatedHandles (Dormant)');

  // Downstream subscriber connects -> Triggers on-demand allocation
  final socketRunner = socketResource.effect(() {
    print('  [Socket Runner] Using ${untracked(socketResource)}');
  }).run();

  await Future<void>.delayed(Duration.zero);
  print('While subscribed: allocatedHandles = $allocatedHandles');

  // Downstream subscriber deactivates -> Automatically cleans up
  print('Subscriber deactivates...');
  socketRunner.deactivate();
  print('After deactivation: allocatedHandles = $allocatedHandles (Dormant again)');
}
