import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  Future<FakeCallsRepository> pumpApp(WidgetTester tester, List<CallTask> tasks) async {
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
    return repo;
  }

  testWidgets('shows the empty state with quick-start templates', (tester) async {
    await pumpApp(tester, []);
    expect(find.text('귀찮은 전화, 대신 걸어드릴게요'), findsOneWidget);
    expect(find.text('식당 예약'), findsOneWidget);
    expect(find.textContaining('시뮬레이션 모드'), findsOneWidget);
  });

  testWidgets('user approves a mid-call request from the live call screen', (tester) async {
    final repo = await pumpApp(tester, [CallTask.fromJson(taskJson(approvals: [approvalJson()]))]);

    expect(find.text('라 파스타'), findsOneWidget);
    expect(find.text('승인 대기'), findsOneWidget);

    await tester.tap(find.text('라 파스타'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('상대방이 기다리고 있어요'), findsOneWidget);
    expect(find.text('예약금 1만 원 결제가 필요합니다. 진행할까요?'), findsOneWidget);
    expect(find.text('네, 라 파스타입니다.'), findsOneWidget);

    expect(find.text('조건 덧붙이기 (선택)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1만 원까지만 승인');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '승인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      repo.decisions.single,
      (approvalId: 'approval-1', approve: true, comment: '1만 원까지만 승인'),
    );
    expect(find.text('상대방이 기다리고 있어요'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
