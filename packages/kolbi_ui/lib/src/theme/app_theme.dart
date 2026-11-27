import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

abstract final class AppTheme {
  /// Electric Indigo: the seed, the filled-button background and live accents only, never text (SPEC-DESIGN-001).
  static const seed = Color(0xFF635BFF);

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
    final light = brightness == Brightness.light;
    // SPEC-DESIGN-001 plan §A.3: fromSeed alone does not give the 06 values, so the text roles are set here.
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
      primary: light ? AppColors.indigoText : AppColors.periwinkle,
      onPrimary: light ? AppColors.white : AppColors.darkBackground,
      primaryContainer: light ? AppColors.softIndigo : AppColors.darkIndigoContainer,
      onPrimaryContainer: light ? AppColors.indigoText : AppColors.periwinkle,
      surface: light ? AppColors.cloudWhite : AppColors.darkBackground,
      surfaceContainerLowest: light ? AppColors.white : AppColors.darkSurface,
      onSurface: light ? AppColors.midnight : AppColors.darkText,
      onSurfaceVariant: light ? AppColors.mutedText : AppColors.darkMutedText,
      outlineVariant: light ? AppColors.line : AppColors.darkLine,
      error: light ? AppColors.errorText : AppColors.darkErrorText,
      onError: light ? AppColors.white : AppColors.darkBackground,
    );
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
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: AppColors.white,
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
    // `caution` shares the neutral values: 06 has no colour for "partly done" (plan §A.1).
    CardTone.neutral || CardTone.caution =>
      _light
          ? const ToneColors(background: Color(0xFFF1F2F8), foreground: AppColors.mutedText, accent: Color(0xFF7A7F94))
          : const ToneColors(background: AppColors.darkSurface, foreground: AppColors.darkMutedText, accent: AppColors.darkMutedText),
    CardTone.attention =>
      _light
          ? const ToneColors(background: Color(0xFFFEF3E2), foreground: Color(0xFFA44A0C), accent: Color(0xFFC2650A))
          : const ToneColors(background: Color(0xFF3A2A12), foreground: Color(0xFFFBBF24), accent: Color(0xFFFBBF24)),
    CardTone.positive =>
      _light
          ? const ToneColors(background: Color(0xFFE9F7EE), foreground: Color(0xFF157037), accent: Color(0xFF159343))
          : const ToneColors(background: Color(0xFF13301F), foreground: Color(0xFF4ADE80), accent: Color(0xFF4ADE80)),
    CardTone.critical =>
      _light
          ? const ToneColors(background: Color(0xFFFDECEC), foreground: AppColors.errorText, accent: Color(0xFFDC2626))
          : const ToneColors(background: Color(0xFF3A1820), foreground: AppColors.darkErrorText, accent: AppColors.darkErrorText),
  };

  /// A call that is dialing, ringing or talking.
  ToneColors get live => _light
      ? const ToneColors(background: AppColors.softIndigo, foreground: AppColors.indigoText, accent: AppTheme.seed)
      : const ToneColors(background: AppColors.darkIndigoContainer, foreground: AppColors.periwinkle, accent: AppColors.periwinkle);
}
