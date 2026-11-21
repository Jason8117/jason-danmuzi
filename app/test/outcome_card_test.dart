import 'package:callmate/features/calls/domain/call_models.dart';
import 'package:callmate/features/calls/presentation/widgets/outcome_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fakes.dart';

// SPEC-OUTCOME-001 AC-010 / REQ-012
void main() {
  Future<void> pumpCard(WidgetTester tester, Map<String, dynamic> outcome) async {
    final task = CallTask.fromJson(taskJson(status: 'completed', outcome: outcome));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: OutcomeCard(task: task)))));
  }

  testWidgets('shows an unverified outcome distinctly', (tester) async {
    await pumpCard(tester, {
      'result': 'unverified',
      'source': 'heuristic',
      'summary': '자동 요약(검증되지 않음): 라 파스타과(와) 통화했습니다.',
      'keyFacts': <String>[],
      'followUps': <String>[],
    });

    expect(find.text('결과 미확인'), findsOneWidget);
    expect(find.text('자동 요약이라 목표를 이뤘는지 확인하지 못했어요. 대화 기록을 직접 확인해 주세요.'), findsOneWidget);
    expect(find.text('목표 달성'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byIcon(Icons.error_rounded), findsNothing);
  });

  testWidgets('keeps the success presentation', (tester) async {
    await pumpCard(tester, {
      'result': 'success',
      'source': 'llm',
      'summary': '7시 예약 완료',
      'keyFacts': ['7시'],
      'followUps': <String>[],
    });

    expect(find.text('목표 달성'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('결과 미확인'), findsNothing);
    expect(find.textContaining('자동 요약이라'), findsNothing);
  });
}
