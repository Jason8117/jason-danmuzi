import 'package:meta/meta.dart';

import '../models/call_models.dart';

/// The six steps of one task (SPEC-SHELL-001 REQ-009, design.md D2.1).
enum TaskStepId {
  understand('요청 이해'),
  contact('연락처 확인'),
  availability('가능 여부 확인'),
  approval('내 승인'),
  confirm('확정'),
  report('결과 보고');

  const TaskStepId(this.label);
  final String label;
}

/// Where one step stands.
enum TaskStepState {
  done('끝남'),
  current('지금'),
  waiting('대기'),
  failed('실패'),
  skipped('건너뜀'),
  canceled('취소');

  const TaskStepState(this.label);
  final String label;
}

@immutable
class TaskStep {
  const TaskStep({
    required this.id,
    required this.state,
    required this.description,
  });

  final TaskStepId id;
  final TaskStepState state;

  /// The fixed line under the step (design.md D2.3); it never repeats other text on the detail screen.
  final String description;

  /// 1 .. 6.
  int get number => id.index + 1;
}

// @MX:ANCHOR: [AUTO] The one place a task's six step states are decided; the timeline and every kind's steps use it.
// @MX:REASON: The result must equal every row of design.md D2.2 (AC-009 tests it row by row); change the table first.
// @MX:SPEC: SPEC-SHELL-001 REQ-009
/// The six steps of [task], per design.md D2.2.
List<TaskStep> taskSteps(CallTask task) {
  const d = TaskStepState.done;
  const n = TaskStepState.current;
  const w = TaskStepState.waiting;
  const f = TaskStepState.failed;
  const s = TaskStepState.skipped;
  const c = TaskStepState.canceled;

  final pending = task.pendingApproval != null;
  final answeredApprovals = task.approvals.where((a) => !a.isPending).toList();
  final answered = answeredApprovals.isNotEmpty;
  final talked = task.transcript.isNotEmpty;
  // ④ when nothing was asked during the call.
  final mine = answered ? d : s;

  final states = switch (task.status) {
    TaskStatus.planning => [n, w, w, w, w, w],
    TaskStatus.awaitingApproval => [d, d, w, w, w, w],
    TaskStatus.dialing ||
    TaskStatus.ringing ||
    TaskStatus.inProgress when pending => [d, d, d, n, w, w],
    TaskStatus.inProgress when answered => [d, d, d, d, n, w],
    TaskStatus.dialing ||
    TaskStatus.ringing ||
    TaskStatus.inProgress => [d, d, n, w, w, w],
    TaskStatus.summarizing => [d, d, d, mine, n, w],
    TaskStatus.completed => [d, d, d, mine, d, task.outcome != null ? d : w],
    // OD-8: whether the call connected is read from the transcript (design.md D2.2 rows 12-14).
    TaskStatus.failed => talked ? [d, d, d, mine, f, w] : [d, d, f, w, w, w],
    TaskStatus.canceled => talked ? [d, d, d, c, c, c] : [d, d, c, c, c, c],
  };

  final approvalDone =
      answeredApprovals.isNotEmpty &&
          answeredApprovals.last.status == ApprovalStatus.expired
      ? '응답 시간이 지났어요'
      : '답했어요';

  return [
    for (final id in TaskStepId.values)
      TaskStep(
        id: id,
        state: states[id.index],
        description: _describe(id, states[id.index], approvalDone),
      ),
  ];
}

String _describe(TaskStepId id, TaskStepState state, String approvalDone) =>
    switch (state) {
      TaskStepState.skipped => '확인할 일이 없었어요',
      TaskStepState.waiting => '다음 순서예요',
      TaskStepState.canceled => '멈췄어요',
      TaskStepState.done => switch (id) {
        TaskStepId.understand => '부탁을 이해했어요',
        TaskStepId.contact => '연락처를 확인했어요',
        TaskStepId.availability => '통화가 연결됐어요',
        TaskStepId.approval => approvalDone,
        TaskStepId.confirm => '확정했어요',
        TaskStepId.report => '결과를 정리했어요',
      },
      TaskStepState.current => switch (id) {
        TaskStepId.understand => '부탁을 살펴보고 있어요',
        TaskStepId.availability => '상대와 통화하고 있어요',
        TaskStepId.approval => '응답을 기다리고 있어요',
        _ => '결과를 정리하고 있어요',
      },
      TaskStepState.failed =>
        id == TaskStepId.availability ? '통화가 이어지지 않았어요' : '확정하지 못했어요',
    };
