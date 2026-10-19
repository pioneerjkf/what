// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// Resolved-AST lint harness.
///
/// Runs every registered `what_lints` rule through its real `run()` pipeline
/// (`DartLintRule.testRun`) against fully resolved files in two corpora, and
/// diffs the produced diagnostics against `expect_lint:` annotations:
///
/// * [showcaseDir] (`example/lib/`): the curated pub.dev guided tour.
/// * [lintCasesDir] (`example/lint_cases/`): exhaustive edge and regression cases.
///
/// ## Case file grammar
/// ```dart
/// // #case <rule_or_topic>/<bad|good>/<slug>
/// final x = computed((via) {
///   // An `expect_lint: avoid_untracked_what_read` comment would go here
///   return counter.data;            // <- diagnostic must start on this line
/// });
/// ```
/// * `// #case <id>` opens a case region that lasts until the next marker.
/// * An `expect_lint: a, b` comment expects rules `a` and `b` on the **next line**
///   (identical semantics to `custom_lint`'s own `expect_lint`).
/// * Any diagnostic without a matching expectation is a false positive, and any
///   expectation without a matching diagnostic is a false negative.
/// * All rules run on every file, so cross-rule noise is caught as well.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:what_lints/what_lints.dart';

/// Root of the `what_lints` example package.
final Directory exampleDir = () {
  final direct = Directory(p.normalize(p.absolute('example')));
  if (direct.existsSync()) return direct;
  final nested =
      Directory(p.normalize(p.absolute('packages/what_lints/example')));
  if (nested.existsSync()) return nested;
  return direct;
}();

/// The curated, pub.dev-facing guided tour (one BAD/GOOD pair per rule).
final Directory showcaseDir = Directory(p.join(exampleDir.path, 'lib'));

/// The exhaustive edge-case and regression corpus.
final Directory lintCasesDir = Directory(p.join(exampleDir.path, 'lint_cases'));

/// Every verified corpus root.
final List<Directory> corpusRoots = [showcaseDir, lintCasesDir];

/// Every rule exactly as registered by the plugin entrypoint.
///
/// `CustomLintConfigs.parse(null, ...)` is the public way to obtain an empty
/// configuration (the `empty` constant itself is `@internal`).
final List<DartLintRule> registeredRules = createPlugin()
    .getLintRules(CustomLintConfigs.parse(null, PackageConfig.empty))
    .cast<DartLintRule>();

/// Names of every registered rule.
final Set<String> registeredRuleNames = {
  for (final rule in registeredRules) rule.code.name,
};

final _caseMarker = RegExp(r'^\s*//\s*#case\s+(\S+)');
final _expectMarker = RegExp(r'^\s*//\s*expect_lint\s*:\s*(.+)$');

/// A single `(rule, line)` diagnostic identity. Lines are 1-based.
typedef LintHit = ({String rule, int line});

/// A `// #case` region inside a case file.
final class LintCase {
  LintCase(this.file, this.id, this.startLine);

  final LintCaseFile file;
  final String id;

  /// 1-based line of the `// #case` marker.
  final int startLine;

  /// 1-based exclusive end line (start of the next case or EOF + 1).
  late final int endLine;

  /// Expected hits declared by `expect_lint:` within this region.
  final Set<LintHit> expected = {};

  bool contains(int line) => line >= startLine && line < endLine;
}

/// A parsed case file. Parsing is synchronous so that one `test()` per case
/// can be declared before any asynchronous analysis happens.
final class LintCaseFile {
  LintCaseFile._(this.path, this.lines);

  factory LintCaseFile.parse(String path) {
    final file = LintCaseFile._(path, File(path).readAsLinesSync());
    LintCase? current;
    for (var i = 0; i < file.lines.length; i++) {
      final line = i + 1;
      final text = file.lines[i];

      final caseMatch = _caseMarker.firstMatch(text);
      if (caseMatch != null) {
        current?.endLine = line;
        current = LintCase(file, caseMatch.group(1)!, line);
        file.cases.add(current);
        continue;
      }

      final expectMatch = _expectMarker.firstMatch(text);
      if (expectMatch != null) {
        final region = current;
        if (region == null) {
          file.strayExpectations.add(line);
          continue;
        }
        for (final rule in expectMatch.group(1)!.split(',')) {
          final name = rule.trim();
          if (name.isNotEmpty)
            region.expected.add((rule: name, line: line + 1));
        }
      }
    }
    current?.endLine = file.lines.length + 1;
    return file;
  }

