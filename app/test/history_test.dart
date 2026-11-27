// SPEC-SHELL-001 AC-014: the history tab (finished tasks by Seoul day, design.md D4 result chips).
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:kolbi_ui/kolbi_ui.dart' show StatusChip, StatusCategory;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'support/shell_support.dart';

Finder inHistory(Finder finder) =>
    find.descendant(of: find.byKey(historyScreen), matching: finder);

Future<void> openHistory(WidgetTester tester, List<CallTask> tasks) async {
  await pumpShell(tester, tasks: tasks);
  await tapAndSettle(tester, find.byKey(tabHistory));
}

Finder rowOf(String name) => find.ancestor(
  of: inHistory(find.text(name)),
  matching: find.byKey(const Key('kind-call-row')),
);

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  testWidgets('history lists finished tasks by day with result chips', (
    tester,
  ) async {
    double top(Finder f) => tester.getTopLeft(f).dy;

    // (1) the mixed set
    await openHistory(tester, mixedTasks());
    final today = inHistory(find.text('오늘 · 11월 26일'));
    final yesterday = inHistory(find.text('어제 · 11월 25일'));
    expect(today, findsOneWidget);
    expect(yesterday, findsOneWidget);
    expect(top(today), lessThan(top(inHistory(find.text('관리사무소')))));
    expect(top(inHistory(find.text('관리사무소'))), lessThan(top(yesterday)));
    expect(top(yesterday), lessThan(top(inHistory(find.text('행복 소아과')))));
    expect(
      find.descendant(of: rowOf('관리사무소'), matching: find.text('완료')),
      findsOneWidget,
    );
    // Inside the chip: with no summary the result line repeats the status wording (design.md D4).
    expect(
      find.descendant(
        of: find.descendant(
          of: rowOf('행복 소아과'),
          matching: find.byType(StatusChip),
        ),
        matching: find.text('실패'),
      ),
      findsOneWidget,
    );
    for (final name in ['라 파스타', '우리동네 치과', '헤어살롱 봄']) {
      expect(inHistory(find.text(name)), findsNothing, reason: name);
    }

    // (2) nothing finished
    await openHistory(
      tester,
      mixedTasks().where((t) => !t.status.isTerminal).toList(),
    );
    expect(inHistory(find.text('아직 끝난 업무가 없어요')), findsOneWidget);

    // (3) 23:59 and 00:01 in Seoul are different days
    await openHistory(tester, [
      shellTask(
        'late',
        '늦은 가게',
        status: 'completed',
        outcome: successOutcome(),
        updatedAt: '2026-11-25T23:59:00+09:00',
      ),
      shellTask(
        'early',
        '이른 가게',
        status: 'completed',
        outcome: successOutcome(),
        updatedAt: '2026-11-26T00:01:00+09:00',
      ),
    ]);
    expect(
      top(inHistory(find.text('오늘 · 11월 26일'))),
      lessThan(top(inHistory(find.text('이른 가게')))),
    );
    expect(
      top(inHistory(find.text('이른 가게'))),
      lessThan(top(inHistory(find.text('어제 · 11월 25일')))),
    );
    expect(
      top(inHistory(find.text('어제 · 11월 25일'))),
      lessThan(top(inHistory(find.text('늦은 가게')))),
    );

    // (4) design.md D4, one task per row
    Map<String, dynamic> result(String r) => {
      ...successOutcome('결과 $r'),
      'result': r,
    };
    final cases =
        <(String, String, Map<String, dynamic>?, StatusCategory, String)>[
          ('완료 가게', 'completed', result('success'), StatusCategory.done, '완료'),
          (
            '일부 가게',
            'completed',
            result('partial'),
            StatusCategory.waiting,
            '일부 달성',
          ),
          (
            '미확인 가게',
            'completed',
            result('unverified'),
            StatusCategory.waiting,
            '확인 못 함',
          ),
          ('결과없음 가게', 'completed', null, StatusCategory.waiting, '확인 못 함'),
          (
            '못함 가게',
            'completed',
            result('failed'),
            StatusCategory.failed,
            '달성 못 함',
          ),
          ('실패 가게', 'failed', null, StatusCategory.failed, '실패'),
          ('취소 가게', 'canceled', null, StatusCategory.waiting, '취소됨'),
        ];
    await openHistory(tester, [
      for (final (i, (name, status, outcome, _, _)) in cases.indexed)
        shellTask(
          'r$i',
          name,
          status: status,
          outcome: outcome,
          updatedAt: '2026-11-26T0${i + 1}:00:00+09:00',
        ),
    ]);
    for (final (name, _, outcome, category, label) in cases) {
      final chip = find.descendant(
        of: rowOf(name),
        matching: find.byType(StatusChip),
      );
      expect(chip, findsOneWidget, reason: name);
      expect(tester.widget<StatusChip>(chip).category, category, reason: name);
      expect(
        find.descendant(of: chip, matching: find.text(label)),
        findsOneWidget,
        reason: name,
      );
      expect(
        find.descendant(of: chip, matching: find.byType(Icon)),
        findsOneWidget,
        reason: name,
      );
      // The result line: the summary when there is one, else the status wording.
      final line = outcome == null ? null : outcome['summary'] as String;
      if (line != null)
        expect(
          find.descendant(of: rowOf(name), matching: find.text(line)),
          findsOneWidget,
        );
    }
  });
}
