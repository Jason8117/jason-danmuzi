import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../application/calls_controller.dart';
import '../domain/call_models.dart';
import 'widgets/approval_card.dart';
import 'widgets/outcome_card.dart';
import 'widgets/status_chip.dart';
import 'widgets/transcript_view.dart';

class CallDetailScreen extends ConsumerStatefulWidget {
  const CallDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends ConsumerState<CallDetailScreen> {
  final _scroll = ScrollController();
  String? _editedOpeningLine;
  bool _busy = false;

  CallsController get _calls => ref.read(callsControllerProvider.notifier);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Follows new transcript lines during a live call unless the user scrolled up to read,
  /// and jumps back to the result summary at the top once the call is over.
  void _followTranscript(CallTask? previous, CallTask? next) {
    if (next != null && next.status.isTerminal && (previous?.status.isOngoing ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      });
      return;
    }
    if (next == null || !next.status.isOngoing) return;
    if ((previous?.transcript.length ?? 0) == next.transcript.length) return;
    if (!_scroll.hasClients) return;
    final nearBottom = _scroll.position.maxScrollExtent - _scroll.offset < 240;
    if (!nearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await runWithFeedback(context, action);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _editOpeningLine(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('첫 인사 수정'),
        content: TextField(controller: controller, minLines: 3, maxLines: 6, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('저장')),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) setState(() => _editedOpeningLine = result);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('통화 기록을 삭제할까요?'),
        content: const Text('대화 내용과 결과 요약이 모두 삭제돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await runWithFeedback(context, () => _calls.delete(widget.taskId));
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CallTask?>(taskProvider(widget.taskId), _followTranscript);
    final task = ref.watch(taskProvider(widget.taskId));
    final loading = ref.watch(callsControllerProvider).isLoading;

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : const MessageView(icon: Icons.search_off_rounded, title: '통화를 찾을 수 없어요', message: '삭제되었거나 다른 서버의 기록이에요.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(task.targetName),
        actions: [
          if (task.status.isTerminal || task.status == TaskStatus.awaitingApproval)
            IconButton(tooltip: '삭제', icon: const Icon(Icons.delete_outline), onPressed: _confirmDelete),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _CallHeader(task: task),
            const SizedBox(height: 16),
            ..._body(task),
          ],
        ),
      ),
      // A pending approval is pinned here rather than in the scrolling list, so
      // following the live transcript can never push it off screen.
      bottomNavigationBar: _ActionBar(
        top: switch (task.pendingApproval) {
          final approval? => ApprovalCard(key: ValueKey(approval.id), taskId: task.id, approval: approval),
          null => null,
        },
        children: _actions(task),
      ),
    );
  }

