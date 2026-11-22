import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// Same limit and unit as the server (`server/src/http/schemas.ts`): Unicode code points.
const int kMaxApprovalCommentCodePoints = 500;

/// The "N / 500" counter only appears from this many code points on.
const int kApprovalCommentCounterFrom = 400;

/// Quick replies that fit both an approval and a rejection (SPEC-APPROVAL-001 OD-2).
const List<String> kApprovalQuickReplies = [
  '금액이 더 나오면 거절해 주세요',
  '다른 날짜·시간도 물어봐 주세요',
  '조건을 자세히 듣고 다시 물어봐 주세요',
];

int codePointLength(String text) => text.runes.length;

/// Cuts [text] to at most [max] code points without splitting a user-perceived character.
String truncateToCodePoints(String text, int max) {
  if (codePointLength(text) <= max) return text;
  final kept = StringBuffer();
  var used = 0;
  for (final character in text.characters) {
    final size = codePointLength(character);
    if (used + size > max) break;
    kept.write(character);
    used += size;
  }
  return kept.toString();
}

/// Keeps the comment field within [kMaxApprovalCommentCodePoints]; Flutter's `maxLength` counts graphemes.
class CodePointLengthLimitingFormatter extends TextInputFormatter {
  const CodePointLengthLimitingFormatter(this.maxCodePoints);

  final int maxCodePoints;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (codePointLength(newValue.text) <= maxCodePoints) return newValue;
    // Let an IME finish composing (e.g. Korean syllables); the next edit is checked again.
    if (newValue.composing.isValid) return newValue;
    if (codePointLength(oldValue.text) >= maxCodePoints) return oldValue;
    final text = truncateToCodePoints(newValue.text, maxCodePoints);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Adds a quick reply to the comment: as is when empty, after one space otherwise.
/// Unchanged when the reply is already there or the result would exceed the limit.
String withQuickReply(String current, String reply) {
  if (current.contains(reply)) return current;
  final base = current.trimRight();
  final next = base.isEmpty ? reply : '$base $reply';
  return codePointLength(next) > kMaxApprovalCommentCodePoints ? current : next;
}

final _controlChars = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]');
final _digitChain = RegExp(r'\d(?:[ -]?\d)*');
final _phoneToken = RegExp(r'^0\d{1,2}-\d{3,4}-\d{4}$');
const _sensitiveMinDigits = 13;

/// Whether the server would mask part of [text] (SPEC-APPROVAL-001 REQ-003, REQ-013).
/// Mirrors `server/src/domain/approvalComment.ts`; the app only warns, the server masks.
// @MX:NOTE: [AUTO] Mirror of the server digit rule; both sides run the same 16-row AC-003 vector table.
// @MX:SPEC: SPEC-APPROVAL-001
bool hasSensitiveDigits(String text) {
  final normalized = text.replaceAll(_controlChars, '').replaceAll('\t', ' ');
  for (final chain in _digitChain.allMatches(normalized)) {
    var digits = 0;
    for (final token in chain[0]!.split(' ')) {
      if (_phoneToken.hasMatch(token)) {
        digits = 0;
        continue;
      }
      digits += token.replaceAll(RegExp(r'\D'), '').length;
      if (digits >= _sensitiveMinDigits) return true;
    }
  }
  return false;
}
