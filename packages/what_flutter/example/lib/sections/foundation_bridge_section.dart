// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 09: Foundation & Listenable Two-Way Bridges (toWhat & toListenable)
base class FoundationBridgeSectionDemo extends WhatWidget {
  const FoundationBridgeSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.foundationBridge;
    final query = via(store.textWhat);

    return Column(
      children: [
        ShowcaseCard(
          title: 'Input Bridge (Listenable.toWhatBy / toWhat)',
          badge: 'toWhat()',
          description:
              'Convert standard Flutter controllers (TextEditingController, ScrollController, ValueNotifier) into reactive What nodes.',
          child: Column(
            children: [
              TextField(
                controller: store.textController,
                decoration: const InputDecoration(
                  labelText: 'Type something to test toWhat()...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SandboxContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Live Analyzed Text: "$query"',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Chip(
                          label: Text('Chars: ${query.length}'),
                        ),
                        Chip(
                          label: Text(
                            'Words: ${query.trim().isEmpty ? 0 : query.trim().split(RegExp(r'\s+')).length}',
                          ),
                        ),
                        Chip(
                          label: Text('Upper: ${query.toUpperCase()}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShowcaseCard(
          title: 'Output Bridge (What.toListenable)',
          badge: 'toListenable()',
          description:
              'Convert any What node into a standard Flutter ValueListenable for seamless interop with existing widgets like ValueListenableBuilder.',
          child: Column(
            children: [
              SandboxContainer(
                child: ValueListenableBuilder<int>(
                  valueListenable: store.counterListenable,
                  builder: (context, value, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Consumed via ValueListenableBuilder:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$value',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: store.incrementCounter,
                    child: const Text('Increment What'),
                  ),
                  OutlinedButton(
                    onPressed: store.resetCounter,
                    child: const Text('Reset What (10)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
