import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/call_models.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.needsApproval = false});

  final TaskStatus status;
  final bool needsApproval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg) = switch (status) {
      _ when needsApproval => (scheme.tone(CardTone.attention).background, scheme.tone(CardTone.attention).foreground),
      TaskStatus.dialing ||
      TaskStatus.ringing ||
      TaskStatus.inProgress => (scheme.live.background, scheme.live.foreground),
      TaskStatus.awaitingApproval => (scheme.primaryContainer, scheme.onPrimaryContainer),
      TaskStatus.completed => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      TaskStatus.failed => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    final label = needsApproval ? '승인 대기' : status.label;

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
              if (status.isLiveCall || needsApproval) ...[
                PulsingDot(color: fg, size: 7),
                const SizedBox(width: AppSpace.xs),
              ],
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
