import 'package:flutter/services.dart';
import 'package:kolbi_core/kolbi_core.dart';

export 'package:kolbi_core/kolbi_core.dart' show kMaxApprovalCommentCodePoints, kApprovalCommentCounterFrom, kApprovalQuickReplies, codePointLength, truncateToCodePoints, withQuickReply, hasSensitiveDigits;

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
