import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/call_models.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.needsApproval = false});

  final TaskStatus status;
  final bool needsApproval;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (status) {
      _ when needsApproval => (scheme.warning.withValues(alpha: 0.15), scheme.warning),
      TaskStatus.dialing || TaskStatus.ringing || TaskStatus.inProgress => (scheme.callLive.withValues(alpha: 0.14), scheme.callLive),
      TaskStatus.awaitingApproval => (scheme.primaryContainer, scheme.onPrimaryContainer),
      TaskStatus.completed => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      TaskStatus.failed => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.isLiveCall || needsApproval) ...[PulsingDot(color: fg, size: 7), const SizedBox(width: 6)],
          Text(
            needsApproval ? '승인 대기' : status.label,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
