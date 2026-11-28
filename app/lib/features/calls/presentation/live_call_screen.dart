import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shell/navigation.dart';
import '../application/calls_controller.dart';
import 'widgets/approval_card.dart';
import 'widgets/call_timer.dart';

/// SCR-T08, `/calls/:id/live` outside the tab shell (SPEC-ASSIST-001 REQ-011): the call in immersive dark —
/// hang-up, who is on the line, live captions — with a pending approval pinned below in the light theme.
/// It is pushed over the task screen and pops back to it once the call is no longer live.
class LiveCallScreen extends ConsumerStatefulWidget {
  const LiveCallScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends ConsumerState<LiveCallScreen> {
  final _scroll = ScrollController();
  bool _busy = false;
  bool _leaving = false;
  bool _placed = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The call ended (summarizing or later) or the task is gone: back to the task screen, once.
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) closeLiveCall(GoRouter.of(context), widget.taskId);
    });
  }

  void _onTask(CallTask? previous, CallTask? next) {
    if (next == null || !next.status.isLiveCall) return _leave();
    if ((previous?.transcript.length ?? 0) == next.transcript.length) return;
    // Follow new lines unless the user scrolled up to read.
    if (!_scroll.hasClients) return;
    final nearBottom = _scroll.position.maxScrollExtent - _scroll.offset < 240;
    if (nearBottom) _toEnd(animate: true);
  }

  void _toEnd({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      final duration = motionDuration(context, AppMotion.medium);
      if (!animate || duration == Duration.zero) {
        _scroll.jumpTo(end);
      } else {
        scrollToOffset(_scroll, end, duration);
      }
    });
  }

  Future<void> _hangUp(CallTask task) async {
    setState(() => _busy = true);
    await runWithFeedback(
      context,
      () => ref.read(callsControllerProvider.notifier).cancel(task.id),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CallTask?>(taskProvider(widget.taskId), _onTask);
    final task = ref.watch(taskProvider(widget.taskId));
    final loading = ref.watch(callsControllerProvider).isLoading;
    if (task != null && !task.status.isLiveCall || task == null && !loading) {
      _leave();
    }
    if (task != null && !_placed) {
      _placed = true;
      _toEnd(animate: false);
    }

    return Theme(
      data: KolbiTheme.immersive(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          return Scaffold(
            key: const Key('live-call-screen'),
            appBar: AppBar(
              leading: const BackButton(),
              actions: [
                if (task != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.md),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      onPressed: _busy ? null : () => _hangUp(task),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.call_end),
                      label: const Text('통화 끊기'),
                    ),
                  ),
              ],
            ),
            body: task == null
                ? const SizedBox.shrink()
                : ResponsiveBody(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // The header stays put while there is room; on a short screen (big text, the
                        // approval pinned below) it scrolls with the captions instead of squeezing them.
                        final pinHeader = constraints.maxHeight >= 420;
                        final captions = TranscriptView(
                          entries: task.transcript,
                          calleeName: task.targetName,
                          agentName: '콜비',
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (pinHeader) _Header(task: task),
                            Expanded(
                              child: SingleChildScrollView(
                                key: const Key('live-captions'),
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpace.lg,
                                  AppSpace.sm,
                                  AppSpace.lg,
                                  0,
                                ),
                                child: pinHeader
                                    ? captions
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _Header(task: task, inset: false),
                                          const SizedBox(height: AppSpace.sm),
                                          captions,
                                        ],
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpace.sm),
                              child: Text(
                                '실시간 자막 · 통화는 글로 기록돼요',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
            bottomNavigationBar: switch (task?.pendingApproval) {
              final approval? => _PinnedApproval(
                child: ApprovalCard(
                  key: ValueKey(approval.id),
                  taskId: task!.id,
                  approval: approval,
                ),
              ),
              null => null,
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.task, this.inset = true});

  final CallTask task;

  /// Side padding of its own; inside the captions' scroll view the view pads it.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = task.status == TaskStatus.inProgress;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset ? AppSpace.lg : 0,
        AppSpace.xs,
        inset ? AppSpace.lg : 0,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KolbiOrb(state: KolbiOrbState.responding, size: 48),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      connected ? '통화 중' : '연결하고 있어요',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    if (connected && task.connectedAt != null) ...[
                      Text(
                        ' · ',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      CallTimer(
                        since: task.connectedAt!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(task.targetName, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.xs),
                Text(
                  task.goal,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The approval card in the light theme it was designed and tested in (SPEC-UX-001), pinned so the captions
/// never push it away; it never grows past half the screen with big text, two thirds otherwise.
class _PinnedApproval extends StatelessWidget {
  const _PinnedApproval({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final light = AppTheme.light();
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1;
    return Theme(
      data: light,
      child: Material(
        color: light.colorScheme.surface,
        child: SafeArea(
          child: ResponsiveBody(
            shrinkHeight: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height *
                    (enlarged ? 1 / 2 : 2 / 3),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  AppSpace.md,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
