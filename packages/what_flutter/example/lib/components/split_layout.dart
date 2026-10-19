// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../models/section.dart';
import '../store/showcase_store.dart';
import 'code_viewer.dart';

/// Responsive layout supporting side-by-side split screen on desktop/tablet
/// and segmented tab switching on mobile devices.
base class ResponsiveSplitLayout extends WhatWidget {
  const ResponsiveSplitLayout({
    super.key,
    this.section,
  });

  /// Explicit section override, or null to reactively discover active section from [ShowcaseStore].
  final ShowcaseSection? section;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final storeWhat = context.whatOf<ShowcaseStore>();
    final store = via(storeWhat);
    final activeSection = section ?? store.sections.all[via(store.activeIndex)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 950;

        if (isWide) {
          // Desktop / Tablet Landscape: Two-column split layout with independent scrolling
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Interactive Live Sandbox (Independent Scroll)
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 12, 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(context, activeSection),
                      const SizedBox(height: 16),
                      activeSection.builder(),
                    ],
                  ),
                ),
              ),
              // Right Column: Core Code & Highlights (Independent Scroll)
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 24, 24, 64),
                  child: CodeViewerCard(
                    title: activeSection.title,
                    code: activeSection.codeSnippet,
                    highlights: activeSection.highlights,
                    filename: '${activeSection.id}.dart',
                    roadmapTree: activeSection.roadmapTree,
                  ),
                ),
              ),
            ],
          );
        } else {
          // Mobile / Portrait View: Tab switcher between Live Demo and Core Code
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader(context, activeSection),
                  const SizedBox(height: 16),
                  _MobileSectionView(
                    key: ValueKey(activeSection.id),
                    section: activeSection,
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, ShowcaseSection section) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SECTION ${section.number}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section.badge,
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  section.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  section.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

base class _MobileSectionView extends WhatWidget {
  const _MobileSectionView({super.key, required this.section});
  final ShowcaseSection section;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final storeWhat = context.whatOf<ShowcaseStore>();
    final store = via(storeWhat);
    final activeMobileTab = via(store.mobileTabIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Live Demo'),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Core Code'),
            ),
          ],
          selected: {activeMobileTab},
          onSelectionChanged: (selection) {
            store.setMobileTab(selection.first);
          },
        ),
        const SizedBox(height: 16),
        if (activeMobileTab == 0)
          section.builder()
        else
          CodeViewerCard(
            title: section.title,
            code: section.codeSnippet,
            highlights: section.highlights,
            filename: '${section.id}.dart',
            roadmapTree: section.roadmapTree,
          ),
      ],
    );
  }
}
