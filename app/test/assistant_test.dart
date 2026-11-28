// SPEC-ASSIST-001 AC-001 .. AC-010, AC-014 (assistant). The recognizer is always the fake, except where a
// test checks that the real one degrades without plugins.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;

import 'package:callmate/app.dart';
import 'package:callmate/core/clock.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/network/api_client.dart';
import 'package:callmate/features/assistant/speech/platform_speech_recognizer.dart';
import 'package:callmate/features/assistant/speech/speech_recognizer.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/domain/intake_models.dart';
import 'package:callmate/features/calls/presentation/call_templates.dart';
import 'package:callmate/features/calls/presentation/plan_card_screen.dart';
import 'package:callmate/shell/navigation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_speech_recognizer.dart';
import 'support/shell_support.dart';

const field = Key('home-intake-field');
const send = Key('home-intake-send');
const orb = Key('assistant-orb');
const chip = Key('assistant-status-chip');
const close = Key('assistant-close');
const heard = '잘 못 들었어요. 다시 말하거나 글로 적어 주세요';
// flutter_test runs as Android, so the base profile has already seen the Android speech-service notice;
// the notice itself is tested on its own below.
const profile = {
  'requesterName': '김민수',
  'trustNoticeAcknowledged': true,
  'androidSpeechServiceNoticeAcknowledged': true,
};
const profileBeforeNotice = {'requesterName': '김민수', 'trustNoticeAcknowledged': true};

/// The whole app with the fake recognizer (or, with [speech] null, the real one, which finds no plugin).
Future<CountingCallsRepository> pumpAssistantApp(
  WidgetTester tester, {
  FakeSpeechRecognizer? speech,
  List<CallTask> tasks = const [],
  Map<String, Object> prefs = profile,
  Size size = const Size(800, 2400),
  double textScale = 1,
  void Function(CountingCallsRepository repo)? setup,
}) async {
  await tester.pumpWidget(const SizedBox());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final repo = CountingCallsRepository(tasks);
  setup?.call(repo);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        callsRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => shellNow),
        if (speech != null) speechRecognizerProvider.overrideWithValue(speech),
      ],
      child: const CallMateApp(),
    ),
  );
  await settle(tester);
  return repo;
}

/// The centre button, then one frame: the screen is up and has asked for the permission state.
Future<void> openFromButton(WidgetTester tester) async {
  await tester.tap(find.byKey(assistantButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

String? chipText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(chip), matching: find.byType(Text)),
    )
    .first
    .data;

TextEditingController input(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(field)).controller!;

PlanDraft draftFor(String goal) => IntakeResult.fromJson({
  'draft': {
    'targetName': '라 파스타',
    'phoneNumber': '+8221234567',
    'goal': goal,
    'conditions': <String>[],
    'language': 'ko',
  },
  'missing': <String>[],
  'phoneSource': 'history',
  'source': 'llm',
}).draft;

Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
}

