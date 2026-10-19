// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/foundation_bridge_section.dart';

/// Sub-store for Section 09: Foundation & Listenable Bridge
class FoundationBridgeStore {
  final textController = TextEditingController(text: 'Reactive Flutter');
  late final textWhat = textController.toWhatBy((c) => c.text);

  final counterController = WhatController<int>(10);
  late final counterListenable = counterController.what.toListenable();

  void incrementCounter() => counterController.set(counterController.data + 1);

  void resetCounter() => counterController.set(10);

  ShowcaseSection get section => ShowcaseSection(
        id: '11_foundation_bridge',
        number: '11',
        title: 'Foundation & Listenable Bridges',
        subtitle: 'Two-way bridges between Flutter Listenable and What nodes',
        badge: 'Bridges',
        icon: Icons.sync_alt_rounded,
        codeSnippet: '''
// 1. Input Bridge: Convert TextEditingController to reactive What
final textController = TextEditingController();
late final textWhat = textController.toWhatBy((c) => c.text);

// 2. Output Bridge: Convert What to ValueListenable
final counter = WhatController<int>(0);
final ValueListenable<int> listenable = counter.what.toListenable();''',
        highlights: const [
          'Listenable.toWhat() / toWhatBy(): Bridges Flutter inputs seamlessly into What pipelines.',
          'What.toListenable(): Enables interoperability with standard Flutter ValueListenableBuilders.',
          'Automatic subscription lifecycle upon What activation/deactivation.',
        ],
        roadmapTree: '''
Listenable.toWhat() / .toWhatBy(selector)      -> Bridges Flutter inputs to What<T>
What<T>.toListenable()                        -> Bridges What<T> to ValueListenable<T>
Stream<T>.toWhat()                            -> Bridges async streams to What<T>
''',
        builder: () => FoundationBridgeSectionDemo(),
      );
}