  final String path;
  final List<String> lines;
  final List<LintCase> cases = [];

  /// `expect_lint` markers placed outside any `#case` region (authoring error).
  final List<int> strayExpectations = [];

  String get relativePath => p.relative(path, from: exampleDir.path);

  /// Whether this file belongs to the pub.dev-facing guided tour.
  bool get isShowcase => p.isWithin(showcaseDir.path, path);

  /// Returns the trimmed source at 1-based [line], for readable diffs.
  String sourceAt(int line) =>
      line >= 1 && line <= lines.length ? lines[line - 1].trim() : '<eof>';
}

/// Analysis outcome of a single case file.
final class LintFileReport {
  LintFileReport(this.compileErrors, this.hits);

  /// Analyzer compile-time errors. A case file must compile, otherwise the
  /// resolved AST is partial and the case is meaningless.
  final List<String> compileErrors;

  /// Every diagnostic produced by every registered rule.
  final Set<LintHit> hits;
}

/// Discovers every `.dart` file under [corpusRoots], sorted for stable ordering.
List<LintCaseFile> discoverCaseFiles() {
  final files = [
    for (final root in corpusRoots)
      for (final f in root.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart')) p.normalize(f.absolute.path),
  ]..sort();
  return [for (final path in files) LintCaseFile.parse(path)];
}

AnalysisContextCollection? _collection;
final Map<String, Future<LintFileReport>> _reports = {};

/// Resolves [file] once (memoized) and runs every registered rule against it.
Future<LintFileReport> analyzeCaseFile(LintCaseFile file) =>
    _reports[file.path] ??= _analyze(file.path);

Future<LintFileReport> _analyze(String path) async {
  final collection = _collection ??= AnalysisContextCollection(
    includedPaths: [for (final root in corpusRoots) root.path],
  );
  final result =
      await collection.contextFor(path).currentSession.getResolvedUnit(path);
  if (result is! ResolvedUnitResult) {
    return LintFileReport(['Failed to resolve: ${result.runtimeType}'], {});
  }

  final compileErrors = [
    for (final d in result.diagnostics)
      if (d.severity == DiagnosticSeverity.ERROR)
        'L${result.lineInfo.getLocation(d.offset).lineNumber}: '
            '${d.diagnosticCode.name} - ${d.message}',
  ];

  final hits = <LintHit>{};
  for (final rule in registeredRules) {
    for (final d in await rule.testRun(result)) {
      hits.add((
        rule: d.diagnosticCode.name,
        line: result.lineInfo.getLocation(d.offset).lineNumber,
      ));
    }
  }
  return LintFileReport(compileErrors, hits);
}

/// Returns a human-readable mismatch report for [lintCase], or `null` if the
/// produced diagnostics exactly match the declared expectations.
String? diffCase(LintCase lintCase, LintFileReport report) {
  final actual = {
    for (final hit in report.hits)
      if (lintCase.contains(hit.line)) hit,
  };
  final falsePositives = actual.difference(lintCase.expected);
  final falseNegatives = lintCase.expected.difference(actual);
  if (falsePositives.isEmpty && falseNegatives.isEmpty) return null;

  final file = lintCase.file;
  String fmt(LintHit h) =>
      '    L${h.line}  ${h.rule}\n        ${file.sourceAt(h.line)}';
  int byLine(LintHit a, LintHit b) => a.line.compareTo(b.line);

  return [
    '[${file.relativePath}] #case ${lintCase.id}',
    if (falsePositives.isNotEmpty) ...[
      '  False positives (unexpected diagnostics):',
      ...(falsePositives.toList()..sort(byLine)).map(fmt),
    ],
    if (falseNegatives.isNotEmpty) ...[
      '  False negatives (missing diagnostics):',
      ...(falseNegatives.toList()..sort(byLine)).map(fmt),
    ],
  ].join('\n');
}