/// The mixed set plus a finished, connected call, so "최근 통화한 곳" has an entry.
List<CallTask> withRecentPlace() => [
  ...mixedTasks(),
  shellTask(
    'f',
    '동네 세탁소',
    status: 'completed',
    outcome: successOutcome(),
    updatedAt: '2026-11-24T10:00:00+09:00',
  ),
];

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  group('speech port (M1)', () {
    test('without plugins the platform recognizer reports unavailable, never throws', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // The host (macOS/Linux) is not a dictation platform; forced on, the missing plugin is caught.
      final forced = PlatformSpeechRecognizer(supported: true);
      expect(await forced.permission(), MicPermission.unavailable);
      expect(await forced.koreanLocaleId(), isNull);
      final recognizer = PlatformSpeechRecognizer();
      expect(await recognizer.permission(), MicPermission.unavailable);
      expect(await recognizer.requestPermission(), MicPermission.unavailable);
      expect(await recognizer.koreanLocaleId(), isNull);
      final events = await recognizer
          .listen(localeId: 'ko-KR', onDevice: true)
          .toList();
      expect(events.single, isA<SpeechError>());
      await recognizer.stop();
      await recognizer.cancel();
      await recognizer.cancel();
      await recognizer.openAppSettings();
    });
  });

  // AC-001
  testWidgets('assistant screen follows the immersive layout', (tester) async {
    final speech = FakeSpeechRecognizer();
    final repo = await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);

    final order = [
      find.text('AI 비서'),
      find.byKey(chip),
      find.byKey(orb),
      find.text('무엇을 도와드릴까요?'),
      find.text('말씀해 주시면 제가 대신 처리할게요.'),
      find.text('이렇게 부탁해 보세요'),
      find.text(callTemplates[0].label),
      find.text('글로 입력'),
    ];
    final tops = [for (final f in order) tester.getTopLeft(f).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: 'item $i');
    }
    expect(
      tester.getTopLeft(find.text(callTemplates[1].label)).dy,
      tester.getTopLeft(find.text(callTemplates[0].label)).dy,
    );
    for (final label in ['말하기 끝', '그만하기']) {
      expect(
        tester.getTopLeft(find.text(label)).dy,
        closeTo(tops.last, 4),
        reason: label,
      );
    }
    final scaffold = find.byKey(const Key('assistant-screen'));
    final material = tester.widget<Material>(
      find.descendant(of: scaffold, matching: find.byType(Material)).first,
    );
    expect(material.color, const Color(0xFF11131F));

    await tapAndSettle(tester, find.text(callTemplates[0].label));
    expect(find.byKey(field), findsOneWidget);
    expect(input(tester).text, callTemplates.first.goal);
    expect(repo.intakeCalls, isEmpty);
    expect(speech.cancelCalls, greaterThan(0));
    expect(File('lib/shell/assistant_placeholder.dart').existsSync(), isFalse);
  });

  // AC-003, AC-004
  testWidgets('dictation fills the request and opens the plan card', (
    tester,
  ) async {
    const sentence = '금요일 7시 2명 라 파스타 예약해 줘';
    final speech = FakeSpeechRecognizer(
      sessions: [
        [
          const SpeechPartial('금요일'),
          const SpeechPartial('금요일 7시 2명'),
          const SpeechFinal(sentence),
        ],
      ],
    );
    final repo = await pumpAssistantApp(
      tester,
      speech: speech,
      setup: (r) => r.intakeResult = IntakeResult(draft: draftFor(sentence)),
    );
    final before = repo.callLog.length;
    await openFromButton(tester);

    expect(speech.listenCalls, [
      (localeId: 'ko-KR', onDevice: true, partialResults: true),
    ]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('금요일'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('금요일 7시 2명'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);

    expect(repo.intakeCalls, [sentence]);
    expect(find.byType(PlanCardScreen), findsOneWidget);
    expect(find.text(sentence), findsOneWidget);
    expect(find.byKey(tabToday).hitTestable(), findsNothing);
    // AC-004: after the assistant opened, Kolbi got the final text only.
    expect(repo.callLog.sublist(before), ['intake']);

    await systemBack(tester);
    expect(find.byKey(const Key('assistant-screen')), findsOneWidget);
    expect(find.byType(PlanCardScreen), findsNothing);
    expect(speech.listenCalls, hasLength(1));
  });

  testWidgets('an older server keeps the blank-plan fallback', (tester) async {
    const sentence = '내일 오후 치과 예약 바꿔 줘';
    final speech = FakeSpeechRecognizer(
      sessions: [
        [const SpeechFinal(sentence)],
      ],
    );
    await pumpAssistantApp(
      tester,
      speech: speech,
      setup: (r) => r.intakeError = const ApiException(
        'http_404',
        '요청을 처리하지 못했어요.',
        statusCode: 404,
      ),
    );
    await openFromButton(tester);
    await settle(tester);
    await settle(tester);
    expect(find.byType(PlanCardScreen), findsOneWidget);
    expect(find.text(sentence), findsOneWidget);
    expect(find.text('AI 없이 간단히 정리했어요. 내용을 확인해 주세요.'), findsOneWidget);

    // Without a fake: no plugin, so the assistant opens in text mode without an exception.
    await pumpAssistantApp(tester);
    await openFromButton(tester);
    await settle(tester);
    expect(find.byKey(field), findsOneWidget);
    expect(find.byKey(chip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // AC-004
  testWidgets('only the final text reaches Kolbi', (tester) async {
    final port = File('lib/features/assistant/speech/speech_recognizer.dart')
        .readAsStringSync();
    expect(RegExp(r'Uint8List|List<int>').hasMatch(port), isFalse);
    for (final file in Directory(
      'lib/features/assistant',
    ).listSync(recursive: true).whereType<File>()) {
      expect(
        RegExp(r'\.wav|\.m4a|\.aac|writeAsBytes')
            .hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }

    final speech = FakeSpeechRecognizer(status: MicPermission.notDetermined);
    await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    expect(find.textContaining('콜비는 음성을 저장하지 않아요'), findsOneWidget);
    expect(find.textContaining('음성은 저장하지 않아요'), findsNothing);
  });

  // AC-005
  testWidgets('microphone permission is asked with a purpose first', (
    tester,
  ) async {
    const notice = '말로 부탁하면 제가 글로 받아 적어요. 콜비는 음성을 저장하지 않아요.';
    const consent = Key('mic-consent-continue');

    // (1) not asked yet, then granted
    var speech = FakeSpeechRecognizer(status: MicPermission.notDetermined);
    await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    expect(find.text(notice), findsOneWidget);
    expect(find.byKey(consent), findsOneWidget);
    expect(speech.requestCalls, 0);
    expect(speech.listenCalls, isEmpty);
    await tapAndSettle(tester, find.byKey(consent));
    expect(speech.requestCalls, 1);
    expect(speech.listenCalls, hasLength(1));
    expect(chipText(tester), '듣고 있어요');

    // (2) not asked yet, then refused
    speech = FakeSpeechRecognizer(
      status: MicPermission.notDetermined,
      requestResult: MicPermission.denied,
    );
    await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    await tapAndSettle(tester, find.byKey(consent));
    expect(find.byKey(field), findsOneWidget);
    expect(find.text('마이크 없이도 글로 부탁할 수 있어요'), findsOneWidget);
    expect(speech.listenCalls, isEmpty);

    // (3) refused with "don't ask again"
    speech = FakeSpeechRecognizer(status: MicPermission.permanentlyDenied);
    await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    expect(find.text(notice), findsNothing);
    expect(find.byKey(consent), findsNothing);
    expect(find.textContaining('설정에서 마이크와 음성 인식을 켜면'), findsOneWidget);
    expect(speech.requestCalls, 0);
    await tapAndSettle(tester, find.byKey(const Key('open-settings')));
    expect(speech.settingsCalls, 1);
  });

  // AC-006
  testWidgets('recognition failures never loop or send an empty request', (
    tester,
  ) async {
    // (1)-(3) one failure: the line, back to waiting, nothing sent
    for (final failure in <SpeechEvent>[
      const SpeechNoSpeech(),
      const SpeechError('network'),
      const SpeechFinal(''),
    ]) {
      final speech = FakeSpeechRecognizer(
        sessions: [
          [failure],
        ],
      );
      final repo = await pumpAssistantApp(tester, speech: speech);
      await openFromButton(tester);
      await settle(tester);
      expect(find.text(heard), findsOneWidget, reason: '$failure');
      expect(chipText(tester), '기다리고 있어요', reason: '$failure');
      expect(repo.intakeCalls, isEmpty, reason: '$failure');
    }

    // (4) on-device recognition is not available: the OD-2 notice, then the general recognizer once
    const sentence = '내일 치과 예약 바꿔 줘';
    var speech = FakeSpeechRecognizer(
      sessions: [
        [const SpeechOnDeviceUnavailable()],
        [const SpeechFinal(sentence)],
        [const SpeechNoSpeech()],
        const [],
      ],
    );
    var repo = await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    const od2 = '음성 인식 서비스가 말을 글로 바꿔요. 콜비는 음성을 저장하지 않아요.';
    expect(find.textContaining(od2), findsOneWidget);
    expect(find.textContaining('이 기기에서는 '), findsOneWidget);
    await tapAndSettle(tester, find.byKey(const Key('fallback-continue')));
    expect(speech.listenCalls[1].onDevice, isFalse);
    expect(repo.intakeCalls, [sentence]);

    // (6) second half: the general recognizer is remembered for this run of the app.
    await systemBack(tester); // plan card -> assistant
    await tapAndSettle(tester, find.byKey(close));
    await openFromButton(tester);
    await settle(tester);
    expect(speech.listenCalls, hasLength(3));
    expect(speech.listenCalls[2].onDevice, isFalse);
    expect(find.textContaining(od2), findsNothing);
    await tapAndSettle(tester, find.byKey(orb));
    expect(speech.listenCalls, hasLength(4));
    expect(speech.listenCalls[3].onDevice, isFalse);
    expect(find.textContaining(od2), findsNothing);

    // (5) both fail: text mode, exactly two listens, and no automatic listening on the next open
    speech = FakeSpeechRecognizer(
      sessions: [
        [const SpeechOnDeviceUnavailable()],
        [const SpeechError('network')],
      ],
    );
    repo = await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    await tapAndSettle(tester, find.byKey(const Key('fallback-continue')));
    expect(find.text(heard), findsOneWidget);
    expect(find.byKey(field), findsOneWidget);
    expect(speech.listenCalls, hasLength(2));
    await tapAndSettle(tester, find.byKey(close));
    await openFromButton(tester);
    await settle(tester);
    expect(speech.listenCalls, hasLength(2));
    expect(repo.intakeCalls, isEmpty);

    // (6) first half: [글로 입력] on the OD-2 notice
    speech = FakeSpeechRecognizer(
      sessions: [
        [const SpeechOnDeviceUnavailable()],
      ],
    );
    await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    await tapAndSettle(tester, find.byKey(const Key('fallback-text')));
    expect(speech.listenCalls, hasLength(1));
    expect(find.byKey(field), findsOneWidget);
  });

  // AC-007
  testWidgets('stopping or leaving cancels dictation; inactive does not', (
    tester,
  ) async {
    Future<(FakeSpeechRecognizer, CountingCallsRepository)> listening() async {
      final speech = FakeSpeechRecognizer(
        sessions: [
          [const SpeechPartial('오늘 저녁')],
        ],
      );
      final repo = await pumpAssistantApp(
        tester,
        speech: speech,
        // Without a's pending approval, so its snack bar never covers the control row.
        tasks: mixedTasks().where((t) => t.id != 'a').toList(),
      );
      openTask(appRouter(tester), 'c');
      await settle(tester);
      await openFromButton(tester);
      await settle(tester);
      expect(find.text('오늘 저녁'), findsOneWidget);
      return (speech, repo);
    }

    Future<void> leave(WidgetTester tester, int how) async {
      switch (how) {
        case 1:
          await tapAndSettle(tester, find.text('그만하기'));
        case 2:
          await tapAndSettle(tester, find.byKey(close));
        case 3:
          await systemBack(tester);
      }
    }

    for (final how in [1, 2, 3]) {
      final (speech, repo) = await listening();
      await leave(tester, how);
      expect(speech.cancelCalls, greaterThan(0), reason: '($how)');
      expect(detailOf('c'), findsOneWidget, reason: '($how)');
      expect(isSelected(tester, tabTasks), isTrue, reason: '($how)');
      speech.emitLate(const SpeechFinal('오늘 저녁 7시 예약'));
      await settle(tester);
      expect(repo.intakeCalls, isEmpty, reason: '($how)');
      expect(tester.takeException(), isNull, reason: '($how)');
    }

    void lifecycle(List<AppLifecycleState> states) {
      for (final s in states) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    // (4) the app goes to the background
    var (speech, repo) = await listening();
    lifecycle([
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await settle(tester);
    expect(speech.cancelCalls, greaterThan(0));
    lifecycle([
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    speech.emitLate(const SpeechFinal('오늘 저녁 7시 예약'));
    await settle(tester);
    expect(repo.intakeCalls, isEmpty);

    // (5) inactive only (the OS permission dialog): dictation keeps going
    (speech, repo) = await listening();
    lifecycle([AppLifecycleState.inactive]);
    await settle(tester);
    lifecycle([AppLifecycleState.resumed]);
    await settle(tester);
    expect(speech.cancelCalls, 0);
    expect(chipText(tester), '듣고 있어요');
  });

  // AC-008
  testWidgets('text mode carries the whole request box', (tester) async {
    // (1) [글로 입력] while dictating keeps the words
    final speech = FakeSpeechRecognizer(
      sessions: [
        [const SpeechPartial('내일 치과')],
      ],
    );
    var repo = await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    final big = tester.getSize(find.byKey(orb));
    await tapAndSettle(tester, find.text('글로 입력'));
    expect(speech.cancelCalls, greaterThan(0));
    expect(input(tester).text, '내일 치과');
    expect(tester.getSize(find.byKey(orb)).width, lessThan(big.width));
    await tester.enterText(find.byKey(field), '내일 치과 예약 바꿔 줘');
    await tester.pump();
    await tapAndSettle(tester, find.byKey(send));
    expect(repo.intakeCalls, ['내일 치과 예약 바꿔 줘']);
    expect(find.byType(PlanCardScreen), findsOneWidget);

    // (2) /assistant?mode=text with recent places
    repo = await pumpAssistantApp(
      tester,
      speech: FakeSpeechRecognizer(),
      tasks: withRecentPlace(),
    );
    openAssistant(appRouter(tester), text: true);
    await settle(tester);
    expect(find.byKey(field), findsOneWidget);
    expect(find.byTooltip('보내기'), findsOneWidget);
    expect(find.text('직접 입력하기'), findsOneWidget);
    expect(find.text('최근 통화한 곳'), findsOneWidget);
    expect(find.textContaining('동네 세탁소 ·'), findsOneWidget);
    expect(find.text('이런 부탁도 할 수 있어요'), findsOneWidget);
    expect(find.byKey(chip), findsNothing);
    expect(find.text('이렇게 부탁해 보세요'), findsNothing);
    expect(find.text('그만하기'), findsNothing);
    expect(find.text('무엇을 도와드릴까요?'), findsOneWidget);
    expect(find.text('식당 예약'), findsOneWidget);
    expect(find.byKey(orb), findsOneWidget);

    await tapAndSettle(tester, find.text('직접 입력하기'));
    expect(find.text('통화 계획 만들기'), findsOneWidget);
    expect(find.byKey(tabToday).hitTestable(), findsNothing);
    await goBack(tester);
    expect(find.byKey(field), findsOneWidget);

    // A failing list hides only the recent places.
    await pumpAssistantApp(
      tester,
      speech: FakeSpeechRecognizer(),
      setup: (r) => r.listError = Exception('down'),
    );
    openAssistant(appRouter(tester), text: true);
    await settle(tester);
    expect(find.text('최근 통화한 곳'), findsNothing);
    expect(find.byKey(field), findsOneWidget);
    expect(find.text('직접 입력하기'), findsOneWidget);
    expect(find.text('이런 부탁도 할 수 있어요'), findsOneWidget);
  });

  // AC-009
  testWidgets('missing profile and intake errors keep the request', (
    tester,
  ) async {
    // (1) no profile: settings over the assistant, then back with the text kept
    var repo = await pumpAssistantApp(
      tester,
      speech: FakeSpeechRecognizer(),
      prefs: const {'trustNoticeAcknowledged': true},
    );
    openAssistant(appRouter(tester), text: true);
    await settle(tester);
    await tester.enterText(find.byKey(field), '내일 치과 예약');
    await tester.pump();
    await tapAndSettle(tester, find.byKey(send));
    expect(find.text('AI 비서와 기록'), findsOneWidget);
    expect(find.byKey(tabToday).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
    expect(repo.intakeCalls, isEmpty);
    await goBack(tester);
    expect(input(tester).text, '내일 치과 예약');

    // (2) another error: the message, no plan card, the text kept
    const error = ApiException(
      'server_error',
      '서버에 문제가 생겼어요.',
      statusCode: 500,
    );
    repo = await pumpAssistantApp(
      tester,
      speech: FakeSpeechRecognizer(),
      setup: (r) => r.intakeError = error,
    );
    openAssistant(appRouter(tester), text: true);
    await settle(tester);
    await tester.enterText(find.byKey(field), '내일 치과 예약');
    await tester.pump();
    await tapAndSettle(tester, find.byKey(send));
    expect(repo.intakeCalls, ['내일 치과 예약']);
    expect(find.text(describeError(error)), findsOneWidget);
    expect(find.byType(PlanCardScreen), findsNothing);
    expect(input(tester).text, '내일 치과 예약');
  });

  // SHELL-001 sync-audit F1: /assistant as the first route (a web deep link).
  testWidgets(
    'the assistant opened as the first route never pops into nothing',
    (tester) async {
      // Close goes to today.
      await pumpAssistantApp(tester, speech: FakeSpeechRecognizer());
      appRouter(tester).go('/assistant');
      await settle(tester);
      expect(find.byKey(const Key('assistant-screen')), findsOneWidget);
      await tapAndSettle(tester, find.byKey(close));
      expect(find.byKey(todayScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // No profile: settings opens over it, back returns to it.
      var repo = await pumpAssistantApp(
        tester,
        speech: FakeSpeechRecognizer(),
        prefs: const {'trustNoticeAcknowledged': true},
      );
      appRouter(tester).go('/assistant?mode=text');
      await settle(tester);
      await tester.enterText(find.byKey(field), '내일 치과 예약');
      await tester.pump();
      await tapAndSettle(tester, find.byKey(send));
      expect(find.text('AI 비서와 기록'), findsOneWidget);
      await goBack(tester);
      expect(input(tester).text, '내일 치과 예약');
      expect(repo.intakeCalls, isEmpty);
      expect(tester.takeException(), isNull);

      // Submit: the plan card opens over it, and [이대로 시작] lands on the tasks tab.
      repo = await pumpAssistantApp(tester, speech: FakeSpeechRecognizer());
      repo.nextCreated = shellTask('task-9', '라 파스타', status: 'planning');
      repo.intakeResult = IntakeResult(draft: draftFor('라 파스타 금요일 7시 예약'));
      appRouter(tester).go('/assistant?mode=text');
      await settle(tester);
      await tester.enterText(find.byKey(field), '라 파스타 금요일 7시 예약');
      await tester.pump();
      await tapAndSettle(tester, find.byKey(send));
      expect(find.byType(PlanCardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapAndSettle(tester, find.byKey(const Key('plan-start')));
      expect(detailOf('task-9'), findsOneWidget);
      expect(isSelected(tester, tabTasks), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  // AC-002
  testWidgets('orb state is shown in words and announced', (tester) async {
    for (final reduceMotion in [false, true]) {
      const sentence = '오늘 저녁 7시 예약해 줘';
      final speech = FakeSpeechRecognizer(
        sessions: [
          [const SpeechPartial('오늘'), const SpeechFinal(sentence)],
        ],
      );
      final hold = Completer<void>();
      final repo = await pumpAssistantApp(
        tester,
        speech: speech,
        setup: (r) => r.intakeHold = hold,
      );
      if (reduceMotion) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
      }
      tester.takeAnnouncements();
      await openFromButton(tester);
      expect(chipText(tester), '듣고 있어요', reason: 'reduce=$reduceMotion');
      if (reduceMotion) {
        expect(
          find.descendant(
            of: find.byKey(orb),
            matching: find.byType(AnimatedBuilder),
          ),
          findsNothing,
        );
      }
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // partial: no announcement
      await tester.pump(const Duration(milliseconds: 100)); // final
      await tester.pump();
      expect(chipText(tester), '처리하고 있어요', reason: 'reduce=$reduceMotion');
      expect(repo.intakeCalls, [sentence]);
      final said = tester.takeAnnouncements();
      expect(said.map((a) => a.message), ['듣고 있어요', '처리하고 있어요. $sentence']);
      expect(
        said.map((a) => a.assertiveness),
        everyElement(Assertiveness.polite),
      );
      expect(
        find.descendant(
          of: find.byKey(orb),
          matching: find.byType(ExcludeSemantics),
          matchRoot: true,
        ),
        findsWidgets,
      );
      if (reduceMotion) {
        expect(
          find.descendant(
            of: find.byKey(orb),
            matching: find.byType(AnimatedBuilder),
          ),
          findsNothing,
        );
      }
      hold.complete();
      await settle(tester);
      expect(find.byType(PlanCardScreen), findsOneWidget);
    }
  });

  // AC-014 (assistant)
  testWidgets('immersive screens meet the accessibility guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final cases = <String, FakeSpeechRecognizer Function()>{
      'idle': () => FakeSpeechRecognizer(
        sessions: [
          [const SpeechNoSpeech()],
        ],
      ),
      'listening': () => FakeSpeechRecognizer(
        sessions: [
          [const SpeechPartial('내일 치과')],
        ],
      ),
      'text': () => FakeSpeechRecognizer(status: MicPermission.denied),
    };
    for (final MapEntry(key: name, value: make) in cases.entries) {
      for (final small in [false, true]) {
        await pumpAssistantApp(
          tester,
          speech: make(),
          tasks: withRecentPlace(),
          size: small ? const Size(360, 640) : const Size(800, 2400),
          textScale: small ? 2 : 1,
        );
        await openFromButton(tester);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '$name small=$small');
        if (small) continue;
        for (final guideline in [
          androidTapTargetGuideline,
          iOSTapTargetGuideline,
          labeledTapTargetGuideline,
          textContrastGuideline,
        ]) {
          await expectLater(
            tester,
            meetsGuideline(guideline),
            reason: '$name ${guideline.description}',
          );
        }
        if (name != 'text') {
          for (final label in ['글로 입력하기', '말하기 끝내고 보내기', '그만하기']) {
            expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
          }
        }
      }
    }

    // Partial words never announce; the final sentence does, once, as it is sent.
    final speech = FakeSpeechRecognizer(
      sessions: [
        [
          const SpeechPartial('내일'),
          const SpeechPartial('내일 치과'),
          const SpeechPartial('내일 치과 예약'),
          const SpeechFinal('내일 치과 예약 바꿔 줘'),
        ],
      ],
    );
    final hold = Completer<void>();
    await pumpAssistantApp(
      tester,
      speech: speech,
      setup: (r) => r.intakeHold = hold,
    );
    tester.takeAnnouncements();
    await openFromButton(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeAnnouncements().map((a) => a.message), ['듣고 있어요']);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(tester.takeAnnouncements().map((a) => a.message), [
      '처리하고 있어요. 내일 치과 예약 바꿔 줘',
    ]);
    hold.complete();
    await settle(tester);
    handle.dispose();
  });

  // AC-010
  testWidgets('today hands requests to the assistant', (tester) async {
    void expectNoRequestBox(String reason) {
      final today = find.byKey(todayScreen);
      Finder inToday(Finder f) => find.descendant(of: today, matching: f);
      expect(inToday(find.byKey(field)), findsNothing, reason: reason);
      expect(inToday(find.byTooltip('보내기')), findsNothing, reason: reason);
      expect(inToday(find.text('직접 입력하기')), findsNothing, reason: reason);
      expect(
        inToday(find.text('이런 부탁도 할 수 있어요')),
        findsNothing,
        reason: reason,
      );
    }

    // (1) the mixed set plus a finished call to recent places
    await pumpAssistantApp(tester, tasks: withRecentPlace());
    expectNoRequestBox('(1)');
    final order = [
      find.byKey(const Key('today-briefing')),
      find.text('비서에게 부탁하기'),
      find.text('확인이 필요해요'),
      find.text('진행 중'),
      find.text('최근 통화한 곳'),
    ];
    final tops = [for (final f in order) tester.getTopLeft(f).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: 'item $i');
    }
    final place = find.textContaining('동네 세탁소 ·');
    await tapAndSettle(tester, place);
    expect(find.byKey(const Key('assistant-screen')), findsOneWidget);
    expect(find.byKey(chip), findsNothing);
    expect(input(tester).text, '동네 세탁소에 ');

    for (final key in ['shortcut-call', 'shortcut-search']) {
      await pumpAssistantApp(
        tester,
        speech: FakeSpeechRecognizer(),
        tasks: withRecentPlace(),
      );
      await tapAndSettle(tester, find.byKey(Key(key)));
      expect(
        find.byKey(const Key('assistant-screen')),
        findsOneWidget,
        reason: key,
      );
    }

    // (2) no tasks
    await pumpAssistantApp(tester);
    expectNoRequestBox('(2)');
    expect(find.text('귀찮은 전화, 대신 걸어드릴게요'), findsNothing);
    expect(find.text('오늘은 맡긴 일이 없어요.'), findsOneWidget);
    expect(find.text('가운데 버튼으로 부탁해 보세요.'), findsOneWidget);
    expect(find.byTooltip('설정'), findsOneWidget);
  });

  testWidgets('Android shows the speech-service notice once before the first dictation', (tester) async {
    const sentence = 'Android에서는 구글 음성 인식 서비스가 말을 글로 바꿀 수 있어요. 콜비는 음성을 저장하지 않아요.';
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    // (1) permission already granted: the notice on its own, nothing heard until [계속]
    var speech = FakeSpeechRecognizer();
    await pumpAssistantApp(tester, speech: speech, prefs: profileBeforeNotice);
    await openFromButton(tester);
    await settle(tester);
    expect(find.text(sentence), findsOneWidget);
    expect(speech.listenCalls, isEmpty);
    await tapAndSettle(tester, find.byKey(const Key('speech-service-continue')));
    expect(speech.listenCalls, hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('androidSpeechServiceNoticeAcknowledged'), isTrue);

    // (2) seen before: listening starts at once, no notice
    speech = FakeSpeechRecognizer();
    await pumpAssistantApp(tester, speech: speech);
    await openFromButton(tester);
    await settle(tester);
    expect(find.text(sentence), findsNothing);
    expect(speech.listenCalls, hasLength(1));

    // (3) permission not asked yet: one sheet carries both sentences, [계속] acknowledges both
    speech = FakeSpeechRecognizer(status: MicPermission.notDetermined);
    await pumpAssistantApp(tester, speech: speech, prefs: profileBeforeNotice);
    await openFromButton(tester);
    await settle(tester);
    expect(find.textContaining(sentence), findsOneWidget);
    await tapAndSettle(tester, find.byKey(const Key('mic-consent-continue')));
    expect(speech.requestCalls, 1);
    expect(speech.listenCalls, hasLength(1));
    expect(find.byKey(const Key('speech-service-continue')), findsNothing);
  });

  testWidgets('iOS does not show the Android notice up front', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final speech = FakeSpeechRecognizer();
    await pumpAssistantApp(tester, speech: speech, prefs: profileBeforeNotice);
    await openFromButton(tester);
    await settle(tester);
    expect(find.textContaining('구글 음성 인식 서비스'), findsNothing);
    expect(speech.listenCalls, hasLength(1));
  });
}
