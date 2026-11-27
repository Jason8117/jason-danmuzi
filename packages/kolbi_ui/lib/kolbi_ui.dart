/// Kolbi UI: shared Flutter design tokens, theme and widgets (SPEC-MODULE-001).
library;

export 'src/input/code_point_formatter.dart'
    show CodePointLengthLimitingFormatter;
export 'src/theme/app_theme.dart'
    show AppTheme, CardTone, ToneColors, StatusColors;
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
export 'src/widgets/outcome_card.dart' show outcomeTone, OutcomeCard;
export 'src/widgets/status_chip.dart' show StatusChip, StatusCategory;
export 'src/widgets/transcript_view.dart' show TranscriptView;
