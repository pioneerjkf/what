// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/text_editing_controller_section.dart';

/// Sub-store for Section 05: Standard Form Input & Listenable Bridge (`toWhatBy`).
class TextEditingControllerStore {
  TextEditingControllerStore({
    Graceful? graceful = Graceful.microtask,
  }) : _mutationCount = WhatController<int>(0) {
    // 1. Flutter standard TextEditingController
    textController = TextEditingController(text: 'Hello What World!');

    // 2. Bridge Flutter TextEditingController -> What reactive state via toWhatBy
    textWhat = textController.toWhatBy((c) => c.text, graceful: graceful);

    // 3. Derived reactive computed metrics
    _charCount = computed<int>((via) => via(textWhat).length);
    _wordCount = computed<int>((via) {
      final text = via(textWhat).trim();
      if (text.isEmpty) return 0;
      return text.split(RegExp(r'\s+')).length;
    });
  }

  final WhatController<int> _mutationCount;

  /// Native Flutter [TextEditingController].
  late final TextEditingController textController;

  /// Reactive string stream extracted directly from [textController] via `.toWhatBy((c) => c.text)`.
  late final What<String> textWhat;

  late final What<int> _charCount;
  late final What<int> _wordCount;

  /// Number of programmatic external mutations dispatched.
  What<int> get mutationCount => _mutationCount.what;

  /// Reactive character count derived from [textWhat].
  What<int> get charCount => _charCount;

  /// Reactive word count derived from [textWhat].
  What<int> get wordCount => _wordCount;

  /// Programmatically mutates the text in the active controller while preserving cursor.
  void _mutateController(
      void Function(TextEditingController controller) action) {
    action(textController);
    _mutationCount.set(_mutationCount.data + 1);
  }

  /// Clears the controller text.
  void clear() {
    _mutateController((c) => c.clear());
  }

  /// Transforms current query to uppercase.
  void toUpperCase() {
    _mutateController((c) {
      final current = c.text;
      c.value = c.value.copyWith(
        text: current.toUpperCase(),
        selection: TextSelection.collapsed(offset: current.length),
      );
    });
  }

  /// Transforms current query to lowercase.
  void toLowerCase() {
    _mutateController((c) {
      final current = c.text;
      c.value = c.value.copyWith(
        text: current.toLowerCase(),
        selection: TextSelection.collapsed(offset: current.length),
      );
    });
  }

  /// Prepends a tag prefix to current query.
  void prependTag(String tag) {
    _mutateController((c) {
      final next = '$tag ${c.text}';
      c.value = c.value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });
  }

  /// Appends an emoji suffix to current query.
  void appendSuffix(String suffix) {
    _mutateController((c) {
      final next = '${c.text} $suffix';
      c.value = c.value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });
  }

  /// Sets a sample Korean text for IME verification.
  void setKoreanSample() {
    _mutateController((c) {
      const sample = '리액티브 상태관리의 새로운 패러다임: What 프레임워크';
      c.value = TextEditingValue(
        text: sample,
        selection: const TextSelection.collapsed(offset: sample.length),
      );
    });
  }

  /// Resets to default initial greeting.
  void resetDefault() {
    _mutateController((c) {
      const sample = 'Hello What World!';
      c.value = TextEditingValue(
        text: sample,
        selection: const TextSelection.collapsed(offset: sample.length),
      );
    });
  }

  /// Showcase section metadata.
  ShowcaseSection get section => ShowcaseSection(
        id: '05_text_editing_controller',
        number: '05',
        title: 'Form Input & Listenable Bridge (toWhatBy)',
        subtitle:
            'Standard Flutter TextEditingController with zero-leak toWhatBy bridge & managed lifecycle',
        badge: 'Listenable Bridge',
        icon: Icons.edit_note_rounded,
        codeSnippet: _codeSnippet,
        highlights: const [
          'Standard Architecture: Uses native Flutter TextEditingController directly with 0 custom wrapper bloat.',
          'Zero-Leak Bridge: Extracts reactive string updates via toWhatBy((c) => c.text) with Demand-Driven Dormancy.',
          'Natural Unidirectional Flow: UI typing updates Flutter controller; What computed reacts surgically.',
          'Lifecycle Management: Integrates seamlessly with managed() for automatic disposal on widget unmount.',
        ],
        roadmapTree: '''
[What Form Input Architecture]
 ├── TextEditingController                 -> Native Flutter UI Controller
 │
 ├── controller.toWhatBy((c) => c.text)   -> Demand-Driven Reactive Bridge
 │    ├── Automatic Dormancy Detachment   -> Zero listener leaks when inactive
 │    └── Derived computations            -> computed(() => via(textWhat).length)
 │
 └── managed(create, dispose)              -> Auto-disposed Lifecycle Binding
      ├── create: (_) => TextEditingController(...)
      ├── dispose: (ctrl) => ctrl.dispose()
      └── graceful: Graceful.microtask     -> Dormant Mooring Preservation
''',
        builder: () => const TextEditingControllerSection(),
      );

  static const _codeSnippet = '''
// 1. Native Flutter TextEditingController
final textController = TextEditingController(text: 'Hello What World!');

// 2. Bridge controller to reactive What node with toWhatBy
late final textWhat = textController.toWhatBy((c) => c.text);

// 3. Surgical computations derived from text
late final charCount = computed((via) => via(textWhat).length);

// 4. In UI widget:
TextField(controller: textController);
''';
}
