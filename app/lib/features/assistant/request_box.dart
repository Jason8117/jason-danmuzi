import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../shell/request_intake.dart';

/// SPEC-ASSIST-001 REQ-008: today's request box, moved whole into the assistant's text mode — the input (same
/// hint and keys), send, [직접 입력하기], "최근 통화한 곳" and the templates (SPEC-INTAKE-001 REQ-017, REQ-018).
class RequestBox extends ConsumerWidget {
  const RequestBox({
    super.key,
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

  static const _decoration = InputDecoration(
    hintText: '무엇을 도와드릴까요?',
    counterText: '',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(requestTemplatesProvider);
    final recent = ref.watch(recentPlacesProvider);
    // While another screen covers the assistant (including its push transition), the input is drawn as a
    // look-alike without an editor, so the screen on top stays the only TextField owner.
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            Expanded(
              // The SHELL-001 keys stay on the same input, so the shell's assistant tests keep finding it.
              child: KeyedSubtree(
                key: const Key('assistant-intake-field'),
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
                        child: Text(
                          input.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            KeyedSubtree(
              key: const Key('assistant-intake-send'),
              child: IconButton.filled(
                key: const Key('home-intake-send'),
                tooltip: '보내기',
                onPressed: onSend,
                icon: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
        TextButton(onPressed: onManual, child: const Text('직접 입력하기')),
        if (recent != null && recent.isNotEmpty) ...[
          const _SectionHeader('최근 통화한 곳'),
          for (final counterparty in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              // One Text per suggestion, so each reads as a single item.
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
            for (final template in templates)
              ActionChip(
                avatar: Icon(
                  template.icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(template.label),
                onPressed: () => onFill(template.goal),
              ),
          ],
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xs,
        AppSpace.xl,
        AppSpace.xs,
        AppSpace.sm,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
