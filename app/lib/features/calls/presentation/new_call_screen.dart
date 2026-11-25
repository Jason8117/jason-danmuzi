import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../application/calls_controller.dart';
import '../domain/call_models.dart';
import 'call_templates.dart';
import 'trust_notice.dart';

class NewCallScreen extends ConsumerStatefulWidget {
  const NewCallScreen({super.key, this.template, this.redial});

  final CallTemplate? template;

  /// A previous task to call again with the same details.
  final CallTask? redial;

  @override
  ConsumerState<NewCallScreen> createState() => _NewCallScreenState();
}

class _NewCallScreenState extends ConsumerState<NewCallScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _target = TextEditingController(text: widget.redial?.targetName);
  late final _phone = TextEditingController(text: widget.redial == null ? null : formatPhone(widget.redial!.phoneNumber));
  late final _goal = TextEditingController(text: widget.redial?.goal ?? widget.template?.goal);
  late final _context = TextEditingController(text: widget.redial?.context);
  late CallLanguage _language = widget.redial?.language ?? CallLanguage.ko;
  late String _targetHint = widget.template?.targetHint ?? '예: 라 파스타 강남점';
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [_target, _phone, _goal, _context]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyTemplate(CallTemplate template) {
    setState(() {
      _goal.text = template.goal;
      _targetHint = template.targetHint;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final settings = ref.read(settingsProvider);
    setState(() => _submitting = true);

    late CallTask created;
    final ok = await runWithFeedback(context, () async {
      created = await ref.read(callsControllerProvider.notifier).create(
            NewCallRequest(
              targetName: _target.text.trim(),
              phoneNumber: _phone.text.trim(),
              goal: _goal.text.trim(),
              context: _context.text.trim(),
              language: _language,
              requesterName: settings.requesterName,
              callbackNumber: settings.callbackNumber,
            ),
          );
    });

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) context.pushReplacement('/calls/${created.id}');
  }

  String? _required(String? value, String message) => (value == null || value.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('전화 맡기기')),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xxxl),
            children: [
              Text('자주 하는 부탁', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: callTemplates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final template = callTemplates[i];
                    return ActionChip(
                      avatar: Icon(template.icon, size: 18),
                      label: Text(template.label),
                      onPressed: () => _applyTemplate(template),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _target,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: '어디에 전화할까요?', hintText: _targetHint, prefixIcon: const Icon(Icons.storefront_outlined)),
                validator: (v) => _required(v, '전화할 곳의 이름을 입력해 주세요.'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]'))],
                decoration: const InputDecoration(labelText: '전화번호', hintText: '예: 02-123-4567', prefixIcon: Icon(Icons.phone_outlined)),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.isEmpty) return '전화번호를 입력해 주세요.';
                  if (digits.length < 8) return '전화번호가 너무 짧아요.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _goal,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: '무엇을 해결할까요?',
                  hintText: '예: 금요일 저녁 7시 2명 예약. 안 되면 8시도 괜찮아요.',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 5) ? '목적을 조금 더 자세히 알려주세요.' : null,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _context,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: '상대에게 알려줘도 되는 정보 (선택)',
                  hintText: '예: 주문번호 2024-1234, 가입자 이름 김민수',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 6),
              Text('통화 언어', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<CallLanguage>(
                segments: [for (final l in CallLanguage.values) ButtonSegment(value: l, label: Text(l.label))],
                selected: {_language},
                onSelectionChanged: (s) => setState(() => _language = s.first),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      // SPEC-FOLLOWUP-001 REQ-015: instructions given to the AI, not guarantees (same constants as the notice).
                      child: Text(
                        agentRulesNotice,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: const Text('통화 계획 만들기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
