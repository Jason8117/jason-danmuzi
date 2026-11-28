// SPEC-ASSIST-001 AC-002 / REQ-013: the orb draws a state value only, and reduced motion stops it.
import 'package:flutter_test/flutter_test.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpOrb(
  WidgetTester tester,
  KolbiOrbState state, {
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: KolbiTheme.immersive(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: KolbiOrb(key: const Key('orb'), state: state, size: 120),
        ),
      ),
    ),
  ),
);

Finder animated() => find.descendant(
  of: find.byKey(const Key('orb')),
  matching: find.byType(AnimatedBuilder),
);

void main() {
  testWidgets('every state draws, and only the moving ones animate', (
    tester,
  ) async {
    for (final state in KolbiOrbState.values) {
      await pumpOrb(tester, state);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: '$state');
      expect(
        tester.getSize(find.byKey(const Key('orb'))),
        const Size(120, 120),
      );
      final moving = state != KolbiOrbState.idle;
      expect(
        animated(),
        moving ? findsOneWidget : findsNothing,
        reason: '$state',
      );
      expect(tester.hasRunningAnimations, moving, reason: '$state');
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion creates no animation controller', (tester) async {
    for (final state in KolbiOrbState.values) {
      await pumpOrb(tester, state, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: '$state');
      expect(animated(), findsNothing, reason: '$state');
      expect(tester.hasRunningAnimations, isFalse, reason: '$state');
    }
    // Switching reduced motion on while moving stops the controller.
    await pumpOrb(tester, KolbiOrbState.listening);
    expect(tester.hasRunningAnimations, isTrue);
    await pumpOrb(tester, KolbiOrbState.listening, reduceMotion: true);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the orb is decorative: nothing in the semantics tree', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpOrb(tester, KolbiOrbState.listening, reduceMotion: true);
    expect(
      find.descendant(
        of: find.byKey(const Key('orb')),
        matching: find.byType(ExcludeSemantics),
        matchRoot: true,
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  test('the immersive theme is the dark scheme of SPEC-DESIGN-001', () {
    final immersive = KolbiTheme.immersive();
    final dark = AppTheme.dark();
    expect(immersive.colorScheme, dark.colorScheme);
    expect(immersive.scaffoldBackgroundColor, const Color(0xFF11131F));
    expect(immersive.brightness, Brightness.dark);
  });
}
