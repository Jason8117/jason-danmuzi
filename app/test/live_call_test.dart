// SPEC-ASSIST-001 AC-011, AC-012, AC-014 (live call). Screens and buttons are found by Key where one exists.
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/presentation/widgets/approval_card.dart';
import 'package:callmate/shell/navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'support/shell_support.dart';

const live = Key('live-call-screen');
const openLive = Key('open-live-call');

Map<String, dynamic> callJson({
  String id = 'p',
  String name = '피자 하우스',
  String status = 'in_progress',
  int lines = 22,
  int version = 1,
  List<Map<String, dynamic>> approvals = const [],
}) => {
  ...shellTaskJson(
    id,
    name,
    status: status,
    approvals: approvals,
    version: version,
  ),
  'goal': '토요일 저녁 6시 4명 예약',
  'transcript': [
    for (var i = 0; i < lines; i++)
      {
        'id': 'l$i',
        'speaker': i.isEven ? 'agent' : 'callee',
        'text': '자막 $i번째 줄',
        'at': DateTime.now().toUtc().toIso8601String(),
      },
  ],
};

Future<CountingCallsRepository> pumpLive(
  WidgetTester tester, {
  List<Map<String, dynamic>> extra = const [],
  int lines = 22,
  Size size = const Size(800, 600),
  double textScale = 1,
}) async {
  final repo = await pumpShell(
    tester,
    tasks: [
      CallTask.fromJson(callJson(lines: lines)),
      for (final json in extra) CallTask.fromJson(json),
    ],
    size: size,
    textScale: textScale,
  );
  openTask(appRouter(tester), 'p');
  await settle(tester);
  await tapAndSettle(tester, find.byKey(openLive));
  expect(find.byKey(live), findsOneWidget);
  return repo;
}

/// A live update carrying [json] as the new snapshot of its task.
Future<void> update(
  WidgetTester tester,
  CountingCallsRepository repo,
  Map<String, dynamic> json,
) async {
  repo.live.emit({'type': 'task.updated', 'task': json});
  await settle(tester);
}

