import 'dart:convert';
import 'dart:typed_data';

import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/router/app_router.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/domain/follow_up.dart';
import 'package:callmate/features/calls/presentation/plan_card_screen.dart';
import 'package:callmate/features/calls/presentation/widgets/follow_up_actions.dart';
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

  const shareText1 = '[목표 달성] 라 파스타 통화 결과\n'
      '2026년 11월 21일 오후 7:05\n'
      '\n'
      '금요일 7시 2명 예약을 확정했어요.\n'
      '\n'
      '알아낸 내용\n'
      '• 7시 2명\n'
      '• 예약금 없음\n'
      '\n'
      '해야 할 일\n'
      '• 10분 전 도착';
  final generatedAt = DateTime.utc(2026, 11, 21, 10, 6);

  // AC-009 / REQ-009
  test('builds the share text (1)-(4)', () {
    final task = CallTask.fromJson(confirmedTask());

    // (1)
    expect(buildShareText(task, displayOffset: const Duration(hours: 9)), shareText1);

    // (2)
    final unverified = CallTask.fromJson({
      ...taskJson(
        status: 'completed',
        outcome: {
          'result': 'unverified',
          'source': 'heuristic',
          'summary': '자동 요약(검증되지 않음): 라 파스타과(와) 통화했습니다.',
          'keyFacts': <String>[],
          'followUps': <String>[],
        },
      ),
      'endedAt': '2026-11-21T10:05:00Z',
    });
    expect(
      buildShareText(unverified, displayOffset: const Duration(hours: 9)),
      '[결과 미확인] 라 파스타 통화 결과\n'
      '2026년 11월 21일 오후 7:05\n'
      '\n'
      '자동 요약(검증되지 않음): 라 파스타과(와) 통화했습니다.\n'
      '※ 자동 요약이라 목표를 이뤘는지 확인하지 못했어요.',
    );

    // (3) number, requester, transcript and approval comment never leave the device in the text
    final withPrivate = CallTask.fromJson({
      ...confirmedTask(),
      'approvals': [approvalJson(status: 'approved', userComment: '1만 원까지만')],
    });
    expect(withPrivate.requesterName, '김민수');
    expect(withPrivate.transcript.first.text, '네, 라 파스타입니다.');
    final text = buildShareText(withPrivate, displayOffset: const Duration(hours: 9));
    for (final secret in ['02-123-4567', '+8221234567', '김민수', '네, 라 파스타입니다.', '1만 원까지만']) {
      expect(text.contains(secret), isFalse, reason: secret);
    }

    // (4) the display offset is an argument; the default is +09:00
    expect(buildShareText(task, displayOffset: Duration.zero).split('\n')[1], '2026년 11월 21일 오전 10:05');
    expect(buildShareText(task), shareText1);
  });

  /// AC-006 table: status, outcome (null = none), expected buttons.
  final table = <({String status, Map<String, dynamic>? outcome, Set<String> buttons})>[
    (
      status: 'completed',
      outcome: {'result': 'success', 'source': 'llm', 'appointment': dinner},
      buttons: {'다시 걸기', '요약 복사', '공유', '캘린더 파일 보내기'},
    ),
    (
      status: 'completed',
      outcome: {'result': 'partial', 'source': 'llm', 'appointment': dinner},
      buttons: {'다시 걸기', '요약 복사', '공유', '캘린더 파일 보내기'},
    ),
    (status: 'completed', outcome: {'result': 'success', 'source': 'llm'}, buttons: {'다시 걸기', '요약 복사', '공유'}),
    (
      status: 'completed',
      outcome: {'result': 'unverified', 'source': 'heuristic', 'appointment': dinner},
      buttons: {'다시 걸기', '요약 복사', '공유'},
    ),
    (status: 'completed', outcome: {'result': 'success', 'appointment': dinner}, buttons: {'다시 걸기', '요약 복사', '공유'}),
    (
      status: 'failed',
      outcome: {'result': 'failed', 'source': 'llm', 'appointment': dinner},
      buttons: {'다시 걸기', '요약 복사', '공유'},
    ),
    (status: 'failed', outcome: null, buttons: {'다시 걸기'}),
    (status: 'canceled', outcome: null, buttons: {'다시 걸기'}),
  ];
  const allButtons = ['다시 걸기', '요약 복사', '공유', '캘린더 파일 보내기'];

  Map<String, dynamic> rowTask(({String status, Map<String, dynamic>? outcome, Set<String> buttons}) row) => {
        ...taskJson(
          status: row.status,
          outcome: row.outcome == null
              ? null
              : {'summary': '요약', 'keyFacts': <String>[], 'followUps': <String>[], ...row.outcome!},
        ),
        'endedAt': '2026-11-21T10:05:00Z',
      };

  // AC-010 / REQ-010
  test('offers a calendar draft only for confirmed LLM outcomes', () {
    final offered = [for (final row in table) offersCalendarDraft(CallTask.fromJson(rowTask(row)).outcome)];
    expect(offered, [true, true, false, false, false, false, false, false]);
  });

  // AC-011 / REQ-011
  test('builds an RFC 5545 calendar draft (1)-(6)', () {
    final task = CallTask.fromJson(confirmedTask());
    final ics = buildCalendarDraft(task, now: generatedAt);

    // (1) unfolded content lines, in order
    final lines = ics.replaceAll('\r\n ', '').split('\r\n');
    expect(lines.last, '');
    expect(lines.sublist(0, lines.length - 1), [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//CallMate//Follow-up//KO',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:task-1-appointment@callmate.local',
      'DTSTAMP:20261121T100600Z',
      'DTSTART:20261127T100000Z',
      'DTEND:20261127T110000Z',
      'SUMMARY:라 파스타 저녁 예약',
      r'DESCRIPTION:금요일 7시 2명 예약을 확정했어요.\n\nAI 비서가 통화에서 확인한 내용으로 만든 초안이에요. 저장하기 전에 확인해 주세요.',
      'END:VEVENT',
      'END:VCALENDAR',
    ]);

    // (2) CRLF only
    expect(ics.replaceAll('\r\n', '').contains('\n'), isFalse);
    expect(ics.endsWith('\r\n'), isTrue);

    // (3) folded at 75 octets without splitting a UTF-8 character
    final physical = ics.split('\r\n')..removeLast();
    expect(physical.length, greaterThan(lines.length - 1), reason: 'DESCRIPTION must be folded');
    for (final (i, line) in physical.indexed) {
      final bytes = utf8.encode(line);
      expect(bytes.length, lessThanOrEqualTo(75), reason: line);
      expect(utf8.decode(bytes), line);
      if (i > 0 && !RegExp(r'^[A-Z]').hasMatch(line)) expect(line.startsWith(' '), isTrue, reason: line);
    }

    // (4) TEXT escaping
    CallTask withAppointment(Map<String, dynamic> appointment) => CallTask.fromJson({
          ...confirmedTask(),
          'outcome': {...confirmedTask()['outcome'] as Map<String, dynamic>, 'appointment': appointment},
        });
    final escaped = buildCalendarDraft(
      withAppointment({'title': r'A;B,C\D', 'startsAt': '2026-11-27T19:00:00+09:00'}),
      now: generatedAt,
    );
    expect(escaped.split('\r\n'), contains(r'SUMMARY:A\;B\,C\\D'));

    // (5) explicit end
    final ended = buildCalendarDraft(
      withAppointment({...dinner, 'endsAt': '2026-11-27T21:30:00+09:00'}),
      now: generatedAt,
    );
    expect(ended.split('\r\n'), contains('DTEND:20261127T123000Z'));

    // (6) no people, no numbers
    for (final banned in ['ATTENDEE', 'ORGANIZER', '+82', '02-']) {
      expect(ics.contains(banned), isFalse, reason: banned);
    }

    // AC-005 (5): an untitled appointment falls back to "<상대 이름> 일정"
    final untitled = buildCalendarDraft(withAppointment({'startsAt': '2026-11-27T19:00:00+09:00'}), now: generatedAt);
    expect(untitled.split('\r\n'), contains('SUMMARY:라 파스타 일정'));
  });

  Future<FakeFollowUpService> pumpWithService(WidgetTester tester, Map<String, dynamic> task) async {
    final service = FakeFollowUpService();
    await pumpDetail(
      tester,
      task,
      overrides: [
        followUpServiceProvider.overrideWithValue(service),
        followUpClockProvider.overrideWithValue(() => generatedAt),
      ],
    );
    return service;
  }

  // AC-006 / REQ-006, REQ-010
  testWidgets('shows follow-up actions that match the outcome', (tester) async {
    for (final (i, row) in table.indexed) {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpDetail(tester, rowTask(row));
      for (final label in allButtons) {
        expect(find.text(label), row.buttons.contains(label) ? findsOneWidget : findsNothing, reason: '#${i + 1} $label');
      }
    }
  });

  // AC-008 / REQ-008
  testWidgets('copies and shares the summary', (tester) async {
    final service = await pumpWithService(tester, confirmedTask());

    await tapAndSettle(tester, find.text('요약 복사'));
    expect(service.copied, [shareText1]);
    expect(find.text('요약을 복사했어요'), findsOneWidget);

    await tapAndSettle(tester, find.text('공유'));
    expect(service.sharedTexts, [shareText1]);

    service.failShare = true;
    await tapAndSettle(tester, find.text('공유'));
    expect(service.copied, [shareText1, shareText1]);
    expect(find.text('공유할 수 없어 복사했어요'), findsOneWidget);
  });

  // AC-012 / REQ-012
  testWidgets('shares the calendar draft as a file', (tester) async {
    final service = await pumpWithService(tester, confirmedTask());

    await tapAndSettle(tester, find.text('캘린더 파일 보내기'));
    expect(service.sharedFiles, hasLength(1));
    final file = service.sharedFiles.single;
    expect(file.name, 'appointment.ics');
    expect(file.mimeType, 'text/calendar');
    expect(file.content, buildCalendarDraft(CallTask.fromJson(confirmedTask()), now: generatedAt));

    service.failFileShare = true;
    await tapAndSettle(tester, find.text('캘린더 파일 보내기'));
    expect(find.text('캘린더 초안을 열 수 없어요'), findsOneWidget);
  });
}

/// Records follow-up calls instead of touching the clipboard or the share sheet.
class FakeFollowUpService implements FollowUpService {
  final copied = <String>[];
  final sharedTexts = <String>[];
  final sharedFiles = <({String name, String mimeType, String content})>[];
  bool failShare = false;
  bool failFileShare = false;

  @override
  Future<void> copyText(String text) async => copied.add(text);

  @override
  Future<void> shareText(String text) async {
    if (failShare) throw StateError('share unavailable');
    sharedTexts.add(text);
  }

  @override
  Future<void> shareFile({required Uint8List bytes, required String name, required String mimeType}) async {
    if (failFileShare) throw StateError('share unavailable');
    sharedFiles.add((name: name, mimeType: mimeType, content: utf8.decode(bytes)));
  }
}
