// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Living Documentation Auditor Integrity Suite', () {
    late File docAuditFile;

    setUpAll(() {
      var curr = Directory.current;
      while (true) {
        if (File('${curr.path}/pubspec.yaml').existsSync() && Directory('${curr.path}/packages').existsSync()) {
          break;
        }
        final parent = curr.parent;
        if (parent.path == curr.path) break;
        curr = parent;
      }
      docAuditFile = File('${curr.path}/tool/doc_audit.dart');
    });

    test('[INV-DOC-ZERO-MOCK] tool/doc_audit.dart contains zero synthetic mocks or proxy shims', () {
      expect(docAuditFile.existsSync(), isTrue, reason: 'tool/doc_audit.dart must exist at repository root');
      final content = docAuditFile.readAsStringSync();

      // Prohibit synthetic proxy declarations (DEF-08 / DEF-DOC-06)
      final mockClassRegex = RegExp(r'class\s+(_ContextWhatProxy|_ContextMediaQueryProxy|_ContextScopeProxy)\b');
      final mockVarRegex = RegExp(r'final\s+contextWhat\s*=');

      expect(mockClassRegex.hasMatch(content), isFalse,
          reason: 'tool/doc_audit.dart must NOT contain synthetic proxy class declarations');
      expect(mockVarRegex.hasMatch(content), isFalse,
          reason: 'tool/doc_audit.dart must NOT define a synthetic contextWhat variable');
    });

    test('[INV-DOC-DENYLIST] tool/doc_audit.dart enforces pruned symbols denylist', () {
      final content = docAuditFile.readAsStringSync();
      expect(content, contains('prunedDenylist'));
      expect(content, contains('contextWhat'));
      expect(content, contains('ContextWhatAware'));
      expect(content, contains('WhatBuildContextMediaQueryProxy'));
      expect(content, contains('WritableWhat'));
    });
  });
}
