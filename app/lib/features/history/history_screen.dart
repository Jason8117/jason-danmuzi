import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../shell/kind_registration.dart';
import '../../shell/navigation.dart';
import '../../shell/routes.dart';
import '../../shell/tab_scaffold.dart';
import '../../shell/task_feed.dart';

/// The result chip of a finished task (SPEC-SHELL-001 design.md D4).
(StatusCategory, String) historyChipOf(CallTask task) => switch (task.status) {
  TaskStatus.failed => (StatusCategory.failed, '실패'),
  TaskStatus.canceled => (StatusCategory.waiting, '취소됨'),
  _ => switch (task.outcome?.result) {
    OutcomeResult.success => (StatusCategory.done, '완료'),
    OutcomeResult.partial => (StatusCategory.waiting, '일부 달성'),
    OutcomeResult.failed => (StatusCategory.failed, '달성 못 함'),
    OutcomeResult.unverified || null => (StatusCategory.waiting, '확인 못 함'),
  },
};

/// The row's result line: the summary's first line, else the status wording (design.md D4).
String historyLineOf(CallTask task) {
  final summary = task.outcome?.summary.trim() ?? '';
  return summary.isEmpty ? task.status.label : summary.split('\n').first;
}

/// SCR-R01: finished tasks by Seoul day, newest first (REQ-014).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    return Scaffold(
      key: const Key('history-screen'),
      appBar: AppBar(title: const Text('기록')),
      body: ResponsiveBody(
        child: switch (tasks) {
          AsyncValue(hasValue: true) => const _HistoryList(),
          AsyncValue(:final error?) => MessageView(
            icon: Icons.cloud_off_rounded,
            title: '서버와 연결되지 않았어요',
            message: describeError(error),
            actions: [
              OutlinedButton(
                onPressed: () => context.pushNamed(RouteNames.settings),
                child: const Text('서버 설정'),
              ),
              FilledButton(
                onPressed: () => reloadTasks(ref),
                child: const Text('다시 시도'),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(historyDaysProvider);
    if (days.isEmpty) {
      return const MessageView(
        icon: Icons.history_rounded,
        title: '아직 끝난 업무가 없어요',
        message: '끝난 업무가 날짜별로 여기에 모여요.',
      );
    }
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => refreshTasks(ref),
      child: ListView(
        controller: TabScrollScope.rootControllerOf(context, AppTab.history),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.xs,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          for (final day in days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xs,
                AppSpace.xl,
                AppSpace.xs,
                AppSpace.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  day.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            for (final task in day.tasks)
              presenterForTask(ref, task).buildRow(
                context,
                task,
                onTap: () => openTask(GoRouter.of(context), task.id),
                trailing: switch (historyChipOf(task)) {
                  (final category, final label) => StatusChip.category(
                    category,
                    label,
                  ),
                },
                subtitle: historyLineOf(task),
              ),
          ],
        ],
      ),
    );
  }
}
