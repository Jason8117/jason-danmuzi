import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/config/app_settings.dart';
import '../features/calls/presentation/call_templates.dart';
import '../features/calls/presentation/home_screen.dart';
import 'navigation.dart';
import 'routes.dart';

/// `/assistant` until SPEC-ASSIST-001: a light, full-screen copy of today's request input (OD-6, REQ-006).
/// It sits outside the tab shell, so it closes itself before any tab screen opens (research R1-G).
class AssistantPlaceholderScreen extends ConsumerStatefulWidget {
  const AssistantPlaceholderScreen({super.key});

  @override
  ConsumerState<AssistantPlaceholderScreen> createState() =>
      _AssistantPlaceholderScreenState();
}

class _AssistantPlaceholderScreenState
    extends ConsumerState<AssistantPlaceholderScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  bool get _canSend => !_sending && _input.text.trim().length >= 2;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (!_canSend) return;
    final router = GoRouter.of(context);
    if (!ref.read(settingsProvider).hasProfile) {
      // The plan card needs the requester's name: close the assistant, then open settings.
      router.pop();
      router.pushNamed(RouteNames.settings);
      return;
    }
    setState(() => _sending = true);
    final draft = await requestPlanDraft(
      ref,
      ScaffoldMessenger.of(context),
      text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (draft != null) submitFromAssistant(router, draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(
          key: const Key('assistant-close'),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        title: const Text('비서에게 부탁하기'),
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('assistant-intake-field'),
                    controller: _input,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: '무엇을 도와드릴까요?',
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                IconButton.filled(
                  key: const Key('assistant-intake-send'),
                  tooltip: '보내기',
                  onPressed: _canSend ? _send : null,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            Text(
              '이런 부탁도 할 수 있어요',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final template in callTemplates)
                  ActionChip(
                    avatar: Icon(
                      template.icon,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(template.label),
                    onPressed: () => setState(() {
                      _input.value = TextEditingValue(
                        text: template.goal,
                        selection: TextSelection.collapsed(
                          offset: template.goal.length,
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
