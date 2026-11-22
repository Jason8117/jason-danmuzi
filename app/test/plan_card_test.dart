import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/network/api_client.dart';
import 'package:callmate/core/router/app_router.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/domain/intake_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

// SPEC-INTAKE-001 AC-019 .. AC-021, AC-023. Elements are found by text, Key or type only,
// so SPEC-UX-001 can restyle the plan card without breaking these tests.
void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  const phoneField = Key('plan-phone-field');
  const targetField = Key('plan-target-field');
  const goalField = Key('plan-goal-field');
  const startButton = Key('plan-start');

  /// The AC-019 draft, parsed from an intake response like the server sends it.
  PlanDraft draft({
    String? targetName = '라 파스타',
    String? phoneNumber = '+8221234567',
    String? phoneSource = 'history',
    String? numberIssue,
    String source = 'heuristic',
    List<String> missing = const [],
  }) =>
      IntakeResult.fromJson({
        'draft': {
          'targetName': targetName,
          'phoneNumber': phoneNumber,
          'goal': '금요일 7시 2명 예약',
          'conditions': ['8시도 괜찮음'],
          'context': '회원번호 1234',
          'language': 'ko',
        },
        'missing': missing,
        'phoneSource': phoneSource,
        'numberIssue': numberIssue,
        'source': source,
      }).draft;

  Future<(FakeCallsRepository, ProviderContainer)> pumpAppAt(
    WidgetTester tester,
    String location, {
    Object? extra,
    List<CallTask> tasks = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'requesterName': '김민수'});
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
    final container = ProviderScope.containerOf(tester.element(find.byType(CallMateApp)));
    container.read(routerProvider).push(location, extra: extra);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return (repo, container);
  }

  Future<FakeCallsRepository> openPlanCard(WidgetTester tester, PlanDraft draft) async =>
      (await pumpAppAt(tester, '/plan', extra: draft)).$1;

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  bool startEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(startButton)).onPressed != null;

  // AC-019 / REQ-019
  testWidgets('shows the draft and edits rows in place', (tester) async {
    await openPlanCard(tester, draft());

    expect(find.text('이렇게 걸어 볼게요'), findsOneWidget);
    for (final text in [
      '라 파스타',
      '02-123-4567',
      '지난번 통화한 번호',
      '금요일 7시 2명 예약',
      '8시도 괜찮음',
      '회원번호 1234',
      '한국어',
      '김민수',
      'AI 없이 간단히 정리했어요. 내용을 확인해 주세요.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

    await tapAndSettle(tester, find.text('금요일 7시 2명 예약'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('이렇게 걸어 볼게요'), findsOneWidget);
    await tester.enterText(find.byKey(goalField), '토요일 7시 2명 예약');
    await tester.pump();

    await tapAndSettle(tester, find.byTooltip('조건 삭제'));
    await tapAndSettle(tester, find.text('한국어'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('토요일 7시 2명 예약'), findsOneWidget);
    expect(find.text('8시도 괜찮음'), findsNothing);
    expect(find.byType(InputChip), findsNothing);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('shows the draft and edits rows in place: a number from the text, interpreted by the LLM', (tester) async {
    await openPlanCard(tester, draft(phoneSource: 'text', source: 'llm'));

    expect(find.text('말씀하신 번호'), findsOneWidget);
    expect(find.text('지난번 통화한 번호'), findsNothing);
    expect(find.text('AI 없이 간단히 정리했어요. 내용을 확인해 주세요.'), findsNothing);
  });

  // AC-020 / REQ-020
  testWidgets('asks for the number once', (tester) async {
    await openPlanCard(tester, draft(phoneNumber: null, phoneSource: null, missing: ['phoneNumber']));

    expect(tester.getTopLeft(find.byKey(phoneField)).dy, lessThan(tester.getTopLeft(find.text('전화할 곳')).dy));
    final editable = tester.widget<EditableText>(find.descendant(of: find.byKey(phoneField), matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(tester.widget<TextField>(find.byKey(phoneField)).keyboardType, TextInputType.phone);
    expect(find.text('번호만 알려 주시면 바로 걸게요.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('asks for the number once: a blocked number in the request', (tester) async {
    await openPlanCard(
      tester,
      draft(phoneNumber: null, phoneSource: null, numberIssue: 'blocked', missing: ['phoneNumber']),
    );

    expect(find.text('긴급·특수번호에는 걸 수 없어요. 다른 번호를 알려 주세요.'), findsOneWidget);
    expect(find.text('번호만 알려 주시면 바로 걸게요.'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('asks for the number once: no name either', (tester) async {
    await openPlanCard(
      tester,
      draft(targetName: null, phoneNumber: null, phoneSource: null, missing: ['targetName', 'phoneNumber']),
    );

    expect(find.byKey(targetField), findsOneWidget);
    expect(tester.widget(find.byKey(targetField)), isA<TextField>());
    expect(find.byKey(phoneField), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  // AC-021 / REQ-021
  testWidgets('starts the call with one tap (1) sends autoStart and opens the call', (tester) async {
    final (repo, _) = await pumpAppAt(tester, '/plan', extra: draft());
    repo.nextCreated = CallTask.fromJson(taskJson(id: 'task-9', status: 'planning'));

    await tapAndSettle(tester, find.byKey(startButton));
    // One more frame so the replaced page's exit transition has finished.
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.createRequests.single.toJson(), {
      'targetName': '라 파스타',
      'phoneNumber': '+8221234567',
      'goal': '금요일 7시 2명 예약\n조건: 8시도 괜찮음',
      'context': '회원번호 1234',
      'language': 'ko',
      'requesterName': '김민수',
      'autoStart': true,
    });
    expect(find.text('어떻게 통화할지 계획을 세우고 있어요…'), findsOneWidget);
    expect(find.text('이렇게 걸어 볼게요'), findsNothing);

    // pageBack() looks for the English "Back" tooltip; the app runs in Korean.
    await tapAndSettle(tester, find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('CallMate'), findsOneWidget);
  });

  testWidgets('starts the call with one tap (2) needs 8 digits', (tester) async {
    await openPlanCard(tester, draft());
    expect(startEnabled(tester), isTrue);

    await tapAndSettle(tester, find.text('02-123-4567'));
    await tester.enterText(find.byKey(phoneField), '0212');
    await tester.pump();

    expect(startEnabled(tester), isFalse);
  });

  testWidgets('starts the call with one tap (3) needs a 5-character goal', (tester) async {
    await openPlanCard(tester, draft());

    await tapAndSettle(tester, find.text('금요일 7시 2명 예약'));
    await tester.enterText(find.byKey(goalField), '예약');
    await tester.pump();

    expect(startEnabled(tester), isFalse);
  });

  testWidgets('starts the call with one tap (4) caps the goal with conditions at 1000', (tester) async {
    await openPlanCard(tester, draft());

    // '\n조건: 8시도 괜찮음' is 12 UTF-16 units, so 989 + 12 = 1001.
    await tapAndSettle(tester, find.text('금요일 7시 2명 예약'));
    await tester.enterText(find.byKey(goalField), '가' * 989);
    await tester.pump();

    expect(startEnabled(tester), isFalse);
    expect(find.text('부탁할 일이 너무 길어요.'), findsOneWidget);

    await tester.enterText(find.byKey(goalField), '가' * 988);
    await tester.pump();
    expect(startEnabled(tester), isTrue);
    expect(find.text('부탁할 일이 너무 길어요.'), findsNothing);
  });

  testWidgets('starts the call with one tap (5) shows a number error under the number', (tester) async {
    final repo = await openPlanCard(tester, draft());
    repo.createError = const ApiException('blocked_number', '긴급·특수번호에는 전화할 수 없습니다.', statusCode: 400);

    await tapAndSettle(tester, find.byKey(startButton));

    expect(find.text('이렇게 걸어 볼게요'), findsOneWidget);
    expect(find.text('긴급·특수번호에는 전화할 수 없습니다.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester.getTopLeft(find.text('긴급·특수번호에는 전화할 수 없습니다.')).dy,
      greaterThan(tester.getTopLeft(find.byKey(phoneField)).dy),
    );
  });

  testWidgets('starts the call with one tap (6) reports other errors in a snackbar', (tester) async {
    final repo = await openPlanCard(tester, draft());
    repo.createError = const ApiException('network', 'Request timed out');

    await tapAndSettle(tester, find.byKey(startButton));

    expect(find.text('서버에 연결할 수 없어요. 설정에서 서버 주소를 확인해 주세요.'), findsOneWidget);
    expect(find.text('이렇게 걸어 볼게요'), findsOneWidget);
  });

  // AC-023 / REQ-023
  Map<String, dynamic> awaiting([Object? blocked]) => {
        ...taskJson(status: 'awaiting_approval'),
        'autoStartBlocked': ?blocked,
      };

  testWidgets('explains a blocked auto start on the detail screen (1) a known code', (tester) async {
    final task = CallTask.fromJson(awaiting({'code': 'too_many_active_calls', 'message': 'Too many calls are in progress'}));
    await pumpAppAt(tester, '/calls/task-1', tasks: [task]);

    expect(find.text('바로 걸지 못했어요: 이미 진행 중인 통화가 있어요. 끝난 뒤 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('이대로 전화 걸기'), findsOneWidget);
  });

  testWidgets('explains a blocked auto start on the detail screen (2) the server message', (tester) async {
    final task = CallTask.fromJson(awaiting({'code': 'auto_start_failed', 'message': '자동으로 통화를 시작하지 못했어요.'}));
    await pumpAppAt(tester, '/calls/task-1', tasks: [task]);

    expect(find.text('바로 걸지 못했어요: 자동으로 통화를 시작하지 못했어요.'), findsOneWidget);
  });

  testWidgets('explains a blocked auto start on the detail screen (3) nothing to explain', (tester) async {
    await pumpAppAt(tester, '/calls/task-1', tasks: [CallTask.fromJson(awaiting())]);

    expect(find.textContaining('바로 걸지 못했어요'), findsNothing);
    expect(find.text('이대로 전화 걸기'), findsOneWidget);
  });
}
