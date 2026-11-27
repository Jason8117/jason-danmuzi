import 'package:meta/meta.dart';

import '../follow_up.dart' show seoulOffset;
import '../models/call_models.dart';

/// The tasks tab, today and the badge, computed once (SPEC-SHELL-001 REQ-013, design.md D3).
@immutable
class TaskGroups {
  const TaskGroups({
    required this.approvals,
    required this.ongoing,
    required this.completedToday,
  });

  /// 승인 요청: plan approvals and unfinished tasks with a pending approval, soonest expiry first.
  final List<CallTask> approvals;

  /// 진행 중: unfinished tasks that are not approval requests, most recently updated first.
  final List<CallTask> ongoing;

  /// 반복: always empty in this SPEC.
  List<CallTask> get routines => const [];

  /// Tasks completed on the Seoul day of `now`.
  final int completedToday;

  /// The tasks tab badge = 승인 요청 count = today's "확인이 필요해요" count.
  int get badgeCount => approvals.length;

  /// "오늘 중요한 일이 N개 있어요."
  int get briefingCount => approvals.length + ongoing.length;

  /// Approval requests waiting on an in-call question; the same set as `pendingApprovalsProvider`
  /// without finished tasks.
  List<CallTask> get inCallApprovals => [
    for (final t in approvals)
      if (t.pendingApproval != null) t,
  ];
}

/// The calendar day of [time] in Seoul, as a UTC midnight.
DateTime _seoulDay(DateTime time) {
  final seoul = time.toUtc().add(seoulOffset);
  return DateTime.utc(seoul.year, seoul.month, seoul.day);
}

int _recentFirst(CallTask a, CallTask b) => b.updatedAt.compareTo(a.updatedAt);

/// Whether [task] belongs in 승인 요청 (design.md D3). The only place this rule is written.
bool isApprovalRequest(CallTask task) =>
    !task.status.isTerminal &&
    (task.status == TaskStatus.awaitingApproval ||
        task.pendingApproval != null);

// @MX:ANCHOR: [AUTO] Badge, tasks tab groups and today's lists all come from here (REQ-013).
// @MX:REASON: The three counts must stay equal; never re-derive the approval rule elsewhere (AC-013).
// @MX:SPEC: SPEC-SHELL-001 REQ-011, REQ-013
TaskGroups groupTasks(Iterable<CallTask> tasks, {required DateTime now}) {
  final approvals = <CallTask>[];
  final ongoing = <CallTask>[];
  var completedToday = 0;
  final today = _seoulDay(now);
  for (final task in tasks) {
    if (isApprovalRequest(task)) {
      approvals.add(task);
    } else if (!task.status.isTerminal) {
      ongoing.add(task);
    } else if (task.status == TaskStatus.completed &&
        _seoulDay(task.updatedAt) == today) {
      completedToday++;
    }
  }
  approvals.sort((a, b) {
    final ea = a.pendingApproval?.expiresAt;
    final eb = b.pendingApproval?.expiresAt;
    if (ea != null && eb != null) return ea.compareTo(eb);
    if (ea != null) return -1;
    if (eb != null) return 1;
    return _recentFirst(a, b);
  });
  ongoing.sort(_recentFirst);
  return TaskGroups(
    approvals: approvals,
    ongoing: ongoing,
    completedToday: completedToday,
  );
}

/// One day of finished tasks in the history tab.
@immutable
class HistoryDay {
  const HistoryDay({
    required this.day,
    required this.label,
    required this.tasks,
  });

  /// The Seoul calendar day, as a UTC midnight.
  final DateTime day;

  /// "오늘 · 11월 26일", "어제 · 11월 25일" or "11월 24일".
  final String label;
  final List<CallTask> tasks;
}

/// Finished tasks by Seoul day, newest day first and newest task first within a day (REQ-014, design.md D3).
List<HistoryDay> groupHistory(
  Iterable<CallTask> tasks, {
  required DateTime now,
}) {
  final finished = [
    for (final t in tasks)
      if (t.status.isTerminal) t,
  ]..sort(_recentFirst);
  final today = _seoulDay(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final byDay = <DateTime, List<CallTask>>{};
  for (final task in finished) {
    byDay.putIfAbsent(_seoulDay(task.updatedAt), () => []).add(task);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      HistoryDay(
        day: day,
        label: switch (day) {
          _ when day == today => '오늘 · ${day.month}월 ${day.day}일',
          _ when day == yesterday => '어제 · ${day.month}월 ${day.day}일',
          _ => '${day.month}월 ${day.day}일',
        },
        tasks: byDay[day]!,
      ),
  ];
}
