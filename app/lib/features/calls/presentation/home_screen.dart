import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/network/live_channel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../application/calls_controller.dart';
import '../data/calls_repository.dart';
import '../domain/call_models.dart';
import 'call_templates.dart';
import 'widgets/status_chip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(sortedTasksProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CallMate'),
        actions: [
          const _LiveIndicator(),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: tasks.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => context.push(settings.hasProfile ? '/calls/new' : '/settings'),
              icon: const Icon(Icons.add_call),
              label: const Text('전화 맡기기'),
            )
          : null,
      body: ResponsiveBody(
        child: switch (tasks) {
          AsyncData(:final value) => _TaskList(tasks: value, hasProfile: settings.hasProfile),
          AsyncError(:final error) => MessageView(
              icon: Icons.cloud_off_rounded,
              title: '서버와 연결되지 않았어요',
              message: describeError(error),
              actions: [
                OutlinedButton(onPressed: () => context.push('/settings'), child: const Text('서버 설정')),
                FilledButton(onPressed: () => ref.invalidate(callsControllerProvider), child: const Text('다시 시도')),
              ],
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _LiveIndicator extends ConsumerWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(liveStatusProvider);
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      LiveStatus.connected => (scheme.callLive, '실시간 연결됨'),
      LiveStatus.connecting => (scheme.warning, '연결 중'),
      LiveStatus.disconnected => (scheme.error, '연결 끊김 · 재시도 중'),
    };
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.hasProfile});

  final List<CallTask> tasks;
  final bool hasProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ongoing = tasks.where((t) => !t.status.isTerminal).toList();
    final finished = tasks.where((t) => t.status.isTerminal).toList();
    final isSimulated = ref.watch(serverInfoProvider).value?.realCalls == false;

    return RefreshIndicator(
      onRefresh: () => ref.read(callsControllerProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          if (isSimulated) const _SimulationBanner(),
          if (!hasProfile) const _ProfilePrompt(),
          if (tasks.isEmpty) const _EmptyState(),
          if (ongoing.isNotEmpty) ...[
            const _SectionHeader('진행 중'),
            for (final task in ongoing) _TaskTile(task: task),
          ],
          if (finished.isNotEmpty) ...[
            const _SectionHeader('지난 통화'),
            for (final task in finished) _TaskTile(task: task),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
    );
  }
}

class _SimulationBanner extends StatelessWidget {
  const _SimulationBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '시뮬레이션 모드예요. 실제 전화는 걸리지 않고, 가상의 상대와 통화가 진행돼요.',
              style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        title: '먼저 내 이름을 알려주세요',
        icon: Icons.badge_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('AI 비서가 "○○님을 대신해 전화드렸어요"라고 소개할 때 사용해요.'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: () => context.push('/settings'), child: const Text('내 정보 입력')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const MessageView(
            icon: Icons.support_agent_rounded,
            title: '귀찮은 전화, 대신 걸어드릴게요',
            message: '예약, 문의, 요금 할인, 환불 요청까지.\n목적만 알려주시면 AI 비서가 통화하고 결과를 정리해 드려요.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final template in callTemplates)
                ActionChip(
                  avatar: Icon(template.icon, size: 18, color: theme.colorScheme.primary),
                  label: Text(template.label),
                  onPressed: () => context.push('/calls/new', extra: template),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final CallTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsApproval = task.pendingApproval != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/calls/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    task.status.isLiveCall ? Icons.phone_in_talk_rounded : Icons.call_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.targetName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        task.outcome?.summary ?? task.goal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(task.status, needsApproval: needsApproval),
                    const SizedBox(height: 6),
                    Text(formatRelative(task.createdAt), style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
