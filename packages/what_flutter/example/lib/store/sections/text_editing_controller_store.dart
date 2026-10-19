// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/text_editing_controller_section.dart';

/// Sub-store for Section 05: Zero-Jump Form Binding & WhatTextEditingController.
class TextEditingControllerStore {
  TextEditingControllerStore({
    Graceful? gracefulPolicy = const Graceful.period(Duration(minutes: 5)),
  })  : _query = WhatController<String>('Hello What World!'),
        _mutationCount = WhatController<int>(0) {
    _charCount = computed<int>((via) => via(_query.what).length);
    _wordCount = computed<int>((via) {
      final text = via(_query.what).trim();
      if (text.isEmpty) return 0;
      return text.split(RegExp(r'\s+')).length;
    });
    textControllerWhat = managed<WhatTextEditingController>(
      create: (via) => _query.bindTextController(),
      dispose: (c) => c.dispose(),
      graceful: gracefulPolicy,
    );
  }

  final WhatController<String> _query;
  final WhatController<int> _mutationCount;

  late final What<int> _charCount;
  late final What<int> _wordCount;

  /// Managed reactive [WhatTextEditingController] automatically disposed upon Inactive Dormancy
  /// with a graceful mooring window to preserve cursor/selection across navigation.
  late final What<WhatTextEditingController> textControllerWhat;

  /// The underlying two-way reactive state controller.
  WhatController<String> get query => _query;

  /// Number of programmatic external mutations dispatched.
  What<int> get mutationCount => _mutationCount.what;

  /// Reactive character count derived from [query].
  What<int> get charCount => _charCount;

  /// Reactive word count derived from [query].
  What<int> get wordCount => _wordCount;

  /// Clears the query state.
  void clear() {
    _query.set('');
    _mutationCount.set(_mutationCount.data + 1);
  }

  /// Transforms current query to uppercase.
  void toUpperCase() {
    _query.set(_query.data.toUpperCase());
    _mutationCount.set(_mutationCount.data + 1);
  }

  /// Transforms current query to lowercase.
  void toLowerCase() {
    _query.set(_query.data.toLowerCase());
    _mutationCount.set(_mutationCount.data + 1);
  }

  /// Prepends a tag prefix to current query.
  void prependTag(String tag) {
    _query.set('$tag ${_query.data}');
    _mutationCount.set(_mutationCount.data + 1);
  }

  /// Appends an emoji suffix to current query.
  void appendSuffix(String suffix) {
    _query.set('${_query.data} $suffix');
    _mutationCount.set(_mutationCount.data + 1);
  }

  /// Sets a sample Korean text for IME verification.
  void setKoreanSample() {
    _query.set('리액티브 상태관리의 새로운 패러다임: What 프레임워크');
    _mutationCount.set(_mutationCount.data + 1);
  }

  /// Resets to default initial greeting.
  void resetDefault() {
    _query.set('Hello What World!');
    _mutationCount.set(_mutationCount.data + 1);
  }

  /// Showcase section metadata.
  ShowcaseSection get section => ShowcaseSection(
        id: '05_text_editing_controller',
        number: '05',
        title: 'Zero-Jump Form Binding & WhatTextEditingController',
        subtitle:
            'Two-way form synchronization, cursor jumping immunity & lifecycle auto-disposal',
        badge: '2-Way Form',
        icon: Icons.edit_note_rounded,
        codeSnippet: _codeSnippet,
        highlights: const [
          'Bidirectional Synchronization: UI typing seamlessly updates WhatController with 0 feedback ping-pong.',
          'Zero-Jump Invariant: External state updates preserve cursor and selection via Smart Clamping.',
          'CJK IME Composition Protection: Prevents Korean/Japanese/Chinese syllable separation during typing.',
          'Lifecycle Management: Integrates seamlessly with managed() or standard Store/State lifecycles.',
        ],
        roadmapTree: '''
[What Form Binding Pipeline]
 ├── WhatTextEditingController(what)        -> Two-Way Reactive TextEditingController
 │    ├── .what                             -> Bound WhatController<String>
 │    ├── .graceful                         -> Debounced sync policy (e.g. 5m TTL)
 │    └── Smart Clamping                    -> Zero-Jump cursor / IME composition guard
 │
 ├── bindTextController(...)                -> Declarative Widget Extension
 │    └── textField.bind(controller)
 │
 └── managed(create, dispose)               -> Auto-disposed Lifecycle Binding
      ├── create: (_) => WhatTextEditingController(what)
      ├── dispose: (ctrl) => ctrl.dispose()
      └── graceful: graceful.period(...)    -> Dormant Mooring Preservation
''',
        builder: () => TextEditingControllerSection(),
      );

  static const _codeSnippet = '''
// 1. Define reactive string controller in Store / ViewModel
final query = WhatController<String>('Hello What!');

// 2. Instantiate WhatTextEditingController bound to WhatController
// In Store:
late final controller = WhatTextEditingController(query);

// Or in UI with managed() reactive lifecycle:
late final managedCtrl = managed(
  create: (_) => WhatTextEditingController(query),
  dispose: (c) => c.dispose(),
  graceful: graceful.period(const Duration(minutes: 5)),
);
''';
}
