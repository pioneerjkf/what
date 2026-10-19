// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import 'lint_harness.dart';

void main() {
  final files = discoverCaseFiles();

  group('corpus integrity', () {
    test('case corpus is not empty', () {
      expect(files, isNotEmpty,
          reason: 'No case files in ${lintCasesDir.path}');
    });

    test('every expect_lint lives inside a #case region', () {
      final stray = [
        for (final f in files)
          for (final line in f.strayExpectations) '${f.relativePath}:L$line',
      ];
      expect(stray, isEmpty);
    });

    test('every expect_lint names a registered rule', () {
      final unknown = [
        for (final f in files)
          for (final c in f.cases)
            for (final hit in c.expected)
              if (!registeredRuleNames.contains(hit.rule))
                '${f.relativePath}:L${hit.line - 1} ${hit.rule}',
      ];
      expect(unknown, isEmpty);
    });

    test('every registered rule has at least one positive (bad) case', () {
      final covered = {
        for (final f in files)
          for (final c in f.cases)
            for (final hit in c.expected) hit.rule,
      };
      expect(registeredRuleNames.difference(covered), isEmpty);
    });

    test('pub.dev tour shows a bad and a good case for every rule', () {
      final tourIds = {
        for (final f in files.where((f) => f.isShowcase))
          for (final c in f.cases) c.id,
      };
      final missing = [
        for (final rule in registeredRuleNames.toList()..sort())
          for (final kind in const ['bad', 'good'])
            if (!tourIds.contains('tour/$rule/$kind')) 'tour/$rule/$kind',
      ];
      expect(missing, isEmpty);
    });

    test('case ids are unique', () {
      final seen = <String>{};
      final dupes = [
        for (final f in files)
          for (final c in f.cases)
            if (!seen.add(c.id)) '${f.relativePath}:L${c.startLine} ${c.id}',
      ];
      expect(dupes, isEmpty);
    });
  });

  for (final file in files) {
    group(file.relativePath, () {
      test('compiles without analyzer errors', () async {
        final report = await analyzeCaseFile(file);
        expect(report.compileErrors, isEmpty);
      });

      test('emits no diagnostics outside #case regions', () async {
        final report = await analyzeCaseFile(file);
        final orphans = [
          for (final hit in report.hits)
            if (!file.cases.any((c) => c.contains(hit.line)))
              'L${hit.line} ${hit.rule}: ${file.sourceAt(hit.line)}',
        ];
        expect(orphans, isEmpty);
      });

      for (final lintCase in file.cases) {
        test(
          lintCase.id,
          () async {
            final diff = diffCase(lintCase, await analyzeCaseFile(file));
            if (diff != null) fail(diff);
          },
        );
      }
    });
  }
}
