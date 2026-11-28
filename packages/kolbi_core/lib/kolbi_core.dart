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
export 'src/data/places_repository.dart' show PlacesRepository;
export 'src/follow_up.dart'
    show
        seoulOffset,
        defaultAppointmentLength,
        buildShareText,
        offersCalendarDraft,
        buildCalendarDraft;
export 'src/format/formatters.dart'
    show formatPhone, formatDuration, formatRelative, formatClock;
export 'src/format/korean_particle.dart' show withSubjectParticle;
export 'src/kinds/call_kind.dart' show CallTaskKind;
export 'src/kinds/task_kind.dart'
    show
        TaskKindDescriptor,
        kCallKindId,
        DuplicateTaskKindError,
        UnknownTaskKind,
        TaskKindCatalog;
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
export 'src/models/place_models.dart'
    show
        PlacePhoneCheck,
        PlaceSearchSource,
        Place,
        PlaceSearchResult,
        PlaceSearchStart;
export 'src/network/api_client.dart' show ApiException, ApiClient;
export 'src/network/live_channel.dart'
    show LiveStatus, LiveConnection, LiveChannel;
export 'src/places/place_intent.dart' show placeSearchStartFor;
export 'src/tasks/task_groups.dart'
    show TaskGroups, isApprovalRequest, groupTasks, HistoryDay, groupHistory;
export 'src/tasks/task_steps.dart'
    show TaskStepId, TaskStepState, TaskStep, taskSteps;
