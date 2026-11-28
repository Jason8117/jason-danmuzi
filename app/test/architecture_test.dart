// App dependency rules (SPEC-MODULE-001 REQ-007, REQ-008, REQ-011).
// Reads import/export lines as text, like server/src/architecture.test.ts.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Feature-to-feature imports that exist today: none since SPEC-SHELL-001 (REQ-018).
const allowedCrossFeature = <String>{};

/// Old paths of the moved files (plan.md §B.4); they must only re-export the packages.
const legacyPaths = [
  'lib/core/network/api_client.dart',
  'lib/core/network/live_channel.dart',
  'lib/core/theme/app_theme.dart',
  'lib/core/theme/tokens.dart',
  'lib/core/utils/formatters.dart',
  'lib/core/widgets/common.dart',
  'lib/features/calls/domain/call_models.dart',
  'lib/features/calls/domain/intake_models.dart',
  'lib/features/calls/domain/counterparties.dart',
  'lib/features/calls/domain/follow_up.dart',
  'lib/features/calls/domain/approval_comment.dart',
  'lib/features/calls/presentation/widgets/status_chip.dart',
  'lib/features/calls/presentation/widgets/outcome_card.dart',
  'lib/features/calls/presentation/widgets/transcript_view.dart',
  // SPEC-SHELL-001: moved into app core / the shell.
  'lib/features/calls/presentation/trust_notice.dart',
  'lib/core/router/app_router.dart',
];

/// Files under lib/core that only re-export a moved file; they alone may point outside core (SPEC-SHELL-001 REQ-018).
const coreReexportOnly = ['lib/core/router/app_router.dart'];

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

  test('legacy paths only re-export', () {
    for (final path in legacyPaths) {
      final source = File(path)
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//[^\n]*'), '');
      final statements = source
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      expect(statements, isNotEmpty, reason: path);
      for (final statement in statements) {
        expect(statement, startsWith('export '), reason: path);
      }
    }
  });

  test('every package:callmate import in the tests points at a file', () {
    final missing = <String>{
      for (final file in dartFiles('test'))
        for (final uri in directiveUris(file))
          if (uri.startsWith('package:callmate/'))
            if (!File(resolveInApp(file, uri)!).existsSync()) uri,
    };
    expect(missing, isEmpty);
  });

  test('core does not import features', () {
    final files = dartFiles('lib/core');
    expect(files, isNotEmpty, reason: 'no files checked');

    final found = <String>{};
    final reexports = <String>{};
    for (final file in files) {
      for (final uri in directiveUris(file)) {
        final target = resolveInApp(file, uri);
        if (target == null) continue;
        if (target.startsWith('lib/features/') ||
            target.startsWith('lib/shell/')) {
          (coreReexportOnly.contains(file) ? reexports : found).add(
            '$file -> $target',
          );
        }
      }
    }
    expect(found, isEmpty, reason: 'core reaches into features or the shell');
    // The pinned list is exactly the re-export files that still point outside core.
    expect({
      for (final r in reexports) r.split(' -> ').first,
    }, coreReexportOnly.toSet());
    for (final path in coreReexportOnly) {
      expect(
        legacyPaths,
        contains(path),
        reason: '$path must be re-export only',
      );
    }
  });

  test('router and tab switching live in the shell', () {
    final routers = [
      for (final file in dartFiles('lib'))
        if (File(file).readAsStringSync().contains('GoRouter(')) file,
    ];
    expect(routers, ['lib/shell/app_router.dart']);

    final tabSwitch = RegExp(r'\.go\(|goNamed\(|goBranch\(');
    final routeLiteral = RegExp(
      r"""'/(calls|plan|settings|inbox|history|me|assistant)""",
    );
    final violations = <String>[];
    for (final file in dartFiles('lib/features')) {
      final lines = File(file).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (tabSwitch.hasMatch(lines[i])) {
          violations.add('$file:${i + 1} tab switch: ${lines[i].trim()}');
        }
        if (routeLiteral.hasMatch(lines[i])) {
          violations.add('$file:${i + 1} route literal: ${lines[i].trim()}');
        }
      }
    }
    expect(violations, isEmpty);
  });

  // SPEC-ASSIST-001 AC-013: the device recognizer and the permission plugin sit behind the speech port.
  test('speech and permission packages stay inside the assistant feature', () {
    const speech = ['package:speech_to_text/', 'package:permission_handler/'];
    final found = <String>[
      for (final file in [
        ...dartFiles('lib'),
        ...dartFiles('../packages/kolbi_ui/lib'),
        ...dartFiles('../packages/kolbi_core/lib'),
      ])
        for (final uri in directiveUris(file))
          if (speech.any(uri.startsWith)) file,
    ];
    expect(found, isNotEmpty, reason: 'the speech adapter imports the packages');
    expect(
      found.where((f) => !f.startsWith('lib/features/assistant/speech/')),
      isEmpty,
    );
  });

  // SPEC-ASSIST-001 spec §4: the platform declarations the recognizer needs, and no Bluetooth.
  test('platform files declare the microphone and speech permissions', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in [
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
    ]) {
      expect(plist, contains('<key>$key</key>'), reason: key);
    }
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.speech.RecognitionService'));
    expect(manifest, isNot(contains('BLUETOOTH')));
  });

  // SPEC-PLACE-001 AC-017 / REQ-017 (OD-8): the location package sits behind the places feature's port,
  // and the places feature asks for location through it, not through permission_handler.
  test('the location package stays inside the places feature', () {
    final found = <String>[
      for (final file in [
        ...dartFiles('lib'),
        ...dartFiles('../packages/kolbi_ui/lib'),
        ...dartFiles('../packages/kolbi_core/lib'),
      ])
        for (final uri in directiveUris(file))
          if (uri.startsWith('package:geolocator')) file,
    ];
    expect(
      found,
      isNotEmpty,
      reason: 'the location adapter imports the package',
    );
    expect(
      found.where((f) => !f.startsWith('lib/features/places/location/')),
      isEmpty,
    );
    final placesPermission = <String>[
      for (final file in dartFiles('lib/features/places'))
        for (final uri in directiveUris(file))
          if (uri.startsWith('package:permission_handler/')) file,
    ];
    expect(placesPermission, isEmpty);
  });

  // SPEC-PLACE-001 AC-018 / REQ-018: coarse, foreground location only.
  test('platform files declare coarse location only', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final key = RegExp(
      r'<key>NSLocationWhenInUseUsageDescription</key>\s*<string>([^<]*)</string>',
    ).firstMatch(plist);
    expect(key, isNotNull);
    expect(key!.group(1), contains('콜비는 위치를 저장하지 않아요'));
    expect(plist, isNot(contains('NSLocationAlways')));
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(manifest, isNot(contains('ACCESS_FINE_LOCATION')));
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
  });
}
