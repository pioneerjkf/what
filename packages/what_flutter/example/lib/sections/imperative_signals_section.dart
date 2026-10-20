// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../store/sections/imperative_signals_store.dart';

base class ImperativeSignalsSection extends WhatWidget {
  const ImperativeSignalsSection({super.key, required this.store});

  final ImperativeSignalsStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    return WhatListener(
      store.cleanDialogSignal.what,
      (ctx, _) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Clean Signal Fired! (Zero Zombie State)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: WhatListener<bool>(
        store.zombieDialogState.what,
        (ctx, isZombie) {
          if (isZombie) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Zombie State Fired! (Requires manual clearing)'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
            // [BUG DEMONSTRATION]
            // We intentionally do NOT clear the state here.
            // Because WhatListener has a 0-Run on Mount invariant, the snackbar won't pop on remount.
            // BUT because the state is stuck at 'true', tapping the button again will NOT trigger a mutation!
            // The button becomes permanently broken until the state is manually cleared.
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Try triggering both buttons, then navigate away from this section and come back. '
                'The Signal leaves no cached data behind, while boolean states force you to write manual boilerplate to clear them.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: store.triggerClean,
                icon: const Icon(Icons.flash_on),
                label: const Text('Fire Clean Signal (Recommended)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: store.triggerZombie,
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Trigger Zombie State (Anti-Pattern)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
