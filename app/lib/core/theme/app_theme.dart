import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static const seed = Color(0xFF1F8A70);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// REQ-003 type scale. Colors come from the theme; the font is the system default (OD-4).
  static const textTheme = TextTheme(
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 15, height: 1.5),
    bodySmall: TextStyle(fontSize: 13, height: 1.45),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill))),
    );
  }
}

/// The five card moods (REQ-004). Only [attention] draws a border.
enum CardTone { neutral, attention, positive, caution, critical }

/// A background with the text and the icon/border color drawn on it.
/// Text pairs reach 4.5:1 and icon/border pairs 3:1 in both modes (REQ-002, AC-002).
@immutable
class ToneColors {
  const ToneColors({required this.background, required this.foreground, required this.accent});

  final Color background;

  /// Text on [background].
  final Color foreground;

  /// Icons and borders on [background].
  final Color accent;
}

/// Status colors for chips, cards and the live call header.
extension StatusColors on ColorScheme {
  bool get _light => brightness == Brightness.light;

  ToneColors tone(CardTone tone) => switch (tone) {
    CardTone.neutral => ToneColors(background: surfaceContainerLow, foreground: onSurface, accent: primary),
    CardTone.attention =>
      _light
          ? const ToneColors(background: Color(0xFFFFF1D6), foreground: Color(0xFF6B3A00), accent: Color(0xFFA86200))
          : const ToneColors(background: Color(0xFF3A2700), foreground: Color(0xFFFFD593), accent: Color(0xFFE2A53C)),
    CardTone.positive =>
      _light
          ? const ToneColors(background: Color(0xFFDDF3E6), foreground: Color(0xFF0B5130), accent: Color(0xFF23784A))
          : const ToneColors(background: Color(0xFF0E2E1E), foreground: Color(0xFFA6E8C0), accent: Color(0xFF5CC488)),
    CardTone.caution =>
      _light
          ? const ToneColors(background: Color(0xFFFFE6D5), foreground: Color(0xFF7F3300), accent: Color(0xFFB85000))
          : const ToneColors(background: Color(0xFF3A1E05), foreground: Color(0xFFFFC6A0), accent: Color(0xFFF08A4B)),
    CardTone.critical => ToneColors(background: errorContainer, foreground: onErrorContainer, accent: error),
  };

  /// A call that is dialing, ringing or talking.
  ToneColors get live => _light
      ? const ToneColors(background: Color(0xFFDCF2E4), foreground: Color(0xFF0B5A31), accent: Color(0xFF1D7F47))
      : const ToneColors(background: Color(0xFF0D2C1C), foreground: Color(0xFF97E3B4), accent: Color(0xFF4FC07F));
}
