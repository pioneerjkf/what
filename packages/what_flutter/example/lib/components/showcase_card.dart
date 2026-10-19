// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Reusable card container wrapping interactive live demos in the showcase app.
class ShowcaseCard extends StatelessWidget {
  const ShowcaseCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.badge,
    this.actions,
  });

  final String title;
  final String description;
  final Widget child;
  final String? badge;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A2D3A) : const Color(0xFFE2E8F0),
        ),
      ),
      color: isDark ? const Color(0xFF1E212B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Badge row
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    isDark ? const Color(0xFF90A4AE) : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            // Interactive Child Content
            child,
          ],
        ),
      ),
    );
  }
}

/// Standardized interactive sandbox frame for live visual state rendering.
class SandboxContainer extends StatelessWidget {
  const SandboxContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.minHeight,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? minHeight;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 140),
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF262936) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(child: child),
    );
  }
}
