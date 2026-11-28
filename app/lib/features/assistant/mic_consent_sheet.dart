import 'package:flutter/foundation.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

// SPEC-ASSIST-001 REQ-005 (CMP-23) and REQ-006 (OD-2): the notices shown before the OS takes over.

const micPurpose = '말로 부탁하면 제가 글로 받아 적어요. 콜비는 음성을 저장하지 않아요.';

/// Android only, shown once before the first dictation (OD-2 deviation, owner decision 2026-11-28).
const androidSpeechServiceNotice =
    'Android에서는 구글 음성 인식 서비스가 말을 글로 바꿀 수 있어요. 콜비는 음성을 저장하지 않아요.';

/// The device flag that the Android notice was seen; stored like the trust notice, never sent anywhere.
const androidSpeechServiceNoticeKey = 'androidSpeechServiceNoticeAcknowledged';

/// OD-2: who turns speech into text when the device cannot do it on its own (iOS Apple, Android Google).
String generalRecognizerNotice([TargetPlatform? platform]) {
  final provider = switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => '애플',
    _ => '구글',
  };
  return '이 기기에서는 $provider의 음성 인식 서비스가 말을 글로 바꿔요. 콜비는 음성을 저장하지 않아요.';
}

/// The purpose notice with [계속]; the OS permission dialog appears only after it (04 DP-7).
class MicConsentSheet extends StatelessWidget {
  const MicConsentSheet({
    super.key,
    required this.onContinue,
    this.withSpeechService = false,
  });

  final VoidCallback onContinue;

  /// Android before the first dictation: the purpose notice also says who may turn speech into text.
  final bool withSpeechService;

  @override
  Widget build(BuildContext context) => _NoticeCard(
    icon: Icons.mic_none_rounded,
    message: withSpeechService
        ? '$micPurpose\n$androidSpeechServiceNotice'
        : micPurpose,
    actions: [
      FilledButton(
        key: const Key('mic-consent-continue'),
        onPressed: onContinue,
        child: const Text('계속'),
      ),
    ],
  );
}

/// The OD-2 notice: [계속] uses the general recognizer once, [글로 입력] goes to text mode.
class GeneralRecognizerNotice extends StatelessWidget {
  const GeneralRecognizerNotice({
    super.key,
    required this.onContinue,
    required this.onText,
  });

  final VoidCallback onContinue;
  final VoidCallback onText;

  @override
  Widget build(BuildContext context) => _NoticeCard(
    icon: Icons.cloud_outlined,
    message: generalRecognizerNotice(),
    actions: [
      TextButton(
        key: const Key('fallback-text'),
        onPressed: onText,
        child: const Text('글로 입력'),
      ),
      FilledButton(
        key: const Key('fallback-continue'),
        onPressed: onContinue,
        child: const Text('계속'),
      ),
    ],
  );
}

/// Android, permission already granted, first dictation: the speech-service sentence on its own.
class SpeechServiceNotice extends StatelessWidget {
  const SpeechServiceNotice({
    super.key,
    required this.onContinue,
    required this.onText,
  });

  final VoidCallback onContinue;
  final VoidCallback onText;

  @override
  Widget build(BuildContext context) => _NoticeCard(
    icon: Icons.cloud_outlined,
    message: androidSpeechServiceNotice,
    actions: [
      TextButton(
        key: const Key('speech-service-text'),
        onPressed: onText,
        child: const Text('글로 입력'),
      ),
      FilledButton(
        key: const Key('speech-service-continue'),
        onPressed: onContinue,
        child: const Text('계속'),
      ),
    ],
  );
}

/// Refused with "don't ask again": how to turn it on, and [설정 열기].
class MicSettingsNotice extends StatelessWidget {
  const MicSettingsNotice({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => _NoticeCard(
    icon: Icons.mic_off_outlined,
    message: '설정에서 마이크와 음성 인식을 켜면 말로 부탁할 수 있어요.',
    actions: [
      OutlinedButton(
        key: const Key('open-settings'),
        onPressed: onOpenSettings,
        child: const Text('설정 열기'),
      ),
    ],
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(message)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: actions,
          ),
        ],
      ),
    );
  }
}
