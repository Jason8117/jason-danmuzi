// Dependency rules for kolbi_core (SPEC-MODULE-001 REQ-004, AC-004).
// Reads import/export lines as text, like server/src/architecture.test.ts.
import 'dart:io';

import 'package:test/test.dart';

const forbidden = [
  'package:flutter/',
  'dart:ui',
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:shared_preferences/',
  'package:kolbi_ui/',
  'package:callmate/',
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
  test('lib/ imports no Flutter, state management, UI or app code', () {
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
