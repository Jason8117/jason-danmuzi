import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock.dart';
import '../../../core/config/app_settings.dart';
import '../../../shell/kind_registration.dart';
import '../../../shell/navigation.dart';
import '../../../shell/request_intake.dart';
import '../../../shell/routes.dart';
import '../../../shell/tab_scaffold.dart';
import '../../../shell/task_feed.dart';
import '../application/calls_controller.dart';
import '../data/calls_repository.dart';
import 'call_templates.dart';

/// SPEC-INTAKE-001 REQ-017: one input at the top sends a one-line request to `POST /v1/intake` and opens the plan card.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  bool get _canSend => !_sending && _input.text.trim().length >= 2;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Replaces the input and puts the cursor at the end, so the user can keep typing.
  void _fill(String text) => setState(() {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  });

  Future<void> _send() async {
    final text = _input.text.trim();
    if (!_canSend) return;
    // The plan card needs the requester's name; the typed text stays where it is meanwhile.
    if (!ref.read(settingsProvider).hasProfile) {
      context.pushNamed(RouteNames.settings);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final draft = await requestPlanDraft(ref, messenger, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (draft != null) context.pushNamed(RouteNames.plan, extra: draft);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(sortedTasksProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      key: const Key('today-screen'),
      appBar: AppBar(
        title: const _Wordmark(),
        actions: [
          const _LiveIndicator(),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(RouteNames.settings),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: switch (tasks) {
          AsyncData(:final value) => _TaskList(
            tasks: value,
            hasProfile: settings.hasProfile,
            intake: _IntakeBox(
              input: _input,
              sending: _sending,
              onChanged: () => setState(() {}),
              onSend: _canSend ? _send : null,
              onManual: () => context.pushNamed(settings.hasProfile ? RouteNames.newCall : RouteNames.settings),
              onFill: _fill,
            ),
            recentPlaces: _RecentPlaces(suggestions: recentCounterparties(value), onFill: _fill),
          ),
          AsyncError(:final error) => MessageView(
            icon: Icons.cloud_off_rounded,
            title: '서버와 연결되지 않았어요',
            message: describeError(error),
            actions: [
              OutlinedButton(onPressed: () => context.pushNamed(RouteNames.settings), child: const Text('서버 설정')),
              FilledButton(onPressed: () => ref.invalidate(callsControllerProvider), child: const Text('다시 시도')),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// design.md D5: the "kolbi." wordmark with the indigo square, where the app bar said CallMate.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: AppSpace.sm),
        Text('kolbi.', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// "11월 26일 목요일" for [now] in Seoul (design.md D5).
String todayDateLabel(DateTime now) => DateFormat('M월 d일 EEEE', 'ko').format(now.toUtc().add(seoulOffset));

/// 05:00-10:59 morning, 11:00-16:59 afternoon, otherwise evening, in Seoul; then ", 이름 님." when a name is set.
String todayGreeting(DateTime now, String name) {
  final hour = now.toUtc().add(seoulOffset).hour;
  final part = hour >= 5 && hour < 11
      ? '좋은 아침이에요'
      : hour >= 11 && hour < 17
      ? '좋은 오후예요'
      : '좋은 저녁이에요';
  final trimmed = name.trim();
  return trimmed.isEmpty ? '$part.' : '$part, $trimmed 님.';
}

class _LiveIndicator extends ConsumerWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(liveStatusProvider);
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      LiveStatus.connected => (scheme.live.accent, '실시간 연결됨'),
      LiveStatus.connecting => (scheme.tone(CardTone.attention).accent, '연결 중'),
      LiveStatus.disconnected => (scheme.error, '연결 끊김 · 재시도 중'),
    };
    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: kMinTapTarget,
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _IntakeBox extends StatelessWidget {
  const _IntakeBox({
    required this.input,
    required this.sending,
    required this.onChanged,
    required this.onSend,
    required this.onManual,
    required this.onFill,
  });

  final TextEditingController input;
  final bool sending;
  final VoidCallback onChanged;
  final VoidCallback? onSend;
  final VoidCallback onManual;
  final ValueChanged<String> onFill;

  static const _decoration = InputDecoration(hintText: '무엇을 도와드릴까요?', counterText: '');

  @override
  Widget build(BuildContext context) {
    // While another screen covers home (including its push transition), the input is drawn as a look-alike without
    // an editor: a covered screen needs no live text field, and screens on top keep being the only TextField owner.
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            Expanded(
              child: current
                  ? TextField(
                      key: const Key('home-intake-field'),
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      decoration: _decoration,
                      onChanged: (_) => onChanged(),
                      onSubmitted: (_) => onSend?.call(),
                    )
                  : InputDecorator(
                      decoration: _decoration,
                      isEmpty: input.text.isEmpty,
                      child: Text(input.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
            ),
            const SizedBox(width: AppSpace.sm),
            IconButton.filled(
              key: const Key('home-intake-send'),
              tooltip: '보내기',
              onPressed: onSend,
              icon: sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
        TextButton(onPressed: onManual, child: const Text('직접 입력하기')),
        const _SectionHeader('이런 부탁도 할 수 있어요'),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final template in callTemplates)
              ActionChip(
                avatar: Icon(template.icon, size: 18, color: Theme.of(context).colorScheme.primary),
                label: Text(template.label),
                onPressed: () => onFill(template.goal),
              ),
          ],
        ),
      ],
    );
  }
}

/// "최근 통화한 곳": recent counterparties; tapping one starts a request to it (SPEC-INTAKE-001 REQ-018).
class _RecentPlaces extends StatelessWidget {
  const _RecentPlaces({required this.suggestions, required this.onFill});

  final List<Counterparty> suggestions;
  final ValueChanged<String> onFill;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('최근 통화한 곳'),
        for (final counterparty in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            // One Text per suggestion, so each reads as a single item and its name never repeats a list tile.
            child: ActionChip(
              avatar: const Icon(Icons.history_rounded, size: 18),
              label: Text(
                '${counterparty.name} · ${formatPhone(counterparty.phoneNumber)} · ${counterparty.callCount}번 통화',
              ),
              onPressed: () => onFill('${counterparty.name}에 '),
            ),
          ),
      ],
    );
  }
}

/// SCR-H01 in the order of SPEC-SHELL-001 REQ-015: date and greeting, briefing, the request input with its
/// chips and shortcuts, then 확인이 필요해요 and 진행 중 (first two each), then 최근 통화한 곳. Finished tasks
/// live in the history tab.
class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.hasProfile, required this.intake, required this.recentPlaces});

  final List<CallTask> tasks;
  final bool hasProfile;
  final Widget intake;
  final Widget recentPlaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groups = ref.watch(taskGroupsProvider);
    final now = ref.watch(clockProvider)();
    final name = ref.watch(settingsProvider.select((s) => s.requesterName));
    final isSimulated = ref.watch(serverInfoProvider).value?.realCalls == false;
    final router = GoRouter.of(context);

    return RefreshIndicator(
      onRefresh: () => ref.read(callsControllerProvider.notifier).refresh(),
      child: ListView(
        controller: TabScrollScope.rootControllerOf(context, AppTab.today),
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xxl),
        children: [
          const SizedBox(height: AppSpace.sm),
          Text(todayDateLabel(now), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpace.xs),
          Text(todayGreeting(now, name), style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpace.xs),
          Text('오늘도 제가 함께할게요.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (tasks.isNotEmpty && groups.briefingCount > 0) ...[
            const SizedBox(height: AppSpace.lg),
            KolbiBriefingCard(
              key: const Key('today-briefing'),
              title: '오늘 중요한 일이 ${groups.briefingCount}개 있어요.',
              message: groups.approvals.isNotEmpty
                  ? '${withSubjectParticle(groups.approvals.first.targetName)} 답을 기다려요.'
                  : '${groups.ongoing.first.targetName}에 전화하고 있어요.',
              linkLabel: '업무 보기 →',
              onLink: () => openTab(router, AppTab.tasks),
            ),
          ],
          const _SectionHeader('비서에게 부탁하기'),
          intake,
          const SizedBox(height: AppSpace.lg),
          _Shortcuts(onAssistant: () => openAssistant(router)),
          if (isSimulated) const _SimulationBanner(),
          if (!hasProfile) const _ProfilePrompt(),
          if (tasks.isEmpty) const _EmptyState(),
          if (tasks.isNotEmpty && groups.approvals.isNotEmpty) ...[
            _SectionHeader(
              '확인이 필요해요',
              trailing: Text(
                '${groups.approvals.length}',
                key: const Key('today-approvals-count'),
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            for (final task in groups.approvals.take(2)) _row(context, ref, task),
          ],
          if (tasks.isNotEmpty && groups.ongoing.isNotEmpty) ...[
            const _SectionHeader('진행 중'),
            for (final task in groups.ongoing.take(2)) _row(context, ref, task),
          ],
          recentPlaces,
        ],
      ),
    );
  }
}

/// The 2x2 shortcuts (design.md D5): two open the assistant, two are not available yet.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.onAssistant});

  final VoidCallback onAssistant;

  @override
  Widget build(BuildContext context) {
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: a), const SizedBox(width: AppSpace.sm), Expanded(child: b)],
    );
    return Column(
      children: [
        pair(
          _Shortcut(key: const Key('shortcut-call'), icon: Icons.phone_forwarded_rounded, label: '전화 대신하기', onTap: onAssistant),
          _Shortcut(key: const Key('shortcut-search'), icon: Icons.travel_explore_rounded, label: '정보 찾아보기', onTap: onAssistant),
        ),
        const SizedBox(height: AppSpace.sm),
        pair(
          const _Shortcut(key: Key('shortcut-calendar'), icon: Icons.event_note_rounded, label: '일정 관리'),
          const _Shortcut(key: Key('shortcut-mail'), icon: Icons.mail_outline_rounded, label: '메일 확인'),
        ),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({super.key, required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;

  /// Null: shown, but not available yet ("곧 쓸 수 있어요").
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: enabled ? label : '$label, 곧 쓸 수 있어요',
      excludeSemantics: true,
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            child: Row(
              children: [
                Icon(icon, color: enabled ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: theme.textTheme.titleSmall),
                      if (!enabled)
                        Text('곧 쓸 수 있어요', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A task row drawn by its kind's presenter; tapping it opens the task on the tasks tab (REQ-005, REQ-007).
Widget _row(BuildContext context, WidgetRef ref, CallTask task) =>
    presenterForTask(ref, task).buildRow(context, task, onTap: () => openTask(GoRouter.of(context), task.id));

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xl, AppSpace.xs, AppSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SimulationBanner extends StatelessWidget {
  const _SimulationBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              '시뮬레이션 모드예요. 실제 전화는 걸리지 않고, 가상의 상대와 통화가 진행돼요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
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
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: SectionCard(
        title: '먼저 내 이름을 알려주세요',
        icon: Icons.badge_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('AI 비서가 "○○님을 대신해 전화드렸어요"라고 소개할 때 사용해요.'),
            const SizedBox(height: AppSpace.md),
            // A tonal look: the filled style's #635BFF would make this read like the main action (DESIGN plan-audit N6).
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              onPressed: () => context.pushNamed(RouteNames.settings),
              child: const Text('내 정보 입력'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  // REQ-018 (b): the template chips live only in the suggestion row above, so the empty state keeps just its message.
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpace.xxl),
      child: MessageView(
        icon: Icons.support_agent_rounded,
        title: '귀찮은 전화, 대신 걸어드릴게요',
        message: '예약, 문의, 요금 할인, 환불 요청까지.\n목적만 알려주시면 AI 비서가 통화하고 결과를 정리해 드려요.',
      ),
    );
  }
}
