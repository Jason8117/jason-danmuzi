import 'package:callmate/core/theme/app_theme.dart';
import 'package:callmate/core/theme/tokens.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/presentation/widgets/status_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// SPEC-UX-001 AC-001, AC-002, AC-003, AC-006 (tokens, contrast, type scale, reduced motion).
void main() {
  // AC-001
  test('design tokens have the agreed values', () {
    expect(
      [AppSpace.xs, AppSpace.sm, AppSpace.md, AppSpace.lg, AppSpace.xl, AppSpace.xxl, AppSpace.xxxl],
      [4, 8, 12, 16, 20, 24, 32],
    );
    expect([AppRadius.sm, AppRadius.md, AppRadius.lg, AppRadius.pill], [12, 16, 20, 999]);
    expect(
      [AppMotion.fast, AppMotion.medium, AppMotion.slow],
      const [Duration(milliseconds: 150), Duration(milliseconds: 250), Duration(milliseconds: 400)],
    );
    expect(AppMotion.pulse, const Duration(milliseconds: 1100));
    expect(kMinTapTarget, 48);
  });

  // AC-002
  test('status color pairs meet contrast in light and dark', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21.0, 0.001));
    expect(contrastRatio(const Color(0xFFD97706), const Color(0xFFFFFFFF)).toStringAsFixed(2), '3.19');
    expect(AppTheme.seed, const Color(0xFF1F8A70));

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      final pairs = {for (final tone in CardTone.values) tone.name: scheme.tone(tone), 'live': scheme.live};
      for (final MapEntry(key: name, value: colors) in pairs.entries) {
        final mode = scheme.brightness.name;
        expect(
          contrastRatio(colors.background, colors.foreground),
          greaterThanOrEqualTo(4.5),
          reason: '$mode $name text',
        );
        expect(
          contrastRatio(colors.background, colors.accent),
          greaterThanOrEqualTo(3.0),
          reason: '$mode $name accent',
        );
      }
    }
  });

  // AC-003
  test('text styles follow the type scale', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final t = theme.textTheme;
      void expectStyle(TextStyle? style, double size, {FontWeight? weight, double? height}) {
        expect(style?.fontSize, size);
        if (weight != null) expect(style?.fontWeight, weight);
        if (height != null) expect(style?.height, height);
      }

      expectStyle(t.titleLarge, 22, weight: FontWeight.w700);
      expectStyle(t.titleMedium, 18, weight: FontWeight.w700);
      expectStyle(t.titleSmall, 16, weight: FontWeight.w700);
      expectStyle(t.bodyLarge, 16, height: 1.5);
      expectStyle(t.bodyMedium, 15, height: 1.5);
      expectStyle(t.bodySmall, 13, height: 1.45);
      expectStyle(t.labelLarge, 15, weight: FontWeight.w600);
      expectStyle(t.labelSmall, 12, weight: FontWeight.w600);
    }
  });

  // AC-006 (helper and live dot)
  testWidgets('respects reduce motion', (tester) async {
    Future<(Duration, double, double)> measure(bool reduce) async {
      late Duration medium;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Builder(
              builder: (context) {
                medium = motionDuration(context, AppMotion.medium);
                return const Scaffold(body: Center(child: StatusChip(TaskStatus.inProgress)));
              },
            ),
          ),
        ),
      );
      double opacity() => tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value;
      final before = opacity();
      await tester.pump(const Duration(milliseconds: 500));
      final after = opacity();
      await tester.pumpWidget(const SizedBox());
      return (medium, before, after);
    }

    final (onDuration, onBefore, onAfter) = await measure(true);
    expect(onDuration, Duration.zero);
    expect(onAfter, onBefore);

    final (offDuration, offBefore, offAfter) = await measure(false);
    expect(offDuration, const Duration(milliseconds: 250));
    expect(offAfter, isNot(offBefore));
  });
}
