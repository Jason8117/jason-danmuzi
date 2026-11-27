import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_settings.dart';
import '../application/calls_controller.dart';
import 'trust_notice.dart';

/// Server limit on `goal`, in UTF-16 units like `CreateTaskBody` (SPEC-INTAKE-001 REQ-021).
const _maxGoalLength = 1000;

enum _Field { target, phone, goal, context }

/// One card with the draft the server proposed. Every row is edited where it is — no dialog, no new screen —
/// and a single tap on [이대로 시작] creates the task with `autoStart` (SPEC-INTAKE-001 REQ-019 .. REQ-021).
class PlanCardScreen extends ConsumerStatefulWidget {
  const PlanCardScreen({super.key, required this.draft});

  final PlanDraft draft;

  @override
  ConsumerState<PlanCardScreen> createState() => _PlanCardScreenState();
}

class _PlanCardScreenState extends ConsumerState<PlanCardScreen> {
  late final _target = TextEditingController(text: widget.draft.targetName ?? '');
  late final _phone = TextEditingController(text: _draftPhone == null ? '' : formatPhone(_draftPhone!));
  late final _goal = TextEditingController(text: widget.draft.goal);
  late final _context = TextEditingController(text: widget.draft.context ?? '');
  final _newCondition = TextEditingController();
  late final List<String> _conditions = [...widget.draft.conditions];
  late CallLanguage _language = widget.draft.language;
  late final Set<_Field> _editing = {if (widget.draft.targetName == null) _Field.target};
  bool _phoneEdited = false;
  bool _addingCondition = false;
  bool _submitting = false;
  String? _phoneError;

  String? get _draftPhone => widget.draft.phoneNumber;

  /// REQ-020: without a number the card asks for it once, in a field above every row.
  bool get _askNumber => _draftPhone == null;

  /// The draft's E.164 value until the user types; the server normalizes whatever was typed.
  String get _phoneValue => _askNumber || _phoneEdited ? _phone.text.trim() : _draftPhone!;

  String get _fullGoal => goalWithConditions(_goal.text.trim(), _conditions);

  bool get _goalTooLong => _fullGoal.length > _maxGoalLength;

  bool _canStart(AppSettings settings) =>
      _target.text.trim().isNotEmpty &&
      _phoneValue.replaceAll(RegExp(r'\D'), '').length >= 8 &&
      _goal.text.trim().length >= 5 &&
      !_goalTooLong &&
      settings.hasProfile;

  @override
  void dispose() {
    for (final c in [_target, _phone, _goal, _context, _newCondition]) {
      c.dispose();
    }
    super.dispose();
  }

  void _edit(_Field field) => setState(() => _editing.add(field));

  void _addCondition(String value) {
    final condition = value.trim();
    setState(() {
      if (condition.isNotEmpty) _conditions.add(condition);
      _newCondition.clear();
      _addingCondition = false;
    });
  }

