// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import 'components/split_layout.dart';
import 'store/showcase_store.dart';

void main() {
  runApp(WhatShowcaseApp());
}

/// Root Application providing ShowcaseStore down the tree via WhatProvider.
base class WhatShowcaseApp extends WhatWidget {
  WhatShowcaseApp({
    super.key,
    ShowcaseStore? store,
  }) : store = store ?? ShowcaseStore();

  final ShowcaseStore store;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final themeMode = via(store.themeMode);

    // Provide the root ShowcaseStore down the tree (Zero Prop-Drilling)
    return What.constant(store).provide(
      child: MaterialApp(
        title: 'What Flutter Showcase',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFF0F1117),
        ),
        home: ShowcaseShell(),
      ),
    );
  }
}

/// Main Showcase UI Shell discovering ShowcaseStore via `context.whatOf<ShowcaseStore>()`
base class ShowcaseShell extends WhatWidget {
  const ShowcaseShell({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final storeWhat = context.whatOf<ShowcaseStore>();
    final store = via(storeWhat);
    final activeIndexWhat = store.activeIndex;
    final themeModeWhat = store.themeMode;
    final sections = store.sections.all;

    return Scaffold(
      appBar: AppBar(
        leading: composed((context, via) {
          final isSidebarOpen = via(store.isSidebarOpen);
          return IconButton(
            tooltip: isSidebarOpen ? 'Hide Menu' : 'Show Menu',
            onPressed: () => store.toggleSidebar(),
            icon: const Icon(Icons.menu_rounded),
          );
        }),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.indigo, Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.hub_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'What Flutter Showcase',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withAlpha(80),
                ),
              ),
              child: Text(
                'v0.1.0',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Section Navigation Buttons & Indicator (Surgical micro-rebuild)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              composed((context, via) {
                final activeIndex = via(activeIndexWhat);
                return IconButton(
                  tooltip: 'Previous Section',
                  onPressed: activeIndex > 0 ? () => store.prevSection() : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                );
              }),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: composed((context, via) => Text(
                      '${via(activeIndexWhat) + 1} / ${sections.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    )),
              ),
              composed((context, via) {
                final activeIndex = via(activeIndexWhat);
                return IconButton(
                  tooltip: 'Next Section',
                  onPressed: activeIndex < sections.length - 1
                      ? () => store.nextSection(sections.length)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                );
              }),
            ],
          ),
          const SizedBox(width: 8),
          // Theme Toggle (Surgical micro-rebuild)
          composed((context, via) {
            final themeMode = via(themeModeWhat);
            final (icon, tooltip) = switch (themeMode) {
              ThemeMode.system => (
                  Icons.brightness_auto_rounded,
                  'Theme: System (Follows OS)',
                ),
              ThemeMode.light => (
                  Icons.light_mode_rounded,
                  'Theme: Light Mode',
                ),
              ThemeMode.dark => (
                  Icons.dark_mode_rounded,
                  'Theme: Dark Mode',
                ),
            };
            return IconButton(
              tooltip: tooltip,
              onPressed: () => store.toggleTheme(),
              icon: Icon(icon),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated Collapsible Sidebar Menu (Surgical micro-rebuild)
          composed((context, via) {
            final isSidebarOpen = via(store.isSidebarOpen);
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              width: isSidebarOpen ? 300 : 0,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF13151A) : const Color(0xFFF8FAFC),
                border: Border(
                  right: BorderSide(
                    color: isDark
                        ? const Color(0xFF262936)
                            .withAlpha(isSidebarOpen ? 255 : 0)
                        : const Color(0xFFE2E8F0)
                            .withAlpha(isSidebarOpen ? 255 : 0),
                  ),
                ),
              ),
              child: ClipRect(
                child: OverflowBox(
                  minWidth: 300,
                  maxWidth: 300,
                  alignment: Alignment.topLeft,
                  child: _buildSectionList(context, store),
                ),
              ),
            );
          }),
          // Main Showcase Content Area (Zero prop-drilling)
          Expanded(
            child: const ResponsiveSplitLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList(BuildContext context, ShowcaseStore store) {
    final sections = store.sections.all;

    return composed((context, via) {
      final activeIndex = via(store.activeIndex);
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          final isSelected = index == activeIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                store.selectSection(index, sections.length);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                          .withAlpha(isDark ? 90 : 140)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withAlpha(120)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    if (isSelected)
                      Container(
                        width: 3.5,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${section.number}. ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  section.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            section.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? theme.colorScheme.primary.withAlpha(200)
                                  : theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
