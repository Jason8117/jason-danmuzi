import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/common.dart';
import '../../domain/call_models.dart';

/// OD-2 default wording (pending owner review).
const _unverifiedNotice = '자동 요약이라 목표를 이뤘는지 확인하지 못했어요. 대화 기록을 직접 확인해 주세요.';

class OutcomeCard extends StatelessWidget {
  const OutcomeCard({super.key, required this.task});

  final CallTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final outcome = task.outcome;

    if (task.status == TaskStatus.canceled) {
      return const SectionCard(
        title: '취소된 통화',
        icon: Icons.block_rounded,
        child: Text('통화를 걸기 전에 취소했어요.'),
      );
    }

    final (IconData icon, Color color) = switch (outcome?.result) {
      OutcomeResult.success => (Icons.check_circle_rounded, scheme.primary),
      OutcomeResult.partial => (Icons.timelapse_rounded, Colors.orange.shade700),
      // Neutral: neither a success claim nor a failure verdict (SPEC-OUTCOME-001 REQ-012).
      OutcomeResult.unverified => (Icons.help_outline_rounded, scheme.onSurfaceVariant),
      _ => (Icons.error_rounded, scheme.error),
    };

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Text(
                outcome?.result.label ?? '통화 실패',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            outcome?.summary ?? task.error ?? '통화를 완료하지 못했어요.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          if (outcome?.result == OutcomeResult.unverified) ...[
            const SizedBox(height: 8),
            Text(
              _unverifiedNotice,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (task.error != null && outcome != null) ...[
            const SizedBox(height: 8),
            Text(task.error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
          ],
          if (outcome != null && outcome.keyFacts.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('알아낸 내용', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            BulletList(outcome.keyFacts),
          ],
          if (outcome != null && outcome.followUps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('해야 할 일', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            BulletList(outcome.followUps),
          ],
        ],
      ),
    );
  }
}
