// Split between package:kolbi_core (constants and pure functions) and
// package:kolbi_ui (input formatter) by SPEC-MODULE-001; this path re-exports both.
export 'package:kolbi_core/kolbi_core.dart'
    show
        kMaxApprovalCommentCodePoints,
        kApprovalCommentCounterFrom,
        kApprovalQuickReplies,
        codePointLength,
        truncateToCodePoints,
        withQuickReply,
        hasSensitiveDigits;
export 'package:kolbi_ui/kolbi_ui.dart' show CodePointLengthLimitingFormatter;
