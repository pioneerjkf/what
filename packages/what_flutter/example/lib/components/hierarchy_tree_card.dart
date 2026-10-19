// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Card component that renders canonical ASCII architecture hierarchy trees with syntax highlighting.
class HierarchyTreeCard extends StatefulWidget {
  const HierarchyTreeCard({
    super.key,
    required this.title,
    required this.treeText,
    this.badge = 'Cascade Hierarchy',
    this.activeBranch,
  });

  final String title;
  final String treeText;
  final String badge;
  final String? activeBranch;

  @override
  State<HierarchyTreeCard> createState() => _HierarchyTreeCardState();
}

class _HierarchyTreeCardState extends State<HierarchyTreeCard> {
  bool _isCopied = false;
  Timer? _copiedTimer;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.treeText));
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14161D) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF262A38) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(40)
                : Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1E28) : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF262A38)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFECEFF1)
                          : const Color(0xFF1E293B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.badge.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0D47A1).withAlpha(80)
                          : const Color(0xFF3B82F6).withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E88E5).withAlpha(120)
                            : const Color(0xFF3B82F6).withAlpha(80),
                      ),
                    ),
                    child: Text(
                      widget.badge,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF90CAF9)
                            : const Color(0xFF1D4ED8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      _isCopied ? 'Copied' : 'Copy',
                      style: TextStyle(
                        color: _isCopied
                            ? (isDark
                                ? const Color(0xFF81C784)
                                : const Color(0xFF15803D))
                            : (isDark
                                ? const Color(0xFF90A4AE)
                                : const Color(0xFF64748B)),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tree Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child:
                  _buildSyntaxHighlightedTree(widget.treeText, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyntaxHighlightedTree(String text, {required bool isDark}) {
    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (index) {
        final line = lines[index];
        final isActive =
            widget.activeBranch != null && line.contains(widget.activeBranch!);

        return Container(
          decoration: isActive
              ? BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E88E5).withAlpha(35)
                      : const Color(0xFF3B82F6).withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          child: RichText(
            text: _highlightTreeLine(line, isActive: isActive, isDark: isDark),
          ),
        );
      }),
    );
  }

  TextSpan _highlightTreeLine(String line,
      {bool isActive = false, required bool isDark}) {
    // Tree formatting characters: ├──, └──, │, ──
    // Annotations: ((watch) => ...), (controller), -> What<T>
    final spans = <TextSpan>[];

    final arrowIdx = line.indexOf('->');
    final parenIdx = line.indexOf('(');

    var codePart = line;
    var signaturePart = '';

    if (arrowIdx != -1) {
      codePart = line.substring(0, arrowIdx);
      signaturePart = line.substring(arrowIdx);
    } else if (parenIdx != -1) {
      codePart = line.substring(0, parenIdx);
      signaturePart = line.substring(parenIdx);
    }

    // Code and Tree Branches
    spans.add(TextSpan(
      text: codePart,
      style: TextStyle(
        color: isActive
            ? (isDark ? const Color(0xFF80D8FF) : const Color(0xFF2563EB))
            : (isDark ? const Color(0xFFECEFF1) : const Color(0xFF1E293B)),
        fontFamily: 'monospace',
        fontSize: 12,
        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
      ),
    ));

    if (signaturePart.isNotEmpty) {
      spans.add(TextSpan(
        text: signaturePart,
        style: TextStyle(
          color: isActive
              ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309))
              : (isDark ? const Color(0xFF78909C) : const Color(0xFF64748B)),
          fontFamily: 'monospace',
          fontSize: 11.5,
          fontStyle: FontStyle.italic,
        ),
      ));
    }

    return TextSpan(children: spans);
  }
}
