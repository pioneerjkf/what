// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/section.dart';
import '../../sections/adaptive_proxies_section.dart';

/// Sub-store for Section 10: Adaptive Design & Context Integration
class AdaptiveProxiesStore {
  final _isCupertinoSwitchActive = WhatController<bool>(true);
  What<bool> get isCupertinoSwitchActive => _isCupertinoSwitchActive.what;

  void toggleCupertinoSwitch(bool value) => _isCupertinoSwitchActive.set(value);

  ShowcaseSection get section => ShowcaseSection(
        id: '12_adaptive_proxies',
        number: '12',
        title: 'Adaptive Material & Cupertino Integration',
        subtitle:
            'Standard Flutter theme integration with What reactive pipelines',
        badge: 'Design System',
        icon: Icons.palette_rounded,
        codeSnippet: '''
base class AdaptiveThemedView extends WhatWidget {
  const AdaptiveThemedView({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    // Flutter Standard Theme & ColorScheme access:
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Flutter Standard Cupertino Theme access:
    final cupertinoTheme = CupertinoTheme.of(context);

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const Text('Material & Cupertino Theme Integration'),
    );
  }
}''',
        highlights: const [
          'Direct BuildContext access without intermediate reactive wrappers.',
          'Native Flutter 3.x Aspect-based MediaQuery & Theme integration.',
          'const WhatWidget: Compile-time constant widget trees with zero allocation.',
        ],
        roadmapTree: '''
Theme.of(context) / CupertinoTheme.of(context)
 ├── .colorScheme / .textTheme
 └── Flutter Standard Declarative Theming
''',
        builder: () => const AdaptiveProxiesSectionDemo(),
      );
}
