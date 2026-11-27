import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../application/calls_controller.dart';
import 'trust_notice.dart';
import 'widgets/approval_card.dart';
import 'widgets/follow_up_actions.dart';

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
        if (mounted) scrollToOffset(_scroll, 0, motionDuration(context, AppMotion.slow));
      });
      return;
    }
    if (next == null || !next.status.isOngoing) return;
    if ((previous?.transcript.length ?? 0) == next.transcript.length) return;
    if (!_scroll.hasClients) return;
    final nearBottom = _scroll.position.maxScrollExtent - _scroll.offset < 240;
    if (!nearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final duration = motionDuration(context, AppMotion.medium);
      scrollToOffset(_scroll, _scroll.position.maxScrollExtent, duration);
      // The list lays out lazily, so its estimated end moves once the last lines are built; settle on the real end.
      Future<void>.delayed(duration, () => _settleAtBottom(3));
    });
  }

  void _settleAtBottom(int frames) {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels != position.maxScrollExtent) position.jumpTo(position.maxScrollExtent);
    if (frames > 1) WidgetsBinding.instance.addPostFrameCallback((_) => _settleAtBottom(frames - 1));
  }

  /// Which button is running; it shows progress while every action button is disabled (REQ-007).
  String? _busyAction;

  Future<void> _run(String action, Future<void> Function() run) async {
    setState(() {
      _busy = true;
      _busyAction = action;
    });
    await runWithFeedback(context, run);
    if (mounted) {
      setState(() {
        _busy = false;
        _busyAction = null;
      });
    }
  }

  Widget _label(String action, Widget label) => _busyAction == action
      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
      : label;

  /// SPEC-FOLLOWUP-001 REQ-014: the first call on a device waits for the trust notice.
  Future<void> _approvePlan(CallTask task) async {
    if (!await ensureTrustAcknowledged(context, ref) || !mounted) return;
    await _run('start', () => _calls.approvePlan(task.id, openingLine: _editedOpeningLine));
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
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xxl),
          children: [
            // SPEC-SHELL-001 REQ-010: the six steps on top; everything below is unchanged.
            KolbiStepTimeline(key: const Key('task-steps'), steps: taskSteps(task)),
            const SizedBox(height: AppSpace.md),
            _CallHeader(task: task),
            const SizedBox(height: AppSpace.lg),
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
                SizedBox(width: AppSpace.xl, height: AppSpace.xl, child: CircularProgressIndicator(strokeWidth: 2.5)),
                SizedBox(width: AppSpace.md),
                Expanded(child: Text('어떻게 통화할지 계획을 세우고 있어요…')),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _GoalCard(task: task),
        ];
      case TaskStatus.awaitingApproval:
        return [
          if (task.autoStartBlocked case final blocked?) ...[
            _AutoStartBlockedCard(blocked: blocked),
            const SizedBox(height: AppSpace.md),
          ],
          _GoalCard(task: task),
          const SizedBox(height: AppSpace.md),
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
                  SizedBox(width: AppSpace.xl, height: AppSpace.xl, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  SizedBox(width: AppSpace.md),
                  Text('통화 결과를 정리하고 있어요…'),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          transcript ??
              (task.status == TaskStatus.inProgress
                  ? const MessageView(
                      icon: Icons.forum_outlined,
                      title: '대화를 기다리고 있어요',
                      message: '대화가 시작되면 여기에 실시간으로 보여드려요.',
                    )
                  : const MessageView(
                      icon: Icons.phone_in_talk_outlined,
                      title: '대화를 기다리고 있어요',
                      message: '상대방이 전화를 받으면 대화가 여기에 나타나요.',
                    )),
          // SPEC-FOLLOWUP-001 REQ-015. Below the transcript so it never pushes live lines or the header down.
          if (task.status.isLiveCall) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Text(liveCallTrustLine, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ],
        ];
      case TaskStatus.completed || TaskStatus.failed || TaskStatus.canceled:
        return [
          // REQ-013: the follow-up actions sit in the result card's action row, right under the result.
          OutcomeCard(
            task: task,
            actions: FollowUpActions(task: task),
          ),
          if (task.approvals.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            _ApprovalHistory(approvals: task.approvals),
          ],
          const SizedBox(height: AppSpace.md),
          _GoalCard(task: task),
          if (transcript != null) ...[const SizedBox(height: AppSpace.md), transcript],
        ];
    }
  }

  List<Widget> _actions(CallTask task) {
    final danger = Theme.of(context).colorScheme.error;
    return switch (task.status) {
      TaskStatus.planning => [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => _run('cancel', () => _calls.cancel(task.id)),
            child: _label('cancel', const Text('취소')),
          ),
        ),
      ],
      TaskStatus.awaitingApproval => [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => _run('cancel', () => _calls.cancel(task.id)),
            child: _label('cancel', const Text('취소')),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _approvePlan(task),
            icon: _label('start', const Icon(Icons.call)),
            label: const Text('이대로 전화 걸기'),
          ),
        ),
      ],
      TaskStatus.dialing || TaskStatus.ringing || TaskStatus.inProgress => [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: danger, foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: _busy ? null : () => _run('hangup', () => _calls.cancel(task.id)),
            icon: _label('hangup', const Icon(Icons.call_end)),
            label: const Text('통화 끊기'),
          ),
        ),
      ],
      TaskStatus.summarizing => const [],
      TaskStatus.completed || TaskStatus.failed || TaskStatus.canceled => const [],
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
    // REQ-011: with enlarged text the pinned area never grows past half the screen, and at normal size never past
    // two thirds; beyond that it scrolls inside, so the transcript above always keeps some room.
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1;
    return SafeArea(
      child: ResponsiveBody(
        shrinkHeight: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * (enlarged ? 1 / 2 : 2 / 3)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (top != null)
                  AnimatedSize(
                    duration: motionDuration(context, AppMotion.medium),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: top,
                    ),
                  ),
                if (children.isNotEmpty) Row(children: children),
              ],
            ),
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
      color: live ? scheme.live.background : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: live ? scheme.live.accent : scheme.primaryContainer,
              child: Icon(
                live ? Icons.phone_in_talk_rounded : Icons.storefront_rounded,
                color: live ? scheme.live.background : scheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatPhone(task.phoneNumber),
                    style: theme.textTheme.titleMedium?.copyWith(color: live ? scheme.live.foreground : null),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(task.status, needsApproval: task.pendingApproval != null),
                      if (task.status == TaskStatus.inProgress && task.connectedAt != null)
                        _CallTimer(since: task.connectedAt!),
                      if (task.isSimulated)
                        Text(
                          '시뮬레이션',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: live ? scheme.live.foreground : scheme.tertiary,
                          ),
                        ),
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

