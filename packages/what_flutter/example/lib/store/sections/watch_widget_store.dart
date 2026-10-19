// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/framework.dart';
import '../../models/section.dart';
import '../../sections/watch_widget_section.dart';

/// Sub-store for Section 01: WhatWidget & Dynamic Discovery
class WhatWidgetStore {
  final _counter = WhatController<int>(0);
  final _userStatus = WhatController<String>('Online');
  final _showDetails = WhatController<bool>(false);

  What<int> get counter => _counter.what;
  What<String> get userStatus => _userStatus.what;
  What<bool> get showDetails => _showDetails.what;

  void increment() => _counter.set(_counter.data + 1);
  void reset() => _counter.set(0);
  void toggleDetails(bool value) => _showDetails.set(value);
  void cycleUserStatus() {
    final current = _userStatus.data;
    _userStatus.set(
      current == 'Online' ? 'Away' : (current == 'Away' ? 'Busy' : 'Online'),
    );
  }

  ShowcaseSection get section => ShowcaseSection(
        id: '01_watch_widget',
        number: '01',
        title: 'WhatWidget & Dynamic Discovery',
        subtitle: 'Explicit WhatVia manifest & 1-pass epoch sweeping',
        badge: 'Widgets',
        icon: Icons.visibility_rounded,
        codeSnippet: '''
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

final counterController = WhatController<int>(0);

base class UserCounterCard extends WhatWidget {
  UserCounterCard({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    // Explicit WhatVia dependency manifest (Zero tracking stack overhead)
    final count = via(counterController.what);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Current Count: \$count'),
      ),
    );
  }
}''',
        highlights: const [
          'Explicit WhatVia Manifest: Dynamically tracks only nodes accessed in executed branches.',
          '1-Pass Zero-Allocation Epoch Sweeping: Automatically detaches inactive graph edges.',
          'Extends ComponentElement directly, eliminating standard StatefulWidget boilerplate.',
        ],
        roadmapTree: '''
WhatWidget (ComponentElement integration)
 ├── WhatVia (via(what))    -> Explicit dependency manifest & dynamic discovery
 └── 1-Pass Epoch Sweeping       -> Automatically prunes unexecuted conditional branches
''',
        builder: () => WhatWidgetSectionDemo(),
      );
}
