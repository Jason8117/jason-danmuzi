import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../application/calls_controller.dart';
import '../../domain/call_models.dart';

const int kMaxApprovalCommentChars = 500;

/// Shown while the AI has put the other party on hold and is waiting for the user's decision.
class ApprovalCard extends ConsumerStatefulWidget {
  const ApprovalCard({super.key, required this.taskId, required this.approval});

  final String taskId;
  final ApprovalRequest approval;

  @override
  ConsumerState<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<ApprovalCard> {
  final _commentController = TextEditingController();
  Timer? _ticker;
  /// null = idle; true/false = which button is submitting
  bool? _submittingApprove;

  bool get _busy => _submittingApprove != null;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _commentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    if (_busy) return;
    setState(() => _submittingApprove = approve);
    final comment = _commentController.text.trim();
    await runWithFeedback(
      context,
      () => ref.read(callsControllerProvider.notifier).decide(
            widget.taskId,
            widget.approval.id,
            approve: approve,
            comment: comment.isEmpty ? null : comment,
          ),
    );
    // Keep the comment on failure (e.g. 409 approval_closed) so the user can retry.
    if (mounted) setState(() => _submittingApprove = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = widget.approval.expiresAt.difference(DateTime.now());
    final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
    final charCount = _commentController.text.characters.length;

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
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              enabled: !_busy,
              maxLines: 3,
              minLines: 2,
              maxLength: kMaxApprovalCommentChars,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '조건·안내 (선택)',
                hintText: '예: 예약금은 1만 원까지만, 그 이상은 거절해 주세요',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                counterText: '$charCount / $kMaxApprovalCommentChars',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _decide(false),
                    child: _submittingApprove == false
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('거절'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _decide(true),
                    child: _submittingApprove == true
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('승인'),
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
