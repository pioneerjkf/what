// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'dart:io';

final Set<String> _stateMembers = {
  'hasData',
  'isEmpty',
  'hasError',
  'snapshot',
  'dataOrNull',
  'dataOrElse',
  'match',
  'matchOrElse',
  'error',
  'stackTrace',
  'emptyReason',
};

String transform(
    String content, void Function(int dataCount, int stateCount) onCounts) {
  final sb = StringBuffer();
  var i = 0;
  var dataCount = 0;
  var stateCount = 0;

  while (i < content.length) {
    final matchIndex = content.indexOf('via(', i);
    if (matchIndex == -1) {
      sb.write(content.substring(i));
      break;
    }

    // Check boundary before 'via'
    if (matchIndex > 0) {
      final prevChar = content.codeUnitAt(matchIndex - 1);
      final isId = (prevChar >= 48 && prevChar <= 57) ||
          (prevChar >= 65 && prevChar <= 90) ||
          (prevChar >= 97 && prevChar <= 122) ||
          prevChar == 95 ||
          prevChar == 36; // 0-9, A-Z, a-z, _, $
      // Also if preceded by '.' (e.g. Effect.via(...)), it is not WhatVia.call
      if (isId || prevChar == 46) {
        sb.write(content.substring(i, matchIndex + 3));
        i = matchIndex + 3;
        continue;
      }
    }

    // Match closing parenthesis of via(...)
    var depth = 1;
    var j = matchIndex + 4;
    var inSingleQuote = false;
    var inDoubleQuote = false;

    while (j < content.length && depth > 0) {
      final c = content[j];
      if (c == '\\' && (inSingleQuote || inDoubleQuote)) {
        j += 2;
        continue;
      }
      if (!inDoubleQuote && c == "'") {
        inSingleQuote = !inSingleQuote;
      } else if (!inSingleQuote && c == '"') {
        inDoubleQuote = !inDoubleQuote;
      } else if (!inSingleQuote && !inDoubleQuote) {
        if (c == '(') {
          depth++;
        } else if (c == ')') {
          depth--;
        }
      }
      j++;
    }

    if (depth != 0) {
      sb.write(content.substring(i, matchIndex + 4));
      i = matchIndex + 4;
      continue;
    }

    final arg = content.substring(matchIndex + 4, j - 1);

    // Case 1: .data
    if (content.startsWith('.data', j)) {
      final after = j + 5;
      var isAfterId = false;
      if (after < content.length) {
        final c = content.codeUnitAt(after);
        isAfterId = (c >= 48 && c <= 57) ||
            (c >= 65 && c <= 90) ||
            (c >= 97 && c <= 122) ||
            c == 95 ||
            c == 36;
      }
      if (!isAfterId) {
        sb.write(content.substring(i, matchIndex));
        sb.write('via($arg)');
        i = after;
        dataCount++;
        continue;
      }
    }

    // Case 2: .<stateMember>
    var matchedMember = false;
    for (final member in _stateMembers) {
      final prefix = '.$member';
      if (content.startsWith(prefix, j)) {
        final after = j + prefix.length;
        var isAfterId = false;
        if (after < content.length) {
          final c = content.codeUnitAt(after);
          isAfterId = (c >= 48 && c <= 57) ||
              (c >= 65 && c <= 90) ||
              (c >= 97 && c <= 122) ||
              c == 95 ||
              c == 36;
        }
        if (!isAfterId) {
          sb.write(content.substring(i, matchIndex));
          sb.write('via.state($arg).$member');
          i = after;
          stateCount++;
          matchedMember = true;
          break;
        }
      }
    }
    if (matchedMember) continue;

    // No replacement needed
    sb.write(content.substring(i, j));
    i = j;
  }

  onCounts(dataCount, stateCount);
  return sb.toString();
}

void main(List<String> args) {
  var dryRun = false;
  var includeMd = false;
  String? targetPath;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--include-md') {
      includeMd = true;
    } else if (arg == '--path' && i + 1 < args.length) {
      targetPath = args[++i];
    } else if (arg.startsWith('--path=')) {
      targetPath = arg.substring('--path='.length);
    }
  }

  targetPath ??= 'packages/what';

  final targetDir = Directory(targetPath);
  if (!targetDir.existsSync()) {
    stderr.writeln('Error: Directory does not exist: $targetPath');
    exit(1);
  }

  final extensions = <String>{'.dart'};
  if (includeMd) {
    extensions.add('.md');
  }

  print('========================================================');
  print('Codemod: Migrating WhatVia call to return T & via.state');
  print('Target:  $targetPath');
  print(
      'Mode:    ${dryRun ? "DRY-RUN (no changes written)" : "EXECUTE (writing changes)"}');
  print('Exts:    ${extensions.join(", ")}');
  print('========================================================\n');

  var totalFilesChanged = 0;
  var totalViaDataReplacements = 0;
  var totalViaStateReplacements = 0;

  void processFile(File file) {
    final path = file.path;
    final ext = extensions.firstWhere(
      (e) => path.endsWith(e),
      orElse: () => '',
    );
    if (ext.isEmpty) return;

    final content = file.readAsStringSync();
    var fileViaDataCount = 0;
    var fileViaStateCount = 0;

    final newContent = transform(content, (d, s) {
      fileViaDataCount = d;
      fileViaStateCount = s;
    });

    if (newContent != content) {
      totalFilesChanged++;
      totalViaDataReplacements += fileViaDataCount;
      totalViaStateReplacements += fileViaStateCount;

      print('[$ext] $path:');
      if (fileViaDataCount > 0) {
        print('  - via(...).data -> via(...): $fileViaDataCount');
      }
      if (fileViaStateCount > 0) {
        print(
            '  - via(...).<state> -> via.state(...).<state>: $fileViaStateCount');
      }

      if (!dryRun) {
        file.writeAsStringSync(newContent);
      }
    }
  }

  void scan(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name == '.dart_tool' || name == '.git' || name == 'build') continue;
        scan(entity);
      } else if (entity is File) {
        processFile(entity);
      }
    }
  }

  final sw = Stopwatch()..start();
  scan(targetDir);
  sw.stop();

  print('\n--------------------------------------------------------');
  print('Summary:');
  print('  Elapsed time:              ${sw.elapsedMilliseconds} ms');
  print('  Files modified:            $totalFilesChanged');
  print('  via(...).data replaced:    $totalViaDataReplacements');
  print('  via(...).state replaced:   $totalViaStateReplacements');
  print(
      '  Total replacements:        ${totalViaDataReplacements + totalViaStateReplacements}');
  print('--------------------------------------------------------');
}