  Future<void> _start() async {
    // SPEC-FOLLOWUP-001 REQ-014: the first call on a device waits for the trust notice.
    if (!await ensureTrustAcknowledged(context, ref) || !mounted) return;
    final settings = ref.read(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _submitting = true;
      _phoneError = null;
    });
    try {
      final created = await ref
          .read(callsControllerProvider.notifier)
          .create(
            NewCallRequest(
              targetName: _target.text.trim(),
              phoneNumber: _phoneValue,
              goal: _fullGoal,
              context: _context.text.trim(),
              language: _language,
              requesterName: settings.requesterName,
              callbackNumber: settings.callbackNumber,
              autoStart: true,
            ),
          );
      HapticFeedback.lightImpact();
      if (mounted) context.pushReplacement('/calls/${created.id}');
    } on ApiException catch (error) {
      if (!mounted) return;
      final numberProblem = error.code == 'invalid_phone' || error.code == 'blocked_number';
      setState(() {
        _submitting = false;
        if (numberProblem) {
          _phoneError = error.message;
          _editing.add(_Field.phone);
        }
      });
      if (!numberProblem) messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
    }
  }

  TextField _phoneField({required bool autofocus, String? helper}) => TextField(
    key: const Key('plan-phone-field'),
    controller: _phone,
    autofocus: autofocus,
    keyboardType: TextInputType.phone,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]'))],
    decoration: InputDecoration(
      labelText: '전화번호',
      hintText: '예: 02-123-4567',
      helperText: helper,
      errorText: _phoneError,
    ),
    onChanged: (_) => setState(() {
      _phoneEdited = true;
      _phoneError = null;
    }),
  );

  TextField _textField(Key key, TextEditingController controller, {bool autofocus = true, int maxLines = 1}) =>
      TextField(
        key: key,
        controller: controller,
        autofocus: autofocus,
        minLines: 1,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final draft = widget.draft;

    return Scaffold(
      appBar: AppBar(title: const Text('이렇게 걸어 볼게요')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xxl),
          children: [
            if (_askNumber) ...[
              _phoneField(
                autofocus: true,
                helper: draft.numberBlocked ? '긴급·특수번호에는 걸 수 없어요. 다른 번호를 알려 주세요.' : '번호만 알려 주시면 바로 걸게요.',
              ),
              const SizedBox(height: AppSpace.md),
            ],
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlanRow(
                    label: '전화할 곳',
                    onTap: _editing.contains(_Field.target) ? null : () => _edit(_Field.target),
                    child: _editing.contains(_Field.target)
                        ? _textField(const Key('plan-target-field'), _target, autofocus: draft.targetName != null)
                        : Text(_target.text),
                  ),
                  if (!_askNumber)
                    _PlanRow(
                      label: '전화번호',
                      onTap: _editing.contains(_Field.phone) ? null : () => _edit(_Field.phone),
                      child: _editing.contains(_Field.phone)
                          ? _phoneField(autofocus: true)
                          : Wrap(
                              spacing: AppSpace.sm,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(formatPhone(_draftPhone!)),
                                if (draft.phoneSource case final source?)
                                  Text(
                                    source.label,
                                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                                  ),
                              ],
                            ),
                    ),
                  _PlanRow(
                    label: '부탁할 일',
                    onTap: _editing.contains(_Field.goal) ? null : () => _edit(_Field.goal),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_editing.contains(_Field.goal))
                          _textField(const Key('plan-goal-field'), _goal, maxLines: 6)
                        else
                          Text(_goal.text),
                        if (_goalTooLong) ...[
                          const SizedBox(height: AppSpace.xs),
                          Text('부탁할 일이 너무 길어요.', style: TextStyle(color: theme.colorScheme.error)),
                        ],
                      ],
                    ),
                  ),
                  _PlanRow(
                    label: '조건',
                    child: Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (i, condition) in _conditions.indexed)
                          InputChip(
                            label: Text(condition),
                            deleteButtonTooltipMessage: '조건 삭제',
                            onDeleted: () => setState(() => _conditions.removeAt(i)),
                          ),
                        if (_addingCondition)
                          SizedBox(
                            width: 220,
                            child: TextField(
                              key: const Key('plan-condition-field'),
                              controller: _newCondition,
                              autofocus: true,
                              decoration: const InputDecoration(hintText: '예: 8시도 괜찮아요'),
                              onSubmitted: _addCondition,
                            ),
                          )
                        else
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: const Text('조건 추가'),
                            onPressed: () => setState(() => _addingCondition = true),
                          ),
                      ],
                    ),
                  ),
                  if (draft.context != null)
                    _PlanRow(
                      label: '알려줘도 되는 정보',
                      onTap: _editing.contains(_Field.context) ? null : () => _edit(_Field.context),
                      child: _editing.contains(_Field.context)
                          ? _textField(const Key('plan-context-field'), _context, maxLines: 4)
                          : Text(_context.text),
                    ),
                  _PlanRow(
                    label: '통화 언어',
                    onTap: () =>
                        setState(() => _language = _language == CallLanguage.ko ? CallLanguage.en : CallLanguage.ko),
                    child: Text(_language.label),
                  ),
                  _PlanRow(
                    label: '내 이름',
                    onTap: () => context.push('/settings'),
                    child: Text(settings.hasProfile ? settings.requesterName : '설정에서 입력해 주세요'),
                  ),
                ],
              ),
            ),
            if (draft.source == IntakeSource.heuristic) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                'AI 없이 간단히 정리했어요. 내용을 확인해 주세요.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ResponsiveBody(
          shrinkHeight: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.md),
            child: FilledButton(
              key: const Key('plan-start'),
              onPressed: _submitting || !_canStart(settings) ? null : _start,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('이대로 시작'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // REQ-009: each row is at least one tap target tall; the pencil is its own labeled button.
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(child: child),
              if (onTap != null)
                IconButton(
                  tooltip: '수정',
                  onPressed: onTap,
                  icon: Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
