// SPEC-SHELL-001 AC-007, AC-008, AC-010, AC-011, AC-012 (tasks tab and task detail). Found by Key where labels repeat.
import 'package:callmate/shell/navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'support/shell_support.dart';

Finder inTasks(Finder finder) =>
    find.descendant(of: find.byKey(tasksScreen), matching: finder);

Future<void> openTasksTab(WidgetTester tester) =>
    tapAndSettle(tester, find.byKey(tabTasks));

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  testWidgets('rows are drawn through the registered kind', (tester) async {
    await pumpShell(tester, tasks: mixedTasks());
    // Today
    expect(find.byKey(const Key('kind-call-row')), findsWidgets);
    // Tasks: a, b, c
    await openTasksTab(tester);
    expect(inTasks(find.byKey(const Key('kind-call-row'))), findsNWidgets(3));
    // History: d, e
    await tapAndSettle(tester, find.byKey(tabHistory));
    expect(
      find.descendant(
        of: find.byKey(historyScreen),
        matching: find.byKey(const Key('kind-call-row')),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('unknown kinds degrade to a placeholder', (tester) async {
    await pumpShell(
      tester,
      tasks: [
        shellTask('ga', '가 업체', updatedAt: '2026-11-26T11:00:00+09:00'),
        shellTask(
          'na',
          '나 사이트',
          kind: 'web',
          updatedAt: '2026-11-26T11:30:00+09:00',
        ),
      ],
    );
    await openTasksTab(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('kind-call-row')),
        matching: find.text('가 업체'),
      ),
      findsOneWidget,
    );
    expect(inTasks(find.byKey(const Key('kind-unknown-row'))), findsOneWidget);
    expect(inTasks(find.text('이 앱에서 아직 볼 수 없는 작업이에요')), findsOneWidget);
    expect(inTasks(find.text('나 사이트')), findsNothing);

    await tapAndSettle(
      tester,
      inTasks(find.byKey(const Key('kind-unknown-row'))),
    );
    expect(find.text('이 작업은 앱을 업데이트하면 볼 수 있어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tasks tab groups approvals, ongoing and routines', (
    tester,
  ) async {
    await pumpShell(tester, tasks: mixedTasks());
    await openTasksTab(tester);

    expect(inTasks(find.text('나의 업무')), findsOneWidget);
    for (final (key, value) in [
      ('tasks-count-ongoing', '1'),
      ('tasks-count-approvals', '2'),
      ('tasks-count-done-today', '1'),
    ]) {
      expect(
        find.descendant(of: find.byKey(Key(key)), matching: find.text(value)),
        findsOneWidget,
        reason: key,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('tasks-count-ongoing')),
        matching: find.text('진행 중'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tasks-count-approvals')),
        matching: find.text('승인 대기'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tasks-count-done-today')),
        matching: find.text('오늘 완료'),
      ),
      findsOneWidget,
    );

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final approvals = find.byKey(const Key('tasks-group-approvals'));
    final ongoing = find.byKey(const Key('tasks-group-ongoing'));
    final routines = find.byKey(const Key('tasks-group-routines'));
    expect(
      find.descendant(of: approvals, matching: find.text('승인 요청')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: ongoing, matching: find.text('진행 중')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: routines, matching: find.text('반복')),
      findsOneWidget,
    );
    expect(top(approvals), lessThan(top(ongoing)));
    expect(top(ongoing), lessThan(top(routines)));

    final pasta = top(inTasks(find.text('라 파스타')));
    final dentist = top(inTasks(find.text('우리동네 치과')));
    final salon = top(inTasks(find.text('헤어살롱 봄')));
    expect(top(approvals), lessThan(pasta));
    expect(pasta, lessThan(dentist));
    expect(dentist, lessThan(top(ongoing)));
    expect(top(ongoing), lessThan(salon));
    expect(salon, lessThan(top(routines)));
    expect(inTasks(find.text('반복할 일을 만들면 여기에 모여요')), findsOneWidget);
    expect(inTasks(find.text('관리사무소')), findsNothing);
    expect(inTasks(find.text('행복 소아과')), findsNothing);

    await tapAndSettle(tester, inTasks(find.text('끝난 업무는 기록에서 볼 수 있어요')));
    expect(isSelected(tester, tabHistory), isTrue);

    // Finished tasks only: no approval or ongoing group.
    await pumpShell(
      tester,
      tasks: mixedTasks().where((t) => t.status.isTerminal).toList(),
    );
    await openTasksTab(tester);
    expect(find.byKey(const Key('tasks-group-approvals')), findsNothing);
    expect(find.byKey(const Key('tasks-group-ongoing')), findsNothing);
    expect(find.byKey(const Key('tasks-group-routines')), findsOneWidget);
  });

  testWidgets('empty and error states', (tester) async {
    // (1) no tasks
    await pumpShell(tester);
    await openTasksTab(tester);
    expect(inTasks(find.text('아직 맡긴 일이 없어요')), findsOneWidget);
    await tapAndSettle(tester, inTasks(find.text('비서에게 맡기기')));
    expect(find.byKey(const Key('assistant-intake-field')), findsOneWidget);

    // (2) the list fails; [다시 시도] loads it again.
    final repo = await pumpShell(
      tester,
      setup: (r) => r.listError = Exception('down'),
    );
    await openTasksTab(tester);
    expect(inTasks(find.text('서버와 연결되지 않았어요')), findsOneWidget);
    final before = repo.listCalls;
    // One frame: the reload itself, before any automatic retry timer can fire.
    await tester.tap(inTasks(find.text('다시 시도')));
    await tester.pump();
    expect(repo.listCalls, before + 1);
  });

  testWidgets('task detail shows the six steps above the existing detail', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const names = ['요청 이해', '연락처 확인', '가능 여부 확인', '내 승인', '확정', '결과 보고'];
    const states = {
      'a': ['끝남', '끝남', '끝남', '지금', '대기', '대기'],
      'b': ['끝남', '끝남', '대기', '대기', '대기', '대기'],
      'c': ['끝남', '끝남', '지금', '대기', '대기', '대기'],
      'd': ['끝남', '끝남', '끝남', '건너뜀', '끝남', '끝남'],
      'e': ['끝남', '끝남', '실패', '대기', '대기', '대기'],
    };
    const lines = {
      'a': (4, '응답을 기다리고 있어요'),
      'b': (3, '다음 순서예요'),
      'c': (3, '상대와 통화하고 있어요'),
      'd': (4, '확인할 일이 없었어요'),
      'e': (3, '통화가 이어지지 않았어요'),
    };
    for (final id in states.keys) {
      await pumpShell(tester, tasks: mixedTasks(), size: const Size(800, 2400));
      openTask(appRouter(tester), id);
      await settle(tester);
      final steps = find.byKey(const Key('task-steps'));
      expect(steps, findsOneWidget, reason: id);
      final tops = [
        for (var n = 1; n <= 6; n++)
          tester.getTopLeft(find.byKey(Key('task-step-$n'))).dy,
      ];
      for (var n = 1; n < 6; n++) {
        expect(tops[n], greaterThan(tops[n - 1]), reason: '$id step ${n + 1}');
      }
      for (var n = 1; n <= 6; n++) {
        final step = find.byKey(Key('task-step-$n'));
        expect(
          find.descendant(of: step, matching: find.text(names[n - 1])),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(step).label,
          '6단계 중 $n단계, ${names[n - 1]}, ${states[id]![n - 1]}',
          reason: id,
        );
      }
      final (n, line) = lines[id]!;
      expect(
        find.descendant(
          of: find.byKey(Key('task-step-$n')),
          matching: find.text(line),
        ),
        findsOneWidget,
        reason: id,
      );
      // The steps sit on top; the existing header follows.
      expect(
        tester.getTopLeft(steps).dy,
        lessThan(tester.getTopLeft(find.text('02-123-4567')).dy),
        reason: id,
      );
      if (id == 'a') {
        expect(find.text('예약금 1만 원 결제가 필요합니다. 진행할까요?'), findsOneWidget);
        expect(find.text('네, 라 파스타입니다.'), findsOneWidget);
        expect(find.text('상대방이 기다리고 있어요'), findsOneWidget);
      }
    }
    handle.dispose();
  });
}
