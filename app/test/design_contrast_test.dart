import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
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

// SPEC-DESIGN-001 AC-004b (device dark mode) and AC-013 (text contrast on the audited screens).
void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  Future<void> pumpAt(
    WidgetTester tester, {
    String? location,
    Object? extra,
    List<CallTask> tasks = const [],
    bool dark = false,
  }) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = dark
        ? Brightness.dark
        : Brightness.light;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({
      'requesterName': '김민수',
      'trustNoticeAcknowledged': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          callsRepositoryProvider.overrideWithValue(FakeCallsRepository(tasks)),
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
  }

  PlanDraft draft() => IntakeResult.fromJson({
    'draft': {
      'targetName': '라 파스타',
      'phoneNumber': '+8221234567',
      'goal': '금요일 7시 2명 예약',
      'conditions': ['8시도 괜찮음'],
      'context': '회원번호 1234',
      'language': 'ko',
    },
    'missing': <String>[],
    'phoneSource': 'history',
    'source': 'heuristic',
  }).draft;

  List<String> texts(WidgetTester tester) => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .toList();

  /// Settings after [연결 테스트]: the test binding answers every HTTP request with 400, so the
  /// failure text (`settings_screen.dart:149`) is on screen when contrast is checked.
  Future<void> settingsWithResult(
    WidgetTester tester, {
    bool dark = false,
  }) async {
    await pumpAt(tester, location: '/settings', dark: dark);
    final before = texts(tester).toSet();
    final button = find.text('연결 테스트');
    await tester.ensureVisible(button);
    await tester.tap(button);
    for (
      var i = 0;
      i < 50 && texts(tester).toSet().difference(before).isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(
      texts(tester).toSet().difference(before),
      isNotEmpty,
      reason: 'connection result text shown',
    );
  }

  final screens = <String, Future<void> Function(WidgetTester, {bool dark})>{
    'home (직접 입력하기)': (t, {dark = false}) => pumpAt(t, dark: dark),
    'approval (거절)': (t, {dark = false}) => pumpAt(
      t,
      location: '/calls/task-1',
      tasks: [
        CallTask.fromJson(taskJson(approvals: [approvalJson()])),
      ],
      dark: dark,
    ),
    'call detail (통화 끊기)': (t, {dark = false}) => pumpAt(
      t,
      location: '/calls/task-1',
      tasks: [CallTask.fromJson(taskJson())],
      dark: dark,
    ),
    'settings (연결 테스트 결과)': settingsWithResult,
    'plan card': (t, {dark = false}) =>
        pumpAt(t, location: '/plan', extra: draft(), dark: dark),
  };

  testWidgets('text contrast meets guidelines on design screens', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final dark in [false, true]) {
      for (final MapEntry(key: name, value: pump) in screens.entries) {
        await pump(tester, dark: dark);
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: '$name dark=$dark',
        );
        await tester.pumpWidget(const SizedBox());
      }
    }
    handle.dispose();
  });

  testWidgets('app follows the device dark mode', (tester) async {
    Color scaffoldColor() {
      final scaffold = find.byType(Scaffold).first;
      return tester
          .widget<Material>(
            find
                .descendant(of: scaffold, matching: find.byType(Material))
                .first,
          )
          .color!;
    }

    await pumpAt(tester, dark: true);
    expect(scaffoldColor(), const Color(0xFF11131F));

    await pumpAt(tester, location: '/settings');
    final light = texts(tester);
    await pumpAt(tester, location: '/settings', dark: true);
    expect(texts(tester), light);
    await tester.pumpWidget(const SizedBox());
  });
}
