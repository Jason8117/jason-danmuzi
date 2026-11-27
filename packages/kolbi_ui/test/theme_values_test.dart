// Theme values for SPEC-DESIGN-001 (AC-001, AC-002, AC-004a).
import 'package:flutter_test/flutter_test.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

/// plan.md §A.3 role table: (light, dark).
const roles = <String, (Color, Color)>{
  'primary': (Color(0xFF4F46E5), Color(0xFFA6ACFF)),
  'onPrimary': (Color(0xFFFFFFFF), Color(0xFF11131F)),
  'primaryContainer': (Color(0xFFEEEDFC), Color(0xFF23264A)),
  'onPrimaryContainer': (Color(0xFF4F46E5), Color(0xFFA6ACFF)),
  'surface': (Color(0xFFF7F8FC), Color(0xFF11131F)),
  'surfaceContainerLowest': (Color(0xFFFFFFFF), Color(0xFF1B1F33)),
  'onSurface': (Color(0xFF171B2E), Color(0xFFF2F3FA)),
  'onSurfaceVariant': (Color(0xFF5F6478), Color(0xFFA3A8C3)),
  'outlineVariant': (Color(0xFFE6E8F0), Color(0xFF2A2E45)),
  'error': (Color(0xFFB91C1C), Color(0xFFFCA5A5)),
  'onError': (Color(0xFFFFFFFF), Color(0xFF11131F)),
};

Color role(ColorScheme s, String name) => switch (name) {
  'primary' => s.primary,
  'onPrimary' => s.onPrimary,
  'primaryContainer' => s.primaryContainer,
  'onPrimaryContainer' => s.onPrimaryContainer,
  'surface' => s.surface,
  'surfaceContainerLowest' => s.surfaceContainerLowest,
  'onSurface' => s.onSurface,
  'onSurfaceVariant' => s.onSurfaceVariant,
  'outlineVariant' => s.outlineVariant,
  'error' => s.error,
  'onError' => s.onError,
  _ => throw ArgumentError(name),
};

/// plan.md §A.1 tone table: background, foreground, accent.
typedef Tone = (Color, Color, Color);
const neutralLight = (Color(0xFFF1F2F8), Color(0xFF5F6478), Color(0xFF7A7F94));
const neutralDark = (Color(0xFF1B1F33), Color(0xFFA3A8C3), Color(0xFFA3A8C3));
const tones = <String, (Tone, Tone)>{
  'live': (
    (Color(0xFFEEEDFC), Color(0xFF4F46E5), Color(0xFF635BFF)),
    (Color(0xFF23264A), Color(0xFFA6ACFF), Color(0xFFA6ACFF)),
  ),
  'attention': (
    (Color(0xFFFEF3E2), Color(0xFFA44A0C), Color(0xFFC2650A)),
    (Color(0xFF3A2A12), Color(0xFFFBBF24), Color(0xFFFBBF24)),
  ),
  'positive': (
    (Color(0xFFE9F7EE), Color(0xFF157037), Color(0xFF159343)),
    (Color(0xFF13301F), Color(0xFF4ADE80), Color(0xFF4ADE80)),
  ),
  'critical': (
    (Color(0xFFFDECEC), Color(0xFFB91C1C), Color(0xFFDC2626)),
    (Color(0xFF3A1820), Color(0xFFFCA5A5), Color(0xFFFCA5A5)),
  ),
  'neutral': (neutralLight, neutralDark),
  'caution': (neutralLight, neutralDark),
};

ToneColors toneOf(ColorScheme s, String name) =>
    name == 'live' ? s.live : s.tone(CardTone.values.byName(name));

void expectRoles(ThemeData theme, {required bool dark}) {
  final mode = dark ? 'dark' : 'light';
  for (final MapEntry(key: name, value: (light, darkValue)) in roles.entries) {
    expect(
      role(theme.colorScheme, name),
      dark ? darkValue : light,
      reason: '$mode $name',
    );
  }
}

void expectTones(ThemeData theme, {required bool dark}) {
  final mode = dark ? 'dark' : 'light';
  for (final MapEntry(key: name, value: (light, darkValue)) in tones.entries) {
    final (bg, fg, accent) = dark ? darkValue : light;
    final colors = toneOf(theme.colorScheme, name);
    expect(colors.background, bg, reason: '$mode $name background');
    expect(colors.foreground, fg, reason: '$mode $name foreground');
    expect(colors.accent, accent, reason: '$mode $name accent');
  }
}

void main() {
  // AC-001
  test('seed, roles, background, card and filled button follow plan §A.3', () {
    expect(AppTheme.seed, const Color(0xFF635BFF));
    for (final (theme, dark) in [
      (AppTheme.light(), false),
      (AppTheme.dark(), true),
    ]) {
      final mode = dark ? 'dark' : 'light';
      expectRoles(theme, dark: dark);
      expect(
        theme.scaffoldBackgroundColor,
        dark ? const Color(0xFF11131F) : const Color(0xFFF7F8FC),
        reason: mode,
      );
      expect(
        theme.cardTheme.color,
        dark ? const Color(0xFF1B1F33) : const Color(0xFFFFFFFF),
        reason: mode,
      );
      final style = theme.filledButtonTheme.style!;
      expect(
        style.backgroundColor?.resolve({}),
        const Color(0xFF635BFF),
        reason: '$mode filled bg',
      );
      expect(
        style.foregroundColor?.resolve({}),
        const Color(0xFFFFFFFF),
        reason: '$mode filled fg',
      );
    }
  });

  // AC-002
  test('tone pairs follow plan §A.1 and keep their names', () {
    expect(CardTone.values.map((t) => t.name), [
      'neutral',
      'attention',
      'positive',
      'caution',
      'critical',
    ]);
    expectTones(AppTheme.light(), dark: false);
    expectTones(AppTheme.dark(), dark: true);
  });

  // AC-004a
  test('dark scheme uses the 06 dark roles', () {
    final theme = AppTheme.dark();
    expect(theme.colorScheme.brightness, Brightness.dark);
    expectRoles(theme, dark: true);
    expectTones(theme, dark: true);
  });
}
