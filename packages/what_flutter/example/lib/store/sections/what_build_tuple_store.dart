// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/what_build_tuple_section.dart';

/// Sub-store for Section 03: what.build & Inline Cascades
class WhatBuildTupleStore {
  final _user = WhatController<String>('Alice');
  final _score = WhatController<int>(2500);
  final _rank = WhatController<int>(1);
  final _cascadeMode =
      WhatController<int>(0); // 0: direct, 1: context, 2: child, 3: children

  What<String> get user => _user.what;
  What<int> get score => _score.what;
  What<int> get rank => _rank.what;
  What<int> get cascadeMode => _cascadeMode.what;

  void nextPlayer() {
    final current = _user.data;
    _user.set(
        current == 'Alice' ? 'Bob' : (current == 'Bob' ? 'Charlie' : 'Alice'));
  }

  void addXp() => _score.set(_score.data + 250);

  void improveRank() {
    final current = _rank.data;
    _rank.set(current > 1 ? current - 1 : 5);
  }

  void selectCascadeMode(int mode) => _cascadeMode.set(mode);

  ShowcaseSection get section => ShowcaseSection(
        id: '03_what_build_tuple',
        number: '03',
        title: 'what.build & Direct Value Cascades',
        subtitle: 'Zero-cost direct value binding & multi-node composition',
        badge: 'Functors',
        icon: Icons.data_object_rounded,
        codeSnippet: '''
// 1. Direct value binding (Zero runtime allocation via extension type const):
counterWhat.build((context, count) => Text('Count: \$count'));

// 2. what.build with Child Caching:
scoreWhat.build.child(
  (context, score, child) => Row(children: [child, Text('XP: \$score')]),
  child: const TrophyIcon(),
);

// 3. what.build with Children List:
rankWhat.build.children(
  (context, rank, children) => Row(children: [...children, Text('Rank #\$rank')]),
  children: const [Icon(Icons.military_tech), Icon(Icons.star)],
);

// 4. Multi-Node Dynamic Discovery Composition:
composed(
  (context, via) => LeaderboardCard(
    user: via(userWhat),
    score: via(scoreWhat),
    rank: via(rankWhat),
  ),
);''',
        highlights: const [
          'Zero runtime allocation overhead via Dart extension types (extension type const).',
          'Always injected BuildContext matching canonical Flutter builder signatures.',
          'Direct pathways (.child, .children) for optimal static subtree caching.',
          'Surgical single-node direct value unboxing for maximum performance.',
          'Seamless multi-node dynamic discovery via composed((via) => ...).',
        ],
        roadmapTree: '''
what.build           ((data) => ...)
 ├── .context         ((context, data) => ...)
 │    ├── .child      ((context, data, child) => ..., child: ...)
 │    └── .children   ((context, data, children) => ..., children: ...)
 ├── .child           ((data, child) => ..., child: ...)
 │    └── .context    ((context, data, child) => ..., child: ...)
 └── .children        ((data, children) => ..., children: ...)
      └── .context    ((context, data, children) => ..., children: ...)

composed((via) => ...)    [Multi-Node Dynamic Discovery & 1-Pass Epoch Sweeping]
''',
        builder: () => WhatBuildTupleSectionDemo(),
      );
}
