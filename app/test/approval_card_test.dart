import 'package:callmate/app.dart';
import 'package:callmate/core/config/app_settings.dart';
import 'package:callmate/core/network/api_client.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/presentation/approval_listener.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

// SPEC-APPROVAL-001 AC-009 .. AC-013. Elements are found by text, never by colour or size,
// so SPEC-UX-001 can restyle the card without breaking these tests.
void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  const chip1 = '금액이 더 나오면 거절해 주세요';
  const chip2 = '다른 날짜·시간도 물어봐 주세요';
  const chip3 = '조건을 자세히 듣고 다시 물어봐 주세요';
  const warning = '카드번호처럼 보이는 숫자는 지우고 보낼게요.';
  const family = '👨‍👩‍👧';

  /// Opens the call detail screen of the first task, like `approval_flow_test.dart`.
  Future<FakeCallsRepository> openCall(WidgetTester tester, CallTask task, {Object? decideError}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'requesterName': '김민수'});
    final prefs = await SharedPreferences.getInstance();
    final repo = FakeCallsRepository([task])..decideError = decideError;
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
    await tester.tap(find.text('라 파스타').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return repo;
  }

  Future<FakeCallsRepository> openPendingApproval(WidgetTester tester, {Object? decideError}) =>
      openCall(tester, CallTask.fromJson(taskJson(approvals: [approvalJson()])), decideError: decideError);

  TextField commentField(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField));
  String commentText(WidgetTester tester) => commentField(tester).controller!.text;

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The card's one-second ticker must not outlive the test.
  Future<void> dispose(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('quick replies fill the comment without sending', (tester) async {
    final repo = await openPendingApproval(tester);

    for (final chip in [chip1, chip2, chip3]) {
      expect(find.text(chip), findsOneWidget);
    }

    await tapAndSettle(tester, find.text(chip1));
    expect(commentText(tester), chip1);
    expect(repo.decisions, isEmpty);

    await tapAndSettle(tester, find.text(chip2));
    expect(commentText(tester), '$chip1 $chip2');

    await tapAndSettle(tester, find.text(chip2));
    expect(commentText(tester), '$chip1 $chip2');
    expect(repo.decisions, isEmpty);

    await tapAndSettle(tester, find.widgetWithText(FilledButton, '승인'));
    expect(repo.decisions.single, (approvalId: 'approval-1', approve: true, comment: '$chip1 $chip2'));

    await dispose(tester);
  });

  testWidgets('comment field starts as one line and counts code points', (tester) async {
    final repo = await openPendingApproval(tester);

    expect(find.text('조건 덧붙이기 (선택)'), findsOneWidget);
    expect(find.text('카드번호·비밀번호·주민번호는 적지 마세요.'), findsOneWidget);
    expect(commentField(tester).minLines, 1);
    expect(commentField(tester).maxLines, 4);

    await tester.enterText(find.byType(TextField), '가' * 399);
    await tester.pump();
    expect(find.textContaining('/ 500'), findsNothing);

    await tester.enterText(find.byType(TextField), '가' * 400);
    await tester.pump();
    expect(find.text('400 / 500'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '가' * 501);
    await tester.pump();
    expect(commentText(tester).runes.length, 500);

    await tester.enterText(find.byType(TextField), family * 101);
    await tester.pump();
    expect(commentText(tester).runes.length, lessThanOrEqualTo(500));

    await tapAndSettle(tester, find.widgetWithText(FilledButton, '승인'));
    expect(repo.decisions.single.comment!.runes.length, lessThanOrEqualTo(500));

    await dispose(tester);
  });

  testWidgets('warns about card-shaped numbers without blocking', (tester) async {
    final repo = await openPendingApproval(tester);

    await tester.enterText(find.byType(TextField), '1234-5678-9012-3456');
    await tester.pump();
    expect(find.text(warning), findsOneWidget);

    await tapAndSettle(tester, find.widgetWithText(FilledButton, '승인'));
    expect(repo.decisions.single.comment, '1234-5678-9012-3456');
    await dispose(tester);

    await openPendingApproval(tester);
    await tester.enterText(find.byType(TextField), '010-1234-5678로 연락');
    await tester.pump();
    expect(find.text(warning), findsNothing);
    await dispose(tester);
  });

  testWidgets('keeps the comment when sending fails', (tester) async {
    await openPendingApproval(
      tester,
      decideError: const ApiException('approval_closed', 'This approval is no longer pending', statusCode: 409),
    );

    // The list screen announced the approval with a 12-second snackbar; drop it so the error is not queued behind it.
    scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    await tester.enterText(find.byType(TextField), '1만 원까지만');
    await tester.pump();
    await tapAndSettle(tester, find.widgetWithText(FilledButton, '승인'));

    expect(find.text('이미 처리되었거나 시간이 지난 요청이에요.'), findsOneWidget);
    expect(commentText(tester), '1만 원까지만');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '승인')).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '거절')).onPressed, isNotNull);

    await dispose(tester);
  });

  testWidgets('shows the guidance in history and transcript', (tester) async {
    Map<String, dynamic> completed({required bool withGuidance}) {
      final json = taskJson(
        status: 'completed',
        approvals: [approvalJson(status: 'approved', userComment: '1만 원까지만')],
        outcome: {'result': 'success', 'summary': '요약', 'keyFacts': <String>[], 'followUps': <String>[]},
      );
      final at = DateTime.now().toUtc().toIso8601String();
      return {
        ...json,
        'transcript': [
          ...(json['transcript'] as List),
          if (withGuidance) {'id': 't3', 'speaker': 'system', 'text': '사용자 안내: 1만 원까지만', 'at': at},
        ],
      };
    }

    // Speaker labels on the screen without the guidance line, to show the line adds none.
    await openCall(tester, CallTask.fromJson(completed(withGuidance: false)));
    final agentLabels = find.text('AI 비서').evaluate().length;
    final calleeLabels = find.text('라 파스타').evaluate().length;
    await dispose(tester);

    await openCall(tester, CallTask.fromJson(completed(withGuidance: true)));
    final historyLine = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data ?? '').split('\n').contains('안내: 1만 원까지만'),
    );
    expect(historyLine, findsOneWidget);
    expect(find.text('사용자 안내: 1만 원까지만'), findsOneWidget);
    expect(find.text('AI 비서').evaluate().length, agentLabels);
    expect(find.text('라 파스타').evaluate().length, calleeLabels);

    await dispose(tester);
  });
}
