// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/imperative_signals_section.dart';

class ImperativeSignalsStore {
  // A persistent state simulating a zombie payload if implemented incorrectly
  final zombieDialogState = WhatController<bool>(false);

  // A true transient signal for the proper architecture
  final cleanDialogSignal = WhatSignalController();

  void triggerZombie() => zombieDialogState.set(true);
  void clearZombie() => zombieDialogState.set(false);

  void triggerClean() => cleanDialogSignal.emit();

  ShowcaseSection get section => ShowcaseSection(
        id: '07_imperative_signals',
        number: '07',
        title: 'Imperative Signals vs State',
        subtitle: 'Transient Events vs Zombie States',
        badge: 'Transient',
        icon: Icons.flash_on_rounded,
        codeSnippet: '''
// [Anti-Pattern] State-based event (Leaves Zombie Payload)
final showDialogState = WhatController<bool>(false);

// [Recommended] Signal-based event (Fires exactly once)
final showDialogSignal = WhatSignalController();

WhatListener(
  [showDialogSignal.what],
  (context) => showDialog(...),
  child: FormWidget(),
);
''',
        highlights: [
          'WhatSignalController for pure transient events.',
          'Zero payload caching prevents zombie dialogs on remount.',
          'Decouples persistent state from one-off actions.',
        ],
        builder: () => ImperativeSignalsSection(store: this),
      );
}
