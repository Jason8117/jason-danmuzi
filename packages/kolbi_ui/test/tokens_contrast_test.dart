// Contrast of every text and accent pair, light and dark (SPEC-DESIGN-001 REQ-003, AC-003).
import 'package:flutter_test/flutter_test.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

const electricIndigo = Color(0xFF635BFF);

String hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

/// (name, foreground, background) pairs drawn as text.
List<(String, Color, Color)> textPairs(ThemeData theme) {
  final s = theme.colorScheme;
  final card = theme.cardTheme.color!;
  final filled = theme.filledButtonTheme.style!;
  return [
    for (final tone in CardTone.values)
      ('${tone.name} text', s.tone(tone).foreground, s.tone(tone).background),
    ('live text', s.live.foreground, s.live.background),
    for (final (bgName, bg) in [
      ('background', theme.scaffoldBackgroundColor),
      ('card', card),
    ]) ...[
      ('onSurface on $bgName', s.onSurface, bg),
      ('onSurfaceVariant on $bgName', s.onSurfaceVariant, bg),
      ('primary on $bgName', s.primary, bg),
      ('error on $bgName', s.error, bg),
    ],
    ('onPrimary on primary', s.onPrimary, s.primary),
    (
      'onPrimaryContainer on primaryContainer',
      s.onPrimaryContainer,
      s.primaryContainer,
    ),
    (
      'filled button text',
      filled.foregroundColor!.resolve({})!,
      filled.backgroundColor!.resolve({})!,
    ),
    ('onError on error (danger button)', s.onError, s.error),
  ];
}

/// (name, accent, background) pairs drawn as icons and borders.
List<(String, Color, Color)> accentPairs(ThemeData theme) {
  final s = theme.colorScheme;
  return [
    for (final tone in CardTone.values)
      ('${tone.name} accent', s.tone(tone).accent, s.tone(tone).background),
    ('live accent', s.live.accent, s.live.background),
  ];
}

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    for (final (name, fg, bg) in textPairs(theme)) {
      final ratio = contrastRatio(fg, bg);
      test(
        '$mode $name ${hex(fg)} on ${hex(bg)} reaches 4.5:1 (${ratio.toStringAsFixed(2)})',
        () {
          expect(ratio, greaterThanOrEqualTo(4.5));
        },
      );
    }
    for (final (name, fg, bg) in accentPairs(theme)) {
      final ratio = contrastRatio(fg, bg);
      test(
        '$mode $name ${hex(fg)} on ${hex(bg)} reaches 3:1 (${ratio.toStringAsFixed(2)})',
        () {
          expect(ratio, greaterThanOrEqualTo(3.0));
        },
      );
    }
    test('$mode never draws Electric Indigo #635BFF as text', () {
      final offenders = [
        for (final (name, fg, _) in textPairs(theme))
          if (fg == electricIndigo) name,
      ];
      expect(offenders, isEmpty);
    });
  }
}
