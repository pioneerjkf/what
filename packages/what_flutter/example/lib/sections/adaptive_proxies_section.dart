// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 10: Adaptive Design & Context Integration
base class AdaptiveProxiesSectionDemo extends WhatWidget {
  const AdaptiveProxiesSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.adaptiveProxies;

    // Flutter Standard Theme & ColorScheme access:
    final materialTheme = Theme.of(context);
    final colorScheme = materialTheme.colorScheme;

    // Flutter Standard Cupertino Theme access:
    final cupertinoTheme = CupertinoTheme.of(context);

    return Column(
      children: [
        ShowcaseCard(
          title: 'Material 3 & Theme Integration',
          badge: 'Material Integration',
          description:
              'Provides seamless, reactive integration with Flutter\'s Material 3 theme and ColorScheme without unnecessary abstraction layers.',
          child: SandboxContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Active Material Seed: Indigo',
                  style: materialTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _ColorBox(
                      name: 'Primary',
                      color: colorScheme.primary,
                      onColor: colorScheme.onPrimary,
                    ),
                    _ColorBox(
                      name: 'Secondary',
                      color: colorScheme.secondary,
                      onColor: colorScheme.onSecondary,
                    ),
                    _ColorBox(
                      name: 'Tertiary',
                      color: colorScheme.tertiary,
                      onColor: colorScheme.onTertiary,
                    ),
                    _ColorBox(
                      name: 'Surface',
                      color: colorScheme.surfaceContainerHighest,
                      onColor: colorScheme.onSurface,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShowcaseCard(
          title: 'Cupertino Design System Integration',
          badge: 'iOS Integration',
          description:
              'Seamlessly renders Apple HIG styled components with type-safe access to CupertinoThemeData.',
          child: SandboxContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cupertino Primary: ${cupertinoTheme.primaryColor}',
                  style: TextStyle(
                    color: cupertinoTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Surgical micro-rebuild: Only the switch and toggle button rebuild
                composed((context, via) {
                  final isCupertinoActive = via(store.isCupertinoSwitchActive);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Cupertino Switch: '),
                          const SizedBox(width: 8),
                          CupertinoSwitch(
                            value: isCupertinoActive,
                            onChanged: store.toggleCupertinoSwitch,
                            activeTrackColor: cupertinoTheme.primaryColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        onPressed: () {
                          store.toggleCupertinoSwitch(!isCupertinoActive);
                        },
                        child: Text(isCupertinoActive
                            ? 'Disable Switch'
                            : 'Enable Switch'),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

base class _ColorBox extends StatelessWidget {
  const _ColorBox({
    required this.name,
    required this.color,
    required this.onColor,
  });

  final String name;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: onColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
