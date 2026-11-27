import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The call kind's row in today, tasks and history (SPEC-SHELL-001 REQ-007; was home's `_TaskTile`).
/// History passes its result chip as [trailing] and its result line as [subtitle].
class CallTaskTile extends StatelessWidget {
  const CallTaskTile({
    super.key,
    required this.task,
    required this.onTap,
    this.trailing,
    this.subtitle,
  });

  final CallTask task;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsApproval = task.pendingApproval != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Card(
        key: const Key('kind-call-row'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    task.status.isLiveCall
                        ? Icons.phone_in_talk_rounded
                        : Icons.call_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.targetName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        subtitle ?? task.outcome?.summary ?? task.goal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    trailing ??
                        StatusChip(task.status, needsApproval: needsApproval),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      formatRelative(task.createdAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