  List<Widget> _body(CallTask task) {
    final transcript = task.transcript.isEmpty
        ? null
        : SectionCard(
            title: '대화 내용',
            icon: Icons.forum_outlined,
            child: TranscriptView(entries: task.transcript, calleeName: task.targetName),
          );

    switch (task.status) {
      case TaskStatus.planning:
        return [
          const SectionCard(
            child: Row(
              children: [
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                SizedBox(width: 14),
                Expanded(child: Text('어떻게 통화할지 계획을 세우고 있어요…')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GoalCard(task: task),
        ];
      case TaskStatus.awaitingApproval:
        return [
          _GoalCard(task: task),
          const SizedBox(height: 12),
          if (task.plan case final plan?)
            _PlanReview(
              plan: plan,
              openingLine: _editedOpeningLine ?? plan.openingLine,
              onEditOpeningLine: () => _editOpeningLine(_editedOpeningLine ?? plan.openingLine),
            ),
        ];
      case TaskStatus.dialing || TaskStatus.ringing || TaskStatus.inProgress || TaskStatus.summarizing:
        return [
          if (task.status == TaskStatus.summarizing) ...[
            const SectionCard(
              child: Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  SizedBox(width: 14),
                  Text('통화 결과를 정리하고 있어요…'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          transcript ??
              SectionCard(
                child: Text(
                  task.status == TaskStatus.inProgress ? '대화가 시작되면 여기에 실시간으로 보여드려요.' : '상대방이 전화를 받으면 대화가 여기에 나타나요.',
                ),
              ),
        ];
      case TaskStatus.completed || TaskStatus.failed || TaskStatus.canceled:
        return [
          OutcomeCard(task: task),
          if (task.approvals.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ApprovalHistory(approvals: task.approvals),
          ],
          const SizedBox(height: 12),
          _GoalCard(task: task),
          if (transcript != null) ...[const SizedBox(height: 12), transcript],
        ];
    }
  }

  List<Widget> _actions(CallTask task) {
    final danger = Theme.of(context).colorScheme.error;
    return switch (task.status) {
      TaskStatus.planning => [
          Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _run(() => _calls.cancel(task.id)), child: const Text('취소'))),
        ],
      TaskStatus.awaitingApproval => [
          Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _run(() => _calls.cancel(task.id)), child: const Text('취소'))),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _run(() => _calls.approvePlan(task.id, openingLine: _editedOpeningLine)),
              icon: const Icon(Icons.call),
              label: const Text('이대로 전화 걸기'),
            ),
          ),
        ],
      TaskStatus.dialing || TaskStatus.ringing || TaskStatus.inProgress => [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: danger),
              onPressed: _busy ? null : () => _run(() => _calls.cancel(task.id)),
              icon: const Icon(Icons.call_end),
              label: const Text('통화 끊기'),
            ),
          ),
        ],
      TaskStatus.summarizing => const [],
      TaskStatus.completed || TaskStatus.failed || TaskStatus.canceled => [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/calls/new', extra: task),
              icon: const Icon(Icons.replay),
              label: const Text('다시 걸기'),
            ),
          ),
        ],
    };
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children, this.top});

  final List<Widget> children;
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && top == null) return const SizedBox.shrink();
    return SafeArea(
      child: ResponsiveBody(
        shrinkHeight: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (top != null) ...[top!, const SizedBox(height: 10)],
              if (children.isNotEmpty) Row(children: children),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallHeader extends StatelessWidget {
  const _CallHeader({required this.task});
  final CallTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live = task.status.isLiveCall;

    return Card(
      color: live ? scheme.callLive.withValues(alpha: 0.1) : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: live ? scheme.callLive : scheme.primaryContainer,
              child: Icon(
                live ? Icons.phone_in_talk_rounded : Icons.storefront_rounded,
                color: live ? Colors.white : scheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatPhone(task.phoneNumber), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusChip(task.status, needsApproval: task.pendingApproval != null),
                      if (task.status == TaskStatus.inProgress && task.connectedAt != null) ...[
                        const SizedBox(width: 10),
                        _CallTimer(since: task.connectedAt!),
                      ],
                      if (task.isSimulated) ...[
                        const SizedBox(width: 8),
                        Text('시뮬레이션', style: theme.textTheme.labelSmall?.copyWith(color: scheme.tertiary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallTimer extends StatefulWidget {
  const _CallTimer({required this.since});
  final DateTime since;

  @override
  State<_CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<_CallTimer> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    return Text(
      formatDuration(elapsed.isNegative ? Duration.zero : elapsed),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.task});
  final CallTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '부탁한 일',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.goal, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          if (task.context?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text('알려줘도 되는 정보', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(task.context!),
          ],
        ],
      ),
    );
  }
}

class _PlanReview extends StatelessWidget {
  const _PlanReview({required this.plan, required this.openingLine, required this.onEditOpeningLine});

  final CallPlan plan;
  final String openingLine;
  final VoidCallback onEditOpeningLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: '첫 인사',
          icon: Icons.record_voice_over_outlined,
          trailing: TextButton(onPressed: onEditOpeningLine, child: const Text('수정')),
          child: Text('"$openingLine"', style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, height: 1.5)),
        ),
        const SizedBox(height: 12),
        SectionCard(title: '통화 순서', icon: Icons.route_outlined, child: BulletList(plan.steps, numbered: true)),
        const SizedBox(height: 12),
        SectionCard(title: '물어볼 것', icon: Icons.help_outline_rounded, child: BulletList(plan.questionsToAsk)),
        if (plan.approvalPoints.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: '이럴 땐 통화 중에 먼저 물어볼게요',
            icon: Icons.pan_tool_alt_outlined,
            color: theme.colorScheme.warning.withValues(alpha: 0.1),
            child: BulletList(plan.approvalPoints),
          ),
        ],
        if (plan.fallback.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(title: '목표를 못 이루면', icon: Icons.alt_route_rounded, child: Text(plan.fallback)),
        ],
      ],
    );
  }
}

class _ApprovalHistory extends StatelessWidget {
  const _ApprovalHistory({required this.approvals});
  final List<ApprovalRequest> approvals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: '통화 중 결정한 것',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: [
          for (final a in approvals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                switch (a.status) {
                  ApprovalStatus.approved => Icons.check_circle,
                  ApprovalStatus.rejected => Icons.cancel,
                  _ => Icons.timer_off_outlined,
                },
                color: a.status == ApprovalStatus.approved ? scheme.primary : scheme.error,
              ),
              title: Text(a.question),
              subtitle: Text(switch (a.status) {
                ApprovalStatus.approved => '승인함',
                ApprovalStatus.rejected => '거절함',
                ApprovalStatus.expired => '시간 초과로 진행 안 함',
                ApprovalStatus.pending => '대기 중',
              }),
            ),
        ],
      ),
    );
  }
}
