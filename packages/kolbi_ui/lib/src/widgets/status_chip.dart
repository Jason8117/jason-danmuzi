import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'package:kolbi_core/kolbi_core.dart';

/// The five ways a status is shown (SPEC-DESIGN-001 REQ-007, plan.md §A.2).
enum StatusCategory { waiting, active, needsApproval, done, failed }

class StatusChip extends StatelessWidget {
  const StatusChip(TaskStatus this.status, {super.key, this.needsApproval = false}) : _category = null, _label = null;

  /// A chip for anything that is not a task status (e.g. a result kind), drawn with the category's
  /// color and icon and never a pulsing dot (REQ-008).
  const StatusChip.category(StatusCategory category, String label, {super.key})
    : status = null,
      needsApproval = false,
      _category = category,
      _label = label;

  /// Null only for [StatusChip.category].
  final TaskStatus? status;
  final bool needsApproval;
  final StatusCategory? _category;
  final String? _label;

  /// A pending approval wins over every status, as before.
  StatusCategory get category =>
      _category ??
      switch (status!) {
        _ when needsApproval => StatusCategory.needsApproval,
        TaskStatus.dialing ||
        TaskStatus.ringing ||
        TaskStatus.inProgress ||
        TaskStatus.planning ||
        TaskStatus.summarizing => StatusCategory.active,
        TaskStatus.awaitingApproval => StatusCategory.needsApproval,
        TaskStatus.completed => StatusCategory.done,
        TaskStatus.failed => StatusCategory.failed,
        TaskStatus.canceled => StatusCategory.waiting,
      };

  /// Five distinct shapes so the category never depends on color alone (04 DP-6).
  static IconData iconOf(StatusCategory category) => switch (category) {
    StatusCategory.waiting => Icons.pause_circle_rounded,
    StatusCategory.active => Icons.autorenew_rounded,
    StatusCategory.needsApproval => Icons.pan_tool_alt_rounded,
    StatusCategory.done => Icons.task_alt_rounded,
    StatusCategory.failed => Icons.report_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = this.category;
    final colors = switch (category) {
      StatusCategory.waiting => scheme.tone(CardTone.neutral),
      StatusCategory.active => scheme.live,
      StatusCategory.needsApproval => scheme.tone(CardTone.attention),
      StatusCategory.done => scheme.tone(CardTone.positive),
      StatusCategory.failed => scheme.tone(CardTone.critical),
    };
    final (bg, fg) = (colors.background, colors.foreground);
    final label = _label ?? (needsApproval ? '승인 대기' : status!.label);
    final dot = (status?.isLiveCall ?? false) || needsApproval;

    // REQ-012: one readable label; REQ-006: the color and wording cross-fade on change.
    return Semantics(
      container: true,
      label: '상태: $label',
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: motionDuration(context, AppMotion.medium),
        child: Container(
          key: ValueKey(label),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot)
                PulsingDot(color: fg, size: 7)
              else
                Icon(iconOf(category), size: 14, color: fg),
              const SizedBox(width: AppSpace.xs),
              // REQ-011: with large text the label wraps inside the chip instead of overflowing it.
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