/// SPEC-INTAKE-001 REQ-023: the server could not start the call the user confirmed. The reason uses the app's
/// existing error wording for known codes and the server's message otherwise; manual start stays available below.
class _AutoStartBlockedCard extends StatelessWidget {
  const _AutoStartBlockedCard({required this.blocked});
  final AutoStartBlocked blocked;

  @override
  Widget build(BuildContext context) {
    final reason = ApiException(blocked.code, blocked.message).userMessage;
    return SectionCard(icon: Icons.info_outline_rounded, tone: CardTone.caution, child: Text('바로 걸지 못했어요: $reason'));
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
          Text(task.goal, style: theme.textTheme.bodyLarge),
          if (task.context?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpace.md),
            Text('알려줘도 되는 정보', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpace.xs),
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
          child: Text(
            '"$openingLine"',
            style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, height: 1.5),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        SectionCard(title: '통화 순서', icon: Icons.route_outlined, child: BulletList(plan.steps, numbered: true)),
        const SizedBox(height: AppSpace.md),
        SectionCard(title: '물어볼 것', icon: Icons.help_outline_rounded, child: BulletList(plan.questionsToAsk)),
        if (plan.approvalPoints.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: '이럴 땐 통화 중에 먼저 물어볼게요',
            icon: Icons.pan_tool_alt_outlined,
            child: BulletList(plan.approvalPoints),
          ),
        ],
        if (plan.fallback.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
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
              leading: Icon(switch (a.status) {
                ApprovalStatus.approved => Icons.check_circle,
                ApprovalStatus.rejected => Icons.cancel,
                _ => Icons.timer_off_outlined,
              }, color: a.status == ApprovalStatus.approved ? scheme.primary : scheme.error),
              title: Text(a.question),
              subtitle: Text(
                [
                  switch (a.status) {
                    ApprovalStatus.approved => '승인함',
                    ApprovalStatus.rejected => '거절함',
                    ApprovalStatus.expired => '시간 초과로 진행 안 함',
                    ApprovalStatus.pending => '대기 중',
                  },
                  if (a.userComment != null && a.userComment!.isNotEmpty) '안내: ${a.userComment}',
                ].join('\n'),
              ),
              isThreeLine: a.userComment != null && a.userComment!.isNotEmpty,
            ),
        ],
      ),
    );
  }
}
