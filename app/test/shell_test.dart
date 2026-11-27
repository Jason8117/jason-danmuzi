// SPEC-SHELL-001 AC-001 .. AC-006, AC-013 (app), AC-017. Tabs and screens are found by Key, never by label.
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/domain/intake_models.dart';
import 'package:callmate/features/calls/presentation/plan_card_screen.dart';
import 'package:callmate/shell/navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fakes.dart';
import 'support/shell_support.dart';

PlanDraft draft() => IntakeResult.fromJson({
  'draft': {
    'targetName': '라 파스타',
    'phoneNumber': '+8221234567',
    'goal': '금요일 7시 2명 예약',
    'conditions': <String>[],
    'language': 'ko',
  },
  'missing': <String>[],
  'phoneSource': 'history',
  'source': 'heuristic',
}).draft;

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  void expectTabBar(
    WidgetTester tester, {
    required bool visible,
    String? reason,
  }) {
    for (final key in [
      tabToday,
      tabTasks,
      assistantButton,
      tabHistory,
      tabMe,
    ]) {
      expect(
        find.byKey(key).hitTestable(),
        visible ? findsOneWidget : findsNothing,
        reason: '$key $reason',
      );
    }
  }

  testWidgets('tab bar shows four tabs and the centre assistant button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpShell(tester, tasks: mixedTasks());

    expectTabBar(tester, visible: true, reason: 'first screen');
    final xs = [
      for (final key in [
        tabToday,
        tabTasks,
        assistantButton,
        tabHistory,
        tabMe,
      ])
        tester.getCenter(find.byKey(key)).dx,
    ];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]));
    }
    final labels = {
      tabToday: '오늘',
      tabTasks: '업무',
      assistantButton: '비서',
      tabHistory: '기록',
      tabMe: '내 정보',
    };
    for (final MapEntry(:key, :value) in labels.entries) {
      expect(
        find.descendant(of: find.byKey(key), matching: find.text(value)),
        findsOneWidget,
        reason: value,
      );
    }
    expect(isSelected(tester, tabToday), isTrue);
    expect(isSelected(tester, tabTasks), isFalse);
    final todayLabel = tester.widget<Text>(
      find.descendant(of: find.byKey(tabToday), matching: find.text('오늘')),
    );
    expect(todayLabel.style?.color, const Color(0xFF4F46E5));
    final assistant = tester.getSemantics(find.byKey(assistantButton));
    expect(assistant.label, '비서 부르기');
    expect(assistant.flagsCollection.isSelected.toBoolOrNull(), isNull);

    for (final (location, extra) in [
      ('/plan', draft() as Object?),
      ('/calls/a', null),
      ('/calls/new', null),
      ('/settings', null),
    ]) {
      await pumpShell(tester, tasks: mixedTasks());
      await pushLocation(tester, location, extra: extra);
      expectTabBar(tester, visible: true, reason: location);
    }

    await pumpShell(tester, tasks: mixedTasks());
    await pushLocation(tester, '/assistant');
    expect(find.byKey(const Key('assistant-intake-field')), findsOneWidget);
    expectTabBar(tester, visible: false, reason: '/assistant');
    handle.dispose();
  });

  testWidgets(
    're-tapping the current tab pops to its root, then scrolls to top',
    (tester) async {
      await pumpShell(tester, tasks: mixedTasks());
      openTask(appRouter(tester), 'c');
      await settle(tester);
      expect(detailOf('c'), findsOneWidget);

      await tapAndSettle(tester, find.byKey(tabTasks));
      expect(detailOf('c'), findsNothing);
      expect(find.byKey(tasksScreen), findsOneWidget);

      // (2) history with 30 finished tasks, scrolled down: re-tapping history scrolls to the top.
      await pumpShell(
        tester,
        size: const Size(800, 1200),
        tasks: [
          for (var i = 0; i < 30; i++)
            shellTask(
              'f$i',
              '끝난 곳 $i',
              status: 'completed',
              outcome: successOutcome(),
              updatedAt: shellNow
                  .subtract(Duration(hours: i))
                  .toIso8601String(),
            ),
        ],
      );
      await tapAndSettle(tester, find.byKey(tabHistory));
      final list = find
          .descendant(
            of: find.byKey(historyScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(list, const Offset(0, -1500));
      await settle(tester);
      expect(
        tester.state<ScrollableState>(list).position.pixels,
        greaterThan(0),
      );
      await tapAndSettle(tester, find.byKey(tabHistory));
      expect(tester.state<ScrollableState>(list).position.pixels, 0);
    },
  );

  testWidgets('tasks badge counts approval requests', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = await pumpShell(tester, tasks: mixedTasks());
    Finder badge(String text) =>
        find.descendant(of: find.byKey(tabTasks), matching: find.text(text));
    expect(badge('2'), findsOneWidget);
    expect(tester.getSemantics(find.byKey(tabTasks)).label, '업무, 승인 대기 2개');

    // a's approval is answered: one request left.
    repo.live.emit({
      'type': 'task.updated',
      'task': {
        ...shellTaskJson(
          'a',
          '라 파스타',
          approvals: [approvalJson(status: 'approved')],
          version: 2,
        ),
      },
    });
    await settle(tester);
    expect(badge('1'), findsOneWidget);
    expect(tester.getSemantics(find.byKey(tabTasks)).label, '업무, 승인 대기 1개');

    await pumpShell(
      tester,
      tasks: [
        for (var i = 0; i < 11; i++)
          shellTask('w$i', '치과 $i', status: 'awaiting_approval'),
      ],
    );
    expect(badge('9+'), findsOneWidget);

    await pumpShell(
      tester,
      tasks: mixedTasks().where((t) => t.status.isTerminal).toList(),
    );
    expect(
      find.descendant(of: find.byKey(tabTasks), matching: find.byType(Badge)),
      findsNothing,
    );
    expect(tester.getSemantics(find.byKey(tabTasks)).label, '업무');
    handle.dispose();
  });

  testWidgets('legacy and new locations open the expected screens', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final cases = <(String, Object?, Finder)>[
      ('/calls/new', null, find.text('통화 계획 만들기')),
      ('/plan', draft(), find.byType(PlanCardScreen)),
      ('/plan', null, find.byKey(todayScreen)),
      ('/calls/a', null, detailOf('a')),
      ('/calls/nope', null, find.text('통화를 찾을 수 없어요')),
      ('/settings', null, find.text('AI 비서와 기록')),
      ('/inbox', null, find.byKey(tasksScreen)),
      ('/history', null, find.byKey(historyScreen)),
      ('/me', null, find.byKey(meScreen)),
    ];
    for (final (i, (location, extra, expected)) in cases.indexed) {
      await pumpShell(tester, tasks: mixedTasks());
      await pushLocation(tester, location, extra: extra);
      expect(expected, findsOneWidget, reason: location);
      if (i < 6) expect(isSelected(tester, tabToday), isTrue, reason: location);
    }
    handle.dispose();
  });

  testWidgets('opening a task switches to the tasks tab', (tester) async {
    final handle = tester.ensureSemantics();
    Future<void> expectOnTask(String id, String reason) async {
      expect(detailOf(id), findsOneWidget, reason: reason);
      expect(isSelected(tester, tabTasks), isTrue, reason: reason);
      await goBack(tester);
      expect(find.byKey(tasksScreen), findsOneWidget, reason: '$reason back');
    }

    // (1) today's row
    await pumpShell(tester, tasks: mixedTasks());
    await tapAndSettle(tester, find.text('라 파스타'));
    await expectOnTask('a', '(1)');

    // (2) the tasks tab's row
    await pumpShell(tester, tasks: mixedTasks());
    await tapAndSettle(tester, find.byKey(tabTasks));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byKey(tasksScreen),
        matching: find.text('헤어살롱 봄'),
      ),
    );
    await expectOnTask('c', '(2)');

    // (3) the history tab's row
    await pumpShell(tester, tasks: mixedTasks());
    await tapAndSettle(tester, find.byKey(tabHistory));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byKey(historyScreen),
        matching: find.text('관리사무소'),
      ),
    );
    await expectOnTask('d', '(3)');

    // (4) [이대로 시작] on a plan card opened from today; tapping today then shows today, not the card.
    // Without a's approval, so its snack bar never covers [이대로 시작].
    List<CallTask> quiet() => mixedTasks().where((t) => t.id != 'a').toList();
    var repo = await pumpShell(tester, tasks: quiet());
    repo.nextCreated = shellTask('task-9', '라 파스타', status: 'planning');
    await pushLocation(tester, '/plan', extra: draft());
    await tapAndSettle(tester, find.byKey(const Key('plan-start')));
    await expectOnTask('task-9', '(4)');
    await tapAndSettle(tester, find.byKey(tabToday));
    expect(find.byKey(todayScreen), findsOneWidget);
    expect(find.byType(PlanCardScreen), findsNothing);

    // (5) the approval snack bar's [답하기], received on today.
    await pumpShell(tester, tasks: mixedTasks());
    await tester.tap(find.text('답하기'));
    await settle(tester);
    await expectOnTask('a', '(5)');

    // (6) plan card, settings on top of it, back, then [이대로 시작].
    repo = await pumpShell(tester, tasks: quiet());
    repo.nextCreated = shellTask('task-9', '라 파스타', status: 'planning');
    await pushLocation(tester, '/plan', extra: draft());
    await tapAndSettle(tester, find.text('김민수'));
    expect(find.text('AI 비서와 기록'), findsOneWidget);
    await goBack(tester);
    await tapAndSettle(tester, find.byKey(const Key('plan-start')));
    await expectOnTask('task-9', '(6)');
    await tapAndSettle(tester, find.byKey(tabToday));
    expect(find.byKey(todayScreen), findsOneWidget);
    expect(find.byType(PlanCardScreen), findsNothing);

    // (7) another tab keeps the tasks tab's detail; re-tapping tasks goes to its first screen.
    await pumpShell(tester, tasks: mixedTasks());
    openTask(appRouter(tester), 'c');
    await settle(tester);
    await tapAndSettle(tester, find.byKey(tabToday));
    await tapAndSettle(tester, find.byKey(tabTasks));
    expect(detailOf('c'), findsOneWidget);
    await tapAndSettle(tester, find.byKey(tabTasks));
    expect(find.byKey(tasksScreen), findsOneWidget);
    handle.dispose();
  });

  testWidgets('centre button opens the assistant over the current tab', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final repo = await pumpShell(tester, tasks: mixedTasks());
    openTask(appRouter(tester), 'c');
    await settle(tester);

    // (1) open and close
    await tapAndSettle(tester, find.byKey(assistantButton));
    expect(find.byKey(const Key('assistant-intake-field')), findsOneWidget);
    expect(find.byKey(tabTasks).hitTestable(), findsNothing);
    await tapAndSettle(tester, find.byKey(const Key('assistant-close')));
    expect(detailOf('c'), findsOneWidget);
    expect(isSelected(tester, tabTasks), isTrue);

    // (2) send a request: the assistant closes and the plan card opens on the tasks tab.
    await tapAndSettle(tester, find.byKey(assistantButton));
    await tester.enterText(
      find.byKey(const Key('assistant-intake-field')),
      '내일 치과 예약',
    );
    await tester.pump();
    await tapAndSettle(tester, find.byKey(const Key('assistant-intake-send')));
    expect(repo.intakeCalls, ['내일 치과 예약']);
    expect(find.byKey(const Key('assistant-intake-field')), findsNothing);
    expect(find.byType(PlanCardScreen), findsOneWidget);
    expect(isSelected(tester, tabTasks), isTrue);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
