// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../models/section.dart';
import '../../sections/scroll_kinematics_section.dart';

class ScrollKinematicsStore {
  ShowcaseSection get section => ShowcaseSection(
        id: '08_scroll_kinematics',
        number: '08',
        title: 'Scroll Kinematics & 120fps Rebuilds',
        subtitle: '120fps Surgical Micro-Rebuild Optimization',
        badge: 'Optimization',
        icon: Icons.speed_rounded,
        codeSnippet: '''
final scrollOffset = scrollController.toWhatBy(
  (ctrl) => ctrl.hasClients ? ctrl.offset : 0.0,
);

final appBarOpacity = computed((via) {
  final offset = via(scrollOffset);
  return (offset / 150.0).clamp(0.0, 1.0);
}).distinct(); // Halts propagation if opacity remains 1.0

// Surgical 120fps rebuild isolated here
composed((via) {
  final opacity = via(appBarOpacity);
  return Opacity(
    opacity: opacity,
    child: const AppBar(title: Text('Feed')),
  );
})
''',
        highlights: [
          'observe bridges Listenable high-frequency changes into LPDAG.',
          'distinct() prevents redundant layout passes when values saturate.',
          'Only a micro-tree (the Opacity widget) rebuilds at 120fps.',
        ],
        builder: () => const ScrollKinematicsSection(),
      );
}
