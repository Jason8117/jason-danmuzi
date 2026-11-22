import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/router/app_router.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/domain/intake_models.dart';
import 'package:callmate/features/calls/presentation/plan_card_screen.dart';
import 'package:callmate/features/calls/presentation/trust_notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

/// Records plan approvals instead of calling the server (AC-014 (5)).
class _ApprovingRepository extends FakeCallsRepository {
  _ApprovingRepository(super.tasks);

  final approvedPlans = <String>[];

  @override
  Future<CallTask> approvePlan(String id, {String? openingLine}) async {
    approvedPlans.add(id);
    return CallTask.fromJson(taskJson(id: id, status: 'dialing'));
  }
}

// SPEC-FOLLOWUP-001 AC-013 .. AC-015. Elements are found by text, Key or type only.
void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  // REQ-013, verbatim (OD-3 DEFAULT).
  const agreedSix = [
    'AI 비서는 통화를 시작할 때 AI라고 먼저 밝히도록 정해져 있어요.',
    '결제·약정처럼 중요한 결정은 통화 중에 먼저 물어보도록 정해져 있어요.',
    '대화 내용은 글로 기록되어 서버에 저장돼요. 끝난 통화는 상세 화면에서 지울 수 있어요.',
    '통화 음성은 이 앱의 서버에 저장하지 않아요. 실제 통화에서는 음성이 통신 서비스(KAT)와 OpenAI를 거쳐 처리돼요.',
    '카드번호·비밀번호 같은 정보는 상대에게 말하지 않도록 정해져 있어요.',
    '서버에 OpenAI가 연결되어 있으면, 부탁 정리·통화 계획·결과 요약을 위해 부탁 내용, 내 이름, 상대에게 알려도 된다고 한 정보, '
        '승인 코멘트, 대화 글이 OpenAI로 전송돼요. 실제 통화에서는 회신 번호도 통화 지시문에 담겨 OpenAI로 전송돼요.',
  ];
  const liveLine = 'AI 비서는 AI임을 밝히도록 정해져 있어요 · 대화는 글로 기록돼요';
  const draft = PlanDraft(
    targetName: '라 파스타',
    phoneNumber: '+8221234567',
    goal: '금요일 7시 2명 예약',
    phoneSource: PhoneSource.history,
  );

  Future<ProviderContainer> pumpApp(
    WidgetTester tester,
    FakeCallsRepository repo, {
    Map<String, Object>? initialPrefs,
    String? location,
    Object? extra,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (initialPrefs != null) SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          callsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const CallMateApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final container = ProviderScope.containerOf(tester.element(find.byType(CallMateApp)));
    if (location != null) {
      container.read(routerProvider).push(location, extra: extra);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    return container;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void expectNoticeShown() {
    for (final statement in agreedSix) {
      expect(find.text(statement), findsOneWidget, reason: statement);
    }
    expect(find.text('확인했어요'), findsOneWidget);
  }

  // AC-013 / REQ-013
  test('trust statements are exactly the agreed six', () {
    expect(trustStatements, agreedSix);
    for (final i in [0, 1, 4]) {
      expect(trustStatements[i].endsWith('정해져 있어요.'), isTrue, reason: trustStatements[i]);
    }
  });

  // AC-014 / REQ-014
  testWidgets('asks for the trust notice once before the first call (1)-(4)', (tester) async {
    final repo = FakeCallsRepository([])..nextCreated = CallTask.fromJson(taskJson(id: 'task-2', status: 'planning'));
    await pumpApp(tester, repo, initialPrefs: {'requesterName': '김민수'}, location: '/plan', extra: draft);

    // (1) the first start shows the notice and sends nothing
    await tapAndSettle(tester, find.byKey(const Key('plan-start')));
    expectNoticeShown();
    expect(repo.createRequests, isEmpty);

    // (2) tapping outside closes it; the plan card stays and nothing is sent
    await tester.tapAt(const Offset(400, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('확인했어요'), findsNothing);
    expect(find.byType(PlanCardScreen), findsOneWidget);
    expect(repo.createRequests, isEmpty);

    // (3) the notice comes back; confirming sends the request and opens the detail screen
    await tapAndSettle(tester, find.byKey(const Key('plan-start')));
    expectNoticeShown();
    await tapAndSettle(tester, find.text('확인했어요'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.createRequests, hasLength(1));
    expect(find.byType(PlanCardScreen), findsNothing);

    // (4) a restarted app (same device storage) starts without the notice
    final again = FakeCallsRepository([])..nextCreated = CallTask.fromJson(taskJson(id: 'task-3', status: 'planning'));
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester, again, location: '/plan', extra: draft);
    await tapAndSettle(tester, find.byKey(const Key('plan-start')));
    expect(find.text('확인했어요'), findsNothing);
    expect(again.createRequests, hasLength(1));
  });

  testWidgets('asks for the trust notice once before the first call (5) on the plan review', (tester) async {
    final repo = _ApprovingRepository([CallTask.fromJson(taskJson(status: 'awaiting_approval'))]);
    await pumpApp(tester, repo, initialPrefs: {'requesterName': '김민수'}, location: '/calls/task-1');

    await tapAndSettle(tester, find.text('이대로 전화 걸기'));
    expectNoticeShown();
    expect(repo.approvedPlans, isEmpty);

    await tapAndSettle(tester, find.text('확인했어요'));
    expect(repo.approvedPlans, ['task-1']);
  });

  // AC-015 / REQ-015
  testWidgets('shows trust statements in settings and during calls', (tester) async {
    final repo = FakeCallsRepository([
      CallTask.fromJson(taskJson(id: 'live', status: 'in_progress')),
      CallTask.fromJson(taskJson(id: 'done', status: 'completed')),
    ]);
    final container = await pumpApp(
      tester,
      repo,
      initialPrefs: {'requesterName': '김민수', 'trustNoticeAcknowledged': true},
      location: '/settings',
    );

    // (1) settings
    expect(find.text('AI 비서와 기록'), findsOneWidget);
    for (final statement in agreedSix) {
      await tester.ensureVisible(find.text(statement));
      expect(find.text(statement), findsOneWidget, reason: statement);
    }

    // (2) a live call shows the one line
    final router = container.read(routerProvider);
    router.go('/calls/live');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(liveLine), findsOneWidget);

    // (3) a finished call does not
    router.go('/calls/done');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(liveLine), findsNothing);

    // (4) the manual form states instructions, not guarantees
    router.go('/calls/new');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final paragraph = find.textContaining('정해져 있어요');
    expect(paragraph, findsOneWidget);
    for (final old in ['AI임을 밝혀요.', '꼭 먼저 물어봐요', '절대 말하지 않아요']) {
      expect(find.textContaining(old), findsNothing, reason: old);
    }
  });
}
