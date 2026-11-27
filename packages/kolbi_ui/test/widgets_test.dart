// Package tests for kolbi_ui (SPEC-MODULE-001 REQ-005, REQ-012, AC-005, AC-012).
import 'package:flutter_test/flutter_test.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('spacing and tap-size tokens keep their values', () {
    expect(
      [
        AppSpace.xs,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.lg,
        AppSpace.xl,
        AppSpace.xxl,
        AppSpace.xxxl,
      ],
      [4, 8, 12, 16, 20, 24, 32],
    );
    expect(kMinTapTarget, 48);
  });

  testWidgets('AppCard renders its title and body', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppCard(title: '통화 결과', child: Text('본문')),
        ),
      ),
    );

    expect(find.text('통화 결과'), findsOneWidget);
    expect(find.text('본문'), findsOneWidget);
  });

  test('the barrel exposes the shared UI names', () {
    // Compiles only while each name is exported by package:kolbi_ui/kolbi_ui.dart.
    const types = [
      AppCard,
      SectionCard,
      MessageView,
      PulsingDot,
      ResponsiveBody,
      BulletList,
      CardTone,
      AppTheme,
      StatusChip,
      OutcomeCard,
      TranscriptView,
      CodePointLengthLimitingFormatter,
    ];
    expect(types, hasLength(12));
    expect(describeError(Exception('x')), isNotEmpty);
  });
}
