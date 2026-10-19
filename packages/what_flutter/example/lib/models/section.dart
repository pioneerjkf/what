// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Metadata model for each showcase section corresponding to README chapters.
class ShowcaseSection {
  const ShowcaseSection({
    required this.id,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.codeSnippet,
    required this.highlights,
    required this.builder,
    this.roadmapTree,
  });

  final String id;
  final String number;
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final String codeSnippet;
  final List<String> highlights;
  final Widget Function() builder;
  final String? roadmapTree;
}
