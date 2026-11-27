import 'package:kolbi_core/kolbi_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// CMP-34: a task's six steps, top to bottom (SPEC-SHELL-001 REQ-010).
/// Each row is keyed `task-step-<n>` and reads "6단계 중 N단계, <이름>, <상태>". Steps after the first
/// canceled one are hidden (design.md D2.2).
class KolbiStepTimeline extends StatelessWidget {
  const KolbiStepTimeline({super.key, required this.steps});

  final List<TaskStep> steps;

  @override
  Widget build(BuildContext context) {
    final firstCanceled = steps.indexWhere(
      (s) => s.state == TaskStepState.canceled,
    );
    final shown = firstCanceled < 0
        ? steps
        : steps.sublist(0, firstCanceled + 1);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final step in shown) _StepRow(step: step, total: steps.length),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.total});

  final TaskStep step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = switch (step.state) {
      TaskStepState.done => (
        Icons.check_circle_rounded,
        scheme.tone(CardTone.positive).foreground,
      ),
      TaskStepState.current => (
        Icons.radio_button_checked_rounded,
        scheme.onPrimaryContainer,
      ),
      TaskStepState.waiting => (
        Icons.radio_button_unchecked_rounded,
        scheme.onSurfaceVariant,
      ),
      TaskStepState.failed => (
        Icons.cancel_rounded,
        scheme.tone(CardTone.critical).foreground,
      ),
      TaskStepState.skipped => (
        Icons.remove_circle_outline_rounded,
        scheme.onSurfaceVariant,
      ),
      TaskStepState.canceled => (Icons.block_rounded, scheme.onSurfaceVariant),
    };
    final current = step.state == TaskStepState.current;
    return Semantics(
      key: Key('task-step-${step.number}'),
      container: true,
      excludeSemantics: true,
      label:
          '$total단계 중 ${step.number}단계, ${step.id.label}, ${step.state.label}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.id.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: current ? FontWeight.w700 : null,
                    ),
                  ),
                  Text(
                    step.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
