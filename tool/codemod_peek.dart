// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:io';

const Set<String> _stateMembers = {
  'snapshot',
  'dataOrNull',
  'dataOrElse',
  'hasData',
  'isEmpty',
  'emptyReason',
  'hasError',
  'error',
  'stackTrace',
  'equals',
  'match',
  'matchOrNull',
  'matchOrElse',
};

final RegExp _messagePattern = RegExp(
  r"The (?:getter|method) '(\w+)' isn't defined for the type '([^']+)'",
);

bool _isTargetType(String typeName) {
  return typeName == 'What' ||
      typeName.startsWith('What<') ||
      typeName == 'WhatSignal' ||
      typeName.startsWith('WhatSignal<');
}

final class _Edit {
  _Edit({
    required this.file,
    required this.line,
    required this.col,
    required this.length,
    required this.memberName,
  });

  final String file;
  final int line;
  final int col;
  final int length;
  final String memberName;
}

List<int> _computeLineOffsets(String content) {
  final offsets = <int>[0];
  for (var i = 0; i < content.length; i++) {
    if (content.codeUnitAt(i) == 10) {
      // '\n'
      offsets.add(i + 1);
    }
  }
  return offsets;
}

void main(List<String> args) {
  var dryRun = false;
  String? targetPath;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--path' && i + 1 < args.length) {
      targetPath = args[++i];
    } else if (arg.startsWith('--path=')) {
      targetPath = arg.substring('--path='.length);
    } else if (!arg.startsWith('-') && targetPath == null) {
      targetPath = arg;
    }
  }

  targetPath ??= 'packages/what';

  print('========================================================');
  print('Codemod: Migrating What raw reads to peek & peekState');
  print('Target:  $targetPath');
  print(
      'Mode:    ${dryRun ? "DRY-RUN (no changes written)" : "EXECUTE (writing changes)"}');
  print('========================================================\n');

  var iteration = 0;
  var totalDataReplaced = 0;
  var totalStateReplaced = 0;
  final modifiedFiles = <String>{};

  final sw = Stopwatch()..start();

  while (true) {
    iteration++;
    print(
        'Iteration $iteration: Running dart analyze --format=machine $targetPath...');

    final result = Process.runSync(
      'dart',
      ['analyze', '--format=machine', targetPath],
      runInShell: true,
    );

    final lines = (result.stdout as String).split('\n');
    final editsByFile = <String, List<_Edit>>{};

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final parts = line.split('|');
      if (parts.length < 8) continue;

      final code = parts[2];
      if (code != 'UNDEFINED_GETTER' && code != 'UNDEFINED_METHOD') continue;

      final filePath = parts[3];
      final lineNum = int.tryParse(parts[4]);
      final colNum = int.tryParse(parts[5]);
      final length = int.tryParse(parts[6]);
      final message = parts[7];

      if (lineNum == null || colNum == null || length == null) continue;

      final match = _messagePattern.firstMatch(message);
      if (match == null) continue;

      final memberName = match.group(1)!;
      final typeName = match.group(2)!;

      if (!_isTargetType(typeName)) continue;
      if (memberName != 'data' && !_stateMembers.contains(memberName)) continue;

      editsByFile.putIfAbsent(filePath, () => []).add(_Edit(
            file: filePath,
            line: lineNum,
            col: colNum,
            length: length,
            memberName: memberName,
          ));
    }

    if (editsByFile.isEmpty) {
      print('Iteration $iteration: No applicable diagnostics found.');
      break;
    }

    var iterationReplaced = 0;

    for (final entry in editsByFile.entries) {
      final filePath = entry.key;
      final edits = entry.value;

      final file = File(filePath);
      if (!file.existsSync()) continue;

      final content = file.readAsStringSync();
      final lineOffsets = _computeLineOffsets(content);

      // Sort edits descending by position so earlier offsets remain valid
      edits.sort((a, b) {
        if (a.line != b.line) return b.line.compareTo(a.line);
        return b.col.compareTo(a.col);
      });

      var updated = content;
      var fileDataCount = 0;
      var fileStateCount = 0;

      for (final edit in edits) {
        if (edit.line - 1 >= lineOffsets.length) continue;
        final startOffset = lineOffsets[edit.line - 1] + (edit.col - 1);
        final endOffset = startOffset + edit.length;

        if (startOffset < 0 || endOffset > updated.length) continue;

        final actual = updated.substring(startOffset, endOffset);
        if (actual != edit.memberName) {
          stderr.writeln(
            'Warning: Expected "${edit.memberName}" at ${edit.file}:${edit.line}:${edit.col}, '
            'found "$actual". Skipping.',
          );
          continue;
        }

        final replacement =
            edit.memberName == 'data' ? 'peek' : 'peekState.${edit.memberName}';

        updated = updated.replaceRange(startOffset, endOffset, replacement);
        iterationReplaced++;

        if (edit.memberName == 'data') {
          fileDataCount++;
          totalDataReplaced++;
        } else {
          fileStateCount++;
          totalStateReplaced++;
        }
      }

      if (updated != content) {
        modifiedFiles.add(filePath);
        print('  $filePath:');
        if (fileDataCount > 0) print('    - .data -> .peek: $fileDataCount');
        if (fileStateCount > 0)
          print('    - .<state> -> .peekState.<state>: $fileStateCount');

        if (!dryRun) {
          file.writeAsStringSync(updated);
        }
      }
    }

    if (iterationReplaced == 0) {
      print('Iteration $iteration: No replacements applied.');
      break;
    }

    if (dryRun) {
      print('Dry-run completed after iteration $iteration.');
      break;
    }
  }

  sw.stop();

  print('\n--------------------------------------------------------');
  print('Summary:');
  print('  Elapsed time:        ${sw.elapsedMilliseconds} ms');
  print('  Iterations:          $iteration');
  print('  Files modified:      ${modifiedFiles.length}');
  print('  .data -> .peek:      $totalDataReplaced');
  print('  .<state> -> .peekState.<state>: $totalStateReplaced');
  print('  Total replacements:  ${totalDataReplaced + totalStateReplaced}');
  print('--------------------------------------------------------');
}
