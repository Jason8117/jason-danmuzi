import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/network/api_client.dart';
import 'package:callmate/core/router/app_router.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/presentation/call_templates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

// SPEC-INTAKE-001 AC-017, AC-018, AC-022, AC-024 (manual form). Elements are found by text, Key or type only.
void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  const field = Key('home-intake-field');
  const send = Key('home-intake-send');

  Future<FakeCallsRepository> pumpHome(WidgetTester tester, List<CallTask> tasks, {String requesterName = '김민수'}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({if (requesterName.isNotEmpty) 'requesterName': requesterName});
    final prefs = await SharedPreferences.getInstance();
    final repo = FakeCallsRepository(tasks);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          callsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const CallMateApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // SPEC-ASSIST-001 REQ-010: requests start in the AI assistant's text mode, not on today.
    ProviderScope.containerOf(tester.element(find.byType(CallMateApp))).read(routerProvider).push('/assistant?mode=text');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return repo;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  bool sendEnabled(WidgetTester tester) => tester.widget<IconButton>(find.byKey(send)).onPressed != null;
  TextEditingController input(WidgetTester tester) => tester.widget<TextField>(find.byKey(field)).controller!;

  /// A finished (or live) call, as the server would list it.
  CallTask call(String id, String name, String phone, String day, {String status = 'completed', bool connected = true}) {
    final at = DateTime.utc(2026, 11, int.parse(day), 10).toIso8601String();
    return CallTask.fromJson({
      ...taskJson(id: id, status: status),
      'targetName': name,
      'phoneNumber': phone,
      'createdAt': at,
      'updatedAt': at,
      'connectedAt': connected ? at : null,
    });
  }

  // AC-017 / REQ-017
  testWidgets('home sends one line to intake', (tester) async {
    final repo = await pumpHome(tester, []);

    expect(find.text('무엇을 도와드릴까요?'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('전화 맡기기'), findsNothing);
    expect(find.text('직접 입력하기'), findsOneWidget);

    await tester.enterText(find.byKey(field), '가');
    await tester.pump();
    expect(sendEnabled(tester), isFalse);
    await tester.enterText(find.byKey(field), '예약');
    await tester.pump();
    expect(sendEnabled(tester), isTrue);

    await tester.enterText(find.byKey(field), '라 파스타에 전화해서 7시 예약');
    await tester.pump();
    await tapAndSettle(tester, find.byKey(send));

    expect(repo.intakeCalls, ['라 파스타에 전화해서 7시 예약']);
    expect(find.text('이렇게 걸어 볼게요'), findsOneWidget);
  });

  testWidgets('home sends one line to intake: without a name it opens settings first', (tester) async {
    final repo = await pumpHome(tester, [], requesterName: '');

    await tester.enterText(find.byKey(field), '라 파스타에 전화해서 7시 예약');
    await tester.pump();
    await tapAndSettle(tester, find.byKey(send));

    expect(find.text('설정'), findsOneWidget);
    expect(repo.intakeCalls, isEmpty);

    await tapAndSettle(tester, find.byType(BackButton));
    expect(input(tester).text, '라 파스타에 전화해서 7시 예약');
  });

  testWidgets('home sends one line to intake: the manual form stays reachable', (tester) async {
    await pumpHome(tester, []);

    await tapAndSettle(tester, find.text('직접 입력하기'));

    expect(find.text('통화 계획 만들기'), findsOneWidget);
  });

  // AC-018 / REQ-018
  testWidgets('suggests recent counterparties and templates', (tester) async {
    await pumpHome(tester, [
      call('a', '라 파스타', '+8221234567', '01'),
      call('b', '라파스타', '+8221234567', '10'),
      call('c', '미용실', '+82311112222', '05'),
      call('d', '세탁소', '+82311113333', '12', connected: false),
      call('e', '치과', '+82311114444', '03'),
      call('f', '빵집', '+82311115555', '02'),
      call('g', '피자집', '+82311116666', '20', status: 'in_progress'),
    ]);

    expect(find.text('최근 장소'), findsOneWidget);
    final suggestions = find.textContaining('번 통화');
    expect(suggestions, findsNWidgets(3));
    final first = find.text('라파스타 · 02-123-4567 · 2번 통화');
    final second = find.text('미용실 · 031-111-2222 · 1번 통화');
    final third = find.text('치과 · 031-111-4444 · 1번 통화');
    for (final suggestion in [first, second, third]) {
      expect(suggestion, findsOneWidget);
    }
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(tester.getTopLeft(second).dy, lessThan(tester.getTopLeft(third).dy));
    expect(find.textContaining('세탁소 ·'), findsNothing);
    expect(find.textContaining('빵집 ·'), findsNothing);
    expect(find.textContaining('피자집 ·'), findsNothing);

    await tapAndSettle(tester, first);
    expect(input(tester).text, '라파스타에 ');
    expect(input(tester).selection, const TextSelection.collapsed(offset: 6));

    await tapAndSettle(tester, find.text('식당 예약'));
    expect(input(tester).text, callTemplates.first.goal);
  });

  testWidgets('suggests recent counterparties and templates: no tasks yet', (tester) async {
    await pumpHome(tester, []);

    expect(find.text('식당 예약'), findsOneWidget);
    expect(find.text('최근 장소'), findsNothing);

    await tapAndSettle(tester, find.text('식당 예약'));

    expect(input(tester).text, callTemplates.first.goal);
    expect(find.text('통화 계획 만들기'), findsNothing);
  });

  // AC-022 / REQ-022
  testWidgets('falls back to a blank plan card on older servers', (tester) async {
    final repo = await pumpHome(tester, []);
    repo.intakeError = const ApiException('http_404', '요청을 처리하지 못했어요.', statusCode: 404);

    await tester.enterText(find.byKey(field), '라 파스타 7시 예약');
    await tester.pump();
    await tapAndSettle(tester, find.byKey(send));

    expect(find.text('이렇게 걸어 볼게요'), findsOneWidget);
    expect(find.byKey(const Key('plan-goal-field')), findsNothing);
    expect(find.text('라 파스타 7시 예약'), findsOneWidget);
    expect(find.byKey(const Key('plan-phone-field')), findsOneWidget);
    expect(find.byKey(const Key('plan-target-field')), findsOneWidget);
    expect(find.text('AI 없이 간단히 정리했어요. 내용을 확인해 주세요.'), findsOneWidget);
  });

  testWidgets('falls back to a blank plan card on older servers: other errors stay home', (tester) async {
    final repo = await pumpHome(tester, []);
    repo.intakeError = const ApiException('shutting_down', '서버가 종료 중입니다. 잠시 후 다시 시도해 주세요.', statusCode: 503);

    await tester.enterText(find.byKey(field), '라 파스타 7시 예약');
    await tester.pump();
    await tapAndSettle(tester, find.byKey(send));

    expect(find.text('서버가 종료 중입니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('이렇게 걸어 볼게요'), findsNothing);
    expect(input(tester).text, '라 파스타 7시 예약');
  });

  // AC-024 / REQ-024
  testWidgets('the manual form never auto-starts', (tester) async {
    final repo = await pumpHome(tester, []);
    repo.nextCreated = CallTask.fromJson(taskJson(id: 'task-7', status: 'planning'));

    await tapAndSettle(tester, find.text('직접 입력하기'));
    await tester.enterText(find.widgetWithText(TextFormField, '어디에 전화할까요?'), '라 파스타');
    await tester.enterText(find.widgetWithText(TextFormField, '전화번호'), '02-123-4567');
    await tester.enterText(find.widgetWithText(TextFormField, '무엇을 해결할까요?'), '금요일 7시 2명 예약');
    await tester.pump();
    await tapAndSettle(tester, find.text('통화 계획 만들기'));

    final sent = repo.createRequests.single.toJson();
    expect(sent['targetName'], '라 파스타');
    expect(sent.containsKey('autoStart'), isFalse);
  });
}
