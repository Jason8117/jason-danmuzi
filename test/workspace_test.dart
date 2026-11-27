// Workspace layout check (SPEC-MODULE-001 REQ-001). Runs at the repository root,
// where the pre-commit gate runs `dart test`.
import 'dart:io';

import 'package:test/test.dart';

const members = ['app', 'packages/kolbi_core', 'packages/kolbi_ui'];

/// Reads the `workspace:` list of the root pubspec with plain line checks.
List<String> workspaceMembers(String pubspec) {
  final lines = pubspec.split('\n');
  final start = lines.indexWhere((l) => l.trimRight() == 'workspace:');
  if (start < 0) return const [];
  final found = <String>[];
  for (final line in lines.skip(start + 1)) {
    final item = RegExp(r'^\s+-\s+(\S+)\s*$').firstMatch(line);
    if (item != null) {
      found.add(item.group(1)!);
    } else if (line.trim().isNotEmpty) {
      break;
    }
  }
  return found;
}

void main() {
  test('root pubspec lists exactly the three workspace members', () {
    expect(workspaceMembers(File('pubspec.yaml').readAsStringSync()), members);
  });

  test('every member resolves through the workspace', () {
    for (final member in members) {
      final lines = File('$member/pubspec.yaml').readAsLinesSync();
      expect(
        lines.map((l) => l.trimRight()),
        contains('resolution: workspace'),
        reason: member,
      );
    }
  });
}
