import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../application/calls_controller.dart';
import '../../domain/call_models.dart';

/// Shown while the AI has put the other party on hold and is waiting for the user's decision.
class ApprovalCard extends ConsumerStatefulWidget {
  const ApprovalCard({super.key, required this.taskId, required this.approval});

  final String taskId;
  final ApprovalRequest approval;

  @override
  ConsumerState<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<ApprovalCard> {
  Timer? _ticker;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    setState(() => _submitting = true);
    await runWithFeedback(
      context,
      () => ref.read(callsControllerProvider.notifier).decide(widget.taskId, widget.approval.id, approve: approve),
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = widget.approval.expiresAt.difference(DateTime.now());
    final seconds = remaining.isNegative ? 0 : remaining.inSeconds;

    return Card(
      color: scheme.warning.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.warning.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pan_tool_alt_rounded, color: scheme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('상대방이 기다리고 있어요', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text('$seconds초', style: theme.textTheme.labelLarge?.copyWith(color: scheme.warning, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Text(widget.approval.question, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 6),
            Text(
              '응답이 없으면 진행하지 않는 것으로 처리돼요.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => _decide(false),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : () => _decide(true),
                    child: const Text('승인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
