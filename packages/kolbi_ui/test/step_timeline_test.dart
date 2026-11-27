// SPEC-SHELL-001 M1 (kolbi_ui): step timeline (REQ-010), badge (REQ-003), briefing card (REQ-015),
// kind presenter registry and the unknown-kind row (REQ-007, REQ-008).
import 'package:flutter_test/flutter_test.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

CallTask task({
  String status = 'in_progress',
  List<Map<String, dynamic>> approvals = const [],
  bool talked = true,
}) => CallTask.fromJson({
  'id': 't',
  'targetName': '라 파스타',
  'phoneNumber': '+8221234567',
  'goal': '예약',
  'status': status,
  'transcript': [
    if (talked)
      {
        'id': 'l1',
        'speaker': 'callee',
        'text': '네',
        'at': '2026-11-26T03:00:00Z',
      },
  ],
  'approvals': approvals,
});

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

class _FakePresenter extends TaskKindPresenter {
  const _FakePresenter();

  @override
  String get kindId => 'call';

  @override
  IconData get icon => Icons.call;

  @override
  Widget buildRow(
    BuildContext context,
    CallTask task, {
    required VoidCallback onTap,
    Widget? trailing,
    String? subtitle,
  }) => Text('row ${task.targetName}');

  @override
  Widget buildDetail(BuildContext context, String taskId) =>
      Text('detail $taskId');
}

void main() {
  testWidgets('step timeline lists six steps with labels in order', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final steps = taskSteps(
      task(
        approvals: [
          {
            'id': 'a',
            'question': 'q',
            'status': 'pending',
            'requestedAt': '2026-11-26T03:00:00Z',
            'expiresAt': '2026-11-26T03:01:00Z',
          },
        ],
      ),
    );
    await tester.pumpWidget(
      host(KolbiStepTimeline(key: const Key('task-steps'), steps: steps)),
    );

    final tops = [
      for (var i = 1; i <= 6; i++)
        tester.getTopLeft(find.byKey(Key('task-step-$i'))).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]));
    }
    for (final name in ['요청 이해', '연락처 확인', '가능 여부 확인', '내 승인', '확정', '결과 보고']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('task-step-4')),
        matching: find.text('응답을 기다리고 있어요'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('task-step-3'))).label,
      '6단계 중 3단계, 가능 여부 확인, 끝남',
    );
    expect(
      tester.getSemantics(find.byKey(const Key('task-step-4'))).label,
      '6단계 중 4단계, 내 승인, 지금',
    );
    expect(
      tester.getSemantics(find.byKey(const Key('task-step-6'))).label,
      '6단계 중 6단계, 결과 보고, 대기',
    );
    handle.dispose();
  });

  testWidgets('step timeline hides the steps after the first canceled one', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(KolbiStepTimeline(steps: taskSteps(task(status: 'canceled')))),
    );
    expect(find.byKey(const Key('task-step-4')), findsOneWidget);
    expect(find.text('멈췄어요'), findsOneWidget);
    expect(find.byKey(const Key('task-step-5')), findsNothing);
    expect(find.byKey(const Key('task-step-6')), findsNothing);
    // The cancel buttons on the detail screen read "취소"; the timeline never draws that word.
    expect(find.text('취소'), findsNothing);
  });

  testWidgets('tab badge shows the count, 9+ from ten, nothing at zero', (
    tester,
  ) async {
    expect(KolbiTabBadge.labelFor(0), isNull);
    expect(KolbiTabBadge.labelFor(2), '2');
    expect(KolbiTabBadge.labelFor(9), '9');
    expect(KolbiTabBadge.labelFor(10), '9+');
    expect(KolbiTabBadge.labelFor(11), '9+');

    await tester.pumpWidget(
      host(const KolbiTabBadge(count: 11, child: Icon(Icons.inbox))),
    );
    expect(find.text('9+'), findsOneWidget);
    await tester.pumpWidget(
      host(const KolbiTabBadge(count: 0, child: Icon(Icons.inbox))),
    );
    expect(find.byType(Badge), findsNothing);
    expect(find.byIcon(Icons.inbox), findsOneWidget);
  });

  testWidgets('briefing card shows title, message and a link', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      host(
        KolbiBriefingCard(
          title: '오늘 중요한 일이 3개 있어요.',
          message: '라 파스타가 답을 기다려요.',
          linkLabel: '업무 보기 →',
          onLink: () => tapped++,
        ),
      ),
    );
    expect(find.text('오늘 중요한 일이 3개 있어요.'), findsOneWidget);
    expect(find.text('라 파스타가 답을 기다려요.'), findsOneWidget);
    await tester.tap(find.text('업무 보기 →'));
    expect(tapped, 1);
  });

  testWidgets(
    'presenter registry finds registered kinds and degrades unknown ones',
    (tester) async {
      final presenters = TaskKindPresenters()..register(const _FakePresenter());
      expect(
        () => presenters.register(const _FakePresenter()),
        throwsA(isA<DuplicateTaskKindError>()),
      );
      final catalog = TaskKindCatalog()..register(const CallTaskKind());

      expect(
        presenters.presenterFor(catalog.resolve(null)),
        isA<_FakePresenter>(),
      );
      final unknown = presenters.presenterFor(catalog.resolve('web'));
      expect(unknown, isA<UnknownKindPresenter>());

      var tapped = 0;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) =>
                unknown.buildRow(context, task(), onTap: () => tapped++),
          ),
        ),
      );
      expect(find.byKey(const Key('kind-unknown-row')), findsOneWidget);
      expect(find.text('이 앱에서 아직 볼 수 없는 작업이에요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('kind-unknown-row')));
      expect(tapped, 1);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => unknown.buildDetail(context, 't'),
          ),
        ),
      );
      expect(find.byType(MessageView), findsOneWidget);
      expect(find.text('이 작업은 앱을 업데이트하면 볼 수 있어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
