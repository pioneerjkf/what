// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hierarchy_tree_card.dart';

/// Dark-themed code viewer card with syntax-styled blocks, architecture roadmap tabs, and copy capability.
class CodeViewerCard extends StatefulWidget {
  const CodeViewerCard({
    super.key,
    required this.title,
    required this.code,
    required this.highlights,
    this.filename = 'example.dart',
    this.roadmapTree,
  });

  final String title;
  final String code;
  final List<String> highlights;
  final String filename;
  final String? roadmapTree;

  @override
  State<CodeViewerCard> createState() => _CodeViewerCardState();
}

class _CodeViewerCardState extends State<CodeViewerCard> {
  int _activeTab = 0;
  bool _isCopied = false;
  Timer? _copiedTimer;

  static final _tokenPattern = RegExp(
    r'(//.*)|' // 1: Line comment
    r"('(?:\\.|[^'\\])*'|"
    r'"(?:\\.|[^"\\])*")|' // 2: Single/Double quoted String
    r'(\b\d+(?:\.\d+)?\b)|' // 3: Numbers
    r'([a-zA-Z_$][a-zA-Z0-9_$]*)|' // 4: Identifiers/Keywords
    r'(\s+)|' // 5: Whitespace
    r'(.)', // 6: Any other punctuation/symbol
  );

  static final _whatPrimitives = {
    // Core Topology & Nodes
    'What',
    'WhatController',
    'RawWhatController',
    'WhatVia',
    'RawViaTerminal',

    // Core Reactive Functors & Lifecycle
    'computed',
    'switched',
    'managed',
    'effect',
    'tether',
    'Graceful',

    // Flutter Reactive Widgets & Components
    'WhatWidget',
    'WhatProvider',
    'WhatAsyncBuilder',
    'WhatPendingIndicator',
    'WhatAsyncSnapshot',

    // Reactive Functor Extensions & Bridges
    'composed',
    'vsync',
    'whatOf',
    'whatProvide',
    'toWhat',
    'toWhatBy',
    'toListenable',

    // Frame Pipeline & Inline Operators
    'drive',
    'animate',
    'build',
    'controller',

    // Animation & Physics Controllers
    'DurabilityPolicy',
    'DurableAnimationController',
    'FrozenAnimationController',
    'CatchUpAnimationController',
    'DurableMotion',
    'DurableSimulation',
    'SpringSimulation',
    'GravitySimulation',
    'FrictionSimulation',
  };

  static final _controlKeywords = {
    'import',
    'final',
    'const',
    'late',
    'base',
    'class',
    'extends',
    'implements',
    'override',
    'void',
    'return',
    'if',
    'else',
    'switch',
    'case',
    'break',
    'default',
    'get',
    'set',
    'required',
    'super',
    'true',
    'false',
    'null',
    'async',
    'await',
    'yield',
  };

  static final _typeKeywords = {
    'int',
    'double',
    'num',
    'String',
    'bool',
    'Widget',
    'BuildContext',
    'Duration',
    'Curve',
    'Curves',
    'Color',
    'Colors',
    'Offset',
    'Size',
    'TextEditingController',
    'AnimationController',
    'ScrollController',
    'ValueNotifier',
  };

