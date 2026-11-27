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

/// SCR-T01 "나의 업무": three counts, then 승인 요청 / 진행 중 / 반복 (SPEC-SHELL-001 REQ-011, REQ-012, design.md D3).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    return Scaffold(
      key: const Key('tasks-screen'),
      appBar: AppBar(title: const Text('나의 업무')),
      body: ResponsiveBody(
        child: switch (tasks) {
          // Riverpod retries a failed load by itself, so an error can arrive while loading: show it
          // whenever there is no list yet.
          AsyncValue(:final value?) when value.isEmpty => MessageView(
            icon: Icons.assignment_outlined,
            title: '아직 맡긴 일이 없어요',
            message: '부탁할 일을 비서에게 말해 보세요.',
            actions: [
              FilledButton(
                onPressed: () => openAssistant(GoRouter.of(context)),
                child: const Text('비서에게 맡기기'),
              ),
            ],
          ),
          AsyncValue(hasValue: true) => const _TaskGroupsView(),
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

class _TaskGroupsView extends ConsumerWidget {
  const _TaskGroupsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(taskGroupsProvider);
    final theme = Theme.of(context);
    Widget row(CallTask task) => presenterForTask(ref, task).buildRow(
      context,
      task,
      onTap: () => openTask(GoRouter.of(context), task.id),
    );

    return RefreshIndicator(
      onRefresh: () => refreshTasks(ref),
      child: ListView(
        controller: TabScrollScope.rootControllerOf(context, AppTab.tasks),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.xs,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _CountCell(
                  key: const Key('tasks-count-ongoing'),
                  label: '진행 중',
                  value: groups.ongoing.length,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _CountCell(
                  key: const Key('tasks-count-approvals'),
                  label: '승인 대기',
                  value: groups.approvals.length,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _CountCell(
                  key: const Key('tasks-count-done-today'),
                  label: '오늘 완료',
                  value: groups.completedToday,
                ),
              ),
            ],
          ),
          if (groups.approvals.isNotEmpty) ...[
            const _GroupHeader('승인 요청', key: Key('tasks-group-approvals')),
            for (final task in groups.approvals) row(task),
          ],
          if (groups.ongoing.isNotEmpty) ...[
            const _GroupHeader('진행 중', key: Key('tasks-group-ongoing')),
            for (final task in groups.ongoing) row(task),
          ],
          const _GroupHeader('반복', key: Key('tasks-group-routines')),
          Text(
            '반복할 일을 만들면 여기에 모여요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Center(
            child: TextButton(
              onPressed: () => openTab(GoRouter.of(context), AppTab.history),
              child: const Text('끝난 업무는 기록에서 볼 수 있어요'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCell extends StatelessWidget {
  const _CountCell({super.key, required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: theme.textTheme.headlineSmall),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xs,
        AppSpace.xl,
        AppSpace.xs,
        AppSpace.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
