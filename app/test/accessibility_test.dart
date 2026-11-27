import 'dart:async';
import 'dart:io';

import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/router/app_router.dart';
import 'package:callmate/core/theme/app_theme.dart';
import 'package:callmate/core/widgets/common.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/domain/intake_models.dart';
import 'package:callmate/features/calls/presentation/plan_card_screen.dart';
import 'package:callmate/features/calls/presentation/widgets/approval_card.dart';
import 'package:callmate/features/calls/presentation/widgets/outcome_card.dart';
import 'package:callmate/shell/navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/shell_support.dart' as shell;

// SPEC-UX-001 AC-004, AC-006 (scroll), AC-007 .. AC-013. Elements are found by text, Key, type or semantics only.
void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  // ---- the four screens -------------------------------------------------------------------------------------

  Map<String, dynamic> finished(String id, String name, String phone) => {
    ...taskJson(
      id: id,
      status: 'completed',
      outcome: {'result': 'success', 'source': 'llm', 'summary': '$name 통화를 마쳤어요.', 'keyFacts': [], 'followUps': []},
    ),
    'targetName': name,
    'phoneNumber': phone,
  };

  /// (H) one live call and two finished ones, so two recent places show.
  List<CallTask> homeTasks() => [
    CallTask.fromJson(taskJson(id: 'live-1')),
    CallTask.fromJson(finished('done-1', '미용실', '+82311112222')),
    CallTask.fromJson(finished('done-2', '치과', '+82311114444')),
  ];

  PlanDraft draft({String? phoneNumber = '+8221234567'}) => IntakeResult.fromJson({
    'draft': {
      'targetName': '라 파스타',
      'phoneNumber': phoneNumber,
      'goal': '금요일 7시 2명 예약',
      'conditions': ['8시도 괜찮음'],
      'context': '회원번호 1234',
      'language': 'ko',
    },
    'missing': phoneNumber == null ? ['phoneNumber'] : <String>[],
    'phoneSource': phoneNumber == null ? null : 'history',
    'source': 'heuristic',
  }).draft;

  /// (A) a live call waiting for a decision.
  Map<String, dynamic> approvalTask() => taskJson(approvals: [approvalJson()]);

  /// (R) a confirmed result with an appointment, so all four follow-up actions show.
  Map<String, dynamic> resultTask() => {
    ...taskJson(
      status: 'completed',
      approvals: [approvalJson(status: 'approved', userComment: '1만 원까지만')],
      outcome: {
        'result': 'success',
        'source': 'llm',
        'summary': '금요일 7시 2명 예약을 확정했어요.',
        'keyFacts': ['7시 2명', '예약금 없음'],
        'followUps': ['10분 전 도착'],
        'appointment': {'title': '라 파스타 저녁 예약', 'startsAt': '2026-11-27T19:00:00+09:00'},
      },
    ),
    'endedAt': '2026-11-21T10:05:00Z',
  };

  Future<FakeCallsRepository> pumpAt(
    WidgetTester tester, {
    String? location,
    Object? extra,
    List<CallTask> tasks = const [],
    Size size = const Size(800, 1400),
    bool dark = false,
    double textScale = 1,
    bool reduceMotion = false,
    void Function(FakeCallsRepository repo)? setup,
  }) async {
    // A fresh ProviderScope per screen: never carry the previous screen's container or route.
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
    }
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({'requesterName': '김민수', 'trustNoticeAcknowledged': true});
    final prefs = await SharedPreferences.getInstance();
    final repo = FakeCallsRepository(tasks);
    setup?.call(repo);
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
    if (location != null) {
      ProviderScope.containerOf(tester.element(find.byType(CallMateApp)))
          .read(routerProvider)
          .push(location, extra: extra);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    return repo;
  }

  /// Every screen variant the guideline checks run on.
  final screens = <String, Future<void> Function(WidgetTester, {bool dark})>{
    'home': (t, {dark = false}) => pumpAt(t, tasks: homeTasks(), dark: dark),
    'plan without number': (t, {dark = false}) =>
        pumpAt(t, location: '/plan', extra: draft(phoneNumber: null), dark: dark),
    'plan with every row': (t, {dark = false}) => pumpAt(t, location: '/plan', extra: draft(), dark: dark),
    'approval': (t, {dark = false}) =>
        pumpAt(t, location: '/calls/task-1', tasks: [CallTask.fromJson(approvalTask())], dark: dark),
    'result': (t, {dark = false}) =>
        pumpAt(t, location: '/calls/task-1', tasks: [CallTask.fromJson(resultTask())], dark: dark),
  };

  // ---- AC-004 -------------------------------------------------------------------------------------------------

  testWidgets('cards share one component and tone', (tester) async {
    await screens['plan with every row']!(tester);
    expect(find.descendant(of: find.byType(PlanCardScreen), matching: find.byType(AppCard)), findsWidgets);

    await screens['approval']!(tester);
    final approvalCard = find.descendant(of: find.byType(ApprovalCard), matching: find.byType(AppCard));
    expect(approvalCard, findsOneWidget);
    expect(tester.widget<AppCard>(approvalCard).tone, CardTone.attention);

    await screens['result']!(tester);
    expect(find.descendant(of: find.byType(OutcomeCard), matching: find.byType(AppCard)), findsOneWidget);

    final cases = <Map<String, dynamic>, CardTone>{
      taskJson(status: 'completed', outcome: {'result': 'success', 'source': 'llm', 'summary': 's'}): CardTone.positive,
      taskJson(status: 'completed', outcome: {'result': 'partial', 'source': 'llm', 'summary': 's'}): CardTone.caution,
      taskJson(status: 'completed', outcome: {'result': 'unverified', 'source': 'heuristic', 'summary': 's'}):
          CardTone.neutral,
      taskJson(status: 'failed', outcome: {'result': 'failed', 'source': 'llm', 'summary': 's'}): CardTone.critical,
      taskJson(status: 'canceled'): CardTone.neutral,
    };
    for (final MapEntry(key: json, value: tone) in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: OutcomeCard(task: CallTask.fromJson(json))),
        ),
      );
      final card = find.descendant(of: find.byType(OutcomeCard), matching: find.byType(AppCard));
      expect(tester.widget<AppCard>(card).tone, tone, reason: json['status'] as String);
    }

    // A SectionCard call with the old arguments still draws the shared card.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SectionCard(title: '제목', icon: Icons.info, trailing: Text('끝'), child: Text('본문')),
        ),
      ),
    );
    expect(find.byType(AppCard), findsOneWidget);
  });

  // ---- AC-006 (scroll) ----------------------------------------------------------------------------------------

  testWidgets('scrolls without animation when motion is reduced', (tester) async {
    Map<String, dynamic> withLines(String status, int version) => {
      ...taskJson(status: status, version: version),
      'transcript': [
        for (var i = 0; i < 22; i++)
          {
            'id': 'l$i',
            'speaker': i.isEven ? 'callee' : 'agent',
            'text': '대화 $i번째 줄',
            'at': DateTime.now().toUtc().toIso8601String(),
          },
      ],
    };
    ScrollPosition position() => tester
        .state<ScrollableState>(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first)
        .position;

    for (final reduce in [true, false]) {
      final repo = await pumpAt(
        tester,
        location: '/calls/task-1',
        tasks: [CallTask.fromJson(taskJson())],
        size: const Size(800, 600),
        reduceMotion: reduce,
      );
      repo.live.emit({'type': 'task.updated', 'task': withLines('in_progress', 2)});
      await tester.pump(); // delivers the live event
      await tester.pump(); // the frame that draws it and jumps
      // A lazily built list can grow once its last lines exist; the screen settles on the real end within a few frames.
      for (var i = 0; i < 3; i++) {
        await tester.pump(reduce ? Duration.zero : const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull);
      expect(position().maxScrollExtent, greaterThan(0));
      expect(position().pixels, position().maxScrollExtent, reason: 'follows the transcript (reduce=$reduce)');

      repo.live.emit({'type': 'task.updated', 'task': withLines('completed', 3)});
      await tester.pump();
      await tester.pump();
      if (!reduce) await tester.pump(const Duration(milliseconds: 450));
      expect(tester.takeException(), isNull);
      expect(position().pixels, 0, reason: 'back to the result (reduce=$reduce)');
      await tester.pumpWidget(const SizedBox());
    }
  });

  // ---- AC-007 -------------------------------------------------------------------------------------------------

  testWidgets('busy buttons show progress and success gives light haptics', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    void expectBusy(Finder button) {
      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
      expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    }

    // (1) [이대로 시작]
    final hold1 = Completer<void>();
    final repo1 = await pumpAt(
      tester,
      location: '/plan',
      extra: draft(),
      setup: (r) {
        r.hold = hold1;
        r.nextCreated = CallTask.fromJson(taskJson(id: 'task-9', status: 'planning'));
      },
    );
    await tester.tap(find.byKey(const Key('plan-start')));
    await tester.pump();
    expectBusy(find.byKey(const Key('plan-start')));
    hold1.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo1.createRequests, hasLength(1));
    expect(haptics.where((h) => h == 'HapticFeedbackType.lightImpact'), hasLength(1));

    // (2) 승인
    haptics.clear();
    final hold2 = Completer<void>();
    final repo2 = await pumpAt(
      tester,
      location: '/calls/task-1',
      tasks: [CallTask.fromJson(approvalTask())],
      setup: (r) => r.hold = hold2,
    );
    // The card's arrival vibration (plus the app-wide listener's, unchanged by this SPEC) happens before the tap.
    final heavyOnArrival = haptics.where((h) => h == 'HapticFeedbackType.heavyImpact').length;
    expect(heavyOnArrival, greaterThanOrEqualTo(1));
    final approve = find.widgetWithText(FilledButton, '승인');
    await tester.tap(approve);
    await tester.pump();
    final busyApprove = find.descendant(of: find.byType(ApprovalCard), matching: find.byType(FilledButton));
    expectBusy(busyApprove);
    hold2.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo2.decisions, hasLength(1));
    expect(haptics.where((h) => h == 'HapticFeedbackType.lightImpact'), hasLength(1));
    expect(haptics.where((h) => h == 'HapticFeedbackType.heavyImpact'), hasLength(heavyOnArrival));

    // (3) 이대로 전화 걸기
    final hold3 = Completer<void>();
    await pumpAt(
      tester,
      location: '/calls/task-1',
      tasks: [CallTask.fromJson(taskJson(status: 'awaiting_approval'))],
      setup: (r) => r.hold = hold3,
    );
    final dial = find.ancestor(
      of: find.text('이대로 전화 걸기'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    await tester.tap(dial);
    await tester.pump();
    expectBusy(dial);
    hold3.complete();
    await tester.pump(const Duration(milliseconds: 100));

    // (4) 연결 테스트, with a server that never answers
    final previous = HttpOverrides.current;
    HttpOverrides.global = _SilentServer();
    addTearDown(() => HttpOverrides.global = previous);
    await pumpAt(tester, location: '/settings');
    final test = find.ancestor(
      of: find.text('연결 테스트'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    await tester.ensureVisible(test);
    await tester.tap(test);
    await tester.pump();
    expectBusy(test);
    // Let the client's own timeout end the request so no timer outlives the test.
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpWidget(const SizedBox());
  });

  // ---- AC-008 -------------------------------------------------------------------------------------------------

  testWidgets('empty states share one widget and wording', (tester) async {
    void expectEmpty(String title, String message) {
      expect(find.byType(MessageView), findsOneWidget);
      expect(find.descendant(of: find.byType(MessageView), matching: find.text(title)), findsOneWidget);
      expect(find.descendant(of: find.byType(MessageView), matching: find.text(message)), findsOneWidget);
    }

    // (1) no tasks
    await pumpAt(tester);
    expectEmpty('귀찮은 전화, 대신 걸어드릴게요', '예약, 문의, 요금 할인, 환불 요청까지.\n목적만 알려주시면 AI 비서가 통화하고 결과를 정리해 드려요.');
    expect(find.descendant(of: find.byType(MessageView), matching: find.byType(ActionChip)), findsNothing);
    expect(find.text('식당 예약'), findsOneWidget);

    // (2) ringing, (3) in progress, both without transcript
    for (final (status, message) in [
      ('ringing', '상대방이 전화를 받으면 대화가 여기에 나타나요.'),
      ('in_progress', '대화가 시작되면 여기에 실시간으로 보여드려요.'),
    ]) {
      await pumpAt(
        tester,
        location: '/calls/task-1',
        tasks: [
          CallTask.fromJson({...taskJson(status: status), 'transcript': []}),
        ],
      );
      expectEmpty('대화를 기다리고 있어요', message);
    }

    // (4) the list fails
    await pumpAt(tester, setup: (r) => r.listError = Exception('down'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MessageView), findsOneWidget);
    expect(find.text('서버와 연결되지 않았어요'), findsOneWidget);
    expect(find.text('서버 설정'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    // (5) unknown task
    await pumpAt(tester, location: '/calls/nope');
    expectEmpty('통화를 찾을 수 없어요', '삭제되었거나 다른 서버의 기록이에요.');
    await tester.pumpWidget(const SizedBox());
  });

  // ---- AC-009, AC-010 -----------------------------------------------------------------------------------------

  testWidgets('tap targets meet guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    for (final MapEntry(key: name, value: pump) in screens.entries) {
      await pump(tester);
      for (final guideline in [androidTapTargetGuideline, iOSTapTargetGuideline, labeledTapTargetGuideline]) {
        await expectLater(tester, meetsGuideline(guideline), reason: '$name ${guideline.description}');
      }
      await tester.pumpWidget(const SizedBox());
    }
    handle.dispose();
  });

  testWidgets('text contrast meets guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    for (final dark in [false, true]) {
      for (final MapEntry(key: name, value: pump) in screens.entries) {
        await pump(tester, dark: dark);
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$name dark=$dark');
        await tester.pumpWidget(const SizedBox());
      }
    }
    handle.dispose();
  });

  // ---- AC-011 -------------------------------------------------------------------------------------------------

  testWidgets('survives 2x text scale on a small phone', (tester) async {
    const phone = Size(360, 640);
    Future<void> tapVisible(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    for (final MapEntry(key: name, value: _) in screens.entries) {
      // Every screen draws without overflow.
      switch (name) {
        case 'home':
          await pumpAt(tester, tasks: homeTasks(), size: phone, textScale: 2);
        case 'plan without number':
          await pumpAt(tester, location: '/plan', extra: draft(phoneNumber: null), size: phone, textScale: 2);
        case 'plan with every row':
          await pumpAt(tester, location: '/plan', extra: draft(), size: phone, textScale: 2);
        case 'approval':
          await pumpAt(
            tester,
            location: '/calls/task-1',
            tasks: [CallTask.fromJson(approvalTask())],
            size: phone,
            textScale: 2,
          );
        case 'result':
          await pumpAt(
            tester,
            location: '/calls/task-1',
            tasks: [CallTask.fromJson(resultTask())],
            size: phone,
            textScale: 2,
          );
      }
      final error = tester.takeException();
      expect(error, isNull, reason: '$name: $error');
      await tester.pumpWidget(const SizedBox());
    }

    // [이대로 시작]
    final plan = await pumpAt(
      tester,
      location: '/plan',
      extra: draft(),
      size: phone,
      textScale: 2,
      setup: (r) => r.nextCreated = CallTask.fromJson(taskJson(id: 'task-9', status: 'planning')),
    );
    await tapVisible(find.byKey(const Key('plan-start')));
    expect(plan.createRequests, hasLength(1));

    // 승인 / 거절, and the pinned area stays within half the screen
    for (final (label, approve) in [('승인', true), ('거절', false)]) {
      final repo = await pumpAt(
        tester,
        location: '/calls/task-1',
        tasks: [CallTask.fromJson(approvalTask())],
        size: phone,
        textScale: 2,
      );
      final pinned = find.ancestor(of: find.byType(ApprovalCard), matching: find.byType(SingleChildScrollView)).first;
      expect(tester.getSize(pinned).height, lessThanOrEqualTo(320));
      await tapVisible(find.descendant(of: find.byType(ApprovalCard), matching: find.text(label)));
      expect(repo.decisions.single.approve, approve);
      final afterTap = tester.takeException();
      expect(afterTap, isNull, reason: '$label: ${afterTap is FlutterError ? afterTap.toStringDeep() : afterTap}');
    }

    // 다시 걸기
    await pumpAt(
      tester,
      location: '/calls/task-1',
      tasks: [CallTask.fromJson(resultTask())],
      size: phone,
      textScale: 2,
    );
    await tester.scrollUntilVisible(find.text('다시 걸기'), 200, scrollable: find.byType(Scrollable).first);
    await tapVisible(find.text('다시 걸기'));
    expect(find.byType(PlanCardScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // ---- AC-012 -------------------------------------------------------------------------------------------------

  const question = '예약금 1만 원 결제가 필요합니다. 진행할까요?';
  final cardNode = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == '승인 요청: $question');

  Future<(List<String>, Future<void> Function())> pumpCard(
    WidgetTester tester,
    int secondsLeft, {
    required bool announce,
  }) async {
    var fakeNow = DateTime.utc(2026, 11, 21, 10);
    final announcements = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
      message,
    ) async {
      final map = message as Map<dynamic, dynamic>;
      if (map['type'] == 'announce') announcements.add((map['data'] as Map<dynamic, dynamic>)['message'] as String);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      ),
    );
    final approval = ApprovalRequest.fromJson({
      ...approvalJson(),
      'expiresAt': fakeNow.add(Duration(seconds: secondsLeft)).toIso8601String(),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [callsRepositoryProvider.overrideWithValue(FakeCallsRepository([]))],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(supportsAnnounce: announce),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ApprovalCard(taskId: 'task-1', approval: approval, now: () => fakeNow),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> tick() async {
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    return (announcements, tick);
  }

  Future<void> ticks(WidgetTester tester, Future<void> Function() tick, int n) async {
    for (var i = 0; i < n; i++) {
      await tick();
    }
  }

  testWidgets('screen reader labels are present', (tester) async {
    final handle = tester.ensureSemantics();
    final (_, tick) = await pumpCard(tester, 90, announce: true);
    final semantics = tester.getSemantics(cardNode);
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
    expect(semantics.label, contains('승인 요청: $question'));
    expect(RegExp(r'\d+\s*초').hasMatch(semantics.label.replaceAll(question, '')), isFalse);
    final first = semantics.label;
    await ticks(tester, tick, 5);
    expect(tester.getSemantics(cardNode).label, first);
    expect(find.bySemanticsLabel(RegExp(r'\d+\s*초$')), findsNothing);

    // The status chip and the icon buttons have labels.
    await pumpAt(tester, location: '/calls/task-1', tasks: [CallTask.fromJson(taskJson())]);
    expect(find.bySemanticsLabel('상태: 통화 중'), findsOneWidget);
    await pumpAt(tester, tasks: homeTasks());
    expect(find.byTooltip('설정'), findsOneWidget);
    expect(find.byTooltip('보내기'), findsOneWidget);
    await pumpAt(tester, location: '/plan', extra: draft());
    expect(find.byTooltip('수정'), findsWidgets);
    await pumpAt(tester, location: '/calls/task-1', tasks: [CallTask.fromJson(resultTask())]);
    expect(find.byTooltip('삭제'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });

  testWidgets('announces the remaining time only at 30 and 10 seconds', (tester) async {
    final handle = tester.ensureSemantics();

    // (가) the platform announces
    var (said, tick) = await pumpCard(tester, 32, announce: true);
    await ticks(tester, tick, 3);
    expect(said, ['30초 남았어요']);
    await ticks(tester, tick, 20);
    expect(said, ['30초 남았어요', '10초 남았어요']);

    // (나) no announcements: a separate live region carries the text
    Finder notice(String text) =>
        find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true && w.properties.label == text);
    (said, tick) = await pumpCard(tester, 32, announce: false);
    await ticks(tester, tick, 3);
    expect(notice('30초 남았어요'), findsOneWidget);
    await ticks(tester, tick, 5);
    expect(notice('30초 남았어요'), findsOneWidget);
    await ticks(tester, tick, 15);
    expect(notice('10초 남았어요'), findsOneWidget);
    expect(said, isEmpty);

    // Starting past the marks announces nothing.
    (said, tick) = await pumpCard(tester, 8, announce: true);
    await ticks(tester, tick, 3);
    expect(said, isEmpty);
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });

  // ---- AC-013 -------------------------------------------------------------------------------------------------

  testWidgets('screens follow the wireframe order', (tester) async {
    double top(Finder finder) => tester.getTopLeft(finder.first).dy;
    void expectOrder(List<Finder> finders) {
      final tops = [for (final f in finders) top(f)];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: 'item $i of ${finders.length}');
      }
    }

    await pumpAt(tester, tasks: homeTasks(), size: const Size(800, 2400));
    expectOrder([
      find.byKey(const Key('home-intake-field')),
      find.text('진행 중'),
      find.text('최근 통화한 곳'),
    ]);

    await pumpAt(tester, location: '/plan', extra: draft(phoneNumber: null), size: const Size(800, 2400));
    expectOrder([find.byKey(const Key('plan-phone-field')), find.text('전화할 곳'), find.byKey(const Key('plan-start'))]);

    await pumpAt(
      tester,
      location: '/calls/task-1',
      tasks: [CallTask.fromJson(approvalTask())],
      size: const Size(800, 2400),
    );
    expectOrder([
      find.text('02-123-4567'),
      find.text('네, 라 파스타입니다.'),
      find.byType(ApprovalCard),
      find.descendant(of: find.byType(ApprovalCard), matching: find.text('승인')),
    ]);

    await pumpAt(
      tester,
      location: '/calls/task-1',
      tasks: [CallTask.fromJson(resultTask())],
      size: const Size(800, 2400),
    );
    expectOrder([
      find.byType(OutcomeCard),
      find.text('다시 걸기'),
      find.text('통화 중 결정한 것'),
      find.text('부탁한 일'),
      find.text('대화 내용'),
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  // ---- SPEC-SHELL-001 AC-020 ------------------------------------------------------------------------------

  testWidgets('shell screens meet the accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    final shellScreens = <String, Future<shell.CountingCallsRepository> Function({bool dark, Size size, double textScale})>{
      'today': ({dark = false, size = const Size(800, 2400), textScale = 1}) =>
          shell.pumpShell(tester, tasks: shell.mixedTasks(), dark: dark, size: size, textScale: textScale),
      for (final (name, key) in [('tasks', shell.tabTasks), ('history', shell.tabHistory), ('me', shell.tabMe)])
        name: ({dark = false, size = const Size(800, 2400), textScale = 1}) async {
          final repo = await shell.pumpShell(
            tester,
            tasks: shell.mixedTasks(),
            dark: dark,
            size: size,
            textScale: textScale,
          );
          await tester.tap(find.byKey(key));
          await shell.settle(tester);
          return repo;
        },
      'detail (a)': ({dark = false, size = const Size(800, 2400), textScale = 1}) async {
        final repo = await shell.pumpShell(
          tester,
          tasks: shell.mixedTasks(),
          dark: dark,
          size: size,
          textScale: textScale,
        );
        openTask(shell.appRouter(tester), 'a');
        await shell.settle(tester);
        return repo;
      },
    };

    // Guidelines, light and dark.
    for (final dark in [false, true]) {
      for (final MapEntry(key: name, value: pump) in shellScreens.entries) {
        await pump(dark: dark);
        for (final guideline in [
          androidTapTargetGuideline,
          iOSTapTargetGuideline,
          labeledTapTargetGuideline,
          textContrastGuideline,
        ]) {
          await expectLater(tester, meetsGuideline(guideline), reason: '$name dark=$dark ${guideline.description}');
        }
      }
    }

    // 360x640 at 2x text: no overflow, tab labels stay at most 1.5x.
    for (final MapEntry(key: name, value: pump) in shellScreens.entries) {
      await pump(size: const Size(360, 640), textScale: 2);
      final error = tester.takeException();
      expect(error, isNull, reason: '$name: $error');
      for (final (key, label) in [
        (shell.tabToday, '오늘'),
        (shell.tabTasks, '업무'),
        (shell.tabHistory, '기록'),
        (shell.tabMe, '내 정보'),
      ]) {
        final text = find.descendant(of: find.byKey(key), matching: find.text(label));
        expect(MediaQuery.textScalerOf(tester.element(text)).scale(14) / 14, lessThanOrEqualTo(1.5), reason: label);
      }
    }

    // The approval card's [승인] can be reached and tapped.
    final repo = await shellScreens['detail (a)']!(size: const Size(360, 640), textScale: 2);
    final approve = find.descendant(of: find.byType(ApprovalCard), matching: find.text('승인'));
    await tester.ensureVisible(approve);
    await tester.pump();
    await tester.tap(approve);
    await shell.settle(tester);
    expect(repo.decisions.single.approve, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });
}

/// An HTTP client whose requests never complete, so a button stays in its busy state.
class _SilentServer extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _SilentClient();
}

class _SilentClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
