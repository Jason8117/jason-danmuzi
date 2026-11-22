import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_settings.dart';

// @MX:ANCHOR: [AUTO] The six trust statements shown before the first call, in settings and (1)(2)(5) on the manual form.
// @MX:REASON: Each sentence must stay true against the server code (SPEC-FOLLOWUP-001 AC-013 command table); change wording only with that table.
const trustStatements = [
  'AI 비서는 통화를 시작할 때 AI라고 먼저 밝히도록 정해져 있어요.',
  '결제·약정처럼 중요한 결정은 통화 중에 먼저 물어보도록 정해져 있어요.',
  '대화 내용은 글로 기록되어 서버에 저장돼요. 끝난 통화는 상세 화면에서 지울 수 있어요.',
  '통화 음성은 이 앱의 서버에 저장하지 않아요. 실제 통화에서는 음성이 통신 서비스(KAT)와 OpenAI를 거쳐 처리돼요.',
  '카드번호·비밀번호 같은 정보는 상대에게 말하지 않도록 정해져 있어요.',
  '서버에 OpenAI가 연결되어 있으면, 부탁 정리·통화 계획·결과 요약을 위해 부탁 내용, 내 이름, 상대에게 알려도 된다고 한 정보, '
      '승인 코멘트, 대화 글이 OpenAI로 전송돼요. 실제 통화에서는 회신 번호도 통화 지시문에 담겨 OpenAI로 전송돼요.',
];

/// REQ-015: the manual form's paragraph — statements (1)(2)(5), the instruction-level wording.
final String agentRulesNotice = [trustStatements[0], trustStatements[1], trustStatements[4]].join(' ');

/// REQ-015: shown on the detail screen while the call is dialing, ringing or in progress.
const liveCallTrustLine = 'AI 비서는 AI임을 밝히도록 정해져 있어요 · 대화는 글로 기록돼요';

/// REQ-014: true when the user has confirmed the notice — now or on an earlier call on this device.
/// Closing the sheet any other way (back, tapping outside) returns false and the caller sends nothing.
Future<bool> ensureTrustAcknowledged(BuildContext context, WidgetRef ref) async {
  if (ref.read(settingsProvider).trustNoticeAcknowledged) return true;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _TrustNoticeSheet(),
  );
  if (confirmed != true) return false;
  await ref.read(settingsProvider.notifier).acknowledgeTrustNotice();
  return true;
}

/// The six statements as a list; used by the first-call sheet and the settings screen.
class TrustStatementList extends StatelessWidget {
  const TrustStatementList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final statement in trustStatements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(statement, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrustNoticeSheet extends StatelessWidget {
  const _TrustNoticeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('전화하기 전에 알려 드려요', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const TrustStatementList(),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인했어요')),
          ],
        ),
      ),
    );
  }
}
