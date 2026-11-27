// App dependency rules (SPEC-MODULE-001 REQ-007, REQ-008, REQ-011).
// Reads import/export lines as text, like server/src/architecture.test.ts.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Feature-to-feature imports that exist today. SPEC-SHELL-001 removes the last one.
const allowedCrossFeature = {
  'lib/features/settings/settings_screen.dart -> lib/features/calls/domain/call_models.dart',
  'lib/features/settings/settings_screen.dart -> lib/features/calls/presentation/trust_notice.dart',
};

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
final _feature = RegExp(r'^lib/features/([^/]+)/');

List<String> dartFiles(String root) =>
    Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.dart'))
        .toList()
      ..sort();

List<String> directiveUris(String path) => [
  for (final line in File(path).readAsLinesSync())
    ?_directive.firstMatch(line)?.group(1),
];

/// Resolves [uri] from [from] to an app path under `lib/`, or null when it points elsewhere.
String? resolveInApp(String from, String uri) {
  if (uri.startsWith('package:callmate/')) {
    return 'lib/${uri.substring('package:callmate/'.length)}';
  }
  if (uri.contains(':')) return null;
  return Uri(path: from).resolve(uri).path;
}

void main() {
  test('app does not reach into package src', () {
    final files = [...dartFiles('lib'), ...dartFiles('test')];
    expect(files, isNotEmpty, reason: 'no files checked');

    final violations = [
      for (final file in files)
        for (final uri in directiveUris(file))
          if (uri.startsWith('package:kolbi_core/src/') ||
              uri.startsWith('package:kolbi_ui/src/'))
            '$file $uri',
    ];
    expect(violations, isEmpty);
  });

  test('features do not import each other', () {
    final files = dartFiles('lib/features');
    expect(files, isNotEmpty, reason: 'no files checked');

    final found = <String>{};
    for (final file in files) {
      final from = _feature.firstMatch(file)!.group(1);
      for (final uri in directiveUris(file)) {
        final target = resolveInApp(file, uri);
        final to = target == null
            ? null
            : _feature.firstMatch(target)?.group(1);
        if (to != null && to != from) found.add('$file -> $target');
      }
    }

    expect(
      found.difference(allowedCrossFeature),
      isEmpty,
      reason: 'cross-feature import not in the allowlist',
    );
    expect(
      allowedCrossFeature.difference(found),
      isEmpty,
      reason: 'allowlist entry no longer exists; remove it',
    );
  });
}
