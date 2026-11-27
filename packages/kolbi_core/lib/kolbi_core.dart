/// Kolbi core: the headless, pure Dart part of the app (SPEC-MODULE-001).
library;

export 'src/approval_comment.dart'
    show
        kMaxApprovalCommentCodePoints,
        kApprovalCommentCounterFrom,
        kApprovalQuickReplies,
        codePointLength,
        truncateToCodePoints,
        withQuickReply,
        hasSensitiveDigits;
export 'src/data/calls_repository.dart'
    show CallsEvent, TasksSnapshot, TaskUpdated, TaskDeleted, CallsRepository;
export 'src/follow_up.dart'
    show
        seoulOffset,
        defaultAppointmentLength,
        buildShareText,
        offersCalendarDraft,
        buildCalendarDraft;
export 'src/format/formatters.dart'
    show formatPhone, formatDuration, formatRelative, formatClock;
export 'src/models/call_models.dart'
    show
        CallLanguage,
        TaskStatus,
        Speaker,
        ApprovalStatus,
        OutcomeResult,
        OutcomeSource,
        TranscriptEntry,
        CallPlan,
        ApprovalRequest,
        CallOutcome,
        Appointment,
        CallTask,
        AutoStartBlocked,
        NewCallRequest,
        ServerInfo;
export 'src/models/counterparties.dart'
    show normalizeName, Counterparty, recentCounterparties;
export 'src/models/intake_models.dart'
    show PhoneSource, IntakeSource, PlanDraft, IntakeResult, goalWithConditions;
export 'src/network/api_client.dart' show ApiException, ApiClient;
export 'src/network/live_channel.dart'
    show LiveStatus, LiveConnection, LiveChannel;
