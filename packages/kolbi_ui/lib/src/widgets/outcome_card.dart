import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'package:kolbi_core/kolbi_core.dart';

/// OD-2 default wording (pending owner review).
const _unverifiedNotice = '자동 요약이라 목표를 이뤘는지 확인하지 못했어요. 대화 기록을 직접 확인해 주세요.';

/// SPEC-UX-001 REQ-004: the card's tone follows the result.
CardTone outcomeTone(CallTask task) => task.status == TaskStatus.canceled
    ? CardTone.neutral
    : switch (task.outcome?.result) {
        OutcomeResult.success => CardTone.positive,
        OutcomeResult.partial => CardTone.caution,
        // Neutral: neither a success claim nor a failure verdict (SPEC-OUTCOME-001 REQ-012).
        OutcomeResult.unverified => CardTone.neutral,
        _ => CardTone.critical,
      };

class OutcomeCard extends StatelessWidget {
  const OutcomeCard({super.key, required this.task, this.actions});

  final CallTask task;

  /// The follow-up actions, drawn as the card's action row.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final outcome = task.outcome;
    final tone = outcomeTone(task);
    final colors = scheme.tone(tone);

    if (task.status == TaskStatus.canceled) {
      return AppCard(
        title: '취소된 통화',
        icon: Icons.block_rounded,
        actions: actions,
        child: const Text('통화를 걸기 전에 취소했어요.'),
      );
    }

    final icon = switch (outcome?.result) {
      OutcomeResult.success => Icons.check_circle_rounded,
      OutcomeResult.partial => Icons.timelapse_rounded,
      OutcomeResult.unverified => Icons.help_outline_rounded,
      _ => Icons.error_rounded,
    };
    final labelColor = tone == CardTone.neutral ? scheme.onSurfaceVariant : colors.foreground;
    final errorColor = tone == CardTone.critical ? colors.foreground : scheme.error;

    return AppCard(
      tone: tone,
      actions: actions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone == CardTone.neutral ? scheme.onSurfaceVariant : colors.accent, size: 28),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  outcome?.result.label ?? '통화 실패',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: labelColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(outcome?.summary ?? task.error ?? '통화를 완료하지 못했어요.', style: theme.textTheme.bodyLarge),
          if (outcome?.result == OutcomeResult.unverified) ...[
            const SizedBox(height: AppSpace.sm),
            Text(_unverifiedNotice, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          if (task.error != null && outcome != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(task.error!, style: theme.textTheme.bodySmall?.copyWith(color: errorColor)),
          ],
          if (outcome != null && outcome.keyFacts.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Text('알아낸 내용', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpace.sm),
            BulletList(outcome.keyFacts),
          ],
          if (outcome != null && outcome.followUps.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text('해야 할 일', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpace.sm),
            BulletList(outcome.followUps),
          ],
        ],
      ),
    );
  }
}
