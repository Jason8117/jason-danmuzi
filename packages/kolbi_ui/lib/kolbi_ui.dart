/// Kolbi UI: shared Flutter design tokens, theme and widgets (SPEC-MODULE-001).
library;

export 'src/kinds/task_kind_presenter.dart'
    show TaskKindPresenter, UnknownKindPresenter, TaskKindPresenters;
export 'src/input/code_point_formatter.dart'
    show CodePointLengthLimitingFormatter;
export 'src/theme/app_theme.dart'
    show AppTheme, CardTone, ToneColors, StatusColors;
export 'src/theme/fonts.dart' show registerKolbiFontLicenses;
export 'src/theme/tokens.dart'
    show
        AppSpace,
        AppRadius,
        AppMotion,
        kMinTapTarget,
        motionDuration,
        scrollToOffset,
        relativeLuminance,
        contrastRatio;
export 'src/widgets/common.dart'
    show
        ResponsiveBody,
        AppCard,
        SectionCard,
        BulletList,
        MessageView,
        PulsingDot,
        runWithFeedback,
        describeError;
export 'src/widgets/briefing_card.dart' show KolbiBriefingCard;
export 'src/widgets/outcome_card.dart' show outcomeTone, OutcomeCard;
export 'src/widgets/status_chip.dart' show StatusChip, StatusCategory;
export 'src/widgets/step_timeline.dart' show KolbiStepTimeline;
export 'src/widgets/tab_badge.dart' show KolbiTabBadge;
export 'src/widgets/transcript_view.dart' show TranscriptView;