  void _copyToClipboard() {
    final activeTab = _activeTab;
    final textToCopy = (activeTab == 1 && widget.roadmapTree != null)
        ? widget.roadmapTree!
        : widget.code;

    Clipboard.setData(ClipboardData(text: textToCopy));
    setState(() => _isCopied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isCopied = false);
      }
    });
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasRoadmap =
        widget.roadmapTree != null && widget.roadmapTree!.trim().isNotEmpty;
    final effectiveTab = hasRoadmap ? _activeTab : 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A20) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D3A) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(50)
                : Colors.black.withAlpha(12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Single Unified Code & Architecture Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E212B) : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF2A2D3A)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                // Left Controls: Window Dots + Filename + Tabs
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Window dots
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            _WindowDot(color: Color(0xFFFF5F56)),
                            SizedBox(width: 6),
                            _WindowDot(color: Color(0xFFFFBD2E)),
                            SizedBox(width: 6),
                            _WindowDot(color: Color(0xFF27C93F)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // File Name Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2B3040)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.filename,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFB0BEC5)
                                  : const Color(0xFF475569),
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Sub-Header Tabs (Code vs Architecture Roadmap)
                        if (hasRoadmap) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 16,
                            color: isDark
                                ? const Color(0xFF33384A)
                                : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 10),
                          _buildTabButton(
                            index: 0,
                            label: 'Code Snippet',
                            isActive: effectiveTab == 0,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            index: 1,
                            label: 'Cascade Roadmap',
                            isActive: effectiveTab == 1,
                            badge: 'Architecture',
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Copy Button
                InkWell(
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isCopied
                          ? (isDark
                              ? const Color(0xFF2E7D32).withAlpha(120)
                              : const Color(0xFFDCFCE7))
                          : (isDark
                              ? const Color(0xFF2A2D3A)
                              : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isCopied
                            ? (isDark
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF86EFAC))
                            : (isDark
                                ? const Color(0xFF3F4458)
                                : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Text(
                      _isCopied ? 'Copied' : 'Copy',
                      style: TextStyle(
                        color: _isCopied
                            ? (isDark
                                ? const Color(0xFF81C784)
                                : const Color(0xFF15803D))
                            : (isDark
                                ? const Color(0xFFCFD8DC)
                                : const Color(0xFF475569)),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body Content depending on active tab
          if (effectiveTab == 1 && hasRoadmap) ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: HierarchyTreeCard(
                title: '${widget.title} — Canonical Hierarchy',
                treeText: widget.roadmapTree!,
                badge: 'Roadmap Tree',
              ),
            ),
          ] else ...[
            // Code Content Block
            Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildSyntaxHighlightedText(widget.code, isDark: isDark),
              ),
            ),
          ],

          // Architectural Highlights Area
          if (widget.highlights.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF13151A) : const Color(0xFFF8FAFC),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF2A2D3A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Architectural Highlights',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFB45309),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.highlights.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 8),
                            child: Container(
                              width: 4.5,
                              height: 4.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? const Color(0xFF64B5F6)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFECEFF1)
                                    : const Color(0xFF334155),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required bool isActive,
    required bool isDark,
    String? badge,
  }) {
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF262B3A) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF3B82F6) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? (isDark ? Colors.white : const Color(0xFF1D4ED8))
                    : (isDark
                        ? const Color(0xFF90A4AE)
                        : const Color(0xFF64748B)),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3B82F6).withAlpha(40)
                      : const Color(0xFF3B82F6).withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1D4ED8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyntaxHighlightedText(String text, {required bool isDark}) {
    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (index) {
        final lineNum = (index + 1).toString().padLeft(2, ' ');
        final lineContent = lines[index];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                lineNum,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF546E7A)
                      : const Color(0xFF94A3B8),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: _highlightLine(lineContent, isDark: isDark),
            ),
          ],
        );
      }),
    );
  }

  TextSpan _highlightLine(String line, {required bool isDark}) {
    final commentColor =
        isDark ? const Color(0xFF78909C) : const Color(0xFF64748B);
    final stringColor =
        isDark ? const Color(0xFFA7FFEB) : const Color(0xFF0D9488);
    final numberColor =
        isDark ? const Color(0xFFEA80FC) : const Color(0xFF7C3AED);
    final whatColor =
        isDark ? const Color(0xFF80D8FF) : const Color(0xFF2563EB);
    final controlColor =
        isDark ? const Color(0xFFFF80AB) : const Color(0xFFBE123C);
    final typeColor =
        isDark ? const Color(0xFFFFD180) : const Color(0xFFD97706);
    final normalColor =
        isDark ? const Color(0xFFECEFF1) : const Color(0xFF1E293B);

    if (line.trim().startsWith('//')) {
      return TextSpan(
        text: line,
        style: TextStyle(
          color: commentColor,
          fontStyle: FontStyle.italic,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      );
    }

    final spans = <TextSpan>[];
    for (final match in _tokenPattern.allMatches(line)) {
      final token = match[0]!;

      if (match[1] != null) {
        // Line comment
        spans.add(TextSpan(
          text: token,
          style: TextStyle(
            color: commentColor,
            fontStyle: FontStyle.italic,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ));
      } else if (match[2] != null) {
        // String literal
        spans.add(TextSpan(
          text: token,
          style: TextStyle(
            color: stringColor,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ));
      } else if (match[3] != null) {
        // Number literal
        spans.add(TextSpan(
          text: token,
          style: TextStyle(
            color: numberColor,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ));
      } else if (match[4] != null) {
        // Identifier / Keyword
        if (_whatPrimitives.contains(token)) {
          spans.add(TextSpan(
            text: token,
            style: TextStyle(
              color: whatColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ));
        } else if (_controlKeywords.contains(token)) {
          spans.add(TextSpan(
            text: token,
            style: TextStyle(
              color: controlColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ));
        } else if (_typeKeywords.contains(token)) {
          spans.add(TextSpan(
            text: token,
            style: TextStyle(
              color: typeColor,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ));
        } else {
          spans.add(TextSpan(
            text: token,
            style: TextStyle(
              color: normalColor,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ));
        }
      } else {
        // Whitespace or punctuation
        spans.add(TextSpan(
          text: token,
          style: TextStyle(
            color: normalColor,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ));
      }
    }

    return TextSpan(children: spans);
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