ScrollPosition captions(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('live-captions')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  // AC-011 (1), (2)
  testWidgets('live call screen shows captions, hang-up and approvals', (
    tester,
  ) async {
    for (final reduce in [false, true]) {
      if (reduce) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
      }
      final repo = await pumpLive(tester);
      final scaffold = find.byKey(live);
      final material = tester.widget<Material>(
        find.descendant(of: scaffold, matching: find.byType(Material)).first,
      );
      expect(material.color, const Color(0xFF11131F));
      expect(find.text('통화 끊기'), findsOneWidget);
      expect(find.text('통화 중'), findsOneWidget);
      expect(find.text('토요일 저녁 6시 4명 예약'), findsOneWidget);
      // A speaker name over every bubble: 11 "콜비", 11 the other party, plus the header name.
      expect(find.text('콜비'), findsNWidgets(11));
      expect(find.text('피자 하우스'), findsNWidgets(12));
      expect(find.text('실시간 자막 · 통화는 글로 기록돼요'), findsOneWidget);
      expect(captions(tester).maxScrollExtent, greaterThan(0));
      expect(
        captions(tester).pixels,
        captions(tester).maxScrollExtent,
        reason: 'reduce=$reduce',
      );

      // A new line follows to the end.
      await update(tester, repo, callJson(lines: 24, version: 2));
      expect(find.text('자막 23번째 줄'), findsOneWidget);
      expect(captions(tester).pixels, captions(tester).maxScrollExtent);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    }

    // (2) a pending approval: the light card pinned at the bottom; [승인] decides once.
    final repo = await pumpLive(tester);
    await update(
      tester,
      repo,
      callJson(version: 2, approvals: [pendingApproval(id: 'approval-p')]),
    );
    final card = find.byType(ApprovalCard);
    expect(card, findsOneWidget);
    expect(Theme.of(tester.element(card)).brightness, Brightness.light);
    expect(
      find.descendant(
        of: card,
        matching: find.text('예약금 1만 원 결제가 필요합니다. 진행할까요?'),
      ),
      findsOneWidget,
    );
    await tapAndSettle(
      tester,
      find.descendant(of: card, matching: find.text('승인')),
    );
    expect(repo.decisions, hasLength(1));
    expect(repo.decisions.single.approve, isTrue);

    // [통화 끊기] does what the task screen's button does: it ends the call (no dialog there either).
    final hangUp = await pumpLive(tester);
    await tapAndSettle(tester, find.text('통화 끊기'));
    expect(hangUp.cancelCalls, ['p']);
    expect(tester.takeException(), isNull);
  });

  // AC-011 (3)
  testWidgets('finishing the call returns to the task screen', (tester) async {
    final repo = await pumpLive(tester);
    await update(tester, repo, callJson(status: 'summarizing', version: 2));
    await settle(tester); // the pop runs after the frame that saw the update
    expect(find.byKey(live), findsNothing);
    expect(find.byKey(const Key('task-steps')), findsOneWidget);
    await goBack(tester);
    expect(find.byKey(tasksScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // AC-011 (4), (5)
  testWidgets('approval alerts from the live and assistant screens', (
    tester,
  ) async {
    final salon = shellTaskJson('c', '헤어살롱 봄');
    var repo = await pumpLive(tester, extra: [salon]);
    // The same task: no snack bar over its own live screen.
    await update(
      tester,
      repo,
      callJson(version: 2, approvals: [pendingApproval(id: 'approval-new')]),
    );
    expect(find.byType(SnackBar), findsNothing);
    // Another task: the snack bar, and [답하기] opens it on the tasks tab.
    await update(tester, repo, {
      ...salon,
      'version': 2,
      'approvals': [pendingApproval(id: 'approval-c')],
    });
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.text('답하기'));
    await settle(tester);
    expect(detailOf('c'), findsOneWidget);
    expect(isSelected(tester, tabTasks), isTrue);
    expect(tester.takeException(), isNull);

    // (5) the same alert while the assistant is open: the assistant closes first.
    repo = await pumpShell(
      tester,
      tasks: [CallTask.fromJson(callJson()), CallTask.fromJson(salon)],
    );
    await tapAndSettle(tester, find.byKey(assistantButton));
    expect(find.byKey(const Key('assistant-screen')), findsOneWidget);
    await update(tester, repo, {
      ...salon,
      'version': 2,
      'approvals': [pendingApproval(id: 'approval-c')],
    });
    await tester.tap(find.text('답하기'));
    await settle(tester);
    expect(find.byKey(const Key('assistant-screen')), findsNothing);
    expect(detailOf('c'), findsOneWidget);
    expect(isSelected(tester, tabTasks), isTrue);
    expect(tester.takeException(), isNull);
  });

  // AC-012
  testWidgets('task screen links to the live call', (tester) async {
    // (1) a live call: [통화 보기], and the transcript stays whole on the task screen.
    var repo = await pumpShell(
      tester,
      tasks: [CallTask.fromJson(callJson(lines: 6))],
    );
    openTask(appRouter(tester), 'p');
    await settle(tester);
    for (var i = 0; i < 6; i++) {
      expect(find.text('자막 $i번째 줄'), findsOneWidget, reason: 'line $i');
    }
    await tapAndSettle(tester, find.byKey(openLive));
    expect(find.byKey(live), findsOneWidget);

    // An approval answered on the task screen is gone from the live screen.
    await goBack(tester);
    await update(
      tester,
      repo,
      callJson(
        lines: 6,
        version: 2,
        approvals: [pendingApproval(id: 'approval-p')],
      ),
    );
    await tapAndSettle(
      tester,
      find.descendant(of: find.byType(ApprovalCard), matching: find.text('승인')),
    );
    expect(repo.decisions, hasLength(1));
    await update(
      tester,
      repo,
      callJson(
        lines: 6,
        version: 3,
        approvals: [
          {...pendingApproval(id: 'approval-p'), 'status': 'approved'},
        ],
      ),
    );
    await tapAndSettle(tester, find.byKey(openLive));
    expect(find.byKey(live), findsOneWidget);
    expect(find.byType(ApprovalCard), findsNothing);

    // (2) a finished call: no [통화 보기].
    repo = await pumpShell(tester, tasks: mixedTasks());
    openTask(appRouter(tester), 'd');
    await settle(tester);
    expect(find.byKey(openLive), findsNothing);
  });

  // AC-014 (live call)
  testWidgets('immersive screens meet the accessibility guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var repo = await pumpLive(tester, size: const Size(800, 2400));
    await update(
      tester,
      repo,
      callJson(version: 2, approvals: [pendingApproval(id: 'approval-p')]),
    );
    for (final guideline in [
      androidTapTargetGuideline,
      iOSTapTargetGuideline,
      labeledTapTargetGuideline,
      textContrastGuideline,
    ]) {
      await expectLater(
        tester,
        meetsGuideline(guideline),
        reason: guideline.description,
      );
    }

    // 360x640 at 2x: no overflow, and [승인] can be scrolled to and pressed.
    repo = await pumpLive(tester, size: const Size(360, 640), textScale: 2);
    await update(
      tester,
      repo,
      callJson(version: 2, approvals: [pendingApproval(id: 'approval-p')]),
    );
    expect(tester.takeException(), isNull);
    final approve = find.descendant(
      of: find.byType(ApprovalCard),
      matching: find.text('승인'),
    );
    await tester.ensureVisible(approve);
    await tester.pump();
    await tester.tap(approve);
    await settle(tester);
    expect(repo.decisions, hasLength(1));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
