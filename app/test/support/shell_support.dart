// Shared set-up for the SPEC-SHELL-001 tests: the "섞음" task set, a list-counting fake, the fixed clock.
import 'dart:ui' show Tristate;

import 'package:callmate/app.dart';
import 'package:callmate/core/network/live_channel.dart';
import 'package:callmate/core/clock.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/router/app_router.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/presentation/call_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// 2026-11-26 12:00 in Seoul (acceptance.md, common set-up).
final shellNow = DateTime.utc(2026, 11, 26, 3);

/// A pending approval that expires [seconds] from the real clock (the approval card counts down in real time).
Map<String, dynamic> pendingApproval({
  String id = 'approval-1',
  int seconds = 60,
}) => {
  ...approvalJson(),
  'id': id,
  'expiresAt': DateTime.now()
      .toUtc()
      .add(Duration(seconds: seconds))
      .toIso8601String(),
};

/// One task as the server would list it, with every field the shell reads settable.
Map<String, dynamic> shellTaskJson(
  String id,
  String name, {
  String status = 'in_progress',
  List<Map<String, dynamic>> approvals = const [],
  bool transcript = true,
  Map<String, dynamic>? outcome,
  String? updatedAt,
  int version = 1,
  Object? kind,
}) {
  final base = taskJson(
    id: id,
    status: status,
    approvals: approvals,
    outcome: outcome,
    version: version,
  );
  final at = updatedAt ?? shellNow.toIso8601String();
  return {
    ...base,
    'targetName': name,
    if (!transcript) 'transcript': <Map<String, dynamic>>[],
    'createdAt': at,
    'updatedAt': at,
    'kind': ?kind,
  };
}

CallTask shellTask(
  String id,
  String name, {
  String status = 'in_progress',
  List<Map<String, dynamic>> approvals = const [],
  bool transcript = true,
  Map<String, dynamic>? outcome,
  String? updatedAt,
  Object? kind,
}) => CallTask.fromJson(
  shellTaskJson(
    id,
    name,
    status: status,
    approvals: approvals,
    transcript: transcript,
    outcome: outcome,
    updatedAt: updatedAt,
    kind: kind,
  ),
);

Map<String, dynamic> successOutcome([String summary = '관리비 납부일을 확인했어요.']) => {
  'result': 'success',
  'source': 'llm',
  'summary': summary,
  'keyFacts': <String>[],
  'followUps': <String>[],
};

/// The standard set "섞음" (acceptance.md): a needs a decision, b waits for plan approval, c is on a call,
/// d finished today, e failed yesterday.
List<CallTask> mixedTasks() => [
  shellTask(
    'a',
    '라 파스타',
    approvals: [pendingApproval()],
    updatedAt: '2026-11-26T11:00:00+09:00',
  ),
  shellTask(
    'b',
    '우리동네 치과',
    status: 'awaiting_approval',
    transcript: false,
    updatedAt: '2026-11-26T11:30:00+09:00',
  ),
  shellTask('c', '헤어살롱 봄', updatedAt: '2026-11-26T11:10:00+09:00'),
  shellTask(
    'd',
    '관리사무소',
    status: 'completed',
    outcome: successOutcome(),
    updatedAt: '2026-11-26T10:00:00+09:00',
  ),
  shellTask(
    'e',
    '행복 소아과',
    status: 'failed',
    transcript: false,
    updatedAt: '2026-11-25T18:00:00+09:00',
  ),
];

/// The fake repository, counting `list` calls (AC-012).
class CountingCallsRepository extends FakeCallsRepository {
  CountingCallsRepository(super.tasks);

  int listCalls = 0;
  int _opened = 0;

  @override
  Future<List<CallTask>> list() {
    listCalls++;
    return super.list();
  }

  /// [live] first; a reload (`[다시 시도]`) closes the old channel, so later opens get a fresh one.
  @override
  LiveConnection openLiveChannel() =>
      _opened++ == 0 ? live : FakeLiveConnection();
}

/// Starts the whole app with [tasks], the fixed clock and a stored profile.
Future<CountingCallsRepository> pumpShell(
  WidgetTester tester, {
  List<CallTask> tasks = const [],
  Map<String, Object> prefs = const {
    'requesterName': '김민수',
    'trustNoticeAcknowledged': true,
  },
  Size size = const Size(800, 2400),
  bool dark = false,
  double textScale = 1,
  DateTime? now,
  void Function(CountingCallsRepository repo)? setup,
}) async {
  await tester.pumpWidget(const SizedBox());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final repo = CountingCallsRepository(tasks);
  setup?.call(repo);
  final fixed = now ?? shellNow;
  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry: a failing list stays failed, so error states and reload counts are exact.
      retry: (retryCount, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        callsRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => fixed),
      ],
      child: const CallMateApp(),
    ),
  );
  await settle(tester);
  return repo;
}

/// Enough frames for a route transition and the fake repository's answers.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

GoRouter appRouter(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CallMateApp)))
        .read(routerProvider);

Future<void> pushLocation(
  WidgetTester tester,
  String location, {
  Object? extra,
}) async {
  appRouter(tester).push(location, extra: extra);
  await settle(tester);
}

const tabToday = Key('tab-today');
const tabTasks = Key('tab-tasks');
const tabHistory = Key('tab-history');
const tabMe = Key('tab-me');
const assistantButton = Key('assistant-button');
const tasksScreen = Key('tasks-screen');
const historyScreen = Key('history-screen');
const todayScreen = Key('today-screen');
const meScreen = Key('me-screen');

bool isSelected(WidgetTester tester, Key key) =>
    tester.getSemantics(find.byKey(key)).flagsCollection.isSelected ==
    Tristate.isTrue;

Finder detailOf(String taskId) =>
    find.byWidgetPredicate((w) => w is CallDetailScreen && w.taskId == taskId);

/// System back: the app bar back button of the screen on top.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).hitTestable().last);
  await settle(tester);
}
