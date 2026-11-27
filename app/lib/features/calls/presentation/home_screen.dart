import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_settings.dart';
import '../../../shell/kind_registration.dart';
import '../../../shell/navigation.dart';
import '../../../shell/routes.dart';
import '../application/calls_controller.dart';
import '../data/calls_repository.dart';
import 'call_templates.dart';

/// Sends a one-line request to `POST /v1/intake` (SPEC-INTAKE-001 REQ-017). A server without the endpoint
/// gets a blank draft (REQ-022); any other failure shows a snack bar and returns null.
Future<PlanDraft?> requestPlanDraft(WidgetRef ref, ScaffoldMessengerState messenger, String text) async {
  try {
    // The input has no language picker; the plan card can switch the call language.
    return (await ref.read(callsRepositoryProvider).intake(text, CallLanguage.ko)).draft;
  } on ApiException catch (error) {
    if (error.statusCode == 404) return PlanDraft.blank(text);
    messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
  }
  return null;
}

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
        title: const Text('CallMate'),
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
              suggestions: recentCounterparties(value),
              onFill: _fill,
            ),
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
    required this.suggestions,
    required this.onFill,
  });

  final TextEditingController input;
  final bool sending;
  final VoidCallback onChanged;
  final VoidCallback? onSend;
  final VoidCallback onManual;
  final List<Counterparty> suggestions;
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
        if (suggestions.isNotEmpty) ...[
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

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.hasProfile, required this.intake});

  final List<CallTask> tasks;
  final bool hasProfile;
  final Widget intake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ongoing = tasks.where((t) => !t.status.isTerminal).toList();
    final finished = tasks.where((t) => t.status.isTerminal).toList();
    final isSimulated = ref.watch(serverInfoProvider).value?.realCalls == false;

    return RefreshIndicator(
      onRefresh: () => ref.read(callsControllerProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xxl),
        children: [
          intake,
          if (isSimulated) const _SimulationBanner(),
          if (!hasProfile) const _ProfilePrompt(),
          if (tasks.isEmpty) const _EmptyState(),
          if (ongoing.isNotEmpty) ...[const _SectionHeader('진행 중'), for (final task in ongoing) _row(context, ref, task)],
          if (finished.isNotEmpty) ...[
            const _SectionHeader('지난 통화'),
            for (final task in finished) _row(context, ref, task),
          ],
        ],
      ),
    );
  }
}

/// A task row drawn by its kind's presenter; tapping it opens the task on the tasks tab (REQ-005, REQ-007).
Widget _row(BuildContext context, WidgetRef ref, CallTask task) =>
    presenterForTask(ref, task).buildRow(context, task, onTap: () => openTask(GoRouter.of(context), task.id));

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xl, AppSpace.xs, AppSpace.sm),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
            FilledButton.tonal(onPressed: () => context.pushNamed(RouteNames.settings), child: const Text('내 정보 입력')),
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
