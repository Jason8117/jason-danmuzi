// Status chip categories (SPEC-DESIGN-001 REQ-007, AC-007; plan.md §A.2 18-cell table).
import 'package:flutter_test/flutter_test.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Without a pending approval: (tone, leading icon or null for the pulsing dot).
const table = <TaskStatus, (String, IconData?)>{
  TaskStatus.dialing: ('live', null),
  TaskStatus.ringing: ('live', null),
  TaskStatus.inProgress: ('live', null),
  TaskStatus.planning: ('live', Icons.autorenew_rounded),
  TaskStatus.summarizing: ('live', Icons.autorenew_rounded),
  TaskStatus.awaitingApproval: ('attention', Icons.pan_tool_alt_rounded),
  TaskStatus.completed: ('positive', Icons.task_alt_rounded),
  TaskStatus.failed: ('critical', Icons.report_rounded),
  TaskStatus.canceled: ('neutral', Icons.pause_circle_rounded),
};

ToneColors toneOf(ColorScheme s, String name) =>
    name == 'live' ? s.live : s.tone(CardTone.values.byName(name));

/// A fresh tree per chip, so the AnimatedSwitcher never shows the previous chip fading out.
Future<void> pumpChip(
  WidgetTester tester,
  Widget chip, {
  bool dark = false,
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(body: Center(child: chip)),
    ),
  );
}

/// Checks one chip on screen against its tone, label and leading mark.
void expectChip(
  WidgetTester tester, {
  required String tone,
  required String label,
  IconData? icon,
  required String cell,
}) {
  final chip = find.byType(StatusChip);
  final colors = toneOf(Theme.of(tester.element(chip)).colorScheme, tone);
  final box = tester.widget<Container>(
    find.descendant(of: chip, matching: find.byType(Container)).first,
  );
  expect(
    (box.decoration! as BoxDecoration).color,
    colors.background,
    reason: '$cell background',
  );
  expect(
    tester
        .widget<Text>(find.descendant(of: chip, matching: find.text(label)))
        .style
        ?.color,
    colors.foreground,
    reason: '$cell text',
  );
  expect(
    find.bySemanticsLabel('상태: $label'),
    findsOneWidget,
    reason: '$cell semantics',
  );

  final icons = find.descendant(of: chip, matching: find.byType(Icon));
  final dots = find.descendant(of: chip, matching: find.byType(PulsingDot));
  if (icon == null) {
    expect(dots, findsOneWidget, reason: '$cell dot');
    expect(icons, findsNothing, reason: '$cell no icon');
  } else {
    expect(dots, findsNothing, reason: '$cell no dot');
    expect(icons, findsOneWidget, reason: '$cell one icon');
    final drawn = tester.widget<Icon>(icons);
    expect(drawn.icon, icon, reason: '$cell icon');
    expect(drawn.color, colors.foreground, reason: '$cell icon colour');
  }
  expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  expect(find.byIcon(Icons.error_rounded), findsNothing);
}

void main() {
  testWidgets(
    'every status with and without a pending approval follows the 18-cell table',
    (tester) async {
      final handle = tester.ensureSemantics();
      expect(table.keys.toSet(), TaskStatus.values.toSet());
      for (final dark in [false, true]) {
        for (final status in TaskStatus.values) {
          await pumpChip(
            tester,
            StatusChip(status, needsApproval: true),
            dark: dark,
          );
          expectChip(
            tester,
            tone: 'attention',
            label: '승인 대기',
            cell: '${status.name}+approval dark=$dark',
          );

          final (tone, icon) = table[status]!;
          await pumpChip(tester, StatusChip(status), dark: dark);
          expectChip(
            tester,
            tone: tone,
            label: status.label,
            icon: icon,
            cell: '${status.name} dark=$dark',
          );
        }
      }
      handle.dispose();
    },
  );

  // AC-008
  testWidgets('category chips use the category tone and five distinct icons', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const categories = <StatusCategory, (String, IconData)>{
      StatusCategory.waiting: ('neutral', Icons.pause_circle_rounded),
      StatusCategory.active: ('live', Icons.autorenew_rounded),
      StatusCategory.needsApproval: ('attention', Icons.pan_tool_alt_rounded),
      StatusCategory.done: ('positive', Icons.task_alt_rounded),
      StatusCategory.failed: ('critical', Icons.report_rounded),
    };
    expect(categories.keys.toSet(), StatusCategory.values.toSet());
    for (final dark in [false, true]) {
      final codePoints = <int>{};
      for (final MapEntry(key: category, value: (tone, icon))
          in categories.entries) {
        await pumpChip(tester, StatusChip.category(category, '라벨'), dark: dark);
        expectChip(
          tester,
          tone: tone,
          label: '라벨',
          icon: icon,
          cell: '${category.name} dark=$dark',
        );
        codePoints.add(tester.widget<Icon>(find.byType(Icon)).icon!.codePoint);
      }
      expect(codePoints, hasLength(5));
    }
    handle.dispose();
  });
}
