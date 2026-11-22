import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/router/app_router.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/presentation/plan_card_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

// SPEC-FOLLOWUP-001 AC-006 .. AC-012. Elements are found by text, Key or type only,
// so SPEC-UX-001 can restyle the result screen without breaking these tests.
void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  const dinner = {'title': '라 파스타 저녁 예약', 'startsAt': '2026-11-27T19:00:00+09:00'};

  /// AC-006 #1: a completed task with a confirmed LLM appointment.
  Map<String, dynamic> confirmedTask() => {
        ...taskJson(
          status: 'completed',
          outcome: {
            'result': 'success',
            'source': 'llm',
            'summary': '금요일 7시 2명 예약을 확정했어요.',
            'keyFacts': ['7시 2명', '예약금 없음'],
            'followUps': ['10분 전 도착'],
            'appointment': dinner,
          },
        ),
        'endedAt': '2026-11-21T10:05:00Z',
      };

  Future<(FakeCallsRepository, ProviderContainer)> pumpDetail(
    WidgetTester tester,
    Map<String, dynamic> task, {
    bool acknowledged = true,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'requesterName': '김민수', if (acknowledged) 'trustNoticeAcknowledged': true});
    final prefs = await SharedPreferences.getInstance();
    final repo = FakeCallsRepository([CallTask.fromJson(task)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          callsRepositoryProvider.overrideWithValue(repo),
          ...overrides,
        ],
        child: const CallMateApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final container = ProviderScope.containerOf(tester.element(find.byType(CallMateApp)));
    container.read(routerProvider).push('/calls/${task['id']}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return (repo, container);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // AC-007 / REQ-007
  testWidgets('call again opens a filled plan card', (tester) async {
    final (repo, _) = await pumpDetail(tester, confirmedTask());
    repo.nextCreated = CallTask.fromJson(taskJson(id: 'task-2', status: 'planning'));

    await tapAndSettle(tester, find.text('다시 걸기'));

    // The detail route may still be onstage while the push transition runs, so look inside the plan card only.
    Finder inPlan(String text) => find.descendant(of: find.byType(PlanCardScreen), matching: find.text(text));
    expect(inPlan('이렇게 걸어 볼게요'), findsOneWidget);
    expect(find.text('통화 계획 만들기'), findsNothing);
    expect(inPlan('라 파스타'), findsOneWidget);
    expect(inPlan('02-123-4567'), findsOneWidget);
    expect(inPlan('지난번과 같은 번호'), findsOneWidget);
    expect(inPlan('금요일 저녁 7시 2명 예약'), findsOneWidget);
    expect(repo.intakeCalls, isEmpty);

    await tapAndSettle(tester, find.byKey(const Key('plan-start')));

    expect(repo.intakeCalls, isEmpty);
    expect(repo.createRequests, hasLength(1));
    final request = repo.createRequests.single;
    expect(request.targetName, '라 파스타');
    expect(request.phoneNumber, '+8221234567');
    expect(request.goal, '금요일 저녁 7시 2명 예약');
    expect(request.language, CallLanguage.ko);
    expect(request.autoStart, isTrue);
  });
}
