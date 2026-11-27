import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/calls_controller.dart';

/// Shown while the AI has put the other party on hold and is waiting for the user's decision.
class ApprovalCard extends ConsumerStatefulWidget {
  const ApprovalCard({super.key, required this.taskId, required this.approval, this.now = DateTime.now});

  final String taskId;
  final ApprovalRequest approval;

  /// Clock for the remaining seconds; tests pass a fake one (SPEC-UX-001 REQ-012).
  final DateTime Function() now;

  @override
  ConsumerState<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<ApprovalCard> {
  final _commentController = TextEditingController();
  Timer? _ticker;

  /// null = idle; true/false = which button is submitting
  bool? _submittingApprove;

  bool get _busy => _submittingApprove != null;

  /// Remaining seconds at the previous build, to spot the 30 s and 10 s crossings.
  int? _lastSeconds;

  /// Fallback live-region text when the platform cannot announce (REQ-012).
  String? _timeNotice;

  int get _secondsLeft {
    final remaining = widget.approval.expiresAt.difference(widget.now());
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  /// Speaks "30초 남았어요" / "10초 남았어요" once each, at the moment the countdown passes them.
  void _announceCrossings(int seconds) {
    final last = _lastSeconds;
    _lastSeconds = seconds;
    if (last == null) return;
    for (final mark in const [30, 10]) {
      if (last > mark && seconds <= mark) {
        final message = '$mark초 남았어요';
        if (MediaQuery.supportsAnnounceOf(context)) {
          SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);
        } else {
          _timeNotice = message;
        }
      }
    }
  }

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
    final comment = truncateToCodePoints(_commentController.text.trim(), kMaxApprovalCommentCodePoints);
    final ok = await runWithFeedback(
      context,
      () => ref
          .read(callsControllerProvider.notifier)
          .decide(widget.taskId, widget.approval.id, approve: approve, comment: comment.isEmpty ? null : comment),
    );
    if (ok) HapticFeedback.lightImpact();
    // Keep the comment on failure (e.g. 409 approval_closed) so the user can retry.
    if (mounted) setState(() => _submittingApprove = null);
  }

  /// Only fills the field; the decision is still sent with 승인 / 거절 (SPEC-APPROVAL-001 REQ-011).
  void _addQuickReply(String reply) {
    final next = withQuickReply(_commentController.text, reply);
    if (next == _commentController.text) return;
    _commentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = scheme.tone(CardTone.attention);
    final seconds = _secondsLeft;
    _announceCrossings(seconds);
    final comment = _commentController.text;
    final codePoints = codePointLength(comment);
    const progress = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));

    // The card announces itself once as a live region; its label never carries the ticking seconds (REQ-012).
    return Semantics(
      container: true,
      liveRegion: true,
      label: '승인 요청: ${widget.approval.question}',
      child: AppCard(
        tone: CardTone.attention,
        icon: Icons.pan_tool_alt_rounded,
        title: '상대방이 기다리고 있어요',
        trailing: ExcludeSemantics(
          child: Text(
            '$seconds초',
            style: theme.textTheme.labelLarge?.copyWith(
              color: tone.foreground,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        actions: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _decide(false),
                child: _submittingApprove == false ? progress : const Text('거절'),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _decide(true),
                child: _submittingApprove == true ? progress : const Text('승인'),
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(container: true, liveRegion: true, label: _timeNotice ?? '', child: const SizedBox.shrink()),
            Text(widget.approval.question, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpace.xs),
            Text(
              '응답이 없으면 진행하지 않는 것으로 처리돼요.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpace.md),
            // One scrollable row keeps the pinned card short, so the live transcript above stays visible.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (index, reply) in kApprovalQuickReplies.indexed) ...[
                    if (index > 0) const SizedBox(width: AppSpace.sm),
                    ActionChip(label: Text(reply), onPressed: _busy ? null : () => _addQuickReply(reply)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            TextField(
              controller: _commentController,
              enabled: !_busy,
              minLines: 1,
              maxLines: 4,
              inputFormatters: const [CodePointLengthLimitingFormatter(kMaxApprovalCommentCodePoints)],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '조건 덧붙이기 (선택)',
                hintText: '예: 예약금은 1만 원까지만, 그 이상은 거절해 주세요',
                helperText: '카드번호·비밀번호·주민번호는 적지 마세요.',
                border: const OutlineInputBorder(),
                counterText: codePoints >= kApprovalCommentCounterFrom
                    ? '$codePoints / $kMaxApprovalCommentCodePoints'
                    : null,
              ),
            ),
            if (hasSensitiveDigits(comment)) ...[
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.error),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      '카드번호처럼 보이는 숫자는 지우고 보낼게요.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
