// Dependency rules for kolbi_ui (SPEC-MODULE-001 REQ-006, REQ-007, AC-006).
// Reads import/export lines as text, like server/src/architecture.test.ts.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const forbidden = [
  'package:callmate/',
  'package:go_router/',
  'package:flutter_riverpod/',
  'package:shared_preferences/',
  'package:share_plus/',
  'package:kolbi_core/src/',
];

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

List<File> dartFiles(String root) =>
    Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('lib/ imports no app code, router, state management or core src', () {
    final files = dartFiles('lib');
    expect(files, isNotEmpty, reason: 'no files checked');

    final violations = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final uri = _directive.firstMatch(lines[i])?.group(1);
        if (uri == null) continue;
        if (forbidden.any(uri.startsWith)) {
          violations.add('${file.path}:${i + 1} $uri');
        }
      }
    }
    expect(violations, isEmpty);
  });
}
