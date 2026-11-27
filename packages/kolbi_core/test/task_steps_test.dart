// SPEC-SHELL-001 AC-009: design.md D2.2, one test per row. "—" cells are tried with at least two values.
import 'package:kolbi_core/kolbi_core.dart';
import 'package:test/test.dart';

import 'support/tasks.dart';

const d = TaskStepState.done;
const n = TaskStepState.current;
const w = TaskStepState.waiting;
const f = TaskStepState.failed;
const s = TaskStepState.skipped;
const c = TaskStepState.canceled;

final pending = approval();
final answered = approval(id: 'a0', status: 'approved');

/// Every combination of the "—" cells a row leaves open.
List<CallTask> variants(
  String status, {
  List<bool> pendingValues = const [false, true],
  List<bool> answeredValues = const [false, true],
  List<bool> transcriptValues = const [false, true],
  List<bool> outcomeValues = const [false, true],
}) => [
  for (final p in pendingValues)
    for (final a in answeredValues)
      for (final t in transcriptValues)
        for (final o in outcomeValues)
          task(
            status: status,
            approvals: [if (a) answered, if (p) pending],
            transcript: t,
            outcome: o ? outcome() : null,
          ),
];

void expectRow(List<CallTask> tasks, List<TaskStepState> expected) {
  expect(tasks.length, greaterThanOrEqualTo(1));
  for (final t in tasks) {
    final steps = taskSteps(t);
    expect(
      steps.map((step) => step.state).toList(),
      expected,
      reason:
          '${t.status} pending=${t.pendingApproval != null} approvals=${t.approvals.length} '
          'transcript=${t.transcript.isNotEmpty} outcome=${t.outcome != null}',
    );
  }
}

void main() {
  test(
    'row 1 planning',
    () => expectRow(variants('planning'), [n, w, w, w, w, w]),
  );

  test(
    'row 2 awaiting approval',
    () => expectRow(variants('awaiting_approval'), [d, d, w, w, w, w]),
  );

  test('row 3 dialing and ringing without a pending approval', () {
    for (final status in ['dialing', 'ringing']) {
      expectRow(variants(status, pendingValues: [false]), [d, d, n, w, w, w]);
    }
  });

  test('row 4 in progress, nothing pending or answered', () {
    expectRow(
      variants('in_progress', pendingValues: [false], answeredValues: [false]),
      [d, d, n, w, w, w],
    );
  });

  test('row 5 in progress with an answered approval', () {
    expectRow(
      variants('in_progress', pendingValues: [false], answeredValues: [true]),
      [d, d, d, d, n, w],
    );
  });

  test('row 6 live call with a pending approval', () {
    for (final status in ['dialing', 'ringing', 'in_progress']) {
      expectRow(variants(status, pendingValues: [true]), [d, d, d, n, w, w]);
    }
  });

  test('row 7 summarizing with an answered approval', () {
    expectRow(
      variants('summarizing', pendingValues: [false], answeredValues: [true]),
      [d, d, d, d, n, w],
    );
  });

  test('row 8 summarizing without an answered approval', () {
    expectRow(
      variants('summarizing', pendingValues: [false], answeredValues: [false]),
      [d, d, d, s, n, w],
    );
  });

  test('row 9 completed with an answered approval and a result', () {
    expectRow(
      variants(
        'completed',
        pendingValues: [false],
        answeredValues: [true],
        outcomeValues: [true],
      ),
      [d, d, d, d, d, d],
    );
  });

  test('row 10 completed without an answered approval, with a result', () {
    expectRow(
      variants(
        'completed',
        pendingValues: [false],
        answeredValues: [false],
        outcomeValues: [true],
      ),
      [d, d, d, s, d, d],
    );
  });

  test('row 11 completed without a result', () {
    expectRow(
      variants(
        'completed',
        pendingValues: [false],
        answeredValues: [true],
        outcomeValues: [false],
      ),
      [d, d, d, d, d, w],
    );
    expectRow(
      variants(
        'completed',
        pendingValues: [false],
        answeredValues: [false],
        outcomeValues: [false],
      ),
      [d, d, d, s, d, w],
    );
  });

  test('row 12 failed without a transcript', () {
    expectRow(variants('failed', transcriptValues: [false]), [
      d,
      d,
      f,
      w,
      w,
      w,
    ]);
  });

  test('row 13 failed with a transcript and an answered approval', () {
    expectRow(
      variants('failed', answeredValues: [true], transcriptValues: [true]),
      [d, d, d, d, f, w],
    );
  });

  test('row 14 failed with a transcript and no answered approval', () {
    expectRow(
      variants(
        'failed',
        pendingValues: [false],
        answeredValues: [false],
        transcriptValues: [true],
      ),
      [d, d, d, s, f, w],
    );
  });

  test('row 15 canceled without a transcript', () {
    expectRow(variants('canceled', transcriptValues: [false]), [
      d,
      d,
      c,
      c,
      c,
      c,
    ]);
  });

  test('row 16 canceled with a transcript', () {
    expectRow(variants('canceled', transcriptValues: [true]), [
      d,
      d,
      d,
      c,
      c,
      c,
    ]);
  });

  test('steps carry the six names in order and the D2.3 wording', () {
    final steps = taskSteps(task(approvals: [pending]));
    expect(steps.map((step) => step.id.label).toList(), [
      '요청 이해',
      '연락처 확인',
      '가능 여부 확인',
      '내 승인',
      '확정',
      '결과 보고',
    ]);
    expect(steps.map((step) => step.number).toList(), [1, 2, 3, 4, 5, 6]);
    expect(steps.map((step) => step.description).toList(), [
      '부탁을 이해했어요',
      '연락처를 확인했어요',
      '통화가 연결됐어요',
      '응답을 기다리고 있어요',
      '다음 순서예요',
      '다음 순서예요',
    ]);

    String describe(CallTask t, int number) =>
        taskSteps(t)[number - 1].description;
    expect(describe(task(status: 'planning'), 1), '부탁을 살펴보고 있어요');
    expect(describe(task(), 3), '상대와 통화하고 있어요');
    expect(
      describe(task(status: 'failed', transcript: false), 3),
      '통화가 이어지지 않았어요',
    );
    expect(describe(task(status: 'summarizing'), 5), '결과를 정리하고 있어요');
    expect(describe(task(status: 'failed', transcript: true), 5), '확정하지 못했어요');
    expect(describe(task(status: 'completed', outcome: outcome()), 5), '확정했어요');
    expect(
      describe(task(status: 'completed', outcome: outcome()), 6),
      '결과를 정리했어요',
    );
    expect(
      describe(task(status: 'completed', outcome: outcome()), 4),
      '확인할 일이 없었어요',
    );
    expect(describe(task(status: 'canceled'), 4), '멈췄어요');
    final rejected = task(
      status: 'completed',
      approvals: [approval(status: 'rejected')],
      outcome: outcome(),
    );
    expect(describe(rejected, 4), '답했어요');
    final expired = task(
      status: 'completed',
      approvals: [approval(status: 'expired')],
      outcome: outcome(),
    );
    expect(describe(expired, 4), '응답 시간이 지났어요');
    expect(TaskStepState.values.map((state) => state.label).toList(), [
      '끝남',
      '지금',
      '대기',
      '실패',
      '건너뜀',
      '취소',
    ]);
  });
}
