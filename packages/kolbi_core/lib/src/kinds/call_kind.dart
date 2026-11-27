import '../models/call_models.dart';
import '../tasks/task_steps.dart';
import 'task_kind.dart';

/// The phone call kind, the only one this SPEC registers.
class CallTaskKind implements TaskKindDescriptor {
  const CallTaskKind();

  @override
  String get id => kCallKindId;

  @override
  bool get isKnown => true;

  /// Same wording as the status chip: a pending approval wins over the status.
  @override
  String statusLabel(CallTask task) =>
      task.pendingApproval != null ? '승인 대기' : task.status.label;

  @override
  Object? parseDetails(Map<String, dynamic> json) => null;

  @override
  List<TaskStep> steps(CallTask task) => taskSteps(task);
}
